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
  // MARK: Internal

  var body: some Scene {
    WindowGroup {
      makeGradient()
        .frame(minWidth: 1_000, maxWidth: .infinity, minHeight: 630, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
          Text("vChewing Input Method")
            .font(.system(size: 30))
            .italic().bold()
            .padding()
            .foregroundStyle(Color.white)
            .shadow(color: .black, radius: 0, x: 5, y: 5)
        }
        .overlay {
          MainView()
            .shadow(color: .black, radius: 3, x: 0, y: 0)
        }
        .onAppear {
          NSWindow.allowsAutomaticWindowTabbing = false
          NSApp.windows.forEach { window in
            window.titlebarAppearsTransparent = true
            window.setContentSize(.init(width: 1_000, height: 630))
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

  // MARK: Private

  @ViewBuilder
  private func makeGradient() -> some View {
    if #available(macOS 15.0, *) {
      MeshGradient(
        width: 2,
        height: 2,
        points: [
          [0, 0], [1, 0],
          [0, 1], [1, 1],
        ],
        colors: [
          Color(red: 28 / 255, green: 46 / 255, blue: 61 / 255),
          Color(red: 61 / 255, green: 98 / 255, blue: 126 / 255),
          Color(red: 145 / 255, green: 189 / 255, blue: 224 / 255),
          Color(red: 193 / 255, green: 207 / 255, blue: 217 / 255),
        ]
      )
    } else {
      LinearGradient(
        gradient: Gradient(
          colors: [
            Color(red: 28 / 255, green: 46 / 255, blue: 61 / 255),
            Color(red: 145 / 255, green: 189 / 255, blue: 224 / 255),
          ]
        ),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}
