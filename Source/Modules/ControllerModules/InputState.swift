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

// 用以讓每個狀態自描述的 enum。
enum StateType {
  case ofDeactivated
  case ofAssociatedPhrases
  case ofEmpty
  case ofEmptyIgnorePreviousState
  case ofCommitting
  case ofNotEmpty
  case ofInputting
  case ofMarking
  case ofChooseCandidate
  case ofSymbolTable
}

// 所有 InputState 均遵守該協定：
protocol InputStateProtocol {
  var type: StateType { get }
}

/// 此型別用以呈現輸入法控制器（ctlInputMethod）的各種狀態。
///
/// 從實際角度來看，輸入法屬於有限態械（Finite State Machine）。其藉由滑鼠/鍵盤
/// 等輸入裝置接收輸入訊號，據此切換至對應的狀態，再根據狀態更新使用者介面內容，
/// 最終生成文字輸出、遞交給接收文字輸入行為的客體應用。此乃單向資訊流序，且使用
/// 者介面內容與文字輸出均無條件地遵循某一個指定的資料來源。
///
/// InputState 型別用以呈現輸入法控制器正在做的事情，且分狀態儲存各種狀態限定的
/// 常數與變數。對輸入法而言，使用狀態模式（而非策略模式）來做這種常數變數隔離，
/// 可能會讓新手覺得會有些牛鼎烹雞，卻實際上變相減少了在程式維護方面的管理難度、
/// 不需要再在某個狀態下為了該狀態不需要的變數與常數的處置策略而煩惱。
///
/// 對 InputState 型別下的諸多狀態的切換，應以生成新副本來取代舊有副本的形式來完
/// 成。唯一例外是 InputState.Marking、擁有可以將自身轉變為 InputState.Inputting
/// 的成員函式，但也只是生成副本、來交給輸入法控制器來處理而已。
///
/// 輸入法控制器持下述狀態：
///
/// - .Deactivated: 使用者沒在使用輸入法。
/// - .AssociatedPhrases: 逐字選字模式內的聯想詞輸入狀態。因為逐字選字模式不需要在
///   組字區內存入任何東西，所以該狀態不受 .NotEmpty 的管轄。
/// - .Empty: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。抑或是剛剛敲字遞交給
///   客體應用、準備新的輸入行為。
/// - .EmptyIgnorePreviousState: 與 Empty 類似，但會扔掉上一個狀態的內容、不將這些
///   內容遞交給客體應用。該狀態在處理完畢之後會被立刻切換至 .Empty()。
/// - .Committing: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
/// - .NotEmpty: 非空狀態，是一種狀態大類、用以派生且代表下述諸狀態。
/// - .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
/// - .Marking: 使用者在組字區內標記某段範圍，可以決定是添入新詞、還是將這個範圍的
///   詞音組合放入語彙濾除清單。
/// - .ChoosingCandidate: 叫出選字窗、允許使用者選字。
/// - .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
enum InputState {
  /// .Deactivated: 使用者沒在使用輸入法。
  class Deactivated: InputStateProtocol {
    public var type: StateType { .ofDeactivated }
    var description: String {
      "<InputState.Deactivated>"
    }
  }

  // MARK: -

  /// .Empty: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。
  /// 抑或是剛剛敲字遞交給客體應用、準備新的輸入行為。
  class Empty: InputStateProtocol {
    public var type: StateType { .ofEmpty }

    var composingBuffer: String {
      ""
    }

    var description: String {
      "<InputState.Empty>"
    }
  }

  // MARK: -

  /// .EmptyIgnorePreviousState: 與 Empty 類似，
  /// 但會扔掉上一個狀態的內容、不將這些內容遞交給客體應用。
  /// 該狀態在處理完畢之後會被立刻切換至 .Empty()。
  class EmptyIgnoringPreviousState: Empty {
    override public var type: StateType { .ofEmptyIgnorePreviousState }
    override var description: String {
      "<InputState.EmptyIgnoringPreviousState>"
    }
  }

  // MARK: -

  /// .Committing: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
  class Committing: InputStateProtocol {
    public var type: StateType { .ofCommitting }
    private(set) var textToCommit: String = ""

    convenience init(textToCommit: String) {
      self.init()
      self.textToCommit = textToCommit
    }

    var description: String {
      "<InputState.Committing textToCommit:\(textToCommit)>"
    }
  }

  // MARK: -

  /// .AssociatedPhrases: 逐字選字模式內的聯想詞輸入狀態。
  /// 因為逐字選字模式不需要在組字區內存入任何東西，所以該狀態不受 .NotEmpty 的管轄。
  class AssociatedPhrases: InputStateProtocol {
    public var type: StateType { .ofAssociatedPhrases }
    private(set) var candidates: [String] = []
    private(set) var isTypingVertical: Bool = false
    init(candidates: [String], isTypingVertical: Bool) {
      self.candidates = candidates
      self.isTypingVertical = isTypingVertical
    }

    var description: String {
      "<InputState.AssociatedPhrases, candidates:\(candidates), isTypingVertical:\(isTypingVertical)>"
    }
  }

  // MARK: -

  /// .NotEmpty: 非空狀態，是一種狀態大類、用以派生且代表下述諸狀態。
  /// - .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
  /// - .Marking: 使用者在組字區內標記某段範圍，可以決定是添入新詞、
  ///   還是將這個範圍的詞音組合放入語彙濾除清單。
  /// - .ChoosingCandidate: 叫出選字窗、允許使用者選字。
  /// - .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
  class NotEmpty: InputStateProtocol {
    public var type: StateType { .ofNotEmpty }
    private(set) var composingBuffer: String
    private(set) var cursorIndex: Int = 0 { didSet { cursorIndex = max(cursorIndex, 0) } }
    public var composingBufferConverted: String {
      let converted = IME.kanjiConversionIfRequired(composingBuffer)
      if converted.utf16.count != composingBuffer.utf16.count
        || converted.count != composingBuffer.count
      {
        return composingBuffer
      }
      return converted
    }

    init(composingBuffer: String, cursorIndex: Int) {
      self.composingBuffer = composingBuffer
      defer { self.cursorIndex = cursorIndex }
    }

    var attributedString: NSMutableAttributedString {
      /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
      /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
      let attributedString = NSMutableAttributedString(
        string: composingBufferConverted,
        attributes: [
          .underlineStyle: NSUnderlineStyle.single.rawValue,
          .markedClauseSegment: 0,
        ]
      )
      return attributedString
    }

    var description: String {
      "<InputState.NotEmpty, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
    }
  }

  // MARK: -

  /// .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
  class Inputting: NotEmpty {
    override public var type: StateType { .ofInputting }
    var textToCommit: String = ""
    var tooltip: String = ""

    override init(composingBuffer: String, cursorIndex: Int) {
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
    }

    override var description: String {
      "<InputState.Inputting, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>, textToCommit:\(textToCommit)>"
    }
  }

  // MARK: -

  /// .Marking: 使用者在組字區內標記某段範圍，可以決定是添入新詞、
  /// 還是將這個範圍的詞音組合放入語彙濾除清單。
  class Marking: NotEmpty {
    override public var type: StateType { .ofMarking }
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
        userPhrase: text, mode: IME.currentInputMode, key: joined
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
      let begin = min(cursorIndex, markerIndex)
      let end = max(cursorIndex, markerIndex)
      markedRange = begin..<end
      self.readings = readings
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
      defer { self.markerIndex = markerIndex }
    }

    override var attributedString: NSMutableAttributedString {
      /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
      /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
      let attributedString = NSMutableAttributedString(string: composingBufferConverted)
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
        userPhrase: text, mode: IME.currentInputMode, key: joined
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

  /// .ChoosingCandidate: 叫出選字窗、允許使用者選字。
  class ChoosingCandidate: NotEmpty {
    override public var type: StateType { .ofChooseCandidate }
    private(set) var candidates: [String]
    private(set) var isTypingVertical: Bool

    init(composingBuffer: String, cursorIndex: Int, candidates: [String], isTypingVertical: Bool) {
      self.candidates = candidates
      self.isTypingVertical = isTypingVertical
      super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
    }

    override var description: String {
      "<InputState.ChoosingCandidate, candidates:\(candidates), isTypingVertical:\(isTypingVertical),  composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
    }
  }

  // MARK: -

  /// .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
  class SymbolTable: ChoosingCandidate {
    override public var type: StateType { .ofSymbolTable }
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
    override var attributedString: NSMutableAttributedString {
      let attributedString = NSMutableAttributedString(
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
