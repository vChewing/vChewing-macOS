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

public class TooltipController: NSWindowController {
	static var backgroundColor = NSColor.windowBackgroundColor
	static var textColor = NSColor.windowBackgroundColor
	private var messageTextField: NSTextField
	private var tooltip: String = "" {
		didSet {
			messageTextField.stringValue = tooltip
			adjustSize()
		}
	}

	public init() {
		let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
		let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
		let panel = NSPanel(
			contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
		panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 1)
		panel.hasShadow = true

		messageTextField = NSTextField()
		messageTextField.isEditable = false
		messageTextField.isSelectable = false
		messageTextField.isBezeled = false
		messageTextField.textColor = TooltipController.textColor
		messageTextField.drawsBackground = true
		messageTextField.backgroundColor = TooltipController.backgroundColor
		messageTextField.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
		panel.contentView?.addSubview(messageTextField)

		super.init(window: panel)
	}

	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc(showTooltip:atPoint:)
	public func show(tooltip: String, at point: NSPoint) {
		messageTextField.textColor = TooltipController.textColor
		messageTextField.backgroundColor = TooltipController.backgroundColor
		self.tooltip = tooltip
		window?.orderFront(nil)
		set(windowLocation: point)
	}

	@objc
	public func hide() {
		window?.orderOut(nil)
	}

	private func set(windowLocation windowTopLeftPoint: NSPoint) {

		var adjustedPoint = windowTopLeftPoint
		adjustedPoint.y -= 5

		var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
		for screen in NSScreen.screens {
			let frame = screen.visibleFrame
			if windowTopLeftPoint.x >= frame.minX && windowTopLeftPoint.x <= frame.maxX
				&& windowTopLeftPoint.y >= frame.minY && windowTopLeftPoint.y <= frame.maxY
			{
				screenFrame = frame
				break
			}
		}

		let windowSize = window?.frame.size ?? NSSize.zero

		// bottom beneath the screen?
		if adjustedPoint.y - windowSize.height < screenFrame.minY {
			adjustedPoint.y = screenFrame.minY + windowSize.height
		}

		// top over the screen?
		if adjustedPoint.y >= screenFrame.maxY {
			adjustedPoint.y = screenFrame.maxY - 1.0
		}

		// right
		if adjustedPoint.x + windowSize.width >= screenFrame.maxX {
			adjustedPoint.x = screenFrame.maxX - windowSize.width
		}

		// left
		if adjustedPoint.x < screenFrame.minX {
			adjustedPoint.x = screenFrame.minX
		}

		window?.setFrameTopLeftPoint(adjustedPoint)

	}

	private func adjustSize() {
		let attrString = messageTextField.attributedStringValue
		var rect = attrString.boundingRect(
			with: NSSize(width: 1600.0, height: 1600.0), options: .usesLineFragmentOrigin)
		rect.size.width += 10
		messageTextField.frame = rect
		window?.setFrame(rect, display: true)
	}

}
