// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import MainAssembly

class CtlAboutWindow: NSWindowController {
  @IBOutlet var appVersionLabel: NSTextField!
  @IBOutlet var appCopyrightLabel: NSTextField!
  @IBOutlet var appEULAContent: NSTextView!

  public static var shared: CtlAboutWindow?

  static func show() {
    if shared == nil { shared = CtlAboutWindow(windowNibName: "frmAboutWindow") }
    guard let shared = shared, let sharedWindow = shared.window else { return }
    sharedWindow.setPosition(vertical: .top, horizontal: .left, padding: 20)
    sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    sharedWindow.titlebarAppearsTransparent = true
    shared.showWindow(shared)
    NSApp.popup()
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .left, padding: 20)
    window?.standardWindowButton(.closeButton)?.isHidden = true
    window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window?.standardWindowButton(.zoomButton)?.isHidden = true
    if let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"]
      as? String
    {
      appCopyrightLabel.stringValue = copyrightLabel
    }
    if let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String,
       let eulaContentUpstream = Bundle.main.infoDictionary?["CFUpstreamEULAContent"] as? String
    {
      appEULAContent.string = eulaContent + "\n" + eulaContentUpstream
    }
    appVersionLabel.stringValue = IMEApp.appVersionLabel
  }

  @IBAction func btnBugReport(_: NSButton) {
    if let url = URL(string: "https://vchewing.github.io/BUGREPORT.html") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func btnWebsite(_: NSButton) {
    if let url = URL(string: "https://vchewing.github.io/") {
      NSWorkspace.shared.open(url)
    }
  }
}
