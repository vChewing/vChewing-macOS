// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class Notifier: NSWindowController {
  public static func notify(message: String) {
    Self.message = message
  }

  static var message: String = "" {
    didSet {
      if !Self.message.isEmpty {
        Self.message = Notifier(message).blankValue
      }
    }
  }

  // MARK: - Private Declarations

  private static var instanceStack: [Notifier] = []
  private let blankValue = ""

  @discardableResult private init(_ message: String) {
    let rawMessage = message.replacingOccurrences(of: "\n", with: "")
    guard let screenRect = NSScreen.main?.visibleFrame, !rawMessage.isEmpty else {
      super.init(window: nil)
      return
    }
    let kLargeFontSize: Double = 17
    let kSmallFontSize: Double = 15
    let messageArray = message.components(separatedBy: "\n")

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .center
    let attrTitle: [NSAttributedString.Key: AnyObject] = [
      .foregroundColor: NSColor.controlTextColor,
      .font: NSFont.boldSystemFont(ofSize: kLargeFontSize),
      .paragraphStyle: paraStyle,
    ]
    let attrString = NSMutableAttributedString(string: messageArray[0], attributes: attrTitle)
    let attrAlt: [NSAttributedString.Key: AnyObject] = [
      .foregroundColor: NSColor.secondaryLabelColor,
      .font: NSFont.systemFont(ofSize: kSmallFontSize),
      .paragraphStyle: paraStyle,
    ]
    let additionalString = messageArray.count > 1 ? "\n\(messageArray[1])" : ""
    let attrStringAlt = NSMutableAttributedString(string: additionalString, attributes: attrAlt)
    attrString.insert(attrStringAlt, at: attrString.length)

    let textRect: NSRect = attrString.boundingRect(
      with: NSSize(width: 1600.0, height: 1600.0), options: [.usesLineFragmentOrigin]
    )
    let windowWidth = Double(4) * kLargeFontSize + textRect.width
    let contentRect = NSRect(x: 0, y: 0, width: windowWidth, height: 60.0)
    var windowRect = contentRect
    windowRect.origin.x = screenRect.maxX - windowRect.width - 10
    windowRect.origin.y = screenRect.maxY - windowRect.height - 10
    let styleMask: NSWindow.StyleMask = [.borderless]

    let transparentVisualEffect = NSVisualEffectView()
    transparentVisualEffect.blendingMode = .behindWindow
    transparentVisualEffect.state = .active

    let theWindow = NSWindow(
      contentRect: windowRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    theWindow.contentView = transparentVisualEffect
    theWindow.isMovableByWindowBackground = true
    theWindow.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel))
    theWindow.hasShadow = true
    theWindow.backgroundColor = .textBackgroundColor
    theWindow.title = ""
    theWindow.titlebarAppearsTransparent = true
    theWindow.titleVisibility = .hidden
    theWindow.showsToolbarButton = false
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.isReleasedWhenClosed = true
    theWindow.isMovable = false

    let lblMessage = NSTextField()
    lblMessage.attributedStringValue = attrString
    lblMessage.drawsBackground = false
    lblMessage.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
    lblMessage.frame = contentRect
    lblMessage.isBezeled = false
    lblMessage.isEditable = false
    lblMessage.isSelectable = false
    lblMessage.textColor = .controlTextColor
    theWindow.contentView?.addSubview(lblMessage)

    let x = lblMessage.frame.origin.x
    let y = ((theWindow.frame.height) - textRect.height) / 1.9
    let newFrame = NSRect(x: x, y: y, width: theWindow.frame.width, height: textRect.height)
    lblMessage.frame = newFrame

    super.init(window: theWindow)
    display()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func close() {
    super.close()
  }
}

// MARK: - Private Functions

extension Notifier {
  private func shiftExistingWindowPositions() {
    guard let window = window, !Self.instanceStack.isEmpty else { return }
    for theInstanceWindow in Self.instanceStack.compactMap(\.window) {
      var theOrigin = theInstanceWindow.frame
      theOrigin.origin.y -= (10 + window.frame.height)
      theInstanceWindow.setFrame(theOrigin, display: true)
    }
  }

  private func fadeIn() {
    guard let window = window else { return }
    let afterRect = window.frame
    var beforeRect = afterRect
    beforeRect.origin.x -= 20
    window.setFrame(beforeRect, display: true)
    window.orderFront(self)
    window.setFrame(afterRect, display: true, animate: true)
  }

  private func display() {
    let existingInstanceArray = Self.instanceStack.compactMap(\.window)
    if !existingInstanceArray.isEmpty {
      existingInstanceArray.forEach {
        $0.alphaValue -= 0.1
        $0.contentView?.subviews.forEach { $0.alphaValue *= 0.5 }
      }
    }
    shiftExistingWindowPositions()
    fadeIn()
    Self.instanceStack.insert(self, at: 0)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.close()
      Self.instanceStack.removeAll(where: { $0.window == nil })
    }
  }
}
