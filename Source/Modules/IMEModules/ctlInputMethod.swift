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

private let kMinKeyLabelSize: CGFloat = 10

private var ctlCandidateCurrent = ctlCandidateUniversal.init(.horizontal)

@objc(ctlInputMethod)
class ctlInputMethod: IMKInputController {
  @objc static var areWeDeleting = false

  static let tooltipController = TooltipController()

  // MARK: -

  private var keyHandler: KeyHandler = .init()
  private var state: InputState = .Empty()

  // MARK: - Keyboard Layout Specifier

  @objc func setKeyLayout() {
    client().overrideKeyboard(withKeyboardNamed: mgrPrefs.basicKeyboardLayout)
  }

  // MARK: - IMKInputController methods

  override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    keyHandler.delegate = self
    // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    activateServer(inputClient)
    resetKeyHandler()
  }

  // MARK: - KeyHandler Reset Command

  func resetKeyHandler() {
    keyHandler.clear()
    handle(state: InputState.Empty())
  }

  // MARK: - IMKStateSetting protocol methods

  override func activateServer(_ sender: Any!) {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    UserDefaults.standard.synchronize()

    keyHandler.clear()
    keyHandler.ensureParser()

    if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
      // Override the keyboard layout to the basic one.
      setKeyLayout()
      handle(state: .Empty())
    }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    (NSApp.delegate as? AppDelegate)?.checkForUpdate()
  }

  override func deactivateServer(_ sender: Any!) {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    keyHandler.clear()
    handle(state: .Empty())
    handle(state: .Deactivated())
  }

  override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    _ = tag  // Stop clang-format from ruining the parameters of this function.
    _ = sender  // Stop clang-format from ruining the parameters of this function.
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
      if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
        // Remember to override the keyboard layout again -- treat this as an activate event.
        setKeyLayout()
        handle(state: .Empty())
      }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    }

    // 讓外界知道目前的簡繁體輸入模式。
    IME.currentInputMode = keyHandler.inputMode
  }

  // MARK: - IMKServerInput protocol methods

  override func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  @objc(handleEvent:client:) override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    // 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    // 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    // 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    // 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
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

    let result = keyHandler.handle(input: input, state: state) { newState in
      self.handle(state: newState)
    } errorCallback: {
      clsSFX.beep()
    }
    return result
  }

  // 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  // 也就是說 handle(event:) 完全抓不到這個 Event。
  // 這時需要在 commitComposition 這一關做一些收尾處理。
  override func commitComposition(_ sender: Any!) {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    if let state = state as? InputState.NotEmpty {
      handle(state: InputState.Committing(poppedText: state.composingBuffer))
    }
    resetKeyHandler()
  }

  // 這個函數必須得在對應的狀態下給出對應的內容。
  override func composedString(_ sender: Any!) -> Any! {
    _ = sender  // Stop clang-format from ruining the parameters of this function.
    return (state as? InputState.NotEmpty)?.composingBuffer ?? ""
  }
}

// MARK: - State Handling

extension ctlInputMethod {
  private func handle(state newState: InputState) {
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

  private func commit(text: String) {
    func kanjiConversionIfRequired(_ text: String) -> String {
      if keyHandler.inputMode == InputMode.imeModeCHT {
        switch (mgrPrefs.chineseConversionEnabled, mgrPrefs.shiftJISShinjitaiOutputEnabled) {
          case (false, true): return vChewingKanjiConverter.cnvTradToJIS(text)
          case (true, false): return vChewingKanjiConverter.cnvTradToKangXi(text)
          // 本來這兩個開關不該同時開啟的，但萬一被開啟了的話就這樣處理：
          case (true, true): return vChewingKanjiConverter.cnvTradToJIS(text)
          case (false, false): return text
        }
      }
      return text
    }

    let buffer = kanjiConversionIfRequired(text)
    if buffer.isEmpty {
      return
    }

    var bufferOutput = ""

    // 防止輸入法輸出不可列印的字元。
    for theChar in buffer {
      if let charCode = theChar.utf16.first {
        if !(theChar.isASCII && !(charCode.isPrintable())) {
          bufferOutput += String(theChar)
        }
      }
    }

    client().insertText(
      bufferOutput, replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Deactivated, previous: InputState) {
    _ = state  // Stop clang-format from ruining the parameters of this function.

    ctlCandidateCurrent.delegate = nil
    ctlCandidateCurrent.visible = false
    hideTooltip()

    if let previous = previous as? InputState.NotEmpty {
      commit(text: previous.composingBuffer)
    }
    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Empty, previous: InputState) {
    _ = state  // Stop clang-format from ruining the parameters of this function.
    ctlCandidateCurrent.visible = false
    hideTooltip()

    if let previous = previous as? InputState.NotEmpty,
      !(state is InputState.EmptyIgnoringPreviousState)
    {
      commit(text: previous.composingBuffer)
    }
    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(
    state: InputState.EmptyIgnoringPreviousState, previous: InputState
  ) {
    _ = state  // Stop clang-format from ruining the parameters of this function.
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    ctlCandidateCurrent.visible = false
    hideTooltip()

    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Committing, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    ctlCandidateCurrent.visible = false
    hideTooltip()

    let poppedText = state.poppedText
    if !poppedText.isEmpty {
      commit(text: poppedText)
    }
    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
  }

  private func handle(state: InputState.Inputting, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    ctlCandidateCurrent.visible = false
    hideTooltip()

    let poppedText = state.poppedText
    if !poppedText.isEmpty {
      commit(text: poppedText)
    }

    // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
    // i.e. the client app needs to take care of where to put this composing buffer
    client().setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
    if !state.tooltip.isEmpty {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.cursorIndex
      )
    }
  }

  private func handle(state: InputState.Marking, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    ctlCandidateCurrent.visible = false

    // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
    // i.e. the client app needs to take care of where to put this composing buffer
    client().setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )

    if state.tooltip.isEmpty {
      hideTooltip()
    } else {
      show(
        tooltip: state.tooltip, composingBuffer: state.composingBuffer,
        cursorIndex: state.markerIndex
      )
    }
  }

  private func handle(state: InputState.ChoosingCandidate, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    hideTooltip()

    // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
    // i.e. the client app needs to take care of where to put this composing buffer
    client().setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.SymbolTable, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    hideTooltip()

    // the selection range is where the cursor is, with the length being 0 and replacement range NSNotFound,
    // i.e. the client app needs to take care of where to put this composing buffer
    client().setMarkedText(
      state.attributedString, selectionRange: NSRange(location: state.cursorIndex, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
    show(candidateWindowWith: state)
  }

  private func handle(state: InputState.AssociatedPhrases, previous: InputState) {
    _ = previous  // Stop clang-format from ruining the parameters of this function.
    hideTooltip()

    client().setMarkedText(
      "", selectionRange: NSRange(location: 0, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
    )
    show(candidateWindowWith: state)
  }
}

// MARK: -

extension ctlInputMethod {
  private func show(candidateWindowWith state: InputState) {
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
    let keyLabelSize = max(textSize / 2, kMinKeyLabelSize)

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
      // 對更紗黑體的依賴到 macOS 11 Big Sur 為止。macOS 12 Monterey 開始則依賴系統內建的函數使用蘋方來處理。
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

  func keyHandler(_ keyHandler: KeyHandler, didRequestWriteUserPhraseWith state: InputState)
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
    _ = controller  // Stop clang-format from ruining the parameters of this function.
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
    _ = controller  // Stop clang-format from ruining the parameters of this function.
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates[index]
    } else if let state = state as? InputState.AssociatedPhrases {
      return state.candidates[index]
    }
    return ""
  }

  func ctlCandidate(_ controller: ctlCandidate, didSelectCandidateAtIndex index: Int) {
    _ = controller  // Stop clang-format from ruining the parameters of this function.

    if let state = state as? InputState.SymbolTable,
      let node = state.node.children?[index]
    {
      if let children = node.children, !children.isEmpty {
        handle(state: .Empty())  // 防止縱橫排選字窗同時出現
        handle(
          state: .SymbolTable(node: node, isTypingVertical: state.isTypingVertical)
        )
      } else {
        handle(state: .Committing(poppedText: node.title))
        handle(state: .Empty())
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
        handle(state: .Committing(poppedText: composingBuffer))
        if mgrPrefs.associatedPhrasesEnabled,
          let associatePhrases = keyHandler.buildAssociatePhraseState(
            withKey: composingBuffer, isTypingVertical: state.isTypingVertical
          ), !associatePhrases.candidates.isEmpty
        {
          handle(state: associatePhrases)
        } else {
          handle(state: .Empty())
        }
      } else {
        handle(state: inputting)
      }
      return
    }

    if let state = state as? InputState.AssociatedPhrases {
      let selectedValue = state.candidates[index]
      handle(state: .Committing(poppedText: selectedValue))
      if mgrPrefs.associatedPhrasesEnabled,
        let associatePhrases = keyHandler.buildAssociatePhraseState(
          withKey: selectedValue, isTypingVertical: state.isTypingVertical
        ), !associatePhrases.candidates.isEmpty
      {
        handle(state: associatePhrases)
      } else {
        handle(state: .Empty())
      }
    }
  }
}
