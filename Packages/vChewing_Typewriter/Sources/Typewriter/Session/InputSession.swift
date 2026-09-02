// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - InputSession

public final class InputSession: @MainActor SessionProtocol, Sendable {
  // MARK: Lifecycle

  /// 預配置 session（極性雙緩衝用）：不繫結任何 controller/client，僅初始化內部引擎。
  /// 後續經由 `reassign(toAddr:)` 與具體 controller 綁定。
  public init(
    preallocated: (),
    manuallyAssignedClientProxy: (any SessionClientProxy)? = nil,
    controllerAddr: UInt? = nil
  ) {
    if let controllerAddr {
      self.inputControllerAssignedAddr = controllerAddr
      Self.registerSessionAddr(self, for: controllerAddr)
    }
    if let manuallyAssignedClientProxy {
      let obj = manuallyAssignedClientProxy as AnyObject
      let controllerAddr = UInt(bitPattern: Unmanaged.passUnretained(obj).toOpaque())
      self.inputControllerAssignedAddr = controllerAddr
      Self.registerSessionAddr(self, for: controllerAddr)
      construct(clientProxy: manuallyAssignedClientProxy)
    }
    initInputHandler()
    synchronizer4LMPrefs?()
    self.inputMode = .init(rawValue: prefs.mostRecentInputMode) ?? .imeModeNULL
    vCLog("InputSession preallocated. ID: \(id.uuidString)")
  }

  nonisolated deinit {
    vCLog("InputSession deconstructing. ID: \(id.uuidString)")
  }

  // MARK: Public

  public typealias State = IMEState
  public typealias Handler = InputHandler

  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  public static var areWeNerfing: Bool = false

  /// 給所有副本共用的 isASCIIMode 追蹤用餐數。
  public static var isASCIIModeForAllClients = false
  /// 一個共用辭典，專門用來給每個副本用的 isASCIIMode 追蹤用餐數。
  public static var isASCIIModeForEachClient: [String: Bool] = [:]

  // MARK: - 極性雙緩衝 Session 池

  /// 偶數 generation controller 專用 session。
  public static let sessionEven = InputSession(preallocated: ())
  /// 奇數 generation controller 專用 session。
  public static let sessionOdd = InputSession(preallocated: ())

  public static var current: InputSession? {
    get { _current }
    set { _current = newValue }
  }

  /// 用以記錄最近存取過的十個客體（亂序），相關內容會在客體管理器當中用得到。
  public static var recentClientBundleIdentifiers = [String: Int]() {
    didSet {
      if recentClientBundleIdentifiers.count < 20 { return }
      if recentClientBundleIdentifiers.isEmpty { return }
      let x = recentClientBundleIdentifiers.sorted(by: { $0.value < $1.value }).first?.key
      guard let x = x else { return }
      recentClientBundleIdentifiers[x] = nil
    }
  }

  public let id: UUID = .init()

  public var clientProxyObjectIdentifier: ObjectIdentifier?

  public var buzzer: (() -> ())? = { mainSync { SessionHost.shared.buzz() } }

  public var synchronizer4LMPrefs: (() -> ())? = { SessionHost.shared.syncLMPrefs() }

  public var trieCacheFlushHandler: (() -> ())? = { SessionHost.shared.flushTrieCaches() }

  public var ui: (any SessionUIProtocol)? = SessionHost.shared.ui()

  public var prefs: any PrefMgrProtocol = SessionHost.shared.prefs()

  /// 上一個被處理過的鍵盤事件。
  public var previouslyHandledEvents = [KBEvent]()

  /// 當前副本的客體是否是輸入法本體？
  public var isServingIMEItself: Bool = false

  /// 輸入調度模組的副本。
  public var inputHandler: Handler?

  /// 最近一個被 set 的 marked text。
  public var recentMarkedText: (text: NSAttributedString?, selectionRange: NSRange?) = (nil, nil)

  /// 當前客體應用是否採用 Web 技術構築（例：Electron）。
  public var isClientElectronBased = false

  public var isVerticalTyping: Bool = false

  /// 用來標記當前副本是否已處於活動狀態。
  public var isActivated: Bool = false

  /// 上次實際套用至 client 的鍵盤佈局名稱，用以跳過重複的 overrideKeyboard() 呼叫。
  public var lastAppliedKeyboardLayout: String?

  /// IMKInputController 副本（記憶體位址）。
  public nonisolated(unsafe) var inputControllerAssignedAddr: UInt?

  /// 宿主可注入的 replacementRange 提供器（Darwin 端會綁定至 IMK controller）。
  public var replacementRangeProvider: () -> NSRange = {
    .init(location: NSNotFound, length: NSNotFound)
  }

  /// 用以透過 ObjC proxy 安全存取 IMKTextInput（避免 Swift ARC 干擾 IMKTextInput Client 物件）。
  /// 生產環境：從 `inputControllerAssignedAddr` 解析 IMKInputSessionController；
  /// 測試環境：從 `manuallyAssignedClientProxy` 解析 FakeClient。
  public var clientProxy: (any SessionClientProxy)? {
    guard let addr = inputControllerAssignedAddr,
          let opaque = UnsafeRawPointer(bitPattern: addr)
    else { return nil }
    if !UserDefaults.pendingUnitTests {
      guard SessionHost.shared.isControllerAddressAlive(addr) else { return nil }
    }
    let obj = Unmanaged<AnyObject>.fromOpaque(opaque).takeUnretainedValue()
    return obj as? any SessionClientProxy
  }

  /// 用以存儲客體的 bundleIdentifier。
  /// 由於每次動態獲取都會耗時，所以這裡直接靜態記載之。
  public var clientBundleIdentifier: String = "" {
    willSet {
      if newValue.isEmpty { return }
      Self.recentClientBundleIdentifiers[newValue] = Int(Date().timeIntervalSince1970)
    }
  }

  /// 用以記錄當前輸入法狀態的變數。
  public var state: State = .ofEmpty() {
    didSet {
      guard oldValue.type != state.type else { return }
      if prefs.isDebugModeEnabled {
        var stateDescription = state.type.rawValue
        if state.type == .ofCommitting { stateDescription += "(\(state.textToCommit))" }
        vCLog("Current State: \(stateDescription), client: \(clientBundleIdentifier)")
      }
      // 因鍵盤訊號翻譯機制存在，故禁用下文。
      // guard state.isCandidateContainer != oldValue.isCandidateContainer else { return }
      // if state.isCandidateContainer || oldValue.isCandidateContainer { setKeyLayout() }
    }
  }

  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  ///
  /// 在 parity 雙緩衝 singleton pair 體制下，兩個 Session 實例共用同一個 `prefs` 引用。
  /// `willSet` 將新模式寫入 `prefs.mostRecentInputMode`（全局唯一），另一方在
  /// `performServerActivation()` 啟動時自動從 `IMEApp.currentInputMode` 同步，
  /// 確保簡繁模式在雙極性 Session 之間一致。
  public var inputMode: Shared.InputMode = .imeModeNULL {
    willSet {
      /// 將新的簡繁輸入模式提報給 Prefs 模組。IMEApp 模組會據此計算正確的資料值。
      prefs.mostRecentInputMode = newValue.rawValue
    }
    didSet {
      /// 原廠辭典（TextMap）在 AppDelegate 階段就已初始化，此處無需 lazy-load。
      if oldValue != inputMode, inputMode != .imeModeNULL {
        /// 先重置輸入調度模組，不然會因為之後的命令而導致該命令無法正常執行。
        resetInputHandler()
        // ----------------------------
        /// 重設所有語言模組。這裡不需要做按需重設，因為對運算量沒有影響。
        inputHandler?.currentLM = inputMode.langModel // 會自動更新組字引擎內的模組。
        /// 清空注拼槽＋同步最新的注拼槽排列設定。
        inputHandler?.ensureKeyboardParser()
        /// 將輸入法偏好設定同步至語言模組內。
        synchronizer4LMPrefs?()
      }
    }
  }

  /// 從 controller 位址查詢對應的 InputSession。
  public static func session(for controllerAddr: UInt) -> InputSession? {
    if UserDefaults.pendingUnitTests {
      guard controllerAddr == 0 else { return nil }
    } else {
      guard SessionHost.shared.isControllerAddressAlive(controllerAddr) else { return nil }
    }
    guard let ssnAddr = sessionAddrByControllerAddr.withLockRead({ $0[controllerAddr] }),
          let opaque = UnsafeRawPointer(bitPattern: ssnAddr)
    else { return nil }
    return Unmanaged<InputSession>.fromOpaque(opaque).takeUnretainedValue()
  }

  /// 登記 controller → session 對照關係。
  public static func registerSessionAddr(_ session: InputSession, for controllerAddr: UInt) {
    let ssnKey = UInt(bitPattern: Unmanaged.passUnretained(session).toOpaque())
    sessionAddrByControllerAddr.withLock { $0[controllerAddr] = ssnKey }
  }

  /// 以純記憶體位址移除 controller 對照關係（供 `onDealloc` block 使用，避免捕獲 self）。
  public static func unregisterSessionAddr(forControllerAddr ctlKey: UInt) {
    sessionAddrByControllerAddr.withLock { map in
      guard let ssnKey = map[ctlKey],
            let opaque = UnsafeRawPointer(bitPattern: ssnKey) else { return }
      map[ctlKey] = nil
      let session = Unmanaged<InputSession>.fromOpaque(opaque).takeUnretainedValue()
      // 僅在 session 仍屬於該 controller 時才清空 inputControllerAssignedAddr。
      // reassign 後 session 已歸新 controller 所有，舊 controller 的 dealloc 不應干擾。
      if session.inputControllerAssignedAddr == ctlKey {
        session.inputControllerAssignedAddr = nil
      }
    }
  }

  /// 以 generation parity 查詢對應的 InputSession singleton。
  public static func session(forParity parity: Int) -> InputSession {
    (parity & 1) == 0 ? sessionEven : sessionOdd
  }

  public func initInputHandler() {
    if let inputHandler {
      inputHandler.currentLM = inputMode.langModel
      inputHandler.prefs = SessionHost.shared.prefs()
      inputHandler.errorCallback = { [weak self] msg in self?.callError(msg) }
      inputHandler.filterabilityChecker = SessionHost.shared.isStateDataFilterableForMarked
      inputHandler.notificationCallback = SessionHost.shared.notify
      inputHandler.pomSaveCallback = { SessionHost.shared.savePerceptionOverrideModelData() }
      inputHandler.assembler.maxSegLength = prefs.maxCandidateLength
      inputHandler.ensureKeyboardParser()
    } else {
      inputHandler = InputHandler(
        lm: inputMode.langModel,
        pref: SessionHost.shared.prefs(),
        errorCallback: { [weak self] msg in self?.callError(msg) },
        filterabilityChecker: SessionHost.shared.isStateDataFilterableForMarked,
        notificationCallback: SessionHost.shared.notify,
        pomSaveCallback: { SessionHost.shared.savePerceptionOverrideModelData() }
      )
    }
    inputHandler?.markingTooltipGenerator = { state in
      let result = IMEStateParsed(state).generateTooltipForMarking()
      var colorState = result.colorState
      var tooltip = result.tooltip
      if SessionHost.shared.prefs().phraseReplacementEnabled {
        colorState = .warning
        tooltip += "\n" + "i18n:PhraseOperation.PhraseReplacementInterfering".i18n
      }
      return (tooltip, colorState)
    }
    inputHandler?.session = self
  }

  /// 重新綁定至新的 controller 位址。
  /// 更新 controller→session 對照表並清理舊 controller 的殘留 mapping。
  public func reassign(toAddr newAddr: UInt) {
    let oldAddr = inputControllerAssignedAddr
    inputControllerAssignedAddr = newAddr
    if let oldAddr {
      Self.sessionAddrByControllerAddr.withLock { $0[oldAddr] = nil }
    }
    Self.registerSessionAddr(self, for: newAddr)
  }

  public func hidePalettes() {
    asyncOnMain {
      SessionHost.shared.postEventForClosingAllPanels()
    }
  }

  public func replacementRange() -> NSRange {
    replacementRangeProvider()
  }

  public func setValue(_ value: Any?, forTag tag: Int) {
    if isCurrentSession {
      hidePalettes()
    }
    let newMode: Shared.InputMode = .init(
      rawValue: value as? String ?? prefs.mostRecentInputMode
    ) ?? .imeModeNULL
    if inputMode != newMode {
      inputMode = newMode
    }
  }

  public func selectionRange() -> NSRange {
    attributedStringSecured.range
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  public func inputControllerWillClose() {
    // 防止尚未完成拼寫的注音內容被遞交出去。
    resetInputHandler()
  }

  /// 指定輸入法要遞交出去的內容（個別 IMKInputClient 會呼叫這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  public func composedString() -> Any? {
    guard let inputHandler else { return "" }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool = state.type == .ofInputting
    if state.hasComposition {
      textToCommit = IMEStateParsed(
        inputHandler
          .generateStateOfInputting(sansReading: sansReading)
      ).displayedTextConverted
    }
    return textToCommit
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public func commitComposition() {
    resetInputHandler()
    clearInlineDisplay()
  }

  // MARK: Private

  private static var _current: InputSession?

  /// 以 controller NSObject 的記憶體位址整數值為鍵的對照字典。
  /// 資料值是 Session 的記憶體位址。
  /// - Note: Session 的記憶體位址必須在其生命週期有效期間內確保有效。
  ///   此處不保留強引用，避免靜態字典參與 ARC。
  private nonisolated(unsafe) static var sessionAddrByControllerAddr = NSMutex([UInt: UInt]())
}
