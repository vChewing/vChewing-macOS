// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

private let kSidebarWidth: CGFloat = 170

// MARK: - FlippedClipContainerView

/// A flipped NSView for use as NSScrollView.documentView,
/// ensuring content starts from the top.
private final class FlippedClipContainerView: NSView {
  override var isFlipped: Bool { true }
}

// MARK: - CtlSettingsCocoa

// InputMethodServerPreferencesWindowControllerClass 非必需。

public final class CtlSettingsCocoa: NSWindowController, NSWindowDelegate {
  // MARK: Lifecycle

  public init() {
    let totalWidth = kSidebarWidth + 1 + SettingsPanesCocoa.windowWidth
    super.init(
      window: .init(
        contentRect: CGRect(x: 401, y: 295, width: totalWidth, height: 600),
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

  nonisolated deinit {
    #if DEBUG
      NSLog("[CtlSettingsCocoa] deinit called")
    #endif
  }

  // MARK: Public

  public static var shared: CtlSettingsCocoa?

  override public func close() {
    // 由於我們使用靜態 `shared` 變數保留 window controller，
    // 因此每次關閉都要把它清掉，無論 CPU 架構為何。
    // 另外必須把 contentView 從 window 抽離，
    // 否則它會被 NSWindow 仍然持有，導致記憶體不會即時回收。
    autoreleasepool {
      // 先行斷開 delegate 與內容，避免循環引用
      window?.delegate = nil
      sidebarTableView.delegate = nil
      sidebarTableView.dataSource = nil
      previousView = nil
      // 此舉抽離 contentView。
      window?.contentView = nil
      super.close()
      Self.shared = nil
    }
  }

  override public func windowDidLoad() {
    autoreleasepool {
      super.windowDidLoad()
      window?.setPosition(vertical: .top, horizontal: .right, padding: 20)

      var preferencesTitleName = "vChewing Preferences…".i18n
      preferencesTitleName.removeLast()
      window?.title = preferencesTitleName
      if #available(macOS 10.10, *) {
        window?.titlebarAppearsTransparent = false
      }
      window?.allowsToolTipsWhenApplicationIsInactive = false
      window?.autorecalculatesKeyViewLoop = false
      window?.isRestorable = false
      window?.animationBehavior = .default
      window?.styleMask = [.titled, .closable, .miniaturizable]

      previousView = nil
      setupSplitLayout()
      sidebarTableView.reloadData()
      selectTab(.tabGeneral)
    }
  }

  @objc
  public static func show() {
    // 避免在先前已關閉視窗的 controller 上誤觸復活；
    // `shared` 會在 `close()` 或下方的 `windowWillClose(_:)`
    // 中被清空。
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

  // MARK: - NSWindowDelegate helpers

  public func windowWillClose(_ notification: Notification) {
    // 使用者按紅色關閉按鈕或 ⌘W 時走的是這條路徑，
    // 不會觸發 NSWindowController.close() override，
    // 因此必須在此處做同等的清理。
    window?.delegate = nil
    sidebarTableView.delegate = nil
    sidebarTableView.dataSource = nil
    previousView = nil
    window?.contentView = nil
    Self.shared = nil
  }

  // MARK: Internal

  let panes = SettingsPanesCocoa()
  var previousView: NSView?

  // MARK: Private

  private var selectedTab: PrefUITabs = .tabGeneral

  private lazy var sidebarTableView: NSTableView = {
    let tv = NSTableView()
    let column = NSTableColumn()
    column.resizingMask = .autoresizingMask
    tv.addTableColumn(column)
    tv.headerView = nil
    if #available(macOS 11.0, *) {
      tv.style = .sourceList
    } else {
      tv.selectionHighlightStyle = .sourceList
    }
    if #available(macOS 10.14, *) {
      tv.backgroundColor = .clear
    }
    tv.focusRingType = .none
    tv.intercellSpacing = NSSize(width: 0, height: 2)
    tv.backgroundColor = .clear
    tv.rowHeight = 28
    tv.delegate = self
    tv.dataSource = self
    return tv
  }()

  private lazy var contentContainerView: NSView = {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.masksToBounds = true
    return v
  }()
}

// MARK: - Split Layout Setup

extension CtlSettingsCocoa {
  fileprivate func setupSplitLayout() {
    guard let window = window else { return }

    let mainContainer = NSView()
    mainContainer.translatesAutoresizingMaskIntoConstraints = false

    // Sidebar.
    let sidebarView = makeSidebar()
    sidebarView.translatesAutoresizingMaskIntoConstraints = false

    // Divider line.
    let dividerView = NSView()
    dividerView.translatesAutoresizingMaskIntoConstraints = false
    dividerView.wantsLayer = true
    dividerView.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor

    // Content container (right panel).
    contentContainerView.translatesAutoresizingMaskIntoConstraints = false

    mainContainer.addSubview(sidebarView)
    mainContainer.addSubview(dividerView)
    mainContainer.addSubview(contentContainerView)

    window.contentView = mainContainer

    // AutoLayout constraints.
    mainContainer.addConstraints([
      // Sidebar: left, top, bottom, fixed width.
      NSLayoutConstraint(
        item: sidebarView, attribute: .leading, relatedBy: .equal,
        toItem: mainContainer, attribute: .leading, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: sidebarView, attribute: .top, relatedBy: .equal,
        toItem: mainContainer, attribute: .top, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: sidebarView, attribute: .bottom, relatedBy: .equal,
        toItem: mainContainer, attribute: .bottom, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: sidebarView, attribute: .width, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: kSidebarWidth
      ),
      // Divider: 1px between sidebar and content.
      NSLayoutConstraint(
        item: dividerView, attribute: .leading, relatedBy: .equal,
        toItem: sidebarView, attribute: .trailing, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: dividerView, attribute: .top, relatedBy: .equal,
        toItem: mainContainer, attribute: .top, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: dividerView, attribute: .bottom, relatedBy: .equal,
        toItem: mainContainer, attribute: .bottom, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: dividerView, attribute: .width, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 1
      ),
      // Content container: fills remaining space.
      NSLayoutConstraint(
        item: contentContainerView, attribute: .leading, relatedBy: .equal,
        toItem: dividerView, attribute: .trailing, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: contentContainerView, attribute: .top, relatedBy: .equal,
        toItem: mainContainer, attribute: .top, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: contentContainerView, attribute: .bottom, relatedBy: .equal,
        toItem: mainContainer, attribute: .bottom, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: contentContainerView, attribute: .trailing, relatedBy: .equal,
        toItem: mainContainer, attribute: .trailing, multiplier: 1, constant: 0
      ),
    ])
  }

  fileprivate func makeSidebar() -> NSView {
    // Use NSVisualEffectView for sidebar background on supported macOS versions.
    let sidebarContainer: NSView
    if #available(macOS 10.14, *) {
      let effectView = NSVisualEffectView()
      effectView.material = .sidebar
      effectView.blendingMode = .behindWindow
      effectView.state = .followsWindowActiveState
      sidebarContainer = effectView
    } else {
      let plainView = NSView()
      plainView.wantsLayer = true
      plainView.layer?.backgroundColor = CGColor(red: 0.75, green: 0.87, blue: 1.00, alpha: 1.00)
      sidebarContainer = plainView
    }

    // App icon at the top.
    let iconView = NSImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    if let appIcon = NSImage(named: "PrefBanner") {
      iconView.image = appIcon
    }

    // Table view wrapped in scroll view.
    let tableScrollView = NSScrollView()
    tableScrollView.translatesAutoresizingMaskIntoConstraints = false
    tableScrollView.hasVerticalScroller = false
    tableScrollView.hasHorizontalScroller = false
    tableScrollView.borderType = .noBorder
    tableScrollView.drawsBackground = false
    tableScrollView.autohidesScrollers = true
    tableScrollView.documentView = sidebarTableView

    // Version label at the bottom.
    let versionString = "v\(IMEApp.appMainVersionLabel.joined(separator: " Build "))\n\(IMEApp.appSignedDateLabel)"
    let versionLabel = NSTextField()
    versionLabel.translatesAutoresizingMaskIntoConstraints = false
    versionLabel.isEditable = false
    versionLabel.isBordered = false
    versionLabel.drawsBackground = false
    versionLabel.stringValue = versionString
    versionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    if #available(macOS 10.10, *) {
      versionLabel.textColor = .secondaryLabelColor
    } else {
      versionLabel.textColor = .gray
    }

    sidebarContainer.addSubview(iconView)
    sidebarContainer.addSubview(tableScrollView)
    sidebarContainer.addSubview(versionLabel)

    sidebarContainer.addConstraints([
      // Icon: top leading, 48×48.
      NSLayoutConstraint(
        item: iconView, attribute: .top, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .top, multiplier: 1, constant: 12
      ),
      NSLayoutConstraint(
        item: iconView, attribute: .leading, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .leading, multiplier: 1, constant: 12
      ),
      NSLayoutConstraint(
        item: iconView, attribute: .width, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 144
      ),
      NSLayoutConstraint(
        item: iconView, attribute: .height, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 49
      ),
      // Table: between icon and version label, full width.
      NSLayoutConstraint(
        item: tableScrollView, attribute: .top, relatedBy: .equal,
        toItem: iconView, attribute: .bottom, multiplier: 1, constant: 8
      ),
      NSLayoutConstraint(
        item: tableScrollView, attribute: .leading, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .leading, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: tableScrollView, attribute: .trailing, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .trailing, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: tableScrollView, attribute: .bottom, relatedBy: .equal,
        toItem: versionLabel, attribute: .top, multiplier: 1, constant: -8
      ),
      // Version label: bottom, with padding.
      NSLayoutConstraint(
        item: versionLabel, attribute: .leading, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .leading, multiplier: 1, constant: 12
      ),
      NSLayoutConstraint(
        item: versionLabel, attribute: .trailing, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .trailing, multiplier: 1, constant: -8
      ),
      NSLayoutConstraint(
        item: versionLabel, attribute: .bottom, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .bottom, multiplier: 1, constant: -8
      ),
    ])

    return sidebarContainer
  }
}

// MARK: - Tab Selection & Content Switching

extension CtlSettingsCocoa {
  func selectTab(_ tab: PrefUITabs) {
    selectedTab = tab
    if let index = PrefUITabs.allCases.firstIndex(of: tab) {
      sidebarTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }
    showContentForTab(tab)
  }

  private func showContentForTab(_ tab: PrefUITabs) {
    let paneView = viewForTab(tab)
    guard paneView !== previousView else { return }
    previousView = paneView

    contentContainerView.subviews.forEach { $0.removeFromSuperview() }

    paneView.layoutSubtreeIfNeeded()

    if #available(macOS 10.13, *) {
      // Use NSScrollView for scrollable content on macOS 10.13+.
      let scrollView = NSScrollView()
      scrollView.translatesAutoresizingMaskIntoConstraints = false
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true
      scrollView.drawsBackground = false
      scrollView.borderType = .noBorder
      scrollView.scrollerStyle = .legacy

      let docView = FlippedClipContainerView()
      let fittingSize = paneView.fittingSize
      docView.frame = NSRect(
        origin: .zero,
        size: CGSize(
          width: max(fittingSize.width, SettingsPanesCocoa.windowWidth),
          height: fittingSize.height
        )
      )
      docView.addSubview(paneView)

      // Pin pane to document view's top-leading corner.
      paneView.translatesAutoresizingMaskIntoConstraints = false
      docView.addConstraints([
        NSLayoutConstraint(
          item: paneView, attribute: .top, relatedBy: .equal,
          toItem: docView, attribute: .top, multiplier: 1, constant: 0
        ),
        NSLayoutConstraint(
          item: paneView, attribute: .leading, relatedBy: .equal,
          toItem: docView, attribute: .leading, multiplier: 1, constant: 0
        ),
      ])

      scrollView.documentView = docView
      contentContainerView.addSubview(scrollView)
      scrollView.pinEdges(to: contentContainerView)

      // Scroll to top.
      scrollView.contentView.scroll(to: .zero)
      scrollView.reflectScrolledClipView(scrollView.contentView)
    } else {
      // On macOS < 10.13, place pane directly without scroll view
      // to avoid potential system freeze in input method processes.
      contentContainerView.addSubview(paneView)
      paneView.translatesAutoresizingMaskIntoConstraints = false
      contentContainerView.addConstraints([
        NSLayoutConstraint(
          item: paneView, attribute: .top, relatedBy: .equal,
          toItem: contentContainerView, attribute: .top, multiplier: 1, constant: 0
        ),
        NSLayoutConstraint(
          item: paneView, attribute: .leading, relatedBy: .equal,
          toItem: contentContainerView, attribute: .leading, multiplier: 1, constant: 0
        ),
        NSLayoutConstraint(
          item: paneView, attribute: .trailing, relatedBy: .equal,
          toItem: contentContainerView, attribute: .trailing, multiplier: 1, constant: 0
        ),
      ])
    }
  }

  private func viewForTab(_ tab: PrefUITabs) -> NSView {
    switch tab {
    case .tabAbout: return panes.ctlPageAbout.view
    case .tabGeneral: return panes.ctlPageGeneral.view
    case .tabCandidates: return panes.ctlPageCandidates.view
    case .tabBehavior: return panes.ctlPageBehavior.view
    case .tabOutput: return panes.ctlPageOutput.view
    case .tabDictionary: return panes.ctlPageDictionary.view
    case .tabPhrases: return panes.ctlPagePhrases.view
    case .tabCassette: return panes.ctlPageCassette.view
    case .tabKeyboard: return panes.ctlPageKeyboard.view
    case .tabClients: return panes.ctlPageClients.view
    case .tabServices: return panes.ctlPageServices.view
    case .tabDevZone: return panes.ctlPageDevZone.view
    }
  }
}

// MARK: NSTableViewDelegate, NSTableViewDataSource

extension CtlSettingsCocoa: NSTableViewDelegate, NSTableViewDataSource {
  public func numberOfRows(in _: NSTableView) -> Int {
    PrefUITabs.allCases.count
  }

  public func tableView(
    _ tableView: NSTableView,
    viewFor _: NSTableColumn?,
    row: Int
  )
    -> NSView? {
    guard row >= 0, row < PrefUITabs.allCases.count else { return nil }
    let tab = PrefUITabs.allCases[row]

    let rowView = NSView()

    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = tab.icon
    imageView.wantsLayer = true
    imageView.shadow = {
      let s = NSShadow()
      s.shadowColor = NSColor.black.withAlphaComponent(0.6)
      s.shadowOffset = NSSize(width: 0, height: -0.5)
      s.shadowBlurRadius = 1.5
      return s
    }()

    let textField = NSTextField()
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.stringValue = tab.i18nTitle
    textField.isEditable = false
    textField.isBordered = false
    textField.drawsBackground = false
    textField.backgroundColor = .clear
    textField.font = NSFont.systemFont(ofSize: 13)
    textField.cell?.lineBreakMode = .byTruncatingTail
    textField.cell?.truncatesLastVisibleLine = true

    rowView.addSubview(imageView)
    rowView.addSubview(textField)

    rowView.addConstraints([
      NSLayoutConstraint(
        item: imageView, attribute: .leading, relatedBy: .equal,
        toItem: rowView, attribute: .leading, multiplier: 1, constant: 10
      ),
      NSLayoutConstraint(
        item: imageView, attribute: .centerY, relatedBy: .equal,
        toItem: rowView, attribute: .centerY, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: imageView, attribute: .width, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 16
      ),
      NSLayoutConstraint(
        item: imageView, attribute: .height, relatedBy: .equal,
        toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 16
      ),
      NSLayoutConstraint(
        item: textField, attribute: .leading, relatedBy: .equal,
        toItem: imageView, attribute: .trailing, multiplier: 1, constant: 6
      ),
      NSLayoutConstraint(
        item: textField, attribute: .centerY, relatedBy: .equal,
        toItem: rowView, attribute: .centerY, multiplier: 1, constant: 0
      ),
      NSLayoutConstraint(
        item: textField, attribute: .trailing, relatedBy: .equal,
        toItem: rowView, attribute: .trailing, multiplier: 1, constant: -8
      ),
    ])

    return rowView
  }

  public func tableViewSelectionDidChange(_: Notification) {
    let row = sidebarTableView.selectedRow
    guard row >= 0, row < PrefUITabs.allCases.count else { return }
    let tab = PrefUITabs.allCases[row]
    guard tab != selectedTab else { return }
    selectedTab = tab
    showContentForTab(tab)
  }
}
