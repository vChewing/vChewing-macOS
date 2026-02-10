// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

private let kWindowTitleHeight: Double = 78

// MARK: - CtlSettingsUI

// InputMethodServerPreferencesWindowControllerClass 非必需。

@available(macOS 14, *)
public final class CtlSettingsUI: NSWindowController, NSWindowDelegate {
  public static var shared: CtlSettingsUI?

  override public func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)
    window?.contentView = NSHostingView(
      rootView: VwrSettingsUI()
        .ignoresSafeArea()
    )
    var preferencesTitleName = "vChewing Preferences…".i18n
    preferencesTitleName.removeLast()
    window?.title = preferencesTitleName
  }

  override public func close() {
    autoreleasepool {
      super.close()
      if NSApplication.isAppleSilicon {
        Self.shared = nil
      }
    }
  }

  @objc
  public static func show() {
    autoreleasepool {
      if shared == nil {
        let newWindow = NSWindow(
          contentRect: CGRect(x: 401, y: 295, width: 577, height: contentMaxHeight),
          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
          backing: .buffered, defer: true
        )
        newWindow.titlebarAppearsTransparent = false
        let newInstance = CtlSettingsUI(window: newWindow)
        shared = newInstance
      }
      guard let shared = shared, let sharedWindow = shared.window else { return }
      sharedWindow.delegate = shared
      if !sharedWindow.isVisible {
        shared.windowDidLoad()
      }
      sharedWindow.setPosition(vertical: .top, horizontal: .right, padding: 20)
      sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
      sharedWindow.level = .statusBar
      shared.showWindow(shared)
      NSApp.popup()
    }
  }
}

// MARK: - Shared Static Variables and Constants

@available(macOS 14, *)
extension CtlSettingsUI {
  public static let sentenceSeparator: String = {
    switch PrefMgr.shared.appleLanguages[0] {
    case "ja":
      return ""
    default:
      if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
        return ""
      } else {
        return " "
      }
    }
  }()

  public static let contentMaxHeight: Double = 560

  public static let formWidth: Double = {
    let delta: Double
    if #available(macOS 26, *) {
      delta = 20
    } else {
      delta = 0
    }
    switch PrefMgr.shared.appleLanguages[0] {
    case "ja":
      return 520 + delta
    default:
      if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
        return 500 + delta
      } else {
        return 580 + delta
      }
    }
  }()

  public static var isCJKInterface: Bool {
    PrefMgr.shared.appleLanguages[0].contains("zh-Han") || PrefMgr.shared.appleLanguages[0] == "ja"
  }
}

@available(macOS 10.15, *)
extension View {
  public func settingsDescription(maxWidth: CGFloat? = .infinity) -> some View {
    controlSize(.small)
      .frame(maxWidth: maxWidth, alignment: .leading)
      // TODO: Use `.foregroundStyle` when targeting macOS 12.
      .foregroundColor(.secondary)
  }
}

@available(macOS 10.15, *)
extension View {
  public func formStyled() -> some View {
    if #available(macOS 14, *) { return self.formStyle(.grouped) }
    return padding()
  }
}
