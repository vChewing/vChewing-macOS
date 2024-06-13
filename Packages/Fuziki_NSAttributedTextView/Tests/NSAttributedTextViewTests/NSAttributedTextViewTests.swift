// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
@testable import NSAttributedTextView
import OSFrameworkImpl
import Shared
import XCTest

// MARK: - MainAssemblyTests

class MainAssemblyTests: XCTestCase {
  func testView() throws {
    let testCtl: testController = .init()
    var rect = testCtl.attrView.shrinkFrame()
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += ceil(NSFont.systemFontSize / 2)
    rect.origin.y += ceil(NSFont.systemFontSize / 2)
    testCtl.attrView.frame = rect
    testCtl.window?.setFrame(bigRect, display: true)
    testCtl.window?.orderFront(nil)
    testCtl.attrView.draw(testCtl.attrView.frame)
    testCtl.window?.setIsVisible(true)
  }
}

// MARK: - testController

class testController: NSWindowController {
  // MARK: Lifecycle

  init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.clear
    panel.isOpaque = false
    panel.isMovable = false
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.cornerRadius = 7
    panel.contentView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    self.attrView = NSAttributedTextView()
    attrView.backgroundColor = NSColor.clear
    attrView.textColor = NSColor.textColor
    attrView.needsDisplay = true
    attrView.text = "114514"
    panel.contentView?.addSubview(attrView)
    super.init(window: panel)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  var attrView: NSAttributedTextView
}
