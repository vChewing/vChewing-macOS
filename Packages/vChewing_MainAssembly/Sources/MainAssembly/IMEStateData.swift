// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKUtils
import InputMethodKit
import Shared
import Tekkon
import TooltipUI

// MARK: - IMEStateData

public struct IMEStateData: IMEStateDataProtocol {
  // MARK: Public

  public var displayedText: String = "" {
    didSet {
      if displayedText.rangeOfCharacter(from: .newlines) != nil {
        displayedText = displayedText.trimmingCharacters(in: .newlines)
      }
    }
  }

  public var displayedTextConverted: String {
    /// 先做繁簡轉換
    var result = ChineseConverter.kanjiConversionIfRequired(displayedText)
    if result.utf16.count != displayedText.utf16.count
      || result.count != displayedText.count {
      result = displayedText
    }
    return result
  }

  // MARK: Cursor & Marker & Range for UTF8

  public var cursor: Int = 0 {
    didSet {
      cursor = min(max(cursor, 0), displayedText.count)
    }
  }

  public var marker: Int = 0 {
    didSet {
      marker = min(max(marker, 0), displayedText.count)
    }
  }

  public var markedRange: Range<Int> {
    min(cursor, marker) ..< max(cursor, marker)
  }

  // MARK: Cursor & Marker & Range for UTF16 (Read-Only)

  /// IMK 協定的內文組字區的游標長度與游標位置無法正確統計 UTF8 高萬字（比如 emoji）的長度，
  /// 所以在這裡必須做糾偏處理。因為在用 Swift，所以可以用「.utf16」取代「NSString.length()」。
  /// 這樣就可以免除不必要的類型轉換。
  public var u16Cursor: Int {
    let upperBound = max(0, min(cursor, displayedText.count))
    return displayedText.map(\.description)[0 ..< upperBound].joined().utf16.count
  }

  public var u16Marker: Int {
    let upperBound = max(0, min(marker, displayedText.count))
    return displayedText.map(\.description)[0 ..< upperBound].joined().utf16.count
  }

  public var u16MarkedRange: Range<Int> {
    min(u16Cursor, u16Marker) ..< max(u16Cursor, u16Marker)
  }

  // MARK: Other data for non-empty states.

  public var markedTargetExists: Bool {
    let pair = userPhraseKVPair
    return LMMgr.checkIfPhrasePairExists(
      userPhrase: pair.value, mode: IMEApp.currentInputMode, keyArray: pair.keyArray
    )
  }

  public var markedTargetIsCurrentlyFiltered: Bool {
    let pair = userPhraseKVPair
    return LMMgr.checkIfPhrasePairIsFiltered(
      userPhrase: pair.value, mode: IMEApp.currentInputMode, keyArray: pair.keyArray
    )
  }

  public var displayTextSegments = [String]() {
    didSet {
      displayedText = displayTextSegments.joined()
    }
  }

  public var highlightAtSegment: Int?
  public var reading: String = ""
  public var markedReadings = [String]()
  public var candidates = [(keyArray: [String], value: String)]()
  public var textToCommit: String = ""

  public var isFilterable: Bool {
    guard isMarkedLengthValid else { return false } // 範圍長度必須合規。
    guard markedTargetExists else { return false } // 必須得有在庫對象
    guard markedReadings.count == 1 else { return true } // 如果幅長大於 1，則直接批准。
    // 處理單個漢字的情形：當且僅當在庫量僅有一筆的時候，才禁止過濾。
    return LMMgr.countPhrasePairs(keyArray: markedReadings, mode: IMEApp.currentInputMode) > 1
  }

  public var isMarkedLengthValid: Bool {
    Self.allowedMarkLengthRange.contains(markedRange.count)
  }

  // MARK: Tooltip neta.

  public var tooltip: String = ""
  public var tooltipDuration: Double = 1.0
  public var tooltipBackupForInputting: String = ""
  public var tooltipColorState: TooltipColorState = .normal

  // MARK: Internal

  static var allowedMarkLengthRange: ClosedRange<Int> {
    Self.minCandidateLength ... PrefMgr.shared.maxCandidateLength
  }

  // MARK: Private

  private static var minCandidateLength: Int {
    PrefMgr.shared.allowBoostingSingleKanjiAsUserPhrase ? 1 : 2
  }
}

// MARK: - AttributedString 生成器

extension IMEStateData {
  public func attributedStringNormal(for session: IMKInputControllerProtocol) -> NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedTextConverted)
    var newBegin = 0
    for (i, neta) in displayTextSegments.enumerated() {
      let rangeNow = NSRange(location: newBegin, length: neta.utf16.count)
      /// 不能用 .thick，否則會看不到游標。
      var theAttributes: [NSAttributedString.Key: Any]
        = session.mark(forStyle: kTSMHiliteConvertedText, at: rangeNow)
        as? [NSAttributedString.Key: Any]
        ?? [.underlineStyle: NSUnderlineStyle.single.rawValue]
      theAttributes[.markedClauseSegment] = i
      attributedString.setAttributes(theAttributes, range: rangeNow)
      newBegin += neta.utf16.count
    }
    return attributedString
  }

  public func attributedStringMarking(for session: IMKInputControllerProtocol) -> NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedTextConverted)
    let u16MarkedRange = u16MarkedRange
    let range1 = NSRange(location: 0, length: u16MarkedRange.lowerBound)
    let range2 = NSRange(
      location: u16MarkedRange.lowerBound,
      length: u16MarkedRange.upperBound - u16MarkedRange.lowerBound
    )
    let range3 = NSRange(
      location: u16MarkedRange.upperBound,
      length: displayedTextConverted.utf16.count - u16MarkedRange.upperBound
    )
    var rawAttribute1: [NSAttributedString.Key: Any]
      = session.mark(forStyle: kTSMHiliteConvertedText, at: range1)
      as? [NSAttributedString.Key: Any]
      ?? [.underlineStyle: NSUnderlineStyle.single.rawValue]
    rawAttribute1[.markedClauseSegment] = 0
    var rawAttribute2: [NSAttributedString.Key: Any]
      = session.mark(forStyle: kTSMHiliteSelectedConvertedText, at: range2)
      as? [NSAttributedString.Key: Any]
      ?? [.underlineStyle: NSUnderlineStyle.thick.rawValue]
    rawAttribute2[.markedClauseSegment] = 1
    var rawAttribute3: [NSAttributedString.Key: Any]
      = session.mark(forStyle: kTSMHiliteConvertedText, at: range3)
      as? [NSAttributedString.Key: Any]
      ?? [.underlineStyle: NSUnderlineStyle.single.rawValue]
    rawAttribute3[.markedClauseSegment] = 2
    attributedString.setAttributes(rawAttribute1, range: range1)
    attributedString.setAttributes(rawAttribute2, range: range2)
    attributedString.setAttributes(rawAttribute3, range: range3)
    return attributedString
  }

  public func attributedStringPlaceholder(for session: IMKInputControllerProtocol) -> NSAttributedString {
    let attributes: [NSAttributedString.Key: Any]
      = session.mark(forStyle: kTSMHiliteSelectedRawText, at: .zero)
      as? [NSAttributedString.Key: Any]
      ?? [.underlineStyle: NSUnderlineStyle.single.rawValue]
    return .init(string: "✍", attributes: attributes)
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

  public var userPhraseKVPair: (keyArray: [String], value: String) {
    let key = markedReadings
    let value = displayedText.map(\.description)[markedRange].joined()
    return (key, value)
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
            "\"%@\" length must ≥ 2 for a user phrase.", comment: ""
          ) + "\n◆  " + readingDisplay, text
        )
      } else if markedRange.count > Self.allowedMarkLengthRange.upperBound {
        tooltipColorState = .denialOverflow
        return String(
          format: NSLocalizedString(
            "\"%@\" length should ≤ %d for a user phrase.", comment: ""
          ) + "\n◆  " + readingDisplay, text, Self.allowedMarkLengthRange.upperBound
        )
      }

      if markedTargetExists {
        tooltipColorState = .prompt
        switch isFilterable {
        case false:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf.",
              comment: ""
            ) + "\n◆  " + readingDisplay, text
          )
        case true:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.",
              comment: ""
            ) + "\n◆  " + readingDisplay, text
          )
        }
      }

      if markedTargetIsCurrentlyFiltered {
        tooltipColorState = .information
        return String(
          format: NSLocalizedString(
            "\"%@\" selected. ENTER to unfilter this phrase.",
            comment: ""
          ) +
            "\n◆  "
            + readingDisplay,
          text
        )
      }

      tooltipColorState = .normal
      return String(
        format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: "") +
          "\n◆  "
          + readingDisplay,
        text
      )
    }
    tooltip = tooltipForMarking
    if PrefMgr.shared.phraseReplacementEnabled {
      tooltipColorState = .warning
      tooltip += "\n" + NSLocalizedString(
        "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", comment: ""
      )
    }
  }
}
