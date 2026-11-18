// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LibVanguard

// 歸入本測試目標唯一根 suite（見 `LibVanguardTests_Root.swift`）。
extension LibVanguardTestsRoot {
  /// `UserDefaultsStore` 之讀穿快取（P355）。
  ///
  /// 一顆按鍵在真行程裡要讀數十次偏好，每次 `UserDefaults.object(forKey:)` 都是一趟
  /// CFPreferences 查詢；快取把同一輪的重複讀取收斂。本套房守住三件事：非 `_` 鍵會被快取、
  /// `_` 開頭之診斷鍵永不快取、以及兩路失效（本物件之寫入、外部改動之通知）。
  @Suite("SwiftExtensionDefaultsCacheTests")
  struct SwiftExtensionDefaultsCacheTests {
    // MARK: Internal

    @Test
    func nonUnderscoreKeyIsReadOnce() {
      withStore { store, defaults in
        defaults.set("alpha", forKey: "kCachedKey")
        #expect(store.object(forKey: "kCachedKey") as? String == "alpha")
        #expect(store.object(forKey: "kCachedKey") as? String == "alpha")
        #expect(store.underlyingReadCount == 1)
        #expect(store.cachedKeyCount == 1)
      }
    }

    @Test
    func underscoreKeyIsNeverCached() {
      withStore { store, defaults in
        defaults.set(true, forKey: "_DebugMode")
        #expect(store.bool(forKey: "_DebugMode"))
        #expect(store.bool(forKey: "_DebugMode"))
        #expect(store.underlyingReadCount == 2)
        #expect(store.cachedKeyCount == 0)
      }
    }

    @Test
    func writeThroughTheStoreInvalidatesTheKey() {
      withStore { store, defaults in
        defaults.set("alpha", forKey: "kWritten")
        #expect(store.string(forKey: "kWritten") == "alpha")
        store.set("beta", forKey: "kWritten")
        #expect(store.string(forKey: "kWritten") == "beta")
        #expect(store.underlyingReadCount == 2)
      }
    }

    @Test
    func externalChangeNotificationClearsTheCache() {
      withStore { store, defaults in
        defaults.set("alpha", forKey: "kExternal")
        #expect(store.string(forKey: "kExternal") == "alpha")
        #expect(store.cachedKeyCount == 1)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        #expect(store.cachedKeyCount == 0)
        #expect(store.string(forKey: "kExternal") == "alpha")
        #expect(store.underlyingReadCount == 2)
      }
    }

    // MARK: Private

    private func withStore(_ body: (UserDefaultsStore, UserDefaults) -> ()) {
      let suiteName = "org.atelierInmu.vChewing.LibVanguard.DefaultsCacheTests"
      let defaults = UserDefaults(suiteName: suiteName) ?? .standard
      defaults.removePersistentDomain(forName: suiteName)
      defer { defaults.removePersistentDomain(forName: suiteName) }
      body(UserDefaultsStore(defaults), defaults)
    }
  }
}
