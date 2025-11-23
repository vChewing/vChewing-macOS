// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared

// MARK: - CandidateCellData

/// 用來管理選字窗內顯示的候選字的單位。用 class 型別會比較方便一些。
public final class CandidateCellData: Hashable {
  // MARK: Lifecycle

  public init(
    key: String, displayedText: String,
    segLength: Int? = nil, isSelected: Bool = false
  ) {
    self.selectionKey = key
    self.displayedText = displayedText
    self.segLength = max(segLength ?? displayedText.count, 1)
    self.isHighlighted = isSelected
    self.textDimension = .init(
      width: ceil(Self.unifiedCharDimension * 1.4),
      height: Self.unifiedTextHeight
    )
    if displayedText.count > 1 {
      textDimension.width = attributedString().getBoundingDimension().width
    }
  }

  // MARK: Public

  public static var unifiedSize: Double = 16

  // MARK: - Basic NSAttributedString Components.

  public static let sharedParagraphStyle: NSParagraphStyle = {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .natural
    paraStyle.lineBreakMode = .byWordWrapping
    return paraStyle
  }()

  public static var unifiedCharDimension: Double { ceil(unifiedSize * 1.0125 + 7) }
  public static var unifiedTextHeight: Double { ceil(unifiedSize * 19 / 16) }
  public static var plainTextColor: NSColor { absoluteTextColor.withAlphaComponent(0.85) }
  public static var absoluteTextColor: NSColor { NSApplication.isDarkMode ? .white : .black }

  public static var menuHighlightedTextColor: NSColor {
    if #available(macOS 10.14, *) {
      let yellowHue = NSColor.systemYellow.usingColorSpace(
        .deviceRGB
      )?.hueComponent
      let shitCellHue = CandidatePool.shitCell.clientThemeColor?.usingColorSpace(
        .deviceRGB
      )?.hueComponent
      guard let shitCellHue, let yellowHue else {
        return .selectedMenuItemTextColor
      }
      if shitCellHue == yellowHue || (0.12 ... 0.182).contains(shitCellHue) {
        return .black
      }
    }
    return .selectedMenuItemTextColor
  }

  public var visualDimension: CGSize = .zero
  public var visualOrigin: CGPoint = .zero
  public var locale = ""
  public var selectionKey: String
  public let displayedText: String
  public private(set) var textDimension: CGSize
  public var segLength: Int
  public var isHighlighted: Bool = false
  public var whichLine: Int = 0
  // 該候選字詞在資料池內的總索引編號
  public var index: Int = 0
  // 該候選字詞在當前行/列內的索引編號
  public var subIndex: Int = 0

  public var clientThemeColor: NSColor?

  public var size: Double { Self.unifiedSize }
  public var fontSizeCandidate: Double { size }
  public var fontSizeKey: Double { max(ceil(fontSizeCandidate * 0.6), 11) }

  public var fontColorCandidate: NSColor {
    isHighlighted ? Self.menuHighlightedTextColor : Self.plainTextColor
  }

  public var fontColorKey: NSColor {
    isHighlighted
      ? Self.menuHighlightedTextColor.withAlphaComponent(0.9)
      : Self.plainTextColor.withAlphaComponent(0.5)
  }

  public var hardCopy: CandidateCellData {
    let result = CandidateCellData(
      key: selectionKey,
      displayedText: displayedText,
      segLength: segLength,
      isSelected: isHighlighted
    )
    result.visualDimension = visualDimension
    result.locale = locale
    result.whichLine = whichLine
    result.index = index
    result.subIndex = subIndex
    return result
  }

  public var cleanCopy: CandidateCellData {
    let result = hardCopy
    result.isHighlighted = false
    result.selectionKey = " "
    return result
  }

  public var attributedStringHeader: NSAttributedString {
    let attrKey: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: selectionKeyFont(size: fontSizeKey),
      .paragraphStyle: Self.sharedParagraphStyle,
      .foregroundColor: fontColorKey,
    ]
    let attrStrKey = NSAttributedString(string: selectionKey, attributes: attrKey)
    return attrStrKey
  }

  public static func == (lhs: CandidateCellData, rhs: CandidateCellData) -> Bool {
    lhs.selectionKey == rhs.selectionKey && lhs.displayedText == rhs.displayedText
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(selectionKey)
    hasher.combine(displayedText)
  }

  public func cellLength(isMatrix: Bool = true) -> Double {
    let factor: CGFloat = (Self.internalPrefs.minCellWidthForHorizontalMatrix == 0) ? 1.5 : 2
    let minLength = ceil(Self.unifiedCharDimension * factor + size * 1.25)
    if displayedText.count <= 2, isMatrix { return minLength }
    return textDimension.width
  }

  public func attributedString(
    noSpacePadding: Bool = true, withHighlight: Bool = false, isMatrix: Bool = false
  )
    -> NSAttributedString {
    let attrSpace: [NSAttributedString.Key: Any] = [
      .kern: 0,
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

  public func attributedStringPhrase(isMatrix: Bool = false) -> NSAttributedString {
    var attrCandidate: [NSAttributedString.Key: Any] = [
      .kern: 0,
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

  public func charDescriptions(shortened: Bool = false) -> [String] {
    var result = displayedText
    if displayedText.contains("("), displayedText.count > 2 {
      result = displayedText.replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
    }
    return result.flatMap(\.unicodeScalars).compactMap {
      let theName: String = $0.properties.name ?? ""
      return shortened ? String(format: "U+%02X", $0.value) :
        String(format: "U+%02X %@", $0.value, theName)
    }
  }

  public func updateMetrics(pool thePool: CandidatePool, origin currentOrigin: CGPoint) {
    let padding = thePool.padding
    var cellDimension = textDimension
    if let givenWidth = thePool.cellWidth(self).min, displayedText.count <= 2 {
      cellDimension.width = max(cellDimension.width + 4 * padding, givenWidth)
    } else {
      cellDimension.width += 4 * padding
    }
    cellDimension.width = ceil(cellDimension.width)
    cellDimension.height = Self.unifiedTextHeight + 2 * padding
    visualDimension = cellDimension
    visualOrigin = currentOrigin
  }

  // MARK: Internal

  static var internalPrefs = PrefMgr()

  var themeColorCocoa: NSColor {
    switch locale {
    case "zh-Hans": return .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255, alpha: 0.85)
    case "zh-Hant": return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
    case "ja": return .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: 0.85)
    default: return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
    }
  }

  // MARK: - Fonts and NSColors.

  func selectionKeyFont(size: CGFloat? = nil) -> NSFont {
    let size: CGFloat = size ?? fontSizeKey
    if #available(macOS 10.15, *) {
      return NSFont.monospacedSystemFont(ofSize: fontSizeKey, weight: .regular)
    }
    return NSFont(name: "Courier New", size: size) ?? phraseFont(size: size)
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
}

// MARK: - Array Container Extension.

extension Array where Element == CandidateCellData {
  public var hasHighlightedCell: Bool {
    for neta in self {
      if neta.isHighlighted { return true }
    }
    return false
  }
}
