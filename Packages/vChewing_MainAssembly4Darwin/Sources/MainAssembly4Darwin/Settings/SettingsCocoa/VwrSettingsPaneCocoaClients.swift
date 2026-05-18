// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa.Clients

extension SettingsPanesCocoa {
  public final class Clients: NSViewController {
    // MARK: Public

    override public func loadView() {
      tblClients.reloadData()
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
      btnRemoveClient.keyEquivalent = .init(NSEvent.SpecialKey.delete.unicodeScalar)
    }

    // MARK: Internal

    let buttonWidth: CGFloat = 150
    let tableHeight: CGFloat = 390

    lazy var tblClients: NSTableView = .init()
    lazy var btnAddClient = NSButton(
      "i18n:ClientManager.AddClient",
      target: self,
      action: #selector(btnAddClientClicked(_:))
    ).controlSize(.small).withNarrowedFont(size: NSFont.smallSystemFontSize)
    lazy var btnRemoveClient = NSButton(
      "i18n:Common.RemoveSelected",
      target: self,
      action: #selector(btnRemoveClientClicked(_:))
    ).controlSize(.small).withNarrowedFont(size: NSFont.smallSystemFontSize)
    lazy var tableColumn1Cell = NSButtonCell()
    lazy var tableColumn1 = NSTableColumn()
    lazy var tableColumn2Cell = NSTextFieldCell()
    lazy var tableColumn2 = NSTableColumn()

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.build(.vertical) {
          NSStackView.build(.horizontal, spacing: 6) {
            btnAddClient
            NSView()
            btnRemoveClient
          }
          makeScrollableTable()
            .makeSimpleConstraint(.height, relation: .equal, value: tableHeight)
          NSStackView.build(.horizontal) {
            let descriptionWidth = contentWidth
            NSStackView.build(.vertical) {
              let strDescription =
                "i18n:ClientManager.ManageClientsDescription"
              strDescription.makeNSLabel(descriptive: true, fixWidth: descriptionWidth)
                .makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: descriptionWidth)
              NSView()
            }
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    static func clientTableRowHeight(for font: NSFont) -> CGFloat {
      max(20, ceil(font.ascender - font.descender + font.leading) + 4)
    }

    func makeScrollableTable() -> NSScrollView {
      let scrollContainer = NSScrollView()
      scrollContainer.scrollerStyle = .legacy
      scrollContainer.autohidesScrollers = true
      scrollContainer.documentView = tblClients
      scrollContainer.hasVerticalScroller = true
      scrollContainer.hasHorizontalScroller = true

      if #available(macOS 26, *) {
        scrollContainer.borderType = .lineBorder
      }

      let narrowSysFont = NSFont.narrowedFont(size: 15)

      if #available(macOS 11.0, *) {
        tblClients.style = .inset
      }
      tblClients.addTableColumn(tableColumn1)
      tblClients.addTableColumn(tableColumn2)
      tblClients.headerView = nil
      tblClients.delegate = self
      tblClients.allowsExpansionToolTips = true
      tblClients.allowsMultipleSelection = true
      tblClients.autoresizingMask = [.width, .height]
      tblClients.autosaveTableColumns = false
      tblClients.backgroundColor = NSColor.controlBackgroundColor
      tblClients.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
      tblClients.frame = CGRect(x: 0, y: 0, width: contentWidth - 20, height: tableHeight)
      tblClients.gridColor = NSColor.clear
      tblClients.intercellSpacing = CGSize(width: 17, height: 0)
      tblClients.rowHeight = Self.clientTableRowHeight(for: narrowSysFont)
      tblClients.setContentHuggingPriority(.defaultHigh, for: .vertical)
      tblClients.registerForDraggedTypes([.kUTTypeFileURL])
      tblClients.dataSource = self
      tblClients.action = #selector(onItemClicked(_:))
      tblClients.target = self
      if #available(macOS 11.0, *) { tblClients.style = .fullWidth }

      tableColumn1.identifier = NSUserInterfaceItemIdentifier("colPCBEnabled")
      tableColumn1.maxWidth = 20
      tableColumn1.minWidth = 20
      tableColumn1.resizingMask = [.autoresizingMask, .userResizingMask]
      tableColumn1.width = 20
      tableColumn1.dataCell = tableColumn1Cell

      tableColumn1Cell.font = narrowSysFont
      tableColumn1Cell.setButtonType(.switch)
      tableColumn1Cell.bezelStyle = .rounded

      tableColumn2.identifier = NSUserInterfaceItemIdentifier("colClient")
      tableColumn2.maxWidth = 1_000
      tableColumn2.minWidth = 40
      tableColumn2.resizingMask = [.autoresizingMask, .userResizingMask]
      tableColumn2.width = 546
      tableColumn2.dataCell = tableColumn2Cell

      tableColumn2Cell.backgroundColor = NSColor.controlBackgroundColor
      tableColumn2Cell.font = narrowSysFont
      tableColumn2Cell.isEditable = true
      tableColumn2Cell.isSelectable = true
      tableColumn2Cell.lineBreakMode = .byTruncatingTail
      tableColumn2Cell.stringValue = "Text Cell"
      tableColumn2Cell.textColor = NSColor.controlTextColor
      tableColumn2Cell.isEditable = true

      return scrollContainer
    }
  }
}

// MARK: - UserDefaults Handlers.

extension SettingsPanesCocoa.Clients {
  public static var clientsList: [String] {
    PrefMgr.shared.clientsIMKTextInputIncapable.keys.sorted()
  }

  public static func removeClient(at index: Int) {
    guard index < Self.clientsList.count else { return }
    let key = Self.clientsList[index]
    var dict = PrefMgr.shared.clientsIMKTextInputIncapable
    dict[key] = nil
    PrefMgr.shared.clientsIMKTextInputIncapable = dict
  }
}

// MARK: - Common Operation Methods.

extension SettingsPanesCocoa.Clients {
  func applyNewValue(_ newValue: String, highMitigation mitigation: Bool = true) {
    guard !newValue.isEmpty else { return }
    var dict = PrefMgr.shared.clientsIMKTextInputIncapable
    dict[newValue] = mitigation
    PrefMgr.shared.clientsIMKTextInputIncapable = dict
    tblClients.reloadData()
    btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(
      tblClients.selectedRow
    )
  }

  /// 檢查傳入的 NSDraggingInfo 當中的 URL 對應的物件是否是 App Bundle。
  /// - Parameters:
  ///   - info: 傳入的 NSDraggingInfo 物件。
  ///   - onError: 當不滿足判定條件時，執行給定的 lambda expression。
  ///   - handler: 當滿足判定條件時，讓傳入的 lambda expression 處理已經整理出來的 URL 陣列。
  private func validatePasteboardForAppBundles(
    neta info: NSDraggingInfo, onError: @escaping () -> ()?, handler: (([URL]) -> ())? = nil
  ) {
    let board = info.draggingPasteboard
    let type = NSPasteboard.PasteboardType.kUTTypeAppBundle
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
      .urlReadingContentsConformToTypes: [type],
    ]
    guard let urls = board.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
          !urls.isEmpty else {
      onError()
      return
    }
    if let handler = handler {
      handler(urls)
    }
  }
}

// MARK: - IBActions.

extension SettingsPanesCocoa.Clients {
  @IBAction
  func onItemClicked(_: Any!) {
    guard tblClients.clickedColumn == 0 else { return }
    PrefMgr.shared.clientsIMKTextInputIncapable[Self.clientsList[tblClients.clickedRow]]?.toggle()
    tblClients.reloadData()
  }

  @IBAction
  func btnRemoveClientClicked(_: Any) {
    guard let minIndexSelected = tblClients.selectedRowIndexes.min() else { return }
    if minIndexSelected >= Self.clientsList.count { return }
    if minIndexSelected < 0 { return }
    var isLastRow = false
    tblClients.selectedRowIndexes.sorted().reversed().forEach { index in
      isLastRow = {
        if Self.clientsList.count < 2 { return false }
        return minIndexSelected == Self.clientsList.count - 1
      }()
      if index < Self.clientsList.count {
        Self.removeClient(at: index)
      }
    }
    if isLastRow {
      tblClients.selectRowIndexes(
        .init(arrayLiteral: minIndexSelected - 1),
        byExtendingSelection: false
      )
    }
    tblClients.reloadData()
    btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(minIndexSelected)
  }

  @IBAction
  func btnAddClientClicked(_: Any) {
    guard let window = CtlSettingsCocoa.shared?.window else { return }
    let alert = NSAlert()
    alert.messageText = "i18n:ClientManager.EnterBundleIdentifier".i18n
    alert.informativeText = "i18n:PhraseEditor.OneRecordPerLine".i18n
    alert.addButton(withTitle: "i18n:Common.OK".i18n)
    alert.addButton(withTitle: "i18n:Common.JustSelect".i18n + "\u{2026}")
    alert.addButton(withTitle: "i18n:Common.Cancel".i18n)

    let maxFloat = Double(Float.greatestFiniteMagnitude)
    let scrollview = NSScrollView(frame: CGRect(x: 0, y: 0, width: 370, height: 200))
    let contentSize = scrollview.contentSize
    scrollview.borderType = .noBorder
    scrollview.hasVerticalScroller = true
    scrollview.hasHorizontalScroller = true
    scrollview.horizontalScroller?.scrollerStyle = .legacy
    scrollview.verticalScroller?.scrollerStyle = .legacy
    scrollview.autoresizingMask = [.width, .height]
    let theTextView = NSTextView(frame: CGRect(
      x: 0,
      y: 0,
      width: contentSize.width,
      height: contentSize.height
    ))
    scrollview.documentView = theTextView
    theTextView.minSize = CGSize(width: 0.0, height: contentSize.height)
    theTextView.maxSize = CGSize(width: maxFloat, height: maxFloat)
    theTextView.isVerticallyResizable = true
    theTextView.isHorizontallyResizable = false
    theTextView.autoresizingMask = .width
    theTextView.textContainer?.containerSize = CGSize(width: contentSize.width, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = true
    theTextView.enclosingScrollView?.hasHorizontalScroller = true
    theTextView.isHorizontallyResizable = true
    theTextView.autoresizingMask = [.width, .height]
    theTextView.textContainer?.containerSize = CGSize(width: maxFloat, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = false

    // 預先填寫近期用過唯音輸入法的客體軟體，最多二十筆。
    theTextView.textContainer?.textView?.string = {
      let recentClients = InputSession.recentClientBundleIdentifiers.keys.compactMap {
        PrefMgr.shared.clientsIMKTextInputIncapable.keys.contains($0) ? nil : $0
      }
      return recentClients.sorted().joined(separator: "\n")
    }()

    alert.accessoryView = scrollview
    alert.beginSheetModal(at: window) { [weak self] result in
      resultCheck: switch result {
      case .alertFirstButtonReturn, .alertSecondButtonReturn:
        theTextView.textContainer?.textView?.string.components(separatedBy: "\n")
          .filter { !$0.isEmpty }.forEach {
            self?.applyNewValue($0, highMitigation: result == .alertFirstButtonReturn)
          }
        if result == .alertFirstButtonReturn { break }
        if #unavailable(macOS 10.13) {
          window
            .callAlert(
              title: "i18n:ClientManager.DragAppsInstruction".i18n
            )
          break resultCheck
        }
        let dlgOpenPath = NSOpenPanel()
        dlgOpenPath.title = "i18n:Settings.ChooseTargetAppBundle".i18n
        dlgOpenPath.showsResizeIndicator = true
        dlgOpenPath.allowsMultipleSelection = true
        if #available(macOS 11.0, *) {
          dlgOpenPath.allowedContentTypes = [.applicationBundle]
        } else {
          dlgOpenPath.allowedFileTypes = ["app"]
        }
        dlgOpenPath.allowsOtherFileTypes = false
        dlgOpenPath.showsHiddenFiles = true
        dlgOpenPath.canChooseFiles = true
        dlgOpenPath.canChooseDirectories = false
        dlgOpenPath.beginSheetModal(at: window) { [weak self] result in
          switch result {
          case .OK:
            for url in dlgOpenPath.urls {
              let title =
                "i18n:ErrorMessage.InvalidAppBundle".i18n
              let text = url.path + "\n\n" + "i18n:Common.PleaseTryAgain".i18n
              guard let bundle = Bundle(url: url) else {
                CtlSettingsCocoa.shared?.window.callAlert(title: title, text: text)
                return
              }
              guard let identifier = bundle.bundleIdentifier else {
                CtlSettingsCocoa.shared?.window.callAlert(title: title, text: text)
                return
              }
              let isIdentifierAlreadyRegistered = Self.clientsList.contains(identifier)
              let alert2 = NSAlert()
              alert2.messageText =
                "i18n:ClientManager.EnablePopupCompositionBuffer".i18n
              alert2.informativeText = "\(identifier)\n\n"
                + "i18n:ClientManager.CompatibilityNote".i18n
              alert2.addButton(withTitle: "i18n:Common.Yes".i18n)
              alert2.addButton(withTitle: "i18n:Common.No".i18n)
              alert2.beginSheetModal(for: window) { [weak self] result2 in
                let oldValue = PrefMgr.shared.clientsIMKTextInputIncapable[identifier]
                let newValue = result2 == .alertFirstButtonReturn
                if !(isIdentifierAlreadyRegistered && oldValue == newValue), let this = self {
                  this.applyNewValue(identifier, highMitigation: newValue)
                }
              }
            }
          default: return
          }
        }
      default: return
      }
    }
  }
}

// MARK: - SettingsPanesCocoa.Clients + NSTableViewDelegate, NSTableViewDataSource

extension SettingsPanesCocoa.Clients: NSTableViewDelegate, NSTableViewDataSource {
  public func numberOfRows(in _: NSTableView) -> Int {
    Self.clientsList.count
  }

  public func tableView(_: NSTableView, shouldEdit _: NSTableColumn?, row _: Int) -> Bool {
    false
  }

  public func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    defer {
      self.btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(
        self.tblClients.selectedRow
      )
    }
    guard row < Self.clientsList.count else { return "" }
    if let column = column {
      let colName = column.identifier.rawValue
      switch colName {
      case "colPCBEnabled":
        let tick = PrefMgr.shared.clientsIMKTextInputIncapable[Self.clientsList[row]] ?? true
        return tick
      case "colClient": return Self.clientsList[row]
      default: return ""
      }
    }
    return Self.clientsList[row]
  }

  public func tableView(
    _: NSTableView, validateDrop info: NSDraggingInfo, proposedRow _: Int,
    proposedDropOperation _: NSTableView.DropOperation
  )
    -> NSDragOperation {
    var result = NSDragOperation.copy
    validatePasteboardForAppBundles(
      neta: info, onError: { result = .init(rawValue: 0) } // 對應 NSDragOperationNone。
    )
    return result
  }

  public func tableView(
    _: NSTableView, acceptDrop info: NSDraggingInfo,
    row _: Int, dropOperation _: NSTableView.DropOperation
  )
    -> Bool {
    var result = true
    validatePasteboardForAppBundles(
      neta: info, onError: { result = false } // 對應 NSDragOperationNone。
    ) { theURLs in
      var dealt = false
      theURLs.forEach { url in
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        self.applyNewValue(bundleID, highMitigation: true)
        dealt = true
      }
      result = dealt
    }
    defer { if result { tblClients.reloadData() } }
    return result
  }
}

// MARK: - Preview.

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 614, height: 768)) {
  SettingsPanesCocoa.Clients()
}
