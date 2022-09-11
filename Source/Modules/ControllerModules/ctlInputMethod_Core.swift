// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(ctlInputMethod)  // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
class ctlInputMethod: IMKInputController {
  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  static var areWeNerfing = false

  /// 目前在用的的選字窗副本。
  static var ctlCandidateCurrent: ctlCandidateProtocol =
    mgrPrefs.useIMKCandidateWindow ? ctlCandidateIMK.init(.horizontal) : ctlCandidateUniversal.init(.horizontal)

  /// 工具提示視窗的共用副本。
  static var tooltipInstance = ctlTooltip()

  /// 浮動組字窗的共用副本。
  static var popupCompositionBuffer = ctlPopupCompositionBuffer()

  // MARK: -

  /// 當前這個 ctlInputMethod 副本是否處於英數輸入模式（滯後項）。
  static var isASCIIModeSituation: Bool = false
  /// 當前這個 ctlInputMethod 副本是否處於縱排輸入模式（滯後項）。
  static var isVerticalTypingSituation: Bool = false
  /// 當前這個 ctlInputMethod 副本是否處於縱排選字窗模式（滯後項）。
  static var isVerticalCandidateSituation: Bool = false
  /// 當前這個 ctlInputMethod 副本是否處於英數輸入模式。
  var isASCIIMode: Bool = false
  /// 按鍵調度模組的副本。
  var keyHandler: KeyHandler = .init()
  /// 用以記錄當前輸入法狀態的變數。
  var state: IMEStateProtocol = IMEState.ofEmpty() {
    didSet {
      IME.prtDebugIntel("Current State: \(state.type.rawValue)")
    }
  }

  /// 切換當前 ctlInputMethod 副本的英數輸入模式開關。
  func toggleASCIIMode() -> Bool {
    resetKeyHandler()
    isASCIIMode = !isASCIIMode
    return isASCIIMode
  }

  /// `handle(event:)` 會利用這個參數判定某次 Shift 按鍵是否用來切換中英文輸入。
  var rencentKeyHandledByKeyHandlerEtc = false

  // MARK: - 工具函式

  /// 指定鍵盤佈局。
  func setKeyLayout() {
    if let client = client() {
      client.overrideKeyboard(withKeyboardNamed: mgrPrefs.basicKeyboardLayout)
    }
  }

  /// 重設按鍵調度模組，會將當前尚未遞交的內容遞交出去。
  func resetKeyHandler() {
    // 過濾掉尚未完成拼寫的注音。
    if state.type == .ofInputting, mgrPrefs.trimUnfinishedReadingsOnCommit {
      keyHandler.composer.clear()
      handle(state: keyHandler.buildInputtingState)
    }
    if state.hasComposition {
      /// 將傳回的新狀態交給調度函式。
      handle(state: IMEState.ofCommitting(textToCommit: state.displayedText))
    }
    handle(state: IMEState.ofEmpty())
  }

  // MARK: - IMKInputController 方法

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    keyHandler.delegate = self
    // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    resetKeyHandler()
    activateServer(inputClient)
  }

  // MARK: - IMKStateSetting 協定規定的方法

  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func activateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    UserDefaults.standard.synchronize()

    // 因為偶爾會收到與 activateServer 有關的以「強制拆 nil」為理由的報錯，
    // 所以這裡添加這句、來試圖應對這種情況。
    if keyHandler.delegate == nil { keyHandler.delegate = self }
    setValue(IME.currentInputMode.rawValue, forTag: 114_514, client: client())
    keyHandler.clear()  // 這句不要砍，因為後面 handle State.Empty() 不一定執行。
    keyHandler.ensureParser()

    if isASCIIMode, mgrPrefs.disableShiftTogglingAlphanumericalMode { isASCIIMode = false }

    /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
    /// 這是很多 macOS 副廠輸入法的常見失誤之處。
    if let client = client(), client.bundleIdentifier() != Bundle.main.bundleIdentifier {
      // 強制重設當前鍵盤佈局、使其與偏好設定同步。
      setKeyLayout()
      handle(state: IMEState.ofEmpty())
    }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    UpdateSputnik.shared.checkForUpdate()
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func deactivateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    resetKeyHandler()  // 這條會自動搞定 Empty 狀態。
    handle(state: IMEState.ofDeactivated())
  }

  /// 切換至某一個輸入法的某個副本時（比如威注音的簡體輸入法副本與繁體輸入法副本），會觸發該函式。
  /// - Parameters:
  ///   - value: 輸入法在系統偏好設定當中的副本的 identifier，與 bundle identifier 類似。在輸入法的 info.plist 內定義。
  ///   - tag: 標記（無須使用）。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    _ = tag  // 防止格式整理工具毀掉與此對應的參數。
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    var newInputMode = InputMode(rawValue: value as? String ?? "") ?? InputMode.imeModeNULL
    switch newInputMode {
      case InputMode.imeModeCHS:
        newInputMode = InputMode.imeModeCHS
      case InputMode.imeModeCHT:
        newInputMode = InputMode.imeModeCHT
      default:
        newInputMode = InputMode.imeModeNULL
    }
    mgrLangModel.loadDataModel(newInputMode)

    if keyHandler.inputMode != newInputMode {
      UserDefaults.standard.synchronize()
      keyHandler.clear()  // 這句不要砍，因為後面 handle State.Empty() 不一定執行。
      keyHandler.inputMode = newInputMode
      /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
      /// 這是很多 macOS 副廠輸入法的常見失誤之處。
      if let client = client(), client.bundleIdentifier() != Bundle.main.bundleIdentifier {
        // 強制重設當前鍵盤佈局、使其與偏好設定同步。這裡的這一步也不能省略。
        setKeyLayout()
        handle(state: IMEState.ofEmpty())
      }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    }

    // 讓外界知道目前的簡繁體輸入模式。
    IME.currentInputMode = keyHandler.inputMode
  }

  // MARK: - IMKServerInput 協定規定的方法

  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  override func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:) override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。

    // MARK: 前置處理

    // 更新此時的靜態狀態標記。
    ctlInputMethod.isASCIIModeSituation = isASCIIMode
    ctlInputMethod.isVerticalTypingSituation = isVerticalTyping

    // 就這傳入的 NSEvent 都還有可能是 nil，Apple InputMethodKit 團隊到底在搞三小。
    // 只針對特定類型的 client() 進行處理。
    guard let event = event, sender is IMKTextInput else {
      resetKeyHandler()
      return false
    }

    // 用 Shift 開關半形英數模式，僅對 macOS 10.15 及之後的 macOS 有效。
    let shouldUseShiftToggleHandle: Bool = {
      switch mgrPrefs.shiftKeyAccommodationBehavior {
        case 0: return false
        case 1: return IME.arrClientShiftHandlingExceptionList.contains(clientBundleIdentifier)
        case 2: return true
        default: return false
      }
    }()

    /// 警告：這裡的 event 必須是原始 event 且不能被 var，否則會影響 Shift 中英模式判定。
    if #available(macOS 10.15, *) {
      if ShiftKeyUpChecker.check(event), !mgrPrefs.disableShiftTogglingAlphanumericalMode {
        if !shouldUseShiftToggleHandle || (!rencentKeyHandledByKeyHandlerEtc && shouldUseShiftToggleHandle) {
          NotifierController.notify(
            message: NSLocalizedString("Alphanumerical Mode", comment: "") + "\n"
              + (toggleASCIIMode()
                ? NSLocalizedString("NotificationSwitchON", comment: "")
                : NSLocalizedString("NotificationSwitchOFF", comment: ""))
          )
        }
        if shouldUseShiftToggleHandle {
          rencentKeyHandledByKeyHandlerEtc = false
        }
        return false
      }
    }

    // MARK: 針對客體的具體處理

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged { return false }

    /// 沒有文字輸入客體的話，就不要再往下處理了。
    guard client() != nil else { return false }

    var eventToDeal = event
    // 使 NSEvent 自翻譯，這樣可以讓 Emacs NSEvent 變成標準 NSEvent。
    if eventToDeal.isEmacsKey {
      let verticalProcessing =
        (state.isCandidateContainer)
        ? ctlInputMethod.isVerticalCandidateSituation : ctlInputMethod.isVerticalTypingSituation
      eventToDeal = eventToDeal.convertFromEmacKeyEvent(isVerticalContext: verticalProcessing)
    }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    ctlInputMethod.areWeNerfing = eventToDeal.modifierFlags.contains([.shift, .command])

    // IMK 選字窗處理，當且僅當啟用了 IMK 選字窗的時候才會生效。
    if let result = imkCandidatesEventHandler(event: eventToDeal) {
      if shouldUseShiftToggleHandle {
        rencentKeyHandledByKeyHandlerEtc = result
      }
      return result
    }

    /// 剩下的 NSEvent 直接交給 commonEventHandler 來處理。
    /// 這樣可以與 IMK 選字窗共用按鍵處理資源，維護起來也比較方便。
    let result = commonEventHandler(eventToDeal)
    if shouldUseShiftToggleHandle {
      rencentKeyHandledByKeyHandlerEtc = result
    }
    return result
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func commitComposition(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    resetKeyHandler()
    // super.commitComposition(sender)  // 這句不要引入，否則每次切出輸入法時都會死當。
  }

  /// 指定輸入法要遞交出去的內容（雖然威注音可能並未用到這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  override func composedString(_ sender: Any!) -> Any! {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    guard state.hasComposition else { return "" }
    return state.displayedText
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  override func inputControllerWillClose() {
    // 下述兩行用來防止尚未完成拼寫的注音內容貝蒂交出去。
    resetKeyHandler()
    super.inputControllerWillClose()
  }

  // MARK: - IMKCandidates 功能擴充

  /// 生成 IMK 選字窗專用的候選字串陣列。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: IMK 選字窗專用的候選字串陣列。
  override func candidates(_ sender: Any!) -> [Any]! {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    var arrResult = [String]()

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleCandidatesPrepared(_ candidates: [(String, String)], prefix: String = "") {
      for theCandidate in candidates {
        let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
        var result = (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)\u{1A}(\(theCandidate.1))"
        if arrResult.contains(result) {
          let reading: String =
            mgrPrefs.showHanyuPinyinInCompositionBuffer
            ? Tekkon.cnvPhonaToHanyuPinyin(target: Tekkon.restoreToneOneInZhuyinKey(target: theCandidate.0))
            : theCandidate.0
          result = "\(result)\u{17}(\(reading))"
        }
        arrResult.append(prefix + result)
      }
    }

    if state.type == .ofAssociates {
      handleCandidatesPrepared(state.candidates, prefix: "⇧")
    } else if state.type == .ofSymbolTable {
      // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
      arrResult = state.candidates.map(\.1)
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return .init() }
      if state.candidates[0].0.contains("_punctuation") {
        arrResult = state.candidates.map(\.1)  // 標點符號選單處理。
      } else {
        handleCandidatesPrepared(state.candidates)
      }
    }

    return arrResult
  }

  /// IMK 選字窗限定函式，只要選字窗內的高亮內容選擇出現變化了、就會呼叫這個函式。
  /// - Parameter _: 已經高亮選中的候選字詞內容。
  override open func candidateSelectionChanged(_: NSAttributedString!) {
    // 警告：不要考慮用實作這個函式的方式來更新內文組字區的顯示。
    // 因為這樣會導致 IMKServer.commitCompositionWithReply() 呼叫你本來不想呼叫的 commitComposition()，
    // 然後 keyHandler 會被重設，屆時輸入法會在狀態處理等方面崩潰掉。

    // 這個函式的實作其實很容易誘發各種崩潰，所以最好不要輕易實作。

    // 有些幹話還是要講的：
    // 在這個函式當中試圖（無論是否拿著傳入的參數）從 ctlCandidateIMK 找 identifier 的話，
    // 只會找出 NSNotFound。你想 NSLog 列印看 identifier 是多少，輸入法直接崩潰。
    // 而且會他媽的崩得連 console 內的 ips 錯誤報告都沒有。
    // 在下文的 candidateSelected() 試圖看每個候選字的 identifier 的話，永遠都只能拿到 NSNotFound。
    // 衰洨 IMK 真的看上去就像是沒有做過單元測試的東西，賈伯斯有檢查過的話會被氣得從棺材裡爬出來。
  }

  /// IMK 選字窗限定函式，只要選字窗確認了某個候選字詞的選擇、就會呼叫這個函式。
  /// - Parameter candidateString: 已經確認的候選字詞內容。
  override open func candidateSelected(_ candidateString: NSAttributedString!) {
    let candidateString: NSAttributedString = candidateString ?? .init(string: "")
    if state.type == .ofAssociates {
      if !mgrPrefs.alsoConfirmAssociatedCandidatesByEnter {
        handle(state: IMEState.ofAbortion())
        return
      }
    }

    var indexDeducted = 0

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleCandidatesSelected(_ candidates: [(String, String)], prefix: String = "") {
      for (i, neta) in candidates.enumerated() {
        let theConverted = IME.kanjiConversionIfRequired(neta.1)
        let netaShown = (neta.1 == theConverted) ? neta.1 : "\(theConverted)\u{1A}(\(neta.1))"
        let reading: String =
          mgrPrefs.showHanyuPinyinInCompositionBuffer
          ? Tekkon.cnvPhonaToHanyuPinyin(target: Tekkon.restoreToneOneInZhuyinKey(target: neta.0)) : neta.0
        let netaShownWithPronunciation = "\(netaShown)\u{17}(\(reading))"
        if candidateString.string == prefix + netaShownWithPronunciation {
          indexDeducted = i
          break
        }
        if candidateString.string == prefix + netaShown {
          indexDeducted = i
          break
        }
      }
    }

    // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
    func handleSymbolCandidatesSelected(_ candidates: [(String, String)]) {
      for (i, neta) in candidates.enumerated() {
        if candidateString.string == neta.1 {
          indexDeducted = i
          break
        }
      }
    }

    if state.type == .ofAssociates {
      handleCandidatesSelected(state.candidates, prefix: "⇧")
    } else if state.type == .ofSymbolTable {
      handleSymbolCandidatesSelected(state.candidates)
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return }
      if state.candidates[0].0.contains("_punctuation") {
        handleSymbolCandidatesSelected(state.candidates)  // 標點符號選單處理。
      } else {
        handleCandidatesSelected(state.candidates)
      }
    }
    keyHandler(
      keyHandler,
      didSelectCandidateAt: indexDeducted,
      ctlCandidate: ctlInputMethod.ctlCandidateCurrent
    )
  }
}
