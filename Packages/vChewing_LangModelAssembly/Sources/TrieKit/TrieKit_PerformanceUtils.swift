// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - TrieStringPool

/// 專為樹狀索引操作最佳化的字串拘留池
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

      keyPool[string] = string
      return string
    }
  }

  @usableFromInline
  func internValue(_ string: String) -> String {
    lock.withLock {
      if let interned = valuePool[string] {
        return interned
      }

      valuePool[string] = string
      return string
    }
  }

  @usableFromInline
  func clear() {
    lock.withLock {
      keyPool.removeAll(keepingCapacity: true)
      valuePool.removeAll(keepingCapacity: true)
    }
  }

  // MARK: Private

  private var keyPool: [String: String] = [:]
  private var valuePool: [String: String] = [:]
  private let lock = NSLock()
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
    let key = "\(string)|\(separator)"
    return lock.withLock {
      if let cached = splitCache[key] {
        return cached
      }

      let result = string.split(separator: separator).map(String.init)

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

      let result = string.first?.description ?? ""

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

  private var splitCache: [String: [String]] = [:]
  private var firstCharCache: [String: String] = [:]
  private let lock = NSLock()
  private let maxCacheSize = 2_000 // 樹狀索引操作使用較大的快取
}
