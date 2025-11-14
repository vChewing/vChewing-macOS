// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - AttributedString 材料生成器

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

  public var displayedTextConvertedSansReading: String {
    convertTextIfNeeded(displayedTextSansReading)
  }

  public var displayTextSegmentsConverted: [String] {
    displayTextSegments.map(convertTextIfNeeded)
  }

  // MARK: Other data for non-empty states.

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
}

// MARK: - AttributedString 生成器

extension IMEStateData {
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
      let result = NSMutableAttributedString()
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

  public var attributedStringNormal: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    /// 注意：AttributedString 用於顯示，因此包含讀音片段；但其基礎文本（用於計算長度）
    /// 應該是不包含讀音的，以防某些客體應用從 AttributedString 中提取文本時包含讀音。
    let baseText = displayedTextConvertedSansReading
    guard !displayTextSegments.isEmpty else {
      return AttrStrULStyle.single.getMarkedAttrStr(baseText, clauseSegment: 0)
    }
    // 建構屬性字串：使用無讀音的文本作為基礎，但根據 displayTextSegments 分段標記。
    // displayTextSegments 可能包含讀音片段（highlightAtSegment 所指位置），需跳過。
    var segments: [AttrStrULStyle.StyledPair] = []
    var startIndex = baseText.startIndex
    for (idx, segment) in displayTextSegments.enumerated() {
      // 跳過讀音片段
      if let highlightIdx = highlightAtSegment, idx == highlightIdx {
        continue
      }
      let segmentLength = segment.count
      guard segmentLength > 0 else { continue }
      let endIndex = baseText.index(startIndex, offsetBy: segmentLength, limitedBy: baseText.endIndex)
        ?? baseText.endIndex
      let extractedSegment = String(baseText[startIndex..<endIndex])
      segments.append((extractedSegment, .single))
      startIndex = endIndex
      if startIndex >= baseText.endIndex { break }
    }
    return AttrStrULStyle.pack(segments)
  }

  public var attributedStringMarking: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    /// 使用不包含讀音的文本作為基礎，以防某些客體應用提取文本時包含讀音。
    let converted = displayedTextConvertedSansReading.map(\.description)
    let range2 = markedRange
    let range1 = 0 ..< markedRange.lowerBound
    let range3 = markedRange.upperBound ..< converted.count
    let pairs: [AttrStrULStyle.StyledPair] = [
      (converted[range1].joined(), .single),
      (converted[range2].joined(), .thick),
      (converted[range3].joined(), .single),
    ]
    return AttrStrULStyle.pack(pairs)
  }

  public var attributedStringPlaceholder: NSAttributedString {
    AttrStrULStyle.single.getMarkedAttrStr("¶", clauseSegment: 0)
  }
}

// MARK: - IMEState 工具函式

extension IMEStateData {
  public var readingThreadForDisplay: String {
    var arrOutput = [String]()
    for neta in markedReadings {
      if neta.isEmpty { continue }
      if neta.contains("_") {
        arrOutput.append("??")
        continue
      }
      neta.components(separatedBy: "-").forEach { subNeta in
        var subNeta = subNeta
        if !PrefMgr().cassetteEnabled {
          if PrefMgr().showHanyuPinyinInCompositionBuffer,
             PrefMgr().alwaysShowTooltipTextsHorizontally || !InputSession.isVerticalTyping {
            // 恢復陰平標記->注音轉拼音->轉教科書式標調
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

  public mutating func updateTooltipForMarking() {
    var tooltipForMarking: String {
      let pair = userPhraseKVPair
      if markedRange.isEmpty {
        return ""
      }

      let text = pair.value
      let readingDisplay = readingThreadForDisplay
      if markedRange.count < Self.allowedMarkLengthRange.lowerBound {
        tooltipColorState = .denialInsufficiency
        return String(
          format: NSLocalizedString(
            "\"%@\" length must ≥ 2 for a user phrase.",
            comment: ""
          ) + "\n◆  " + readingDisplay,
          text
        )
      } else if markedRange.count > Self.allowedMarkLengthRange.upperBound {
        tooltipColorState = .denialOverflow
        return String(
          format: NSLocalizedString(
            "\"%@\" length should ≤ %d for a user phrase.",
            comment: ""
          ) + "\n◆  " + readingDisplay,
          text,
          Self.allowedMarkLengthRange.upperBound
        )
      }

      if markedTargetExists {
        tooltipColorState = .prompt
        switch LMMgr.isStateDataFilterableForMarked(self) {
        case false:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf.",
              comment: ""
            ) + "\n◆  " + readingDisplay,
            text
          )
        case true:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.",
              comment: ""
            ) + "\n◆  " + readingDisplay,
            text
          )
        }
      }

      if markedTargetIsCurrentlyFiltered {
        tooltipColorState = .information
        return String(
          format: NSLocalizedString(
            "\"%@\" selected. ENTER to unfilter this phrase.",
            comment: ""
          ) + "\n◆  "
            + readingDisplay,
          text
        )
      }

      tooltipColorState = .normal
      return String(
        format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: "")
          + "\n◆  "
          + readingDisplay,
        text
      )
    }
    tooltip = tooltipForMarking
    if PrefMgr().phraseReplacementEnabled {
      tooltipColorState = .warning
      tooltip +=
        "\n"
        + NSLocalizedString(
          "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.",
          comment: ""
        )
    }
  }
}
