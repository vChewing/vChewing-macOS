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

/// 一個座標翻轉的 NSView，作為 NSScrollView.documentView 使用，
/// 確保內容從頂端開始排列。
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

      var preferencesTitleName = "i18n:Menu.vChewingSettings".i18n
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
      sidebarTableView.delegate = self
      sidebarTableView.dataSource = self
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

  // per-tab UserDef collection map.
  var userDefMap: [PrefUITabs: Set<UserDef>] = [:]

  // Sidebar search field.
  private(set) lazy var searchField: NSSearchField = {
    let sf = NSSearchField()
    sf.translatesAutoresizingMaskIntoConstraints = false
    sf.placeholderString = "i18n:Menu.SearchPreferences".i18n
    sf.sendsWholeSearchString = false
    sf.sendsSearchStringImmediately = true
    if #available(macOS 10.10, *) {
      sf.maximumRecents = 0
    }
    sf.target = self
    sf.action = #selector(searchFieldDidChange(_:))
    return sf
  }()

  func registerUserDef(_ userDef: UserDef, in tab: PrefUITabs) {
    userDefMap[tab, default: []].insert(userDef)
  }

  @objc
  func openHomepage(_: Any?) {
    if let url = URL(string: "https://vchewing.github.io") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc
  func focusSearchField() {
    Self.show()
    window?.makeFirstResponder(searchField)
  }

  // MARK: Private

  private var selectedTab: PrefUITabs = .tabGeneral

  private lazy var searchPopover: NSPopover = {
    let p = NSPopover()
    p.behavior = .transient
    p.animates = false
    return p
  }()

  private lazy var searchResultsTableView: NSTableView = {
    let tv = NSTableView()
    let col = NSTableColumn()
    col.resizingMask = .autoresizingMask
    tv.addTableColumn(col)
    tv.headerView = nil
    tv.focusRingType = .none
    tv.intercellSpacing = NSSize(width: 0, height: 2)
    tv.rowHeight = 24
    tv.delegate = self
    tv.dataSource = self
    tv.target = self
    tv.doubleAction = #selector(searchResultDoubleClicked(_:))
    return tv
  }()

  private var currentSearchResults: [(title: String, tab: PrefUITabs)] = []

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
    return tv
  }()

  private lazy var contentContainerView: NSView = {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.masksToBounds = true
    return v
  }()

  @objc
  private func searchFieldDidChange(_ sender: NSSearchField) {
    let query = sender.stringValue
    guard !query.isEmpty else {
      searchPopover.close()
      return
    }
    performSearch(query)
  }

  private func performSearch(_ query: String) {
    currentSearchResults.removeAll()
    for (tab, userDefs) in userDefMap {
      for userDef in userDefs {
        guard let meta = userDef.metaData else { continue }
        let title = meta.shortTitle?.i18n ?? ""
        let desc = meta.description?.i18n ?? ""
        guard title.localizedStandardContains(query) || desc.localizedStandardContains(query)
        else { continue }
        currentSearchResults.append((title: title.isEmpty ? userDef.rawValue : title, tab: tab))
      }
    }
    currentSearchResults.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    searchResultsTableView.reloadData()
    if !currentSearchResults.isEmpty {
      showSearchPopover()
    } else {
      searchPopover.close()
    }
  }

  private func showSearchPopover() {
    let rowCount = min(currentSearchResults.count, 10)
    let tableHeight = CGFloat(rowCount) * searchResultsTableView.rowHeight
      + searchResultsTableView.intercellSpacing.height * CGFloat(max(rowCount - 1, 0)) + 12
    let height = max(tableHeight, 60)
    let controller = NSViewController()
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.borderType = .noBorder
    scrollView.documentView = searchResultsTableView
    scrollView.frame.size = NSSize(width: 280, height: height)
    controller.view = scrollView
    searchPopover.contentViewController = controller
    searchPopover.contentSize = NSSize(width: 280, height: height)
    searchPopover.show(relativeTo: searchField.bounds, of: searchField, preferredEdge: .maxY)
  }

  @objc
  private func searchResultDoubleClicked(_ sender: NSTableView) {
    let row = sender.clickedRow
    guard row >= 0, row < currentSearchResults.count else { return }
    let tab = currentSearchResults[row].tab
    searchPopover.close()
    searchField.stringValue = ""
    selectTab(tab)
  }
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
    // 在支援的 macOS 版本上使用 NSVisualEffectView 作為側邊欄背景。
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

    // Search field below icon.
    sidebarContainer.addSubview(searchField)

    // Hidden button for ⌘F keyboard shortcut.
    let searchShortcutButton = NSButton()
    searchShortcutButton.title = ""
    searchShortcutButton.isTransparent = true
    searchShortcutButton.keyEquivalent = "f"
    searchShortcutButton.keyEquivalentModifierMask = .command
    searchShortcutButton.target = self
    searchShortcutButton.action = #selector(focusSearchField)
    sidebarContainer.addSubview(searchShortcutButton)

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
    let versionLabel = NSLabelView()
    versionLabel.translatesAutoresizingMaskIntoConstraints = false
    versionLabel.attributedStringValue = NSAttributedString(string: versionString)
    versionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    if #available(macOS 10.10, *) {
      versionLabel.textColor = .secondaryLabelColor
    } else {
      versionLabel.textColor = .gray
    }

    // Homepage & Donation link button.
    let linkButton = NSButton()
    linkButton.translatesAutoresizingMaskIntoConstraints = false
    linkButton.title = "i18n:settings.button.hpAndDonation".i18n
    if #available(macOS 10.14, *) {
      linkButton.contentTintColor = .linkColor
      linkButton.bezelStyle = .inline
      linkButton.isBordered = false
    }
    linkButton.cell?.controlSize = .small
    linkButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    linkButton.target = self
    linkButton.action = #selector(openHomepage(_:))

    sidebarContainer.addSubview(iconView)
    sidebarContainer.addSubview(tableScrollView)
    sidebarContainer.addSubview(versionLabel)
    sidebarContainer.addSubview(linkButton)

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
      // Search field below icon.
      NSLayoutConstraint(
        item: searchField, attribute: .top, relatedBy: .equal,
        toItem: iconView, attribute: .bottom, multiplier: 1, constant: 6
      ),
      NSLayoutConstraint(
        item: searchField, attribute: .leading, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .leading, multiplier: 1, constant: 12
      ),
      NSLayoutConstraint(
        item: searchField, attribute: .trailing, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .trailing, multiplier: 1, constant: -12
      ),
      // Table: between icon and version label, full width.
      NSLayoutConstraint(
        item: tableScrollView, attribute: .top, relatedBy: .equal,
        toItem: searchField, attribute: .bottom, multiplier: 1, constant: 6
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
      // Version label: above link button.
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
        toItem: linkButton, attribute: .top, multiplier: 1, constant: -4
      ),
      // Link button: bottom, with padding.
      NSLayoutConstraint(
        item: linkButton, attribute: .leading, relatedBy: .equal,
        toItem: sidebarContainer, attribute: .leading, multiplier: 1, constant: 10
      ),
      NSLayoutConstraint(
        item: linkButton, attribute: .trailing, relatedBy: .lessThanOrEqual,
        toItem: sidebarContainer, attribute: .trailing, multiplier: 1, constant: -8
      ),
      NSLayoutConstraint(
        item: linkButton, attribute: .bottom, relatedBy: .equal,
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
      // macOS 10.13 以上使用 NSScrollView 包覆可捲動內容。
      let scrollView = NSScrollView()
      scrollView.translatesAutoresizingMaskIntoConstraints = false
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true
      scrollView.drawsBackground = false
      scrollView.borderType = .noBorder
      scrollView.scrollerStyle = .legacy

      let docView = FlippedClipContainerView()
      docView.translatesAutoresizingMaskIntoConstraints = false
      docView.addSubview(paneView)

      // 將 paneView 四邊釘齊 documentView，使分頁切換時
      // intrinsicContentSize 的變化能自動傳播至 docView，
      // 讓 NSScrollView 在 macOS 10.13–15.x 上正確更新可捲動範圍。
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
        NSLayoutConstraint(
          item: paneView, attribute: .trailing, relatedBy: .equal,
          toItem: docView, attribute: .trailing, multiplier: 1, constant: 0
        ),
        NSLayoutConstraint(
          item: paneView, attribute: .bottom, relatedBy: .equal,
          toItem: docView, attribute: .bottom, multiplier: 1, constant: 0
        ),
      ])

      scrollView.documentView = docView
      contentContainerView.addSubview(scrollView)
      scrollView.pinEdges(to: contentContainerView)

      // Scroll to top.
      scrollView.contentView.scroll(to: .zero)
      scrollView.reflectScrolledClipView(scrollView.contentView)
    } else {
      // macOS 10.13 以下直接將 paneView 放入容器，不使用捲動視圖，
      // 以避免在輸入法程序中觸發系統凍結。
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
  public func numberOfRows(in tableView: NSTableView) -> Int {
    if tableView === sidebarTableView {
      return PrefUITabs.allCases.count
    }
    return currentSearchResults.count
  }

  public func tableView(
    _ tableView: NSTableView,
    viewFor _: NSTableColumn?,
    row: Int
  )
    -> NSView? {
    // search results rows.
    if tableView === sidebarTableView {
      return sidebarRowView(for: row)
    }
    return searchResultRowView(for: row)
  }

  public func tableViewSelectionDidChange(_ notification: Notification) {
    guard let tableView = notification.object as? NSTableView, tableView === sidebarTableView else { return }
    let row = tableView.selectedRow
    guard row >= 0, row < PrefUITabs.allCases.count else { return }
    let tab = PrefUITabs.allCases[row]
    guard tab != selectedTab else { return }
    selectedTab = tab
    showContentForTab(tab)
  }

  // MARK: Search result row

  private func searchResultRowView(for row: Int) -> NSView? {
    guard row >= 0, row < currentSearchResults.count else { return nil }
    let result = currentSearchResults[row]
    let rowView = NSView()
    let textField = NSLabelView()
    textField.translatesAutoresizingMaskIntoConstraints = false
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    let attrStr = NSMutableAttributedString(
      string: result.title,
      attributes: [.paragraphStyle: paragraphStyle, .font: NSFont.systemFont(ofSize: 12)]
    )
    attrStr.append(NSAttributedString(
      string: "  → \(result.tab.i18nTitle)",
      attributes: [
        .paragraphStyle: paragraphStyle,
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.secondaryLabelColor,
      ]
    ))
    textField.attributedStringValue = attrStr
    rowView.addSubview(textField)
    rowView.addConstraints([
      NSLayoutConstraint(
        item: textField,
        attribute: .leading,
        relatedBy: .equal,
        toItem: rowView,
        attribute: .leading,
        multiplier: 1,
        constant: 8
      ),
      NSLayoutConstraint(
        item: textField,
        attribute: .centerY,
        relatedBy: .equal,
        toItem: rowView,
        attribute: .centerY,
        multiplier: 1,
        constant: 0
      ),
      NSLayoutConstraint(
        item: textField,
        attribute: .trailing,
        relatedBy: .equal,
        toItem: rowView,
        attribute: .trailing,
        multiplier: 1,
        constant: -8
      ),
    ])
    return rowView
  }

  // MARK: Sidebar row

  private func sidebarRowView(for row: Int) -> NSView? {
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

    let textField = NSLabelView()
    textField.translatesAutoresizingMaskIntoConstraints = false
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    textField.attributedStringValue = NSAttributedString(
      string: tab.i18nTitle,
      attributes: [.paragraphStyle: paragraphStyle]
    )
    textField.font = NSFont.systemFont(ofSize: 13)

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
}

// MARK: - UserDef renderCocoa with per-tab collection

extension UserDef {
  /// 帶 prefUITab 的 renderCocoa 在渲染同時將 UserDef 登記至 CtlSettingsCocoa.userDefMap。
  func renderCocoa(
    fixWidth: CGFloat? = nil,
    prefUITab: PrefUITabs?,
    extraOps: ((inout UserDefRenderableCocoa) -> ())? = nil
  )
    -> NSView? {
    var renderable = toCocoaRenderable()
    extraOps?(&renderable)
    if let tab = prefUITab {
      asyncOnMain {
        CtlSettingsCocoa.shared?.registerUserDef(self, in: tab)
      }
    }
    return renderable.render(fixWidth: fixWidth)
  }
}
