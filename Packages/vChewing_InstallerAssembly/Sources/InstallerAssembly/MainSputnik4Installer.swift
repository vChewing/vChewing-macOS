// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

// MARK: - MainSputnik4Installer

/// macOS 10.9 ~ 10.14 不支援 Swift-based MainActor，但這個必須運行在 Main Thread 上。
public final class MainSputnik4Installer {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public func runNSApp(isLegacyDistro: Bool? = nil) {
    if let isLegacyDistro {
      AppInstallerDelegate.shared.isLegacyDistro = isLegacyDistro
    }
    if #available(macOS 12, *), !AppInstallerDelegate.shared.isLegacyDistro {
      // Legacy: preserve original behavior
      NSApplication.shared.delegate = AppInstallerDelegate.shared
      CtlAppInstaller4SwiftUI.show()
      NSApplication.shared.setValue(
        CtlAppInstaller4SwiftUI.shared?.window,
        forKey: "mainWindow"
      )
      NSApp.mainMenu = AppInstallerDelegate.shared.buildNSAppMainMenu()
      _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    } else {
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
