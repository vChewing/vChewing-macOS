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

@available(macOS 10.15, *)
class CtlPrefUI: NSWindowController, NSWindowDelegate {
  static var vwrGeneral: NSView = generateView(tab: .tabGeneral)
  static var vwrCandidates: NSView = generateView(tab: .tabCandidates)
  static var vwrBehavior: NSView = generateView(tab: .tabBehavior)
  static var vwrOutput: NSView = generateView(tab: .tabOutput)
  static var vwrDictionary: NSView = generateView(tab: .tabDictionary)
  static var vwrPhrases: NSView = generateView(tab: .tabPhrases)
  static var vwrCassette: NSView = generateView(tab: .tabCassette)
  static var vwrKeyboard: NSView = generateView(tab: .tabKeyboard)
  static var vwrDevZone: NSView = generateView(tab: .tabDevZone)

  static func generateView(tab: PrefUITabs) -> NSView {
    var body: some View {
      Group {
        switch tab {
        case .tabGeneral: VwrPrefPaneGeneral()
        case .tabCandidates: VwrPrefPaneCandidates()
        case .tabBehavior: VwrPrefPaneBehavior()
        case .tabOutput: VwrPrefPaneOutput()
        case .tabDictionary: VwrPrefPaneDictionary()
        case .tabPhrases: VwrPrefPanePhrases()
        case .tabCassette: VwrPrefPaneCassette()
        case .tabKeyboard: VwrPrefPaneKeyboard()
        case .tabDevZone: VwrPrefPaneDevZone()
        }
      }.fixedSize()
    }
    return NSHostingView(rootView: body.edgesIgnoringSafeArea(.top))
  }

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
    window?.titlebarAppearsTransparent = false
    use(view: Self.vwrGeneral, animate: false)
  }
}

// MARK: - NSToolbarDelegate Methods

@available(macOS 10.15, *)
extension CtlPrefUI: NSToolbarDelegate {
  func use(view newView: NSView, animate: Bool = true) {
    // 強制重置語彙編輯器畫面。
    if window?.contentView == Self.vwrPhrases || newView == Self.vwrPhrases {
      Self.vwrPhrases = Self.generateView(tab: .tabPhrases)
    }
    guard let window = window, let existingContentView = window.contentView else { return }
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

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  @objc func updateTab(_ target: NSToolbarItem) {
    guard let tab = PrefUITabs.fromInt(target.tag) else { return }
    switch tab {
    case .tabGeneral: use(view: Self.vwrGeneral)
    case .tabCandidates: use(view: Self.vwrCandidates)
    case .tabBehavior: use(view: Self.vwrBehavior)
    case .tabOutput: use(view: Self.vwrOutput)
    case .tabDictionary: use(view: Self.vwrDictionary)
    case .tabPhrases: use(view: Self.vwrPhrases)
    case .tabCassette: use(view: Self.vwrCassette)
    case .tabKeyboard: use(view: Self.vwrKeyboard)
    case .tabDevZone: use(view: Self.vwrDevZone)
    }
    window?.toolbar?.selectedItemIdentifier = tab.toolbarIdentifier
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    guard let tab = PrefUITabs(rawValue: itemIdentifier.rawValue) else { return nil }
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.target = self
    item.image = tab.icon
    item.label = tab.i18nTitle
    item.tag = tab.cocoaTag
    item.action = #selector(updateTab(_:))
    return item
  }
}
