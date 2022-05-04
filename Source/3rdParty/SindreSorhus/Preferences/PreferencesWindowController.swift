// Copyright (c) 2018 and onwards Sindre Sorhus (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

extension NSWindow.FrameAutosaveName {
  static let preferences: NSWindow.FrameAutosaveName = "com.sindresorhus.Preferences.FrameAutosaveName"
}

public final class PreferencesWindowController: NSWindowController {
  private let tabViewController = PreferencesTabViewController()

  public var isAnimated: Bool {
    get { tabViewController.isAnimated }
    set {
      tabViewController.isAnimated = newValue
    }
  }

  public var hidesToolbarForSingleItem: Bool {
    didSet {
      updateToolbarVisibility()
    }
  }

  private func updateToolbarVisibility() {
    window?.toolbar?.isVisible =
      (hidesToolbarForSingleItem == false)
      || (tabViewController.preferencePanesCount > 1)
  }

  public init(
    preferencePanes: [PreferencePane],
    style: Preferences.Style = .toolbarItems,
    animated: Bool = true,
    hidesToolbarForSingleItem: Bool = true
  ) {
    precondition(!preferencePanes.isEmpty, "You need to set at least one view controller")

    let window = UserInteractionPausableWindow(
      contentRect: preferencePanes[0].view.bounds,
      styleMask: [
        .titled,
        .closable,
      ],
      backing: .buffered,
      defer: true
    )
    self.hidesToolbarForSingleItem = hidesToolbarForSingleItem
    super.init(window: window)

    window.contentViewController = tabViewController

    window.titleVisibility = {
      switch style {
        case .toolbarItems:
          return .visible
        case .segmentedControl:
          return preferencePanes.count <= 1 ? .visible : .hidden
      }
    }()

    if #available(macOS 11.0, *), style == .toolbarItems {
      window.toolbarStyle = .preference
    }

    tabViewController.isAnimated = animated
    tabViewController.configure(preferencePanes: preferencePanes, style: style)
    updateToolbarVisibility()
  }

  @available(*, unavailable)
  override public init(window _: NSWindow?) {
    fatalError("init(window:) is not supported, use init(preferences:style:animated:)")
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) is not supported, use init(preferences:style:animated:)")
  }

  /**
     Show the preferences window and brings it to front.

     If you pass a `Preferences.PaneIdentifier`, the window will activate the corresponding tab.

     - Parameter preferencePane: Identifier of the preference pane to display, or `nil` to show the tab that was open when the user last closed the window.

     - Note: Unless you need to open a specific pane, prefer not to pass a parameter at all or `nil`.

     - See `close()` to close the window again.
     - See `showWindow(_:)` to show the window without the convenience of activating the app.
     */
  public func show(preferencePane preferenceIdentifier: Preferences.PaneIdentifier? = nil) {
    if let preferenceIdentifier = preferenceIdentifier {
      tabViewController.activateTab(preferenceIdentifier: preferenceIdentifier, animated: false)
    } else {
      tabViewController.restoreInitialTab()
    }

    showWindow(self)
    restoreWindowPosition()
    NSApp.activate(ignoringOtherApps: true)
  }

  private func restoreWindowPosition() {
    guard
      let window = window,
      let screenContainingWindow = window.screen
    else {
      return
    }

    window.setFrameOrigin(
      CGPoint(
        x: screenContainingWindow.visibleFrame.midX - window.frame.width / 2,
        y: screenContainingWindow.visibleFrame.midY - window.frame.height / 2
      ))
    window.setFrameUsingName(.preferences)
    window.setFrameAutosaveName(.preferences)
  }
}

extension PreferencesWindowController {
  /// Returns the active pane if it responds to the given action.
  public override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
    if let target = super.supplementalTarget(forAction: action, sender: sender) {
      return target
    }

    guard let activeViewController = tabViewController.activeViewController else {
      return nil
    }

    if let target = NSApp.target(forAction: action, to: activeViewController, from: sender) as? NSResponder,
      target.responds(to: action)
    {
      return target
    }

    if let target = activeViewController.supplementalTarget(forAction: action, sender: sender) as? NSResponder,
      target.responds(to: action)
    {
      return target
    }

    return nil
  }
}

@available(macOS 10.15, *)
extension PreferencesWindowController {
  /**
     Create a preferences window from only SwiftUI-based preference panes.
     */
  public convenience init(
    panes: [PreferencePaneConvertible],
    style: Preferences.Style = .toolbarItems,
    animated: Bool = true,
    hidesToolbarForSingleItem: Bool = true
  ) {
    let preferencePanes = panes.map { $0.asPreferencePane() }

    self.init(
      preferencePanes: preferencePanes,
      style: style,
      animated: animated,
      hidesToolbarForSingleItem: hidesToolbarForSingleItem
    )
  }
}
