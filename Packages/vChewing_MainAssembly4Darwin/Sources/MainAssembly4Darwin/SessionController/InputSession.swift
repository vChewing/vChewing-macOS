// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

// MARK: - InputSession

public final class InputSession: @MainActor SessionProtocol, Sendable {
  // MARK: Lifecycle

  public init(
    controller inputController: SessionCtl?,
    client inputClient: @escaping (() -> ClientObj?)
  ) {
    self.theClient = inputClient
    self.inputControllerAssigned = inputController
    construct(client: theClient())
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

  public var buzzer: (() -> ())? = IMEApp.buzz

  public var synchronizer4LMPrefs: (() -> ())? = { LMMgr.syncLMPrefs() }

  public var ui: (any SessionUIProtocol)? = SessionUI.shared

  public var prefs: any PrefMgrProtocol = PrefMgr.shared

  public private(set) lazy var sharedAlertForInputModeToggling: NSAlert = {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Target Input Mode Activation Required".i18n
    alert
      .informativeText =
      "You are proceeding to System Preferences to enable the Input Source which corresponds to the input mode you are going to switch to."
        .i18n
    alert.addButton(withTitle: "OK".i18n)
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

  public var theClient: () -> ClientObj?

  /// 用來標記當前副本是否已處於活動狀態。
  public var isActivated: Bool = false

  /// IMKInputController 副本。
  public weak var inputControllerAssigned: SessionCtl?

  public var inputController: SessionCtl? {
    inputControllerAssigned
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

  public func initInputHandler() {
    if let inputHandler {
      inputHandler.currentLM = inputMode.langModel
      inputHandler.prefs = PrefMgr.shared
      inputHandler.errorCallback = callError
      inputHandler.filterabilityChecker = LMMgr.isStateDataFilterableForMarked
      inputHandler.notificationCallback = Notifier.notify
      inputHandler.pomSaveCallback = { LMMgr.savePerceptionOverrideModelData(false) }
      inputHandler.assembler.maxSegLength = prefs.maxCandidateLength
      inputHandler.ensureKeyboardParser()
    } else {
      inputHandler = InputHandler(
        lm: inputMode.langModel,
        pref: PrefMgr.shared,
        errorCallback: callError,
        filterabilityChecker: LMMgr.isStateDataFilterableForMarked,
        notificationCallback: Notifier.notify,
        pomSaveCallback: { LMMgr.savePerceptionOverrideModelData(false) }
      )
    }
    inputHandler?.session = self
  }

  // MARK: Private

  private static var _current: InputSession?
}

extension InputSession {
  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體。
  public func activateServer(_ sender: Any!) {
    performServerActivation(client: sender as? ClientObj)
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public func deactivateServer(_ sender: Any!) {
    _ = sender
    performServerDeactivation()
  }

  public func value(forTag tag: Int, client sender: Any!) -> Any! {
    inputController?.value(forTag: tag, client: sender)
  }

  public func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
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

  public func modes(_ sender: Any!) -> [AnyHashable: Any]! {
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
  public func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .keyUp]
    return Int(events.rawValue)
  }

  public func showPreferences(_ sender: Any!) {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
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

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public func commitCompositionByOS(_ sender: Any!) {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    resetInputHandler()
    clearInlineDisplay()
  }

  public func updateComposition() {
    inputController?.updateComposition()
  }

  public func cancelComposition() {
    inputController?.cancelComposition()
  }

  /// 指定輸入法要遞交出去的內容（個別 IMKInputClient 會呼叫這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  public func composedString(_ sender: Any!) -> Any! {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    guard let inputHandler else { return "" }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool = state.type == .ofInputting
    if state.hasComposition {
      textToCommit = inputHandler
        .generateStateOfInputting(sansReading: sansReading)
        .displayedTextConverted
    }
    return textToCommit
  }

  public func selectionRange() -> NSRange {
    attributedStringSecured.range
  }

  public func replacementRange() -> NSRange {
    inputController?.replacementRange() ?? .init(location: NSNotFound, length: NSNotFound)
  }

  public func doCommand(by aSelector: Selector!, command infoDictionary: [AnyHashable: Any]!) {
    inputController?.doCommand(by: aSelector, command: infoDictionary)
  }

  public func hidePalettes() {
    Broadcaster.shared.postEventForClosingAllPanels()
  }

  public func menu() -> NSMenu! { inputController?.menu() }

  public func delegate() -> Any! { inputController?.delegate() }

  public func setDelegate(_ newDelegate: Any!) { inputController?.setDelegate(newDelegate) }

  public func server() -> IMKServer! { inputController?.server() }

  public func client() -> (any IMKTextInput & NSObjectProtocol)! {
    /// API 層面的驚嘆號是無法去掉的（否則 IMK 會出錯），那這裡就必須手動 unwrap 確保沒有把 nullptr 丟出去。
    inputController?.client() ?? theClient()
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  public func inputControllerWillClose() {
    // 防止尚未完成拼寫的注音內容被遞交出去。
    resetInputHandler()
  }

  public func annotationSelected(
    _ annotationString: NSAttributedString!,
    forCandidate candidateString: NSAttributedString!
  ) { inputController?.annotationSelected(annotationString, forCandidate: candidateString) }

  public func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
    inputController?.candidateSelectionChanged(candidateString)
  }

  public func candidateSelected(_ candidateString: NSAttributedString!) {
    inputController?.candidateSelected(candidateString)
  }

  public func compositionAttributes(at range: NSRange) -> NSMutableDictionary! {
    inputController?.compositionAttributes(at: range)
  }

  public func mark(forStyle style: Int, at range: NSRange) -> [AnyHashable: Any]! {
    inputController?.mark(forStyle: style, at: range)
  }
}
