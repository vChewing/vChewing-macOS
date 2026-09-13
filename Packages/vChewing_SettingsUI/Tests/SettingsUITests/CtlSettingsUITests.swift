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
/// 原位於 MainAssembly4Darwin 的單元測試靶（該處以 `AppDelegate.shared.checkMemoryUsage()`
/// 另作主體 RAM 取樣）；移入本套件後僅保留視窗生命週期斷言——RAM 取樣屬宿主 App 的
/// 記憶體遙測，非本套件可觀測之範圍。
@Suite(.serialized)
final class CtlSettingsUITests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.SettingsUI.UnitTests")
    UserDefaults.pendingUnitTests = true
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
}
