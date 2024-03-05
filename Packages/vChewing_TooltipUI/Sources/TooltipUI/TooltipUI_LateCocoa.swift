// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import NSAttributedTextView
import OSFrameworkImpl
import Shared

public class TooltipUI_LateCocoa: NSWindowController, TooltipUIProtocol {
  @objc var observation: NSKeyValueObservation?
  private var messageText: NSAttributedTooltipTextView
  private var tooltip: String = "" {
    didSet {
      messageText.text = tooltip.isEmpty ? nil : tooltip
      adjustSize()
    }
  }

  private static var currentWindow: NSWindow? {
    willSet {
      currentWindow?.orderOut(nil)
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
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.clear
    panel.isOpaque = false
    panel.isMovable = false
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.cornerRadius = 7
    panel.contentView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    messageText = NSAttributedTooltipTextView()
    messageText.backgroundColor = NSColor.clear
    messageText.textColor = NSColor.textColor
    messageText.needsDisplay = true
    panel.contentView?.addSubview(messageText)
    Self.currentWindow = panel
    super.init(window: panel)

    observation = Broadcaster.shared.observe(\.eventForClosingAllPanels, options: [.new]) { _, _ in
      self.hide()
    }
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func show(
    tooltip: String, at point: NSPoint,
    bottomOutOfScreenAdjustmentHeight heightDelta: Double,
    direction: NSUserInterfaceLayoutOrientation = .horizontal, duration: Double
  ) {
    self.direction = direction == .horizontal ? .horizontal : .vertical
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
    case .information:
      backgroundColor = NSColor(
        red: 0.09, green: 0.14, blue: 0.16, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.91, green: 0.92, blue: 0.95, alpha: 1.00
      )
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
      backgroundColor = NSColor(
        red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.88, green: 0.88, blue: 0.88, alpha: 1.00
      )
    case .prompt:
      backgroundColor = NSColor(
        red: 0.09, green: 0.16, blue: 0.14, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.91, green: 0.95, blue: 0.92, alpha: 1.00
      )
    }
    if !NSApplication.isDarkMode {
      let colorInterchange = backgroundColor
      backgroundColor = textColor
      textColor = colorInterchange
    }
    window?.contentView?.layer?.backgroundColor = backgroundColor.cgColor
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
