// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
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
  /// 標記狀態來聲明目前是在新增使用者語彙、還是準備要濾除使用者語彙。
  static var areWeDeleting = false

  /// 目前在用的的選字窗副本。
  private var ctlCandidateCurrent = ctlCandidateUniversal.init(.horizontal)

  /// 工具提示視窗的副本。
  static let tooltipController = TooltipController()

  // MARK: -

  /// 按鍵調度模組的副本。
  private var keyHandler: KeyHandler = .init()
  /// 用以記錄當前輸入法狀態的變數。
  private var state: InputStateProtocol = InputState.Empty()

  // MARK: - 工具函式

  /// 指定鍵盤佈局。
  func setKeyLayout() {
    client().overrideKeyboard(withKeyboardNamed: mgrPrefs.basicKeyboardLayout)
  }

  /// 重設按鍵調度模組，會將當前尚未遞交的內容遞交出去。
  func resetKeyHandler() {
    if let state = state as? InputState.NotEmpty {
      /// 將傳回的新狀態交給調度函式。
      handle(state: InputState.Committing(textToCommit: state.composingBufferConverted))
    }
    keyHandler.clear()
    handle(state: InputState.Empty())
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
    activateServer(inputClient)
    resetKeyHandler()
  }

  // MARK: - IMKStateSetting 協定規定的方法

  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func activateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    UserDefaults.standard.synchronize()

    keyHandler.clear()
    keyHandler.ensureParser()

    /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
    /// 這是很多 macOS 副廠輸入法的常見失誤之處。
    if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
      // 強制重設當前鍵盤佈局、使其與偏好設定同步。
      setKeyLayout()
      handle(state: InputState.Empty())
    }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    (NSApp.delegate as? AppDelegate)?.checkForUpdate()
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func deactivateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    keyHandler.clear()
    handle(state: InputState.Empty())
    handle(state: InputState.Deactivated())
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
      keyHandler.clear()
      keyHandler.inputMode = newInputMode
      /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
      /// 這是很多 macOS 副廠輸入法的常見失誤之處。
      if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
        // 強制重設當前鍵盤佈局、使其與偏好設定同步。這裡的這一步也不能省略。
        setKeyLayout()
        handle(state: InputState.Empty())
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
  ///   - event: 裝置操作輸入事件。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:) override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged {
      return false
    }

    // 準備修飾鍵，用來判定是否需要利用就地新增語彙時的 Enter 鍵來砍詞。
    ctlInputMethod.areWeDeleting = event.modifierFlags.contains([.shift, .command])

    var textFrame = NSRect.zero

    let attributes: [AnyHashable: Any]? = client().attributes(
      forCharacterIndex: 0, lineHeightRectangle: &textFrame
    )

    let isTypingVertical =
      (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false

    if client().bundleIdentifier()
      == "org.atelierInmu.vChewing.vChewingPhraseEditor"
    {
      IME.areWeUsingOurOwnPhraseEditor = true
    } else {
      IME.areWeUsingOurOwnPhraseEditor = false
    }

    let input = InputSignal(event: event, isVerticalTyping: isTypingVertical)

    // 無法列印的訊號輸入，一概不作處理。
    // 這個過程不能放在 KeyHandler 內，否則不會起作用。
    if !input.charCode.isPrintable() {
      return false
    }

    /// 將按鍵行為與當前輸入法狀態結合起來、交給按鍵調度模組來處理。
    /// 再根據返回的 result bool 數值來告知 IMK「這個按鍵事件是被處理了還是被放行了」。
    let result = keyHandler.handle(input: input, state: state) { newState in
      self.handle(state: newState)
    } errorCallback: {
      clsSFX.beep()
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
  }
}

// MARK: - 狀態調度 (State Handling)

extension ctlInputMethod {
  /// 針對傳入的新狀態進行調度。
  ///
  /// 先將舊狀態單獨記錄起來，再將新舊狀態作為參數，
  /// 根據新狀態本身的狀態種類來判斷交給哪一個專門的函式來處理。
  /// - Parameter newState: 新狀態。
  private func handle(state newState: InputStateProtocol) {
    let prevState = state
    state = newState

    switch newState {
      case let newState as InputState.Deactivated:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Empty:
        handle(state: newState, previous: prevState)
      case let newState as InputState.EmptyIgnoringPreviousState:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Committing:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Inputting:
        handle(state: newState, previous: prevState)
      case let newState as InputState.Marking:
        handle(state: newState, previous: prevState)
      case let newState as InputState.ChoosingCandidate:
        handle(state: newState, previous: prevState)
      case let newState as InputState.AssociatedPhrases:
        handle(state: newState, previous: prevState)
      case let newState as InputState.SymbolTable:
        handle(state: newState, previous: prevState)
      default: break
    }
  }

  /// 針對受 .NotEmpty() 管轄的非空狀態，在組字區內顯示游標。
  private func setInlineDisplayWithCursor() {
    guard let state = state as? InputState.NotEmpty else {
      clearInlineDisplay()
      return
    }

    var identifier: AnyObject {
      switch IME.currentInputMode {
        case InputMode.imeModeCHS:
          if #available(macOS 12.0, *) {
            return "zh-Hans" as AnyObject
          }
        case InputMode.imeModeCHT:
          if #available(macOS 12.0, *) {
            return (mgrPrefs.shiftJISShinjitaiOutputEnabled || mgrPrefs.chineseConversionEnabled)
              ? "ja" as AnyObject : "zh-Hant" as AnyObject
          }
        default:
          break
      }
      return "" as AnyObject
    }

    // [Shiki's Note] This might needs to be bug-reported to Apple:
    // The LanguageIdentifier attribute of an NSAttributeString designated to
    // IMK Client().SetMarkedText won't let the actual font respect your languageIdentifier
    // settings. Still, this might behaves as Apple's current expectation, I'm afraid.
    if #available(macOS 12.0, *) {
      state.attributedString.setAttributes(
        [.languageIdentifier: identifier],
        range: NSRange(
          location: 0,
          length: state.composingBuffer.utf16.count
        )
      )
    }

    /// 所謂選區「selectionRange」，就是「可見游標位置」的位置，只不過長度
    /// 是 0 且取代範圍（replacementRange）為「NSNotFound」罷了。
    /// 也就是說，內文組字區該在哪裡出現，得由客體軟體來作主。
    client().setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  /// 在處理不受 .NotEmpty() 管轄的狀態時可能要用到的函式，會清空螢幕上顯示的內文組字區。
  /// 當 setInlineDisplayWithCursor() 在錯誤的狀態下被呼叫時，也會觸發這個函式。
  private func clearInlineDisplay() {
    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  /// 遞交組字區內容。
  /// 注意：必須在 IMK 的 commitComposition 函式當中也間接或者直接執行這個處理。
  private func commit(text: String) {
    let buffer = IME.kanjiConversionIfRequired(text)
    if buffer.isEmpty {
      return
    }

    client().insertText(
      buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Deactivated, previous: InputStateProtocol) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    ctlCandidateCurrent.delegate = nil
    ctlCandidateCurrent.visible = false
    hideTooltip()
    if let previous = previous as? InputState.NotEmpty {
      commit(text: previous.composingBuffer)
    }
    clearInlineDisplay()
  }

  private func handle(state: InputState.Empty, previous: InputStateProtocol) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    ctlCandidateCurrent.visible = false
    hideTooltip()
    // 全專案用以判斷「.EmptyIgnoringPreviousState」的地方僅此一處。
    if let previous = previous as? InputState.NotEmpty,
      !(state is InputState.EmptyIgnoringPreviousState)
    {
      commit(text: previous.composingBuffer)
    }
    clearInlineDisplay()
  }

  private func handle(
    state: InputState.EmptyIgnoringPreviousState, previous: InputStateProtocol
  ) {
    _ = state  // 防止格式整理工具毀掉與此對應的參數。
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    // 這個函式就是去掉 previous state 使得沒有任何東西可以 commit。
    handle(state: InputState.Empty())
  }

  private func handle(state: InputState.Committing, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlCandidateCurrent.visible = false
    hideTooltip()
    let textToCommit = state.textToCommit
    if !textToCommit.isEmpty {
      commit(text: textToCommit)
    }
    clearInlineDisplay()
  }

  private func handle(state: InputState.Inputting, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlCandidateCurrent.visible = false
    hideTooltip()
    let textToCommit = state.textToCommit
    if !textToCommit.isEmpty {
      commit(text: textToCommit)
    }
    setInlineDisplayWithCursor()
    if !state.tooltip.isEmpty {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.cursorIndex
      )
    }
  }

  private func handle(state: InputState.Marking, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    ctlCandidateCurrent.visible = false
    setInlineDisplayWithCursor()
    if state.tooltip.isEmpty {
      hideTooltip()
    } else {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.markerIndex
      )
    }
  }

  private func handle(state: InputState.ChoosingCandidate, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    hideTooltip()
    setInlineDisplayWithCursor()
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.SymbolTable, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    hideTooltip()
    setInlineDisplayWithCursor()
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.AssociatedPhrases, previous: InputStateProtocol) {
    _ = previous  // 防止格式整理工具毀掉與此對應的參數。
    hideTooltip()
    clearInlineDisplay()
    show(candidateWindowWith: state)
  }
}

// MARK: -

extension ctlInputMethod {
  private func show(candidateWindowWith state: InputStateProtocol) {
    var isTypingVertical: Bool {
      if let state = state as? InputState.ChoosingCandidate {
        return state.isTypingVertical
      } else if let state = state as? InputState.AssociatedPhrases {
        return state.isTypingVertical
      }
      return false
    }
    var isCandidateWindowVertical: Bool {
      var candidates: [String] = []
      if let state = state as? InputState.ChoosingCandidate {
        candidates = state.candidates
      } else if let state = state as? InputState.AssociatedPhrases {
        candidates = state.candidates
      }
      if isTypingVertical { return true }
      // 以上是通用情形。接下來決定橫排輸入時是否使用縱排選字窗。
      candidates.sort {
        $0.count > $1.count
      }
      // 測量每頁顯示候選字的累計總長度。如果太長的話就強制使用縱排候選字窗。
      // 範例：「屬實牛逼」（會有一大串各種各樣的「鼠食牛Beer」的 emoji）。
      let maxCandidatesPerPage = mgrPrefs.candidateKeys.count
      let firstPageCandidates = candidates[0..<min(maxCandidatesPerPage, candidates.count)]
      return firstPageCandidates.joined().count > Int(round(Double(maxCandidatesPerPage) * 1.8))
      // 上面這句如果是 true 的話，就會是縱排；反之則為橫排。
    }

    ctlCandidateCurrent.delegate = nil

    /// 下面這一段本可直接指定 currentLayout，但這樣的話翻頁按鈕位置無法精準地重新繪製。
    /// 所以只能重新初期化。壞處就是得在 ctlCandidate() 當中與 SymbolTable 控制有關的地方
    /// 新增一個空狀態請求、防止縱排與橫排選字窗同時出現。
    /// layoutCandidateView 在這裡無法起到糾正作用。
    /// 該問題徹底解決的價值並不大，直接等到 macOS 10.x 全線淘汰之後用 SwiftUI 重寫選字窗吧。

    if isCandidateWindowVertical {  // 縱排輸入時強制使用縱排選字窗
      ctlCandidateCurrent = .init(.vertical)
    } else if mgrPrefs.useHorizontalCandidateList {
      ctlCandidateCurrent = .init(.horizontal)
    } else {
      ctlCandidateCurrent = .init(.vertical)
    }

    // set the attributes for the candidate panel (which uses NSAttributedString)
    let textSize = mgrPrefs.candidateListTextSize
    let keyLabelSize = max(textSize / 2, mgrPrefs.minKeyLabelSize)

    func labelFont(name: String?, size: CGFloat) -> NSFont {
      if let name = name {
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
      }
      return NSFont.systemFont(ofSize: size)
    }

    func candidateFont(name: String?, size: CGFloat) -> NSFont {
      let currentMUIFont =
        (keyHandler.inputMode == InputMode.imeModeCHS)
        ? "Sarasa Term Slab SC" : "Sarasa Term Slab TC"
      var finalReturnFont =
        NSFont(name: currentMUIFont, size: size) ?? NSFont.systemFont(ofSize: size)
      // 對更紗黑體的依賴到 macOS 11 Big Sur 為止。macOS 12 Monterey 開始則依賴系統內建的函式使用蘋方來處理。
      if #available(macOS 12.0, *) { finalReturnFont = NSFont.systemFont(ofSize: size) }
      if let name = name {
        return NSFont(name: name, size: size) ?? finalReturnFont
      }
      return finalReturnFont
    }

    ctlCandidateCurrent.keyLabelFont = labelFont(
      name: mgrPrefs.candidateKeyLabelFontName, size: keyLabelSize
    )
    ctlCandidateCurrent.candidateFont = candidateFont(
      name: mgrPrefs.candidateTextFontName, size: textSize
    )

    let candidateKeys = mgrPrefs.candidateKeys
    let keyLabels =
      candidateKeys.count > 4 ? Array(candidateKeys) : Array(mgrPrefs.defaultCandidateKeys)
    let keyLabelSuffix = state is InputState.AssociatedPhrases ? "^" : ""
    ctlCandidateCurrent.keyLabels = keyLabels.map {
      CandidateKeyLabel(key: String($0), displayedText: String($0) + keyLabelSuffix)
    }

    ctlCandidateCurrent.delegate = self
    ctlCandidateCurrent.reloadData()

    ctlCandidateCurrent.visible = true

    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = 0

    if let state = state as? InputState.ChoosingCandidate {
      cursor = state.cursorIndex
      if cursor == state.composingBuffer.count, cursor != 0 {
        cursor -= 1
      }
    }

    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client().attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }

    if isTypingVertical {
      ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(
          x: lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, y: lineHeightRect.origin.y - 4.0
        ),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
      )
    } else {
      ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(x: lineHeightRect.origin.x, y: lineHeightRect.origin.y - 4.0),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
      )
    }
  }

  private func show(tooltip: String, composingBuffer: String, cursorIndex: Int) {
    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = cursorIndex
    if cursor == composingBuffer.count, cursor != 0 {
      cursor -= 1
    }
    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client().attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }
    ctlInputMethod.tooltipController.show(tooltip: tooltip, at: lineHeightRect.origin)
  }

  private func hideTooltip() {
    ctlInputMethod.tooltipController.hide()
  }
}

// MARK: -

extension ctlInputMethod: KeyHandlerDelegate {
  func ctlCandidate() -> ctlCandidate { ctlCandidateCurrent }

  func keyHandler(
    _: KeyHandler, didSelectCandidateAt index: Int,
    ctlCandidate controller: ctlCandidate
  ) {
    ctlCandidate(controller, didSelectCandidateAtIndex: index)
  }

  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputStateProtocol)
    -> Bool
  {
    guard let state = state as? InputState.Marking else {
      return false
    }
    if !state.validToWrite {
      return false
    }
    let refInputModeReversed: InputMode =
      (keyHandler.inputMode == InputMode.imeModeCHT)
      ? InputMode.imeModeCHS : InputMode.imeModeCHT
    if !mgrLangModel.writeUserPhrase(
      state.userPhrase, inputMode: keyHandler.inputMode,
      areWeDuplicating: state.chkIfUserPhraseExists,
      areWeDeleting: ctlInputMethod.areWeDeleting
    )
      || !mgrLangModel.writeUserPhrase(
        state.userPhraseConverted, inputMode: refInputModeReversed,
        areWeDuplicating: false,
        areWeDeleting: ctlInputMethod.areWeDeleting
      )
    {
      return false
    }
    return true
  }
}

// MARK: -

extension ctlInputMethod: ctlCandidateDelegate {
  func candidateCountForController(_ controller: ctlCandidate) -> Int {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates.count
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates.count
    }
    return 0
  }

  func ctlCandidate(_ controller: ctlCandidate, candidateAtIndex index: Int)
    -> String
  {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates[index]
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates[index]
    }
    return ""
  }

  func ctlCandidate(_ controller: ctlCandidate, didSelectCandidateAtIndex index: Int) {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。

    if let state = state as? InputState.SymbolTable,
      let node = state.node.children?[index]
    {
      if let children = node.children, !children.isEmpty {
        handle(state: InputState.Empty())  // 防止縱橫排選字窗同時出現
        handle(
          state: InputState.SymbolTable(node: node, isTypingVertical: state.isTypingVertical)
        )
      } else {
        handle(state: InputState.Committing(textToCommit: node.title))
        handle(state: InputState.Empty())
      }
      return
    }

    if let state = state as? InputState.ChoosingCandidate {
      let selectedValue = state.candidates[index]
      keyHandler.fixNode(value: selectedValue, respectCursorPushing: true)

      let inputting = keyHandler.buildInputtingState

      if mgrPrefs.useSCPCTypingMode {
        keyHandler.clear()
        let composingBuffer = inputting.composingBuffer
        handle(state: InputState.Committing(textToCommit: composingBuffer))
        if mgrPrefs.associatedPhrasesEnabled,
          let associatePhrases = keyHandler.buildAssociatePhraseState(
            withKey: composingBuffer, isTypingVertical: state.isTypingVertical
          ), !associatePhrases.candidates.isEmpty
        {
          handle(state: associatePhrases)
        } else {
          handle(state: InputState.Empty())
        }
      } else {
        handle(state: inputting)
      }
      return
    }

    if let state = state as? InputState.AssociatedPhrases {
      let selectedValue = state.candidates[index]
      handle(state: InputState.Committing(textToCommit: selectedValue))
      if mgrPrefs.associatedPhrasesEnabled,
        let associatePhrases = keyHandler.buildAssociatePhraseState(
          withKey: selectedValue, isTypingVertical: state.isTypingVertical
        ), !associatePhrases.candidates.isEmpty
      {
        handle(state: associatePhrases)
      } else {
        handle(state: InputState.Empty())
      }
    }
  }
}
