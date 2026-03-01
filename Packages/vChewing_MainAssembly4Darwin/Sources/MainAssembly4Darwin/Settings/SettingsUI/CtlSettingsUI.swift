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
  // MARK: Lifecycle

  nonisolated deinit {
    #if DEBUG
      NSLog("[CtlSettingsUI] deinit called")
    #endif
  }

  public init() {
    super.init(
      window: .init(
        contentRect: CGRect(x: 401, y: 295, width: 590, height: Self.contentMaxHeight),
        styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
        backing: .buffered,
        defer: true
      )
    )
    window?.titlebarAppearsTransparent = false
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

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
    // 由於我們使用靜態 `shared` 變數保留 window controller，
    // 因此每次關閉都要把它清掉，無論 CPU 架構為何。
    // 另外必須把 contentView 從 window 抽離，
    // 否則它會被 NSWindow 仍然持有，導致記憶體不會即時回收。
    autoreleasepool {
      // 先行斷開 delegate 與內容，避免循環引用
      window?.delegate = nil
      // 此舉抽離 contentView。
      window?.contentView = nil
      super.close()
      Self.shared = nil
    }
  }

  @objc
  public static func show() {
    // 避免在先前已關閉視窗的 controller 上誤觸復活；
    // `shared` 會在 `close()` 或下方的 `windowWillClose(_:)`
    // 中被清空。
    autoreleasepool {
      if shared == nil {
        let newInstance = CtlSettingsUI()
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

  // MARK: - NSWindowDelegate helpers

  public func windowWillClose(_ notification: Notification) {
    // 使用者按紅色關閉按鈕或 ⌘W 時走的是這條路徑，
    // 不會觸發 NSWindowController.close() override，
    // 因此必須在此處做同等的清理。
    window?.delegate = nil
    window?.contentView = nil
    Self.shared = nil
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
      .multilineTextAlignment(.leading)
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
