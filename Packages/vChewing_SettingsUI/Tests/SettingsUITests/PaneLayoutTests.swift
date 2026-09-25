// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Testing

// MARK: - PaneLayoutTests

/// 「一般設定」與「行為設定」兩面板之**段落歸屬**之固化物（Phase 248）。
///
/// **何以掃原始碼而不掃視圖**：本 phase 之產物純為「哪一項由哪一個面板繪製」之歸屬關係，無行為可測；
/// 而 SwiftUI 之 `Section` 與 AppKit 之 `buildSection` 皆無執行期可讀之標識（前者是語言構造、後者只
/// 是回傳 `NSStackView` 的工廠函式，兩者都不在視圖樹上留下痕跡）。故以原始碼為判準——該四支面板檔內
/// 之出現次數即此歸屬之唯一真源。
///
/// **本測試所釘住者**：Phase 248 所遷移之五項**不得**再出現於任一側之「一般設定」面板、且**各恰一次**
/// 出現於對應之「行為設定」面板；「介面語言」反之（留在「一般設定」、不進「行為設定」）。
@Suite(.serialized)
struct PaneLayoutTests {
  // MARK: Internal

  @Test
  func testMigratedItemsLiveInTheBehaviorPanesOnly() throws {
    let migrated = [
      "kAutoCorrectReadingCombination",
      "kKeepReadingUponCompositionError",
      "kUseSCPCTypingMode",
      "kClassicHaninKeyboardSymbolModeShortcutEnabled",
      "kShowHanyuPinyinInCompositionBuffer",
    ]
    for key in migrated {
      #expect(try occurrences(of: key, in: .generalUI) == 0, "\(key) 仍在「一般設定」（SwiftUI）內")
      #expect(try occurrences(of: key, in: .generalCocoa) == 0, "\(key) 仍在「一般設定」（AppKit）內")
      #expect(try occurrences(of: key, in: .behaviorUI) == 1, "\(key) 於「行為設定」（SwiftUI）內之次數不為 1")
      #expect(try occurrences(of: key, in: .behaviorCocoa) == 1, "\(key) 於「行為設定」（AppKit）內之次數不為 1")
    }
  }

  @Test
  func testInterfaceLanguageStaysInTheGeneralPanes() throws {
    let key = "kAppleLanguages"
    #expect(try occurrences(of: key, in: .generalUI) > 0, "「介面語言」不在「一般設定」（SwiftUI）內")
    #expect(try occurrences(of: key, in: .generalCocoa) > 0, "「介面語言」不在「一般設定」（AppKit）內")
    #expect(try occurrences(of: key, in: .behaviorUI) == 0, "「介面語言」外洩至「行為設定」（SwiftUI）")
    #expect(try occurrences(of: key, in: .behaviorCocoa) == 0, "「介面語言」外洩至「行為設定」（AppKit）")
  }

  // MARK: Private

  private enum Pane: String {
    case generalUI = "SettingsUI/VwrSettingsPaneGeneral.swift"
    case behaviorUI = "SettingsUI/VwrSettingsPaneBehavior.swift"
    case generalCocoa = "SettingsCocoa/VwrSettingsPaneCocoaGeneral.swift"
    case behaviorCocoa = "SettingsCocoa/VwrSettingsPaneCocoaBehavior.swift"

    // MARK: Internal

    var url: URL {
      // #filePath ⇒ <pkg>/Tests/SettingsUITests/PaneLayoutTests.swift
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // …/Tests/SettingsUITests
        .deletingLastPathComponent() // …/Tests
        .deletingLastPathComponent() // …（套件根）
        .appendingPathComponent("Sources/SettingsUI/\(rawValue)")
    }
  }

  private func occurrences(of key: String, in pane: Pane) throws -> Int {
    let text = try String(contentsOf: pane.url, encoding: .utf8)
    return text.components(separatedBy: "UserDef.\(key)").count - 1
  }
}
