// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CandidateWindow
import CocoaExtension
import IMKUtils
import PopupCompositionBuffer
import Shared
import ShiftKeyUpChecker
import TooltipUI

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(SessionCtl)  // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
public class SessionCtl: IMKInputController {
  public static var allInstances: Set<SessionCtl> = .init()

  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  public static var areWeNerfing = false

  /// 目前在用的的選字窗副本。
  public var ctlCandidateCurrent: CtlCandidateProtocol = {
    let direction: NSUserInterfaceLayoutOrientation =
      PrefMgr.shared.useHorizontalCandidateList ? .horizontal : .vertical
    if #available(macOS 10.15, *) {
      return PrefMgr.shared.useIMKCandidateWindow
        ? CtlCandidateIMK(direction) : CtlCandidateTDK(direction)
    } else {
      return CtlCandidateIMK(direction)
    }
  }()

  /// 工具提示視窗的副本。
  public var tooltipInstance = TooltipUI()

  /// 浮動組字窗的副本。
  public var popupCompositionBuffer = PopupCompositionBuffer()

  // MARK: -

  /// 當前 Caps Lock 按鍵是否被摁下。
  public var isCapsLocked: Bool { NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) }

  /// 當前這個 SessionCtl 副本是否處於英數輸入模式。
  public var isASCIIMode = false {
    didSet {
      resetInputHandler()
      setKeyLayout()
    }
  }

  /// 按鍵調度模組的副本。
  var inputHandler = InputHandler(lm: LMMgr.currentLM(), uom: LMMgr.currentUOM(), pref: PrefMgr.shared)
  /// 用以記錄當前輸入法狀態的變數。
  public var state: IMEStateProtocol = IMEState.ofEmpty() {
    didSet {
      guard oldValue.type != state.type else { return }
      vCLog("Current State: \(state.type.rawValue), client: \(clientBundleIdentifier)")
      // 因鍵盤訊號翻譯機制存在，故禁用下文。
      // guard state.isCandidateContainer != oldValue.isCandidateContainer else { return }
      // if state.isCandidateContainer || oldValue.isCandidateContainer { setKeyLayout() }
    }
  }

  /// Shift 按鍵事件分析器的副本。
  /// - Remark: 警告：該工具必須為 Struct 且全專案只能有一個唯一初期化副本。否則會在動 Caps Lock 的時候誤以為是在摁 Shift。
  public static var theShiftKeyDetector = ShiftKeyUpChecker(
    useLShift: PrefMgr.shared.togglingAlphanumericalModeWithLShift)

  /// `handle(event:)` 會利用這個參數判定某次 Shift 按鍵是否用來切換中英文輸入。
  public var rencentKeyHandledByInputHandlerEtc = false

  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  public static var isVerticalTyping: Bool = false
  public var isVerticalTyping: Bool {
    guard let client = client() else { return false }
    var textFrame = NSRect.seniorTheBeast
    let attributes: [AnyHashable: Any]? = client.attributes(
      forCharacterIndex: 0, lineHeightRectangle: &textFrame
    )
    let result = (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false
    Self.isVerticalTyping = result
    return result
  }

  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  public var inputMode: Shared.InputMode = IMEApp.currentInputMode {
    willSet {
      /// 將新的簡繁輸入模式提報給 Prefs 模組。IMEApp 模組會據此計算正確的資料值。
      PrefMgr.shared.mostRecentInputMode = newValue.rawValue
    }
    didSet {
      if oldValue != inputMode, inputMode != .imeModeNULL {
        UserDefaults.standard.synchronize()
        inputHandler.clear()  // 這句不要砍，因為後面 handle State.Empty() 不一定執行。
        // ----------------------------
        /// 重設所有語言模組。這裡不需要做按需重設，因為對運算量沒有影響。
        inputHandler.currentLM = LMMgr.currentLM()  // 會自動更新組字引擎內的模組。
        inputHandler.currentUOM = LMMgr.currentUOM()
        /// 清空注拼槽＋同步最新的注拼槽排列設定。
        inputHandler.ensureKeyboardParser()
        /// 將輸入法偏好設定同步至語言模組內。
        syncBaseLMPrefs()
        // ----------------------------
        Self.isVerticalTyping = isVerticalTyping
        // 強制重設當前鍵盤佈局、使其與偏好設定同步。這裡的這一步也不能省略。
        handle(state: IMEState.ofEmpty())
      }
    }
  }

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override public init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    inputHandler.delegate = self
    syncBaseLMPrefs()
    // 下述部分很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    activateServer(inputClient)
    if PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModel(IMEApp.currentInputMode) }
    if let myID = Bundle.main.bundleIdentifier, !myID.isEmpty, !clientBundleIdentifier.contains(myID) {
      setKeyLayout()
    }
  }
}

// MARK: - 工具函式

extension SessionCtl {
  /// 指定鍵盤佈局。
  public func setKeyLayout() {
    guard let client = client() else { return }

    func doSetKeyLayout() {
      if isASCIIMode, IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
        client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.alphanumericalKeyboardLayout)
        return
      }
      client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.basicKeyboardLayout)
    }

    DispatchQueue.main.async {
      doSetKeyLayout()
    }
  }

  /// 重設按鍵調度模組，會將當前尚未遞交的內容遞交出去。
  public func resetInputHandler() {
    // 過濾掉尚未完成拼寫的注音。
    if state.type == .ofInputting, PrefMgr.shared.trimUnfinishedReadingsOnCommit {
      inputHandler.composer.clear()
      handle(state: inputHandler.generateStateOfInputting())
    }
    let isSecureMode = PrefMgr.shared.clientsIMKTextInputIncapable.contains(clientBundleIdentifier)
    if state.hasComposition, !isSecureMode {
      /// 將傳回的新狀態交給調度函式。
      handle(state: IMEState.ofCommitting(textToCommit: state.displayedText))
    }
    handle(state: isSecureMode ? IMEState.ofAbortion() : IMEState.ofEmpty())
  }
}

// MARK: - IMKStateSetting 協定規定的方法

extension SessionCtl {
  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public override func activateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    UserDefaults.standard.synchronize()
    if Self.allInstances.contains(self) { return }

    // 因為偶爾會收到與 activateServer 有關的以「強制拆 nil」為理由的報錯，
    // 所以這裡添加這句、來試圖應對這種情況。
    if inputHandler.delegate == nil { inputHandler.delegate = self }
    // 這裡不需要 setValue()，因為 IMK 會在 activateServer() 之後自動執行 setValue()。
    inputHandler.clear()  // 這句不要砍，因為後面 handle State.Empty() 不一定執行。
    inputHandler.ensureKeyboardParser()

    Self.theShiftKeyDetector.alsoToggleWithLShift = PrefMgr.shared.togglingAlphanumericalModeWithLShift

    if #available(macOS 10.15, *) {
      if isASCIIMode, PrefMgr.shared.disableShiftTogglingAlphanumericalMode { isASCIIMode = false }
    }

    DispatchQueue.main.async {
      (NSApp.delegate as? AppDelegate)?.updateSputnik.checkForUpdate(forced: false, url: kUpdateInfoSourceURL)
    }

    handle(state: IMEState.ofEmpty())
    Self.allInstances.insert(self)
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public override func deactivateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    resetInputHandler()  // 這條會自動搞定 Empty 狀態。
    handle(state: IMEState.ofDeactivated())
    Self.allInstances.remove(self)
  }

  /// 切換至某一個輸入法的某個副本時（比如威注音的簡體輸入法副本與繁體輸入法副本），會觸發該函式。
  /// - Parameters:
  ///   - value: 輸入法在系統偏好設定當中的副本的 identifier，與 bundle identifier 類似。在輸入法的 info.plist 內定義。
  ///   - tag: 標記（無須使用）。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  public override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    _ = tag  // 防止格式整理工具毀掉與此對應的參數。
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    let newInputMode: Shared.InputMode = .init(rawValue: value as? String ?? "") ?? .imeModeNULL
    if PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModel(newInputMode) }
    inputMode = newInputMode
    if let rawValString = value as? String, let bundleID = Bundle.main.bundleIdentifier,
      !bundleID.isEmpty, !rawValString.contains(bundleID)
    {
      setKeyLayout()
    }
  }

  /// 將輸入法偏好設定同步至語言模組內。
  public func syncBaseLMPrefs() {
    LMMgr.currentLM().isPhraseReplacementEnabled = PrefMgr.shared.phraseReplacementEnabled
    LMMgr.currentLM().isCNSEnabled = PrefMgr.shared.cns11643Enabled
    LMMgr.currentLM().isSymbolEnabled = PrefMgr.shared.symbolInputEnabled
    LMMgr.currentLM().isSCPCEnabled = PrefMgr.shared.useSCPCTypingMode
    LMMgr.currentLM().deltaOfCalendarYears = PrefMgr.shared.deltaOfCalendarYears
  }
}

// MARK: - IMKServerInput 協定規定的方法（僅部分）

// 註：handle(_ event:) 位於 SessionCtl_HandleEvent.swift。

extension SessionCtl {
  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  public override func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  public override func commitComposition(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    resetInputHandler()
    // super.commitComposition(sender)  // 這句不要引入，否則每次切出輸入法時都會死當。
  }

  /// 指定輸入法要遞交出去的內容（雖然 InputMethodKit 可能並不會真的用到這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  public override func composedString(_ sender: Any!) -> Any! {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    guard state.hasComposition else { return "" }
    return state.displayedTextConverted
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  public override func inputControllerWillClose() {
    // 下述兩行用來防止尚未完成拼寫的注音內容貝蒂交出去。
    resetInputHandler()
    super.inputControllerWillClose()
  }
}
