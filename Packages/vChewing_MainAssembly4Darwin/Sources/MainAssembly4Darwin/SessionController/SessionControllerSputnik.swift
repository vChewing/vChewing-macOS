// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - SessionControllerSputnik

public struct SessionControllerSputnik {
  // MARK: Lifecycle

  public init?(controllerAddr: UInt?) {
    guard let controllerAddr else { return nil }
    self.controllerSentinel = ControllerAddrSentinel(addr: controllerAddr)
  }

  // MARK: Public

  public var core: InputSession? {
    guard let controllerAddr = controllerSentinel.unwrapped else { return nil }
    let parity = Int(IMKControllerLifetimeTracker.shared().generation(forAddress: controllerAddr) & 1)
    let session = InputSession.session(forParity: parity)
    // 若 session 尚未被任何 controller 佔用（preallocated 狀態），走完整初始化。
    guard session.inputControllerAssignedAddr != nil else {
      guard let opaque = UnsafeRawPointer(bitPattern: controllerAddr) else { return nil }
      let controller = Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
      let newValue = Self.callCoreAtLeastOnce(controller)
      replaceCore(newValue)
      return newValue
    }
    return session
  }

  public static func injectPostConstructionHandler() {
    _ = _installConstructorHook
    _ = _configureClassLevelBlocks
  }

  /// 以 generation parity 從雙緩衝池中選取 InputSession singleton 並完成 reassign。
  public static func callCoreAtLeastOnce(_ controller: IMKInputSessionController) -> InputSession {
    let parity = Int(IMKInputSessionController.currentGeneration() & 1)
    let session = InputSession.session(forParity: parity)
    session.reassign(to: controller)
    session.state = IMEState.ofEmpty()
    session.resetInputHandler()
    InputSession.current = session
    return session
  }

  public func replaceCore(_ newCore: InputSession?) {
    if let session = newCore, let controllerAddr = controllerSentinel.unwrapped {
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
      instance, _, _, _, _ in
      let ctl = instance as? IMKInputSessionController
      guard let ctl else { return }
      // IMKInputSessionController.initWithServer: 已自動透過 IMKControllerLifetimeTracker
      // 完成追蹤登記與 generation 分配，無需手動呼叫 track。
      let controllerAddr = UInt(bitPattern: Unmanaged.passUnretained(ctl).toOpaque())
      if let sputnik = Self(controllerAddr: controllerAddr) {
        sputnik.replaceCore(Self.callCoreAtLeastOnce(ctl))
      }
    }
    class_addMethod(IMKInputSessionController.self, sel, imp_implementationWithBlock(block), "v@:@@@")
  }()

  private let controllerSentinel: ControllerAddrSentinel
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
    /// - Warning: 必須在 resolve session 之前，將 session 的
    ///   inputControllerAssignedAddr 設為實際觸發 activateServer 的 controller 位址。
    ///   極性雙緩衝模式下，同一奇偶性的 session 可能已被其他 controller 的
    ///   callCoreAtLeastOnce reassign，導致 client() 解讀透過舊 controller 回傳 nil，
    ///   使 doCommit / doSetMarkedText 靜默失效。
    IMKInputSessionController.configureActivatingServer { ctlAddr in
      guard let session = SessionControllerSputnik.session(forAddr: ctlAddr) else { return }
      session.inputControllerAssignedAddr = ctlAddr
      session.performServerActivation()
    }
    /// 停用輸入法時，IMK 呼叫此方法。對應 `-[IMKInputController deactivateServer:]`。
    IMKInputSessionController.configureDeactivatingServer { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.performServerDeactivation()
    }
    /// Controller 被釋放時的最終清理。對應 `-[IMKInputController dealloc]`。
    IMKInputSessionController.configureDealloc { ctlAddr in
      InputSession.unregisterSessionAddr(forControllerAddr: ctlAddr)
    }

    // ---- 偏好設定 ----

    /// 顯示輸入法偏好設定視窗。對應 `-[IMKInputController showPreferences:]`。
    IMKInputSessionController.configureShowingPreferences { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.showPreferences()
    }

    // ---- 組字內容 ----

    /// 自動提交當前組字內容（例如使用者在組字中途切換焦點時）。
    /// 對應 `-[IMKInputController commitComposition:]`。
    IMKInputSessionController.configureAutoCommittingComposition { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.commitComposition()
    }
    /// 向 IMK 提供當前組字緩衝區的 NSAttributedString。
    /// 對應 `-[IMKInputController composedString:]`。
    IMKInputSessionController.configureProvidingComposedString { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.composedString()
    }

    // ---- 鍵盤事件處理 ----

    /// 登記此輸入法能處理的 NSEventType 遮罩。
    /// 對應 `-[IMKInputController recognizedEvents:]`。
    IMKInputSessionController.configureProvidingRecognizedEvents { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.recognizedEvents() ?? 0
    }
    /// 處理來自 IMK 的鍵盤／滑鼠事件。此為輸入法最核心的 dispatch 路徑。
    /// 對應 `-[IMKInputController handleEvent:client:]`。
    IMKInputSessionController.configureHandlingGivenNullableEvent { evPtr, ctlAddr in
      guard let session = SessionControllerSputnik.session(forAddr: ctlAddr) else { return false }
      let event: NSEvent? = evPtr != 0
        ? Unmanaged<NSEvent>.fromOpaque(UnsafeRawPointer(bitPattern: evPtr)!).takeUnretainedValue()
        : nil
      let result = session.handleNSEvent(event)
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
    IMKInputSessionController.configureSettingObjCValue { vp, tag, ctlAddr in
      guard let session = SessionControllerSputnik.session(forAddr: ctlAddr) else { return }
      let value: Any? = vp != 0
        ? Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(bitPattern: vp)!).takeUnretainedValue()
        : nil
      session.setValue(value, forTag: Int(tag))
    }

    // ---- 視窗管理 ----

    /// 隱藏所有浮動視窗（候選窗、tooltip 等）。對應 `-[IMKInputController hidePalettes]`。
    IMKInputSessionController.configureHidingPallettes { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.hidePalettes()
    }
    /// 輸入控制器即將關閉時的清理。
    /// 對應 `-[IMKInputController inputControllerWillClose]`。
    IMKInputSessionController.configureInputControllerWillClose { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.inputControllerWillClose()
    }

    // ---- 選取範圍與選單 ----

    /// 向 IMK 提供當前選取範圍。對應 `-[IMKInputController selectionRange]`。
    IMKInputSessionController.configureProvidingSelectionRange { ctlAddr in
      SessionControllerSputnik.session(forAddr: ctlAddr)?.selectionRange() ?? .notFound
    }
    /// 向 IMK 提供輸入法選單。對應 `-[IMKInputController menu]`。
    IMKInputSessionController.configureProvidingIMEMenu { ctlAddr in
      guard let menuSputnik = IMEMenuSputnik(controllerAddr: ctlAddr) else { return NSMenu() }
      return menuSputnik.build()
    }
  }()

  /// 由 controller 記憶體位址查詢對應的 InputSession（以 parity routing 決定）。
  /// Class-level blocks 統一走 parity 路徑，避免與 `sessionAddrByControllerAddr`
  /// 產生 split-brain：同一枚 parity session 被新 controller reassign 後，
  /// 舊 controller 的事件應仍路由至同一枚 session（而非因 address mapping 被清空而掉事件）。
  ///
  /// 若 controller 未被 tracker 登記（例如已 dealloc 後仍收到 IMK callback），回傳 nil。
  private static func session(forAddr ctlAddr: UInt) -> InputSession? {
    guard IMKControllerLifetimeTracker.shared().isAddressAlive(ctlAddr) else { return nil }
    let parity = Int(IMKControllerLifetimeTracker.shared().generation(forAddress: ctlAddr) & 1)
    return InputSession.session(forParity: parity)
  }
}
