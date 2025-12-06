// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

public final class CtlAboutUI: NSWindowController, NSWindowDelegate {
  // MARK: Lifecycle

  public init(forceLegacy: Bool = false) {
    self.useLegacyView = forceLegacy
    let newWindow = NSWindow(
      contentRect: CGRect(x: 401, y: 295, width: 577, height: 568),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered, defer: true
    )
    super.init(window: newWindow)
    guard #available(macOS 12, *), !useLegacyView else {
      self.viewController = VwrAboutCocoa()
      autoreleasepool {
        viewController?.loadView()
      }
      return
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

  public static var shared: CtlAboutUI?

  override public func close() {
    autoreleasepool {
      super.close()
      if NSApplication.isAppleSilicon {
        Self.shared = nil
      }
    }
  }

  override public func windowDidLoad() {
    autoreleasepool {
      super.windowDidLoad()
      guard let window = window else { return }
      if #available(macOS 12, *), !useLegacyView {
        windowDidLoadSwiftUI()
        return
      }
      let theViewController = viewController ?? VwrAboutCocoa()
      viewController = theViewController
      window.contentViewController = viewController
      let size = theViewController.view.fittingSize
      window.setPosition(vertical: .top, horizontal: .left, padding: 20)
      window.setFrame(.init(origin: window.frame.origin, size: size), display: true)
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
      if #available(macOS 10.10, *) {
        window.titlebarAppearsTransparent = true
      }
      window.title = "i18n:AboutWindow.ABOUT_APP_TITLE_FULL"
        .localized + " (v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")))"
    }
  }

  @objc
  public static func show() {
    autoreleasepool {
      let forceLegacy = NSEvent.modifierFlags == .option
      if shared == nil {
        let newInstance = CtlAboutUI(forceLegacy: forceLegacy)
        shared = newInstance
      }
      guard let shared = shared, let sharedWindow = shared.window else { return }
      shared.useLegacyView = forceLegacy
      sharedWindow.delegate = shared
      if !sharedWindow.isVisible {
        shared.windowDidLoad()
      }
      sharedWindow.setPosition(vertical: .top, horizontal: .left, padding: 20)
      sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
      sharedWindow.level = .statusBar
      shared.showWindow(shared)
      NSApp.popup()
    }
  }

  // MARK: Internal

  var useLegacyView: Bool = false

  // MARK: Private

  private var viewController: NSViewController?

  @available(macOS 12, *)
  private func windowDidLoadSwiftUI() {
    autoreleasepool {
      window?.setPosition(vertical: .top, horizontal: .left, padding: 20)
      window?.standardWindowButton(.closeButton)?.isHidden = true
      window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window?.standardWindowButton(.zoomButton)?.isHidden = true
      window?.titlebarAppearsTransparent = true
      window?.contentView = NSHostingView(
        rootView: VwrAboutUI()
          .fixedSize(horizontal: true, vertical: false)
          .ignoresSafeArea()
      )
      window?.title = "i18n:AboutWindow.ABOUT_APP_TITLE_FULL"
        .localized + " (v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")))"
    }
  }
}
