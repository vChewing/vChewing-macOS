// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import SwiftUI

// MARK: - MainSputnik4Installer

/// macOS 10.9 ~ 10.14 不支援 Swift-based MainActor，但這個必須運行在 Main Thread 上。
public final class MainSputnik4Installer {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  // `async` 所需的 concurrency 執行期起於 macOS 10.15，故標註其可用性下限（呼叫端為 12+ 的 SwiftUI 安裝程式）。
  @available(macOS 10.15, *)
  public static func asyncInit() async -> MainSputnik4Installer {
    MainSputnik4Installer()
  }

  public func runNSApp(isLegacyDistro: Bool? = nil) {
    if let isLegacyDistro {
      AppInstallerDelegate.shared.isLegacyDistro = isLegacyDistro
    }
    // SwiftUI 版安裝程式僅存在於 6.2 側；5.10 側一律走 AppKit 版——與 `vChewing-OSX-Legacy` 的安裝程式一致
    // （該倉無 SwiftUI 版，其 `main.swift` 即直接呼叫 `runNSApp(isLegacyDistro: true)`）。
    #if compiler(>=6.2)
      let isOptPressed = NSEvent.modifierFlags.intersection(
        .deviceIndependentFlagsMask
      ).contains(.command)
      let newInstaller = !AppInstallerDelegate.shared.isLegacyDistro && !isOptPressed
      if #available(macOS 12, *), newInstaller {
        InstallerApp4SwiftUI.main()
        return
      }
    #endif
    NSApplication.shared.delegate = AppInstallerDelegate.shared
    CtlAppInstaller4Cocoa.show()
    NSApplication.shared.setValue(
      CtlAppInstaller4Cocoa.shared?.window,
      forKey: "mainWindow"
    )
    NSApp.mainMenu = AppInstallerDelegate.shared.buildNSAppMainMenu()
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }
}

// MARK: - AppInstallerDelegate

@objc(AppDelegate)
final class AppInstallerDelegate: NSObject, NSApplicationDelegate {
  // MARK: Internal

  static let shared = AppInstallerDelegate()

  var isLegacyDistro = isMainBundleMarkedAsLegacy()

  /// 以此取代 `MainMenu.xib`。
  func buildNSAppMainMenu() -> NSMenu {
    NSMenu(title: "MainMenu").appendItems {
      NSMenu.buildSubMenu(verbatim: "vChewing") {
        NSMenu.Item("Quit")?
          .act(#selector(NSApplication.terminate(_:)))
          .hotkey("q", mask: [.command])
      }

      NSMenu.buildSubMenu(verbatim: "Edit") {
        NSMenu.Item("Undo")?
          .act(#selector(UndoManager.undo))
          .hotkey("z", mask: [.command])
        NSMenu.Item("Redo")?
          .act(#selector(UndoManager.redo))
          .hotkey("Z", mask: [.command, .shift])
        NSMenu.Item.separator()
        NSMenu.Item("Cut")?
          .act(#selector(NSText.cut(_:)))
          .hotkey("x", mask: [.command])
        NSMenu.Item("Copy")?
          .act(#selector(NSText.copy(_:)))
          .hotkey("c", mask: [.command])
        NSMenu.Item("Paste")?
          .act(#selector(NSText.paste(_:)))
          .hotkey("v", mask: [.command])
        NSMenu.Item("Select All")?
          .act(#selector(NSText.selectAll(_:)))
          .hotkey("a", mask: [.command])
        NSMenu.Item.separator()
      }
    }
  }

  // MARK: Private

  private static func isMainBundleMarkedAsLegacy() -> Bool {
    Bundle.main.bundleIdentifier?.lowercased().contains("legacy") ?? false
  }
}
