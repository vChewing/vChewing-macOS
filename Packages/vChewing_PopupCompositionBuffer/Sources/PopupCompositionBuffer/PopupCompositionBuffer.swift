// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Shared

public class PopupCompositionBuffer: NSWindowController {
  public var isTypingDirectionVertical = false {
    didSet {
      if #unavailable(macOS 10.14) {
        isTypingDirectionVertical = false
      }
    }
  }

  private var messageTextField: NSTextField
  private var textShown: NSAttributedString = .init(string: "") {
    didSet {
      messageTextField.attributedStringValue = textShown
      adjustSize()
    }
  }

  public init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 1)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.controlBackgroundColor
    panel.styleMask = .fullSizeContentView
    panel.isMovable = false
    messageTextField = NSTextField()
    messageTextField.isEditable = false
    messageTextField.isSelectable = false
    messageTextField.isBezeled = false
    messageTextField.textColor = NSColor.textColor
    messageTextField.drawsBackground = true
    messageTextField.backgroundColor = NSColor.clear
    messageTextField.font = .systemFont(ofSize: 18)
    panel.contentView?.addSubview(messageTextField)
    panel.contentView?.wantsLayer = true
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

    let attrString: NSMutableAttributedString = .init(string: state.displayedTextConverted)
    let verticalAttributes: [NSAttributedString.Key: Any] = [
      .verticalGlyphForm: true,
      .paragraphStyle: {
        let newStyle = NSMutableParagraphStyle()
        if #available(macOS 10.13, *) {
          let fontSize = messageTextField.font?.pointSize ?? 18
          newStyle.lineSpacing = fontSize / -3
          newStyle.maximumLineHeight = fontSize
          newStyle.minimumLineHeight = fontSize
        }
        return newStyle
      }(),
    ]

    if isTypingDirectionVertical {
      attrString.setAttributes(
        verticalAttributes, range: NSRange(location: 0, length: attrString.length)
      )
    }

    let markerAttributes: [NSAttributedString.Key: Any] = {
      var result: [NSAttributedString.Key: Any] = [
        .backgroundColor: NSApplication.isDarkMode ? NSColor.systemRed : NSColor.systemYellow,
        .markedClauseSegment: 0,
      ]
      if isTypingDirectionVertical {
        result[.paragraphStyle] = verticalAttributes[.paragraphStyle]
        result[.verticalGlyphForm] = true
      }
      return result
    }()

    // 在這個視窗內的下畫線繪製方法就得單獨設計了。
    attrString.setAttributes(
      markerAttributes,
      range: NSRange(
        location: state.u16MarkedRange.lowerBound,
        length: state.u16MarkedRange.upperBound - state.u16MarkedRange.lowerBound
      )
    )

    let cursorAttributes: [NSAttributedString.Key: Any] = {
      var result: [NSAttributedString.Key: Any] = [
        .kern: -18,
        .foregroundColor: NSColor.textColor,
      ]
      if isTypingDirectionVertical {
        result[.paragraphStyle] = verticalAttributes[.paragraphStyle]
        result[.verticalGlyphForm] = true
        result[.baselineOffset] = 3
      } else {
        result[.baselineOffset] = -2
      }
      if #unavailable(macOS 10.13) {
        result[.kern] = 0
        result[.baselineOffset] = 0
      }
      return result
    }()

    let attrCursor: NSAttributedString =
      isTypingDirectionVertical
      ? NSMutableAttributedString(string: "▔", attributes: cursorAttributes)
      : NSMutableAttributedString(string: "_", attributes: cursorAttributes)
    attrString.insert(attrCursor, at: state.u16Cursor)

    textShown = attrString
    messageTextField.maximumNumberOfLines = 1
    if let editor = messageTextField.currentEditor() {
      editor.selectedRange = NSRange(state.u16MarkedRange)
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
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ $0.contains(windowOrigin) }) {
      screenFrame = frame
      break
    }

    adjustedPoint.y = min(max(adjustedPoint.y, screenFrame.minY + windowSize.height), screenFrame.maxY)
    adjustedPoint.x = min(max(adjustedPoint.x, screenFrame.minX), screenFrame.maxX - windowSize.width)

    if isTypingDirectionVertical {
      window.setFrameTopLeftPoint(adjustedPoint)
    } else {
      window.setFrameOrigin(adjustedPoint)
    }
  }

  private func adjustSize() {
    let attrString = messageTextField.attributedStringValue
    var rect = attrString.boundingRect(
      with: NSSize(width: 1600.0, height: 1600.0),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    rect.size.width = max(rect.size.width, 20 * Double(attrString.string.count)) + 2
    rect.size.height *= 1.2
    rect.size.height = max(22, rect.size.height)
    if isTypingDirectionVertical {
      rect = .init(x: rect.minX, y: rect.minY, width: rect.height, height: rect.width)
    }
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += ceil(NSFont.systemFontSize / 2)
    rect.origin.y += ceil(NSFont.systemFontSize / 2)
    if isTypingDirectionVertical {
      messageTextField.boundsRotation = 90
    } else {
      messageTextField.boundsRotation = 0
    }
    messageTextField.frame = rect
    window?.setFrame(bigRect, display: true)
  }
}
