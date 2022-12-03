// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SSPreferences
import SwiftExtension
import SwiftUI

extension NSImage {
  static var tabImageGeneral: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-General")
    } else {
      return NSImage(
        systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: "General Preferences"
      )
    }
  }

  static var tabImageExperience: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-Experience")
    } else {
      return NSImage(
        systemSymbolName: "person.fill.questionmark", accessibilityDescription: "Experience Preferences"
      )
    }
  }

  static var tabImageDictionary: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-Dictionary")
    } else {
      return NSImage(
        systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Dictionary Preferences"
      )
    }
  }

  static var tabImagePhrases: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-Phrases")
    } else {
      return NSImage(
        systemSymbolName: "tablecells.badge.ellipsis", accessibilityDescription: "Phrases Preferences"
      )
    }
  }

  static var tabImageCassette: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-Cassette")
    } else {
      return NSImage(
        systemSymbolName: "externaldrive.fill.badge.plus", accessibilityDescription: "Cassette Preferences"
      )
    }
  }

  static var tabImageKeyboard: NSImage! {
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-Keyboard")
    } else {
      return NSImage(
        systemSymbolName: "keyboard.macwindow", accessibilityDescription: "Keyboard Preferences"
      )
    }
  }

  static var tabImageDevZone: NSImage! {
    if #available(macOS 12.0, *) {
      return NSImage(
        systemSymbolName: "hand.raised.circle", accessibilityDescription: "DevZone Preferences"
      )
    }
    if #unavailable(macOS 11.0) {
      return NSImage(named: "PrefToolbar-DevZone")
    } else {
      return NSImage(
        systemSymbolName: "pc", accessibilityDescription: "DevZone Preferences"
      )
    }
  }
}

@available(macOS 10.15, *)
class CtlPrefUI {
  var controller = PreferencesWindowController(
    panes: [
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "General"),
        title: NSLocalizedString("General", comment: ""),
        toolbarIcon: .tabImageGeneral
      ) {
        VwrPrefPaneGeneral()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "Experience"),
        title: NSLocalizedString("Experience", comment: ""),
        toolbarIcon: .tabImageExperience
      ) {
        VwrPrefPaneExperience()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "Dictionary"),
        title: NSLocalizedString("Dictionary", comment: ""),
        toolbarIcon: .tabImageDictionary
      ) {
        VwrPrefPaneDictionary()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "Phrases"),
        title: CtlPrefWindow.locPhrasesTabTitle,
        toolbarIcon: .tabImagePhrases
      ) {
        VwrPrefPanePhrases()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "Cassette"),
        title: NSLocalizedString("Cassette", comment: ""),
        toolbarIcon: .tabImageCassette
      ) {
        VwrPrefPaneCassette()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "Keyboard"),
        title: NSLocalizedString("Keyboard", comment: ""),
        toolbarIcon: .tabImageKeyboard
      ) {
        VwrPrefPaneKeyboard()
      },
      SSPreferences.Pane(
        identifier: SSPreferences.PaneIdentifier(rawValue: "DevZone"),
        title: NSLocalizedString("DevZone", comment: ""),
        toolbarIcon: .tabImageDevZone
      ) {
        VwrPrefPaneDevZone()
      },
    ],
    style: .toolbarItems
  )
  static let shared = CtlPrefUI()
}

// MARK: - Localization-Related Contents.

extension CtlPrefWindow {
  /// 由於用於頁籤標題的某些用語放在 localizable 資源內管理的話容易混亂，所以這裡單獨處理。
  static var locPhrasesTabTitle: String {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return "辞書編集"
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Hans") {
          return "语汇编辑"
        } else if PrefMgr.shared.appleLanguages[0].contains("zh-Hant") {
          return "語彙編輯"
        }
        return "Phrases"
    }
  }
}
