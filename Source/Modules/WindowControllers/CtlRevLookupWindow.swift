// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import LangModelAssembly

class CtlRevLookupWindow: NSWindowController, NSWindowDelegate {
  static var shared: CtlRevLookupWindow?

  static func show() {
    if shared == nil { Self.shared = .init(window: FrmRevLookupWindow()) }
    guard let shared = Self.shared, let window = shared.window as? FrmRevLookupWindow else { return }
    shared.window = window
    window.delegate = shared
    window.setPosition(vertical: .bottom, horizontal: .right, padding: 20)
    window.orderFrontRegardless()  // 逼著視窗往最前方顯示
    window.level = .statusBar
    window.titlebarAppearsTransparent = true
    shared.showWindow(shared)
    NSApp.activate(ignoringOtherApps: true)
  }
}

class FrmRevLookupWindow: NSWindow {
  typealias LMRevLookup = vChewingLM.LMRevLookup

  static let lmRevLookupCore = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup"))

  // 全字庫資料接近十萬筆索引，只放到單個 Dictionary 內的話、每次查詢時都會把輸入法搞崩潰。只能分卷處理。
  static let lmRevLookupCNS1 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS1"))
  static let lmRevLookupCNS2 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS2"))
  static let lmRevLookupCNS3 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS3"))
  static let lmRevLookupCNS4 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS4"))
  static let lmRevLookupCNS5 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS5"))
  static let lmRevLookupCNS6 = LMRevLookup(path: LMMgr.getBundleDataPath("data-bpmf-reverse-lookup-CNS6"))

  public lazy var inputField = NSTextField()
  public lazy var resultView = NSTextView()
  private lazy var clipView = NSClipView()
  private lazy var scrollView = NSScrollView()
  private lazy var button = NSButton()
  private lazy var view = NSView()

  init() {
    super.init(
      contentRect: CGRect(x: 196, y: 240, width: 480, height: 340),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: true
    )
    setupUI()
    setupLayout()
  }

  private func setupUI() {
    contentView = view

    allowsToolTipsWhenApplicationIsInactive = false
    autorecalculatesKeyViewLoop = false
    isReleasedWhenClosed = false
    title = "Reverse Lookup (Phonabets)".localized

    view.addSubview(inputField)
    view.addSubview(scrollView)
    view.addSubview(button)

    view.wantsLayer = true

    button.setContentHuggingPriority(.defaultHigh, for: .vertical)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.alignment = .center
    button.bezelStyle = .recessed
    button.font = NSFont.systemFont(ofSize: 12, weight: .bold)
    button.imageScaling = .scaleProportionallyDown
    button.title = "👓"
    button.cell.map { $0 as? NSButtonCell }??.isBordered = true
    button.target = self
    button.action = #selector(keyboardConfirmed(_:))
    button.keyEquivalent = String(utf16CodeUnits: [unichar(NSEvent.SpecialKey.enter.rawValue)], count: 1) as String

    scrollView.borderType = .noBorder
    scrollView.hasHorizontalScroller = false
    scrollView.horizontalLineScroll = 10
    scrollView.horizontalPageScroll = 10
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.verticalLineScroll = 10
    scrollView.verticalPageScroll = 10

    clipView.documentView = resultView

    clipView.autoresizingMask = [.width, .height]
    clipView.drawsBackground = false
    clipView.frame = CGRect(x: 0, y: 0, width: 480, height: 320)

    resultView.autoresizingMask = [.width, .height]
    resultView.backgroundColor = NSColor.textBackgroundColor
    resultView.frame = CGRect(x: 0, y: 0, width: 480, height: 320)
    resultView.importsGraphics = false
    resultView.insertionPointColor = NSColor.textColor
    resultView.isEditable = false
    resultView.isRichText = false
    resultView.isVerticallyResizable = true
    resultView.maxSize = CGSize(width: 774, height: 10_000_000)
    resultView.minSize = CGSize(width: 480, height: 320)
    resultView.smartInsertDeleteEnabled = true
    resultView.textColor = NSColor.textColor
    resultView.wantsLayer = true
    resultView.font = NSFont.systemFont(ofSize: 13)
    resultView.string = "Maximum 15 results returnable.".localized

    scrollView.contentView = clipView

    inputField.setContentHuggingPriority(.defaultHigh, for: .vertical)
    inputField.translatesAutoresizingMaskIntoConstraints = false
    inputField.backgroundColor = NSColor.textBackgroundColor
    inputField.drawsBackground = true
    inputField.font = NSFont.systemFont(ofSize: 13)
    inputField.isBezeled = true
    inputField.isEditable = true
    inputField.isSelectable = true
    inputField.lineBreakMode = .byClipping
    inputField.textColor = NSColor.controlTextColor
    inputField.cell.map { $0 as? NSTextFieldCell }??.isScrollable = true
    inputField.cell.map { $0 as? NSTextFieldCell }??.sendsActionOnEndEditing = true
    inputField.cell.map { $0 as? NSTextFieldCell }??.usesSingleLineMode = true
    inputField.action = #selector(keyboardConfirmed(_:))
    inputField.toolTip =
      "Maximum 15 results returnable.".localized
  }

  @objc func keyboardConfirmed(_: Any?) {
    if inputField.stringValue.isEmpty { return }
    resultView.string = "\n" + "Loading…".localized
    DispatchQueue.main.async { [self] in
      self.updateResult(with: self.inputField.stringValue)
    }
  }

  private func updateResult(with input: String) {
    guard !input.isEmpty else { return }
    button.isEnabled = false
    inputField.isEnabled = false
    let strBuilder = NSMutableString()
    strBuilder.append("\n")
    strBuilder.append("Char\tReading(s)\n".localized)
    strBuilder.append("==\t====\n")
    var i = 0
    theLoop: for char in input.charComponents {
      if i == 15 {
        strBuilder.append("Maximum 15 results returnable.".localized + "\n")
        break theLoop
      }
      var arrResult = Self.lmRevLookupCore.query(with: char) ?? []
      // 一般情況下，威注音語彙庫的倉庫內的全字庫資料檔案有做過排序，所以每個分卷的索引都是不重複的。
      arrResult +=
        Self.lmRevLookupCNS1.query(with: char)
        ?? Self.lmRevLookupCNS2.query(with: char)
        ?? Self.lmRevLookupCNS3.query(with: char)
        ?? Self.lmRevLookupCNS4.query(with: char)
        ?? Self.lmRevLookupCNS5.query(with: char)
        ?? Self.lmRevLookupCNS6.query(with: char)
        ?? []
      arrResult = arrResult.deduplicated
      if !arrResult.isEmpty {
        strBuilder.append(char + "\t")
        strBuilder.append(arrResult.joined(separator: ", "))
        strBuilder.append("\n")
        i += 1
      }
    }
    resultView.string = strBuilder.description
    button.isEnabled = true
    inputField.isEnabled = true
  }

  private func setupLayout() {
    inputField.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
    button.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 5).isActive = true
    scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
    inputField.lastBaselineAnchor.constraint(equalTo: button.lastBaselineAnchor).isActive = true
    scrollView.topAnchor.constraint(equalTo: button.bottomAnchor).isActive = true
    view.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 3).isActive = true
    inputField.topAnchor.constraint(equalTo: button.topAnchor).isActive = true
    view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
    view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
    inputField.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    inputField.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
  }
}
