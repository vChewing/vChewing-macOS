// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - ClientControllerAddrPair

public struct ClientControllerAddrPair: Sendable {
  // MARK: Lifecycle

  init(clientAddr: UInt, controllerAddr: UInt) {
    self._clientAddr = clientAddr
    self._controllerAddr = controllerAddr
  }

  init(_ pair: TupleExpr) {
    self._clientAddr = pair.clientAddr
    self._controllerAddr = pair.controllerAddr
  }

  // MARK: Internal

  typealias TupleExpr = (clientAddr: UInt, controllerAddr: UInt)

  let _clientAddr: UInt
  let _controllerAddr: UInt

  var unwrapped: TupleExpr? {
    if UserDefaults.pendingUnitTests {
      guard _controllerAddr == 0 else { return nil }
    } else {
      // Client 在 Controller 建構完畢之後才可用，
      // 但 Controller 被析構之後 Client Addr 必定是 dangling pointer。
      // 所以在此複查 Controller 的生命週期。
      guard IMKControllerLifetimeTracker.shared().isAddressAlive(_controllerAddr) else { return nil }
    }
    return (_clientAddr, _controllerAddr)
  }
}

// MARK: - InputSession

public final class InputSession: @MainActor SessionProtocol, Sendable {
  // MARK: Lifecycle

  public init(
    controller inputController: IMKInputSessionController?,
    clientAddr inputClientAddr: @escaping (() -> ClientControllerAddrPair?)
  ) {
    self.theClientAddr = inputClientAddr
    self.inputControllerAssignedAddr = theClientAddr()?.unwrapped?.controllerAddr
    if let controllerAddr = inputControllerAssignedAddr {
      Self.registerSessionAddr(self, for: controllerAddr)
    }
    construct(client: theClient())
    vCLog("InputSession constructed. ID: \(id.uuidString)")
  }

  /// 預配置 session（極性雙緩衝用）：不繫結任何 controller/client，僅初始化內部引擎。
  /// 後續經由 `reassign(to:clientAddrProvider:)` 與具體 controller 綁定。
  public init(preallocated: ()) {
    self.theClientAddr = { nil }
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

  public var clientObjectIdentifier: ObjectIdentifier?

  public var buzzer: (() -> ())? = { mainSync { IMEApp.buzz() } }

  public var synchronizer4LMPrefs: (() -> ())? = { LMMgr.syncLMPrefs() }

  public var ui: (any SessionUIProtocol)? = SessionUI.shared

  public var prefs: any PrefMgrProtocol = PrefMgr.shared

  public private(set) lazy var sharedAlertForInputModeToggling: NSAlert = {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "i18n:InputMode.TargetInputModeActivationRequired".i18n
    alert
      .informativeText =
      "i18n:InfoMessage.ProceedingToSystemPreferences".i18n
    alert.addButton(withTitle: "i18n:Common.OK".i18n)
    return alert
  }()

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

  public var theClientAddr: () -> ClientControllerAddrPair?

  /// 用來標記當前副本是否已處於活動狀態。
  public var isActivated: Bool = false

  /// 上次實際套用至 client 的鍵盤佈局名稱，用以跳過重複的 overrideKeyboard() 呼叫。
  public var lastAppliedKeyboardLayout: String?

  /// IMKInputController 副本（記憶體位址）。
  public nonisolated(unsafe) var inputControllerAssignedAddr: UInt?

  public var inputController: IMKInputSessionController? {
    guard let addr = inputControllerAssignedAddr,
          IMKControllerLifetimeTracker.shared().isAddressAlive(addr),
          let opaque = UnsafeRawPointer(bitPattern: addr)
    else { return nil }
    return Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
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
  public var inputMode: Shared.InputMode = .imeModeNULL {
    willSet {
      /// 將新的簡繁輸入模式提報給 Prefs 模組。IMEApp 模組會據此計算正確的資料值。
      prefs.mostRecentInputMode = newValue.rawValue
    }
    didSet {
      /// SQLite 資料庫是在 AppDelegate 階段就載入的，所以這裡不需要再 Lazy-Load。
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

  public func theClient() -> ClientObj? {
    guard let addrPair = theClientAddr()?.unwrapped else { return nil }
    if let opaque = UnsafeRawPointer(bitPattern: addrPair.clientAddr) {
      return Unmanaged<ClientObj>.fromOpaque(opaque).takeUnretainedValue()
    }
    return nil
  }

  public func initInputHandler() {
    if let inputHandler {
      inputHandler.currentLM = inputMode.langModel
      inputHandler.prefs = PrefMgr.shared
      inputHandler.errorCallback = { [weak self] msg in self?.callError(msg) }
      inputHandler.filterabilityChecker = LMMgr.isStateDataFilterableForMarked
      inputHandler.notificationCallback = Notifier.notify
      inputHandler.pomSaveCallback = { LMMgr.savePerceptionOverrideModelData(false) }
      inputHandler.assembler.maxSegLength = prefs.maxCandidateLength
      inputHandler.ensureKeyboardParser()
    } else {
      inputHandler = InputHandler(
        lm: inputMode.langModel,
        pref: PrefMgr.shared,
        errorCallback: { [weak self] msg in self?.callError(msg) },
        filterabilityChecker: LMMgr.isStateDataFilterableForMarked,
        notificationCallback: Notifier.notify,
        pomSaveCallback: { LMMgr.savePerceptionOverrideModelData(false) }
      )
    }
    inputHandler?.markingTooltipGenerator = { state in
      let result = IMEStateParsed4Darwin(state).generateTooltipForMarking()
      var colorState = result.colorState
      var tooltip = result.tooltip
      if PrefMgr.shared.phraseReplacementEnabled {
        colorState = .warning
        tooltip += "\n" + "i18n:PhraseOperation.PhraseReplacementInterfering".i18n
      }
      return (tooltip, colorState)
    }
    inputHandler?.session = self
  }

  // MARK: Internal

  // MARK: - 極性雙緩衝 Session 池

  /// 偶數 generation controller 專用 session。
  @MainActor
  static let sessionEven = InputSession(preallocated: ())
  /// 奇數 generation controller 專用 session。
  @MainActor
  static let sessionOdd = InputSession(preallocated: ())

  /// 從 controller 位址查詢對應的 InputSession。
  static func session(for controllerAddr: UInt) -> InputSession? {
    let testPair = ClientControllerAddrPair(clientAddr: 0, controllerAddr: controllerAddr)
    guard let ctlKey = testPair.unwrapped?.controllerAddr else { return nil }
    guard let ssnAddr = sessionAddrByControllerAddr.withLockRead({ $0[ctlKey] }),
          let opaque = UnsafeRawPointer(bitPattern: ssnAddr)
    else { return nil }
    return Unmanaged<InputSession>.fromOpaque(opaque).takeUnretainedValue()
  }

  /// 登記 controller → session 對照關係。
  static func registerSessionAddr(_ session: InputSession, for controllerAddr: UInt) {
    let ssnKey = UInt(bitPattern: Unmanaged.passUnretained(session).toOpaque())
    sessionAddrByControllerAddr.withLock { $0[controllerAddr] = ssnKey }
  }

  /// 以純記憶體位址移除 controller 對照關係（供 `onDealloc` block 使用，避免捕獲 self）。
  static func unregisterSessionAddr(forControllerAddr ctlKey: UInt) {
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
  static func session(forParity parity: Int) -> InputSession {
    (parity & 1) == 0 ? sessionEven : sessionOdd
  }

  /// 重新綁定至新的 IMKInputSessionController。
  /// 更新 controller→session 對照表並清理舊 controller 的殘留 mapping。
  func reassign(
    to controller: IMKInputSessionController,
    clientAddrProvider: @escaping () -> ClientControllerAddrPair?
  ) {
    let oldAddr = inputControllerAssignedAddr
    let newAddr = UInt(bitPattern: Unmanaged.passUnretained(controller).toOpaque())
    inputControllerAssignedAddr = newAddr
    theClientAddr = clientAddrProvider
    if let oldAddr {
      Self.sessionAddrByControllerAddr.withLock { $0[oldAddr] = nil }
    }
    Self.registerSessionAddr(self, for: newAddr)
  }

  // MARK: Private

  private static var _current: InputSession?

  // MARK: - Controller ↔ Session 對照表

  /// 以 controller NSObject 的記憶體位址整數值為鍵的對照字典。
  /// 資料值是 Session 的記憶體位址。
  /// - Note: Session 的記憶體位址必須在其生命週期有效期間內確保有效。
  ///   此處不保留強引用，避免靜態字典參與 ARC。
  private nonisolated(unsafe) static var sessionAddrByControllerAddr = NSMutex([UInt: UInt]())
}

extension InputSession {
  // MARK: - IMKStateSetting surface

  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體。
  public func activateServer(_ sender: any IMKTextInput) {
    performServerActivation(client: sender as? ClientObj)
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public func deactivateServer(_ sender: any IMKTextInput) {
    performServerDeactivation()
  }

  public func value(forTag tag: Int, client sender: any IMKTextInput) -> Any? {
    inputController?.value(forTag: tag, client: sender)
  }

  public func setValue(_ value: Any?, forTag tag: Int, client sender: any IMKTextInput) {
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

  public func modes(_ sender: any IMKTextInput) -> [AnyHashable: Any]? {
    inputController?.modes(sender)
  }

  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  public func recognizedEvents(_ sender: any IMKTextInput) -> UInt {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .keyUp]
    return UInt(events.rawValue)
  }

  public func showPreferences(_ sender: (any IMKTextInput)?) {
    osCheck: if #available(macOS 14, *) {
      switch NSEvent.keyModifierFlags {
      case .option: break osCheck
      default: CtlSettingsUI.show()
      }
      NSApp.popup()
      return
    }
    CtlSettingsCocoa.show()
    NSApp.popup()
  }

  // MARK: - IMKInputController surface

  public func updateComposition() {
    inputController?.updateComposition()
  }

  public func cancelComposition() {
    inputController?.cancelComposition()
  }

  public func compositionAttributes(at range: NSRange) -> NSMutableDictionary {
    inputController?.compositionAttributes(at: range) ?? .init()
  }

  public func selectionRange() -> NSRange {
    attributedStringSecured.range
  }

  public func replacementRange() -> NSRange {
    inputController?.replacementRange() ?? .init(location: NSNotFound, length: NSNotFound)
  }

  public func mark(forStyle style: Int, at range: NSRange) -> [AnyHashable: Any] {
    inputController?.mark(forStyle: style, at: range) ?? [:]
  }

  public func doCommand(by aSelector: Selector, command infoDictionary: [AnyHashable: Any]) {
    inputController?.doCommand(by: aSelector, command: infoDictionary)
  }

  public func hidePalettes() {
    asyncOnMain {
      Broadcaster.shared.postEventForClosingAllPanels()
    }
  }

  public func menu() -> NSMenu? { inputController?.menu() }

  public func delegate() -> Any? { inputController?.delegate() }

  public func setDelegate(_ newDelegate: Any?) { inputController?.setDelegate(newDelegate) }

  public func server() -> IMKServer { inputController!.server() }

  public func client() -> (any IMKTextInput)? {
    inputController?.client() ?? theClient()
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  public func inputControllerWillClose() {
    // 防止尚未完成拼寫的注音內容被遞交出去。
    resetInputHandler()
  }

  public func annotationSelected(
    _ annotationString: NSAttributedString?,
    forCandidate candidateString: NSAttributedString?
  ) { inputController?.annotationSelected(annotationString, forCandidate: candidateString) }

  public func candidateSelectionChanged(_ candidateString: NSAttributedString?) {
    inputController?.candidateSelectionChanged(candidateString)
  }

  public func candidateSelected(_ candidateString: NSAttributedString?) {
    inputController?.candidateSelected(candidateString)
  }

  // MARK: - IMKMouseHandling surface

  public func mouseDown(
    onCharacterIndex index: UInt, coordinate point: NSPoint,
    withModifier flags: UInt,
    continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>,
    client sender: any IMKTextInput
  )
    -> Bool { false }

  public func mouseUp(
    onCharacterIndex index: UInt, coordinate point: NSPoint,
    withModifier flags: UInt, client sender: any IMKTextInput
  )
    -> Bool { false }

  public func mouseMoved(
    onCharacterIndex index: UInt, coordinate point: NSPoint,
    withModifier flags: UInt, client sender: any IMKTextInput
  )
    -> Bool { false }

  // MARK: - IMKServerInput surface

  public func inputText(
    _ string: String, key keyCode: Int,
    modifiers flags: UInt, client sender: any IMKTextInput
  )
    -> Bool { false }

  public func inputText(_ string: String, client sender: any IMKTextInput) -> Bool { false }

  public func handle(_ event: NSEvent?, client sender: any IMKTextInput) -> Bool {
    handleNSEvent(event, client: sender)
  }

  public func didCommand(by aSelector: Selector, client sender: any IMKTextInput) -> Bool { false }

  /// 指定輸入法要遞交出去的內容（個別 IMKInputClient 會呼叫這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  public func composedString(_ sender: any IMKTextInput) -> Any? {
    guard let inputHandler else { return "" }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool = state.type == .ofInputting
    if state.hasComposition {
      textToCommit = IMEStateParsed4Darwin(
        inputHandler
          .generateStateOfInputting(sansReading: sansReading)
      ).displayedTextConverted
    }
    return textToCommit
  }

  public func originalString(_ sender: any IMKTextInput) -> NSAttributedString? { nil }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public func commitComposition(_ sender: any IMKTextInput) {
    resetInputHandler()
    clearInlineDisplay()
  }

  public func candidates(_ sender: any IMKTextInput) -> [Any]? { nil }
}
