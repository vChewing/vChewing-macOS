// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import CoreText
import Shared

// MARK: - PopupCompositionBuffer

public class PopupCompositionBuffer: NSWindowController {
  // MARK: Lifecycle

  public init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect,
      styleMask: styleMask,
      backing: .buffered,
      defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 1)
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false

    self.visualEffectView = {
      if #available(macOS 26.0, *), NSApplication.uxLevel == .liquidGlass {
        #if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
          let resultView = NSGlassEffectView()
          resultView.cornerRadius = 9
          resultView.style = .clear
          let bgTintColor: NSColor = !NSApplication.isDarkMode ? .white : .black
          resultView.wantsLayer = true
          resultView.layer?.cornerRadius = 9
          resultView.layer?.masksToBounds = true
          resultView.layer?.backgroundColor = bgTintColor.withAlphaComponent(0.1).cgColor
          return resultView
        #endif
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        let resultView = NSVisualEffectView()
        resultView.material = .titlebar
        resultView.blendingMode = .behindWindow
        resultView.state = .active
        // 設置圓角以保持原有的視覺特性
        resultView.wantsLayer = true
        resultView.layer?.cornerRadius = 9
        resultView.layer?.masksToBounds = true
        return resultView
      }
      return nil
    }()

    self.compositionView = PopupCompositionView(frame: contentRect)
    let viewSize = compositionView.fittingSize

    if #available(macOS 10.13, *) {
      // 創建容器視圖作為 ZStack，設置固定尺寸
      let containerView = NSView(frame: NSRect(origin: .zero, size: viewSize))
      // 為容器視圖也設置圓角，確保整體一致性
      containerView.wantsLayer = true
      containerView.layer?.cornerRadius = 9
      containerView.layer?.masksToBounds = true

      // 設置背景視覺效果視圖
      if let visualEffectView {
        containerView.addSubview(visualEffectView)
        visualEffectView.pinEdges(to: containerView)
      }

      // 添加候選窗口內容視圖
      containerView.addSubview(compositionView)
      compositionView.pinEdges(to: containerView)

      panel.contentView = containerView
    } else {
      compositionView.translatesAutoresizingMaskIntoConstraints = true
      compositionView.frame = NSRect(origin: .zero, size: contentRect.size)
      panel.contentView = compositionView
      panel.contentView?.wantsLayer = true
      panel.contentView?.shadow = .init()
      panel.contentView?.shadow?.shadowBlurRadius = 6
      panel.contentView?.shadow?.shadowColor = .black
      panel.contentView?.shadow?.shadowOffset = .zero
      if let layer = panel.contentView?.layer {
        layer.cornerRadius = 9
        layer.borderWidth = 1
        layer.masksToBounds = true
      }
    }

    // 設置尺寸變更回調
    compositionView.onSizeChanged = { [weak panel] newSize in
      panel?.setFrame(NSRect(origin: panel?.frame.origin ?? .zero, size: newSize), display: true)
    }

    Self.currentWindow = panel
    super.init(window: panel)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public var isTypingDirectionVertical: Bool {
    get { compositionView.isTypingDirectionVertical }
    set { compositionView.isTypingDirectionVertical = newValue }
  }

  public func sync(accent: NSColor?, locale: String) {
    compositionView.setupTheme(accent: accent, locale: locale)
    window?.backgroundColor = .clear
  }

  public func show(state: IMEStateProtocol, at point: NSPoint) {
    if !state.hasComposition {
      hide()
      return
    }

    compositionView.update(using: state)

    window?.orderFront(nil)
    set(windowOrigin: point)
  }

  public func hide() {
    compositionView.prepareForHide()
    window?.orderOut(nil)
  }

  // MARK: Internal

  static let bgOpacity: CGFloat = 0.8

  // MARK: Private

  private static var currentWindow: NSWindow? {
    willSet {
      currentWindow?.orderOut(nil)
    }
  }

  private let compositionView: PopupCompositionView
  private let visualEffectView: NSView?

  private func set(windowOrigin: NSPoint) {
    guard let window = window else { return }
    let windowSize = window.frame.size

    var adjustedPoint = windowOrigin
    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.seniorTheBeast
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ $0.contains(windowOrigin) }) {
      screenFrame = frame
      break
    }

    adjustedPoint.y = min(
      max(adjustedPoint.y, screenFrame.minY + windowSize.height),
      screenFrame.maxY
    )
    adjustedPoint.x = min(
      max(adjustedPoint.x, screenFrame.minX),
      screenFrame.maxX - windowSize.width
    )

    if compositionView.isTypingDirectionVertical {
      window.setFrameTopLeftPoint(adjustedPoint)
    } else {
      window.setFrameOrigin(adjustedPoint)
    }
  }
}

// MARK: - PopupCompositionView

internal class PopupCompositionView: NSView {
  // MARK: Lifecycle

  override init(frame frameRect: NSRect) {
    self.caretLayer = CALayer()
    super.init(frame: frameRect)
    commonInit()
  }

  required init?(coder: NSCoder) {
    self.caretLayer = CALayer()
    super.init(coder: coder)
    commonInit()
  }

  deinit {
    stopCaretBlinking()
  }

  // MARK: Internal

  override var isFlipped: Bool {
    true
  }

  override var intrinsicContentSize: NSSize {
    cachedIntrinsicSize
  }

  var locale: String = ""
  var accent: NSColor = .accentColor

  var onSizeChanged: ((NSSize) -> ())?

  var isTypingDirectionVertical = false {
    didSet {
      if oldValue != isTypingDirectionVertical {
        updateLayout()
      }
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard !attributedText.string.isEmpty else { return }

    let drawingPoint = textDrawingOrigin()

    if usesVerticalTypesetting {
      // 垂直書寫使用 Core Text
      drawVerticalText(at: drawingPoint)
    } else {
      // 水平書寫使用標準方法
      attributedText.draw(at: drawingPoint)
    }
  }

  func setupTheme(accent: NSColor?, locale: String) {
    self.locale = locale
    if let accent = accent {
      self.accent = (accent.alphaComponent == 1)
        ? accent.withAlphaComponent(PopupCompositionBuffer.bgOpacity) : accent
    } else {
      self.accent = themeColorCocoa
    }
    let themeColor = adjustedThemeColor
    if #unavailable(macOS 10.9) {
      layer?.backgroundColor = themeColor.cgColor
    } else {
      layer?.backgroundColor = themeColor.withAlphaComponent(0.5).cgColor
    }
    layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
    caretLayer.backgroundColor = textColor.cgColor
    needsDisplay = true
  }

  func update(using state: IMEStateProtocol) {
    guard state.hasComposition else {
      attributedText = NSAttributedString(string: "")
      currentCaretIndex = 0
      caretLayer.isHidden = true
      stopCaretBlinking()
      updateLayout()
      return
    }

    let attributed = prepareAttributedString(from: state)
    attributedText = attributed
    currentCaretIndex = max(0, min(state.u16Cursor, attributed.length))
    markedRange = NSRange(
      location: state.u16MarkedRange.lowerBound,
      length: state.u16MarkedRange.upperBound - state.u16MarkedRange.lowerBound
    )
    updateLayout()
  }

  func prepareForHide() {
    stopCaretBlinking()
    caretLayer.isHidden = true
  }

  // MARK: Private

  private let caretLayer: CALayer
  private var attributedText: NSAttributedString = .init()
  private var cachedIntrinsicSize: NSSize = .init(width: 300, height: 20)
  private var currentCaretIndex: Int = 0
  private var markedRange: NSRange = .init(location: NSNotFound, length: 0)

  private var textPadding: CGFloat {
    ceil(NSFont.systemFontSize / 2)
  }

  private var caretThickness: CGFloat {
    usesVerticalTypesetting ? 2.0 : 1.5
  }

  private var usesVerticalTypesetting: Bool {
    isTypingDirectionVertical
  }

  private var themeColorCocoa: NSColor {
    switch locale {
    case "zh-Hans":
      return .init(
        red: 255 / 255,
        green: 64 / 255,
        blue: 53 / 255,
        alpha: PopupCompositionBuffer.bgOpacity
      )
    case "zh-Hant":
      return .init(
        red: 5 / 255,
        green: 127 / 255,
        blue: 255 / 255,
        alpha: PopupCompositionBuffer.bgOpacity
      )
    case "ja":
      return .init(
        red: 167 / 255,
        green: 137 / 255,
        blue: 99 / 255,
        alpha: PopupCompositionBuffer.bgOpacity
      )
    default:
      return .init(
        red: 5 / 255,
        green: 127 / 255,
        blue: 255 / 255,
        alpha: PopupCompositionBuffer.bgOpacity
      )
    }
  }

  private var markerColor: NSColor {
    NSColor.selectedMenuItemTextColor.withAlphaComponent(0.9)
  }

  private var markerTextColor: NSColor {
    adjustedThemeColor
  }

  private var textColor: NSColor {
    .selectedMenuItemTextColor
  }

  private var adjustedThemeColor: NSColor {
    accent.blended(withFraction: NSApplication.isDarkMode ? 0.5 : 0.25, of: .black) ?? accent
  }

  private func drawVerticalText(at point: CGPoint) {
    let context: CGContext?
    if #unavailable(macOS 10.10) {
      guard let currentNSGraphicsContext = NSGraphicsContext.current else { return }
      let contextPtr: Unmanaged<CGContext>? = Unmanaged
        .fromOpaque(currentNSGraphicsContext.graphicsPort)
      context = contextPtr?.takeUnretainedValue()
    } else {
      context = NSGraphicsContext.current?.cgContext
    }
    guard let context, attributedText.length > 0 else { return }

    let measuredRect = attributedText.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).integral

    let textWidth: CGFloat
    let textHeight: CGFloat
    if usesVerticalTypesetting {
      textWidth = max(measuredRect.height, 1)
      textHeight = max(measuredRect.width, 1)
    } else {
      textWidth = max(measuredRect.width, 1)
      textHeight = max(measuredRect.height, 1)
    }

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

  private func commonInit() {
    wantsLayer = true
    shadow = .init()
    shadow?.shadowBlurRadius = 6
    shadow?.shadowColor = .black
    shadow?.shadowOffset = .zero
    layer?.cornerRadius = 9
    layer?.borderWidth = 1
    layer?.masksToBounds = true
    layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2

    caretLayer.opacity = 1
    caretLayer.isHidden = true
    caretLayer.cornerRadius = 0
    caretLayer.backgroundColor = textColor.cgColor
    layer?.addSublayer(caretLayer)

    layer?.isGeometryFlipped = true
    caretLayer.isGeometryFlipped = true

    updateLayout()
  }

  private func updateLayout() {
    let usedRect = attributedText.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    let contentWidth: CGFloat
    let contentHeight: CGFloat
    if usesVerticalTypesetting {
      contentWidth = ceil(max(usedRect.height, 1))
      contentHeight = ceil(max(usedRect.width, 1))
    } else {
      contentWidth = ceil(max(usedRect.width, 1))
      contentHeight = ceil(max(usedRect.height, 1))
    }
    let paddedWidth = max(contentWidth + textPadding * 2, textPadding * 2)
    let paddedHeight = max(contentHeight + textPadding * 2, textPadding * 2)

    let newSize = NSSize(width: paddedWidth, height: paddedHeight)

    if cachedIntrinsicSize != newSize {
      cachedIntrinsicSize = newSize
      invalidateIntrinsicContentSize()
      onSizeChanged?(newSize)
    }

    needsDisplay = true
    updateCaretLayer()
  }

  private func updateCaretLayer() {
    caretLayer.removeAnimation(forKey: "blink")
    caretLayer.removeAnimation(forKey: "verticalPulse")

    guard !attributedText.string.isEmpty || currentCaretIndex == 0 else {
      caretLayer.isHidden = true
      return
    }

    let caretRect = caretRectForCurrentText()
    let origin = textDrawingOrigin()
    caretLayer.frame = caretRect.offsetBy(dx: origin.x, dy: origin.y).integral

    // 針對直書模式優化游標樣式
    if usesVerticalTypesetting {
      caretLayer.cornerRadius = caretLayer.frame.height / 2
      caretLayer.backgroundColor = textColor.withAlphaComponent(0.9).cgColor
    } else {
      caretLayer.cornerRadius = caretLayer.frame.width / 2
      caretLayer.backgroundColor = textColor.cgColor
    }

    caretLayer.isHidden = false
    startCaretBlinking()
  }

  private func caretRectForCurrentText() -> CGRect {
    let font = bufferFont()
    let defaultHeight = font.pointSize * 1.2
    let enhancedThickness = usesVerticalTypesetting ? caretThickness * 1.5 : caretThickness

    guard !attributedText.string.isEmpty else {
      if usesVerticalTypesetting {
        // 直書模式：横向的遊標，稍微加寬以提高可見度
        return CGRect(x: 0, y: 0, width: defaultHeight * 0.9, height: enhancedThickness)
      } else {
        // 橫書模式：縱向的遊標
        return CGRect(x: 0, y: 0, width: caretThickness, height: defaultHeight)
      }
    }

    let clamped = max(0, min(currentCaretIndex, attributedText.length))

    // 計算光標前的文字範圍
    let prefixString = attributedText.attributedSubstring(from: NSRange(
      location: 0,
      length: clamped
    ))
    let prefixRect = prefixString.boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    if usesVerticalTypesetting {
      // 直書模式：遊標沿縱向排列，寬度覆蓋整個行距
      let caretAdvance = max(prefixRect.width, 0)
      let caretSpan = max(prefixRect.height, font.pointSize * 1.1)
      return CGRect(
        x: -caretThickness,
        y: caretAdvance,
        width: caretSpan + caretThickness * 2,
        height: enhancedThickness
      )
    } else {
      // 橫書模式：遊標是縱向的線條
      return CGRect(
        x: prefixRect.width,
        y: 0,
        width: caretThickness,
        height: defaultHeight
      )
    }
  }

  private func textDrawingOrigin() -> CGPoint {
    CGPoint(x: textPadding, y: textPadding)
  }

  private func startCaretBlinking() {
    caretLayer.removeAnimation(forKey: "blink")
    caretLayer.removeAnimation(forKey: "verticalPulse")

    if usesVerticalTypesetting {
      // 直書模式：使用脈衝效果 + 透明度變化
      let opacityAnimation = CABasicAnimation(keyPath: "opacity")
      opacityAnimation.fromValue = 1.0
      opacityAnimation.toValue = 0.3
      opacityAnimation.duration = 0.4
      opacityAnimation.autoreverses = true
      opacityAnimation.repeatCount = .infinity

      let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
      scaleAnimation.fromValue = 1.0
      scaleAnimation.toValue = 1.2
      scaleAnimation.duration = 0.4
      scaleAnimation.autoreverses = true
      scaleAnimation.repeatCount = .infinity

      let groupAnimation = CAAnimationGroup()
      groupAnimation.animations = [opacityAnimation, scaleAnimation]
      groupAnimation.duration = 0.4
      groupAnimation.repeatCount = .infinity

      caretLayer.add(groupAnimation, forKey: "verticalPulse")
    } else {
      // 橫書模式：標準閃爍動畫
      let animation = CABasicAnimation(keyPath: "opacity")
      animation.fromValue = 1.0
      animation.toValue = 0.0
      animation.duration = 0.35
      animation.autoreverses = true
      animation.repeatCount = .infinity
      caretLayer.add(animation, forKey: "blink")
    }
  }

  private func stopCaretBlinking() {
    caretLayer.removeAnimation(forKey: "blink")
    caretLayer.removeAnimation(forKey: "verticalPulse")
    // 重置 layer 狀態
    caretLayer.opacity = 1.0
    caretLayer.transform = CATransform3DIdentity
  }

  private func prepareAttributedString(from state: IMEStateProtocol) -> NSAttributedString {
    let attrString = NSMutableAttributedString(string: state.displayedTextConverted)

    let baseFont = bufferFont()
    let paragraphStyle: NSParagraphStyle = {
      let style = NSMutableParagraphStyle()
      style.lineBreakMode = .byClipping
      // 直書模式需要特殊設定
      if usesVerticalTypesetting, #available(macOS 10.13, *) {
        // 使用較緊密的行高以改善直書顯示
        let fontSize = baseFont.pointSize
        style.maximumLineHeight = fontSize * 1.1
        style.minimumLineHeight = fontSize * 1.1
        style.lineSpacing = -fontSize * 0.1
      }
      return style
    }()

    var baseAttributes: [NSAttributedString.Key: Any] = [
      .font: baseFont,
      .foregroundColor: textColor,
      .paragraphStyle: paragraphStyle,
      .kern: 0,
    ]

    if usesVerticalTypesetting {
      baseAttributes[.verticalGlyphForm] = true
      // 直書模式的額外設定
      baseAttributes[NSAttributedString.Key(rawValue: "CTVerticalForms")] = true
    }

    attrString.setAttributes(baseAttributes, range: NSRange(location: 0, length: attrString.length))

    let markRange = state.u16MarkedRange
    if markRange.lowerBound < markRange.upperBound,
       markRange.upperBound <= attrString.length {
      var markerAttributes: [NSAttributedString.Key: Any] = [
        .backgroundColor: markerColor,
        .foregroundColor: markerTextColor,
        .font: baseFont,
        .markedClauseSegment: 0,
        .kern: 0,
      ]
      if usesVerticalTypesetting {
        markerAttributes[.verticalGlyphForm] = true
        markerAttributes[.paragraphStyle] = paragraphStyle
        markerAttributes[NSAttributedString.Key(rawValue: "CTVerticalForms")] = true
      }
      attrString.addAttributes(
        markerAttributes,
        range: NSRange(
          location: markRange.lowerBound,
          length: markRange.upperBound - markRange.lowerBound
        )
      )
    }

    return attrString
  }

  private func bufferFont(size: CGFloat = 18) -> NSFont {
    let defaultResult: CTFont? = CTFontCreateUIFontForLanguage(.system, size, locale as CFString)
    return defaultResult ?? NSFont.systemFont(ofSize: size)
  }
}
