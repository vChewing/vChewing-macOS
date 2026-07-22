// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKSwift

// MARK: - ClientAddrUnwrapper

/// 泛型輔助結構：將 `(givenClientAddr, thisAddr)` 的安全解讀模式封裝為 block 工廠。
///
/// 解讀失敗時回傳 `fallback`；成功時將 unwrap 後的 `(SessionCtl, any IMKTextInput)` 傳入 `block`。
/// 所有 block 內均以純記憶體位址操作（`Unmanaged` / `takeUnretainedValue`），
/// 不捕獲 `self`，避免 ARC 摻入生命週期。
enum ClientAddrUnwrapper {
  // 回傳型別只能寫成 `(UInt, UInt) -> T`，不然 ObjC 的 Block 無法解讀。
  static func make<T>(
    fallback: T,
    _ block: @escaping (SessionCtl, any IMKTextInput) -> T
  )
    -> ((UInt, UInt) -> T) {
    { givenClientAddr, thisAddr in
      let pair = ClientControllerAddrPair(clientAddr: givenClientAddr, controllerAddr: thisAddr)
      guard let (clientAddr, _) = pair.unwrapped,
            let selfOpaque = UnsafeRawPointer(bitPattern: thisAddr),
            let clientOpaque = UnsafeRawPointer(bitPattern: clientAddr) else { return fallback }
      let myself = Unmanaged<SessionCtl>.fromOpaque(selfOpaque).takeUnretainedValue()
      let sender = Unmanaged<AnyObject>.fromOpaque(clientOpaque).takeUnretainedValue()
      return block(myself, sender as! (any IMKTextInput))
    }
  }
}

// MARK: - SessionCtl

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(SessionCtl) // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
@MainActor
public final class SessionCtl: IMKInputSessionController {
  // MARK: Lifecycle

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override public init(server: IMKServer, delegate: Any?, client inputClient: IMKTextInput) {
    // Note: this constuctor gets called everytime this IME gets switched to.
    // This happens even if the client() is the same IMKTextInput instance.
    super.init(server: server, delegate: delegate, client: inputClient)
    ObjCMemoryLeakTracker.shared.track(self, type: "SessionCtl")

    assignBlocks()

    // macOS 10.9 ~ 10.12 的相容性處理：此處得使用傳入的 client 參數，因為 `client()` 沒有就緒、是 nil。
    // 在這些舊版系統上，IMK 尚未在 super.init 返回時就完成 client 物件的綁定，
    // 因此 `client()` 在建構子同步執行期間始終回傳 nil，導致 Session 無法登記至快取。
    // 穩妥的做法是使用當前建構子內傳入的 client 參數，可確保 IMK 已完成 client 綁定。

    // Force initialization.
    self.core = callCoreAtLeastOnce(client: inputClient)
  }

  // MARK: Public

  @MainActor
  public var core: InputSession? {
    get {
      if let workingValue = InputSession.session(for: self) { return workingValue }
      let newValue = callCoreAtLeastOnce(client: nil) // <- 使用 `client()`。
      self.core = newValue
      return newValue
    }
    set {
      if let session = newValue {
        let thisAddr = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
        InputSession.registerSessionAddr(session, for: thisAddr)
      }
    }
  }

  // MARK: Private

  /// 為所有 `IMKInputSessionController` 的 assignable block 賦值。
  /// 每個 block 內均以純記憶體位址操作（`Unmanaged` / `takeUnretainedValue`），
  /// 不捕獲 `self`，避免 ARC 摻入生命週期。
  private func assignBlocks() {
    // -- 需要 client 的 blocks（走 ClientControllerAddrPair.unwrapped 安全檢查） --

    onActivateServer = ClientAddrUnwrapper.make(fallback: ()) { $0.core?.activateServer($1) }
    onDeactivateServer = ClientAddrUnwrapper.make(fallback: ()) { $0.core?.deactivateServer($1) }
    onShowingPreferences = ClientAddrUnwrapper.make(fallback: ()) { $0.core?.showPreferences($1) }
    onAutoCommittingComposition = ClientAddrUnwrapper.make(fallback: ()) { $0.core?.commitCompositionByOS($1) }

    onProvidingComposedString = ClientAddrUnwrapper.make(fallback: nil) { $0.core?.composedString($1) }
    onProvidingRecognizedEvents = ClientAddrUnwrapper.make(fallback: 0) { $0.core?.recognizedEvents($1) ?? 0 }

    onHandlingGivenNullableEvent = { nsEventPtr, givenClientAddr, thisAddr in
      let pair = ClientControllerAddrPair(clientAddr: givenClientAddr, controllerAddr: thisAddr)
      guard let (clientAddr, _) = pair.unwrapped,
            let selfOpaque = UnsafeRawPointer(bitPattern: thisAddr),
            let clientOpaque = UnsafeRawPointer(bitPattern: clientAddr) else { return false }
      let myself = Unmanaged<SessionCtl>.fromOpaque(selfOpaque).takeUnretainedValue()
      let sender = Unmanaged<AnyObject>.fromOpaque(clientOpaque).takeUnretainedValue()
      let event: NSEvent? = nsEventPtr != 0
        ? Unmanaged<NSEvent>.fromOpaque(UnsafeRawPointer(bitPattern: nsEventPtr)!).takeUnretainedValue()
        : nil
      let result = myself.core?.handleNSEvent(event, client: sender as! (any IMKTextInput)) ?? false
      if !result, PrefMgr.shared.isDebugModeEnabled {
        let stack = Thread.callStackSymbols.prefix(7).joined(separator: "\n")
        if let newEvent = event?.copyAsKBEvent {
          vCLog("OmitNSEvent: \(newEvent);\nstack: \(stack)")
        } else {
          vCLog("OmitNSEvent: [RAW]\(event.debugDescription);\nstack: \(stack)")
        }
      }
      return result
    }

    onSettingObjCValue = { valuePtr, intTag, givenClientAddr, thisAddr in
      let pair = ClientControllerAddrPair(clientAddr: givenClientAddr, controllerAddr: thisAddr)
      guard let (clientAddr, _) = pair.unwrapped,
            let selfOpaque = UnsafeRawPointer(bitPattern: thisAddr),
            let clientOpaque = UnsafeRawPointer(bitPattern: clientAddr) else { return }
      let myself = Unmanaged<SessionCtl>.fromOpaque(selfOpaque).takeUnretainedValue()
      let sender = Unmanaged<AnyObject>.fromOpaque(clientOpaque).takeUnretainedValue()
      let value: Any? = valuePtr != 0
        ? Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(bitPattern: valuePtr)!).takeUnretainedValue()
        : nil
      myself.core?.setValue(value, forTag: Int(intTag), client: sender as! (any IMKTextInput))
    }

    // -- 僅需 self 的 blocks（直接解讀 thisAddr） --

    onHidingPallettes = { thisAddr in
      guard let opaque = UnsafeRawPointer(bitPattern: thisAddr) else { return }
      Unmanaged<SessionCtl>.fromOpaque(opaque).takeUnretainedValue().core?.hidePalettes()
    }

    onInputControllerWillClose = { thisAddr in
      guard let opaque = UnsafeRawPointer(bitPattern: thisAddr) else { return }
      Unmanaged<SessionCtl>.fromOpaque(opaque).takeUnretainedValue().core?.inputControllerWillClose()
    }

    onProvidingSelectionRange = { thisAddr in
      guard let opaque = UnsafeRawPointer(bitPattern: thisAddr) else { return .notFound }
      return Unmanaged<SessionCtl>.fromOpaque(opaque).takeUnretainedValue().core?.selectionRange() ?? .notFound
    }

    onProvidingIMEMenu = { thisAddr in
      guard let menuSputnik = IMEMenuSputnik(controllerAddr: thisAddr) else { return NSMenu() }
      return menuSputnik.build()
    }

    // 藉由 ObjC 端的 `onDealloc` block 確保清理動作必定觸發：
    // `-[IMKInputSessionController dealloc]` 由 ObjC runtime 直接管理，
    // 不依賴 Swift `deinit`，亦不應該實作 Swift `deinit`：不得讓 SessionCtl 的生命週期被摻入 ARC 行為。
    onDealloc = { thisAddr in
      InputSession.unregisterSessionAddr(forControllerAddr: thisAddr)
    }
  }

  private func getClientAddrProvider() -> (() -> ClientControllerAddrPair?) {
    let thisAddr = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    return {
      // Client 在 Controller 建構完畢之後才可用，
      // 但 Controller 被析構之後 Client Addr 必定是 dangling pointer。
      // 所以在此複查 Controller 的生命週期。
      guard ObjCMemoryLeakTracker.shared.isTracked(addr: thisAddr) else { return nil }
      guard let opaque = UnsafeRawPointer(bitPattern: thisAddr) else { return nil }
      let this = Unmanaged<SessionCtl>.fromOpaque(opaque).takeUnretainedValue()
      guard let clientObj = this.client() as? InputSession.ClientObj else { return nil }
      let clientAddr = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
      return ClientControllerAddrPair(clientAddr: clientAddr, controllerAddr: thisAddr)
    }
  }

  private func callCoreAtLeastOnce(client maybeClient: Any!) -> InputSession {
    // 嘗試從快取中複用既有的 InputSession，以緩解 CapsLock 頻繁切換場景下的 ARC 壓力。
    // 參見 DevLab/InputMethodKitPhuquingRetarded.txt 內的分析。
    let maybeClientOnMain = maybeClient as? NSObjectProtocol
    let clientObj: NSObjectProtocol? = maybeClientOnMain ?? (client() as? NSObjectProtocol)
    // 改用 uniqueClientIdentifierString 作為快取鍵。
    // 此舉解決 Chrome/Electron 的 client object memAddr 不穩定問題。
    if let clientObj {
      let key = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
      if let cached = InputSession.cachedSession(for: key) {
        cached.reassign(to: self, clientAddrProvider: getClientAddrProvider())
        vCLog("InputSession reused. ID: \(cached.id.uuidString)")
        return cached
      }
    }
    let thisAddr = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    // 先用傳入的參數完成 InputSession 的初期化，其中包括了對這個 Session 的登記過程。
    let newSession = InputSession(controller: self) {
      if let clientObj {
        let clientAddr = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
        return ClientControllerAddrPair(clientAddr: clientAddr, controllerAddr: thisAddr)
      }
      return nil
    }
    // 然後再用脫手操作給這個 Session 重新指派 clientAddrProvider。
    // 這個 async 反而是有必要的，因為 SessionCtl 的 initializer 在
    // 徹底執行完畢之前能拿到的 client() 反而在早期版本 macOS 系統下會是 nil。
    asyncOnMain {
      guard let opaque = UnsafeRawPointer(bitPattern: thisAddr) else { return }
      let this = Unmanaged<SessionCtl>.fromOpaque(opaque).takeUnretainedValue()
      newSession.reassign(to: this, clientAddrProvider: this.getClientAddrProvider())
    }
    return newSession
  }
}
