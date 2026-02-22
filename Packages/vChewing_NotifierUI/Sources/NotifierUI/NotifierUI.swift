// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import SwiftExtension

// MARK: - Notifier

public final class Notifier: NSWindowController {
  // MARK: Lifecycle

  @discardableResult
  private init(_ message: String) {
    self.currentMessage = message
    let rawMessage = message.replacingOccurrences(of: "\n", with: "")
    let isDuplicated: Bool = {
      if let firstInstanceExisted = Self.instanceSet.firstNotifier {
        return message == firstInstanceExisted.currentMessage && firstInstanceExisted.isNew
      }
      return false
    }()
    guard let screenRect = NSScreen.main?.visibleFrame, !rawMessage.isEmpty, !isDuplicated else {
      super.init(window: nil)
      return
    }
    // 剔除溢出的副本，讓 Swift 自動回收之。
    while Self.instanceSet.count > 3 {
      if let instanceToRemove = Self.instanceSet.lastNotifier {
        instanceToRemove.close()
        Self.instanceSet.remove(instanceToRemove)
      }
    }
    // 正式進入處理環節。
    defer {
      // 先讓新通知標記自此開始過 0.3 秒自動變為 false。
      asyncOnMain(after: 0.3) {
        self.isNew = false
      }
    }
    let kLargeFontSize: CGFloat = 17
    let kSmallFontSize: CGFloat = 15
    let horizontalPadding: CGFloat = 12
    let extraRightSpacing: CGFloat = 64
    let iconSize: CGFloat = 64
    let gapBetweenLabelAndIcon: CGFloat = 6
    let messageArray = message.components(separatedBy: "\n")

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .left
    let attrTitle: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .foregroundColor: NSColor.controlTextColor,
      .font: NSFont.boldSystemFont(ofSize: kLargeFontSize),
      .paragraphStyle: paraStyle,
    ]
    let attrString = NSMutableAttributedString(string: messageArray[0], attributes: attrTitle)
    let foregroundColor: NSColor = {
      if #available(macOS 10.10, *) {
        return NSColor.secondaryLabelColor
      }
      return NSColor.controlTextColor
    }()
    let attrAlt: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .foregroundColor: foregroundColor,
      .font: NSFont.systemFont(ofSize: kSmallFontSize),
      .paragraphStyle: paraStyle,
    ]
    let additionalString = messageArray.count > 1 ? "\n\(messageArray[1])" : ""
    let attrStringAlt = NSMutableAttributedString(string: additionalString, attributes: attrAlt)
    attrString.insert(attrStringAlt, at: attrString.length)

    let lblMessage = NSTextField()
    lblMessage.attributedStringValue = attrString
    lblMessage.drawsBackground = false
    lblMessage.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
    lblMessage.isBezeled = false
    lblMessage.isEditable = false
    lblMessage.isSelectable = false
    lblMessage.textColor = .controlTextColor
    lblMessage.sizeToFit()

    let textWH = lblMessage.frame
    let windowWidth = textWH.width + horizontalPadding * 2 + extraRightSpacing
    let contentRect = CGRect(x: 0, y: 0, width: windowWidth, height: 60.0)
    var windowRect = contentRect
    windowRect.origin.x = screenRect.maxX - windowRect.width - 20
    windowRect.origin.y = screenRect.maxY - ceil(2.5 * windowRect.height) - 10
    let styleMask: NSWindow.StyleMask = [.borderless]

    let transparentVisualEffect: NSView = {
      if #available(macOS 10.10, *) {
        let transparentVisualEffect = NSVisualEffectView()
        transparentVisualEffect.blendingMode = .behindWindow
        transparentVisualEffect.state = .active
        return transparentVisualEffect
      }
      return .init()
    }()

    let theWindow = NSWindow(
      contentRect: windowRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    theWindow.contentView = transparentVisualEffect
    theWindow.isMovableByWindowBackground = true
    theWindow.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)))
    theWindow.hasShadow = true
    theWindow.backgroundColor = .textBackgroundColor
    theWindow.title = ""
    if #available(macOS 10.10, *) {
      theWindow.titlebarAppearsTransparent = true
      theWindow.titleVisibility = .hidden
    }
    // 強制 Notifier 視窗使用 Dark Mode（僅在 macOS 10.14+ 生效）。
    if #available(macOS 10.14, *) {
      theWindow.appearance = Self.currentNSAppearance
      if let visual = transparentVisualEffect as? NSVisualEffectView {
        visual.material = .underWindowBackground
        visual.appearance = Self.currentNSAppearance
      }
    }
    theWindow.showsToolbarButton = false
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.isReleasedWhenClosed = true
    theWindow.isMovable = false
    theWindow.contentView?.addSubview(lblMessage)

    let y = ((theWindow.frame.height) - textWH.height) / 1.9
    let newOrigin = CGPoint(x: horizontalPadding, y: y)
    lblMessage.frame.origin = newOrigin

    if let appIcon = NSApplication.shared.applicationIconImage {
      let iconView = NSImageView()
      iconView.image = appIcon
      iconView.imageScaling = .scaleAxesIndependently
      iconView.alphaValue = 0.5
      iconView.wantsLayer = true
      let iconFrame = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
      iconView.frame = iconFrame
      let iconX = CGFloat(windowWidth - iconSize)
      let iconY = ((theWindow.frame.height) - CGFloat(iconSize)) / 2.0
      iconView.frame.origin = CGPoint(x: iconX, y: iconY)
      theWindow.contentView?.addSubview(iconView)
      let maxLabelWidth = CGFloat(windowWidth - iconSize - gapBetweenLabelAndIcon - horizontalPadding)
      if lblMessage.frame.width > maxLabelWidth {
        lblMessage.frame.size.width = maxLabelWidth
        if let cell = lblMessage.cell as? NSTextFieldCell {
          cell.wraps = true
          cell.truncatesLastVisibleLine = false
          cell.lineBreakMode = .byWordWrapping
        }
        lblMessage.sizeToFit()
        let newY = ((theWindow.frame.height) - lblMessage.frame.height) / 1.9
        lblMessage.frame.origin.y = newY
      }
    }

    super.init(window: theWindow)
    display()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public static func notify(message: String) {
    mainSync { Self.message = message }
  }

  // MARK: Internal

  static var message: String = "" {
    didSet {
      if !Self.message.isEmpty {
        Self.message = Notifier(message).blankValue
      }
    }
  }

  // MARK: Private

  // MARK: - Private Declarations

  private static var instanceSet: NSMutableOrderedSet = .init()
  private static let prefs = PrefMgr.sharedSansDidSetOps

  private static var currentNSAppearance: NSAppearance? {
    if #available(macOS 10.14, *) {
      // minus-zero: Bright, 0: nil, rest: Dark.
      switch prefs.specifiedNotifyUIColorScheme {
      case ..<0: return NSAppearance(named: .aqua)
      case 0: return nil
      default: return NSAppearance(named: .darkAqua)
      }
    }
    return nil
  }

  private var currentMessage: String // 承載該副本在初期化時被傳入的訊息內容。
  private var isNew = true // 新通知標記。

  private let blankValue = ""
}

// MARK: - Private Functions

extension Notifier {
  private func shiftExistingWindowPositions() {
    guard let window = window else { return }
    Self.instanceSet.arrayOfWindows.forEach { theInstanceWindow in
      var theOrigin = theInstanceWindow.frame
      theOrigin.origin.y -= (10 + window.frame.height)
      theInstanceWindow.setFrame(theOrigin, display: true)
    }
  }

  private func performDisplayLifetime() {
    guard let window = window else { return }
    Self.instanceSet.insert(self, at: 0)
    var afterRect = window.frame
    var beforeRect = afterRect
    beforeRect.origin.x -= 20
    window.setFrame(beforeRect, display: true)
    window.orderFront(self)
    window.setFrame(afterRect, display: true, animate: true)
    asyncOnMain(after: 1.3) {
      beforeRect = window.frame
      afterRect = window.frame
      afterRect.origin.x += 20
      window.setFrame(afterRect, display: true, animate: true)
      self.close()
      Self.instanceSet.remove(self)
    }
  }

  private func display() {
    Self.instanceSet.arrayOfWindows.enumerated().forEach { id, theInstance in
      theInstance.alphaValue *= Double(pow(0.4, Double(id + 1)))
      theInstance.contentView?.subviews.forEach {
        $0.alphaValue *= Double(pow(0.6, Double(id + 1)))
      }
    }
    shiftExistingWindowPositions()
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      this.performDisplayLifetime()
    }
  }
}

extension NSMutableOrderedSet {
  fileprivate var arrayOfWindows: [NSWindow] { compactMap { ($0 as? Notifier)?.window } }

  fileprivate var firstNotifier: Notifier? {
    for neta in self { if let result = neta as? Notifier { return result } }
    return nil
  }

  fileprivate var lastNotifier: Notifier? {
    for neta in reversed { if let result = neta as? Notifier { return result } }
    return nil
  }
}
