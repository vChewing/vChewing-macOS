// (c) 2021 and onwards Fuziki (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// Ref: https://qiita.com/fuziki/items/b31055a69330a3ce55a5
// Modified by The vChewing Project in order to use it with AppKit.

import Cocoa
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
  public enum writingDirection: String {
    case horizontal
    case vertical
    case verticalReversed
  }

  public var direction: writingDirection = .horizontal
  public var fontSize: CGFloat = NSFont.systemFontSize {
    didSet {
      attributes[.font] = NSFont.systemFont(ofSize: fontSize)
    }
  }

  public var textColor: NSColor = .textColor {
    didSet {
      attributes[.foregroundColor] = textColor
    }
  }

  public var attributedStringValue: NSAttributedString {
    var newAttributes = attributes
    let isVertical: Bool = !(direction == .horizontal)
    newAttributes[.verticalGlyphForm] = isVertical
    let lineHeight: CGFloat = isVertical ? fontSize * 0.8 : fontSize * 1.3
    let newStyle: NSMutableParagraphStyle = newAttributes[.paragraphStyle] as! NSMutableParagraphStyle
    newStyle.maximumLineHeight = lineHeight
    newStyle.minimumLineHeight = lineHeight
    newAttributes[.paragraphStyle] = newStyle
    let attributedText = NSMutableAttributedString(string: text ?? "", attributes: newAttributes)
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
  private(set) var currentRect: NSRect?

  override public func draw(_ rect: CGRect) {
    let context = NSGraphicsContext.current?.cgContext
    guard let context = context else { return }
    let setter = CTFramesetterCreateWithAttributedString(attributedStringValue)
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
        kCTFrameProgressionAttributeName: theCTFrameProgression.rawValue
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
