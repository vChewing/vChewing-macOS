// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class ctlPopupCompositionBuffer: NSWindowController {
  private var messageTextField: NSTextField
  private var textShown: NSAttributedString = .init(string: "") {
    didSet {
      messageTextField.attributedStringValue = textShown
      adjustSize()
    }
  }

  public init() {
    let transparentVisualEffect = NSVisualEffectView()
    transparentVisualEffect.blendingMode = .behindWindow
    transparentVisualEffect.state = .active
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.contentView = transparentVisualEffect
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 1)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.clear

    messageTextField = NSTextField()
    messageTextField.isEditable = false
    messageTextField.isSelectable = false
    messageTextField.isBezeled = false
    messageTextField.textColor = NSColor.textColor
    messageTextField.drawsBackground = true
    messageTextField.backgroundColor = NSColor.clear
    messageTextField.font = .systemFont(ofSize: 18)
    panel.contentView?.addSubview(messageTextField)
    super.init(window: panel)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func show(state: IMEStateProtocol, at point: NSPoint) {
    if !state.hasComposition {
      hide()
      return
    }
    // 在這個視窗內的下畫線繪製方法就得單獨設計了。
    let attrString: NSMutableAttributedString = .init(string: state.data.displayedTextConverted)
    attrString.setAttributes(
      [
        .backgroundColor: NSColor.alternateSelectedControlColor,
        .foregroundColor: NSColor.alternateSelectedControlTextColor,
        .markedClauseSegment: 0,
      ],
      range: NSRange(
        location: state.data.u16MarkedRange.lowerBound,
        length: state.data.u16MarkedRange.upperBound - state.data.u16MarkedRange.lowerBound
      )
    )
    let attrCursor = NSMutableAttributedString(string: "_")
    if #available(macOS 10.13, *) {
      attrCursor.setAttributes(
        [
          .kern: -18,
          .baselineOffset: -2,
          .markedClauseSegment: 1,
        ],
        range: NSRange(location: 0, length: attrCursor.string.utf16.count)
      )
    }
    attrString.insert(attrCursor, at: state.data.u16Cursor)
    textShown = attrString
    messageTextField.maximumNumberOfLines = 1
    if let editor = messageTextField.currentEditor() {
      editor.selectedRange = NSRange(state.data.u16MarkedRange)
    }
    window?.orderFront(nil)
    set(windowOrigin: point)
  }

  public func hide() {
    window?.orderOut(nil)
  }

  private func set(windowOrigin: NSPoint) {
    guard let window = window else { return }
    let windowSize = window.frame.size

    var adjustedPoint = windowOrigin
    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.seniorTheBeast
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ !$0.contains(windowOrigin) }) {
      screenFrame = frame
      break
    }

    adjustedPoint.y = min(max(adjustedPoint.y, screenFrame.minY + windowSize.height), screenFrame.maxY)
    adjustedPoint.x = min(max(adjustedPoint.x, screenFrame.minX), screenFrame.maxX - windowSize.width)

    window.setFrameOrigin(adjustedPoint)
  }

  private func adjustSize() {
    let attrString = messageTextField.attributedStringValue
    var rect = attrString.boundingRect(
      with: NSSize(width: 1600.0, height: 1600.0),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    rect.size.width = max(rect.size.width, 20 * CGFloat(attrString.string.count)) + 2
    rect.size.height = 22
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += NSFont.systemFontSize / 2
    rect.origin.y += NSFont.systemFontSize / 2
    messageTextField.frame = rect
    window?.setFrame(bigRect, display: true)
  }
}
