// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import OSFrameworkImpl
import Shared

// MARK: - VwrServiceMenuEditor

public class VwrServiceMenuEditor: NSViewController {
  // MARK: Lifecycle

  public convenience init(windowController: NSWindowController? = nil) {
    self.init()
    self.windowController = windowController
  }

  // MARK: Public

  override public func loadView() {
    tblServices.reloadData()
    view = body ?? .init()
    (view as? NSStackView)?.alignment = .centerX
    view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    btnRemoveService.keyEquivalent = .init(NSEvent.SpecialKey.delete.unicodeScalar)
  }

  // MARK: Internal

  let windowWidth: CGFloat = 770
  let contentWidth: CGFloat = 750
  let tableHeight: CGFloat = 230

  lazy var tblServices: NSTableView = .init()
  lazy var btnShowInstructions = NSButton(
    "How to Fill",
    target: self,
    action: #selector(btnShowInstructionsClicked(_:))
  )
  lazy var btnAddService = NSFileDragRetrieverButton(
    "Add Service",
    target: self,
    action: #selector(btnAddServiceClicked(_:)),
    postDrag: handleDrag
  )
  lazy var btnRemoveService = NSButton(
    "Remove Selected",
    target: self,
    action: #selector(btnRemoveServiceClicked(_:))
  )
  lazy var btnResetService = NSButton(
    "Reset Default",
    target: self,
    action: #selector(btnResetServiceClicked(_:))
  )
  lazy var btnCopyAllToClipboard = NSButton(
    "Copy All to Clipboard",
    target: self,
    action: #selector(btnCopyAllToClipboardClicked(_:))
  )
  lazy var tableColumn1Cell = NSTextFieldCell()
  lazy var tableColumn1 = NSTableColumn()
  lazy var tableColumn2Cell = NSTextFieldCell()
  lazy var tableColumn2 = NSTableColumn()

  var windowController: NSWindowController?

  var body: NSView? {
    NSStackView.build(.vertical, insets: .new(all: 14)) {
      NSStackView.build(.horizontal) {
        btnAddService
        btnRemoveService
        btnCopyAllToClipboard
        btnShowInstructions
        NSView()
        btnResetService
      }
      makeScrollableTable()
        .makeSimpleConstraint(.height, relation: .equal, value: tableHeight)
      NSStackView.build(.horizontal) {
        let descriptionWidth = contentWidth - 10
        NSStackView.build(.vertical) {
          let strDescription = "i18n:CandidateServiceMenuEditor.description"
          strDescription.makeNSLabel(descriptive: true, fixWidth: descriptionWidth)
            .makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: descriptionWidth)
          NSView()
        }
      }
    }
  }

  func makeScrollableTable() -> NSScrollView {
    let scrollContainer = NSScrollView()
    scrollContainer.scrollerStyle = .legacy
    scrollContainer.autohidesScrollers = true
    scrollContainer.documentView = tblServices
    scrollContainer.hasVerticalScroller = true
    scrollContainer.hasHorizontalScroller = true

    if #available(macOS 26, *) {
      scrollContainer.borderType = .lineBorder
    }

    if #available(macOS 11.0, *) {
      tblServices.style = .inset
    }
    tblServices.addTableColumn(tableColumn1)
    tblServices.addTableColumn(tableColumn2)
    // tblServices.headerView = nil
    tblServices.delegate = self
    tblServices.allowsExpansionToolTips = true
    tblServices.allowsMultipleSelection = true
    tblServices.autoresizingMask = [.width, .height]
    tblServices.autosaveTableColumns = false
    tblServices.backgroundColor = NSColor.controlBackgroundColor
    tblServices.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    tblServices.frame = CGRect(x: 0, y: 0, width: 728, height: tableHeight)
    tblServices.gridColor = NSColor.clear
    tblServices.intercellSpacing = CGSize(width: 15, height: 0)
    tblServices.setContentHuggingPriority(.defaultHigh, for: .vertical)
    tblServices.registerForDraggedTypes([.kUTTypeData, .kUTTypeFileURL])
    tblServices.dataSource = self
    tblServices.target = self
    if #available(macOS 11.0, *) { tblServices.style = .inset }

    tableColumn1.identifier = NSUserInterfaceItemIdentifier("colTitle")
    tableColumn1.headerCell.title = "i18n:CandidateServiceMenuEditor.table.field.MenuTitle"
      .localized
    tableColumn1.maxWidth = 280
    tableColumn1.minWidth = 200
    tableColumn1.resizingMask = [.autoresizingMask, .userResizingMask]
    tableColumn1.width = 200
    tableColumn1.dataCell = tableColumn1Cell

    tableColumn1Cell.font = NSFont.systemFont(ofSize: 13)
    tableColumn1Cell.isEditable = true
    tableColumn1Cell.isSelectable = true
    tableColumn1Cell.lineBreakMode = .byTruncatingTail
    tableColumn1Cell.stringValue = "Text Cell"
    tableColumn1Cell.textColor = NSColor.controlTextColor

    tableColumn2.identifier = NSUserInterfaceItemIdentifier("colValue")
    tableColumn2.headerCell.title = "i18n:CandidateServiceMenuEditor.table.field.Value".localized
    tableColumn2.maxWidth = 1_000
    tableColumn2.minWidth = 40
    tableColumn2.resizingMask = [.autoresizingMask, .userResizingMask]
    tableColumn2.width = 480
    tableColumn2.dataCell = tableColumn2Cell

    tableColumn2Cell.backgroundColor = NSColor.controlBackgroundColor
    tableColumn2Cell.font = NSFont.systemFont(ofSize: 13)
    tableColumn2Cell.isEditable = true
    tableColumn2Cell.isSelectable = true
    tableColumn2Cell.lineBreakMode = .byTruncatingTail
    tableColumn2Cell.stringValue = "Text Cell"
    tableColumn2Cell.textColor = NSColor.controlTextColor

    return scrollContainer
  }
}

// MARK: - UserDefaults Handlers.

extension VwrServiceMenuEditor {
  public static var servicesList: [CandidateTextService] {
    get {
      PrefMgr.shared.candidateServiceMenuContents.parseIntoCandidateTextServiceStack()
    }
    set {
      PrefMgr.shared.candidateServiceMenuContents = newValue.rawRepresentation
    }
  }

  public static func removeService(at index: Int) {
    guard index < Self.servicesList.count else { return }
    Self.servicesList.remove(at: index)
  }
}

// MARK: - Common Operation Methods.

extension VwrServiceMenuEditor {
  func refresh() {
    tblServices.reloadData()
    reassureButtonAvailability()
  }

  func reassureButtonAvailability() {
    btnRemoveService.isEnabled = (0 ..< Self.servicesList.count).contains(
      tblServices.selectedRow
    )
  }

  func handleDrag(_ givenURL: URL) {
    guard let string = try? String(contentsOf: givenURL) else { return }
    Self.servicesList
      .append(
        contentsOf: string.components(separatedBy: .newlines)
          .parseIntoCandidateTextServiceStack()
      )
    refresh()
  }
}

// MARK: - IBActions.

extension VwrServiceMenuEditor {
  @IBAction
  func btnShowInstructionsClicked(_: Any) {
    let strTitle = "How to Fill".localized
    let strFillGuide = "i18n:CandidateServiceMenuEditor.formatGuide".localized
    windowController?.window.callAlert(title: strTitle, text: strFillGuide)
  }

  @IBAction
  func btnResetServiceClicked(_: Any) {
    PrefMgr.shared.candidateServiceMenuContents = PrefMgr.kDefaultCandidateServiceMenuItem
    tblServices.reloadData()
  }

  @IBAction
  func btnCopyAllToClipboardClicked(_: Any) {
    var resultArrayLines = [String]()
    Self.servicesList.forEach { currentService in
      resultArrayLines.append("\(currentService.key)\t\(currentService.definedValue)")
    }
    let result = resultArrayLines.joined(separator: "\n").appending("\n")
    NSPasteboard.general.declareTypes([.string], owner: nil)
    NSPasteboard.general.setString(result, forType: .string)
  }

  @IBAction
  func btnRemoveServiceClicked(_: Any) {
    guard let minIndexSelected = tblServices.selectedRowIndexes.min() else { return }
    if minIndexSelected >= Self.servicesList.count { return }
    if minIndexSelected < 0 { return }
    var isLastRow = false
    tblServices.selectedRowIndexes.sorted().reversed().forEach { index in
      isLastRow = {
        if Self.servicesList.count < 2 { return false }
        return minIndexSelected == Self.servicesList.count - 1
      }()
      if index < Self.servicesList.count {
        Self.removeService(at: index)
      }
    }
    if isLastRow {
      tblServices.selectRowIndexes(
        .init(arrayLiteral: minIndexSelected - 1),
        byExtendingSelection: false
      )
    }
    tblServices.reloadData()
    btnRemoveService.isEnabled = (0 ..< Self.servicesList.count).contains(minIndexSelected)
  }

  @IBAction
  func btnAddServiceClicked(_: Any) {
    guard let window = windowController?.window else { return }
    let alert = NSAlert()
    alert.messageText = NSLocalizedString(
      "i18n:CandidateServiceMenuEditor.prompt", comment: ""
    )
    alert.informativeText = NSLocalizedString(
      "i18n:CandidateServiceMenuEditor.howToGetGuide", comment: ""
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

    let maxFloat = Double(Float.greatestFiniteMagnitude)
    let scrollview = NSScrollView(frame: CGRect(x: 0, y: 0, width: 512, height: 200))
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
    theTextView.toolTip = "i18n:CandidateServiceMenuEditor.formatGuide".localized

    alert.accessoryView = scrollview
    alert.beginSheetModal(at: window) { result in
      switch result {
      case .alertFirstButtonReturn:
        let rawLines = theTextView.textContainer?.textView?.string
          .components(separatedBy: .newlines) ?? []
        self.tblServices.beginUpdates()
        Self.servicesList.append(contentsOf: rawLines.parseIntoCandidateTextServiceStack())
        self.tblServices.endUpdates()
      default: return
      }
    }
  }
}

// MARK: NSTableViewDelegate, NSTableViewDataSource

extension VwrServiceMenuEditor: NSTableViewDelegate, NSTableViewDataSource {
  public func numberOfRows(in _: NSTableView) -> Int {
    Self.servicesList.count
  }

  public func tableView(_: NSTableView, shouldEdit _: NSTableColumn?, row _: Int) -> Bool {
    false
  }

  public func tableView(_: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
    defer {
      self.btnRemoveService.isEnabled = (0 ..< Self.servicesList.count).contains(
        self.tblServices.selectedRow
      )
    }
    guard row < Self.servicesList.count else { return "" }
    if let column = column {
      let colName = column.identifier.rawValue
      switch colName {
      case "colTitle": return Self.servicesList[row].key
      case "colValue": return Self.servicesList[row].definedValue // TODO: 回頭這裡可能需要自訂。
      default: return ""
      }
    }
    return Self.servicesList[row]
  }

  // MARK: Pasteboard Operations.

  public func tableView(
    _: NSTableView, pasteboardWriterForRow row: Int
  )
    -> NSPasteboardWriting? {
    let pasteboard = NSPasteboardItem()
    pasteboard.setString(row.description, forType: .string)
    return pasteboard
  }

  public func tableView(
    _: NSTableView,
    validateDrop _: NSDraggingInfo,
    proposedRow _: Int,
    proposedDropOperation _: NSTableView.DropOperation
  )
    -> NSDragOperation {
    .move
  }

  public func tableView(
    _ tableView: NSTableView,
    acceptDrop info: NSDraggingInfo,
    row: Int,
    dropOperation _: NSTableView.DropOperation
  )
    -> Bool {
    var oldIndexes = [Int]()
    info.enumerateDraggingItems(
      options: [],
      for: tableView,
      classes: [NSPasteboardItem.self],
      searchOptions: [:]
    ) { dragItem, _, _ in
      guard let pasteboardItem = dragItem.item as? NSPasteboardItem else { return }
      guard let index = Int(pasteboardItem.string(forType: .string) ?? "NULL"),
            index >= 0 else { return }
      oldIndexes.append(index)
    }

    var oldIndexOffset = 0
    var newIndexOffset = 0

    tableView.beginUpdates()
    for oldIndex in oldIndexes {
      if oldIndex < row {
        let contentToMove = Self.servicesList[oldIndex + oldIndexOffset]
        Self.servicesList.remove(at: oldIndex + oldIndexOffset)
        Self.servicesList.insert(contentToMove, at: row - 1)
        tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
        oldIndexOffset -= 1
      } else {
        let contentToMove = Self.servicesList[oldIndex]
        Self.servicesList.remove(at: oldIndex)
        Self.servicesList.insert(contentToMove, at: row + newIndexOffset)
        tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
        newIndexOffset += 1
      }
    }
    tableView.endUpdates()
    reassureButtonAvailability()

    return true
  }
}

// MARK: - Preview.

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 770, height: 335)) {
  VwrServiceMenuEditor()
}
