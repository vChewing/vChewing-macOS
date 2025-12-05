// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - HaninSymbolTypewriter

/// 處理漢音鍵盤符號輸入狀態（Handle Hanin Keyboard Symbol Mode Inputs）
@frozen
public struct HaninSymbolTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  /// 處理漢音鍵盤符號輸入。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    // 這個函式的結果是 non-null，但此處遵從協定。
    guard let session = handler.session else { return false }
    guard session.state.type != .ofDeactivated else { return false }
    let charText = input.text.lowercased().applyingTransformFW2HW(reverse: false)
    guard CandidateNode.mapHaninKeyboardSymbols.keys.contains(charText) else {
      return handler.revolveTypingMethod(to: .vChewingFactory)
    }
    let symbols = CandidateNode.queryHaninKeyboardSymbols(char: charText)
    guard charText.count == 1, let symbols else {
      errorCallback("C1A760C7")
      return true
    }
    // 得在這裡先 commit buffer，
    // 不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = handler.generateStateOfInputting(sansReading: true).displayedText
    session.switchState(State.ofCommitting(textToCommit: textToCommit))
    if symbols.members.count == 1 {
      let textToCommit = symbols.members.map(\.name).joined()
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
    } else {
      session.switchState(State.ofSymbolTable(node: symbols))
    }
    // 用完就關掉，但保持選字窗開啟，所以這裡不用呼叫 toggle 函式。
    handler.currentTypingMethod = .vChewingFactory
    return true
  }
}
