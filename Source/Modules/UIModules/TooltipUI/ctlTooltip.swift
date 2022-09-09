// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class ctlTooltip: NSWindowController {
  public enum ColorStates {
    case normal
    case redAlert
    case warning
    case denialOverflow
    case denialInsufficiency
    case prompt
  }

  private var messageText: NSAttributedTextView
  private var tooltip: String = "" {
    didSet {
      messageText.text = tooltip.isEmpty ? nil : tooltip
      adjustSize()
    }
  }

  public var direction: NSAttributedTextView.writingDirection = .horizontal {
    didSet {
      if #unavailable(macOS 10.13) { direction = .horizontal }
      messageText.direction = direction
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
    messageText = NSAttributedTextView()
    messageText.backgroundColor = NSColor.controlBackgroundColor
    messageText.textColor = NSColor.textColor
    panel.contentView?.addSubview(messageText)
    super.init(window: panel)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func show(
    tooltip: String = "", at point: NSPoint,
    bottomOutOfScreenAdjustmentHeight heightDelta: CGFloat,
    direction: NSAttributedTextView.writingDirection = .horizontal
  ) {
    self.direction = direction
    self.tooltip = tooltip
    window?.orderFront(nil)
    set(windowTopLeftPoint: point, bottomOutOfScreenAdjustmentHeight: heightDelta)
  }

  public func setColor(state: ColorStates) {
    var backgroundColor = NSColor.controlBackgroundColor
    var textColor = NSColor.textColor
    switch state {
      case .normal:
        backgroundColor = NSColor(
          red: 0.18, green: 0.18, blue: 0.18, alpha: 1.00
        )
        textColor = NSColor.white
      case .redAlert:
        backgroundColor = NSColor(
          red: 0.55, green: 0.00, blue: 0.00, alpha: 1.00
        )
        textColor = NSColor.white
      case .warning:
        backgroundColor = NSColor.purple
        textColor = NSColor.white
      case .denialOverflow:
        backgroundColor = NSColor(
          red: 0.13, green: 0.08, blue: 0.00, alpha: 1.00
        )
        textColor = NSColor(
          red: 1.00, green: 0.60, blue: 0.00, alpha: 1.00
        )
      case .denialInsufficiency:
        backgroundColor = NSColor.windowBackgroundColor
        textColor = NSColor.labelColor
      case .prompt:
        backgroundColor = NSColor(
          red: 0.09, green: 0.15, blue: 0.15, alpha: 1.00
        )
        textColor = NSColor(
          red: 0.91, green: 0.95, blue: 0.92, alpha: 1.00
        )
    }
    if !IME.isDarkMode {
      switch state {
        case .denialInsufficiency: break
        default:
          let colorInterchange = backgroundColor
          backgroundColor = textColor
          textColor = colorInterchange
      }
    }
    window?.backgroundColor = backgroundColor
    messageText.backgroundColor = backgroundColor
    messageText.textColor = textColor
  }

  public func resetColor() {
    setColor(state: .normal)
  }

  public func hide() {
    window?.orderOut(nil)
  }

  private func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight heightDelta: CGFloat) {
    guard let window = window else { return }
    let windowSize = window.frame.size

    var adjustedPoint = windowTopLeftPoint
    var delta = heightDelta
    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ !$0.contains(windowTopLeftPoint) }) {
      screenFrame = frame
      break
    }

    if delta > screenFrame.size.height / 2.0 { delta = 0.0 }

    if adjustedPoint.y < screenFrame.minY + windowSize.height {
      adjustedPoint.y = windowTopLeftPoint.y + windowSize.height + delta
    }
    adjustedPoint.y = min(adjustedPoint.y, screenFrame.maxY - 1.0)
    adjustedPoint.x = min(max(adjustedPoint.x, screenFrame.minX), screenFrame.maxX - windowSize.width - 1.0)

    window.setFrameTopLeftPoint(adjustedPoint)
  }

  private func adjustSize() {
    let attrString = messageText.attributedStringValue
    var rect = attrString.boundingRect(
      with: NSSize(width: 1600.0, height: 1600.0),
      options: [.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics]
    )
    if direction != .horizontal {
      rect = .init(x: rect.minX, y: rect.minY, width: rect.height, height: rect.width)
      rect.size.height += NSFont.systemFontSize
      rect.size.width *= 1.03
      rect.size.width = max(rect.size.width, NSFont.systemFontSize * 1.05)
      rect.size.width = ceil(rect.size.width)
    } else {
      rect = .init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
      rect.size.width += NSFont.systemFontSize
      rect.size.height *= 1.03
      rect.size.height = max(rect.size.height, NSFont.systemFontSize * 1.05)
      rect.size.height = ceil(rect.size.height)
    }
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += NSFont.systemFontSize / 2
    rect.origin.y += NSFont.systemFontSize / 2
    messageText.frame = rect
    window?.setFrame(bigRect, display: true)
    messageText.draw(messageText.frame)
  }
}
