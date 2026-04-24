// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

/// 一個會在指定時間間隔後自動使快取條目失效的快取系統。
///
/// 最佳化（2026-04-24）：
/// - 將執行緒同步從 `DispatchQueue.sync` 改為 `NSLock`，消除 GCD 基礎設施開銷。
/// - 將時間戳記從 `Date`（`gettimeofday` 系統呼叫）改為 `DispatchTime.uptimeNanoseconds`（單調時鐘，更輕量）。
/// - 以操作計數器（每 64 次才觸發一次清理檢查）取代每次操作都建立 `Date()` 的模式。
public final class QueryBuffer<T> {
  // MARK: Lifecycle

  /// 以特定的過期時間間隔初期化 QueryBuffer
  /// - Parameter expirationInterval: 條目過期的秒數（預設值：7）
  public init(expirationInterval: TimeInterval = 7.0) {
    self.expirationNanoseconds = UInt64(expirationInterval * 1_000_000_000)
  }

  // MARK: Public

  /// 返回目前在緩衝區中的項目數量（包括尚未清理的過期項目）
  public var count: Int {
    lock.withLock { cache.count }
  }

  /// 使用字串鍵值將值加入緩衝區
  /// - Parameters:
  ///   - key: 將被轉換為雜湊值的字串鍵值
  ///   - value: 要儲存的值
  public func set(key: String, value: T) {
    guard !key.isEmpty else { return }
    set(hashKey: key.hashValue, value: value)
  }

  /// 使用雜湊鍵值將值加入緩衝區
  /// - Parameters:
  ///   - hashKey: 整數雜湊鍵值
  ///   - value: 要儲存的值
  public func set(hashKey: Int, value: T) {
    let now = DispatchTime.now().uptimeNanoseconds
    lock.withLock {
      cache[hashKey] = CacheEntry(value: value, timestampNs: now)
      operationCount &+= 1
      if operationCount & (Self.cleanupCheckInterval - 1) == 0 {
        removeExpiredEntriesLocked(now: now)
      }
    }
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  /// - Parameter key: 將被轉換為雜湊值的字串鍵值
  /// - Returns: 如果快取值可用且未過期則返回該值，否則返回 nil
  public func get(key: String) -> T? {
    guard !key.isEmpty else { return nil }
    return get(hashKey: key.hashValue)
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  /// - Parameter hashKey: 整數雜湊鍵值
  /// - Returns: 如果快取值可用且未過期則返回該值，否則返回 nil
  public func get(hashKey: Int) -> T? {
    let now = DispatchTime.now().uptimeNanoseconds
    return lock.withLock {
      guard let entry = cache[hashKey] else { return nil }
      if now &- entry.timestampNs > expirationNanoseconds {
        cache.removeValue(forKey: hashKey)
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
    guard !key.isEmpty else { return nil }
    return remove(hashKey: key.hashValue)
  }

  /// 從緩衝區中移除特定條目
  /// - Parameter hashKey: 整數雜湊鍵值
  /// - Returns: 如果條目存在則返回被移除的值，否則返回 nil
  @discardableResult
  public func remove(hashKey: Int) -> T? {
    lock.withLock {
      cache.removeValue(forKey: hashKey)?.value
    }
  }

  /// 清除緩衝區中的所有條目
  public func clear() {
    lock.withLock { cache.removeAll() }
  }

  // MARK: Private

  /// 用於追蹤快取值及其時間戳記的內部結構（使用單調奈秒時間戳）
  private struct CacheEntry {
    let value: T
    let timestampNs: UInt64
  }

  /// 每 64 次操作才觸發一次清理（64 = 2^6，使用位元 AND 判斷，避免除法）。
  private static var cleanupCheckInterval: UInt64 { 64 }

  /// 主要快取儲存空間 - 使用 Int（雜湊值）作為鍵值
  private var cache: [Int: CacheEntry] = [:]

  /// 條目過期的奈秒時間間隔
  private let expirationNanoseconds: UInt64

  /// 操作計數器（使用溢位加法，讓其自然環繞而不越界）
  private var operationCount: UInt64 = 0

  /// 輕量互斥鎖，取代 DispatchQueue.sync 的 GCD 基礎設施
  private let lock = NSLock()

  /// 在持有鎖的前提下移除所有過期條目（呼叫方必須先取得 lock）
  private func removeExpiredEntriesLocked(now: UInt64) {
    guard !cache.isEmpty else { return }
    var expiredKeys: [Int] = []
    expiredKeys.reserveCapacity(Swift.min(cache.count, 256))
    for (key, value) in cache where now &- value.timestampNs > expirationNanoseconds {
      expiredKeys.append(key)
    }
    guard !expiredKeys.isEmpty else { return }
    expiredKeys.forEach { cache.removeValue(forKey: $0) }
  }
}
