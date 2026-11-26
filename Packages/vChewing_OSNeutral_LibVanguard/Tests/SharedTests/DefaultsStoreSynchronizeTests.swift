// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import Shared

// MARK: - DefaultsStoreSynchronizeTests

/// 驗證 `doSynchronize()` 之契約：必須是協定要求（否則 `any DefaultsStore` 會走預設）、
/// 且不得改動值與快取。
@Suite("DefaultsStoreSynchronize")
final class DefaultsStoreSynchronizeTests {
  // MARK: Internal

  @Test
  func doSynchronizeIsDispatchedThroughExistential() {
    let spy = SpyDefaultsStore()
    let existential: any DefaultsStore = spy
    existential.doSynchronize()
    #expect(spy.didSynchronize)
  }

  @Test
  func doSynchronizeKeepsValuesAndCacheIntact() {
    let suiteName = "org.atelierInmu.vChewing.DefaultsStoreSynchronizeTests"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("無法建立臨時 UserDefaults suite。")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UserDefaultsStore(defaults)
    store.set("alpha", forKey: "kSyncKey")
    #expect(store.string(forKey: "kSyncKey") == "alpha")
    let cachedBefore = store.cachedKeyCount

    store.doSynchronize()

    #expect(store.string(forKey: "kSyncKey") == "alpha")
    #expect(store.cachedKeyCount == cachedBefore)
  }

  /// T3：非 Darwin 之落盤。上游 `UserDefaults.set` 只把鍵標為 dirty，`doSynchronize()` 才寫檔；
  /// 檔名為 `<suite>.plist`，Linux 落 `$XDG_CONFIG_HOME`（預設 `~/.config`）、Windows 落
  /// `%LOCALAPPDATA%`（Core Foundation 之 `CFKnownLocations`）。查無檔即明示失敗，不略過。
  @Test(.enabled(if: nonDarwinFlushIsTestable))
  func doSynchronizeFlushesOnNonDarwin() throws {
    let suiteName = "org.atelierInmu.vChewing.DefaultsStoreSynchronizeFlushTests"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("無法建立臨時 UserDefaults suite。")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UserDefaultsStore(defaults)
    store.set("alpha", forKey: "kFlushKey")
    store.doSynchronize()

    guard let fileURL = Self.platformPreferencesFileURL(forSuite: suiteName) else {
      Issue.record("本平臺之偏好目錄環境變數不存在（XDG_CONFIG_HOME／LOCALAPPDATA）。")
      return
    }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      let directory = fileURL.deletingLastPathComponent().path
      let listing = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
      Issue.record("偏好檔不存在：\(fileURL.path)；目錄內容：\(listing)")
      return
    }
    let data = try Data(contentsOf: fileURL)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let dictionary = plist as? [String: Any] else {
      Issue.record("偏好檔之根節點不是字典：\(fileURL.path)")
      return
    }
    #expect((dictionary["kFlushKey"] as? String) == "alpha")
  }

  // MARK: Private

  nonisolated private static let nonDarwinFlushIsTestable: Bool = {
    #if canImport(Darwin)
      return false
    #else
      return true
    #endif
  }()

  private static func platformPreferencesFileURL(forSuite suite: String) -> URL? {
    #if os(Windows)
      guard let base = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else { return nil }
      return URL(fileURLWithPath: base, isDirectory: true).appendingPathComponent("\(suite).plist")
    #else
      let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        ?? (NSHomeDirectory() + "/.config")
      return URL(fileURLWithPath: base, isDirectory: true).appendingPathComponent("\(suite).plist")
    #endif
  }
}

// MARK: - SpyDefaultsStore

/// 僅供 T1：以**協定要求**之覆寫證明 `any DefaultsStore` 上之派送不是靜態的。
private final class SpyDefaultsStore: DefaultsStore, @unchecked Sendable {
  // MARK: Internal

  nonisolated(unsafe) var didSynchronize = false

  nonisolated func object(forKey key: String) -> Any? { storage[key] }

  nonisolated func set(_ value: Any?, forKey key: String) {
    if let value {
      storage[key] = value
    } else {
      storage[key] = nil
    }
  }

  nonisolated func removeObject(forKey key: String) {
    storage[key] = nil
  }

  nonisolated func doSynchronize() {
    didSynchronize = true
  }

  // MARK: Private

  nonisolated(unsafe) private var storage: [String: Any] = [:]
}
