// Copyright (c) 2021 and onwards Weizhong Yang (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

private protocol NotifierWindowDelegate: AnyObject {
	func windowDidBecomeClicked(_ window: NotifierWindow)
}

private class NotifierWindow: NSWindow {
	weak var clickDelegate: NotifierWindowDelegate?

	override func mouseDown(with _: NSEvent) {
		clickDelegate?.windowDidBecomeClicked(self)
	}
}

private let kWindowWidth: CGFloat = 213.0
private let kWindowHeight: CGFloat = 60.0

public class NotifierController: NSWindowController, NotifierWindowDelegate {
	private var messageTextField: NSTextField

	private var message: String = "" {
		didSet {
			let paraStyle = NSMutableParagraphStyle()
			paraStyle.setParagraphStyle(NSParagraphStyle.default)
			paraStyle.alignment = .center
			let attr: [NSAttributedString.Key: AnyObject] = [
				.foregroundColor: foregroundColor,
				.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular)),
				.paragraphStyle: paraStyle,
			]
			let attrString = NSAttributedString(string: message, attributes: attr)
			messageTextField.attributedStringValue = attrString
			let width = window?.frame.width ?? kWindowWidth
			let rect = attrString.boundingRect(
				with: NSSize(width: width, height: 1600), options: .usesLineFragmentOrigin
			)
			let height = rect.height
			let x = messageTextField.frame.origin.x
			let y = ((window?.frame.height ?? kWindowHeight) - height) / 2
			let newFrame = NSRect(x: x, y: y, width: width, height: height)
			messageTextField.frame = newFrame
		}
	}

	private var shouldStay: Bool = false
	private var backgroundColor: NSColor = .textBackgroundColor {
		didSet {
			window?.backgroundColor = backgroundColor
		}
	}

	private var foregroundColor: NSColor = .controlTextColor {
		didSet {
			messageTextField.textColor = foregroundColor
		}
	}

	private var waitTimer: Timer?
	private var fadeTimer: Timer?

	private static var instanceCount = 0
	private static var lastLocation = NSPoint.zero

	@objc public static func notify(message: String, stay: Bool = false) {
		let controller = NotifierController()
		controller.message = message
		controller.shouldStay = stay
		controller.show()
	}

	private static func increaseInstanceCount() {
		instanceCount += 1
	}

	private static func decreaseInstanceCount() {
		instanceCount -= 1
		if instanceCount < 0 {
			instanceCount = 0
		}
	}

	private init() {
		let screenRect = NSScreen.main?.visibleFrame ?? NSRect.zero
		let contentRect = NSRect(x: 0, y: 0, width: kWindowWidth, height: kWindowHeight)
		var windowRect = contentRect
		windowRect.origin.x = screenRect.maxX - windowRect.width - 10
		windowRect.origin.y = screenRect.maxY - windowRect.height - 10
		let styleMask: NSWindow.StyleMask = [.fullSizeContentView, .titled]

		let transparentVisualEffect = NSVisualEffectView()
		transparentVisualEffect.blendingMode = .behindWindow
		transparentVisualEffect.state = .active

		let panel = NotifierWindow(
			contentRect: windowRect, styleMask: styleMask, backing: .buffered, defer: false
		)
		panel.contentView = transparentVisualEffect
		panel.isMovableByWindowBackground = true
		panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel))
		panel.hasShadow = true
		panel.backgroundColor = backgroundColor
		panel.title = ""
		panel.titlebarAppearsTransparent = true
		panel.titleVisibility = .hidden
		panel.showsToolbarButton = false
		panel.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
		panel.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
		panel.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
		panel.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true

		messageTextField = NSTextField()
		messageTextField.frame = contentRect
		messageTextField.isEditable = false
		messageTextField.isSelectable = false
		messageTextField.isBezeled = false
		messageTextField.textColor = foregroundColor
		messageTextField.drawsBackground = false
		messageTextField.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
		panel.contentView?.addSubview(messageTextField)

		super.init(window: panel)

		panel.clickDelegate = self
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func show() {
		func setStartLocation() {
			if NotifierController.instanceCount == 0 {
				return
			}
			let lastLocation = NotifierController.lastLocation
			let screenRect = NSScreen.main?.visibleFrame ?? NSRect.zero
			var windowRect = window?.frame ?? NSRect.zero
			windowRect.origin.x = lastLocation.x
			windowRect.origin.y = lastLocation.y - 10 - windowRect.height

			if windowRect.origin.y < screenRect.minY {
				return
			}

			window?.setFrame(windowRect, display: true)
		}

		func moveIn() {
			let afterRect = window?.frame ?? NSRect.zero
			NotifierController.lastLocation = afterRect.origin
			var beforeRect = afterRect
			beforeRect.origin.y += 10
			window?.setFrame(beforeRect, display: true)
			window?.orderFront(self)
			window?.setFrame(afterRect, display: true, animate: true)
		}

		setStartLocation()
		moveIn()
		NotifierController.increaseInstanceCount()
		waitTimer = Timer.scheduledTimer(
			timeInterval: shouldStay ? 5 : 1, target: self, selector: #selector(fadeOut),
			userInfo: nil,
			repeats: false
		)
	}

	@objc private func doFadeOut(_: Timer) {
		let opacity = window?.alphaValue ?? 0
		if opacity <= 0 {
			close()
		} else {
			window?.alphaValue = opacity - 0.2
		}
	}

	@objc private func fadeOut() {
		waitTimer?.invalidate()
		waitTimer = nil
		NotifierController.decreaseInstanceCount()
		fadeTimer = Timer.scheduledTimer(
			timeInterval: 0.01, target: self, selector: #selector(doFadeOut(_:)), userInfo: nil,
			repeats: true
		)
	}

	override public func close() {
		waitTimer?.invalidate()
		waitTimer = nil
		fadeTimer?.invalidate()
		fadeTimer = nil
		super.close()
	}

	fileprivate func windowDidBecomeClicked(_: NotifierWindow) {
		fadeOut()
	}
}
