// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

/// 一個會在指定時間間隔後自動使快取條目失效的快取系統。
///
/// 最佳化（2026-04-24）：
/// - 將執行緒同步從 `DispatchQueue.sync` 改為 `NSMutex`，消除 GCD 基礎設施開銷。
/// - 將時間戳記從 `Date`（`gettimeofday` 系統呼叫）改為 `DispatchTime.uptimeNanoseconds`（單調時鐘，更輕量）。
/// - 以操作計數器（每 64 次才觸發一次清理檢查）取代每次操作都建立 `Date()` 的模式。
/// - 以到期佇列搭配時間閘門與分批回收，避免週期性對整張 Dictionary 做全量掃描。
public final class QueryBuffer<T> {
  // MARK: Lifecycle

  /// 以特定的過期時間間隔初期化 QueryBuffer
  /// - Parameters:
  ///   - expirationInterval: 條目過期的秒數（預設值：7）
  ///   - maxCount: 最大快取條目數，超過時淘汰最舊條目（nil = 無上限）
  public init(expirationInterval: TimeInterval = 7.0, maxCount: Int? = nil) {
    self.expirationNanoseconds = UInt64(expirationInterval * 1_000_000_000)
    self.cleanupThrottleNanoseconds = Swift.max(
      Self.minimumCleanupThrottleNanoseconds,
      Swift.min(expirationNanoseconds, Self.maximumCleanupThrottleNanoseconds)
    )
    self.maxCount = maxCount
  }

  // MARK: Public

  /// 返回目前在緩衝區中的項目數量（包括尚未清理的過期項目）
  public var count: Int {
    mtxCache.withLockRead { $0.count }
  }

  /// 使用字串鍵值將值加入緩衝區
  public func set(key: String, value: T) {
    guard !key.isEmpty else { return }
    set(hashKey: key.hashValue, value: value)
  }

  /// 使用雜湊鍵值將值加入緩衝區
  public func set(hashKey: Int, value: T) {
    let now = DispatchTime.now().uptimeNanoseconds
    let entry = CacheEntry(value: value, timestampNs: now)
    mtxCache.withLock {
      $0[hashKey] = entry
    }
    mtxExpirationQueue.withLock {
      $0.append(.init(hashKey: hashKey, timestampNs: now))
    }
    let shouldCheckCleanup = mtxOperationCount.withLock { operationCount in
      operationCount &+= 1
      return operationCount & (Self.cleanupCheckInterval - 1) == 0
    }
    if shouldCheckCleanup, shouldRunCleanupLocked(now: now) {
      removeExpiredEntriesLocked(now: now)
    }
    evictOldestIfOverMaxCountLocked(now: now)
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  public func get(key: String) -> T? {
    guard !key.isEmpty else { return nil }
    return get(hashKey: key.hashValue)
  }

  /// 如果值存在且未過期，則從緩衝區擷取該值
  public func get(hashKey: Int) -> T? {
    let now = DispatchTime.now().uptimeNanoseconds
    guard let entry = mtxCache.withLockRead({ $0[hashKey] }) else { return nil }
    if now &- entry.timestampNs > expirationNanoseconds {
      mtxCache.withLock { cache in
        if let currentEntry = cache[hashKey], currentEntry.timestampNs == entry.timestampNs {
          cache.removeValue(forKey: hashKey)
        }
      }
      return nil
    }
    return entry.value
  }

  /// 從緩衝區中移除特定條目
  @discardableResult
  public func remove(key: String) -> T? {
    guard !key.isEmpty else { return nil }
    return remove(hashKey: key.hashValue)
  }

  /// 從緩衝區中移除特定條目
  @discardableResult
  public func remove(hashKey: Int) -> T? {
    mtxCache.withLock {
      $0.removeValue(forKey: hashKey)?.value
    }
  }

  /// 清除緩衝區中的所有條目
  public func clear() {
    mtxCache.withLock { $0.removeAll() }
    mtxExpirationQueue.withLock { $0.removeAll(keepingCapacity: false) }
    mtxExpirationQueueHead.value = 0
    mtxOperationCount.value = 0
    mtxLastCleanupTimestampNs.value = 0
    mtxCleanupInProgress.value = false
  }

  // MARK: Private

  private struct CacheEntry {
    let value: T
    let timestampNs: UInt64
  }

  private struct ExpirationMarker {
    let hashKey: Int
    let timestampNs: UInt64
  }

  private static var cleanupCheckInterval: UInt64 { 64 }

  private static var cleanupRemovalLimit: Int { 32 }

  private static var minimumCleanupThrottleNanoseconds: UInt64 { 1_000_000 }

  private static var maximumCleanupThrottleNanoseconds: UInt64 { 250_000_000 }

  private let mtxCache: NSMutex<[Int: CacheEntry]> = .init([:])

  private let mtxExpirationQueue: NSMutex<[ExpirationMarker]> = .init([])

  private let mtxExpirationQueueHead = NSMutex(0)

  private let expirationNanoseconds: UInt64

  private let cleanupThrottleNanoseconds: UInt64

  private let mtxOperationCount = NSMutex<UInt64>(0)

  private let mtxLastCleanupTimestampNs = NSMutex<UInt64>(0)

  private let mtxCleanupInProgress = NSMutex<Bool>(false)

  private let maxCount: Int?

  private func evictOldestIfOverMaxCountLocked(now: UInt64) {
    guard let maxCount else { return }
    let currentCount = count
    guard currentCount > maxCount else { return }
    // 掃描快取尋找最舊條目（timestampNs 最小），逐出之。
    // 每次 set() 最多逐出 1 條，避免單次操作過長時間。
    var oldestKey: Int?
    var oldestTime: UInt64 = .max
    mtxCache.withLockRead { cache in
      for (key, entry) in cache where entry.timestampNs < oldestTime {
        oldestTime = entry.timestampNs
        oldestKey = key
      }
    }
    if let oldestKey {
      _ = mtxCache.withLock { $0.removeValue(forKey: oldestKey) }
    }
  }

  private func shouldRunCleanupLocked(now: UInt64) -> Bool {
    let lastCleanupTimestampNs = mtxLastCleanupTimestampNs.value
    return now &- lastCleanupTimestampNs >= cleanupThrottleNanoseconds
  }

  private func beginCleanupPass(now: UInt64) -> Bool {
    let shouldEnter = mtxCleanupInProgress.withLock { cleanupInProgress in
      if cleanupInProgress {
        return false
      }
      cleanupInProgress = true
      return true
    }
    guard shouldEnter else { return false }
    mtxLastCleanupTimestampNs.value = now
    return true
  }

  private func endCleanupPass() {
    mtxCleanupInProgress.value = false
  }

  private func currentExpirationMarker() -> ExpirationMarker? {
    let head = mtxExpirationQueueHead.value
    return mtxExpirationQueue.withLockRead { queue in
      guard head < queue.count else { return nil }
      return queue[head]
    }
  }

  private func advanceExpirationQueueHead() {
    mtxExpirationQueueHead.withLock { $0 &+= 1 }
  }

  private func compactExpirationQueueIfNeeded() {
    let head = mtxExpirationQueueHead.value
    guard head > 0 else { return }
    let queueCount = mtxExpirationQueue.withLockRead { $0.count }
    guard head >= queueCount / 2 else { return }
    mtxExpirationQueue.withLock { queue in
      if head >= queue.count {
        queue.removeAll(keepingCapacity: false)
      } else {
        queue.removeFirst(head)
      }
    }
    mtxExpirationQueueHead.value = 0
  }

  private func removeExpiredEntriesLocked(now: UInt64) {
    guard beginCleanupPass(now: now) else { return }
    defer { endCleanupPass() }

    var removedCount = 0
    while removedCount < Self.cleanupRemovalLimit {
      guard let marker = currentExpirationMarker() else { break }
      if now &- marker.timestampNs <= expirationNanoseconds {
        break
      }
      let didRemove = mtxCache.withLock { cache in
        guard let currentEntry = cache[marker.hashKey], currentEntry.timestampNs == marker.timestampNs else {
          return false
        }
        cache.removeValue(forKey: marker.hashKey)
        return true
      }
      if didRemove {
        removedCount &+= 1
      }
      advanceExpirationQueueHead()
    }

    compactExpirationQueueIfNeeded()
  }
}
