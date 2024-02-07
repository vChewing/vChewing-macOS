// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared

private let kWindowTitleHeight: Double = 78

// InputMethodServerPreferencesWindowControllerClass 非必需。

public class CtlSettingsCocoa: NSWindowController, NSWindowDelegate {
  let panes = SettingsPanesCocoa()
  var previousView: NSView?

  public static var shared: CtlSettingsCocoa?

  @objc var observation: NSKeyValueObservation?

  public init() {
    super.init(
      window: .init(
        contentRect: CGRect(x: 401, y: 295, width: 577, height: 406),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: true
      )
    )
    panes.preload()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  public static func show() {
    if shared == nil {
      shared = CtlSettingsCocoa()
    }
    guard let shared = shared, let sharedWindow = shared.window else { return }
    sharedWindow.delegate = shared
    if !sharedWindow.isVisible {
      shared.windowDidLoad()
    }
    sharedWindow.setPosition(vertical: .top, horizontal: .right, padding: 20)
    sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    shared.showWindow(shared)
    NSApp.popup()
  }

  private var currentLanguageSelectItem: NSMenuItem?

  override public func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)

    var preferencesTitleName = NSLocalizedString("vChewing Preferences…", comment: "")
    preferencesTitleName.removeLast()
    let toolbar = NSToolbar(identifier: "preference toolbar")
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.sizeMode = .default
    toolbar.delegate = self
    toolbar.selectedItemIdentifier = PrefUITabs.tabGeneral.toolbarIdentifier
    toolbar.showsBaselineSeparator = true
    if #available(macOS 11.0, *) {
      window?.toolbarStyle = .preference
    }
    window?.toolbar = toolbar
    window?.title = "\(preferencesTitleName) (\(IMEApp.appVersionLabel))"
    if #available(macOS 10.10, *) {
      window?.titlebarAppearsTransparent = false
    }
    window?.allowsToolTipsWhenApplicationIsInactive = false
    window?.autorecalculatesKeyViewLoop = false
    window?.isRestorable = false
    window?.animationBehavior = .default
    window?.styleMask = [.titled, .closable, .miniaturizable]

    use(view: panes.ctlPageGeneral.view, animate: false)
  }
}

// MARK: - NSToolbarDelegate Methods

extension CtlSettingsCocoa: NSToolbarDelegate {
  func use(view newView: NSView, animate: Bool = true) {
    guard let window = window, let existingContentView = window.contentView else { return }
    guard previousView != newView else { return }
    newView.layoutSubtreeIfNeeded()
    previousView = newView
    let temporaryViewOld = NSView(frame: existingContentView.frame)
    window.contentView = temporaryViewOld
    var newWindowRect = NSRect(origin: window.frame.origin, size: newView.fittingSize)
    newWindowRect.size.height += kWindowTitleHeight
    newWindowRect.origin.y = window.frame.maxY - newWindowRect.height
    window.setFrame(newWindowRect, display: true, animate: animate)
    window.contentView = newView
  }

  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    PrefUITabs.allCases.map(\.toolbarIdentifier)
  }

  public func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  public func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  public func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  @objc func updateTab(_ target: NSToolbarItem) {
    guard let tab = PrefUITabs.fromInt(target.tag) else { return }
    switch tab {
    case .tabGeneral: use(view: panes.ctlPageGeneral.view)
    case .tabCandidates: use(view: panes.ctlPageCandidates.view)
    case .tabBehavior: use(view: panes.ctlPageBehavior.view)
    case .tabOutput: use(view: panes.ctlPageOutput.view)
    case .tabDictionary: use(view: panes.ctlPageDictionary.view)
    case .tabPhrases: use(view: panes.ctlPagePhrases.view)
    case .tabCassette: use(view: panes.ctlPageCassette.view)
    case .tabKeyboard: use(view: panes.ctlPageKeyboard.view)
    case .tabDevZone: use(view: panes.ctlPageDevZone.view)
    }
    window?.toolbar?.selectedItemIdentifier = tab.toolbarIdentifier
  }

  public func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    guard let tab = PrefUITabs(rawValue: itemIdentifier.rawValue) else { return nil }
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.target = self
    item.image = tab.icon
    item.label = tab.i18nTitle
    item.toolTip = tab.i18nTitle
    item.tag = tab.cocoaTag
    item.action = #selector(updateTab(_:))
    return item
  }
}
