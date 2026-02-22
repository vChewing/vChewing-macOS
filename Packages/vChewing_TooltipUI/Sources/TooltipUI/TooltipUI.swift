// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import CoreText
import Shared_DarwinImpl

// MARK: - TooltipUI

public final class TooltipUI: NSWindowController, TooltipUIProtocol {
  // MARK: Lifecycle

  public init() {
    let contentRect = CGRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
    panel.hasShadow = true
    if #available(macOS 10.13, *) {
      panel.backgroundColor = .clear
      panel.isOpaque = false
    } else {
      panel.backgroundColor = NSColor.windowBackgroundColor
      panel.isOpaque = true
    }
    panel.isMovable = false
    self.tooltipView = TooltipContentView(frame: CGRect(origin: .zero, size: contentRect.size))
    tooltipView.wantsLayer = true
    tooltipView.layer?.cornerRadius = 7
    tooltipView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    tooltipView.layer?.masksToBounds = true
    tooltipView.textColor = NSColor.textColor
    tooltipView.translatesAutoresizingMaskIntoConstraints = true
    if #available(macOS 10.13, *) {
      panel.contentView = tooltipView
    } else {
      panel.contentView = tooltipView
    }
    Self.currentWindow = panel
    super.init(window: panel)

    tooltipView.onIntrinsicSizeChanged = { [weak self] newSize in
      self?.updateWindowSize(to: newSize)
    }
    updateWindowSize(to: tooltipView.intrinsicContentSize)

    self.observation = Broadcaster.shared
      .observe(\.eventForClosingAllPanels, options: [.new]) { [weak self] _, _ in
        asyncOnMain {
          self?.hide()
        }
      }
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    mainSync {
      observation?.invalidate()
    }
  }

  // MARK: Public

  public var direction: UILayoutOrientation = .horizontal {
    didSet {
      if let preferred = Bundle.main.preferredLocalizations.first, preferred == "en",
         direction != .horizontal {
        direction = .horizontal
        return
      }
      tooltipView.writingDirection = direction
      adjustSize()
    }
  }

  public func show(
    tooltip: String, at point: CGPoint,
    bottomOutOfScreenAdjustmentHeight heightDelta: Double,
    direction: UILayoutOrientation = .horizontal, duration: Double
  ) {
    self.direction = direction
    self.tooltip = tooltip
    window?.setIsVisible(false)
    window?.orderFront(nil)
    set(windowTopLeftPoint: point, bottomOutOfScreenAdjustmentHeight: heightDelta, useGCD: false)
    window?.setIsVisible(true)
    if duration > 0 {
      asyncOnMain(after: duration) {
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
    if !NSApplication.isDarkMode, #available(macOS 10.10, *) {
      let colorInterchange = backgroundColor
      backgroundColor = textColor
      textColor = colorInterchange
    }
    tooltipView.layer?.backgroundColor = backgroundColor.cgColor
    if let window, window.isOpaque {
      window.backgroundColor = backgroundColor
    }
    tooltipView.textColor = textColor
  }

  public func resetColor() {
    setColor(state: .normal)
  }

  nonisolated public func hide() {
    mainSync {
      self.setColor(state: .normal)
      self.window?.orderOut(nil)
    }
  }

  // MARK: Internal

  @objc
  var observation: NSKeyValueObservation?

  // MARK: Private

  private static var currentWindow: NSWindow? {
    willSet {
      currentWindow?.orderOut(nil)
    }
  }

  private let tooltipView: TooltipContentView

  private var tooltip: String = "" {
    didSet {
      tooltipView.text = tooltip
      adjustSize()
    }
  }

  private func adjustSize() {
    updateWindowSize(to: tooltipView.intrinsicContentSize)
  }

  private func updateWindowSize(to contentSize: CGSize) {
    guard let window else { return }
    let adjustedSize = CGSize(
      width: max(contentSize.width, TooltipContentView.minimumSize.width),
      height: max(contentSize.height, TooltipContentView.minimumSize.height)
    )
    tooltipView.frame = CGRect(origin: .zero, size: adjustedSize)
    window.setContentSize(adjustedSize)
    window.invalidateShadow()
  }
}

// MARK: - TooltipContentView

private final class TooltipContentView: NSView {
  // MARK: Lifecycle

  override init(frame frameRect: CGRect) {
    self.attributedText = NSAttributedString(string: "")
    super.init(frame: frameRect)
    commonInit()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  static let minimumSize = CGSize(width: 32, height: 20)

  override var isFlipped: Bool {
    true
  }

  override var intrinsicContentSize: CGSize {
    cachedIntrinsicSize
  }

  var onIntrinsicSizeChanged: ((CGSize) -> ())?

  var text: String = "" {
    didSet {
      if text != oldValue {
        rebuildAttributedText()
      }
    }
  }

  var writingDirection: UILayoutOrientation = .horizontal {
    didSet {
      if writingDirection != oldValue {
        rebuildAttributedText()
      }
    }
  }

  var textColor: NSColor = .textColor {
    didSet {
      if textColor != oldValue {
        rebuildAttributedText()
      }
    }
  }

  override func draw(_ dirtyRect: CGRect) {
    super.draw(dirtyRect)
    guard attributedText.length > 0 else { return }

    let origin = textDrawingOrigin()
    if usesVerticalTypesetting {
      drawVerticalText(at: origin)
    } else {
      let drawingRect = CGRect(
        origin: origin,
        size: CGSize(
          width: bounds.width - textPadding * 2,
          height: bounds.height - textPadding * 2
        )
      )
      attributedText.draw(
        with: drawingRect,
        options: [.usesLineFragmentOrigin, .usesFontLeading]
      )
    }
  }

  // MARK: Private

  private var attributedText: NSAttributedString
  private var cachedIntrinsicSize: CGSize = .init(width: 300, height: 20)
  private var cachedTextMetrics: CGSize = .zero

  private var textPadding: CGFloat {
    ceil(NSFont.systemFontSize / 2)
  }

  private var usesVerticalTypesetting: Bool {
    if #available(macOS 10.13, *) {
      return writingDirection == .vertical
    }
    return false
  }

  private func commonInit() {
    wantsLayer = true
    layer?.cornerRadius = 7
    layer?.masksToBounds = true
    layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    rebuildAttributedText()
  }

  private func rebuildAttributedText() {
    let newAttributedText = buildAttributedString()
    attributedText = newAttributedText
    updateLayout()
  }

  private func buildAttributedString() -> NSAttributedString {
    guard !text.isEmpty else {
      return NSAttributedString(string: "")
    }

    let font = tooltipFont()
    let paragraphStyle = paragraphStyleFor(font: font)

    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textColor,
      .paragraphStyle: paragraphStyle,
      .kern: 0,
    ]

    var text = text
    if usesVerticalTypesetting {
      attributes[.verticalGlyphForm] = true
      attributes[NSAttributedString.Key(rawValue: "CTVerticalForms")] = true
      text = normalizedVerticalString(text)
    }

    return NSAttributedString(string: text, attributes: attributes)
  }

  private func paragraphStyleFor(font: NSFont) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    style.lineBreakMode = .byClipping
    if usesVerticalTypesetting, #available(macOS 10.13, *) {
      let lineHeight = font.pointSize * 1.1
      style.minimumLineHeight = lineHeight
      style.maximumLineHeight = lineHeight
      style.lineSpacing = -font.pointSize * 0.1
    }
    return style
  }

  private func tooltipFont() -> NSFont {
    NSFont.systemFont(ofSize: max(12, NSFont.systemFontSize + 1))
  }

  private func updateLayout() {
    let metrics = calculateTextMetrics()
    cachedTextMetrics = metrics

    let paddedWidth = max(metrics.width + textPadding * 2, textPadding * 2)
    let paddedHeight = max(metrics.height + textPadding * 2, textPadding * 2)

    let newSize = CGSize(width: paddedWidth, height: paddedHeight)
    if cachedIntrinsicSize != newSize {
      cachedIntrinsicSize = newSize
      invalidateIntrinsicContentSize()
      onIntrinsicSizeChanged?(newSize)
    }

    needsDisplay = true
  }

  private func drawVerticalText(at point: CGPoint) {
    let graphicsContext: CGContext?
    if #unavailable(macOS 10.10) {
      guard let currentContext = NSGraphicsContext.current else { return }
      let contextPtr = Unmanaged<CGContext>.fromOpaque(currentContext.graphicsPort)
      graphicsContext = contextPtr.takeUnretainedValue()
    } else {
      graphicsContext = NSGraphicsContext.current?.cgContext
    }
    guard let context = graphicsContext, attributedText.length > 0 else { return }

    let textWidth = max(cachedTextMetrics.width, 1)
    let textHeight = max(cachedTextMetrics.height, 1)

    let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
    let frameAttributes: [CFString: Any] = [
      kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue,
    ]

    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: 0, y: bounds.height)
    context.scaleBy(x: 1, y: -1)

    let path = CGMutablePath()
    let frameRect = CGRect(
      x: point.x,
      y: bounds.height - point.y - textHeight,
      width: textWidth,
      height: textHeight
    )
    path.addRect(frameRect)

    let frame = CTFramesetterCreateFrame(
      framesetter,
      CFRangeMake(0, attributedText.length),
      path,
      frameAttributes as CFDictionary
    )
    CTFrameDraw(frame, context)
    context.restoreGState()
  }

  private func textDrawingOrigin() -> CGPoint {
    CGPoint(x: textPadding, y: textPadding)
  }

  private func calculateTextMetrics() -> CGSize {
    guard attributedText.length > 0 else {
      return .zero
    }

    let usedRect = attributedText.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    var contentWidth = ceil(max(usedRect.width, 1))
    var contentHeight = ceil(max(usedRect.height, 1))

    if usesVerticalTypesetting {
      let verticalSize = measureVerticalTextSize()
      if verticalSize != .zero {
        contentWidth = ceil(max(verticalSize.width, 1))
        contentHeight = max(contentHeight, ceil(max(verticalSize.height, 1)))
      }
    }

    return CGSize(width: contentWidth, height: contentHeight)
  }

  private func measureVerticalTextSize() -> CGSize {
    let font = tooltipFont()
    let normalizedText = normalizedVerticalString(attributedText.string)

    guard !normalizedText.isEmpty else {
      return .zero
    }

    let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
    let frameAttributes: [CFString: Any] = [
      kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue,
    ]

    let minimumAdvance = verticalGlyphAdvance(for: font, including: normalizedText)
    let minimumWidth = max(minimumAdvance, 1)
    let minimumHeight = max(ceil(font.pointSize), 1)

    let constraints = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )

    var fitRange = CFRange(location: 0, length: 0)
    var suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter,
      CFRangeMake(0, attributedText.length),
      frameAttributes as CFDictionary,
      constraints,
      &fitRange
    )

    if !suggestedSize.width.isFinite {
      suggestedSize.width = 0
    }
    if !suggestedSize.height.isFinite {
      suggestedSize.height = 0
    }

    let finalWidth: CGFloat = max(ceil(suggestedSize.width), minimumWidth)
    let finalHeight: CGFloat = max(ceil(suggestedSize.height), minimumHeight)

    return CGSize(width: finalWidth, height: finalHeight)
  }

  private func normalizedVerticalString(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "˙", with: "･")
      .replacingOccurrences(of: "\u{A0}", with: "　")
      .replacingOccurrences(of: "+", with: "")
      .replacingOccurrences(of: "Shift", with: "⇧")
      .replacingOccurrences(of: "Control", with: "⌃")
      .replacingOccurrences(of: "Enter", with: "⏎")
      .replacingOccurrences(of: "Command", with: "⌘")
      .replacingOccurrences(of: "Delete", with: "⌦")
      .replacingOccurrences(of: "BackSpace", with: "⌫")
      .replacingOccurrences(of: "Space", with: "␣")
      .replacingOccurrences(of: "SHIFT", with: "⇧")
      .replacingOccurrences(of: "CONTROL", with: "⌃")
      .replacingOccurrences(of: "ENTER", with: "⏎")
      .replacingOccurrences(of: "COMMAND", with: "⌘")
      .replacingOccurrences(of: "DELETE", with: "⌦")
      .replacingOccurrences(of: "BACKSPACE", with: "⌫")
      .replacingOccurrences(of: "SPACE", with: "␣")
  }

  private func verticalGlyphAdvance(for font: NSFont, including text: String) -> CGFloat {
    let ctFont = font as CTFont
    var uniqueSamples: Set<String> = [
      "漢", "字", "A", "0", "・", "　", "💩",
      "･", "　", "", "⇧", "⌃", "⏎", "⌘",
      "⌦", "⌫", "␣", "⇧", "⌃", "⏎", "⌘",
      "⌦", "⌫", "␣",
    ]

    for character in text where character != "\n" {
      uniqueSamples.insert(String(character))
    }

    var maxAdvance: CGFloat = 0

    for sample in uniqueSamples {
      let utf16 = Array(sample.utf16)
      guard !utf16.isEmpty else { continue }

      var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
      utf16.withUnsafeBufferPointer { charPtr in
        glyphs.withUnsafeMutableBufferPointer { glyphPtr in
          guard let charBase = charPtr.baseAddress, let glyphBase = glyphPtr.baseAddress else {
            return
          }
          CTFontGetGlyphsForCharacters(ctFont, charBase, glyphBase, utf16.count)
        }
      }

      for glyph in glyphs where glyph != 0 {
        var advance = CGSize.zero
        _ = withUnsafePointer(to: glyph) { glyphPtr in
          withUnsafeMutablePointer(to: &advance) { advancePtr in
            CTFontGetAdvancesForGlyphs(ctFont, .vertical, glyphPtr, advancePtr, 1)
          }
        }
        maxAdvance = max(maxAdvance, abs(advance.height))
      }
    }

    return ceil(maxAdvance)
  }
}

// MARK: - ShadowHostingView
