// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - TrieStringPool

/// 專為樹狀索引操作最佳化的字串拘留池。
///
/// 為避免常駐記憶體隨查詢範圍無限成長，key/value 兩個 pool 都設有 FIFO（先入先出）上限；
/// 被淘汰的字串只會失去未來 deduplication 的機會，不會影響已回傳的 String reference。
@usableFromInline
final class TrieStringPool: @unchecked Sendable {
  // MARK: Internal

  @usableFromInline
  static let shared = TrieStringPool()

  @usableFromInline
  func internKey(_ string: String) -> String {
    lock.withLock {
      if let interned = keyPool[string] {
        return interned
      }

      evictKeyIfNeeded()
      keyPool[string] = string
      keyPoolOrder.append(string)
      return string
    }
  }

  @usableFromInline
  func internValue(_ string: String) -> String {
    lock.withLock {
      if let interned = valuePool[string] {
        return interned
      }

      evictValueIfNeeded()
      valuePool[string] = string
      valuePoolOrder.append(string)
      return string
    }
  }

  @usableFromInline
  func clear() {
    lock.withLock {
      keyPool.removeAll(keepingCapacity: true)
      valuePool.removeAll(keepingCapacity: true)
      keyPoolOrder.removeAll(keepingCapacity: true)
      valuePoolOrder.removeAll(keepingCapacity: true)
      keyPoolOrderHead = 0
      valuePoolOrderHead = 0
    }
  }

  // MARK: Private

  private let maxPoolSize = 10_000
  private var keyPool: [String: String] = [:]
  private var valuePool: [String: String] = [:]
  private var keyPoolOrder: [String] = []
  private var valuePoolOrder: [String] = []
  /// 佇列頭偏移：逐出時僅前移偏移量（O(1)），累積到一定量再一次壓實陣列（攤還 O(1)）。
  private var keyPoolOrderHead = 0
  private var valuePoolOrderHead = 0
  private let lock = NSLock()

  private func evictKeyIfNeeded() {
    guard keyPool.count >= maxPoolSize, keyPoolOrderHead < keyPoolOrder.count else { return }
    keyPool.removeValue(forKey: keyPoolOrder[keyPoolOrderHead])
    keyPoolOrderHead += 1
    if keyPoolOrderHead >= maxPoolSize {
      keyPoolOrder.removeFirst(keyPoolOrderHead)
      keyPoolOrderHead = 0
    }
  }

  private func evictValueIfNeeded() {
    guard valuePool.count >= maxPoolSize, valuePoolOrderHead < valuePoolOrder.count else { return }
    valuePool.removeValue(forKey: valuePoolOrder[valuePoolOrderHead])
    valuePoolOrderHead += 1
    if valuePoolOrderHead >= maxPoolSize {
      valuePoolOrder.removeFirst(valuePoolOrderHead)
      valuePoolOrderHead = 0
    }
  }
}

// MARK: - TrieStringOperationCache

/// 針對樹狀索引特定模式最佳化的字串操作快取
@usableFromInline
final class TrieStringOperationCache: @unchecked Sendable {
  // MARK: Internal

  @usableFromInline
  static let shared = TrieStringOperationCache()

  @usableFromInline
  func getCachedSplit(_ string: String, separator: Character) -> [String] {
    let key = SplitCacheKey(string: string, separator: separator)
    return lock.withLock {
      if let cached = splitCache[key] {
        return cached
      }

      let result: [String]
      if let asciiValue = separator.asciiValue {
        result = string.utf8.split(separator: asciiValue).map {
          String(decoding: $0, as: UTF8.self)
        }
      } else {
        result = string.split(separator: separator).map(String.init)
      }

      // 防止快取無限制增長
      if splitCache.count < maxCacheSize {
        splitCache[key] = result
      }

      return result
    }
  }

  @usableFromInline
  func getCachedFirstChar(_ string: String) -> String {
    lock.withLock {
      if let cached = firstCharCache[string] {
        return cached
      }

      let result: String = {
        guard !string.isEmpty, let firstScalar = string.unicodeScalars.first else { return "" }
        return String(firstScalar)
      }()

      // 防止快取無限制增長
      if firstCharCache.count < maxCacheSize {
        firstCharCache[string] = result
      }

      return result
    }
  }

  @usableFromInline
  func clear() {
    lock.withLock {
      splitCache.removeAll(keepingCapacity: true)
      firstCharCache.removeAll(keepingCapacity: true)
    }
  }

  // MARK: Private

  /// 複合快取鍵：以結構體取代字串插值，避免每次查詢都配置新 String。
  private struct SplitCacheKey: Hashable {
    let string: String
    let separator: Character
  }

  private var splitCache: [SplitCacheKey: [String]] = [:]
  private var firstCharCache: [String: String] = [:]
  private let lock = NSLock()
  private let maxCacheSize = 2_000 // 樹狀索引操作使用較大的快取
}
