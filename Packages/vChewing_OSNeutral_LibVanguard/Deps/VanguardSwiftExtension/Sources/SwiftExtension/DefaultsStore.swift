// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - DefaultsStore

/// 偏好設定之可注入儲存後端。
///
/// 原先 `AppProperty` 直接以「行程級可變全域」為容器，單元測試只能藉「換掉具名 suite」間接隔離；
/// 代價是每個測試套件各據一顆**落在磁碟上、且跨行程共用**的 plist，故單元測試實際上在讀寫
/// 使用者真機之偏好檔。本協定把「容器」析出為可注入之存在型別，使測試得以改用完全不觸及
/// 磁碟之 `InMemoryDefaultsStore`，且各套件可各持一份實例。
///
/// - Important: 本協定要求 `Sendable`：它會被 `AppProperty`（本身 `Sendable`）以**儲存屬性**
///   持有，故每個實作都得分別以 `@unchecked Sendable` 自行擔保執行緒安全（`UserDefaultsStore`
///   之 `UserDefaults` 本身即執行緒安全，`InMemoryDefaultsStore` 內部則以 `NSMutex` 收斂）。
///   所有成員一律 `nonisolated`，故可自任意隔離域存取。
public protocol DefaultsStore: AnyObject, Sendable {
  /// 讀取指定鍵之原始值；鍵不存在時回傳 `nil`。
  nonisolated func object(forKey key: String) -> Any?

  /// 寫入指定鍵之值。
  nonisolated func set(_ value: Any?, forKey key: String)

  /// 移除指定鍵。
  nonisolated func removeObject(forKey key: String)

  /// 依平臺與系統版本決定是否刻意同步；預設 no-op。
  ///
  /// - Important: 本方法必須是**協定要求**，不可只放協定擴充：`any DefaultsStore` 上之
  ///   extension-only 方法係靜態派送，實作端之覆寫永遠不會被呼叫。
  nonisolated func doSynchronize()
}

extension DefaultsStore {
  /// 以布林解讀指定鍵；非布林或不存在時回傳 `false`（與 `UserDefaults.bool(forKey:)` 同旨）。
  nonisolated public func bool(forKey key: String) -> Bool {
    (object(forKey: key) as? Bool) ?? false
  }

  /// 以字串解讀指定鍵；非字串或不存在時回傳 `nil`。
  nonisolated public func string(forKey key: String) -> String? {
    object(forKey: key) as? String
  }

  /// 以字串陣列解讀指定鍵；型別不符或不存在時回傳 `nil`。
  nonisolated public func stringArray(forKey key: String) -> [String]? {
    object(forKey: key) as? [String]
  }

  /// 以整數解讀指定鍵；不存在時回傳 `0`（與 `UserDefaults.integer(forKey:)` 同旨）。
  nonisolated public func integer(forKey key: String) -> Int {
    (object(forKey: key) as? NSNumber)?.intValue ?? 0
  }

  /// 以浮點數解讀指定鍵；不存在時回傳 `0`（與 `UserDefaults.double(forKey:)` 同旨）。
  nonisolated public func double(forKey key: String) -> Double {
    (object(forKey: key) as? NSNumber)?.doubleValue ?? 0
  }

  /// 以任意陣列解讀指定鍵；型別不符或不存在時回傳 `nil`。
  nonisolated public func array(forKey key: String) -> [Any]? {
    object(forKey: key) as? [Any]
  }

  /// 預設 no-op：記憶體容器等無落盤之實作即沿用。
  nonisolated public func doSynchronize() {}
}

// MARK: - UserDefaultsStore

/// `DefaultsStore` 之 `UserDefaults` 後端——生產環境之唯一實作。
///
/// - Note: **讀取有快取**（P355）。每一顆按鍵在真行程裡要讀數十次偏好，而每次
///   `UserDefaults.object(forKey:)` 都是一趟 CFPreferences 查詢（實測含 `geteuid`／`__persona`
///   一類系統呼叫）。讀穿快取把同一顆鍵的同一輪重複讀取收斂為一次：實測每鍵成本由
///   1.30–1.48 ms 降至 0.84–0.91 ms（約三成五）。
///
///   失效有三路：本物件之 `set`／`removeObject`、以及 `UserDefaults.didChangeNotification`
///   （涵蓋同行程其他 `UserDefaults` 實例與 cfprefsd 之外部改動）。
///
///   **例外**：**以 `_` 開頭之鍵一律不快取**——那是診斷開關與安全代理帳本之專屬命名空間
///   （`_DebugMode`、`_SecurityAgent_*` 等），P299 已立法「診斷開關須決策當下求值、不得快取」。
public final class UserDefaultsStore: DefaultsStore, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated public init(_ defaults: UserDefaults) {
    self.defaults = defaults
    self.observer = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      self?.invalidateAll()
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: Public

  /// `UserDefaults` 本身係執行緒安全（故本型別標 `@unchecked Sendable`），惟其型別未標 `Sendable`；
  /// 於預設 `MainActor` 隔離下不標 `nonisolated(unsafe)` 即會被收歸 `MainActor`，與本型別之
  /// `nonisolated` 成員相斥。
  nonisolated(unsafe) public let defaults: UserDefaults

  /// 當前快取之鍵數（供診斷與測試斷言；不快取 `_` 開頭者）。
  nonisolated public var cachedKeyCount: Int {
    cache.withLockRead { $0.count }
  }

  /// 自開始以來實際落到 `UserDefaults` 之讀取次數（供診斷與測試斷言）。
  nonisolated public var underlyingReadCount: Int {
    underlyingReads.withLockRead { $0 }
  }

  nonisolated public func object(forKey key: String) -> Any? {
    guard !key.hasPrefix("_") else {
      underlyingReads.withLock { $0 += 1 }
      return defaults.object(forKey: key)
    }
    if let hit = cache.withLockRead({ $0[key] }) {
      return hit
    }
    underlyingReads.withLock { $0 += 1 }
    let value = defaults.object(forKey: key)
    cache.withLock { $0[key] = value }
    return value
  }

  nonisolated public func set(_ value: Any?, forKey key: String) {
    defaults.set(value, forKey: key)
    invalidate(key)
  }

  nonisolated public func removeObject(forKey key: String) {
    defaults.removeObject(forKey: key)
    invalidate(key)
  }

  /// 依平臺與系統版本決定是否刻意同步。
  ///
  /// - macOS 10.8 起 cfprefsd 代管落盤（Core Foundation 之 10.8 release notes：`CFPreferencesSynchronize()`
  ///   因而 `-[NSUserDefaults synchronize]`「now automatic in virtually all cases」），故為 no-op；
  ///   本倉 macOS 地板為 10.9，故實務恆真。更古早之 macOS 與非 Darwin 才直呼 `synchronize()`——
  ///   後者之上游 `set` 只把鍵標為 dirty，須顯式落盤。
  nonisolated public func doSynchronize() {
    #if canImport(Darwin)
      #if os(macOS)
        if #available(macOS 10.8, *) { return }
      #else
        return
      #endif
    #endif
    _ = defaults.synchronize()
  }

  /// 清空整份快取（外部改動之通知，與測試）。
  nonisolated public func invalidateAll() {
    cache.withLock { $0.removeAll(keepingCapacity: true) }
  }

  // MARK: Private

  nonisolated private let cache = NSMutex<[String: Any?]>([:])
  nonisolated private let underlyingReads = NSMutex(0)
  nonisolated(unsafe) private var observer: NSObjectProtocol?

  nonisolated private func invalidate(_ key: String) {
    cache.withLock { _ = $0.removeValue(forKey: key) }
  }
}

// MARK: - InMemoryDefaultsStore

/// `DefaultsStore` 之記憶體後端：不觸及磁碟、不跨行程，且可逐測試套件各持一份。
///
/// 取值語意與 `UserDefaults` 一致：存入 `nil` 等同移除該鍵（故 `object(forKey:)` 回傳 `nil`）。
public final class InMemoryDefaultsStore: DefaultsStore, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated public init(_ initial: [String: Any] = [:]) {
    self.storage = NSMutex(initial)
  }

  // MARK: Public

  /// 當前全部鍵之快照（排序後，供診斷與斷言使用）。
  nonisolated public var sortedKeys: [String] {
    storage.withLockRead { $0.keys.sorted() }
  }

  nonisolated public func object(forKey key: String) -> Any? {
    storage.withLockRead { $0[key] }
  }

  nonisolated public func set(_ value: Any?, forKey key: String) {
    storage.withLock { dict in
      if let value {
        dict[key] = value
      } else {
        _ = dict.removeValue(forKey: key)
      }
    }
  }

  nonisolated public func removeObject(forKey key: String) {
    storage.withLock { dict in
      _ = dict.removeValue(forKey: key)
    }
  }

  /// 清空全部鍵——供測試於用例之間將容器歸零。
  nonisolated public func removeAll() {
    storage.withLock { $0.removeAll() }
  }

  // MARK: Private

  private let storage: NSMutex<[String: Any]>
}
