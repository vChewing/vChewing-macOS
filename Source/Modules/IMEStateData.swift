// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import Tekkon
import TooltipUI

public struct IMEStateData: IMEStateDataProtocol {
  private static var minCandidateLength: Int {
    PrefMgr.shared.allowBoostingSingleKanjiAsUserPhrase ? 1 : 2
  }

  static var allowedMarkLengthRange: ClosedRange<Int> {
    Self.minCandidateLength ... PrefMgr.shared.maxCandidateLength
  }

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
      || result.count != displayedText.count
    {
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
    displayedText.map(\.description)[0 ..< cursor].joined().utf16.count
  }

  public var u16Marker: Int {
    displayedText.map(\.description)[0 ..< marker].joined().utf16.count
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

  public var displayTextSegments = [String]() {
    didSet {
      displayedText = displayTextSegments.joined()
    }
  }

  public var reading: String = ""
  public var markedReadings = [String]()
  public var candidates = [(keyArray: [String], value: String)]()
  public var textToCommit: String = ""
  public var tooltip: String = ""
  public var tooltipDuration: Double = 1.0
  public var tooltipBackupForInputting: String = ""
  public var attributedStringPlaceholder: NSAttributedString = .init(
    string: " ",
    attributes: [
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .markedClauseSegment: 0,
    ]
  )
  public var isFilterable: Bool {
    markedTargetExists ? (isMarkedLengthValid && markedRange.count > 1) : false
  }

  public var isMarkedLengthValid: Bool {
    Self.allowedMarkLengthRange.contains(markedRange.count)
  }

  public var tooltipColorState: TooltipColorState = .normal

  public var attributedStringNormal: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedTextConverted)
    var newBegin = 0
    for (i, neta) in displayTextSegments.enumerated() {
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
  }

  public var attributedStringMarking: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedTextConverted)
    let end = u16MarkedRange.upperBound

    attributedString.setAttributes(
      [
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .markedClauseSegment: 0,
      ], range: NSRange(location: 0, length: u16MarkedRange.lowerBound)
    )
    attributedString.setAttributes(
      [
        .underlineStyle: NSUnderlineStyle.thick.rawValue,
        .markedClauseSegment: 1,
      ],
      range: NSRange(
        location: u16MarkedRange.lowerBound,
        length: u16MarkedRange.upperBound - u16MarkedRange.lowerBound
      )
    )
    attributedString.setAttributes(
      [
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .markedClauseSegment: 2,
      ],
      range: NSRange(
        location: end,
        length: displayedTextConverted.utf16.count - end
      )
    )
    return attributedString
  }
}

// MARK: - IMEState 工具函式

public extension IMEStateData {
  var readingThreadForDisplay: String {
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
             PrefMgr.shared.alwaysShowTooltipTextsHorizontally || !SessionCtl.isVerticalTyping
          {
            // 恢復陰平標記->注音轉拼音->轉教科書式標調
            subNeta = Tekkon.restoreToneOneInPhona(target: subNeta)
            subNeta = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: subNeta)
            subNeta = Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: subNeta)
          } else {
            subNeta = Tekkon.cnvPhonaToTextbookReading(target: subNeta)
          }
        }
        arrOutput.append(subNeta)
      }
    }
    return arrOutput.joined(separator: "\u{A0}")
  }

  var userPhraseKVPair: (keyArray: [String], value: String) {
    let key = markedReadings
    let value = displayedText.map(\.description)[markedRange].joined()
    return (key, value)
  }

  mutating func updateTooltipForMarking() {
    var tooltipForMarking: String {
      let pair = userPhraseKVPair
      if PrefMgr.shared.phraseReplacementEnabled {
        tooltipColorState = .warning
        return NSLocalizedString(
          "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", comment: ""
        )
      }
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
        switch markedRange.count {
        case 1:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf.",
              comment: ""
            ) + "\n◆  " + readingDisplay, text
          )
        default:
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.",
              comment: ""
            ) + "\n◆  " + readingDisplay, text
          )
        }
      }
      tooltipColorState = .normal
      return String(
        format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: "") + "\n◆  "
          + readingDisplay,
        text
      )
    }
    tooltip = tooltipForMarking
  }
}
