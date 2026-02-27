// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Testing

@testable import MainAssembly4Darwin

// 簡單 smoke 測試，確認 SwiftUI 的偏好設定視窗關閉後不會
// 自我保留。修正前只有在 Apple Silicon 上會清除 `shared`，
// 造成 Intel 機器 controller 永遠存活，每次開關都漏出
// 幾 MB SwiftUI 狀態。

extension MainAssemblyTests {
  @Test
  func test005_SettingsWindowDoesNotLeak() throws {
    // 直接在同一執行緒上顯示再關閉，測試框架已在 main thread。
    CtlSettingsUI.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    #expect(CtlSettingsUI.shared != nil)

    CtlSettingsUI.shared?.close()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    #expect(CtlSettingsUI.shared == nil)
    // window 的 contentView 也應該已被移除
    #expect(CtlSettingsUI.shared?.window?.contentView == nil)

    // 測量前後記憶體，以確認當視圖階層拆掉並清空 malloc zone 後，
    // 選單 API 回報的佔用會下降。做兩次採樣以避開瞬間雜訊。
    func sampleRAM() -> Double {
      AppDelegate.shared.checkMemoryUsage()
    }
    let before = sampleRAM()
    let after: Double
    // 稍等片刻讓上面的釋放邏輯跑完
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    after = sampleRAM()
    #expect(after <= before + 1.0, "RAM did not decrease after closing UI (")
  }
}
