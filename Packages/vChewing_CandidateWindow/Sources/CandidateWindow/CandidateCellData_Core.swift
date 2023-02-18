// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Shared
import SwiftUI
import SwiftUIBackports

// MARK: - Candidate Cell

/// 用來管理選字窗內顯示的候選字的單位。用 class 型別會比較方便一些。
public class CandidateCellData: Hashable {
  public var locale = ""
  public static var unifiedSize: Double = 16
  public var key: String
  public var displayedText: String
  public var size: Double { Self.unifiedSize }
  public var isHighlighted: Bool = false
  public var whichLine: Int = 0
  // 該候選字詞在資料池內的總索引編號
  public var index: Int = 0
  // 該候選字詞在當前行/列內的索引編號
  public var subIndex: Int = 0

  public var charGlyphWidth: Double { ceil(size * 1.0125 + 7) }
  public var fontSizeCandidate: Double { size }
  public var fontSizeKey: Double { max(ceil(fontSizeCandidate * 0.6), 11) }
  public var fontColorKey: NSColor {
    isHighlighted ? .selectedMenuItemTextColor.withAlphaComponent(0.8) : .secondaryLabelColor
  }

  public var fontColorCandidate: NSColor { isHighlighted ? .selectedMenuItemTextColor : .labelColor }

  public init(key: String, displayedText: String, isSelected: Bool = false) {
    self.key = key
    self.displayedText = displayedText
    isHighlighted = isSelected
  }

  public static func == (lhs: CandidateCellData, rhs: CandidateCellData) -> Bool {
    lhs.key == rhs.key && lhs.displayedText == rhs.displayedText
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(key)
    hasher.combine(displayedText)
  }

  public func cellLength(isMatrix: Bool = true) -> Double {
    let minLength = ceil(charGlyphWidth * 2 + size)
    if displayedText.count <= 2, isMatrix { return minLength }
    return ceil(attributedStringForLengthCalculation.boundingDimension.width)
  }

  public static let sharedParagraphStyle: NSParagraphStyle = {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .natural
    paraStyle.lineBreakMode = .byWordWrapping
    return paraStyle
  }()

  var phraseFont: NSFont {
    CTFontCreateUIFontForLanguage(.system, size, locale as CFString) ?? NSFont.systemFont(ofSize: size)
  }

  var highlightedNSColor: NSColor {
    var result = NSColor.alternateSelectedControlColor
    var colorBlendAmount: Double = NSApplication.isDarkMode ? 0.3 : 0.0
    if #available(macOS 10.14, *), !NSApplication.isDarkMode, locale == "zh-Hant" {
      colorBlendAmount = 0.15
    }
    // 設定當前高亮候選字的背景顏色。
    switch locale {
    case "zh-Hans":
      result = NSColor.systemRed
    case "zh-Hant":
      result = NSColor.systemBlue
    case "ja":
      result = NSColor.systemBrown
    default: break
    }
    var blendingAgainstTarget: NSColor = NSApplication.isDarkMode ? NSColor.black : NSColor.white
    if #unavailable(macOS 10.14) {
      colorBlendAmount = 0.3
      blendingAgainstTarget = NSColor.white
    }
    return result.blended(withFraction: colorBlendAmount, of: blendingAgainstTarget)!
  }

  public var attributedStringForLengthCalculation: NSAttributedString {
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular),
      .paragraphStyle: Self.sharedParagraphStyle,
    ]
    let attrStrCandidate = NSAttributedString(string: displayedText + "　", attributes: attrCandidate)
    return attrStrCandidate
  }

  public func attributedString(
    noSpacePadding: Bool = true, withHighlight: Bool = false, isMatrix: Bool = false
  ) -> NSAttributedString {
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular),
      .paragraphStyle: Self.sharedParagraphStyle,
    ]
    let result: NSMutableAttributedString = {
      if noSpacePadding {
        let resultNeo = NSMutableAttributedString(string: " ", attributes: attrCandidate)
        resultNeo.insert(attributedStringPhrase(isMatrix: isMatrix), at: 1)
        resultNeo.insert(attributedStringHeader, at: 0)
        return resultNeo
      }
      let resultNeo = NSMutableAttributedString(string: "   ", attributes: attrCandidate)
      resultNeo.insert(attributedStringPhrase(isMatrix: isMatrix), at: 2)
      resultNeo.insert(attributedStringHeader, at: 1)
      return resultNeo
    }()
    if withHighlight, isHighlighted {
      result.addAttribute(
        .backgroundColor, value: highlightedNSColor,
        range: NSRange(location: 0, length: result.string.utf16.count)
      )
    }
    return result
  }

  public var attributedStringHeader: NSAttributedString {
    let theFontForCandidateKey: NSFont = {
      if #available(macOS 10.15, *) {
        return NSFont.monospacedSystemFont(ofSize: fontSizeKey, weight: .regular)
      }
      return NSFont.monospacedDigitSystemFont(ofSize: fontSizeKey, weight: .regular)
    }()
    var attrKey: [NSAttributedString.Key: AnyObject] = [
      .font: theFontForCandidateKey,
      .paragraphStyle: Self.sharedParagraphStyle,
    ]
    if isHighlighted {
      attrKey[.foregroundColor] = NSColor.white.withAlphaComponent(0.8)
    } else {
      attrKey[.foregroundColor] = NSColor.secondaryLabelColor
    }
    let attrStrKey = NSAttributedString(string: key, attributes: attrKey)
    return attrStrKey
  }

  public func attributedStringPhrase(isMatrix: Bool = false) -> NSAttributedString {
    var attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: phraseFont,
      .paragraphStyle: Self.sharedParagraphStyle,
    ]
    if isHighlighted {
      attrCandidate[.foregroundColor] = NSColor.white
    } else {
      attrCandidate[.foregroundColor] = NSColor.labelColor
    }
    if #available(macOS 12, *) {
      if UserDefaults.standard.bool(
        forKey: UserDef.kLegacyCandidateViewTypesettingMethodEnabled.rawValue
      ) {
        attrCandidate[.languageIdentifier] = self.locale as AnyObject
      }
    }
    let delta: String = (isMatrix && displayedText.count < 2) ? "  　" : ""
    let attrStrCandidate = NSAttributedString(
      string: displayedText + delta, attributes: attrCandidate
    )
    return attrStrCandidate
  }

  public var charDescriptions: [String] {
    var result = displayedText
    if displayedText.contains("("), displayedText.count > 2 {
      result = displayedText.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
    }
    return result.flatMap(\.unicodeScalars).compactMap {
      let theName: String = $0.properties.name ?? ""
      return String(format: "U+%02X %@", $0.value, theName)
    }
  }

  public func minWidthToDraw(isMatrix: Bool = true) -> Double {
    cellLength(isMatrix: isMatrix) + ceil(fontSizeKey * 0.1)
  }
}
