// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - InstallerApp4SwiftUI

@available(macOS 12, *)
struct InstallerApp4SwiftUI: App {
  var body: some Scene {
    WindowGroup {
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
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(replacing: .appInfo) {}
      CommandGroup(replacing: .help) {}
      CommandGroup(replacing: .appVisibility) {}
      CommandGroup(replacing: .systemServices) {}
    }
  }
}
