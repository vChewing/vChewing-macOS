// (c) 2021 and onwards Fuziki (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// Ref: https://qiita.com/fuziki/items/b31055a69330a3ce55a5
// Modified by The vChewing Project in order to use it with AppKit.

import AppKit
import CocoaExtension
import SwiftUI

@available(macOS 10.15, *)
public struct VText: NSViewRepresentable {
  public var text: String?

  public func makeNSView(context _: Context) -> NSAttributedTextView {
    let nsView = NSAttributedTextView()
    nsView.direction = .vertical
    nsView.text = text
    return nsView
  }

  public func updateNSView(_ nsView: NSAttributedTextView, context _: Context) {
    nsView.text = text
  }
}

@available(macOS 10.15, *)
public struct HText: NSViewRepresentable {
  public var text: String?

  public func makeNSView(context _: Context) -> NSAttributedTextView {
    let nsView = NSAttributedTextView()
    nsView.direction = .horizontal
    nsView.text = text
    return nsView
  }

  public func updateNSView(_ nsView: NSAttributedTextView, context _: Context) {
    nsView.text = text
  }
}

public class NSAttributedTextView: NSView {
  private static let sharedTextField: NSTextField = {
    let result = NSTextField()
    result.isSelectable = false
    result.isEditable = false
    result.isBordered = false
    result.backgroundColor = .clear
    result.allowsEditingTextAttributes = false
    result.preferredMaxLayoutWidth = result.frame.width
    return result
  }()

  public enum writingDirection: String {
    case horizontal
    case vertical
    case verticalReversed
  }

  public var direction: writingDirection = .horizontal
  public var fontSize: Double = NSFont.systemFontSize {
    didSet {
      attributes[.font] = NSFont.systemFont(ofSize: fontSize)
    }
  }

  public var textColor: NSColor = .textColor {
    didSet {
      attributes[.foregroundColor] = textColor
    }
  }

  public func attributedStringValue(areaCalculation: Bool = false) -> NSAttributedString {
    var newAttributes = attributes
    let isVertical: Bool = !(direction == .horizontal)
    newAttributes[.verticalGlyphForm] = isVertical
    let newStyle: NSMutableParagraphStyle = newAttributes[.paragraphStyle] as! NSMutableParagraphStyle
    if #available(macOS 10.13, *) {
      newStyle.lineSpacing = isVertical ? (fontSize / -2) : fontSize * 0.1
      newStyle.maximumLineHeight = fontSize * 1.1
      newStyle.minimumLineHeight = fontSize * 1.1
    }
    newAttributes[.paragraphStyle] = newStyle
    var text: String = text ?? text ?? ""
    if areaCalculation {
      text = text.replacingOccurrences(
        of: "[^\n]",
        with: "國",
        options: .regularExpression,
        range: text.range(of: text)
      )
    }
    let attributedText = NSMutableAttributedString(string: text, attributes: newAttributes)
    return attributedText
  }

  public var backgroundColor: NSColor = .controlBackgroundColor

  public var attributes: [NSAttributedString.Key: Any] = [
    .verticalGlyphForm: true,
    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
    .foregroundColor: NSColor.textColor,
    .paragraphStyle: {
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .left
      return paragraphStyle
    }(),
  ]
  public var text: String? { didSet { ctFrame = nil } }
  private var ctFrame: CTFrame?
  public private(set) var currentRect: NSRect?

  @discardableResult public func shrinkFrame() -> NSRect {
    let attrString: NSAttributedString = {
      switch direction {
      case .horizontal: return attributedStringValue()
      default: return attributedStringValue(areaCalculation: true)
      }
    }()
    Self.sharedTextField.attributedStringValue = attrString
    Self.sharedTextField.sizeToFit()
    var textWH = Self.sharedTextField.fittingSize
    if direction != .horizontal {
      textWH.height = max(ceil(1.03 * textWH.height), ceil(NSFont.systemFontSize * 1.1))
      textWH = .init(width: textWH.height, height: textWH.width)
    }
    return .init(origin: .zero, size: textWH)
  }

  override public func draw(_ rect: CGRect) {
    let context = NSGraphicsContext.current?.cgContext
    guard let context = context else { return }
    let setter = CTFramesetterCreateWithAttributedString(attributedStringValue())
    let path = CGPath(rect: rect, transform: nil)
    let theCTFrameProgression: CTFrameProgression = {
      switch direction {
      case .horizontal: return CTFrameProgression.topToBottom
      case .vertical: return CTFrameProgression.rightToLeft
      case .verticalReversed: return CTFrameProgression.leftToRight
      }
    }()
    let frameAttrs: CFDictionary =
      [
        kCTFrameProgressionAttributeName: theCTFrameProgression.rawValue,
      ] as CFDictionary
    let newFrame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, frameAttrs)
    ctFrame = newFrame
    backgroundColor.setFill()
    let bgPath: NSBezierPath = .init(roundedRect: rect, xRadius: 0, yRadius: 0)
    bgPath.fill()
    currentRect = rect
    CTFrameDraw(newFrame, context)
  }
}

public class NSAttributedTooltipTextView: NSAttributedTextView {
  override public func attributedStringValue(areaCalculation: Bool = false) -> NSAttributedString {
    var newAttributes = attributes
    let isVertical: Bool = !(direction == .horizontal)
    newAttributes[.verticalGlyphForm] = isVertical
    let newStyle: NSMutableParagraphStyle = newAttributes[.paragraphStyle] as! NSMutableParagraphStyle
    if #available(macOS 10.13, *) {
      newStyle.lineSpacing = isVertical ? (fontSize / -2) : fontSize * 0.1
      newStyle.maximumLineHeight = fontSize * 1.1
      newStyle.minimumLineHeight = fontSize * 1.1
    }
    newAttributes[.paragraphStyle] = newStyle
    var text: String = text ?? text ?? ""
    if !(direction == .horizontal) {
      text = text.replacingOccurrences(of: "˙", with: "･")
      text = text.replacingOccurrences(of: "\u{A0}", with: "　")
      text = text.replacingOccurrences(of: "+", with: "")
      text = text.replacingOccurrences(of: "Shift", with: "⇧")
      text = text.replacingOccurrences(of: "Control", with: "⌃")
      text = text.replacingOccurrences(of: "Enter", with: "⏎")
      text = text.replacingOccurrences(of: "Command", with: "⌘")
      text = text.replacingOccurrences(of: "Delete", with: "⌦")
      text = text.replacingOccurrences(of: "BackSpace", with: "⌫")
      text = text.replacingOccurrences(of: "Space", with: "␣")
      text = text.replacingOccurrences(of: "SHIFT", with: "⇧")
      text = text.replacingOccurrences(of: "CONTROL", with: "⌃")
      text = text.replacingOccurrences(of: "ENTER", with: "⏎")
      text = text.replacingOccurrences(of: "COMMAND", with: "⌘")
      text = text.replacingOccurrences(of: "DELETE", with: "⌦")
      text = text.replacingOccurrences(of: "BACKSPACE", with: "⌫")
      text = text.replacingOccurrences(of: "SPACE", with: "␣")
    }
    if areaCalculation {
      text = text.replacingOccurrences(
        of: "[^\n]",
        with: "國",
        options: .regularExpression,
        range: text.range(of: text)
      )
    }
    let attributedText = NSMutableAttributedString(string: text, attributes: newAttributes)
    return attributedText
  }
}
