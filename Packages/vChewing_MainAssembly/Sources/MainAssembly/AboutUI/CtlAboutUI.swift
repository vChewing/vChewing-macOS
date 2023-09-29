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
public class CtlAboutUI: NSWindowController, NSWindowDelegate {
  public static var shared: CtlAboutUI?

  public static func show() {
    if shared == nil {
      let newWindow = NSWindow(
        contentRect: CGRect(x: 401, y: 295, width: 577, height: 568),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered, defer: true
      )
      let newInstance = CtlAboutUI(window: newWindow)
      shared = newInstance
    }
    guard let shared = shared, let sharedWindow = shared.window else { return }
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

  override public func windowDidLoad() {
    super.windowDidLoad()
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
    window?.title = "i18n:aboutWindow.ABOUT_APP_TITLE_FULL".localized + " (v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")))"
  }
}
