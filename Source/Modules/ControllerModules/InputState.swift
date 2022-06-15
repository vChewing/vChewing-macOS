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

// 註：所有 InputState 型別均不適合使用 Struct，因為 Struct 無法相互繼承派生。

/// Represents the states for the input method controller.
///
/// An input method is actually a finite state machine. It receives the inputs
/// from hardware like keyboard and mouse, changes its state, updates user
/// interface by the state, and finally produces the text output and then them
/// to the client apps. It should be a one-way data flow, and the user interface
/// and text output should follow unconditionally one single data source.
///
/// The InputState class is for representing what the input controller is doing,
/// and the place to store the variables that could be used. For example, the
/// array for the candidate list is useful only when the user is choosing a
/// candidate, and the array should not exist when the input controller is in
/// another state.
///
/// They are immutable objects. When the state changes, the controller should
/// create a new state object to replace the current state instead of modifying
/// the existing one.
///
/// The input controller has following possible states:
///
/// - Deactivated: The user is not using the input method yet.
/// - Empty: The user has switched to this input method but inputted nothing yet,
///   or, he or she has committed text into the client apps and starts a new
///   input phase.
/// - Committing: The input controller is sending text to the client apps.
/// - Inputting: The user has inputted something and the input buffer is
///   visible.
/// - Marking: The user is creating a area in the input buffer and about to
///   create a new user phrase.
/// - Choosing Candidate: The candidate window is open to let the user to choose
///   one among the candidates.
class InputState {
  /// Represents that the input controller is deactivated.
  class Deactivated: InputState {
    var description: String {
      "<InputState.Deactivated>"
    }
  }

  // MARK: -

  /// Represents that the composing buffer is empty.
  class Empty: InputState {
    var composingBuffer: String {
      ""
    }

    var description: String {
      "<InputState.Empty>"
    }
  }

  // MARK: -

  /// Represents that the composing buffer is empty.
  class EmptyIgnoringPreviousState: Empty {
    override var description: String {
      "<InputState.EmptyIgnoringPreviousState>"
    }
  }

  // MARK: -

  /// Represents that the input controller is committing text into client app.
  class Committing: InputState {
    private(set) var poppedText: String = ""

    convenience init(poppedText: String) {
      self.init()
      self.poppedText = poppedText
    }

    var description: String {
      "<InputState.Committing poppedText:\(poppedText)>"
    }
  }

  // MARK: -

  /// Represents that the composing buffer is not empty.
  class NotEmpty: InputState {
    private(set) var composingBuffer: String
    private(set) var cursorIndex: Int = 0 { didSet { cursorIndex = max(cursorIndex, 0) } }

    init(composingBuffer: String, cursorIndex: Int) {
      self.composingBuffer = composingBuffer
      self.cursorIndex = cursorIndex
    }

    var description: String {
      "<InputState.NotEmpty, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
    }
  }

  // MARK: -

  /// Represents that the user is inputting text.
  class Inputting: NotEmpty {
    var poppedText: String = ""
    var tooltip: String = ""

    override init(composingBuffer: String, cursorIndex: Int) {
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
    }

    var attributedString: NSAttributedString {
      let attributedString = NSAttributedString(
        string: composingBuffer,
        attributes: [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 0,
        ]
      )
      return attributedString
    }

    override var description: String {
      "<InputState.Inputting, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>, poppedText:\(poppedText)>"
    }
  }

  // MARK: -

  /// Represents that the user is marking a range in the composing buffer.
  class Marking: NotEmpty {
    private var allowedMarkRange: ClosedRange<Int> = mgrPrefs.minCandidateLength...mgrPrefs.maxCandidateLength
    private(set) var markerIndex: Int = 0 { didSet { markerIndex = max(markerIndex, 0) } }
    private(set) var markedRange: Range<Int>
    private var literalMarkedRange: Range<Int> {
      let lowerBoundLiteral = composingBuffer.charIndexLiteral(from: markedRange.lowerBound)
      let upperBoundLiteral = composingBuffer.charIndexLiteral(from: markedRange.upperBound)
      return lowerBoundLiteral..<upperBoundLiteral
    }

    private var deleteTargetExists = false
    var tooltip: String {
      if composingBuffer.count != readings.count {
        ctlInputMethod.tooltipController.setColor(state: .redAlert)
        return NSLocalizedString(
          "⚠︎ Unhandlable: Chars and Readings in buffer doesn't match.", comment: ""
        )
      }
      if mgrPrefs.phraseReplacementEnabled {
        ctlInputMethod.tooltipController.setColor(state: .warning)
        return NSLocalizedString(
          "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", comment: ""
        )
      }
      if markedRange.isEmpty {
        return ""
      }

      let text = composingBuffer.utf16SubString(with: markedRange)
      if literalMarkedRange.count < allowedMarkRange.lowerBound {
        ctlInputMethod.tooltipController.setColor(state: .denialInsufficiency)
        return String(
          format: NSLocalizedString(
            "\"%@\" length must ≥ 2 for a user phrase.", comment: ""
          ), text
        )
      } else if literalMarkedRange.count > allowedMarkRange.upperBound {
        ctlInputMethod.tooltipController.setColor(state: .denialOverflow)
        return String(
          format: NSLocalizedString(
            "\"%@\" length should ≤ %d for a user phrase.", comment: ""
          ),
          text, allowedMarkRange.upperBound
        )
      }

      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      let exist = mgrLangModel.checkIfUserPhraseExist(
        userPhrase: text, mode: ctlInputMethod.currentKeyHandler.inputMode, key: joined
      )
      if exist {
        deleteTargetExists = exist
        ctlInputMethod.tooltipController.setColor(state: .prompt)
        return String(
          format: NSLocalizedString(
            "\"%@\" already exists: ENTER to boost, \n SHIFT+CMD+ENTER to exclude.", comment: ""
          ), text
        )
      }
      ctlInputMethod.tooltipController.resetColor()
      return String(
        format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: ""),
        text
      )
    }

    var tooltipForInputting: String = ""
    private(set) var readings: [String]

    init(composingBuffer: String, cursorIndex: Int, markerIndex: Int, readings: [String]) {
      self.markerIndex = markerIndex
      let begin = min(cursorIndex, markerIndex)
      let end = max(cursorIndex, markerIndex)
      markedRange = begin..<end
      self.readings = readings
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
    }

    var attributedString: NSAttributedString {
      let attributedString = NSMutableAttributedString(string: composingBuffer)
      let end = markedRange.upperBound

      attributedString.setAttributes(
        [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 0,
        ], range: NSRange(location: 0, length: markedRange.lowerBound)
      )
      attributedString.setAttributes(
        [
          .underlineStyle: NSUnderlineStyle.thick.rawValue,
          .markedClauseSegment: 1,
        ],
        range: NSRange(
          location: markedRange.lowerBound,
          length: markedRange.upperBound - markedRange.lowerBound
        )
      )
      attributedString.setAttributes(
        [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 2,
        ],
        range: NSRange(
          location: end,
          length: composingBuffer.utf16.count - end
        )
      )
      return attributedString
    }

    override var description: String {
      "<InputState.Marking, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex), markedRange:\(markedRange)>"
    }

    var convertedToInputting: Inputting {
      let state = Inputting(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
      state.tooltip = tooltipForInputting
      return state
    }

    var validToWrite: Bool {
      /// The input method allows users to input a string whose length differs
      /// from the amount of Bopomofo readings. In this case, the range
      /// in the composing buffer and the readings could not match, so
      /// we disable the function to write user phrases in this case.
      /// 這裡的 deleteTargetExists 是防止使用者排除「詞庫內尚未存在的詞」，
      /// 免得使用者誤操作之後靠北「我怎麼敲不了這個詞？」之類的。
      ((composingBuffer.count != readings.count)
        || (ctlInputMethod.areWeDeleting && !deleteTargetExists))
        ? false
        : allowedMarkRange.contains(literalMarkedRange.count)
    }

    var chkIfUserPhraseExists: Bool {
      let text = composingBuffer.utf16SubString(with: markedRange)
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      return mgrLangModel.checkIfUserPhraseExist(
        userPhrase: text, mode: ctlInputMethod.currentKeyHandler.inputMode, key: joined
      )
    }

    var userPhrase: String {
      let text = composingBuffer.utf16SubString(with: markedRange)
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      return "\(text) \(joined)"
    }

    var userPhraseConverted: String {
      let text =
        OpenCCBridge.crossConvert(composingBuffer.utf16SubString(with: markedRange)) ?? ""
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      let convertedMark = "#𝙊𝙥𝙚𝙣𝘾𝘾"
      return "\(text) \(joined)\t\(convertedMark)"
    }
  }

  // MARK: -

  /// Represents that the user is choosing in a candidates list.
  class ChoosingCandidate: NotEmpty {
    private(set) var candidates: [String]
    private(set) var isTypingVertical: Bool

    init(composingBuffer: String, cursorIndex: Int, candidates: [String], isTypingVertical: Bool) {
      self.candidates = candidates
      self.isTypingVertical = isTypingVertical
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
    }

    var attributedString: NSAttributedString {
      let attributedString = NSAttributedString(
        string: composingBuffer,
        attributes: [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 0,
        ]
      )
      return attributedString
    }

    override var description: String {
      "<InputState.ChoosingCandidate, candidates:\(candidates), isTypingVertical:\(isTypingVertical),  composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
    }
  }

  // MARK: -

  /// Represents that the user is choosing in a candidates list
  /// in the associated phrases mode.
  class AssociatedPhrases: InputState {
    private(set) var candidates: [String] = []
    private(set) var isTypingVertical: Bool = false
    init(candidates: [String], isTypingVertical: Bool) {
      self.candidates = candidates
      self.isTypingVertical = isTypingVertical
      super.init()
    }

    var description: String {
      "<InputState.AssociatedPhrases, candidates:\(candidates), isTypingVertical:\(isTypingVertical)>"
    }
  }

  class SymbolTable: ChoosingCandidate {
    var node: SymbolNode

    init(node: SymbolNode, isTypingVertical: Bool) {
      self.node = node
      let candidates = node.children?.map(\.title) ?? [String]()
      super.init(
        composingBuffer: "", cursorIndex: 0, candidates: candidates,
        isTypingVertical: isTypingVertical
      )
    }

    // InputState.SymbolTable 這個狀態比較特殊，不能把真空組字區交出去。
    // 不然的話，在絕大多數終端機類應用當中、以及在 MS Word 等軟體當中
    // 會出現符號選字窗無法響應方向鍵的問題。
    // 如有誰要修奇摩注音的一點通選單的話，修復原理也是一樣的。
    // Crediting Qwertyyb: https://github.com/qwertyyb/Fire/issues/55#issuecomment-1133497700
    override var attributedString: NSAttributedString {
      let attributedString = NSAttributedString(
        string: " ",
        attributes: [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 0,
        ]
      )
      return attributedString
    }

    override var description: String {
      "<InputState.SymbolTable, candidates:\(candidates), isTypingVertical:\(isTypingVertical),  composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
    }
  }
}
