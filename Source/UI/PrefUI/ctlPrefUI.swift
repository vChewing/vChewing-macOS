// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

@available(macOS 11.0, *)
class ctlPrefUI {
  lazy var controller = PreferencesWindowController(
    panes: [
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "General"),
        title: NSLocalizedString("General", comment: ""),
        toolbarIcon: NSImage(
          systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: "General Preferences"
        )
          ?? NSImage(named: NSImage.homeTemplateName)!
      ) {
        suiPrefPaneGeneral()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Experiences"),
        title: NSLocalizedString("Experience", comment: ""),
        toolbarIcon: NSImage(
          systemSymbolName: "person.fill.questionmark", accessibilityDescription: "Experiences Preferences"
        )
          ?? NSImage(named: NSImage.listViewTemplateName)!
      ) {
        suiPrefPaneExperience()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Dictionary"),
        title: NSLocalizedString("Dictionary", comment: ""),
        toolbarIcon: NSImage(
          systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Dictionary Preferences"
        )
          ?? NSImage(named: NSImage.bookmarksTemplateName)!
      ) {
        suiPrefPaneDictionary()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Keyboard"),
        title: NSLocalizedString("Keyboard", comment: ""),
        toolbarIcon: NSImage(
          systemSymbolName: "keyboard.macwindow", accessibilityDescription: "Keyboard Preferences"
        )
          ?? NSImage(named: NSImage.actionTemplateName)!
      ) {
        suiPrefPaneKeyboard()
      },
    ],
    style: .toolbarItems
  )
  static let shared = ctlPrefUI()
}
