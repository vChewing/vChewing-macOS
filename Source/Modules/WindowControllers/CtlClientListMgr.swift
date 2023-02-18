// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

class CtlClientListMgr: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
  @IBOutlet var tblClients: NSTableView!
  @IBOutlet var btnRemoveClient: NSButton!
  @IBOutlet var btnAddClient: NSButton!
  @IBOutlet var lblClientMgrWindow: NSTextField!

  public static var shared: CtlClientListMgr?

  static func show() {
    if shared == nil { shared = CtlClientListMgr(windowNibName: "frmClientListMgr") }
    guard let shared = shared, let sharedWindow = shared.window else { return }
    sharedWindow.setPosition(vertical: .center, horizontal: .right, padding: 20)
    sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    sharedWindow.titlebarAppearsTransparent = true
    shared.showWindow(shared)
    NSApp.activate(ignoringOtherApps: true)
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .center, horizontal: .right, padding: 20)
    localize()
    tblClients.delegate = self
    tblClients.allowsMultipleSelection = true
    tblClients.dataSource = self
    tblClients.action = #selector(onItemClicked(_:))
    tblClients.target = self
    tblClients.reloadData()
  }
}

// MARK: - UserDefaults Handlers

extension CtlClientListMgr {
  public static var clientsList: [String] { PrefMgr.shared.clientsIMKTextInputIncapable.keys.sorted() }
  public static func removeClient(at index: Int) {
    guard index < Self.clientsList.count else { return }
    let key = Self.clientsList[index]
    var dict = PrefMgr.shared.clientsIMKTextInputIncapable
    dict[key] = nil
    PrefMgr.shared.clientsIMKTextInputIncapable = dict
  }
}

// MARK: - Implementations

extension CtlClientListMgr {
  func numberOfRows(in _: NSTableView) -> Int {
    Self.clientsList.count
  }

  @IBAction func btnAddClientClicked(_: Any) {
    guard let window = window else { return }
    let alert = NSAlert()
    alert.messageText = NSLocalizedString(
      "Please enter the client app bundle identifier(s) you want to register.", comment: ""
    )
    alert.informativeText = NSLocalizedString(
      "One record per line. Use Option+Enter to break lines.\nBlank lines will be dismissed.", comment: ""
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
    let theTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
    theTextView.minSize = NSSize(width: 0.0, height: contentSize.height)
    theTextView.maxSize = NSSize(width: maxFloat, height: maxFloat)
    theTextView.isVerticallyResizable = true
    theTextView.isHorizontallyResizable = false
    theTextView.autoresizingMask = .width
    theTextView.textContainer?.containerSize = NSSize(width: contentSize.width, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = true
    scrollview.documentView = theTextView
    theTextView.enclosingScrollView?.hasHorizontalScroller = true
    theTextView.isHorizontallyResizable = true
    theTextView.autoresizingMask = [.width, .height]
    theTextView.textContainer?.containerSize = NSSize(width: maxFloat, height: maxFloat)
    theTextView.textContainer?.widthTracksTextView = false

    // 預先填寫近期用過威注音輸入法的客體軟體，最多二十筆。
    theTextView.textContainer?.textView?.string = {
      let recentClients = SessionCtl.recentClientBundleIdentifiers.keys.compactMap {
        PrefMgr.shared.clientsIMKTextInputIncapable.keys.contains($0) ? nil : $0
      }
      return recentClients.sorted().joined(separator: "\n")
    }()

    alert.accessoryView = scrollview
    alert.beginSheetModal(for: window) { result in
      switch result {
      case .alertFirstButtonReturn, .alertSecondButtonReturn:
        theTextView.textContainer?.textView?.string.components(separatedBy: "\n").filter { !$0.isEmpty }.forEach {
          self.applyNewValue($0, highMitigation: result == .alertFirstButtonReturn)
        }
        if result == .alertFirstButtonReturn { break }
        let dlgOpenPath = NSOpenPanel()
        dlgOpenPath.title = NSLocalizedString(
          "Choose the target application bundle.", comment: ""
        )
        dlgOpenPath.showsResizeIndicator = true
        dlgOpenPath.allowsMultipleSelection = true
        dlgOpenPath.allowedFileTypes = ["app"]
        dlgOpenPath.allowsOtherFileTypes = false
        dlgOpenPath.showsHiddenFiles = true
        dlgOpenPath.canChooseFiles = true
        dlgOpenPath.canChooseDirectories = false
        dlgOpenPath.beginSheetModal(for: window) { result in
          switch result {
          case .OK:
            for url in dlgOpenPath.urls {
              let title = NSLocalizedString(
                "The selected item is either not a valid macOS application bundle or not having a valid app bundle identifier.",
                comment: ""
              )
              let text = url.path + "\n\n" + NSLocalizedString("Please try again.", comment: "")
              guard let bundle = Bundle(url: url) else {
                self.window?.callAlert(title: title, text: text)
                return
              }
              guard let identifier = bundle.bundleIdentifier else {
                self.window?.callAlert(title: title, text: text)
                return
              }
              let isIdentifierAlreadyRegistered = Self.clientsList.contains(identifier)
              let alert2 = NSAlert()
              alert2.messageText =
                "Do you want to enable the popup composition buffer for this client?".localized
              alert2.informativeText = "\(identifier)\n\n"
                + "Some client apps may have different compatibility issues in IMKTextInput implementation.".localized
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

  private func applyNewValue(_ newValue: String, highMitigation mitigation: Bool = true) {
    guard !newValue.isEmpty else { return }
    var dict = PrefMgr.shared.clientsIMKTextInputIncapable
    dict[newValue] = mitigation
    PrefMgr.shared.clientsIMKTextInputIncapable = dict
    tblClients.reloadData()
    btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(
      tblClients.selectedRow)
  }

  @IBAction func btnRemoveClientClicked(_: Any) {
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
      tblClients.selectRowIndexes(.init(arrayLiteral: minIndexSelected - 1), byExtendingSelection: false)
    }
    tblClients.reloadData()
    btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(minIndexSelected)
  }

  @objc func onItemClicked(_: Any!) {
    guard tblClients.clickedColumn == 0 else { return }
    PrefMgr.shared.clientsIMKTextInputIncapable[Self.clientsList[tblClients.clickedRow]]?.toggle()
    tblClients.reloadData()
  }

  func tableView(_: NSTableView, shouldEdit _: NSTableColumn?, row _: Int) -> Bool {
    false
  }

  func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    defer {
      self.btnRemoveClient.isEnabled = (0 ..< Self.clientsList.count).contains(
        self.tblClients.selectedRow)
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

  private func localize() {
    guard let window = window else { return }
    window.title = NSLocalizedString("Client Manager", comment: "")
    lblClientMgrWindow.stringValue = NSLocalizedString(
      "Please manage the list of those clients here which are: 1) IMKTextInput-incompatible; 2) suspected from abusing the contents of the inline composition buffer. A client listed here, if checked, will use popup composition buffer with maximum 20 reading counts holdable.",
      comment: ""
    )
    btnAddClient.title = NSLocalizedString("Add Client", comment: "")
    btnRemoveClient.title = NSLocalizedString("Remove Selected", comment: "")
  }
}
