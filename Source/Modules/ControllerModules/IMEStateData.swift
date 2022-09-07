// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public struct StateData {
  var displayedText: String = "" {
    didSet {
      let result = IME.kanjiConversionIfRequired(displayedText)
      if result.utf16.count == displayedText.utf16.count, result.count == displayedText.count {
        displayedText = result
      }
    }
  }

  // MARK: Cursor & Marker & Range for UTF8

  var cursor: Int = 0 {
    didSet {
      cursor = min(max(cursor, 0), displayedText.count)
    }
  }

  var marker: Int = 0 {
    didSet {
      marker = min(max(marker, 0), displayedText.count)
    }
  }

  var markedRange: Range<Int> {
    min(cursor, marker)..<max(cursor, marker)
  }

  // MARK: Cursor & Marker & Range for UTF16 (Read-Only)

  /// IMK 協定的內文組字區的游標長度與游標位置無法正確統計 UTF8 高萬字（比如 emoji）的長度，
  /// 所以在這裡必須做糾偏處理。因為在用 Swift，所以可以用「.utf16」取代「NSString.length()」。
  /// 這樣就可以免除不必要的類型轉換。
  var u16Cursor: Int {
    displayedText.charComponents[0..<cursor].joined().utf16.count
  }

  var u16Marker: Int {
    displayedText.charComponents[0..<marker].joined().utf16.count
  }

  var u16MarkedRange: Range<Int> {
    min(u16Cursor, u16Marker)..<max(u16Cursor, u16Marker)
  }

  // MARK: Other data for non-empty states.

  var markedTargetExists: Bool = false
  var displayTextSegments = [String]() {
    didSet {
      displayedText = displayTextSegments.joined()
    }
  }

  var reading: String = ""
  var markedReadings = [String]()
  var candidates = [(String, String)]()
  var textToCommit: String = ""
  var tooltip: String = ""
  var tooltipBackupForInputting: String = ""
  var attributedStringPlaceholder: NSAttributedString = .init(
    string: " ",
    attributes: [
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .markedClauseSegment: 0,
    ]
  )
  var isFilterable: Bool {
    markedTargetExists ? mgrPrefs.allowedMarkRange.contains(markedRange.count) : false
  }

  var attributedStringNormal: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedText)
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

  var attributedStringMarking: NSAttributedString {
    /// 考慮到因為滑鼠點擊等其它行為導致的組字區內容遞交情況，
    /// 這裡對組字區內容也加上康熙字轉換或者 JIS 漢字轉換處理。
    let attributedString = NSMutableAttributedString(string: displayedText)
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
        length: displayedText.utf16.count - end
      )
    )
    return attributedString
  }
}

// MARK: - IMEState 工具函式

extension StateData {
  var chkIfUserPhraseExists: Bool {
    let text = displayedText.charComponents[markedRange].joined()
    let joined = markedReadings.joined(separator: "-")
    return mgrLangModel.checkIfUserPhraseExist(
      userPhrase: text, mode: IME.currentInputMode, key: joined
    )
  }

  var userPhrase: String {
    let text = displayedText.charComponents[markedRange].joined()
    let joined = markedReadings.joined(separator: "-")
    let nerfedScore = ctlInputMethod.areWeNerfing && markedTargetExists ? " -114.514" : ""
    return "\(text) \(joined)\(nerfedScore)"
  }

  var userPhraseConverted: String {
    let text =
      ChineseConverter.crossConvert(displayedText.charComponents[markedRange].joined()) ?? ""
    let joined = markedReadings.joined(separator: "-")
    let nerfedScore = ctlInputMethod.areWeNerfing && markedTargetExists ? " -114.514" : ""
    let convertedMark = "#𝙃𝙪𝙢𝙖𝙣𝘾𝙝𝙚𝙘𝙠𝙍𝙚𝙦𝙪𝙞𝙧𝙚𝙙"
    return "\(text) \(joined)\(nerfedScore)\t\(convertedMark)"
  }

  enum Marking {
    private static func generateReadingThread(_ data: StateData) -> String {
      var arrOutput = [String]()
      for neta in data.markedReadings {
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

    /// 更新工具提示內容、以及對應配對是否在庫。
    /// - Parameter data: 要處理的狀態資料包。
    public static func updateParameters(_ data: inout StateData) {
      var tooltipGenerated: String {
        if mgrPrefs.phraseReplacementEnabled {
          ctlInputMethod.tooltipController.setColor(state: .warning)
          return NSLocalizedString(
            "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", comment: ""
          )
        }
        if data.markedRange.isEmpty {
          return ""
        }

        let text = data.displayedText.charComponents[data.markedRange].joined()
        if data.markedRange.count < mgrPrefs.allowedMarkRange.lowerBound {
          ctlInputMethod.tooltipController.setColor(state: .denialInsufficiency)
          return String(
            format: NSLocalizedString(
              "\"%@\" length must ≥ 2 for a user phrase.", comment: ""
            ) + "\n//  " + generateReadingThread(data), text
          )
        } else if data.markedRange.count > mgrPrefs.allowedMarkRange.upperBound {
          ctlInputMethod.tooltipController.setColor(state: .denialOverflow)
          return String(
            format: NSLocalizedString(
              "\"%@\" length should ≤ %d for a user phrase.", comment: ""
            ) + "\n//  " + generateReadingThread(data), text, mgrPrefs.allowedMarkRange.upperBound
          )
        }

        let joined = data.markedReadings.joined(separator: "-")
        let exist = mgrLangModel.checkIfUserPhraseExist(
          userPhrase: text, mode: IME.currentInputMode, key: joined
        )
        if exist {
          data.markedTargetExists = exist
          ctlInputMethod.tooltipController.setColor(state: .prompt)
          return String(
            format: NSLocalizedString(
              "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.",
              comment: ""
            ) + "\n//  " + generateReadingThread(data), text
          )
        }
        ctlInputMethod.tooltipController.resetColor()
        return String(
          format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: "") + "\n//  "
            + generateReadingThread(data),
          text
        )
      }
      data.tooltip = tooltipGenerated
    }
  }
}
