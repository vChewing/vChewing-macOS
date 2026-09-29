// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - IMEStateParsed

/// 即用即拋的 IMEState 包裝器。
///
/// 所有需要 `NSAttributedString`、`ChineseConverter`、`SessionHost`、`Tekkon`、
/// `InputSession` 等依賴的 IMEState 屬性均集中於此。Session 層面永久儲存的仍是純 `IMEState`。
@frozen
public struct IMEStateParsed {
  // MARK: Lifecycle

  public init(_ state: IMEState) {
    self.state = state
  }

  // MARK: Public

  public let state: IMEState
}

// MARK: - AttrStrULStyle

extension IMEStateParsed {
  /// IMKInputController 的 `mark(forStyle:)` 只可能會標出這些值。
  /// 該值乃使用 hopper disassembler 分析 IMK 而得出。
  public enum AttrStrULStyle: Int {
    case none = 0
    /// #1, kTSMHiliteConvertedText & kTSMHiliteSelectedRawText
    case single = 1
    /// #2, kTSMHiliteSelectedConvertedText
    case thick = 2
    /// #3, 尚未被 TSM 使用。或可用給 kTSMHiliteSelectedRawText 與 1 區分。
    case double = 3

    // MARK: Public

    public typealias StyledPair = (string: String, style: Self)

    public static func pack(_ pairs: [StyledPair]) -> NSAttributedString {
      let result = NSMutableAttributedString(string: "")
      var clauseSegment = 0
      for (string, style) in pairs {
        guard !string.isEmpty else { continue }
        result.append(style.getMarkedAttrStr(string, clauseSegment: clauseSegment))
        clauseSegment += 1
      }
      return result
    }

    public func getDict(clauseSegment: Int? = nil) -> [NSAttributedString.Key: Any] {
      var result: [NSAttributedString.Key: Any] = [Self.keyName4UL: rawValue]
      result[Self.keyName4CS] = clauseSegment
      return result
    }

    public func getMarkedAttrStr(_ rawStr: String, clauseSegment: Int? = nil) -> NSAttributedString {
      let result = NSMutableAttributedString(string: rawStr)
      let rangeNow = NSRange(location: 0, length: rawStr.utf16.count)
      result.setAttributes(getDict(clauseSegment: clauseSegment), range: rangeNow)
      return result
    }

    // MARK: Private

    private static let keyName4UL = NSAttributedString.Key(
      rawValue: "NSUnderline"
    )

    private static let keyName4CS = NSAttributedString.Key(
      rawValue: "NSMarkedClauseSegment"
    )
  }

  public func getAttributedStringPlaceholder(_ char: Unicode.Scalar = " ") -> NSAttributedString {
    AttrStrULStyle.single.getMarkedAttrStr(
      char.description,
      clauseSegment: 0
    )
  }

  /// - Remark: Converter 為 nil 時不做追加漢字轉換。
  public func getAttributedStringNormal(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    AttrStrULStyle.pack(
      state.displayTextSegments.map {
        (converter?($0) ?? $0, .single)
      }
    )
  }

  /// - Remark: Converter 為 nil 時不做追加漢字轉換。
  public func getAttributedStringMarking(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    let converted = (converter?(state.displayedText) ?? state.displayedText).map(\.description)
    let range2 = state.markedRange
    let range1 = 0 ..< range2.lowerBound
    let range3 = range2.upperBound ..< converted.count
    let pairs: [AttrStrULStyle.StyledPair] = [
      (converted[range1].joined(), .single),
      (converted[range2].joined(), .thick),
      (converted[range3].joined(), .single),
    ]
    return AttrStrULStyle.pack(pairs)
  }
}

// MARK: - convertTextIfNeeded / displayedTextConverted / displayTextSegmentsConverted

extension IMEStateParsed {
  private func convertTextIfNeeded(_ rawStr: String) -> String {
    var result = SessionHost.shared.kanjiConversionIfRequired(rawStr)
    if result.utf16.count != rawStr.utf16.count
      || result.count != rawStr.count {
      result = rawStr
    }
    return result
  }

  public var displayedTextConverted: String {
    convertTextIfNeeded(state.displayedText)
  }

  public var displayTextSegmentsConverted: [String] {
    state.displayTextSegments.map(convertTextIfNeeded)
  }
}

// MARK: - markedTargetExists / markedTargetIsCurrentlyFiltered

extension IMEStateParsed {
  public var markedTargetExists: Bool {
    let pair = state.data.userPhraseKVPair
    return SessionHost.shared.checkIfPhrasePairExists(
      pair.value, IMEApp.currentInputMode, pair.keyArray
    )
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    let pair = state.data.userPhraseKVPair
    return SessionHost.shared.checkIfPhrasePairIsFiltered(
      pair.value, IMEApp.currentInputMode, pair.keyArray
    )
  }
}

// MARK: - attributedString properties (backward compat on IMEStateData)

extension IMEStateData {
  /// 繁簡轉換
  private func convertTextIfNeeded(_ rawStr: String) -> String {
    var result = SessionHost.shared.kanjiConversionIfRequired(rawStr)
    if result.utf16.count != rawStr.utf16.count
      || result.count != rawStr.count {
      result = rawStr
    }
    return result
  }

  public var displayedTextConverted: String {
    convertTextIfNeeded(displayedText)
  }

  public var displayTextSegmentsConverted: [String] {
    displayTextSegments.map(convertTextIfNeeded)
  }

  public var markedTargetExists: Bool {
    let pair = userPhraseKVPair
    return SessionHost.shared.checkIfPhrasePairExists(
      pair.value, IMEApp.currentInputMode, pair.keyArray
    )
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    let pair = userPhraseKVPair
    return SessionHost.shared.checkIfPhrasePairIsFiltered(
      pair.value, IMEApp.currentInputMode, pair.keyArray
    )
  }

  public var attributedStringNormal: NSAttributedString {
    getAttributedStringNormal(convertTextIfNeeded)
  }

  public var attributedStringMarking: NSAttributedString {
    getAttributedStringMarking(convertTextIfNeeded)
  }

  public var attributedStringPlaceholder: NSAttributedString {
    getAttributedStringPlaceholder()
  }

  public func getAttributedStringPlaceholder(_ char: Unicode.Scalar = " ") -> NSAttributedString {
    IMEStateParsed.AttrStrULStyle.single.getMarkedAttrStr(
      char.description,
      clauseSegment: 0
    )
  }

  public func getAttributedStringNormal(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    IMEStateParsed.AttrStrULStyle.pack(
      displayTextSegments.map {
        (converter?($0) ?? $0, .single)
      }
    )
  }

  public func getAttributedStringMarking(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    let converted = (converter?(displayedText) ?? displayedText).map(\.description)
    let range2 = markedRange
    let range1 = 0 ..< range2.lowerBound
    let range3 = range2.upperBound ..< converted.count
    let pairs: [IMEStateParsed.AttrStrULStyle.StyledPair] = [
      (converted[range1].joined(), .single),
      (converted[range2].joined(), .thick),
      (converted[range3].joined(), .single),
    ]
    return IMEStateParsed.AttrStrULStyle.pack(pairs)
  }
}

// MARK: - attributedString (wrapper)

extension IMEStateParsed {
  public var attributedStringNormal: NSAttributedString { state.data.attributedStringNormal }
  public var attributedStringMarking: NSAttributedString { state.data.attributedStringMarking }
  public var attributedStringPlaceholder: NSAttributedString { state.data.attributedStringPlaceholder }

  public var attributedString: NSAttributedString {
    switch state.type {
    case .ofMarking: return state.data.attributedStringMarking
    case .ofCandidates where state.cursor != state.marker: return state.data.attributedStringMarking
    case .ofCandidates where state.cursor == state.marker: break
    case .ofAssociates: return state.data.attributedStringPlaceholder
    case .ofSymbolTable where state.displayedText.isEmpty || state.node.containsCandidateServices:
      return state.data.attributedStringPlaceholder
    case .ofSymbolTable where !state.displayedText.isEmpty: break
    default: break
    }
    return state.data.attributedStringNormal
  }
}

// MARK: - readingThreadForDisplay

extension IMEStateParsed {
  /// 依 Tooltip 既有之讀音呈現規則轉換單一讀音。
  ///
  /// 規則（與 `showTooltip(...)` 決定 Tooltip 排版方向的判準同源）：注音一律轉為教科書式
  /// （輕聲前置）；僅當「以漢語拼音顯示組字區讀音」偏好啟用、且該 Tooltip 會以橫排呈現
  /// （`alwaysShowTooltipTextsHorizontally` 或當前非直排輸入）時，才改以漢語拼音教科書式標調呈現。
  /// 磁帶模式不做任何轉換（讀音鍵本身即為組筆序列）。
  ///
  /// - Important: 本處之讀音由組字器之既有鍵推得（標記狀態下之完整讀音），故與
  ///   `convertReadingForHanyuPinyinDisplay(_:isHanyuPinyin:)` **刻意不同**：此處補記陰平
  ///   （`restoreToneOneInPhona`——該記號正是「完整讀音以無調形態記之」之補正）**且**轉
  ///   教材式標調（`cnvHanyuPinyinToTextbookStyle`）。未完成讀音側兩者皆不為（見該函式）。
  static func convertReadingForTooltip(_ neta: String) -> String {
    let prefs = SessionHost.shared.prefs()
    guard !prefs.cassetteEnabled else { return neta }
    if prefs.showHanyuPinyinInCompositionBuffer,
       prefs.alwaysShowTooltipTextsHorizontally || !InputSession.isVerticalTyping {
      var neta = Tekkon.restoreToneOneInPhona(target: neta)
      neta = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: neta)
      return Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: neta)
    }
    return Tekkon.cnvPhonaToTextbookStyle(target: neta)
  }

  /// 依「以漢語拼音顯示組字區讀音」之判定轉換單一讀音（**與組字區讀音欄逐字同式**）。
  ///
  /// 本函式專供**未完成讀音**（注拼槽之當前拼裝、混打緩衝之消化結果）之呈現，其消費者有二：
  /// 組字區讀音欄之對位物——選字窗頂端之「未完成讀音」pane，以及中英混打之 Tooltip 讀音預覽。
  /// **呈現式即組字區讀音欄那一式**（`cnvPhonaToHanyuPinyin`）：數字標調且附於尾端（無聲調者不附）、
  /// `ü` 作 `v`。與 `convertReadingForTooltip(_:)` 之差別有二：
  /// ① **不問呈現方向**——窗頂 pane 由選字窗以單一橫排文字繪製、不隨直排輸入而轉向，故與
  ///    組字區讀音欄同語義：只要該偏好啟用即改以漢語拼音呈現（Tooltip 之方向判定由呼叫端自理）。
  /// ② **不補陰平記號、亦不轉教材式標調**——本處之讀音可能只是**前綴**（如單聲母 ㄍ），
  ///    補上數字 1 會得 `g1` 這種無母音可附調號之殘形；`cnvHanyuPinyinToTextbookStyle` 另會把
  ///    `nv3` 轉成 `nǚ`、把 `yu` 轉成 `yú` 一類教材寫法，與組字區讀音欄所見不一致。
  /// - Parameter isHanyuPinyin: 假（未啟用該偏好、或處於磁帶模式）時原樣返回；真時轉換。
  /// - Important: 讀音素材本即**拼音字母流**者（拼音狂拼之 romaji 緩衝）不得傳真進來——
  ///   該者已屬拼音，再經注音→拼音之轉換只會多添記號。
  static func convertReadingForHanyuPinyinDisplay(
    _ neta: String,
    isHanyuPinyin: Bool
  )
    -> String {
    guard isHanyuPinyin else { return neta }
    return Tekkon.cnvPhonaToHanyuPinyin(targetJoined: neta)
  }

  public var readingThreadForDisplay: String {
    var arrOutput = [String]()
    for neta in state.data.markedReadings {
      if neta.isEmpty { continue }
      if neta.contains("_") {
        arrOutput.append("??")
        continue
      }
      neta.components(separatedBy: "-").forEach { subNeta in
        arrOutput.append(Self.convertReadingForTooltip(subNeta))
      }
    }
    return arrOutput.joined(separator: "\u{A0}")
  }
}

// MARK: - generateTooltipForMarking

extension IMEStateParsed {
  /// 生成標記狀態的工具提示。取代舊有的 `updateTooltipForMarking()` mutating func。
  /// - Returns: 工具提示字串與顏色狀態的 tuple。
  public func generateTooltipForMarking() -> (tooltip: String, colorState: TooltipColorState) {
    let pair = state.data.userPhraseKVPair
    let readingDisplay = readingThreadForDisplay

    if state.markedRange.isEmpty {
      return ("", .normal)
    }

    let text = pair.value

    if state.markedRange.count < IMEStateData.allowedMarkLengthRange.lowerBound {
      return (
        String(
          format: "i18n:StateOfMarking.Tooltip.PhraseLengthTooShort:%@".i18n + "\n◆  " + readingDisplay,
          text
        ),
        .denialInsufficiency
      )
    } else if state.markedRange.count > IMEStateData.allowedMarkLengthRange.upperBound {
      return (
        String(
          format: "i18n:StateOfMarking.Tooltip.PhraseLengthTooLong:%@%d".i18n + "\n◆  " + readingDisplay,
          text,
          IMEStateData.allowedMarkLengthRange.upperBound
        ),
        .denialOverflow
      )
    }

    if markedTargetExists {
      switch SessionHost.shared.isStateDataFilterableForMarked(state.data) {
      case false:
        return (
          String(
            format: "i18n:StateOfMarking.Tooltip.PhraseExistsBoostNerf:%@".i18n
              + "\n◆  " + readingDisplay,
            text
          ),
          .prompt
        )
      case true:
        return (
          String(
            format: "i18n:StateOfMarking.Tooltip.PhraseExistsBoostNerfExclude:%@".i18n
              + "\n◆  " + readingDisplay,
            text
          ),
          .prompt
        )
      }
    }

    if markedTargetIsCurrentlyFiltered {
      return (
        String(
          format: "i18n:StateOfMarking.Tooltip.SelectedEnterToUnfilter:%@".i18n + "\n◆  "
            + readingDisplay,
          text
        ),
        .information
      )
    }

    return (
      String(
        format: "i18n:StateOfMarking.Tooltip.SelectedEnterToAdd:%@".i18n
          + "\n◆  "
          + readingDisplay,
        text
      ),
      .normal
    )
  }
}

// MARK: - hardenVerticalPunctuationsIfNeeded

extension IMEStateParsed {
  public static func hardenVerticalPunctuationsIfNeeded(_ target: inout [String]) {
    if !InputSession.isVerticalTyping || !SessionHost.shared.prefs().hardenVerticalPunctuations {
      return
    }
    target.indices.forEach { i in
      ChineseConverter.hardenVerticalPunctuations(
        target: &target[i],
        convert: true
      )
    }
  }
}
