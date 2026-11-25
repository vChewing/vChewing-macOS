// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LibVanguard

// 讀穿快取（P355）對「另一實例之寫入」之失效（P364 之客訴排查）。

// MARK: - SwiftExtensionDefaultsExternalWriteTests

extension LibVanguardTestsRoot {
  /// P364 期間之疑慮：設定界面以 `@AppStorage` 直寫 `UserDefaults`（另一個實例），
  /// 若讀穿快取未隨之失效，`PrefMgr` 便會一直讀到舊值。本用例把該路徑釘住。
  @Suite("SwiftExtensionDefaultsExternalWriteTests")
  struct SwiftExtensionDefaultsExternalWriteTests {
    /// Linux／Windows 之 Foundation 不為「另一實例之寫入」派 `didChangeNotification`，故
    /// 「跨實例失效」這條路徑僅 Darwin 可測；本專案之生產目標亦只有 macOS。
    nonisolated private static let crossInstanceInvalidationIsTestable: Bool = {
      #if os(macOS)
        return true
      #else
        return false
      #endif
    }()

    @Test(.enabled(if: crossInstanceInvalidationIsTestable))
    func writeThroughAnotherInstanceInvalidatesTheCache() {
      let suiteName = "org.atelierInmu.vChewing.P364ExternalWriteTests"
      guard let writerDefaults = UserDefaults(suiteName: suiteName),
            let readerDefaults = UserDefaults(suiteName: suiteName)
      else {
        Issue.record("無法建立臨時 UserDefaults suite。")
        return
      }
      writerDefaults.removePersistentDomain(forName: suiteName)
      defer { writerDefaults.removePersistentDomain(forName: suiteName) }

      let store = UserDefaultsStore(readerDefaults)
      writerDefaults.set(0, forKey: "KeyboardParser4Zhuyin")
      #expect(store.integer(forKey: "KeyboardParser4Zhuyin") == 0) // 進快取
      #expect(store.cachedKeyCount > 0)

      // 「另一個實例」之寫入（`@AppStorage` 即此形）。
      writerDefaults.set(4, forKey: "KeyboardParser4Zhuyin")
      #expect(store.integer(forKey: "KeyboardParser4Zhuyin") == 4)
    }


    /// 平台中立之對照：`DefaultsStore` 自身之寫入必定失效（不依賴 Foundation 之通知）。
    @Test
    func writeThroughTheStoreItselfInvalidatesTheCache() {
      let suiteName = "org.atelierInmu.vChewing.P364OwnWriteTests"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("無法建立臨時 UserDefaults suite。")
        return
      }
      defaults.removePersistentDomain(forName: suiteName)
      defer { defaults.removePersistentDomain(forName: suiteName) }

      let store = UserDefaultsStore(defaults)
      store.set(0, forKey: "KeyboardParser4Zhuyin")
      #expect(store.integer(forKey: "KeyboardParser4Zhuyin") == 0) // 進快取
      #expect(store.cachedKeyCount > 0)

      store.set(4, forKey: "KeyboardParser4Zhuyin")
      #expect(store.integer(forKey: "KeyboardParser4Zhuyin") == 4) // 自身寫入即失效
    }
  }
}
