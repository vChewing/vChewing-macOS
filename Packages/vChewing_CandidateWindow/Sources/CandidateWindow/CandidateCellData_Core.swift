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
  public var visualDimension: CGSize = .zero
  public var locale = ""
  public static var unifiedSize: Double = 16
  public var selectionKey: String
  public var displayedText: String
  public var spanLength: Int
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
  public var fontColorCandidate: NSColor { isHighlighted ? .selectedMenuItemTextColor : .controlTextColor }
  public var fontColorKey: NSColor {
    isHighlighted
      ? .selectedMenuItemTextColor.withAlphaComponent(0.9)
      : .init(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1)
  }

  public init(
    key: String, displayedText: String,
    spanLength spanningLength: Int? = nil, isSelected: Bool = false
  ) {
    selectionKey = key
    self.displayedText = displayedText
    spanLength = max(spanningLength ?? displayedText.count, 1)
    isHighlighted = isSelected
  }

  public static func == (lhs: CandidateCellData, rhs: CandidateCellData) -> Bool {
    lhs.selectionKey == rhs.selectionKey && lhs.displayedText == rhs.displayedText
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(selectionKey)
    hasher.combine(displayedText)
  }

  public func cellLength(isMatrix: Bool = true) -> Double {
    let minLength = ceil(charGlyphWidth * 2 + size * 1.25)
    if displayedText.count <= 2, isMatrix { return minLength }
    return ceil(attributedStringPhrase().boundingDimension.width + charGlyphWidth)
  }

  // MARK: - Fonts and NSColors.

  func selectionKeyFont(size: CGFloat? = nil) -> NSFont {
    let size: CGFloat = size ?? fontSizeKey
    if #available(macOS 10.15, *) {
      return NSFont.monospacedSystemFont(ofSize: fontSizeKey, weight: .regular)
    }
    return NSFont(name: "Menlo", size: size) ?? phraseFont(size: size)
  }

  func phraseFont(size: CGFloat? = nil) -> NSFont {
    let size: CGFloat = size ?? fontSizeCandidate
    //  暫時停用自訂字型回退機制，因為行高處理比較棘手。
    //  有相關需求者請自行修改 macOS 10.9 - 10.12 的 DefaultFontFallbacks 和 CTPresetFallbacks 檔案。
    //  var result: NSFont?
    //  compatibility: if #unavailable(macOS 10.11) {
    //    var fontIDs = [String]()
    //    switch locale {
    //    case "zh-Hans": fontIDs = ["PingFang SC", "Noto Sans CJK SC", "Hiragino Sans GB"]
    //    case "zh-Hant": fontIDs = ["PingFang TC", "Noto Sans CJK TC", "LiHei Pro"]
    //    case "ja": fontIDs = ["PingFang JA", "Noto Sans CJK JP", "Hiragino Kaku Gothic ProN W3"]
    //    default: break compatibility
    //    }
    //    fallback: for psName in fontIDs {
    //      result = NSFont(name: psName, size: size)
    //      guard result == nil else { break compatibility }
    //    }
    //  }
    let defaultResult: CTFont? = CTFontCreateUIFontForLanguage(.system, size, locale as CFString)
    return defaultResult ?? NSFont.systemFont(ofSize: size)
  }

  func phraseFontEmphasized(size: CGFloat? = nil) -> NSFont {
    let size: CGFloat = size ?? fontSizeCandidate
    let result: CTFont? = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, locale as CFString)
    return result ?? NSFont.systemFont(ofSize: size)
  }

  var themeColorCocoa: NSColor {
    switch locale {
    case "zh-Hans": return .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255, alpha: 0.85)
    case "zh-Hant": return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
    case "ja": return .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: 0.85)
    default: return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
    }
  }

  // MARK: - Basic NSAttributedString Components.

  public static let sharedParagraphStyle: NSParagraphStyle = {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .natural
    paraStyle.lineBreakMode = .byWordWrapping
    return paraStyle
  }()

  public func attributedString(
    noSpacePadding: Bool = true, withHighlight: Bool = false, isMatrix: Bool = false
  ) -> NSAttributedString {
    let attrSpace: [NSAttributedString.Key: AnyObject] = [
      .font: phraseFont(size: size),
      .paragraphStyle: Self.sharedParagraphStyle,
    ]
    let result: NSMutableAttributedString = {
      if noSpacePadding {
        let resultNeo = NSMutableAttributedString(string: " ", attributes: attrSpace)
        resultNeo.insert(attributedStringPhrase(isMatrix: isMatrix), at: 1)
        resultNeo.insert(attributedStringHeader, at: 0)
        return resultNeo
      }
      let resultNeo = NSMutableAttributedString(string: "   ", attributes: attrSpace)
      resultNeo.insert(attributedStringPhrase(isMatrix: isMatrix), at: 2)
      resultNeo.insert(attributedStringHeader, at: 1)
      return resultNeo
    }()
    if withHighlight, isHighlighted {
      result.addAttribute(
        .backgroundColor, value: themeColorCocoa,
        range: NSRange(location: 0, length: result.string.utf16.count)
      )
    }
    return result
  }

  public var attributedStringHeader: NSAttributedString {
    let attrKey: [NSAttributedString.Key: AnyObject] = [
      .font: selectionKeyFont(size: fontSizeKey),
      .paragraphStyle: Self.sharedParagraphStyle,
      .foregroundColor: fontColorKey,
    ]
    let attrStrKey = NSAttributedString(string: selectionKey, attributes: attrKey)
    return attrStrKey
  }

  public func attributedStringPhrase(isMatrix: Bool = false) -> NSAttributedString {
    var attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: phraseFont(size: size),
      .paragraphStyle: Self.sharedParagraphStyle,
      .foregroundColor: fontColorCandidate,
    ]
    if #available(macOS 12, *) {
      attrCandidate[.languageIdentifier] = self.locale as AnyObject
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
}

// MARK: - Array Container Extension.

public extension Array where Element == CandidateCellData {
  var hasHighlightedCell: Bool {
    for neta in self {
      if neta.isHighlighted { return true }
    }
    return false
  }
}
