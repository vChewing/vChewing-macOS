// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - CtlRevLookupWindow

final class CtlRevLookupWindow: NSWindowController, NSWindowDelegate {
  static var shared: CtlRevLookupWindow?

  /// 關閉反查視窗時釋放反查索引，把約 10 MB 記憶體還給系統。
  /// 所有載入/卸除操作均經由 UI 行為在 MainActor 上完成，無需額外同步佇列。
  override func close() {
    autoreleasepool {
      LXMgr.flushFactoryReverseLookupIndex()
      super.close()
      Self.shared = nil
    }
  }

  /// 顯示反查視窗；載入時即預先建立反查索引，避免首次查詢時的 lazy build 延遲。
  /// 所有載入/卸除操作均經由 UI 行為在 MainActor 上完成，無需額外同步佇列。
  static func show() {
    autoreleasepool {
      if shared == nil { Self.shared = .init(window: FrmRevLookupWindow()) }
      guard let shared = Self.shared,
            let window = shared.window as? FrmRevLookupWindow else { return }
      shared.window = window
      window.delegate = shared
      window.setPosition(vertical: .bottom, horizontal: .right, padding: 20)
      window.orderFrontRegardless() // 逼著視窗往最前方顯示
      window.level = .statusBar
      LXMgr.preloadFactoryReverseLookupIndex()
      shared.showWindow(shared)
      NSApp.popup()
    }
  }
}

// MARK: - FrmRevLookupWindow

final class FrmRevLookupWindow: NSWindow {
  // MARK: Lifecycle

  init() {
    super.init(
      contentRect: CGRect(x: 196, y: 240, width: 480, height: 340),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: true
    )
    setupUI()
  }

  // MARK: Internal

  lazy var inputField = NSTextField()
  lazy var resultView = NSTextView()

  static func reloadData() {
    LXMgr.connectCoreDB()
  }

  @objc
  func keyboardConfirmed(_: Any?) {
    if inputField.stringValue.isEmpty { return }
    resultView.string = "\n" + "i18n:DictionaryStatus.Loading".i18n
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      this.updateResult(with: this.inputField.stringValue)
    }
  }

  // MARK: Private

  private lazy var clipView = NSClipView()
  private lazy var scrollView = NSScrollView()
  private lazy var button = NSButton()
  private lazy var view = NSView()

  private func setupUI() {
    contentView = view

    allowsToolTipsWhenApplicationIsInactive = false
    autorecalculatesKeyViewLoop = false
    isReleasedWhenClosed = false
    title = "i18n:UserDef.kUsingHotKeyRevLookup.shortTitle".i18n

    view.addSubview(inputField)
    view.addSubview(scrollView)
    view.addSubview(button)

    view.wantsLayer = true

    button.autoresizingMask = [.maxXMargin, .minYMargin]
    button.frame = CGRect(x: 446, y: 319, width: 31, height: 21)
    button.setContentHuggingPriority(.defaultHigh, for: .vertical)
    button.alignment = .center
    button.bezelStyle = .recessed
    button.font = NSFont.systemFont(ofSize: 12)
    button.imageScaling = .scaleProportionallyDown
    button.title = "👓"
    button.cell.map { $0 as? NSButtonCell }??.isBordered = true
    button.target = self
    button.action = #selector(keyboardConfirmed(_:))
    button.keyEquivalent = String(
      utf16CodeUnits: [unichar(NSEvent.SpecialKey.enter.rawValue)],
      count: 1
    ) as String

    scrollView.autoresizingMask = [.maxXMargin, .minYMargin]
    scrollView.borderType = .noBorder
    scrollView.frame = CGRect(x: 0, y: 0, width: 480, height: 320)
    scrollView.hasHorizontalScroller = false
    scrollView.horizontalLineScroll = 10
    scrollView.horizontalPageScroll = 10
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
    resultView.string = "i18n:ErrorMessage.MaxResultsReturnable".i18n

    scrollView.contentView = clipView

    inputField.autoresizingMask = [.maxXMargin, .minYMargin]
    inputField.frame = CGRect(x: 0, y: 320, width: 441, height: 20)
    inputField.setContentHuggingPriority(.defaultHigh, for: .vertical)
    inputField.backgroundColor = NSColor.textBackgroundColor
    inputField.drawsBackground = true
    inputField.font = NSFont.systemFont(ofSize: 13)
    inputField.isBezeled = true
    inputField.isEditable = true
    inputField.isSelectable = true
    inputField.cell?.lineBreakMode = .byClipping
    inputField.textColor = NSColor.controlTextColor
    inputField.cell.map { $0 as? NSTextFieldCell }??.isScrollable = true
    inputField.cell.map { $0 as? NSTextFieldCell }??.sendsActionOnEndEditing = true
    inputField.cell.map { $0 as? NSTextFieldCell }??.usesSingleLineMode = true
    inputField.action = #selector(keyboardConfirmed(_:))
    inputField.toolTip =
      "i18n:ErrorMessage.MaxResultsReturnable".i18n
  }

  private func updateResult(with input: String) {
    guard !input.isEmpty else { return }
    button.isEnabled = false
    inputField.isEnabled = false
    var strBuilder = ContiguousArray<String>()
    strBuilder.append("\n")
    strBuilder.append("i18n:PhraseEditor.CharReadingHeader".i18n)
    strBuilder.append("==\t====\n")
    var i = 0
    theLoop: for char in input.map(\.description) {
      if i == 15 {
        strBuilder.append("i18n:ErrorMessage.MaxResultsReturnable".i18n + "\n")
        break theLoop
      }
      let arrResult = LXAssembly.LXFacade.getFactoryReverseLookupData(with: char)?
        .deduplicated ?? []
      if !arrResult.isEmpty {
        strBuilder.append(char + "\t")
        strBuilder.append(arrResult.joined(separator: ", "))
        strBuilder.append("\n")
        i += 1
      }
    }
    resultView.string = strBuilder.joined()
    button.isEnabled = true
    inputField.isEnabled = true
  }
}
