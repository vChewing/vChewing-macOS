// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import Shared

// MARK: - VwrClientListMgr

public class VwrClientListMgr: NSViewController {
  // MARK: Public

  override public func loadView() {
    tblClients.reloadData()
    view = body ?? .init()
    (view as? NSStackView)?.alignment = .centerX
    view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    btnRemoveClient.keyEquivalent = .init(NSEvent.SpecialKey.delete.unicodeScalar)
  }

  // MARK: Internal

  let windowWidth: CGFloat = 770
  let contentWidth: CGFloat = 750
  let buttonWidth: CGFloat = 150
  let tableHeight: CGFloat = 230

  lazy var tblClients: NSTableView = .init()
  lazy var btnAddClient = NSButton(
    "Add Client",
    target: self,
    action: #selector(btnAddClientClicked(_:))
  )
  lazy var btnRemoveClient = NSButton(
    "Remove Selected",
    target: self,
    action: #selector(btnRemoveClientClicked(_:))
  )
  lazy var tableColumn1Cell = NSButtonCell()
  lazy var tableColumn1 = NSTableColumn()
  lazy var tableColumn2Cell = NSTextFieldCell()
  lazy var tableColumn2 = NSTableColumn()

  var body: NSView? {
    NSStackView.build(.vertical, insets: .new(all: 14)) {
      makeScrollableTable()
        .makeSimpleConstraint(.height, relation: .equal, value: tableHeight)
      NSStackView.build(.horizontal) {
        let descriptionWidth = contentWidth - buttonWidth - 20
        NSStackView.build(.vertical) {
          let strDescription =
            "Please manage the list of those clients here which are: 1) IMKTextInput-incompatible; 2) suspected from abusing the contents of the inline composition buffer. A client listed here, if checked, will use popup composition buffer with maximum 20 reading counts holdable."
          strDescription.makeNSLabel(descriptive: true, fixWidth: descriptionWidth)
            .makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: descriptionWidth)
          NSView()
        }
        NSStackView.build(.vertical, spacing: 6) {
          btnAddClient
            .makeSimpleConstraint(.width, relation: .equal, value: buttonWidth)
          btnRemoveClient
            .makeSimpleConstraint(.width, relation: .equal, value: buttonWidth)
        }
      }
    }
  }

  func makeScrollableTable() -> NSScrollView {
    let scrollContainer = NSScrollView()
    scrollContainer.scrollerStyle = .legacy
    scrollContainer.autohidesScrollers = true
    scrollContainer.documentView = tblClients
    scrollContainer.hasVerticalScroller = true
    scrollContainer.hasHorizontalScroller = true
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
    tblClients.frame = CGRect(x: 0, y: 0, width: 728, height: tableHeight)
    tblClients.gridColor = NSColor.clear
    tblClients.intercellSpacing = CGSize(width: 17, height: 0)
    tblClients.rowHeight = 24
    tblClients.setContentHuggingPriority(.defaultHigh, for: .vertical)
    tblClients.registerForDraggedTypes([.kUTTypeFileURL])
    tblClients.dataSource = self
    tblClients.action = #selector(onItemClicked(_:))
    tblClients.target = self
    if #available(macOS 11.0, *) { tblClients.style = .inset }

    tableColumn1.identifier = NSUserInterfaceItemIdentifier("colPCBEnabled")
    tableColumn1.maxWidth = 20
    tableColumn1.minWidth = 20
    tableColumn1.resizingMask = [.autoresizingMask, .userResizingMask]
    tableColumn1.width = 20
    tableColumn1.dataCell = tableColumn1Cell

    if #available(macOS 11.0, *) { tableColumn1Cell.controlSize = .large }
    tableColumn1Cell.font = NSFont.systemFont(ofSize: 13)
    tableColumn1Cell.setButtonType(.switch)
    tableColumn1Cell.bezelStyle = .rounded

    tableColumn2.identifier = NSUserInterfaceItemIdentifier("colClient")
    tableColumn2.maxWidth = 1000
    tableColumn2.minWidth = 40
    tableColumn2.resizingMask = [.autoresizingMask, .userResizingMask]
    tableColumn2.width = 546
    tableColumn2.dataCell = tableColumn2Cell

    tableColumn2Cell.backgroundColor = NSColor.controlBackgroundColor
    tableColumn2Cell.font = NSFont.systemFont(ofSize: 20)
    tableColumn2Cell.isEditable = true
    tableColumn2Cell.isSelectable = true
    tableColumn2Cell.lineBreakMode = .byTruncatingTail
    tableColumn2Cell.stringValue = "Text Cell"
    tableColumn2Cell.textColor = NSColor.controlTextColor
    tableColumn2Cell.isEditable = true

    return scrollContainer
  }
}

// MARK: - UserDefaults Handlers.

extension VwrClientListMgr {
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

extension VwrClientListMgr {
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

extension VwrClientListMgr {
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
    guard let window = CtlClientListMgr.shared?.window else { return }
    let alert = NSAlert()
    alert.messageText = NSLocalizedString(
      "Please enter the client app bundle identifier(s) you want to register.", comment: ""
    )
    alert.informativeText = NSLocalizedString(
      "One record per line. Use Option+Enter to break lines.\nBlank lines will be dismissed.",
      comment: ""
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("Just Select", comment: "") + "…")
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

    let maxFloat = Double(Float.greatestFiniteMagnitude)
    let scrollview = NSScrollView(frame: NSRect(x: 0, y: 0, width: 370, height: 200))
    let contentSize = scrollview.contentSize
    scrollview.borderType = .noBorder
    scrollview.hasVerticalScroller = true
    scrollview.hasHorizontalScroller = true
    scrollview.horizontalScroller?.scrollerStyle = .legacy
    scrollview.verticalScroller?.scrollerStyle = .legacy
    scrollview.autoresizingMask = [.width, .height]
    let theTextView = NSTextView(frame: NSRect(
      x: 0,
      y: 0,
      width: contentSize.width,
      height: contentSize.height
    ))
    scrollview.documentView = theTextView
    theTextView.minSize = NSSize(width: 0.0, height: contentSize.height)
    theTextView.maxSize = NSSize(width: maxFloat, height: maxFloat)
    theTextView.isVerticallyResizable = true
    theTextView.isHorizontallyResizable = false
    theTextView.autoresizingMask = .width
    theTextView.textContainer?.containerSize = NSSize(width: contentSize.width, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = true
    theTextView.enclosingScrollView?.hasHorizontalScroller = true
    theTextView.isHorizontallyResizable = true
    theTextView.autoresizingMask = [.width, .height]
    theTextView.textContainer?.containerSize = NSSize(width: maxFloat, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = false

    // 預先填寫近期用過威注音輸入法的客體軟體，最多二十筆。
    theTextView.textContainer?.textView?.string = {
      let recentClients = InputSession.recentClientBundleIdentifiers.keys.compactMap {
        PrefMgr.shared.clientsIMKTextInputIncapable.keys.contains($0) ? nil : $0
      }
      return recentClients.sorted().joined(separator: "\n")
    }()

    alert.accessoryView = scrollview
    alert.beginSheetModal(at: window) { result in
      resultCheck: switch result {
      case .alertFirstButtonReturn, .alertSecondButtonReturn:
        theTextView.textContainer?.textView?.string.components(separatedBy: "\n")
          .filter { !$0.isEmpty }.forEach {
            self.applyNewValue($0, highMitigation: result == .alertFirstButtonReturn)
          }
        if result == .alertFirstButtonReturn { break }
        if #unavailable(macOS 10.13) {
          window
            .callAlert(
              title: "Please drag the apps into the Client Manager window from Finder."
                .localized
            )
          break resultCheck
        }
        let dlgOpenPath = NSOpenPanel()
        dlgOpenPath.title = NSLocalizedString(
          "Choose the target application bundle.", comment: ""
        )
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
        dlgOpenPath.beginSheetModal(at: window) { result in
          switch result {
          case .OK:
            for url in dlgOpenPath.urls {
              let title = NSLocalizedString(
                "The selected item is either not a valid macOS application bundle or not having a valid app bundle identifier.",
                comment: ""
              )
              let text = url.path + "\n\n" + NSLocalizedString("Please try again.", comment: "")
              guard let bundle = Bundle(url: url) else {
                CtlClientListMgr.shared?.window.callAlert(title: title, text: text)
                return
              }
              guard let identifier = bundle.bundleIdentifier else {
                CtlClientListMgr.shared?.window.callAlert(title: title, text: text)
                return
              }
              let isIdentifierAlreadyRegistered = Self.clientsList.contains(identifier)
              let alert2 = NSAlert()
              alert2.messageText =
                "Do you want to enable the popup composition buffer for this client?".localized
              alert2.informativeText = "\(identifier)\n\n"
                +
                "Some client apps may have different compatibility issues in IMKTextInput implementation."
                .localized
              alert2.addButton(withTitle: "Yes".localized)
              alert2.addButton(withTitle: "No".localized)
              alert2.beginSheetModal(for: window) { result2 in
                let oldValue = PrefMgr.shared.clientsIMKTextInputIncapable[identifier]
                let newValue = result2 == .alertFirstButtonReturn
                if !(isIdentifierAlreadyRegistered && oldValue == newValue) {
                  self.applyNewValue(identifier, highMitigation: newValue)
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

// MARK: NSTableViewDelegate, NSTableViewDataSource

extension VwrClientListMgr: NSTableViewDelegate, NSTableViewDataSource {
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
#Preview(traits: .fixedLayout(width: 770, height: 335)) {
  VwrClientListMgr()
}
