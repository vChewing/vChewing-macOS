// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import IMKUtils
import MainAssembly
import Shared
import SwiftUI

private let kWindowTitleHeight: Double = 78

// InputMethodServerPreferencesWindowControllerClass 非必需。

@available(macOS 13, *)
class CtlPrefUI: NSWindowController, NSWindowDelegate {
  public static var shared: CtlPrefUI?

  static func show() {
    if shared == nil {
      let newWindow = NSWindow(
        contentRect: CGRect(x: 401, y: 295, width: 577, height: 568),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered, defer: true
      )
      let newInstance = CtlPrefUI(window: newWindow)
      shared = newInstance
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

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)
    window?.contentView = NSHostingView(
      rootView: VwrSettingsUI()
        .fixedSize(horizontal: true, vertical: false)
        .ignoresSafeArea()
    )
    let toolbar = NSToolbar(identifier: "preference toolbar")
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.sizeMode = .default
    toolbar.delegate = self
    toolbar.selectedItemIdentifier = nil
    toolbar.showsBaselineSeparator = true
    window?.toolbarStyle = .unifiedCompact
    window?.toolbar = toolbar
    var preferencesTitleName = NSLocalizedString("vChewing Preferences…", comment: "")
    preferencesTitleName.removeLast()
    window?.title = preferencesTitleName
  }
}

// MARK: - NSToolbarDelegate.

@available(macOS 13, *)
extension CtlPrefUI: NSToolbarDelegate {
  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    [.init("Collapse or Expand Sidebar")]
  }

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    []
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.isNavigational = true
    item.target = window?.firstResponder
    item.image = NSImage(named: "NSTouchBarSidebarTemplate") ?? .init()
    item.tag = 0
    item.action = #selector(NSSplitViewController.toggleSidebar(_:))
    return item
  }
}

// MARK: - Shared Static Variables and Constants

@available(macOS 13, *)
extension CtlPrefUI {
  static let sentenceSeparator: String = {
    switch PrefMgr.shared.appleLanguages[0] {
    case "ja":
      return ""
    default:
      if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
        return ""
      } else {
        return " "
      }
    }
  }()

  static let contentMaxHeight: Double = 490

  static let formWidth: Double = {
    switch PrefMgr.shared.appleLanguages[0] {
    case "ja":
      return 520
    default:
      if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
        return 500
      } else {
        return 580
      }
    }
  }()

  static var isCJKInterface: Bool {
    PrefMgr.shared.appleLanguages[0].contains("zh-Han") || PrefMgr.shared.appleLanguages[0] == "ja"
  }
}
