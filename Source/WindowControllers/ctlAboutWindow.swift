// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

class ctlAboutWindow: NSWindowController {
  @IBOutlet var appVersionLabel: NSTextField!
  @IBOutlet var appCopyrightLabel: NSTextField!
  @IBOutlet var appEULAContent: NSTextView!

  override func windowDidLoad() {
    super.windowDidLoad()

    window?.standardWindowButton(.closeButton)?.isHidden = true
    window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window?.standardWindowButton(.zoomButton)?.isHidden = true
    guard
      let installingVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String]
        as? String,
      let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    else {
      return
    }
    if let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"]
      as? String
    {
      appCopyrightLabel.stringValue = copyrightLabel
    }
    if let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String {
      appEULAContent.string = eulaContent
    }
    appVersionLabel.stringValue = "\(versionString) Build \(installingVersion)"
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
