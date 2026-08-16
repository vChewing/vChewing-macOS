// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import SwiftExtension

// MARK: - LMAssembly.LMCassette

// 以連續記憶體空間（contiguous [UInt8] blob）取代大量 Dictionary<String, [String]>，
// 將 charDef / symbolDef / reverseLookup / octagram / quickDef / quickPhrase 等大型字典改為
// sorted byte-range index + binary search，按需從 rawData 解析字串，
// 大幅降低 heap allocation 與 Dictionary 開銷。

extension LMAssembly {
  /// 磁帶模組，用來方便使用者自行擴充字根輸入法。
  /// 以連續記憶體 [UInt8] blob + byte-range 索引取代各大型 Dictionary。
  nonisolated struct LMCassette: Sendable {
    // MARK: Internal

    private(set) var filePath: String?
    private(set) var nameShort: String = ""
    private(set) var nameENG: String = ""
    private(set) var nameCJK: String = ""
    private(set) var nameIntl: String = ""
    private(set) var nullCandidate: String = ""
    /// 一個漢字可能最多要用到多少碼。
    private(set) var maxKeyLength: Int = 1
    private(set) var selectionKeys: String = ""
    private(set) var endKeys: [String] = []
    private(set) var wildcardKey: String = ""
    private(set) var anySingleCharKey: String = ""
    private(set) var keysToDirectlyCommit: String = ""
    /// 字根翻譯表（小型，~30 entries），保持 Dictionary。
    private(set) var keyNameMap: [String: String] = [:]
    /// `%quick` 簡碼資料，改用 contiguous-memory index（值為字元拼接字串）。
    private(set) var quickDefMap: CassetteQuickMap = .init()
    /// `%quickphrases` 詞語資料，改用 contiguous-memory index。
    private(set) var quickPhraseMap: CassetteSortedMap = .init()
    private(set) var quickPhraseCommissionKey: String = ""

    // 大型資料結構改為 contiguous-memory 索引。
    /// `%chardef` 字根→字詞對照，sorted by key UTF-8。
    private(set) var charDefMap: CassetteSortedMap = .init()
    /// `%symboldef` 符號選單資料，sorted by key UTF-8。
    private(set) var symbolDefMap: CassetteSortedMap = .init()
    /// 字→碼反向查詢零複製索引（chardef + symboldef 合併）。
    private(set) var reverseIndex: CassetteReverseIndex = .init()
    /// 字根輸入法專用八股文：字詞→頻次，sorted by key UTF-8。
    private(set) var octagramMap: CassetteOctagramMap = .init()
    /// 音韻輸入法專用八股文：字詞→(頻次, 讀音)，sorted by key UTF-8。
    private(set) var octagramDividedMap: CassetteOctagramDividedMap = .init()

    private(set) var areCandidateKeysShiftHeld: Bool = false
    private(set) var supplyQuickResults: Bool = false
    private(set) var supplyPartiallyMatchedResults: Bool = false
    var candidateKeysValidator: @Sendable (String) -> Bool = { _ in false }

    // MARK: Private

    /// 計算頻率時要用到的東西 - NORM
    private var norm = 0.0
  }
}

// MARK: - Contiguous-Memory Index Types

extension LMAssembly {
  /// 以連續 [UInt8] blob 承載的 sorted key→[value] 對照表。
  /// 所有 key / value 字串皆以 byte range 指向 `rawData`，
  /// 查詢時二分搜尋 + 按需物化，避免大量 String / Dictionary 開銷。
  nonisolated struct CassetteSortedMap: Sendable {
    // MARK: Internal

    /// 唯一 key 數量。
    var count: Int { entries.count }
    /// 是否為空。
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    /// 連續記憶體空間，承載所有 key 與 value 的原始 UTF-8。
    fileprivate var rawData: [UInt8] = []
    /// 按 key UTF-8 排序的索引。每個 entry 擁有一段連續 values。
    fileprivate var entries: [CassetteMapEntry] = []
    /// 所有 value 的 byte offset 平坦陣列，每個 value 佔兩個 `UInt32`：start、end。
    fileprivate var valueOffsets: [UInt32] = []
  }

  /// CassetteSortedMap 的單筆 key entry。
  nonisolated struct CassetteMapEntry: Sendable {
    let keyStart: UInt32
    let keyEnd: UInt32
    /// 指向 `valueOffsets` 的範圍（每個 value 佔兩個 slot）。
    let valuesStart: UInt32
    let valuesEnd: UInt32
  }

  /// CassetteReverseIndex 的單筆反查 entry（反查字詞 → 碼 refs 範圍）。
  nonisolated struct CassetteReverseEntry: Sendable {
    /// 反查字詞在 `revChars` 內的範圍。
    let charStart: UInt32
    let charEnd: UInt32
    /// 指向 `revCodeRefs` 的範圍。
    let refsStart: UInt32
    let refsEnd: UInt32
  }

  /// 字→碼反向查詢索引：僅複製去重後的反查字詞 bytes，
  /// 碼字串以 entry 索引引用 charDefMap / symbolDefMap 的既有 rawData，不做全量複製。
  nonisolated struct CassetteReverseIndex: Sendable {
    // MARK: Internal

    var isEmpty: Bool { revEntries.isEmpty }

    // MARK: Fileprivate

    /// 去重後的唯一反查字詞 UTF-8 bytes。
    fileprivate var revChars: [UInt8] = []
    /// 按反查字詞 bytes 排序的索引。
    fileprivate var revEntries: [CassetteReverseEntry] = []
    /// 合併 namespace 的 entry 索引：小於 `charDefEntryCount` 者指向 charDefMap，
    /// 否則減去 `charDefEntryCount` 後指向 symbolDefMap。
    fileprivate var revCodeRefs: [UInt32] = []
    /// 合併 namespace 中 charDefMap 的 entry 數量。
    fileprivate var charDefEntryCount: UInt32 = 0
  }

  /// key→single value 的 contiguous-memory 對照表（取代 quickDef Dictionary）。
  nonisolated struct CassetteQuickMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    fileprivate var rawData: [UInt8] = []
    fileprivate var entries: [CassetteQuickEntry] = []
  }

  nonisolated struct CassetteQuickEntry: Sendable {
    let keyStart: UInt32
    let keyEnd: UInt32
    let valueStart: UInt32
    let valueEnd: UInt32
  }

  /// 八股文 sorted map：字詞→頻次。
  nonisolated struct CassetteOctagramMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    /// Data → [UInt8]。
    fileprivate var rawData: [UInt8] = []
    fileprivate var entries: [CassetteOctagramEntry] = []
  }

  nonisolated struct CassetteOctagramEntry: Sendable {
    let keyStart: UInt32
    let keyEnd: UInt32
    let count: UInt32
  }

  /// 八股文 divided sorted map：字詞→(頻次, 讀音)。
  nonisolated struct CassetteOctagramDividedMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    /// Data → [UInt8]。
    fileprivate var rawData: [UInt8] = []
    fileprivate var entries: [CassetteOctagramDividedEntry] = []
  }

  nonisolated struct CassetteOctagramDividedEntry: Sendable {
    let keyStart: UInt32
    let keyEnd: UInt32
    let count: UInt32
    let readingStart: UInt32
    let readingEnd: UInt32
  }
}

// MARK: - [UInt8] Extension: UTF-8 Byte-Level Comparison

// 字典序比較統一使用 `RangeParserAPI.swift` 的 `compareByteRange` / `compareByteSlices`；
// 此處僅保留磁帶模組專用的 prefix 比較。

nonisolated extension Array where Element == UInt8 {
  /// 比較 range 內的 bytes 是否「大於等於」prefix bytes（用於 lower-bound 搜尋）。
  fileprivate func cassetteCompareUTF8RangePrefix(_ range: Range<Int>, with prefix: [UInt8]) -> Int {
    let lhsCount = range.count
    let prefixCount = prefix.count
    let minCount = Swift.min(lhsCount, prefixCount)
    for i in 0 ..< minCount {
      let lb = self[range.lowerBound + i]
      let rb = prefix[i]
      if lb < rb { return -1 }
      if lb > rb { return 1 }
    }
    if lhsCount < prefixCount { return -1 }
    return 0
  }
}

// MARK: - CassetteSortedMap: Binary Search & Query API

nonisolated extension LMAssembly.CassetteSortedMap {
  /// 二分搜尋精確匹配。
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  /// 從 `valueOffsets` 的指定 slot 取出 value 字串（slot 為偶數，佔兩個 UInt32）。
  private func valueString(at slot: Int) -> String {
    String(
      decoding: rawData[Int(valueOffsets[slot]) ..< Int(valueOffsets[slot + 1])],
      as: UTF8.self
    )
  }

  /// 回傳 entry 對應的所有 value 字串。
  private func entryValues(at entryIndex: Int) -> [String] {
    let e = entries[entryIndex]
    var result = [String]()
    result.reserveCapacity((Int(e.valuesEnd) - Int(e.valuesStart)) / 2)
    for slot in stride(from: Int(e.valuesStart), to: Int(e.valuesEnd), by: 2) {
      result.append(valueString(at: slot))
    }
    return result
  }

  /// 精確查詢 key 對應的 values 字串陣列。
  func valuesFor(key: String) -> [String]? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    let values = entryValues(at: idx)
    return values.isEmpty ? nil : values
  }

  /// 下標存取（與舊版 Dictionary 相容）。
  subscript(key: String) -> [String]? {
    valuesFor(key: key)
  }

  /// 檢查是否含有指定 key。
  func containsKey(_ key: String) -> Bool {
    binarySearchIndex(for: key) != nil
  }

  /// 以前綴掃描取得所有 key 以 `prefix` 開頭的 entries 的 (key, values)。
  /// 利用 sorted 特性做 lower-bound 搜尋 + 線性掃描。
  func prefixScan(prefix: String) -> [(key: String, values: [String])] {
    let prefixUTF8 = Array(prefix.utf8)
    guard !prefixUTF8.isEmpty else { return [] }
    // Lower bound.
    var lo = 0, hi = entries.count
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.cassetteCompareUTF8RangePrefix(
        Int(e.keyStart) ..< Int(e.keyEnd),
        with: prefixUTF8
      )
      if cmp < 0 { lo = mid + 1 } else { hi = mid }
    }
    var results = [(key: String, values: [String])]()
    while lo < entries.count {
      let e = entries[lo]
      let keyStart = Int(e.keyStart)
      let keyEnd = Int(e.keyEnd)
      guard keyEnd - keyStart >= prefixUTF8.count else { break }
      var isPrefix = true
      for i in 0 ..< prefixUTF8.count {
        if rawData[keyStart + i] != prefixUTF8[i] { isPrefix = false; break }
      }
      guard isPrefix else { break }
      let key = String(decoding: rawData[keyStart ..< keyEnd], as: UTF8.self)
      results.append((key, entryValues(at: lo)))
      lo += 1
    }
    return results
  }

  /// 以萬用字元（wildcard，1+ 任意字元）與任意單字元鍵（anySingleChar，恰好 1 字元）
  /// 組成的 pattern 查詢所有匹配 key 的 value。開頭的 wildcard 且後方全為 literal 時，
  /// 視為 anagram（任意字根序）查詢。透過對 sorted entries 做前綴 lower-bound 縮小掃描範圍。
  func patternValuesFor(key: String, wildcard: String, anySingleChar: String) -> [String]? {
    let tokens = Self.tokenizePattern(key, wildcard: wildcard, anySingleChar: anySingleChar)
    guard Self.hasPatternTokens(tokens) else { return nil }
    var results = [String]()
    scanPatternMatches(tokens: tokens) { entryIndex in
      results.append(contentsOf: entryValues(at: entryIndex))
      return true
    }
    return results.isEmpty ? nil : results
  }

  /// 檢查是否有任何萬用字元 / 任意單字元 pattern 匹配。
  func containsPatternMatch(key: String, wildcard: String, anySingleChar: String) -> Bool {
    let tokens = Self.tokenizePattern(key, wildcard: wildcard, anySingleChar: anySingleChar)
    guard Self.hasPatternTokens(tokens) else { return false }
    var found = false
    scanPatternMatches(tokens: tokens) { _ in
      found = true
      return false
    }
    return found
  }

  // MARK: Fileprivate

  /// Pattern 解析後的單筆 token。
  fileprivate enum CassettePatternToken {
    /// literal byte 序列。
    case literal([UInt8])
    /// 萬用字元：一個或多個連續的任意 key char。
    case wildcard
    /// 任意單字元鍵：恰好一個任意 key char。
    case anySingleChar
  }

  /// 將 pattern 解析為 token 序列。wildcard 與 anySingleChar 均為單字元。
  fileprivate static func tokenizePattern(
    _ key: String,
    wildcard: String,
    anySingleChar: String
  )
    -> [CassettePatternToken] {
    var tokens = [CassettePatternToken]()
    var literalBuffer = [UInt8]()
    for char in key {
      let charString = String(char)
      if !wildcard.isEmpty, charString == wildcard {
        if !literalBuffer.isEmpty {
          tokens.append(.literal(literalBuffer))
          literalBuffer.removeAll(keepingCapacity: true)
        }
        tokens.append(.wildcard)
      } else if !anySingleChar.isEmpty, charString == anySingleChar {
        if !literalBuffer.isEmpty {
          tokens.append(.literal(literalBuffer))
          literalBuffer.removeAll(keepingCapacity: true)
        }
        tokens.append(.anySingleChar)
      } else {
        literalBuffer.append(contentsOf: char.utf8)
      }
    }
    if !literalBuffer.isEmpty { tokens.append(.literal(literalBuffer)) }
    return tokens
  }

  /// 是否含有萬用字元 / 任意單字元 token（純 literal 的 pattern 不屬於 pattern 查詢）。
  fileprivate static func hasPatternTokens(_ tokens: [CassettePatternToken]) -> Bool {
    tokens.contains {
      switch $0 {
      case .anySingleChar, .wildcard: true
      case .literal: false
      }
    }
  }

  /// 由 UTF-8 leading byte 推算單個字元佔用的 byte 數。
  fileprivate static func utf8CharByteLength(_ leadingByte: UInt8) -> Int {
    switch leadingByte {
    case 0x00 ... 0x7F: 1
    case 0xC0 ... 0xDF: 2
    case 0xE0 ... 0xEF: 3
    default: 4
    }
  }

  /// 以回溯法判定候選 key bytes 是否匹配 token 序列。
  fileprivate static func matchPattern(
    tokens: [CassettePatternToken],
    tokenIndex: Int,
    key: [UInt8],
    position: Int
  )
    -> Bool {
    if tokenIndex == tokens.count { return position == key.count }
    switch tokens[tokenIndex] {
    case let .literal(bytes):
      guard position + bytes.count <= key.count else { return false }
      for (offset, byte) in bytes.enumerated() where key[position + offset] != byte {
        return false
      }
      return matchPattern(
        tokens: tokens,
        tokenIndex: tokenIndex + 1,
        key: key,
        position: position + bytes.count
      )
    case .anySingleChar:
      guard position < key.count else { return false }
      let nextPosition = position + utf8CharByteLength(key[position])
      guard nextPosition <= key.count else { return false }
      return matchPattern(
        tokens: tokens,
        tokenIndex: tokenIndex + 1,
        key: key,
        position: nextPosition
      )
    case .wildcard:
      // 萬用字元至少消秏一個字元。
      var nextPosition = position
      while nextPosition < key.count {
        nextPosition += utf8CharByteLength(key[nextPosition])
        guard nextPosition <= key.count else { return false }
        if matchPattern(
          tokens: tokens,
          tokenIndex: tokenIndex + 1,
          key: key,
          position: nextPosition
        ) { return true }
      }
      return false
    }
  }

  /// 掃描所有匹配 pattern 的 entries，對每筆匹配 entry 執行 `visit`；
  /// `visit` 回傳 false 時提前終止掃描。
  private func scanPatternMatches(
    tokens: [CassettePatternToken],
    visit: (Int) -> Bool
  ) {
    // 開頭 wildcard 且後方全為 literal：anagram（任意字根序）查詢。
    var isAnagramQuery = false
    if case .wildcard = tokens.first {
      isAnagramQuery = tokens.dropFirst().allSatisfy {
        if case .literal = $0 { return true }
        return false
      }
    }
    if isAnagramQuery {
      let anagramBytes = tokens.dropFirst().flatMap {
        if case let .literal(bytes) = $0 { return bytes }
        return [UInt8]()
      }.sorted()
      guard !anagramBytes.isEmpty else { return }
      for entryIndex in entries.indices {
        let e = entries[entryIndex]
        let keyStart = Int(e.keyStart)
        let keyEnd = Int(e.keyEnd)
        guard keyEnd - keyStart == anagramBytes.count else { continue }
        guard rawData[keyStart ..< keyEnd].sorted() == anagramBytes else { continue }
        guard visit(entryIndex) else { return }
      }
      return
    }

    // 取出開頭的 literal 前綴，用 lower-bound 縮小掃描範圍。
    var literalPrefix = [UInt8]()
    for token in tokens {
      guard case let .literal(bytes) = token else { break }
      literalPrefix.append(contentsOf: bytes)
    }

    var lo = 0
    if !literalPrefix.isEmpty {
      var hi = entries.count
      while lo < hi {
        let mid = lo + (hi - lo) / 2
        let e = entries[mid]
        let cmp = rawData.cassetteCompareUTF8RangePrefix(
          Int(e.keyStart) ..< Int(e.keyEnd),
          with: literalPrefix
        )
        if cmp < 0 { lo = mid + 1 } else { hi = mid }
      }
    }

    var keyBuffer = [UInt8]()
    for entryIndex in lo ..< entries.count {
      let e = entries[entryIndex]
      let keyStart = Int(e.keyStart)
      let keyEnd = Int(e.keyEnd)
      if !literalPrefix.isEmpty {
        guard keyEnd - keyStart >= literalPrefix.count else { break }
        var isPrefix = true
        for i in 0 ..< literalPrefix.count {
          if rawData[keyStart + i] != literalPrefix[i] { isPrefix = false; break }
        }
        guard isPrefix else { break }
      }
      keyBuffer.removeAll(keepingCapacity: true)
      keyBuffer.append(contentsOf: rawData[keyStart ..< keyEnd])
      guard Self.matchPattern(tokens: tokens, tokenIndex: 0, key: keyBuffer, position: 0)
      else { continue }
      guard visit(entryIndex) else { return }
    }
  }

  /// 取得所有 keys（物化後）。測試用。
  var keys: [String] {
    entries.map { String(decoding: rawData[Int($0.keyStart) ..< Int($0.keyEnd)], as: UTF8.self) }
  }
}

// MARK: - CassetteQuickMap: Binary Search & Query API

nonisolated extension LMAssembly.CassetteQuickMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  /// 查詢 key 對應的單一 value 字串。
  func valuesFor(key: String) -> String? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    let e = entries[idx]
    return String(decoding: rawData[Int(e.valueStart) ..< Int(e.valueEnd)], as: UTF8.self)
  }

  /// 下標存取。
  subscript(key: String) -> String? {
    valuesFor(key: key)
  }

  /// 檢查是否含有指定 key。
  func containsKey(_ key: String) -> Bool {
    binarySearchIndex(for: key) != nil
  }
}

// MARK: - CassetteOctagramMap: Binary Search

nonisolated extension LMAssembly.CassetteOctagramMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  /// 查詢頻次。
  subscript(key: String) -> Int? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    return Int(entries[idx].count)
  }
}

nonisolated extension LMAssembly.CassetteOctagramDividedMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  /// 查詢 (頻次, 讀音)。
  subscript(key: String) -> (Int, String)? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    let e = entries[idx]
    let reading = String(
      decoding: rawData[Int(e.readingStart) ..< Int(e.readingEnd)],
      as: UTF8.self
    )
    return (Int(e.count), reading)
  }
}

// MARK: - CassetteSortedMap Builder

nonisolated extension LMAssembly.CassetteSortedMap {
  /// 直接從 grouped Dictionary 建構 sorted map，避免中間 `map {}` 與巢狀暫存陣列。
  static func build(from dictionary: [String: [String]]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    var totalBytes = 0
    var totalValueCount = 0
    for (key, values) in dictionary {
      totalBytes += key.utf8.count
      totalValueCount += values.count
      for value in values { totalBytes += value.utf8.count }
    }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var rawData = [UInt8]()
    rawData.reserveCapacity(totalBytes)
    var entries = [LMAssembly.CassetteMapEntry]()
    entries.reserveCapacity(sortedKeys.count)
    var valueOffsets = [UInt32]()
    valueOffsets.reserveCapacity(totalValueCount * 2)
    for key in sortedKeys {
      guard let values = dictionary[key] else { continue }
      let keyStart = UInt32(rawData.count)
      rawData.append(contentsOf: key.utf8)
      let keyEnd = UInt32(rawData.count)
      let valuesStart = UInt32(valueOffsets.count)
      for value in values {
        let valueStart = UInt32(rawData.count)
        rawData.append(contentsOf: value.utf8)
        valueOffsets.append(valueStart)
        valueOffsets.append(UInt32(rawData.count))
      }
      let valuesEnd = UInt32(valueOffsets.count)
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        valuesStart: valuesStart,
        valuesEnd: valuesEnd
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    result.valueOffsets = valueOffsets
    return result
  }
}

// MARK: - CassetteReverseIndex Builder & Query

nonisolated extension LMAssembly.CassetteReverseIndex {
  /// 反查記錄原型：value bytes 留在來源 map 的 rawData 內，僅記範圍與來源 entry 索引。
  private struct RevPrototype {
    let valueStart: UInt32
    let valueEnd: UInt32
    /// 合併 namespace 的來源 entry 索引（charDef 在前、symbolDef 接續）。
    let ref: UInt32
    let isSymbol: Bool
  }

  /// 直接自既有的 charDefMap / symbolDefMap 建置零複製反查索引。
  /// 涵蓋兩張 map 的全部 entries（含花牌 pattern keys），與舊版自暫存辭典建置的語義等價。
  static func build(
    charDefMap: LMAssembly.CassetteSortedMap,
    symbolDefMap: LMAssembly.CassetteSortedMap
  )
    -> Self {
    var prototypes: [RevPrototype] = []
    var totalValueCount = 0
    for e in charDefMap.entries { totalValueCount += (Int(e.valuesEnd) - Int(e.valuesStart)) / 2 }
    for e in symbolDefMap.entries { totalValueCount += (Int(e.valuesEnd) - Int(e.valuesStart)) / 2 }
    prototypes.reserveCapacity(totalValueCount)
    for (entryIndex, e) in charDefMap.entries.enumerated() {
      for slot in stride(from: Int(e.valuesStart), to: Int(e.valuesEnd), by: 2) {
        prototypes.append(.init(
          valueStart: charDefMap.valueOffsets[slot],
          valueEnd: charDefMap.valueOffsets[slot + 1],
          ref: UInt32(entryIndex),
          isSymbol: false
        ))
      }
    }
    let charDefEntryCount = UInt32(charDefMap.entries.count)
    for (entryIndex, e) in symbolDefMap.entries.enumerated() {
      for slot in stride(from: Int(e.valuesStart), to: Int(e.valuesEnd), by: 2) {
        prototypes.append(.init(
          valueStart: symbolDefMap.valueOffsets[slot],
          valueEnd: symbolDefMap.valueOffsets[slot + 1],
          ref: charDefEntryCount + UInt32(entryIndex),
          isSymbol: true
        ))
      }
    }
    guard !prototypes.isEmpty else { return .init() }
    // 依 value bytes 字典序排序；同 value 時依 ref 升冪（確定性順序：charDef 先、各依碼 bytes 序）。
    prototypes.sort { lhs, rhs in
      let lhsData = lhs.isSymbol ? symbolDefMap.rawData : charDefMap.rawData
      let rhsData = rhs.isSymbol ? symbolDefMap.rawData : charDefMap.rawData
      let cmp = lhsData.compareByteRange(
        Int(lhs.valueStart) ..< Int(lhs.valueEnd),
        with: rhsData,
        in: Int(rhs.valueStart) ..< Int(rhs.valueEnd)
      )
      return cmp != 0 ? cmp < 0 : lhs.ref < rhs.ref
    }
    var revChars = [UInt8]()
    var revEntries = [LMAssembly.CassetteReverseEntry]()
    var revCodeRefs = [UInt32]()
    revCodeRefs.reserveCapacity(prototypes.count)
    var index = 0
    while index < prototypes.count {
      let current = prototypes[index]
      let currentData = current.isSymbol ? symbolDefMap.rawData : charDefMap.rawData
      let charStart = UInt32(revChars.count)
      revChars.append(contentsOf: currentData[Int(current.valueStart) ..< Int(current.valueEnd)])
      let charEnd = UInt32(revChars.count)
      let refsStart = UInt32(revCodeRefs.count)
      while index < prototypes.count {
        let next = prototypes[index]
        let nextData = next.isSymbol ? symbolDefMap.rawData : charDefMap.rawData
        let isSameValue = currentData.compareByteRange(
          Int(current.valueStart) ..< Int(current.valueEnd),
          with: nextData,
          in: Int(next.valueStart) ..< Int(next.valueEnd)
        ) == 0
        guard isSameValue else { break }
        revCodeRefs.append(next.ref)
        index += 1
      }
      revEntries.append(.init(
        charStart: charStart,
        charEnd: charEnd,
        refsStart: refsStart,
        refsEnd: UInt32(revCodeRefs.count)
      ))
    }
    var result = Self()
    result.revChars = revChars
    result.revEntries = revEntries
    result.revCodeRefs = revCodeRefs
    result.charDefEntryCount = charDefEntryCount
    return result
  }

  /// 二分搜尋反查字詞，回傳對應的碼 refs 範圍。
  fileprivate func refsRange(for value: String) -> Range<Int>? {
    let valueUTF8 = Array(value.utf8)
    var lo = 0, hi = revEntries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = revEntries[mid]
      let cmp = revChars.compareByteRange(Int(e.charStart) ..< Int(e.charEnd), with: valueUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else {
        return Int(e.refsStart) ..< Int(e.refsEnd)
      }
    }
    return nil
  }
}

// MARK: - CassetteQuickMap Builder

nonisolated extension LMAssembly.CassetteQuickMap {
  static func build(from dictionary: [String: String]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var totalBytes = 0
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      totalBytes += key.utf8.count + value.utf8.count
    }
    var rawData = [UInt8]()
    rawData.reserveCapacity(totalBytes)
    var entries = [LMAssembly.CassetteQuickEntry]()
    entries.reserveCapacity(sortedKeys.count)
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      let keyStart = UInt32(rawData.count)
      rawData.append(contentsOf: key.utf8)
      let keyEnd = UInt32(rawData.count)
      let valueStart = UInt32(rawData.count)
      rawData.append(contentsOf: value.utf8)
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        valueStart: valueStart,
        valueEnd: UInt32(rawData.count)
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    return result
  }
}

// MARK: - CassetteOctagramMap Builder

nonisolated extension LMAssembly.CassetteOctagramMap {
  static func build(from dictionary: [String: Int]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var totalBytes = 0
    for key in sortedKeys { totalBytes += key.utf8.count }
    var rawData = [UInt8]()
    rawData.reserveCapacity(totalBytes)
    var entries = [LMAssembly.CassetteOctagramEntry]()
    entries.reserveCapacity(sortedKeys.count)
    for key in sortedKeys {
      guard let count = dictionary[key] else { continue }
      let keyStart = UInt32(rawData.count)
      rawData.append(contentsOf: key.utf8)
      entries.append(.init(keyStart: keyStart, keyEnd: UInt32(rawData.count), count: UInt32(count)))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    return result
  }
}

nonisolated extension LMAssembly.CassetteOctagramDividedMap {
  static func build(from dictionary: [String: (Int, String)]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var totalBytes = 0
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      totalBytes += key.utf8.count + value.1.utf8.count
    }
    var rawData = [UInt8]()
    rawData.reserveCapacity(totalBytes)
    var entries = [LMAssembly.CassetteOctagramDividedEntry]()
    entries.reserveCapacity(sortedKeys.count)
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      let keyStart = UInt32(rawData.count)
      rawData.append(contentsOf: key.utf8)
      let keyEnd = UInt32(rawData.count)
      let readingStart = UInt32(rawData.count)
      rawData.append(contentsOf: value.1.utf8)
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        count: UInt32(value.0),
        readingStart: readingStart,
        readingEnd: UInt32(rawData.count)
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    return result
  }
}

// MARK: - LMCassette Public API

nonisolated extension LMAssembly.LMCassette {
  /// 計算頻率時要用到的東西 - fscale
  private static let fscale = 2.7
  /// 萬用花牌字符，哪怕花牌鍵仍不可用。
  var wildcard: String { wildcardKey.isEmpty ? "†" : wildcardKey }
  /// 任意單字元鍵，哪怕其仍不可用。
  var anySingleChar: String { anySingleCharKey.isEmpty ? "†" : anySingleCharKey }
  /// 資料陣列內承載的核心 charDef 資料筆數（唯一 key 數量）。
  var count: Int { charDefMap.count }
  /// 是否已有資料載入。
  var isLoaded: Bool { !charDefMap.isEmpty }
  /// 返回「允許使用的敲字鍵」的陣列。
  var allowedKeys: [String] { Array(keyNameMap.keys + [" "]).deduplicated }
  /// 將給定的按鍵字母轉換成要顯示的形態。
  func convertKeyToDisplay(char: String) -> String {
    keyNameMap[char] ?? char
  }

  /// 字→碼反向查詢（chardef + symboldef 合併 namespace）。
  /// 碼字串自來源 map 的既有 rawData 按需物化，順序為確定性（charDef 先、各依碼 bytes 序）。
  /// - Parameter value: 要拿來反查的字詞。
  /// - Returns: 對應的碼字串陣列；無結果時回傳 nil。
  func reverseCodes(for value: String) -> [String]? {
    guard let refsRange = reverseIndex.refsRange(for: value) else { return nil }
    let charDefEntryCount = Int(reverseIndex.charDefEntryCount)
    var codes = [String]()
    codes.reserveCapacity(refsRange.count)
    for i in refsRange {
      let ref = Int(reverseIndex.revCodeRefs[i])
      if ref < charDefEntryCount {
        let e = charDefMap.entries[ref]
        codes.append(String(
          decoding: charDefMap.rawData[Int(e.keyStart) ..< Int(e.keyEnd)],
          as: UTF8.self
        ))
      } else {
        let e = symbolDefMap.entries[ref - charDefEntryCount]
        codes.append(String(
          decoding: symbolDefMap.rawData[Int(e.keyStart) ..< Int(e.keyEnd)],
          as: UTF8.self
        ))
      }
    }
    return codes.isEmpty ? nil : codes
  }

  /// 載入給定的 CIN 檔案內容。
  /// - Note:
  /// - 檢查是否以 `%gen_inp` 或者 `%ename` 開頭、以確認其是否為 cin 檔案。在讀到這些資訊之前的行都會被忽略。
  /// - `%ename` 決定磁帶的英文名、`%cname` 決定磁帶的 CJK 名稱、
  /// `%sname` 決定磁帶的最短英文縮寫名稱、`%intlname` 決定磁帶的本地化名稱綜合字串。
  /// - `%encoding` 不處理，因為 Swift 只認 UTF-8。
  /// - `%selkey` 不處理，因為唯音輸入法有自己的選字鍵體系。
  /// - `%endkey` 是會觸發組字事件的按鍵。
  /// - `%wildcardkey` 決定磁帶的萬能鍵名稱，只有第一個字元會生效。
  /// - `%anysinglecharkey` 決定磁帶的任意單字元鍵名稱，只有第一個字元會生效，且不得與 `%wildcardkey` 相同。
  /// - `%nullcandidate` 用來指明 `%quick` 字段給出的候選字當中有哪一種是無效的。
  /// - `%keyname begin` 至 `%keyname end` 之間是字根翻譯表，先讀取為 Swift 辭典以備用。
  /// - `%quick begin` 至 `%quick end` 之間則是簡碼資料，對應的 value 得拆成單個漢字。
  /// - `%chardef begin` 至 `%chardef end` 之間則是詞庫資料。
  /// - `%symboldef begin` 至 `%symboldef end` 之間則是符號選單的專用資料。
  /// - `%octagram begin` 至 `%octagram end` 之間則是詞語頻次資料。
  /// 第三欄資料為對應字根、可有可無。第一欄與第二欄分別為「字詞」與「統計頻次」。
  /// - Parameter path: 檔案路徑。
  /// - Returns: 是否載入成功。
  @discardableResult
  mutating func open(_ path: String) -> Bool {
    if isLoaded { return false }
    let oldPath = filePath
    filePath = nil
    if FileManager.default.fileExists(atPath: path) {
      do {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
          throw LMAssembly.FileErrors.fileHandleError("")
        }
        let lineIterator = ByteLineIterator(file: fileHandle)
        var theMaxKeyLength = 1
        var loadingKeys = false

        // 僅保留必要的 grouped Dictionary；reverse / wildcard / quickDef / quickPhrase 改在建構期以輕量 prototype 直接生成。
        var tmpCharDef = [String: [String]]()
        var tmpSymbolDef = [String: [String]]()
        var tmpOctagram = [String: Int]()
        var tmpOctagramDivided = [String: (Int, String)]()
        // quickDef / quickPhrase 改為 tmp Dictionary → contiguous-memory index
        var tmpQuickDef = [String: String]()
        var tmpQuickPhraseMap = [String: [String]]()

        var loadingQuickSets = false {
          willSet {
            supplyQuickResults = true
            if !newValue, tmpQuickDef.keys.contains(wildcardKey) { wildcardKey = "" }
            if !newValue, tmpQuickDef.keys.contains(anySingleCharKey) { anySingleCharKey = "" }
          }
        }
        var loadingCharDefinitions = false {
          willSet {
            if !newValue, tmpCharDef.keys.contains(wildcardKey) { wildcardKey = "" }
            if !newValue, tmpCharDef.keys.contains(anySingleCharKey) { anySingleCharKey = "" }
          }
        }
        var loadingSymbolDefinitions = false {
          willSet {
            if !newValue, tmpSymbolDef.keys.contains(wildcardKey) { wildcardKey = "" }
            if !newValue, tmpSymbolDef.keys.contains(anySingleCharKey) { anySingleCharKey = "" }
          }
        }
        var loadingOctagramData = false
        var loadingQuickPhrases = false
        var keysUsedInCharDef: Set<String> = .init()

        while let lineSlice = lineIterator.nextLine() {
          let strLine = String(decoding: lineSlice, as: UTF8.self)
          let isTabDelimiting = strLine.contains("\t")
          let cells = isTabDelimiting
            ? strLine.split(separator: "\t")
            : strLine.split(separator: " ")
          guard cells.count >= 1 else { continue }
          let strFirstCell = cells[0].trimmingCharacters(in: .newlines)
          let strSecondCell = cells.count >= 2
            ? cells[1].trimmingCharacters(in: .newlines) : nil

          // 處理 Metadata：CIN2 以 `%section begin` / `%section end` 界定段落，
          // 段落外僅 `%flag_disp_partial_match` 等特徵字串會被處理，其餘被無視。
          if strLine.first == "%", strFirstCell != "%" {
            // %flag_disp_partial_match
            if strLine == "%flag_disp_partial_match" {
              supplyPartiallyMatchedResults = true
              supplyQuickResults = true
            }
            guard let strSecondCell = strSecondCell else { continue }
            processTags: switch strFirstCell {
            case "%keyname" where strSecondCell == "begin": loadingKeys = true
            case "%keyname" where strSecondCell == "end": loadingKeys = false
            case "%quick" where strSecondCell == "begin": loadingQuickSets = true
            case "%quick" where strSecondCell == "end": loadingQuickSets = false
            case "%chardef" where strSecondCell == "begin": loadingCharDefinitions = true
            case "%chardef" where strSecondCell == "end": loadingCharDefinitions = false
            case "%symboldef" where strSecondCell == "begin": loadingSymbolDefinitions = true
            case "%symboldef" where strSecondCell == "end": loadingSymbolDefinitions = false
            case "%octagram" where strSecondCell == "begin": loadingOctagramData = true
            case "%octagram" where strSecondCell == "end": loadingOctagramData = false
            case "%quickphrases" where strSecondCell == "begin": loadingQuickPhrases = true
            case "%quickphrases" where strSecondCell == "end": loadingQuickPhrases = false
            case "%ename" where nameENG.isEmpty:
              parseSubCells: for neta in strSecondCell.components(separatedBy: ";") {
                let subNetaGroup = neta.components(separatedBy: ":")
                guard subNetaGroup.count == 2, subNetaGroup[1].contains("en") else { continue }
                nameENG = String(subNetaGroup[0])
                break parseSubCells
              }
              guard nameENG.isEmpty else { break processTags }
              nameENG = strSecondCell
            case "%intlname"
              where nameIntl.isEmpty: nameIntl = strSecondCell
              .replacingOccurrences(of: "_", with: " ")
            case "%cname" where nameCJK.isEmpty: nameCJK = strSecondCell
            case "%sname" where nameShort.isEmpty: nameShort = strSecondCell
            case "%nullcandidate" where nullCandidate.isEmpty: nullCandidate = strSecondCell
            case "%selkey"
              where selectionKeys.isEmpty: selectionKeys = strSecondCell.map(\.description)
              .deduplicated.joined()
            case "%endkey"
              where endKeys.isEmpty: endKeys = strSecondCell.map(\.description).deduplicated
            case "%wildcardkey"
              where wildcardKey.isEmpty && strSecondCell.first?.description != anySingleCharKey:
              wildcardKey = strSecondCell.first?.description ?? ""
            case "%anysinglecharkey"
              where anySingleCharKey.isEmpty && strSecondCell.first?.description != wildcardKey:
              anySingleCharKey = strSecondCell.first?.description ?? ""
            case "%keys_to_directly_commit"
              where keysToDirectlyCommit.isEmpty: keysToDirectlyCommit = strSecondCell
            case "%quickphrases_commission_key"
              where quickPhraseCommissionKey.isEmpty:
              quickPhraseCommissionKey = strSecondCell.first?.description ?? ""
            default: break processTags
            }
            continue
          }

          // 處理普通資料
          guard let strSecondCell = strSecondCell else { continue }
          if loadingKeys {
            keyNameMap[strFirstCell] = strSecondCell.trimmingCharacters(in: .newlines)
          } else if loadingQuickSets {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            // accumulate into tmpQuickDef
            let existing = tmpQuickDef[strFirstCell] ?? ""
            tmpQuickDef[strFirstCell] = existing + strSecondCell
          } else if loadingQuickPhrases {
            theMaxKeyLength = max(theMaxKeyLength, strFirstCell.count)
            var remainderLine = strLine.trimmingCharacters(in: .newlines)
            if remainderLine.hasPrefix(strFirstCell) {
              remainderLine.removeFirst(strFirstCell.count)
            }
            let trimmedRemainder = remainderLine.drop(while: { $0 == "\t" || $0 == " " })
            let remainderString = String(trimmedRemainder)
            var phraseCandidates: [String] = []
            if isTabDelimiting {
              phraseCandidates = remainderString.split(separator: "\t").map {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              }
            } else {
              let trimmed = remainderString
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              if !trimmed.isEmpty { phraseCandidates = [trimmed] }
            }
            let sanitized = phraseCandidates
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
            guard !sanitized.isEmpty else { continue }
            var phrases = tmpQuickPhraseMap[strFirstCell, default: []]
            phrases.append(contentsOf: sanitized)
            phrases = phrases
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
              .deduplicated
            tmpQuickPhraseMap[strFirstCell] = phrases
          } else if loadingCharDefinitions, !loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            tmpCharDef[strFirstCell, default: []].append(strSecondCell)
            if strFirstCell.count > 1 {
              strFirstCell.map(\.description).forEach { keyChar in
                keysUsedInCharDef.insert(keyChar.description)
              }
            }
          } else if loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            tmpSymbolDef[strFirstCell, default: []].append(strSecondCell)
          } else if loadingOctagramData {
            guard let countValue = Int(strSecondCell) else { continue }
            switch cells.count {
            case 2: tmpOctagram[strFirstCell] = countValue
            case 3: tmpOctagramDivided[strFirstCell] = (
                countValue,
                cells[2].trimmingCharacters(in: .newlines)
              )
            default: break
            }
            let powResult = pow(Self.fscale, Double(cells[0].count) / 3.0 - 1.0)
            norm += powResult * Double(countValue)
          }
        }
        // Post process.
        if !candidateKeysValidator(selectionKeys) { selectionKeys = "1234567890" }
        if !keysUsedInCharDef.intersection(selectionKeys.map(\.description)).isEmpty {
          areCandidateKeysShiftHeld = true
        }
        maxKeyLength = theMaxKeyLength
        keyNameMap[wildcardKey] = keyNameMap[wildcardKey] ?? "♧"
        if !anySingleCharKey.isEmpty {
          keyNameMap[anySingleCharKey] = keyNameMap[anySingleCharKey] ?? "⍰"
        }

        // 直接從 grouped Dictionary 建構最終索引，含 quickDef / quickPhrase。
        charDefMap = .build(from: tmpCharDef)
        symbolDefMap = .build(from: tmpSymbolDef)
        reverseIndex = .build(charDefMap: charDefMap, symbolDefMap: symbolDefMap)
        octagramMap = .build(from: tmpOctagram)
        octagramDividedMap = .build(from: tmpOctagramDivided)
        quickDefMap = .build(from: tmpQuickDef)
        quickPhraseMap = .build(from: tmpQuickPhraseMap)

        // 暫存辭典的階段性任務已結束，即刻釋放以降低載入期峰值。
        tmpCharDef.removeAll(keepingCapacity: false)
        tmpSymbolDef.removeAll(keepingCapacity: false)
        tmpOctagram.removeAll(keepingCapacity: false)
        tmpOctagramDivided.removeAll(keepingCapacity: false)
        tmpQuickDef.removeAll(keepingCapacity: false)
        tmpQuickPhraseMap.removeAll(keepingCapacity: false)

        filePath = path
        return true
      } catch {
        vCLMLog("CIN Loading Failed: File Access Error.")
      }
    } else {
      vCLMLog("CIN Loading Failed: File Missing.")
    }
    filePath = oldPath
    return false
  }

  mutating func clear() {
    keyNameMap.removeAll(keepingCapacity: false)
    quickDefMap = .init()
    quickPhraseMap = .init()
    endKeys.removeAll(keepingCapacity: false)
    // 重置 sorted maps。
    charDefMap = .init()
    symbolDefMap = .init()
    reverseIndex = .init()
    octagramMap = .init()
    octagramDividedMap = .init()
    // 重置為初始狀態
    self = .init()
  }

  func quickSetsFor(key: String) -> String? {
    guard !key.isEmpty else { return nil }
    var result = [String]()
    if let specifiedResult = quickDefMap.valuesFor(key: key), !specifiedResult.isEmpty {
      result.append(contentsOf: specifiedResult.map(\.description))
    }
    if supplyQuickResults, result.isEmpty {
      if supplyPartiallyMatchedResults {
        // 改用 sorted map 的前綴掃描。
        let fetched = charDefMap.prefixScan(prefix: key)
          .sorted { $0.key.count < $1.key.count }
          .flatMap(\.values)
          .filter { $0.count == 1 }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      } else {
        let fetched = (charDefMap.valuesFor(key: key) ?? []).filter { $0.count == 1 }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      }
    }
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func quickPhrasesFor(key: String) -> [String]? {
    guard !key.isEmpty else { return nil }
    guard let phrases = quickPhraseMap.valuesFor(key: key)?
      .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
      .filter({ !$0.isEmpty }) else { return nil }
    let sanitized = phrases.filter { $0 != nullCandidate }.deduplicated
    return sanitized.isEmpty ? nil : sanitized
  }

  /// 根據給定的字根索引鍵，來獲取資料庫辭典內的對應結果。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func unigramsFor(key: String, keyArray: [String]? = nil) -> [Homa.Gram] {
    let keyArray = keyArray ?? key.split(separator: "-").map(\.description)
    let arrRaw = (charDefMap.valuesFor(key: key) ?? []).deduplicated
    var arrRawWildcard: [String] = []
    if key.contains(wildcard) || key.contains(anySingleChar) {
      if let arrRawWildcardValues = charDefMap.patternValuesFor(
        key: key,
        wildcard: wildcard,
        anySingleChar: anySingleChar
      )?.deduplicated {
        arrRawWildcard.append(contentsOf: arrRawWildcardValues)
      }
    }
    var arrResults = [Homa.Gram]()
    var lowestScore: Double = 0
    for neta in arrRaw {
      let theScore: Double = {
        if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
          return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
        } else if let freqData = octagramMap[neta] {
          return calculateWeight(count: freqData, phraseLength: neta.count)
        }
        return Double(arrResults.count) * -0.001 - 9.5
      }()
      lowestScore = min(theScore, lowestScore)
      arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
    }
    lowestScore = min(-9.5, lowestScore)
    if !arrRawWildcard.isEmpty {
      for neta in arrRawWildcard {
        var theScore: Double = {
          if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
            return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
          } else if let freqData = octagramMap[neta] {
            return calculateWeight(count: freqData, phraseLength: neta.count)
          }
          return Double(arrResults.count) * -0.001 - 9.7
        }()
        theScore += lowestScore
        arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
      }
    }
    return arrResults
  }

  /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func hasUnigramsFor(key: String) -> Bool {
    if charDefMap.containsKey(key) { return true }
    guard key.contains(wildcard) || key.contains(anySingleChar) else { return false }
    return charDefMap.containsPatternMatch(
      key: key,
      wildcard: wildcard,
      anySingleChar: anySingleChar
    )
  }

  // MARK: - Private Functions.

  private func calculateWeight(count theCount: Int, phraseLength: Int) -> Double {
    var weight: Double = 0
    switch theCount {
    case -2: // 拗音假名
      weight = -13
    case -1: // 單個假名
      weight = -13
    case 0: // 墊底低頻漢字與詞語
      weight = log10(
        pow(Self.fscale, Double(phraseLength) / 3.0 - 1.0) * 0.25 / norm
      )
    default:
      weight = log10(
        pow(Self.fscale, Double(phraseLength) / 3.0 - 1.0) * Double(theCount) / norm
      )
    }
    return weight
  }
}
