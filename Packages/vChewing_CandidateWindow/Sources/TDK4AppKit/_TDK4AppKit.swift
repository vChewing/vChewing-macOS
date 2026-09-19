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
