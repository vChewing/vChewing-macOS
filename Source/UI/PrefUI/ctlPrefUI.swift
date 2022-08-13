// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import SwiftUI

@available(macOS 10.15, *)
class ctlPrefUI {
  private(set) var tabImageGeneral: NSImage! = NSImage(named: "PrefToolbar-General")
  private(set) var tabImageExperiences: NSImage! = NSImage(named: "PrefToolbar-Experiences")
  private(set) var tabImageDictionary: NSImage! = NSImage(named: "PrefToolbar-Dictionary")
  private(set) var tabImageKeyboard: NSImage! = NSImage(named: "PrefToolbar-Keyboard")
  private(set) var tabImageDevZone: NSImage! = NSImage(named: "PrefToolbar-DevZone")

  init() {
    if #available(macOS 11.0, *) {
      tabImageGeneral = NSImage(
        systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: "General Preferences"
      )
      tabImageExperiences = NSImage(
        systemSymbolName: "person.fill.questionmark", accessibilityDescription: "Experiences Preferences"
      )
      tabImageDictionary = NSImage(
        systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Dictionary Preferences"
      )
      tabImageKeyboard = NSImage(
        systemSymbolName: "keyboard.macwindow", accessibilityDescription: "Keyboard Preferences"
      )
      tabImageDevZone = NSImage(
        systemSymbolName: "hand.raised.circle", accessibilityDescription: "DevZone Preferences"
      )
    }
  }

  lazy var controller = PreferencesWindowController(
    panes: [
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "General"),
        title: NSLocalizedString("General", comment: ""),
        toolbarIcon: tabImageGeneral
      ) {
        suiPrefPaneGeneral()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Experiences"),
        title: NSLocalizedString("Experience", comment: ""),
        toolbarIcon: tabImageExperiences
      ) {
        suiPrefPaneExperience()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Dictionary"),
        title: NSLocalizedString("Dictionary", comment: ""),
        toolbarIcon: tabImageDictionary
      ) {
        suiPrefPaneDictionary()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Keyboard"),
        title: NSLocalizedString("Keyboard", comment: ""),
        toolbarIcon: tabImageKeyboard
      ) {
        suiPrefPaneKeyboard()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "DevZone"),
        title: NSLocalizedString("DevZone", comment: ""),
        toolbarIcon: tabImageDevZone
      ) {
        suiPrefPaneDevZone()
      },
    ],
    style: .toolbarItems
  )
  static let shared = ctlPrefUI()
}

// MARK: - Add "onChange" support.

// Ref: https://mjeld.com/swiftui-macos-10-15-toggle-onchange/

@available(macOS 10.15, *)
extension Binding {
  public func onChange(_ action: @escaping () -> Void) -> Binding {
    Binding(
      get: {
        wrappedValue
      },
      set: { newValue in
        wrappedValue = newValue
        action()
      }
    )
  }
}

// MARK: - Add ".tooltip" support.

// Ref: https://stackoverflow.com/a/63217861

@available(macOS 10.15, *)
struct Tooltip: NSViewRepresentable {
  let tooltip: String

  func makeNSView(context _: NSViewRepresentableContext<Tooltip>) -> NSView {
    let view = NSView()
    view.toolTip = tooltip

    return view
  }

  func updateNSView(_: NSView, context _: NSViewRepresentableContext<Tooltip>) {}
}

@available(macOS 10.15, *)
extension View {
  public func toolTip(_ tooltip: String) -> some View {
    overlay(Tooltip(tooltip: tooltip))
  }
}
