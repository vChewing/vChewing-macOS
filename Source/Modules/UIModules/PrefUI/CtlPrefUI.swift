// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Preferences
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
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "General"),
        title: NSLocalizedString("General", comment: ""),
        toolbarIcon: .tabImageGeneral
      ) {
        VwrPrefPaneGeneral()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Experience"),
        title: NSLocalizedString("Experience", comment: ""),
        toolbarIcon: .tabImageExperience
      ) {
        VwrPrefPaneExperience()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Dictionary"),
        title: NSLocalizedString("Dictionary", comment: ""),
        toolbarIcon: .tabImageDictionary
      ) {
        VwrPrefPaneDictionary()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "Keyboard"),
        title: NSLocalizedString("Keyboard", comment: ""),
        toolbarIcon: .tabImageKeyboard
      ) {
        VwrPrefPaneKeyboard()
      },
      Preferences.Pane(
        identifier: Preferences.PaneIdentifier(rawValue: "DevZone"),
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

// MARK: - Windows Aero in Swift UI

// Ref: https://stackoverflow.com/questions/62461957

@available(macOS 10.15, *)
struct VisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context _: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = NSVisualEffectView.State.active
    return visualEffectView
  }

  func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}
