// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

/// 一個會在指定時間間隔後自動使快取條目失效的快取系統
public final class QueryBuffer<T> {
  // MARK: Lifecycle

  /// 以特定的過期時間間隔初期化 QueryBuffer
  /// - Parameter expirationInterval: 條目過期的秒數（預設值：7）
  public init(expirationInterval: TimeInterval = 7.0) {
    self.expirationInterval = expirationInterval
  }

  // MARK: Public

  /// 返回目前在緩衝區中的項目數量（包括尚未清理的過期項目）
  public var count: Int {
    defer {
      cleanupIfNeeded()
    }

    return lockQueue.sync {
      self.cache.count
    }
  }

  /// 使用字串鍵值將值加入緩衝區
  /// - Parameters:
  ///   - key: 將被轉換為雜湊值的字串鍵值
  ///   - value: 要儲存的值
  public func set(key: String, value: T) {
    defer {
      cleanupIfNeeded()
    }
    guard !key.isEmpty else { return }

    let hashKey = key.hashValue
    lockQueue.sync {
      self.cache[hashKey] = CacheEntry(value: value, timestamp: Date())
    }
  }

  /// 使用字串鍵值將值加入緩衝區
  /// - Parameters:
  ///   - hashKey: 將被轉換為雜湊值的字串鍵值
  ///   - value: 要儲存的值
  public func set(hashKey: Int, value: T) {
    defer {
      cleanupIfNeeded()
    }

    lockQueue.sync {
      self.cache[hashKey] = CacheEntry(value: value, timestamp: Date())
    }
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  /// - Parameter key: 將被轉換為雜湊值的字串鍵值
  /// - Returns: 如果快取值可用且未過期則返回該值，否則返回 nil
  public func get(key: String) -> T? {
    defer {
      cleanupIfNeeded()
    }
    guard !key.isEmpty else { return nil }

    let hashKey = key.hashValue

    return lockQueue.sync {
      guard let entry = self.cache[hashKey] else {
        return nil
      }

      // 檢查條目是否已過期
      if Date().timeIntervalSince(entry.timestamp) > self.expirationInterval {
        self.cache.removeValue(forKey: hashKey)
        return nil
      }

      return entry.value
    }
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  /// - Parameter hashKey: 將被轉換為雜湊值的字串鍵值
  /// - Returns: 如果快取值可用且未過期則返回該值，否則返回 nil
  public func get(hashKey: Int) -> T? {
    defer {
      cleanupIfNeeded()
    }

    return lockQueue.sync {
      guard let entry = self.cache[hashKey] else {
        return nil
      }

      // 檢查條目是否已過期
      if Date().timeIntervalSince(entry.timestamp) > self.expirationInterval {
        self.cache.removeValue(forKey: hashKey)
        return nil
      }

      return entry.value
    }
  }

  /// 從緩衝區中移除特定條目
  /// - Parameter key: 將被轉換為雜湊值的字串鍵值
  /// - Returns: 如果條目存在則返回被移除的值，否則返回 nil
  @discardableResult
  public func remove(key: String) -> T? {
    defer {
      cleanupIfNeeded()
    }
    guard !key.isEmpty else { return nil }

    let hashKey = key.hashValue

    return lockQueue.sync {
      let entry = self.cache.removeValue(forKey: hashKey)
      return entry?.value
    }
  }

  /// 從緩衝區中移除特定條目
  /// - Parameter hashKey: 將被轉換為雜湊值的字串鍵值
  /// - Returns: 如果條目存在則返回被移除的值，否則返回 nil
  @discardableResult
  public func remove(hashKey: Int) -> T? {
    defer {
      cleanupIfNeeded()
    }

    return lockQueue.sync {
      let entry = self.cache.removeValue(forKey: hashKey)
      return entry?.value
    }
  }

  /// 清除緩衝區中的所有條目
  public func clear() {
    lockQueue.sync {
      self.cache.removeAll()
    }
  }

  // MARK: Private

  /// 用於追蹤快取值及其時間戳記的內部結構
  private struct CacheEntry {
    let value: T
    let timestamp: Date
  }

  /// 主要快取儲存空間 - 使用 Int（雜湊值）作為鍵值，CacheEntry 作為值
  private var cache: [Int: CacheEntry] = [:]

  /// 條目被視為過期的時間間隔（預設值：7 秒）
  private let expirationInterval: TimeInterval

  /// 追蹤上次清理的執行時間
  private var lastCleanupTime: Date = .init()

  /// 清理操作之間的最小間隔（7 秒）
  private let cleanupThreshold: TimeInterval = 7.0

  /// 用於執行緒同步的序列佇列
  private let lockQueue = DispatchQueue(
    label: "org.libVanguard.vanguardTrie.querybuffer.lock.\(UUID().uuidString)"
  )

  /// 檢查是否需要清理，如有必要則執行清理
  private func cleanupIfNeeded() {
    let now = Date()

    // 僅在距離上次清理已經過足夠時間（7 秒）時才進行清理
    if now.timeIntervalSince(lastCleanupTime) >= cleanupThreshold {
      removeExpiredEntries()
    }
  }

  /// 從快取中移除所有過期的條目
  private func removeExpiredEntries() {
    lockQueue.sync {
      let now = Date()
      self.lastCleanupTime = now

      // 尋找所有過期的鍵值
      let keysToRemove = self.cache.filter { _, entry in
        now.timeIntervalSince(entry.timestamp) > self.expirationInterval
      }.map { $0.key }

      // 移除過期的條目
      for key in keysToRemove {
        self.cache.removeValue(forKey: key)
      }
    }
  }
}
