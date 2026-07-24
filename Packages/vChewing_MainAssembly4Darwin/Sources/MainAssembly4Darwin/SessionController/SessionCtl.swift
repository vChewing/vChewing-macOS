// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
public final class SessionCtl: IMKInputSessionController {}
// MARK: - SessionControllerSputnik

public struct SessionControllerSputnik {
  // MARK: Lifecycle

  /// 用於建構階段：不要求 client() 可用，僅記錄 controller 位址。
  /// `activateServer:` 觸發時 `sputnik.core` 會透過 sessionAddrByControllerAddr 查詢 InputSession。
  public init?(controllerAddr: UInt?, requireClient: Bool = true) {
    guard let controllerAddr else { return nil }
    if requireClient {
      guard let addrPair = Self.getGuardableAddrPair(controllerAddr)() else { return nil }
      self.addrPair = addrPair
    } else {
      // 建構階段 client() 尚未就緒（macOS 10.9），使用 dummy clientAddr。
      // blocks 內會透過 `addrPair.unwrapped` 做 tracker 安全核驗，
      // 屆時 client() 已可用、paired 即可正確 unwrap。
      self.addrPair = ClientControllerAddrPair(clientAddr: 0, controllerAddr: controllerAddr)
    }
  }

  // MARK: Public

  public var core: InputSession? {
    let controllerAddr = addrPair.unwrapped?.controllerAddr
    guard let controllerAddr else { return nil }
    if let workingValue = InputSession.session(for: controllerAddr) {
      return workingValue
    }
    guard let opaque = UnsafeRawPointer(bitPattern: controllerAddr) else { return nil }
    let controller = Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
    let newValue = Self.callCoreAtLeastOnce(controller, client: nil) // <- 使用 `client()`。
    replaceCore(newValue)
    return newValue
  }

  public static func injectPostConstructionHandler() {
    _ = _installConstructorHook
    _ = _configureClassLevelBlocks
  }

  public static func callCoreAtLeastOnce(
    _ controller: IMKInputSessionController,
    client maybeClient: Any!
  )
    -> InputSession {
    // 嘗試從快取中複用既有的 InputSession，以緩解 CapsLock 頻繁切換場景下的 ARC 壓力。
    // 參見 DevLab/InputMethodKitPhuquingRetarded.txt 內的分析。
    let controllerAddr = UInt(bitPattern: Unmanaged.passUnretained(controller).toOpaque())
    let maybeClientOnMain = maybeClient as? NSObjectProtocol
    let clientObj: NSObjectProtocol? = maybeClientOnMain ?? (controller.client() as? NSObjectProtocol)
    // 改用 uniqueClientIdentifierString 作為快取鍵。
    // 此舉解決 Chrome/Electron 的 client object memAddr 不穩定問題。
    if let clientObj {
      let key = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
      if let cached = InputSession.cachedSession(for: key) {
        cached.reassign(to: controller, clientAddrProvider: Self.getGuardableAddrPair(controllerAddr))
        vCLog("InputSession reused. ID: \(cached.id.uuidString)")
        return cached
      }
    }
    // 先用傳入的參數完成 InputSession 的初期化，其中包括了對這個 Session 的登記過程。
    let newSession = InputSession(controller: controller) {
      if let clientObj {
        let clientAddr = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
        return ClientControllerAddrPair(clientAddr: clientAddr, controllerAddr: controllerAddr)
      }
      return nil
    }
    // 然後再用脫手操作給這個 Session 重新指派 clientAddrProvider。
    // 這個 async 反而是有必要的，因為 IMKInputSessionController 的 initializer 在
    // 徹底執行完畢之前能拿到的 client() 反而在早期版本 macOS 系統下會是 nil。
    asyncOnMain {
      // 防止 async dispatch 期間 controller 已被 dealloc 導致的 dangling pointer crash。
      // DeallocSentinel 在 controller dealloc 時會自動 untrack，故此 guard 可安全過濾。
      guard ObjCMemoryLeakTracker.shared.isTracked(addr: controllerAddr),
            let opaque = UnsafeRawPointer(bitPattern: controllerAddr)
      else { return }
      let controllerUnwrapped = Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
      newSession.reassign(to: controllerUnwrapped, clientAddrProvider: Self.getGuardableAddrPair(controllerAddr))
    }
    return newSession
  }

  public static func getGuardableAddrPair(_ controllerAddr: UInt) -> (() -> ClientControllerAddrPair?) {
    {
      // Client 在 Controller 建構完畢之後才可用，
      // 但 Controller 被析構之後 Client Addr 必定是 dangling pointer。
      // 所以在此複查 Controller 的生命週期。
      guard ObjCMemoryLeakTracker.shared.isTracked(addr: controllerAddr) else { return nil }
      guard let opaque = UnsafeRawPointer(bitPattern: controllerAddr) else { return nil }
      let controller = Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
      guard let clientObj = controller.client() as? InputSession.ClientObj else { return nil }
      let clientAddr = UInt(bitPattern: Unmanaged.passUnretained(clientObj).toOpaque())
      return ClientControllerAddrPair(clientAddr: clientAddr, controllerAddr: controllerAddr)
    }
  }

  public func replaceCore(_ newCore: InputSession?) {
    if let session = newCore, let controllerAddr = addrPair.unwrapped?.controllerAddr {
      InputSession.registerSessionAddr(session, for: controllerAddr)
    }
  }

  // MARK: Private

  /// 在 `-[IMKInputSessionController initWithServer:delegate:client:]` 中，
  /// `super.init` 之後會檢測本 selector 是否存在，存在的話即呼叫。
  /// 此處預先以 `class_addMethod` 確保 selector 對 `respondsToSelector:` 回應 YES。
  ///
  /// block 參數對應（`v@:@@@`）：
  /// | 位置 | 型別 | 含義 |
  /// |------|------|------|
  /// | 0 | `AnyObject` | `self`（剛完成 super.init 的 IMKInputSessionController 實例） |
  /// | 1 | `Selector` | `_cmd`（本 selector 自身，無需使用） |
  /// | 2 | `Any?` | `server`（IMKServer *） |
  /// | 3 | `Any?` | `delegate`（nullable id，通常為 nil） |
  /// | 4 | `Any?` | `client`（id<IMKTextInput>，輸入客體 proxy） |
  private static let _installConstructorHook: () = {
    let sel = Selector(("onSuperConstructionSucceeded:delegate:client:"))
    /// 對用以設定委任物件的控制器型別進行初期化處理。
    ///
    /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
    /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
    /// - Parameters:
    ///   - server: IMKServer
    ///   - delegate: 客體物件
    ///   - inputClient: 用以接受輸入的客體應用物件
    let block: @convention(block) (AnyObject, Selector, Any?, Any?, Any?) -> () = {
      // Instance, Selector, IMKServer, Delegate, Client
      instance, _, _, _, givenClient in
      let ctl = instance as? IMKInputSessionController
      guard let ctl else { return }
      ObjCMemoryLeakTracker.shared.track(ctl, type: "IMKInputSessionController")
      let controllerAddr = UInt(bitPattern: Unmanaged.passUnretained(ctl).toOpaque())
      // 建構階段同步完成 tracker 登記 + 極性雙緩衝 session reassign。
      // 使用 constructor 傳入的 givenClient（非 `client()`）：
      // macOS 10.9 下 `client()` 在 init 期間為 nil，但 givenClient 有效。
      if let sputnik = Self(controllerAddr: controllerAddr, requireClient: false) {
        sputnik.replaceCore(Self.callCoreAtLeastOnce(ctl, client: givenClient))
      }
    }
    class_addMethod(IMKInputSessionController.self, sel, imp_implementationWithBlock(block), "v@:@@@")
  }()

  private let addrPair: ClientControllerAddrPair
}

// MARK: - 一次性類別層級 Block 配置（於輸入法啟動時執行）

extension SessionControllerSputnik {
  /// 對 IMKInputSessionController 註冊 13 個類別層級 static block。
  /// 每個 block 均從 raw controller/client 記憶體位址解析對應的 InputSession，
  /// 再將呼叫轉發至 Session 的對應方法。
  @MainActor
  private static let _configureClassLevelBlocks: () = {
    // ---- 伺服器生命週期 ----

    /// 啟用輸入法時，IMK 呼叫此方法。對應 `-[IMKInputController activateServer:]`。
    IMKInputSessionController.configureActivatingServer { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).map { $0.activateServer($1) }
    }
    /// 停用輸入法時，IMK 呼叫此方法。對應 `-[IMKInputController deactivateServer:]`。
    IMKInputSessionController.configureDeactivatingServer { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).map { $0.deactivateServer($1) }
    }
    /// Controller 被釋放時的最終清理。對應 `-[IMKInputController dealloc]`。
    IMKInputSessionController.configureDealloc { sa in
      InputSession.unregisterSessionAddr(forControllerAddr: sa)
    }

    // ---- 偏好設定 ----

    /// 顯示輸入法偏好設定視窗。對應 `-[IMKInputController showPreferences:]`。
    IMKInputSessionController.configureShowingPreferences { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).map { $0.showPreferences($1) }
    }

    // ---- 組字內容 ----

    /// 自動提交當前組字內容（例如使用者在組字中途切換焦點時）。
    /// 對應 `-[IMKInputController commitComposition:]`。
    IMKInputSessionController.configureAutoCommittingComposition { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).map { $0.commitComposition($1) }
    }
    /// 向 IMK 提供當前組字緩衝區的 NSAttributedString。
    /// 對應 `-[IMKInputController composedString:]`。
    IMKInputSessionController.configureProvidingComposedString { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).flatMap { $0.composedString($1) }
    }

    // ---- 鍵盤事件處理 ----

    /// 登記此輸入法能處理的 NSEventType 遮罩。
    /// 對應 `-[IMKInputController recognizedEvents:]`。
    IMKInputSessionController.configureProvidingRecognizedEvents { ca, sa in
      SessionControllerSputnik.controllerAndClient(ca, sa).map { $0.recognizedEvents($1) } ?? 0
    }
    /// 處理來自 IMK 的鍵盤／滑鼠事件。此為輸入法最核心的 dispatch 路徑。
    /// 對應 `-[IMKInputController handleEvent:client:]`。
    IMKInputSessionController.configureHandlingGivenNullableEvent { evPtr, ca, sa in
      guard let (session, sender) = SessionControllerSputnik.controllerAndClient(ca, sa) else { return false }
      let event: NSEvent? = evPtr != 0
        ? Unmanaged<NSEvent>.fromOpaque(UnsafeRawPointer(bitPattern: evPtr)!).takeUnretainedValue()
        : nil
      let result = session.handleNSEvent(event, client: sender)
      if !result, PrefMgr.shared.isDebugModeEnabled {
        let stack = Thread.callStackSymbols.prefix(7).joined(separator: "\n")
        if let newEvent = event?.copyAsKBEvent { vCLog("OmitNSEvent: \(newEvent);\nstack: \(stack)") }
        else { vCLog("OmitNSEvent: [RAW]\(event.debugDescription);\nstack: \(stack)") }
      }
      return result
    }

    // ---- IMK 狀態值 ----

    /// 設定 IMK 狀態值（例如標記文字屬性）。
    /// 對應 `-[IMKInputController setValue:forTag:client:]`。
    IMKInputSessionController.configureSettingObjCValue { vp, tag, ca, sa in
      guard let (session, sender) = SessionControllerSputnik.controllerAndClient(ca, sa) else { return }
      let value: Any? = vp != 0
        ? Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(bitPattern: vp)!).takeUnretainedValue()
        : nil
      session.setValue(value, forTag: Int(tag), client: sender)
    }

    // ---- 視窗管理 ----

    /// 隱藏所有浮動視窗（候選窗、tooltip 等）。對應 `-[IMKInputController hidePalettes]`。
    IMKInputSessionController.configureHidingPallettes { sa in
      SessionControllerSputnik.session(forAddr: sa)?.hidePalettes()
    }
    /// 輸入控制器即將關閉時的清理。
    /// 對應 `-[IMKInputController inputControllerWillClose]`。
    IMKInputSessionController.configureInputControllerWillClose { sa in
      SessionControllerSputnik.session(forAddr: sa)?.inputControllerWillClose()
    }

    // ---- 選取範圍與選單 ----

    /// 向 IMK 提供當前選取範圍。對應 `-[IMKInputController selectionRange]`。
    IMKInputSessionController.configureProvidingSelectionRange { sa in
      SessionControllerSputnik.session(forAddr: sa)?.selectionRange() ?? .notFound
    }
    /// 向 IMK 提供輸入法選單。對應 `-[IMKInputController menu]`。
    IMKInputSessionController.configureProvidingIMEMenu { sa in
      guard let menuSputnik = IMEMenuSputnik(controllerAddr: sa) else { return NSMenu() }
      return menuSputnik.build()
    }
  }()

  /// 由 controller 記憶體位址查詢對應的 InputSession。
  private static func session(forAddr ctlAddr: UInt) -> InputSession? {
    guard let session = InputSession.session(for: ctlAddr) else { return nil }
    return session
  }

  /// 由 raw uintptr_t 位址解析 controller 與 client，傳回 (InputSession, IMKTextInput) 配對。
  /// 在解析前會透過 ObjCMemoryLeakTracker 複查 controller 是否仍存活，
  /// 防止 dangling pointer 被 takeUnretainedValue() 解讀導致 EXC_BAD_ACCESS。
  private static func controllerAndClient(_ ca: UInt, _ sa: UInt) -> (InputSession, any IMKTextInput)? {
    guard ObjCMemoryLeakTracker.shared.isTracked(addr: sa),
          let clientOpaque = UnsafeRawPointer(bitPattern: ca),
          let session = session(forAddr: sa) else { return nil }
    let sender = Unmanaged<AnyObject>.fromOpaque(clientOpaque).takeUnretainedValue()
    return (session, sender as! (any IMKTextInput))
  }
}
