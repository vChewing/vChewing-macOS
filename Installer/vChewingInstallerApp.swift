// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

@main
struct vChewingInstallerApp: App {
  var body: some Scene {
    WindowGroup {
      MainView()
        .onAppear {
          NSWindow.allowsAutomaticWindowTabbing = false
          NSApp.windows.forEach { window in
            window.titlebarAppearsTransparent = true
            window.setContentSize(.init(width: 533, height: 386))
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.styleMask.remove(.resizable)
            window.orderFront(self)
          }
        }
        .onDisappear {
          NSApp.terminate(self)
        }
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(replacing: .appInfo) {}
      CommandGroup(replacing: .help) {}
      CommandGroup(replacing: .appVisibility) {}
      CommandGroup(replacing: .systemServices) {}
    }
  }
}
