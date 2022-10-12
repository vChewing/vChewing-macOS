// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_: Notification) {
    // Insert code here to initialize your application
  }

  func applicationWillTerminate(_: Notification) {
    // Insert code here to tear down your application
  }

  func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
    .terminateNow
  }

  // Call the New About Window
  @IBAction func about(_: Any) {
    CtlAboutWindow.show()
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
