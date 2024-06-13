// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared

public class PopupCompositionBuffer: NSWindowController {
  // MARK: Lifecycle

  public init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 1)
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    self.messageTextField = NSTextField()
    messageTextField.isEditable = false
    messageTextField.isSelectable = false
    messageTextField.isBezeled = false
    messageTextField.textColor = NSColor.selectedMenuItemTextColor
    messageTextField.drawsBackground = true
    messageTextField.backgroundColor = NSColor.clear
    messageTextField.font = .systemFont(ofSize: 18) // 不是最終值。
    panel.contentView?.addSubview(messageTextField)
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
    Self.currentWindow = panel
    super.init(window: panel)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public var isTypingDirectionVertical = false {
    didSet {
      if #unavailable(macOS 10.14) {
        isTypingDirectionVertical = false
      }
    }
  }

  public func sync(accent: NSColor?, locale: String) {
    self.locale = locale
    if let accent = accent {
      self.accent = (accent.alphaComponent == 1) ? accent
        .withAlphaComponent(Self.bgOpacity) : accent
    } else {
      self.accent = themeColorCocoa
    }
    let themeColor = adjustedThemeColor
    window?.backgroundColor = .clear
    window?.contentView?.layer?.backgroundColor = themeColor.cgColor
    window?.contentView?.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
    messageTextField.backgroundColor = .clear
    messageTextField.textColor = textColor
  }

  public func show(state: IMEStateProtocol, at point: NSPoint) {
    if !state.hasComposition {
      hide()
      return
    }

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
        verticalAttributes, range: NSRange(location: 0, length: attrPCBHeader.length)
      )
      attrString.setAttributes(
        verticalAttributes, range: NSRange(location: 0, length: attrString.length)
      )
    } else {
      attrPCBHeader.setAttributes(
        horizontalAttributes, range: NSRange(location: 0, length: attrPCBHeader.length)
      )
      attrString.setAttributes(
        horizontalAttributes, range: NSRange(location: 0, length: attrString.length)
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

    textShown = attrString
    if let editor = messageTextField.currentEditor() {
      editor.selectedRange = NSRange(state.u16MarkedRange)
    }
    window?.orderFront(nil)
    set(windowOrigin: point)
  }

  public func hide() {
    window?.orderOut(nil)
  }

  // MARK: Internal

  var themeColorCocoa: NSColor {
    switch locale {
    case "zh-Hans": return .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255,
                                 alpha: Self.bgOpacity)
    case "zh-Hant": return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255,
                                 alpha: Self.bgOpacity)
    case "ja": return .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: Self.bgOpacity)
    default: return .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: Self.bgOpacity)
    }
  }

  // MARK: Private

  private static let bgOpacity: CGFloat = 0.8

  private static var currentWindow: NSWindow? {
    willSet {
      currentWindow?.orderOut(nil)
    }
  }

  private var messageTextField: NSTextField
  private var accent: NSColor = .accentColor

  private var locale: String = ""

  private var textShown: NSAttributedString = .init(string: "") {
    didSet {
      messageTextField.attributedStringValue = textShown
      adjustSize()
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

  private func bufferFont(size: CGFloat = 18) -> NSFont {
    let defaultResult: CTFont? = CTFontCreateUIFontForLanguage(.system, size, locale as CFString)
    return defaultResult ?? NSFont.systemFont(ofSize: size)
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

    adjustedPoint.y = min(
      max(adjustedPoint.y, screenFrame.minY + windowSize.height),
      screenFrame.maxY
    )
    adjustedPoint.x = min(
      max(adjustedPoint.x, screenFrame.minX),
      screenFrame.maxX - windowSize.width
    )

    if isTypingDirectionVertical {
      window.setFrameTopLeftPoint(adjustedPoint)
    } else {
      window.setFrameOrigin(adjustedPoint)
    }
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
    window?.setFrame(bigRect, display: true)
  }
}
