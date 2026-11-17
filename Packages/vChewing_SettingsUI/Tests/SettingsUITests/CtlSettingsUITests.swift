// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Shared
import SwiftExtension
import Testing

@testable import SettingsUI

// MARK: - CtlSettingsUITests

/// SwiftUI 偏好設定視窗的生命週期測試：確認關閉後不留殘存 controller 與 contentView。
///
/// 原位於 MainAssembly4Darwin 的單元測試目標（該處以 `AppDelegate.shared.checkMemoryUsage()`
/// 另作主體 RAM 取樣）；移入本套件後僅保留視窗生命週期斷言——RAM 取樣屬宿主 App 的
/// 記憶體遙測，非本套件可觀測之範圍。
@Suite(.serialized)
final class CtlSettingsUITests {
  // MARK: Lifecycle

  init() {
    OSUtils.defaultsStore = InMemoryDefaultsStore()
    OSUtils.isRunningUnitTests = true
    UserDef.resetAll()
  }

  // MARK: Internal

  @Test
  func testSettingsWindowDoesNotLeak() throws {
    // `CtlSettingsUI` 僅在 macOS 14 及以上供應；較舊系統沒有這個視窗可測。
    guard #available(macOS 14, *) else { return }
    // 直接在同一執行緒上顯示再關閉，測試框架已在 main thread。
    CtlSettingsUI.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    #expect(CtlSettingsUI.shared != nil)

    CtlSettingsUI.shared?.close()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    #expect(CtlSettingsUI.shared == nil)
    // window 的 contentView 也應該已被移除。
    #expect(CtlSettingsUI.shared?.window?.contentView == nil)
  }

  /// 視窗所宣告之寬度不得短於內容之實需寬。
  ///
  /// 內容之實需寬即 `NavigationSplitView` 之 `NSSplitView` 的 fitting 寬
  /// （側欄欄位 ＋ 分隔線 ＋ 表單最小寬）。macOS 26 之終末版本上，`NSHostingView`
  /// 不再把該值回報為視窗之 `contentMinSize`，視窗遂停在種子寬 758，而內容仍以 790 排版
  /// ⇒ `Form` 左右被裁切。此測試用例即釘住「宣告寬 ≥ 實需寬」這條不變量。
  @Test
  func testSettingsWindowIsWideEnoughForItsColumns() throws {
    guard #available(macOS 14, *) else { return }
    CtlSettingsUI.show()
    defer { CtlSettingsUI.shared?.close() }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    let window = try #require(CtlSettingsUI.shared?.window)
    let contentView = try #require(window.contentView)
    let splitView = try #require(Self.firstSplitView(in: contentView))
    let requiredWidth = splitView.fittingSize.width

    #expect(requiredWidth > 0)
    #expect(requiredWidth <= CGFloat(CtlSettingsUI.windowWidth))
    #expect(requiredWidth <= window.frame.width)
    #expect(splitView.frame.width <= contentView.bounds.width)
  }

  // MARK: Private

  private static func firstSplitView(in view: NSView) -> NSSplitView? {
    if let splitView = view as? NSSplitView { return splitView }
    for subview in view.subviews {
      if let result = firstSplitView(in: subview) { return result }
    }
    return nil
  }
}
