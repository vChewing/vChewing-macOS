// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
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
      // LiquidGlass 效果會嚴重威脅到視窗後特殊背景下的文字可見性，只能棄用。
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

    // 創建容器視圖作為 ZStack，設置固定尺寸
    let containerView = NSView(frame: NSRect(origin: .zero, size: viewSize))
    // 為容器視圖也設置圓角，確保整體一致性
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = 9
    containerView.layer?.masksToBounds = true

    // 設置背景視覺效果視圖
    if let visualEffectView {
      visualEffectView.translatesAutoresizingMaskIntoConstraints = false
      containerView.addSubview(visualEffectView)
      let visualConstraints = [
        NSLayoutConstraint(
          item: visualEffectView,
          attribute: .top,
          relatedBy: .equal,
          toItem: containerView,
          attribute: .top,
          multiplier: 1,
          constant: 0
        ),
        NSLayoutConstraint(
          item: visualEffectView,
          attribute: .leading,
          relatedBy: .equal,
          toItem: containerView,
          attribute: .leading,
          multiplier: 1,
          constant: 0
        ),
        NSLayoutConstraint(
          item: visualEffectView,
          attribute: .trailing,
          relatedBy: .equal,
          toItem: containerView,
          attribute: .trailing,
          multiplier: 1,
          constant: 0
        ),
        NSLayoutConstraint(
          item: visualEffectView,
          attribute: .bottom,
          relatedBy: .equal,
          toItem: containerView,
          attribute: .bottom,
          multiplier: 1,
          constant: 0
        ),
      ]
      containerView.addConstraints(visualConstraints)
    }

    // 添加候選窗口內容視圖
    compositionView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(compositionView)
    let compositionConstraints = [
      NSLayoutConstraint(
        item: compositionView,
        attribute: .top,
        relatedBy: .equal,
        toItem: containerView,
        attribute: .top,
        multiplier: 1,
        constant: 0
      ),
      NSLayoutConstraint(
        item: compositionView,
        attribute: .leading,
        relatedBy: .equal,
        toItem: containerView,
        attribute: .leading,
        multiplier: 1,
        constant: 0
      ),
      NSLayoutConstraint(
        item: compositionView,
        attribute: .trailing,
        relatedBy: .equal,
        toItem: containerView,
        attribute: .trailing,
        multiplier: 1,
        constant: 0
      ),
      NSLayoutConstraint(
        item: compositionView,
        attribute: .bottom,
        relatedBy: .equal,
        toItem: containerView,
        attribute: .bottom,
        multiplier: 1,
        constant: 0
      ),
    ]
    containerView.addConstraints(compositionConstraints)

    panel.contentView = containerView

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

    let attributedString = compositionView.prepareAttributedString(from: state)
    compositionView.updateTextContent(attributedString, markedRange: state.u16MarkedRange)

    window?.orderFront(nil)
    set(windowOrigin: point)
  }

  public func hide() {
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
    self.messageTextField = NSTextField()
    super.init(frame: frameRect)
    setupView()
  }

  required init?(coder: NSCoder) {
    self.messageTextField = NSTextField()
    super.init(coder: coder)
    setupView()
  }

  // MARK: Internal

  var locale: String = ""
  var accent: NSColor = .accentColor

  var onSizeChanged: ((NSSize) -> ())?

  var isTypingDirectionVertical = false {
    didSet {
      if #unavailable(macOS 10.14) {
        isTypingDirectionVertical = false
      }
    }
  }

  var textShown: NSAttributedString = .init(string: "") {
    didSet {
      messageTextField.attributedStringValue = textShown
      adjustSize()
    }
  }

  func setupTheme(accent: NSColor?, locale: String) {
    self.locale = locale
    if let accent = accent {
      self.accent =
        (accent.alphaComponent == 1)
          ? accent
          .withAlphaComponent(PopupCompositionBuffer.bgOpacity) : accent
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
    messageTextField.backgroundColor = .clear
    messageTextField.textColor = textColor
  }

  func prepareAttributedString(
    from state: IMEStateProtocol
  )
    -> NSAttributedString {
    let attrString: NSMutableAttributedString = .init(string: state.displayedTextConverted)
    let attrPCBHeader: NSMutableAttributedString = .init(string: "　")

    let verticalAttributes: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: bufferFont(),
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

    let horizontalAttributes: [NSAttributedString.Key: Any] = [
      .font: bufferFont(),
      .kern: 0,
    ]

    if isTypingDirectionVertical {
      attrPCBHeader.setAttributes(
        verticalAttributes,
        range: NSRange(location: 0, length: attrPCBHeader.length)
      )
      attrString.setAttributes(
        verticalAttributes,
        range: NSRange(location: 0, length: attrString.length)
      )
    } else {
      attrPCBHeader.setAttributes(
        horizontalAttributes,
        range: NSRange(location: 0, length: attrPCBHeader.length)
      )
      attrString.setAttributes(
        horizontalAttributes,
        range: NSRange(location: 0, length: attrString.length)
      )
    }

    var markerAttributes: [NSAttributedString.Key: Any] {
      var result: [NSAttributedString.Key: Any] = [
        .kern: 0,
        .font: bufferFont(),
        .backgroundColor: markerColor,
        .foregroundColor: markerTextColor,
        .markedClauseSegment: 0,
      ]
      if isTypingDirectionVertical {
        result[.paragraphStyle] = verticalAttributes[.paragraphStyle]
        result[.verticalGlyphForm] = true
      }
      return result
    }

    // 在這個視窗內的下畫線繪製方法就得單獨設計了。
    attrString.setAttributes(
      markerAttributes,
      range: NSRange(
        location: state.u16MarkedRange.lowerBound,
        length: state.u16MarkedRange.upperBound - state.u16MarkedRange.lowerBound
      )
    )

    var cursorAttributes: [NSAttributedString.Key: Any] {
      let shadow = NSShadow()
      shadow.shadowBlurRadius = 4
      shadow.shadowOffset.height = 1
      shadow.shadowColor = .black
      var result: [NSAttributedString.Key: Any] = [
        .kern: -18,
        .font: bufferFont(),
        .foregroundColor: textColor,
        .shadow: shadow,
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
    }

    let attrCursor: NSAttributedString =
      isTypingDirectionVertical
        ? NSMutableAttributedString(string: "▔", attributes: cursorAttributes)
        : NSMutableAttributedString(string: "_", attributes: cursorAttributes)
    attrString.insert(attrCursor, at: state.u16Cursor)

    attrString.insert(attrPCBHeader, at: 0)
    attrString.insert(attrPCBHeader, at: attrString.length)

    return attrString
  }

  func updateTextContent(_ attributedString: NSAttributedString, markedRange: Range<Int>) {
    textShown = attributedString
    if let editor = messageTextField.currentEditor() {
      editor.selectedRange = NSRange(markedRange)
    }
  }

  // MARK: Private

  private let messageTextField: NSTextField

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
    .selectedMenuItemTextColor.withAlphaComponent(0.9)
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

  private func setupView() {
    wantsLayer = true
    shadow = .init()
    shadow?.shadowBlurRadius = 6
    shadow?.shadowColor = .black
    shadow?.shadowOffset = .zero

    if let layer = layer {
      layer.cornerRadius = 9
      layer.borderWidth = 1
      layer.masksToBounds = true
    }

    messageTextField.isEditable = false
    messageTextField.isSelectable = false
    messageTextField.isBezeled = false
    messageTextField.textColor = NSColor.selectedMenuItemTextColor
    messageTextField.drawsBackground = true
    messageTextField.backgroundColor = NSColor.clear
    messageTextField.font = .systemFont(ofSize: 18) // 不是最終值。
    addSubview(messageTextField)
  }

  private func bufferFont(size: CGFloat = 18) -> NSFont {
    let defaultResult: CTFont? = CTFontCreateUIFontForLanguage(.system, size, locale as CFString)
    return defaultResult ?? NSFont.systemFont(ofSize: size)
  }

  private func adjustSize() {
    messageTextField.sizeToFit()
    var rect = messageTextField.frame
    if isTypingDirectionVertical {
      rect = .init(x: rect.minX, y: rect.minY, width: rect.height * 1.5, height: rect.width)
    }
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x = ceil(NSFont.systemFontSize / 2)
    rect.origin.y = ceil(NSFont.systemFontSize / 2)
    if isTypingDirectionVertical {
      messageTextField.boundsRotation = 90
    } else {
      messageTextField.boundsRotation = 0
    }
    messageTextField.frame = rect

    // 通知外部尺寸變更
    onSizeChanged?(bigRect.size)
  }
}
