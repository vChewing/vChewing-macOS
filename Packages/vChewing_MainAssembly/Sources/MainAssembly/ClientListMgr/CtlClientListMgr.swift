// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

public class CtlClientListMgr: NSWindowController {
  // MARK: Lifecycle

  public init() {
    super.init(
      window: .init(
        contentRect: CGRect(x: 401, y: 295, width: 770, height: 335),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: true
      )
    )
    autoreleasepool {
      viewController.loadView()
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

  public static var shared: CtlClientListMgr?

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
      let view = viewController.view
      window?.contentView = view
      if let window = window {
        var frame = window.frame
        frame.size = view.fittingSize
        window.setFrame(frame, display: true)
      }
      window?.setPosition(vertical: .center, horizontal: .right, padding: 20)
    }
  }

  public static func show() {
    autoreleasepool {
      if shared == nil {
        shared = CtlClientListMgr()
      }
      guard let shared = shared, let sharedWindow = shared.window else { return }
      if !sharedWindow.isVisible {
        shared.windowDidLoad()
      }
      sharedWindow.setPosition(vertical: .center, horizontal: .right, padding: 20)
      sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
      sharedWindow.title = "Client Manager".localized
      sharedWindow.level = .statusBar
      if #available(macOS 10.10, *) {
        sharedWindow.titlebarAppearsTransparent = true
      }
      shared.showWindow(shared)
      NSApp.popup()
    }
  }

  // MARK: Internal

  let viewController = VwrClientListMgr()
}
