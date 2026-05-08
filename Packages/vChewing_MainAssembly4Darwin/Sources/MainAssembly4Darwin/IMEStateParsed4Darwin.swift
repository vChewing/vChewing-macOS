// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - IMEStateParsed4Darwin

/// 即用即拋的 Darwin 端 IMEState 包裝器。
///
/// 所有需要 `NSAttributedString`、`ChineseConverter`、`LMMgr`、`Tekkon`、`InputSession`
/// 等 Darwin-only 依賴的 IMEState 屬性均集中於此。Session 層面永久儲存的仍是純 `IMEState`。
@frozen
public struct IMEStateParsed4Darwin {
  // MARK: Lifecycle

  public init(_ state: IMEState) {
    self.state = state
  }

  // MARK: Public

  public let state: IMEState
}

// MARK: - AttrStrULStyle

extension IMEStateParsed4Darwin {
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

extension IMEStateParsed4Darwin {
  private func convertTextIfNeeded(_ rawStr: String) -> String {
    var result = ChineseConverter.kanjiConversionIfRequired(rawStr)
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

extension IMEStateParsed4Darwin {
  public var markedTargetExists: Bool {
    let pair = state.data.userPhraseKVPair
    return LMMgr.checkIfPhrasePairExists(
      userPhrase: pair.value,
      mode: IMEApp.currentInputMode,
      keyArray: pair.keyArray
    )
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    let pair = state.data.userPhraseKVPair
    return LMMgr.checkIfPhrasePairIsFiltered(
      userPhrase: pair.value,
      mode: IMEApp.currentInputMode,
      keyArray: pair.keyArray
    )
  }
}

// MARK: - attributedString properties (backward compat on IMEStateData)

extension IMEStateData {
  /// 繁簡轉換
  private func convertTextIfNeeded(_ rawStr: String) -> String {
    var result = ChineseConverter.kanjiConversionIfRequired(rawStr)
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
    return LMMgr.checkIfPhrasePairExists(
      userPhrase: pair.value,
      mode: IMEApp.currentInputMode,
      keyArray: pair.keyArray
    )
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    let pair = userPhraseKVPair
    return LMMgr.checkIfPhrasePairIsFiltered(
      userPhrase: pair.value,
      mode: IMEApp.currentInputMode,
      keyArray: pair.keyArray
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
    IMEStateParsed4Darwin.AttrStrULStyle.single.getMarkedAttrStr(
      char.description,
      clauseSegment: 0
    )
  }

  public func getAttributedStringNormal(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    IMEStateParsed4Darwin.AttrStrULStyle.pack(
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
    let pairs: [IMEStateParsed4Darwin.AttrStrULStyle.StyledPair] = [
      (converted[range1].joined(), .single),
      (converted[range2].joined(), .thick),
      (converted[range3].joined(), .single),
    ]
    return IMEStateParsed4Darwin.AttrStrULStyle.pack(pairs)
  }
}

// MARK: - attributedString (wrapper)

extension IMEStateParsed4Darwin {
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

extension IMEStateParsed4Darwin {
  public var readingThreadForDisplay: String {
    var arrOutput = [String]()
    for neta in state.data.markedReadings {
      if neta.isEmpty { continue }
      if neta.contains("_") {
        arrOutput.append("??")
        continue
      }
      neta.components(separatedBy: "-").forEach { subNeta in
        var subNeta = subNeta
        if !PrefMgr.shared.cassetteEnabled {
          if PrefMgr.shared.showHanyuPinyinInCompositionBuffer,
             PrefMgr.shared.alwaysShowTooltipTextsHorizontally || !InputSession.isVerticalTyping {
            subNeta = Tekkon.restoreToneOneInPhona(target: subNeta)
            subNeta = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: subNeta)
            subNeta = Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: subNeta)
          } else {
            subNeta = Tekkon.cnvPhonaToTextbookStyle(target: subNeta)
          }
        }
        arrOutput.append(subNeta)
      }
    }
    return arrOutput.joined(separator: "\u{A0}")
  }
}

// MARK: - generateTooltipForMarking

extension IMEStateParsed4Darwin {
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
          format: "\"%@\" length must ≥ 2 for a user phrase.".i18n + "\n◆  " + readingDisplay,
          text
        ),
        .denialInsufficiency
      )
    } else if state.markedRange.count > IMEStateData.allowedMarkLengthRange.upperBound {
      return (
        String(
          format: "\"%@\" length should ≤ %d for a user phrase.".i18n + "\n◆  " + readingDisplay,
          text,
          IMEStateData.allowedMarkLengthRange.upperBound
        ),
        .denialOverflow
      )
    }

    if markedTargetExists {
      switch LMMgr.isStateDataFilterableForMarked(state.data) {
      case false:
        return (
          String(
            format: "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf."
              .i18n + "\n◆  " + readingDisplay,
            text
          ),
          .prompt
        )
      case true:
        return (
          String(
            format: "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude."
              .i18n + "\n◆  " + readingDisplay,
            text
          ),
          .prompt
        )
      }
    }

    if markedTargetIsCurrentlyFiltered {
      return (
        String(
          format: "\"%@\" selected. ENTER to unfilter this phrase.".i18n + "\n◆  "
            + readingDisplay,
          text
        ),
        .information
      )
    }

    return (
      String(
        format: "\"%@\" selected. ENTER to add user phrase.".i18n
          + "\n◆  "
          + readingDisplay,
        text
      ),
      .normal
    )
  }
}

// MARK: - hardenVerticalPunctuationsIfNeeded

extension IMEStateParsed4Darwin {
  public static func hardenVerticalPunctuationsIfNeeded(_ target: inout [String]) {
    if !InputSession.isVerticalTyping || !PrefMgr.shared.hardenVerticalPunctuations { return }
    target.indices.forEach { i in
      ChineseConverter.hardenVerticalPunctuations(
        target: &target[i],
        convert: true
      )
    }
  }
}
