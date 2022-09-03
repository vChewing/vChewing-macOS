// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// 註：所有 InputState 型別均不適合使用 Struct，因為 Struct 無法相互繼承派生。

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
/// - .Abortion: 與 Empty 類似，但會扔掉上一個狀態的內容、不將這些
///   內容遞交給客體應用。該狀態在處理完畢之後會被立刻切換至 .Empty()。
/// - .Committing: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
/// - .NotEmpty: 非空狀態，是一種狀態大類、用以派生且代表下述諸狀態。
/// - .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
/// - .Marking: 使用者在組字區內標記某段範圍，可以決定是添入新詞、還是將這個範圍的
///   詞音組合放入語彙濾除清單。
/// - .ChoosingCandidate: 叫出選字窗、允許使用者選字。
/// - .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
public enum InputState {
  /// .Deactivated: 使用者沒在使用輸入法。
  class Deactivated: InputStateProtocol {
    var node: SymbolNode = .init("")
    var attributedString: NSAttributedString = .init()
    var data: StateData = .init()
    var textToCommit: String = ""
    var tooltip: String = ""
    let displayedText: String = ""
    let hasBuffer: Bool = false
    let isCandidateContainer: Bool = false
    public var type: StateType { .ofDeactivated }
  }

  // MARK: -

  /// .Empty: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。
  /// 抑或是剛剛敲字遞交給客體應用、準備新的輸入行為。
  class Empty: InputStateProtocol {
    var node: SymbolNode = .init("")
    var attributedString: NSAttributedString = .init()
    var data: StateData = .init()
    var textToCommit: String = ""
    var tooltip: String = ""
    let hasBuffer: Bool = false
    let isCandidateContainer: Bool = false
    public var type: StateType { .ofEmpty }
    let displayedText: String = ""
  }

  // MARK: -

  /// .Abortion: 與 Empty 類似，
  /// 但會扔掉上一個狀態的內容、不將這些內容遞交給客體應用。
  /// 該狀態在處理完畢之後會被立刻切換至 .Empty()。
  class Abortion: Empty {
    override public var type: StateType { .ofAbortion }
  }

  // MARK: -

  /// .Committing: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
  class Committing: InputStateProtocol {
    var node: SymbolNode = .init("")
    var attributedString: NSAttributedString = .init()
    var data: StateData = .init()
    var tooltip: String = ""
    var textToCommit: String = ""
    let displayedText: String = ""
    let hasBuffer: Bool = false
    let isCandidateContainer: Bool = false
    public var type: StateType { .ofCommitting }

    init(textToCommit: String) {
      self.textToCommit = textToCommit
      ChineseConverter.ensureCurrencyNumerals(target: &self.textToCommit)
    }
  }

  // MARK: -

  /// .AssociatedPhrases: 逐字選字模式內的聯想詞輸入狀態。
  /// 因為逐字選字模式不需要在組字區內存入任何東西，所以該狀態不受 .NotEmpty 的管轄。
  class Associates: InputStateProtocol {
    var node: SymbolNode = .init("")
    var attributedString: NSAttributedString = .init()
    var data: StateData = .init()
    var textToCommit: String = ""
    var tooltip: String = ""
    let displayedText: String = ""
    let hasBuffer: Bool = false
    let isCandidateContainer: Bool = true
    public var type: StateType { .ofAssociates }
    var candidates: [(String, String)] { data.candidates }
    init(candidates: [(String, String)]) {
      data.candidates = candidates
      attributedString = {
        let attributedString = NSMutableAttributedString(
          string: " ",
          attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .markedClauseSegment: 0,
          ]
        )
        return attributedString
      }()
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
    var node: SymbolNode = .init("")
    var attributedString: NSAttributedString = .init()
    var data: StateData = .init()
    var tooltip: String = ""
    var textToCommit: String = ""
    let hasBuffer: Bool = true
    var isCandidateContainer: Bool { false }
    public var type: StateType { .ofNotEmpty }
    private(set) var displayedText: String
    private(set) var cursorIndex: Int = 0 { didSet { cursorIndex = max(cursorIndex, 0) } }
    private(set) var reading: String = ""
    private(set) var nodeValuesArray = [String]()
    public var displayedTextConverted: String {
      let converted = IME.kanjiConversionIfRequired(displayedText)
      if converted.utf16.count != displayedText.utf16.count
        || converted.count != displayedText.count
      {
        return displayedText
      }
      return converted
    }

    public var committingBufferConverted: String { displayedTextConverted }

    init(displayedText: String, cursorIndex: Int, reading: String = "", nodeValuesArray: [String] = []) {
      self.displayedText = displayedText
      self.reading = reading
      // 為了簡化運算，將 reading 本身也變成一個字詞節點。
      if !reading.isEmpty {
        var newNodeValuesArray = [String]()
        var temporaryNode = ""
        var charCounter = 0
        for node in nodeValuesArray {
          for char in node {
            if charCounter == cursorIndex - reading.utf16.count {
              newNodeValuesArray.append(temporaryNode)
              temporaryNode = ""
              newNodeValuesArray.append(reading)
            }
            temporaryNode += String(char)
            charCounter += 1
          }
          newNodeValuesArray.append(temporaryNode)
          temporaryNode = ""
        }
        self.nodeValuesArray = newNodeValuesArray
      } else {
        self.nodeValuesArray = nodeValuesArray
      }
      defer {
        self.cursorIndex = cursorIndex
        self.attributedString = {
          /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
          /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
          let attributedString = NSMutableAttributedString(string: displayedTextConverted)
          var newBegin = 0
          for (i, neta) in nodeValuesArray.enumerated() {
            attributedString.setAttributes(
              [
                /// 不能用 .thick，否則會看不到游標。
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .markedClauseSegment: i,
              ], range: NSRange(location: newBegin, length: neta.utf16.count)
            )
            newBegin += neta.utf16.count
          }
          return attributedString
        }()
      }
    }
  }

  // MARK: -

  /// .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
  class Inputting: NotEmpty {
    override public var type: StateType { .ofInputting }
    override public var committingBufferConverted: String {
      let committingBuffer = nodeValuesArray.joined()
      let converted = IME.kanjiConversionIfRequired(committingBuffer)
      if converted.utf16.count != displayedText.utf16.count
        || converted.count != displayedText.count
      {
        return displayedText
      }
      return converted
    }

    override init(displayedText: String, cursorIndex: Int, reading: String = "", nodeValuesArray: [String] = []) {
      super.init(
        displayedText: displayedText, cursorIndex: cursorIndex, reading: reading, nodeValuesArray: nodeValuesArray
      )
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
      let lowerBoundLiteral = displayedText.charIndexLiteral(from: markedRange.lowerBound)
      let upperBoundLiteral = displayedText.charIndexLiteral(from: markedRange.upperBound)
      return lowerBoundLiteral..<upperBoundLiteral
    }

    var literalReadingThread: String {
      var arrOutput = [String]()
      for neta in readings[literalMarkedRange] {
        var neta = neta
        if neta.isEmpty { continue }
        if neta.contains("_") {
          arrOutput.append("??")
          continue
        }
        if mgrPrefs.showHanyuPinyinInCompositionBuffer {  // 恢復陰平標記->注音轉拼音->轉教科書式標調
          neta = Tekkon.restoreToneOneInZhuyinKey(target: neta)
          neta = Tekkon.cnvPhonaToHanyuPinyin(target: neta)
          neta = Tekkon.cnvHanyuPinyinToTextbookStyle(target: neta)
        } else {
          neta = Tekkon.cnvZhuyinChainToTextbookReading(target: neta)
        }
        arrOutput.append(neta)
      }
      return arrOutput.joined(separator: " ")
    }

    private var markedTargetExists = false

    var tooltipForMarking: String {
      if displayedText.count != readings.count {
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

      let text = displayedText.utf16SubString(with: markedRange)
      if literalMarkedRange.count < allowedMarkRange.lowerBound {
        ctlInputMethod.tooltipController.setColor(state: .denialInsufficiency)
        return String(
          format: NSLocalizedString(
            "\"%@\" length must ≥ 2 for a user phrase.", comment: ""
          ) + "\n//  " + literalReadingThread, text
        )
      } else if literalMarkedRange.count > allowedMarkRange.upperBound {
        ctlInputMethod.tooltipController.setColor(state: .denialOverflow)
        return String(
          format: NSLocalizedString(
            "\"%@\" length should ≤ %d for a user phrase.", comment: ""
          ) + "\n//  " + literalReadingThread, text, allowedMarkRange.upperBound
        )
      }

      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      let exist = mgrLangModel.checkIfUserPhraseExist(
        userPhrase: text, mode: IME.currentInputMode, key: joined
      )
      if exist {
        markedTargetExists = exist
        ctlInputMethod.tooltipController.setColor(state: .prompt)
        return String(
          format: NSLocalizedString(
            "\"%@\" already exists: ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.",
            comment: ""
          ) + "\n//  " + literalReadingThread, text
        )
      }
      ctlInputMethod.tooltipController.resetColor()
      return String(
        format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: "") + "\n//  "
          + literalReadingThread,
        text
      )
    }

    var tooltipBackupForInputting: String = ""
    private(set) var readings: [String]

    init(
      displayedText: String, cursorIndex: Int, markerIndex: Int, readings: [String], nodeValuesArray: [String] = []
    ) {
      let begin = min(cursorIndex, markerIndex)
      let end = max(cursorIndex, markerIndex)
      markedRange = begin..<end
      self.readings = readings
      super.init(
        displayedText: displayedText, cursorIndex: cursorIndex, nodeValuesArray: nodeValuesArray
      )
      defer {
        self.markerIndex = markerIndex
        tooltip = tooltipForMarking
        attributedString = {
          /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
          /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
          let attributedString = NSMutableAttributedString(string: displayedTextConverted)
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
              length: displayedText.utf16.count - end
            )
          )
          return attributedString
        }()
      }
    }

    var convertedToInputting: Inputting {
      let state = Inputting(
        displayedText: displayedText, cursorIndex: cursorIndex, reading: reading, nodeValuesArray: nodeValuesArray
      )
      state.tooltip = tooltipBackupForInputting
      return state
    }

    var isFilterable: Bool { markedTargetExists ? allowedMarkRange.contains(literalMarkedRange.count) : false }

    var bufferReadingCountMisMatch: Bool { displayedText.count != readings.count }

    var chkIfUserPhraseExists: Bool {
      let text = displayedText.utf16SubString(with: markedRange)
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      return mgrLangModel.checkIfUserPhraseExist(
        userPhrase: text, mode: IME.currentInputMode, key: joined
      )
    }

    var userPhrase: String {
      let text = displayedText.utf16SubString(with: markedRange)
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      let nerfedScore = ctlInputMethod.areWeNerfing && markedTargetExists ? " -114.514" : ""
      return "\(text) \(joined)\(nerfedScore)"
    }

    var userPhraseConverted: String {
      let text =
        ChineseConverter.crossConvert(displayedText.utf16SubString(with: markedRange)) ?? ""
      let selectedReadings = readings[literalMarkedRange]
      let joined = selectedReadings.joined(separator: "-")
      let nerfedScore = ctlInputMethod.areWeNerfing && markedTargetExists ? " -114.514" : ""
      let convertedMark = "#𝙃𝙪𝙢𝙖𝙣𝘾𝙝𝙚𝙘𝙠𝙍𝙚𝙦𝙪𝙞𝙧𝙚𝙙"
      return "\(text) \(joined)\(nerfedScore)\t\(convertedMark)"
    }
  }

  // MARK: -

  /// .ChoosingCandidate: 叫出選字窗、允許使用者選字。
  class ChoosingCandidate: NotEmpty {
    override var isCandidateContainer: Bool { true }
    override public var type: StateType { .ofCandidates }
    var candidates: [(String, String)]
    // 該變數改為可以隨時更改的內容，不然的話 ctlInputMethod.candidateSelectionChanged() 會上演俄羅斯套娃（崩潰）。
    public var chosenCandidateString: String = "" {
      didSet {
        // 去掉讀音資訊，且最終留存「執行康熙 / JIS 轉換之前」的結果。
        if chosenCandidateString.contains("\u{17}") {
          chosenCandidateString = String(chosenCandidateString.split(separator: "\u{17}")[0])
        }
        if !chosenCandidateString.contains("\u{1A}") { return }
        chosenCandidateString = String(chosenCandidateString.split(separator: "\u{1A}").reversed()[0])
      }
    }

    init(
      displayedText: String, cursorIndex: Int, candidates: [(String, String)],
      nodeValuesArray: [String] = []
    ) {
      self.candidates = candidates
      super.init(displayedText: displayedText, cursorIndex: cursorIndex, nodeValuesArray: nodeValuesArray)
    }
  }

  // MARK: -

  /// .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
  class SymbolTable: ChoosingCandidate {
    override public var type: StateType { .ofSymbolTable }

    init(node: SymbolNode, previous: SymbolNode? = nil) {
      super.init(displayedText: "", cursorIndex: 0, candidates: [])
      self.node = node
      if let previous = previous {
        self.node.previous = previous
      }
      let candidates = node.children?.map(\.title) ?? [String]()
      self.candidates = candidates.map { ("", $0) }

      // InputState.SymbolTable 這個狀態比較特殊，不能把真空組字區交出去。
      // 不然的話，在絕大多數終端機類應用當中、以及在 MS Word 等軟體當中
      // 會出現符號選字窗無法響應方向鍵的問題。
      // 如有誰要修奇摩注音的一點通選單的話，修復原理也是一樣的。
      // Crediting Qwertyyb: https://github.com/qwertyyb/Fire/issues/55#issuecomment-1133497700
      attributedString = {
        let attributedString = NSMutableAttributedString(
          string: " ",
          attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .markedClauseSegment: 0,
          ]
        )
        return attributedString
      }()
    }
  }
}
