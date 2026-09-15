// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬（legacy 倉庫無對位模組可繼承，其安裝程式僅有 AppKit 版）；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」，整段僅限 6.2+，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - InstallerApp4SwiftUI

  @available(macOS 12, *)
  struct InstallerApp4SwiftUI: App {
    var body: some Scene {
      WindowGroup {
        VwrAppInstaller4SwiftUI()
          .modifier(
            GradientViewWrapper(titleText: LocalizedStringKey("i18n:Installer.VChewingInputMethod"))
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

#endif
