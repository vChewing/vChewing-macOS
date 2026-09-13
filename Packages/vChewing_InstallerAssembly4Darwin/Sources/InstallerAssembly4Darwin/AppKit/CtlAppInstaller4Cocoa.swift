// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

public final class CtlAppInstaller4Cocoa: NSWindowController, NSWindowDelegate {
  // MARK: Lifecycle

  public init() {
    let newWindow = NSWindow(
      contentRect: CGRect(
        x: 401, y: 295,
        width: VwrAppInstaller4Cocoa.meshWindowWidth,
        height: VwrAppInstaller4Cocoa.meshWindowHeight
      ),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered, defer: true
    )
    self.viewController = VwrAppInstaller4Cocoa()
    super.init(window: newWindow)
    autoreleasepool {
      viewController.loadView()
    }
  }

  required init?(coder: NSCoder) {
    self.viewController = VwrAppInstaller4Cocoa()
    super.init(coder: coder)
  }

  // MARK: Public

  public static var shared: CtlAppInstaller4Cocoa?

  override public func close() {
    autoreleasepool {
      super.close()
      if NSApplication.isAppleSilicon {
        Self.shared = nil
      }
    }
  }

  override public func windowDidLoad() {
    if #available(macOS 10.10, *) {
      windowDidLoadSinceYosemite()
    } else {
      windowDidLoad4Mavericks()
    }
  }

  @objc
  public static func show() {
    autoreleasepool {
      if shared == nil {
        let newInstance = CtlAppInstaller4Cocoa()
        shared = newInstance
      }
      guard let shared = shared, let sharedWindow = shared.window else { return }
      sharedWindow.delegate = shared
      if !sharedWindow.isVisible {
        shared.windowDidLoad()
      }
      sharedWindow.setPosition(vertical: .center, horizontal: .center, padding: 0)
      sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
      sharedWindow.level = .statusBar
      shared.showWindow(shared)
      NSApp.popup()
    }
  }

  public func windowDidLoad4Mavericks() {
    autoreleasepool {
      super.windowDidLoad()
      guard let window = window else { return }
      let theView = viewController.view
      window.contentView = theView
      window.setPosition(vertical: .center, horizontal: .center, padding: 0)
      window.setContentSize(.init(
        width: VwrAppInstaller4Cocoa.meshWindowWidth,
        height: VwrAppInstaller4Cocoa.meshWindowHeight
      ))
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
      window.title = mainWindowTitle
    }
  }

  @available(macOS 10.10, *)
  public func windowDidLoadSinceYosemite() {
    autoreleasepool {
      super.windowDidLoad()
      guard let window = window else { return }
      window.contentViewController = viewController
      window.setPosition(vertical: .center, horizontal: .center, padding: 0)
      window.setContentSize(.init(
        width: VwrAppInstaller4Cocoa.meshWindowWidth,
        height: VwrAppInstaller4Cocoa.meshWindowHeight
      ))
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
      window.titlebarAppearsTransparent = true
      window.title = mainWindowTitle
    }
  }

  // MARK: Private

  private var viewController: NSViewController
}
