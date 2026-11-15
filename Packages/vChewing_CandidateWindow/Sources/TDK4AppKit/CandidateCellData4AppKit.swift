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
      if displayedText.count > 1 {
        textDimension.width = makeAttributedString().getBoundingDimension().width
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

    /// 該格之**繪製佔寬**：前端內距 2 × padding ＋ 標籤盒 ＋ 候選字詞（不含尾端內距）。
    ///
    /// `textDimension` 量的是「選字鍵 ＋ 一個空白 ＋ 候選字詞」之組合字串，而繪製面上
    /// 標籤盒係正方形（邊長＝標籤行高）、候選字詞自其右緣起排 ⇒ 兩者之差是一個
    /// **與內容無關、只隨（字級, locale）而變**的常數。該常數由資料池一次算得
    /// （`CandidatePool4AppKit.footprintMargin`），逐格只做一次加法——
    /// 建池路徑**不得**再逐格量測（成本為 O(N)，狂打時 N 可逾千）。
    /// 單字候選之 `textDimension` 係合成值（不量測），其面積由最小格寬／emoji 地板決定。
    func drawFootprintWidth(margin: CGFloat) -> CGFloat {
      textDimension.width + margin
    }

    /// 該格之面積下限：繪製佔寬 ＋ 尾端內距 4 × padding。非矩陣路徑之硬約束。
    func requiredCellWidth(padding: CGFloat, margin: CGFloat) -> CGFloat {
      drawFootprintWidth(margin: margin) + 4 * padding
    }

    /// 計算橫排矩陣之 cell 寬度：**恆為最小格寬之整數倍**，且該倍數須容得下該格之繪製佔寬。
    ///
    /// 尾端內距不在本路徑之約束內（矩陣之尾端內距即該倍數之餘裕，沿既有裁定）。
    /// - Parameters:
    ///   - minCellWidth: 最小 cell 寬度（通常是 `blankCell.cellLength()`）。
    ///   - margin: 該池之佔寬邊距（`CandidatePool4AppKit.footprintMargin`）。
    /// - Returns: 不小於繪製佔寬、且為 `minCellWidth` 整數倍之寬度。
    func cellWidthMultiplied(minCellWidth: Double, margin: CGFloat) -> Double {
      let footprint = drawFootprintWidth(margin: margin)
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
      if thePool.isHorizontal, thePool.isMatrix {
        // 矩陣：格寬稍後由 `matrixCellWidth` 覆寫（以池層 margin 推得，逐格不量測）。
        cellDimension.width = max(
          cellDimension.width,
          requiredCellWidth(padding: padding, margin: thePool.footprintMargin)
        )
      } else {
        // 非矩陣：此處只排「當前頁」（≤ 4 列 × 9 格），故量測不構成建池成本；
        // 單字候選之 `textDimension` 係合成值、非繪製佔寬，故硬約束必須逐格實測。
        let keyAndPhraseWidth = keyLabelBoxSide
          + makeAttributedStringPhrase(isMatrix: false).getBoundingDimension().width
        cellDimension.width = max(cellDimension.width, keyAndPhraseWidth + 6 * padding)
      }
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
