// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Shared_DarwinImpl

// MARK: - TDK4AppKit

public enum TDK4AppKit {}

// MARK: TDK4AppKit.CandidateAppearance

extension TDK4AppKit {
  /// 選字窗之外觀覆寫：跟隨系統（`auto`）、強制淺色（`light`）、強制深色（`dark`）。
  ///
  /// **本特性 jailed 於選字窗模組內**：不經偏好設定、不設設定介面；現行值僅由選字窗控制器之
  /// `appearanceOverride`（`CtlCandidateTDK4AppKit`／`CtlCandidateGSI4AppKit`）寫入，
  /// 模組內之一切顏色解析（文字色、底色、各徽章色）皆以 `isDarkModeResolved` 為準，
  /// 而不再各自去問 `NSApplication.isDarkMode`。是否對外開放給使用者決定，留待日後裁定。
  public enum CandidateAppearance: Int, Sendable {
    /// 跟隨系統。注意：**macOS 10.13 及以前一律解析為淺色**（該等系統無深色模式）。
    case auto = 0
    /// 強制淺色。
    case light = 1
    /// 強制深色。
    case dark = -1

    // MARK: Internal

    /// 現行覆寫值。模組外不得直接讀寫——請經選字窗控制器之 `appearanceOverride`。
    static var current: Self = .auto

    /// 現行覆寫值解析後之明暗狀態。
    static var isDarkModeResolved: Bool { current.isDarkModeResolved }

    /// 該覆寫值於當前系統狀態下解析出之明暗狀態。
    var isDarkModeResolved: Bool {
      switch self {
      case .auto:
        // 深色模式係 macOS 10.14 才引進，之前之系統不可能為深色；一律解析為淺色。
        guard #available(macOS 10.14, *) else { return false }
        return NSApplication.isDarkMode
      case .light: return false
      case .dark: return true
      }
    }

    /// 對應之 `NSAppearance`（供視窗與視覺效果視圖覆寫）；`.auto` 為 nil＝跟隨系統。
    var nsAppearance: NSAppearance? {
      switch self {
      case .auto: return nil
      case .light: return NSAppearance(named: .aqua)
      case .dark:
        // `.darkAqua` 係 macOS 10.14 起；之前之系統無深色模式，回 nil（跟隨系統即可）。
        guard #available(macOS 10.14, *) else { return nil }
        return NSAppearance(named: .darkAqua)
      }
    }
  }
}

// MARK: TDK4AppKit.CandidateLocale

extension TDK4AppKit {
  /// 選字窗之區域編碼（候選字詞之字型回退用）。
  ///
  /// **何以不以 `String` 儲存**：候選字 cell 之數量在極端情形可達千個以上，而區域編碼是
  /// **每一格都一樣**的東西。逐格存一個 `String` 即逐格多佔 16 bytes（兩個 machine word），
  /// 且每次建立字型（`CTFontCreateUIFontForLanguage`）都得把它橋接成 `CFString`——那是逐格、
  /// 逐次排版各一次之橋接開銷。此型別每格只佔 2 bytes，橋接結果則按 case 快取一次。
  ///
  /// 原始值取 Windows LCID 之常見值（與同模組之 `CandidateAppearance: Int` 同制）：
  /// `zh-Hans` ＝ `0x0804`、`zh-Hant` ＝ `0x0404`、`ja` ＝ `0x0411`、不指定 ＝ `0x0000`。
  /// 值域即 `delegate.localeForFontFallbacks` 之封閉集（`zh-Hans`／`zh-Hant`／`ja`／空字串）；
  /// 未知之標籤一律歸 `.none`（＝不指定語言、走系統預設回退）。
  enum CandidateLocale: UInt16, CaseIterable, Sendable {
    case none = 0x0000
    case zhHans = 0x0804
    case zhHant = 0x0404
    case ja = 0x0411

    // MARK: Lifecycle

    /// 由語言標籤解析。未知之標籤一律歸 `.none`。
    init(languageTag: String) {
      switch languageTag {
      case "zh-Hans": self = .zhHans
      case "zh-Hant": self = .zhHant
      case "ja": self = .ja
      default: self = .none
      }
    }

    // MARK: Internal

    /// 該區域之語言標籤；`.none` 為 nil（不指定）。
    var languageTag: String? {
      switch self {
      case .none: return nil
      case .zhHans: return "zh-Hans"
      case .zhHant: return "zh-Hant"
      case .ja: return "ja"
      }
    }

    /// 供 `CTFontCreateUIFontForLanguage` 用之語言；橋接後之 `CFString` 每 case 只造一次。
    var cfLanguage: CFString? {
      switch self {
      case .none: return nil
      case .zhHans: return Self.cfLanguageZHans
      case .zhHant: return Self.cfLanguageZHant
      case .ja: return Self.cfLanguageJA
      }
    }

    // MARK: Private

    private static let cfLanguageZHans: CFString = "zh-Hans" as CFString
    private static let cfLanguageZHant: CFString = "zh-Hant" as CFString
    private static let cfLanguageJA: CFString = "ja" as CFString
  }
}
