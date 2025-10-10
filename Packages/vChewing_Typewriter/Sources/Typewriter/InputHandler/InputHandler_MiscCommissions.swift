// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BrailleSputnik
import Shared
import Tekkon

// MARK: - CommitableMarkupType

/// 該檔案專門管理「用指定熱鍵遞交特殊的內容」的這一類函式。

private enum CommitableMarkupType: Int {
  case bareKeys = -1
  case textWithBracketedAnnotations = 0
  case textWithHTMLRubyAnnotations = 1
  case braille1947 = 2
  case braille2018 = 3

  // MARK: Internal

  var brailleStandard: BrailleSputnik.BrailleStandard? {
    switch self {
    case .braille1947: return .of1947
    case .braille2018: return .of2018
    default: return nil
    }
  }

  static func match(rawValue: Int) -> Self {
    Self(rawValue: rawValue) ?? .textWithBracketedAnnotations
  }
}

extension InputHandlerProtocol {
  // MARK: - (Shift+)Ctrl+Command+Enter 鍵的處理（注音文）

  /// Command+Enter 鍵的處理（注音文）。
  /// - Parameter isShiftPressed: 有沒有同時摁著 Shift 鍵。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func commissionByCtrlCommandEnter(isShiftPressed: Bool = false) -> String {
    var displayedText = assembler.keys.joined(separator: "\t")
    if assembler.isEmpty {
      displayedText = readingForDisplay
    }
    if !prefs.cassetteEnabled {
      if prefs.inlineDumpPinyinInLieuOfZhuyin {
        if !assembler.isEmpty {
          var arrDisplayedTextElements = [String]()
          assembler.keys.forEach { key in
            arrDisplayedTextElements.append(Tekkon.restoreToneOneInPhona(target: key)) // 恢復陰平標記
          }
          displayedText = arrDisplayedTextElements.joined(separator: "\t")
        }
        displayedText = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: displayedText) // 注音轉拼音
      }
      if prefs.showHanyuPinyinInCompositionBuffer {
        if assembler.isEmpty {
          displayedText = displayedText.replacingOccurrences(of: "1", with: "")
        }
      }
    }

    displayedText = displayedText.replacingOccurrences(of: "\t", with: isShiftPressed ? "-" : " ")
    return displayedText
  }

  // MARK: - (Shift+)Ctrl+Command+Option+Enter 鍵的處理（網頁 Ruby 注音文標記）

  /// Command+Option+Enter 鍵的處理（網頁 Ruby 注音文標記）。
  ///
  /// 關於 prefs.specifyCmdOptCtrlEnterBehavior 的幾個參數作用：
  /// 1. 帶括弧的注音標記。
  /// 2. HTML Ruby 注音標記。
  /// 3. 國語點字 (1947)。
  /// 4. 國通盲文 (GF0019-2018)。
  /// - Parameter isShiftPressed: 有沒有同時摁著 Shift 鍵。摁了的話則只遞交讀音字串。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  func commissionByCtrlOptionCommandEnter(isShiftPressed: Bool = false) -> String {
    var behavior = CommitableMarkupType.match(rawValue: prefs.specifyCmdOptCtrlEnterBehavior)
    if prefs.cassetteEnabled, behavior.brailleStandard != nil {
      behavior = .textWithBracketedAnnotations
    }
    if isShiftPressed { behavior = .bareKeys }
    guard let brailleStandard = behavior.brailleStandard else {
      return specifyTextMarkupToCommit(behavior: behavior)
    }
    let brailleProcessor = BrailleSputnik(standard: brailleStandard)
    return brailleProcessor.convertToBraille(
      smashedPairs: assembler.assembledSentence.smashedPairs,
      extraInsertion: (reading: composer.value, cursor: assembler.cursor)
    )
  }

  private func specifyTextMarkupToCommit(behavior: CommitableMarkupType) -> String {
    var composed = ""
    assembler.assembledSentence.smashedPairs.forEach { key, value in
      var key = key
      if !prefs.cassetteEnabled {
        key =
          prefs.inlineDumpPinyinInLieuOfZhuyin
            ? Tekkon.restoreToneOneInPhona(target: key) // 恢復陰平標記
            : Tekkon.cnvPhonaToTextbookStyle(target: key) // 恢復陰平標記

        if prefs.inlineDumpPinyinInLieuOfZhuyin {
          key = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: key) // 注音轉拼音
          key = Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: key) // 轉教科書式標調
        }
      }
      key = key.replacingOccurrences(of: "\t", with: " ")
      switch behavior {
      case .bareKeys:
        if !composed.isEmpty { composed += " " }
        composed += key.contains("_") ? "??" : key
      case .textWithBracketedAnnotations:
        composed += key.contains("_") ? value : "\(value)(\(key))"
      case .textWithHTMLRubyAnnotations:
        composed += key
          .contains("_") ? value : "<ruby>\(value)<rp>(</rp><rt>\(key)</rt><rp>)</rp></ruby>"
      case .braille1947: break // 另案處理
      case .braille2018: break // 另案處理
      }
    }
    return composed
  }
}
