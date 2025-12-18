// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

@available(macOS 12, *)
public final class CtlAppInstaller4SwiftUI: NSWindowController, NSWindowDelegate {
  // MARK: Lifecycle

  public init() {
    let newWindow = NSWindow(
      contentRect: CGRect(x: 401, y: 295, width: 1_000, height: 630),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered, defer: true
    )
    self.viewController = NSHostingController(rootView: Self.makeHostingView())
    super.init(window: newWindow)
    autoreleasepool {
      viewController.loadView()
    }
  }

  required init?(coder: NSCoder) {
    self.viewController = NSHostingController(rootView: Self.makeHostingView())
    super.init(coder: coder)
  }

  // MARK: Public

  public static var shared: CtlAppInstaller4SwiftUI?

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
      window.contentViewController = viewController
      let size = viewController.view.fittingSize
      window.setPosition(vertical: .center, horizontal: .center, padding: 0)
      window.setFrame(.init(origin: window.frame.origin, size: size), display: true)
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
      window.titlebarAppearsTransparent = true
      window.title = mainWindowTitle
    }
  }

  @objc
  public static func show() {
    autoreleasepool {
      if shared == nil {
        let newInstance = CtlAppInstaller4SwiftUI()
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

  // MARK: Private

  private var viewController: NSViewController

  @ViewBuilder
  private static func makeHostingView() -> some View {
    VwrAppInstaller4SwiftUI()
      .modifier(
        GradientViewWrapper(titleText: "vChewing Input Method")
      )
      .frame(minWidth: 1_000, idealWidth: 1_000, minHeight: 630, idealHeight: 630)
      .onAppear {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.windows.forEach { w in
          w.titlebarAppearsTransparent = true
          w.setContentSize(NSSize(width: 1_000, height: 630))
          w.standardWindowButton(.closeButton)?.isHidden = true
          w.standardWindowButton(.miniaturizeButton)?.isHidden = true
          w.standardWindowButton(.zoomButton)?.isHidden = true
          w.styleMask.remove(.resizable)
          w.orderFront(nil)
        }
      }
      .onDisappear {
        NSApp.terminate(nil)
      }
  }
}
