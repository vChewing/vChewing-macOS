// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

private let kWindowTitleHeight: Double = 78

// MARK: - CtlSettingsCocoa

// InputMethodServerPreferencesWindowControllerClass 非必需。

public final class CtlSettingsCocoa: NSWindowController, NSWindowDelegate {
  // MARK: Lifecycle

  public init() {
    super.init(
      window: .init(
        contentRect: CGRect(x: 401, y: 295, width: 577, height: 406),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: true
      )
    )
    autoreleasepool {
      panes.preload()
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

  public static var shared: CtlSettingsCocoa?

  override public func close() {
    autoreleasepool {
      super.close()
      if NSApplication.isAppleSilicon {
        Self.shared = nil
      }
    }
  }

  override public func windowDidLoad() {
    autoreleasepool {
      super.windowDidLoad()
      window?.setPosition(vertical: .top, horizontal: .right, padding: 20)

      var preferencesTitleName = NSLocalizedString("vChewing Preferences…", comment: "")
      preferencesTitleName.removeLast()
      let toolbar = NSToolbar(identifier: "vChewing.Settings.AppKit.Toolbar")
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

  @objc
  public static func show() {
    autoreleasepool {
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
  }

  // MARK: Internal

  let panes = SettingsPanesCocoa()
  var previousView: NSView?

  @objc
  var observation: NSKeyValueObservation?

  // MARK: Private

  private var currentLanguageSelectItem: NSMenuItem?
}

// MARK: NSToolbarDelegate

extension CtlSettingsCocoa: NSToolbarDelegate {
  func use(view newView: NSView, animate: Bool = true) {
    autoreleasepool {
      guard let window = window, let existingContentView = window.contentView else { return }
      guard previousView != newView else { return }
      newView.layoutSubtreeIfNeeded() // 第一遍，保證 macOS 10.9 系統下的顯示正確。
      previousView = newView
      let temporaryViewOld = NSView(frame: existingContentView.frame)
      window.contentView = temporaryViewOld
      var newWindowRect = CGRect(origin: window.frame.origin, size: newView.fittingSize)
      newWindowRect.size.height += kWindowTitleHeight
      newWindowRect.origin.y = window.frame.maxY - newWindowRect.height
      window.setFrame(newWindowRect, display: true, animate: animate)
      window.contentView = newView
      newView.layoutSubtreeIfNeeded() // 第二遍，保證最近幾年的這幾版系統下的顯示正確。
    }
  }

  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    var coreResults = PrefUITabs.allCases.map(\.toolbarIdentifier)
    guard #unavailable(macOS 11) else { return coreResults }
    // 下文是给 macOS 10.x 系统用的，让工具列的图示全部居中。
    coreResults.insert(.flexibleSpace, at: coreResults.startIndex)
    coreResults.append(.flexibleSpace)
    return coreResults
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

  @objc
  func updateTab(_ target: NSToolbarItem) {
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
  )
    -> NSToolbarItem? {
    autoreleasepool {
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
}
