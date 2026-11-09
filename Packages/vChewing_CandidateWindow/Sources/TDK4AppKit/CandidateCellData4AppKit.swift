// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import CoreText
import Shared

// MARK: - TDK4AppKit.CandidateCellData4AppKit

extension TDK4AppKit {
  // MARK: - CandidateCellData

  /// 用來管理選字窗內顯示的候選字的單位。用 struct 型別以取得值語義。
  struct CandidateCellData4AppKit: Hashable {
    // MARK: Lifecycle

    init(
      key: String, displayedText: String,
      keyArray: [String] = [], segLength: Int? = nil,
      isSelected: Bool = false, locale: CandidateLocale = .none
    ) {
      self.selectionKey = key
      self.displayedText = displayedText
      self.keyArray = keyArray
      self.segLength = max(segLength ?? keyArray.count, 1)
      self.isHighlighted = isSelected
      self.locale = locale
      self.textDimension = .init(
        width: ceil(Self.unifiedCharDimension * 1.4),
        height: Self.unifiedTextHeight
      )
      self.keyAndPhraseWidth = 0
      if displayedText.count > 1 {
        textDimension.width = makeAttributedString().getBoundingDimension().width
      }
      // 該格之面積下限只在此處與「繪製所用之字型」同源算出（locale 已就位）：
      // 候選字詞之字型隨 locale 而異（實測 ja 與 zh-Hant 之同字串寬度不同），
      // 若日後改以繪製當下才量測，必須一併保證與此處同源。
      self.keyAndPhraseWidth = keyLabelBoxSide + measuredPhraseWidth(isMatrix: false)
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

    static var internalPrefs = PrefMgr.sharedSansDidSetOps

    static var unifiedSize: Double { .init(internalPrefs.candidateListTextSize) }

    static var unifiedCharDimension: Double { ceil(unifiedSize * 1.0125 + 7) }
    static var unifiedTextHeight: Double { ceil(unifiedSize * 19 / 16) }
    static var plainTextColor: NSColor { absoluteTextColor.withAlphaComponent(0.85) }
    static var absoluteTextColor: NSColor {
      TDK4AppKit.CandidateAppearance.isDarkModeResolved ? .white : .black
    }

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

    /// Pre-computed offsets to avoid per-frame ceil() in draw loops.
    var headerDrawYOffset: CGFloat = 0
    var headerDrawXOffset: CGFloat = 0
    var phraseDrawXOffset: CGFloat = 0

    /// 該格之區域編碼（字型回退用）。以 16 位元之 LCID 儲存，理由見 `CandidateLocale`。
    var locale: CandidateLocale = .none
    var selectionKey: String
    let displayedText: String
    private(set) var textDimension: CGSize
    /// 該格之內容寬度（不含內距）：選字鍵標籤之正方形區域 ＋ 候選字詞之實測寬度。
    /// 此即「面積」之唯一真源——`requiredCellWidth(padding:)` 只在其上加計內距。
    /// 於初期化時以當下之字級與 locale 定影（與 `textDimension` 同制）。
    private(set) var keyAndPhraseWidth: CGFloat
    var segLength: Int
    /// 該候選字詞的原始讀音鍵陣列，用於讀音 disambiguation 顯示。
    let keyArray: [String]
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

    /// 選字鍵標籤之顯示區域：正方形，邊長取其自身之行高。
    /// 該標籤的呈現盒本質上是「窄高」形（寬＝字寬、高＝行高）；若顯示區域只給到字寬那麼窄，
    /// 則候選字字級越大、這個窄高的落差越顯眼。故一律以行高為邊長、給出正方形區域，
    /// 候選字詞自該正方形之右緣起排、標籤水平居中於其內。
    var keyLabelBoxSide: CGFloat {
      let keyFont = selectionKeyFont()
      return ceil(keyFont.ascender + abs(keyFont.descender) + keyFont.leading)
    }

    /// 標籤字串之墨跡盒（相對其繪製原點；`.useGlyphPathBounds` 即字形路徑之實墨，
    /// 非 advance 盒——兩者不可混用，`[.useGlyphPathBounds, .useOpticalBounds]` 會回傳後者）。
    var keyLabelInkBounds: CGRect {
      let line = CTLineCreateWithAttributedString(makeAttributedStringHeader())
      return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    }

    /// 標籤於其正方形區域內之橫向偏移：以**墨跡盒之中點**對齊區域中點。
    /// 該值**不取整**：區域邊長（行高）與墨跡寬皆為分數，取整（無論 `ceil` 或 `rounded`）
    /// 都會造成至多 ±1 點之兩側留白落差——舊制之 `ceil` 更是恆偏一側（實測落差可達 1.8 點，
    /// 在十餘點寬的區域上肉眼可見「偏 center-trailing」）。文字以分數座標繪製本就正常。
    /// 墨跡盒為空（如選字鍵為空白）時退回按 advance 居中。
    var keyLabelHorizontalCenteringOffset: CGFloat {
      let inkBounds = keyLabelInkBounds
      let inkCenterX = inkBounds.isEmpty
        ? makeAttributedStringHeader().size().width / 2
        : inkBounds.midX
      return keyLabelBoxSide / 2 - inkCenterX
    }

    var fontColorCandidate: NSColor {
      isHighlighted ? Self.menuHighlightedTextColor : Self.plainTextColor
    }

    var fontColorKey: NSColor {
      isHighlighted
        ? Self.menuHighlightedTextColor.withAlphaComponent(0.9)
        : Self.plainTextColor.withAlphaComponent(0.5)
    }

    var themeColorCocoa: NSColor {
      switch locale {
      case .zhHans: return .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255, alpha: 0.85)
      case .none, .zhHant: return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 0.85)
      case .ja: return .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: 0.85)
      }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.selectionKey == rhs.selectionKey && lhs.displayedText == rhs.displayedText
    }

    /// 組合「選字鍵 + 候選字詞」屬性字串（含留白與高亮背景）。
    /// 組件由呼叫端提供：cell 自身傳未快取版本，資料池傳池級快取版本。
    static func assembleAttributedString(
      for cell: Self,
      header: NSAttributedString,
      phrase: NSAttributedString,
      noSpacePadding: Bool = true,
      withHighlight: Bool = false
    )
      -> NSAttributedString {
      let attrSpace: [NSAttributedString.Key: Any] = [
        .kern: 0,
        .font: cell.phraseFont(size: cell.size),
        .paragraphStyle: Self.sharedParagraphStyle,
      ]
      let result: NSMutableAttributedString = {
        if noSpacePadding {
          let resultNeo = NSMutableAttributedString(string: " ", attributes: attrSpace)
          resultNeo.insert(phrase, at: 1)
          resultNeo.insert(header, at: 0)
          return resultNeo
        }
        let resultNeo = NSMutableAttributedString(string: "   ", attributes: attrSpace)
        resultNeo.insert(phrase, at: 2)
        resultNeo.insert(header, at: 1)
        return resultNeo
      }()
      if withHighlight, cell.isHighlighted {
        result.addAttribute(
          .backgroundColor, value: cell.themeColorCocoa,
          range: NSRange(location: 0, length: result.string.utf16.count)
        )
      }
      return result
    }

    /// 生成「選字鍵」的屬性字串。不帶快取；快取統一由資料池管理。
    func makeAttributedStringHeader() -> NSAttributedString {
      let attrKey: [NSAttributedString.Key: Any] = [
        .kern: 0,
        .font: selectionKeyFont(size: fontSizeKey),
        .paragraphStyle: Self.sharedParagraphStyle,
        .foregroundColor: fontColorKey,
      ]
      return NSAttributedString(string: selectionKey, attributes: attrKey)
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

    /// 該格之面積下限：前端內距 2 × padding ＋ 標籤盒 ＋ 候選字詞 ＋ 尾端內距 4 × padding。
    ///
    /// 此值**不得**再由「前端內距只算一份」之舊式推得（該式會吃掉尾端內距），亦不得
    /// 以 `textDimension`（＝「選字鍵字串 ＋ 一個空白 ＋ 候選字詞」之實測寬）替代：
    /// 兩者在繪製面上不是同一個東西——標籤盒係正方形（邊長＝標籤行高）、候選字詞自其右緣
    /// 起排，故實際佔寬為「標籤盒 ＋ 候選字詞」，與 `textDimension` 之差可達數點。
    /// 凡計算該格面積者（非矩陣之硬約束、矩陣之倍數化下限）一律經此一途。
    func requiredCellWidth(padding: CGFloat) -> CGFloat {
      keyAndPhraseWidth + 6 * padding
    }

    /// 候選字詞之實測寬度（單行）。`locale` 已就位時，此值與繪製所用之字型同源。
    func measuredPhraseWidth(isMatrix: Bool = false) -> CGFloat {
      makeAttributedStringPhrase(isMatrix: isMatrix).getBoundingDimension().width
    }

    /// 該格之**繪製佔寬**：前端內距 2 × padding ＋ 標籤盒 ＋ 候選字詞（不含尾端內距）。
    /// 此即「不得截字」之硬下限——矩陣之倍數化以此為基，非矩陣之硬約束另加尾端內距。
    func drawFootprintWidth(padding: CGFloat) -> CGFloat {
      2 * padding + keyAndPhraseWidth
    }

    /// 計算橫排矩陣之 cell 寬度：**恆為最小格寬之整數倍**，且該倍數須容得下該格之繪製佔寬。
    ///
    /// 倍數化之基**不得**取 `textDimension`（＝「選字鍵 ＋ 一個空白 ＋ 候選字詞」之實測寬）：
    /// 繪製面上標籤盒係正方形（邊長＝標籤行高）、候選字詞自其右緣起排，實際佔寬是
    /// 「標籤盒 ＋ 候選字詞」，兩者相差數點；而 `ceil` 對「恰為整數倍」之基數不帶來任何餘裕，
    /// 字詞遂越出該格。改以 `drawFootprintWidth(padding:)` 為基之後，倍數化只會加寬、不會截字。
    /// 尾端內距不在本路徑之約束內（矩陣之尾端內距即該倍數之餘裕，沿既有裁定）。
    /// - Parameters:
    ///   - minCellWidth: 最小 cell 寬度（通常是 `blankCell.cellLength()`）。
    ///   - padding: 該池之內距（前端算 2 份）。
    /// - Returns: 不小於繪製佔寬、且為 `minCellWidth` 整數倍之寬度。
    func cellWidthMultiplied(minCellWidth: Double, padding: CGFloat) -> Double {
      let footprint = drawFootprintWidth(padding: padding)
      guard minCellWidth > 0 else { return ceil(footprint) }
      // 單字候選（含全形空白、範本 cell）之佔寬本就小於一個單位，故取一個單位為下限。
      let units = ceil(max(footprint, minCellWidth) / minCellWidth)
      return units * minCellWidth
    }

    /// 生成組合後的屬性字串（選字鍵 + 候選字詞）。不帶快取；快取統一由資料池管理。
    func makeAttributedString(
      noSpacePadding: Bool = true, withHighlight: Bool = false, isMatrix: Bool = false
    )
      -> NSAttributedString {
      Self.assembleAttributedString(
        for: self,
        header: makeAttributedStringHeader(),
        phrase: makeAttributedStringPhrase(isMatrix: isMatrix),
        noSpacePadding: noSpacePadding,
        withHighlight: withHighlight
      )
    }

    /// 生成「候選字詞」的屬性字串。不帶快取；快取統一由資料池管理。
    func makeAttributedStringPhrase(isMatrix: Bool = false) -> NSAttributedString {
      var attrCandidate: [NSAttributedString.Key: Any] = [
        .kern: 0,
        .font: phraseFont(size: size),
        .paragraphStyle: Self.sharedParagraphStyle,
        .foregroundColor: fontColorCandidate,
      ]
      if #available(macOS 12, *), let languageTag = locale.languageTag {
        attrCandidate[.languageIdentifier] = languageTag as AnyObject
      }
      let delta: String = (isMatrix && displayedText.count < 2) ? "  　" : ""
      return NSAttributedString(
        string: displayedText + delta, attributes: attrCandidate
      )
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

    mutating func updateMetrics(pool thePool: CandidatePool4AppKit, origin currentOrigin: CGPoint) {
      let padding = thePool.padding
      var cellDimension = textDimension
      if let givenWidth = thePool.cellWidth(self).min, displayedText.count <= 2 {
        cellDimension.width = max(cellDimension.width + 4 * padding, givenWidth)
      } else {
        cellDimension.width += 4 * padding
      }
      cellDimension.width = ceil(cellDimension.width)
      cellDimension.height = Self.unifiedTextHeight + 2 * padding
      // 標籤之顯示區域自「標籤字級」（＝舊制之顯示區域寬度）擴為「標籤行高」之正方形後，
      // 標籤右緣、連帶緊隨其右緣的候選字詞，一齊右移了兩者之差；該差須由該格之總寬度一併
      // 吸收（補償），否則被吃掉的是尾端內距、候選字詞會貼齊該格右緣。
      cellDimension.width += keyLabelBoxSide - fontSizeKey
      // 選字鍵標籤之正方形區域與候選字詞必須同時放得進該格，且尾端一側亦得留足內距：
      // 內容自 2 × padding 起算、依序為標籤盒與候選字詞，尾端另留 4 × padding（經實機目視定案）。
      // 面積下限之算式住 `requiredCellWidth(padding:)`；此處不得另行就地複寫一份。
      cellDimension.width = max(cellDimension.width, requiredCellWidth(padding: padding))
      visualDimension = cellDimension
      visualOrigin = currentOrigin
      headerDrawYOffset = ceil(cellDimension.height * 0.2)
      headerDrawXOffset = keyLabelHorizontalCenteringOffset
      phraseDrawXOffset = keyLabelBoxSide
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
      let defaultResult: CTFont? = CTFontCreateUIFontForLanguage(
        .system, size, locale.cfLanguage
      )
      return defaultResult ?? NSFont.systemFont(ofSize: size)
    }

    func phraseFontEmphasized(size: CGFloat? = nil) -> NSFont {
      // 該 Font 不自訂。
      let size: CGFloat = size ?? fontSizeCandidate
      let result: CTFont? = CTFontCreateUIFontForLanguage(
        .emphasizedSystem, size, locale.cfLanguage
      )
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
