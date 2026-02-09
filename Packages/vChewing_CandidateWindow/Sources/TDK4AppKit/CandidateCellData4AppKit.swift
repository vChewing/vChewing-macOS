// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared

// MARK: - TDK4AppKit.CandidateCellData4AppKit

extension TDK4AppKit {
  // MARK: - CandidateCellData

  /// 用來管理選字窗內顯示的候選字的單位。用 class 型別會比較方便一些。
  final class CandidateCellData4AppKit: Hashable {
    // MARK: Lifecycle

    init(
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

    // MARK: Internal

    // MARK: - Basic NSAttributedString Components.

    static let sharedParagraphStyle: NSParagraphStyle = {
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.setParagraphStyle(NSParagraphStyle.default)
      paraStyle.alignment = .natural
      paraStyle.lineBreakMode = .byWordWrapping
      return paraStyle
    }()

    static var internalPrefs = PrefMgr()

    static var unifiedSize: Double { internalPrefs.candidateListTextSize }

    static var unifiedCharDimension: Double { ceil(unifiedSize * 1.0125 + 7) }
    static var unifiedTextHeight: Double { ceil(unifiedSize * 19 / 16) }
    static var plainTextColor: NSColor { absoluteTextColor.withAlphaComponent(0.85) }
    static var absoluteTextColor: NSColor { NSApplication.isDarkMode ? .white : .black }

    static var menuHighlightedTextColor: NSColor {
      if #available(macOS 10.14, *) {
        let yellowHue = NSColor.systemYellow.usingColorSpace(
          .deviceRGB
        )?.hueComponent
        let shitCellHue = CandidatePool4AppKit.shitCell.clientThemeColor?.usingColorSpace(
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

    var visualDimension: CGSize = .zero
    var visualOrigin: CGPoint = .zero
    var locale = ""
    var selectionKey: String
    let displayedText: String
    private(set) var textDimension: CGSize
    var segLength: Int
    var isHighlighted: Bool = false
    var whichLine: Int = 0
    // 該候選字詞在資料池內的總索引編號
    var index: Int = 0
    // 該候選字詞在當前行/列內的索引編號
    var subIndex: Int = 0

    var clientThemeColor: NSColor?

    var size: Double { Self.unifiedSize }
    var fontSizeCandidate: Double { size }
    var fontSizeKey: Double { max(ceil(fontSizeCandidate * 0.6), 11) }

    var fontColorCandidate: NSColor {
      isHighlighted ? Self.menuHighlightedTextColor : Self.plainTextColor
    }

    var fontColorKey: NSColor {
      isHighlighted
        ? Self.menuHighlightedTextColor.withAlphaComponent(0.9)
        : Self.plainTextColor.withAlphaComponent(0.5)
    }

    var hardCopy: CandidateCellData4AppKit {
      let result = CandidateCellData4AppKit(
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

    var cleanCopy: CandidateCellData4AppKit {
      let result = hardCopy
      result.isHighlighted = false
      result.selectionKey = " "
      return result
    }

    var attributedStringHeader: NSAttributedString {
      let attrKey: [NSAttributedString.Key: Any] = [
        .kern: 0,
        .font: selectionKeyFont(size: fontSizeKey),
        .paragraphStyle: Self.sharedParagraphStyle,
        .foregroundColor: fontColorKey,
      ]
      let attrStrKey = NSAttributedString(string: selectionKey, attributes: attrKey)
      return attrStrKey
    }

    var themeColorCocoa: NSColor {
      switch locale {
      case "zh-Hans": return .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255, alpha: 0.85)
      case "zh-Hant": return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
      case "ja": return .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: 0.85)
      default: return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
      }
    }

    static func == (lhs: CandidateCellData4AppKit, rhs: CandidateCellData4AppKit) -> Bool {
      lhs.selectionKey == rhs.selectionKey && lhs.displayedText == rhs.displayedText
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(selectionKey)
      hasher.combine(displayedText)
    }

    func cellLength(isMatrix: Bool = true) -> Double {
      let factor: CGFloat = (Self.internalPrefs.minCellWidthForHorizontalMatrix == 0) ? 1.5 : 2
      let minLength = ceil(Self.unifiedCharDimension * factor + size * 1.25)
      if displayedText.count <= 1, isMatrix { return minLength }
      return textDimension.width
    }

    /// 計算倍數化後的 cell 寬度。用於 horizontal matrix 模式，確保每個 cell 寬度是最低寬度的倍數。
    /// - Parameter minCellWidth: 最小 cell 寬度（通常是 blankCell.cellLength()）。
    /// - Returns: 倍數化後的寬度。
    func cellWidthMultiplied(minCellWidth: Double) -> Double {
      guard minCellWidth > 0 else { return textDimension.width }
      // 對於短文字（≤1 字），使用最小寬度。
      if displayedText.count <= 1 { return minCellWidth }
      // 對於長文字，計算需要多少個最小寬度單位。
      let multiplier = ceil(textDimension.width / minCellWidth)
      return multiplier * minCellWidth
    }

    func attributedString(
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

    func attributedStringPhrase(isMatrix: Bool = false) -> NSAttributedString {
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

    func charDescriptions(shortened: Bool = false) -> [String] {
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

    func updateMetrics(pool thePool: CandidatePool4AppKit, origin currentOrigin: CGPoint) {
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

    // MARK: - Fonts and NSColors.

    func selectionKeyFont(size: CGFloat? = nil) -> NSFont {
      let size: CGFloat = size ?? fontSizeKey
      if #available(macOS 10.15, *) {
        return NSFont.monospacedSystemFont(ofSize: fontSizeKey, weight: .regular)
      }
      return NSFont(name: "Courier New", size: size) ?? phraseFont(size: size)
    }

    /// FB10978412: Since macOS 11 Big Sur, CTFontCreateUIFontForLanguage cannot
    /// distinguish zh-Hans and zh-Hant with correct adoptation of proper PingFang SC/TC variants.
    /// Update: This has been fixed in macOS 13.
    ///
    /// Instructions for Apple Developer relations to reveal this bug:
    ///
    /// 0) Please go to Step 1. Reason: IMK Candidate Window support has been removed in this repo.
    /// 1) Make sure the usage of ".languageIdentifier" is disabled in the Dev Zone of the vChewing Preferences.
    /// 2) Run "make update" in the project folder to download the latest git-submodule of dictionary file.
    /// 3) Compile the target "vChewingInstaller", run it. It will install the input method into
    ///    "~/Library/Input Methods/" folder. Remember to ENABLE BOTH "vChewing-CHS"
    ///    and "vChewing-CHT" input sources in System Preferences / Settings.
    /// 4) Type Zhuyin "ej3" (ㄍㄨˇ) (or "gu3" in Pinyin if you enabled Pinyin typing in vChewing Preferences.)
    ///    using both "vChewing-CHS" and "vChewing-CHT", and check the candidate window by pressing SPACE key.
    /// 5) Do NOT enable either KangXi conversion mode nor JIS conversion mode. They are disabled by default.
    /// 6) Expecting the glyph differences of the candidate "骨" between PingFang SC and PingFang TC when rendering
    ///    the candidate window in different "vChewing-CHS" and "vChewing-CHT" input modes.
    func phraseFont(size: CGFloat? = nil) -> NSFont {
      let size: CGFloat = size ?? fontSizeCandidate

      let assignedName = Self.internalPrefs.candidateTextFontName

      if !assignedName.isEmpty, let assignedFont = NSFont(name: assignedName, size: size) {
        return assignedFont
      }

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
      // 該 Font 不自訂。
      let size: CGFloat = size ?? fontSizeCandidate
      let result: CTFont? = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, locale as CFString)
      return result ?? NSFont.systemFont(ofSize: size)
    }
  }
} // extension TDK4AppKit

// MARK: - Array Container Extension.

extension Array where Element == TDK4AppKit.CandidateCellData4AppKit {
  var hasHighlightedCell: Bool {
    for neta in self {
      if neta.isHighlighted { return true }
    }
    return false
  }
}
