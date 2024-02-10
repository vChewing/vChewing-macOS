// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import BookmarkManager
import IMKUtils
import Shared
import SwiftUI

private let kWindowTitleHeight: Double = 78

// InputMethodServerPreferencesWindowControllerClass 非必需。

@available(macOS 13, *)
public class CtlSettingsUI: NSWindowController, NSWindowDelegate {
  public static var shared: CtlSettingsUI?

  public static func show() {
    if shared == nil {
      let newWindow = NSWindow(
        contentRect: CGRect(x: 401, y: 295, width: 577, height: 568),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered, defer: true
      )
      let newInstance = CtlSettingsUI(window: newWindow)
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

  override public func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)
    window?.contentView = NSHostingView(
      rootView: VwrSettingsUI()
        .fixedSize(horizontal: true, vertical: false)
        .ignoresSafeArea()
    )
    let toolbar = NSToolbar(identifier: "vChewing.Settings.SwiftUI.Toolbar")
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
extension CtlSettingsUI: NSToolbarDelegate {
  public var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    [.init("Collapse or Expand Sidebar")]
  }

  public func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  public func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  public func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    []
  }

  public func toolbar(
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
public extension CtlSettingsUI {
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

@available(macOS 10.15, *)
public extension View {
  func settingsDescription(maxWidth: CGFloat? = .infinity) -> some View {
    controlSize(.small)
      .frame(maxWidth: maxWidth, alignment: .leading)
      // TODO: Use `.foregroundStyle` when targeting macOS 12.
      .foregroundColor(.secondary)
  }
}

@available(macOS 10.15, *)
public extension View {
  func formStyled() -> some View {
    if #available(macOS 13, *) { return self.formStyle(.grouped) }
    return padding()
  }
}
