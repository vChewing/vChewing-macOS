// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import CocoaExtension
import NSAttributedTextView
import Shared

public class TooltipUI: NSWindowController {
  private var messageText: NSAttributedTooltipTextView
  private var tooltip: String = "" {
    didSet {
      messageText.text = tooltip.isEmpty ? nil : tooltip
      adjustSize()
    }
  }

  public var direction: NSAttributedTooltipTextView.writingDirection = .horizontal {
    didSet {
      if #unavailable(macOS 10.13) { direction = .horizontal }
      if Bundle.main.preferredLocalizations[0] == "en" { direction = .horizontal }
      messageText.direction = direction
    }
  }

  public init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 2)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.controlBackgroundColor
    panel.isMovable = false
    messageText = NSAttributedTooltipTextView()
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
    bottomOutOfScreenAdjustmentHeight heightDelta: Double,
    direction: NSAttributedTooltipTextView.writingDirection = .horizontal, duration: Double = 0
  ) {
    self.direction = direction
    self.tooltip = tooltip
    window?.setIsVisible(false)
    window?.orderFront(nil)
    set(windowTopLeftPoint: point, bottomOutOfScreenAdjustmentHeight: heightDelta, useGCD: false)
    window?.setIsVisible(true)
    if duration > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        self.window?.orderOut(nil)
      }
    }
  }

  public func setColor(state: TooltipColorState) {
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
      case .succeeded:
        backgroundColor = NSColor(
          red: 0.21, green: 0.15, blue: 0.02, alpha: 1.00
        )
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
    if !NSApplication.isDarkMode {
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
    setColor(state: .normal)
    window?.orderOut(nil)
  }

  private func adjustSize() {
    var rect = messageText.shrinkFrame()
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += ceil(NSFont.systemFontSize / 2)
    rect.origin.y += ceil(NSFont.systemFontSize / 2)
    messageText.frame = rect
    window?.setFrame(bigRect, display: true)
    messageText.draw(messageText.frame)
  }
}
