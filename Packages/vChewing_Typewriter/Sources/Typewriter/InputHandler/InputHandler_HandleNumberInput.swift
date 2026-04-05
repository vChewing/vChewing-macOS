// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - 數字快打模式按鍵處理

extension InputHandlerProtocol {
  func handleNumberQuickInput(input: InputSignalProtocol) -> Bool {
    let h = numberQuickInputHandler
    guard let session = session else { return false }

    switch KeyCode(rawValue: input.keyCode) {
    case .kCarriageReturn, .kLineFeed:
      // 送出選中候選（含前方中文）
      let chosen = session.state.data.currentCandidate?.value ?? h.numberBuffer
      let textToCommit = h.precedingText + chosen
      h.deactivate()
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      return true

    case .kSpace:
      // 同 Enter（選第一個候選）
      let first = session.state.data.candidates.first?.value ?? h.numberBuffer
      let textToCommit = h.precedingText + first
      h.deactivate()
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      return true

    case .kEscape:
      // 取消，回到純中文組字狀態（保留前方中文）
      let prev = h.precedingText
      h.deactivate()
      session.switchState(prev.isEmpty ? State.ofEmpty() : State.ofInputting(
        displayTextSegments: [prev], cursor: prev.count, highlightAt: nil))
      return true

    case .kBackSpace:
      if h.numberBuffer.isEmpty {
        // 緩衝區空，離開模式
        let prev = h.precedingText
        h.deactivate()
        session.switchState(prev.isEmpty ? State.ofEmpty() : State.ofInputting(
          displayTextSegments: [prev], cursor: prev.count, highlightAt: nil))
      } else {
        h.deleteLastChar()
        updateNumberQuickInputState()
      }
      return true

    default: break
    }

    // 有效輸入字元（數字、運算子、點、冒號）
    let validChars: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                                      "+", "-", "*", "/", "(", ")", ".", ":"]
    if let char = input.text.first, validChars.contains(char) {
      h.appendChar(char)
      updateNumberQuickInputState()
      return true
    }

    // 其他按鍵（注音鍵等）：先送出第一個候選再穿透
    if !h.numberBuffer.isEmpty,
       let first = session.state.data.candidates.first?.value {
      let textToCommit = h.precedingText + first
      h.deactivate()
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      return triageInput(event: input)
    }
    h.deactivate()
    return false
  }

  private func updateNumberQuickInputState() {
    let h = numberQuickInputHandler
    guard let session = session else { return }
    let candidates = h.generateCandidates()
    let hint = h.generateDisplayHint()
    let newState = State.ofNumberInput(
      precedingText: h.precedingText,
      numberBuffer: h.numberBuffer,
      candidates: candidates,
      displayHint: hint
    )
    session.switchState(newState)
  }
}
