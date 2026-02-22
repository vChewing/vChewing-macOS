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
  public var attributedStringNormal: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    getAttributedStringNormal(convertTextIfNeeded)
  }

  public var attributedStringMarking: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    getAttributedStringMarking(convertTextIfNeeded)
  }

  public var attributedStringPlaceholder: NSAttributedString {
    getAttributedStringPlaceholder()
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
        if !PrefMgr.shared.cassetteEnabled {
          if PrefMgr.shared.showHanyuPinyinInCompositionBuffer,
             PrefMgr.shared.alwaysShowTooltipTextsHorizontally || !InputSession.isVerticalTyping {
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
          format: "\"%@\" length must ≥ 2 for a user phrase.".i18n + "\n◆  " + readingDisplay,
          text
        )
      } else if markedRange.count > Self.allowedMarkLengthRange.upperBound {
        tooltipColorState = .denialOverflow
        return String(
          format: "\"%@\" length should ≤ %d for a user phrase.".i18n + "\n◆  " + readingDisplay,
          text,
          Self.allowedMarkLengthRange.upperBound
        )
      }

      if markedTargetExists {
        tooltipColorState = .prompt
        switch LMMgr.isStateDataFilterableForMarked(self) {
        case false:
          return String(
            format: "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf."
              .i18n + "\n◆  " + readingDisplay,
            text
          )
        case true:
          return String(
            format: "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude."
              .i18n + "\n◆  " + readingDisplay,
            text
          )
        }
      }

      if markedTargetIsCurrentlyFiltered {
        tooltipColorState = .information
        return String(
          format: "\"%@\" selected. ENTER to unfilter this phrase.".i18n + "\n◆  "
            + readingDisplay,
          text
        )
      }

      tooltipColorState = .normal
      return String(
        format: "\"%@\" selected. ENTER to add user phrase.".i18n
          + "\n◆  "
          + readingDisplay,
        text
      )
    }
    tooltip = tooltipForMarking
    if PrefMgr.shared.phraseReplacementEnabled {
      tooltipColorState = .warning
      tooltip +=
        "\n"
        + "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.".i18n
    }
  }
}
