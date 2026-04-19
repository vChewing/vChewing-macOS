// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import SwiftExtension

// MARK: - FactoryTextMapLexicon

final class FactoryTextMapLexicon: @unchecked Sendable {
  // MARK: Lifecycle

  init(textMapData: Data) throws {
    self.textMapData = textMapData

    let bounds = try Self.locateSectionBounds(in: textMapData)
    let headerSlice = textMapData[bounds.headerContentStart ..< bounds.valuesPragmaStart]
    let headerInfo = Self.parseHeader(String(decoding: headerSlice, as: UTF8.self))

    self.isTyping = headerInfo.isTyping
    self.defaultProbs = headerInfo.defaultProbs
    self.readingSeparator = headerInfo.separator
    self.valueLineOffsets = Self.scanValueLineOffsets(
      in: textMapData,
      start: bounds.valuesContentStart,
      end: bounds.keyMapPragmaStart
    )
    self.valuesEndOffset = bounds.keyMapPragmaStart

    self.sortedKeyEntries = Self.parseKeyMapBytes(
      in: textMapData,
      from: bounds.keyMapContentStart,
      to: textMapData.count
    )
    self.valueLineToKeyEntryIndex = Self.buildLineOwnerIndex(
      keyEntries: sortedKeyEntries,
      valueLineCount: valueLineOffsets.count
    )

    // RevLookup 一律由 MainTextMap 自動生成，不再接受 external revlookup payload。
    self.reverseLookupTable = Self.buildReverseLookupFromKeyEntries(
      textMapData: textMapData,
      keyEntries: sortedKeyEntries,
      valueLineOffsets: valueLineOffsets,
      valuesEndOffset: valuesEndOffset,
      isTyping: isTyping,
      defaultProbs: defaultProbs,
      readingSeparator: readingSeparator
    )
    cachedEntries.countLimit = 8_192
  }

  // MARK: Internal

  struct Entry: Sendable {
    let value: String
    let typeID: Int32
    let probability: Double
  }

  func exactEntries(for key: String) -> [Entry] {
    guard let index = binarySearchIndex(for: key) else { return [] }
    return parsedEntries(for: sortedKeyEntries[index])
  }

  func supersetEntries(containing subsetKey: String) -> [(key: String, entries: [Entry])] {
    let subsetComponents = splitKey(subsetKey)
    guard !subsetComponents.isEmpty else { return [] }

    return sortedKeyEntries.compactMap { currentEntry in
      let currentKey = resolveKey(for: currentEntry)
      let currentComponents = splitKey(currentKey)
      guard currentComponents.count > subsetComponents.count else { return nil }
      guard currentKey != subsetKey else { return nil }
      guard Self.containsContiguousSubsequence(currentComponents, needle: subsetComponents) else { return nil }
      return (currentKey, parsedEntries(for: currentEntry))
    }
  }

  func reverseLookup(for kanji: String) -> [String]? {
    let kanjiUTF8 = Array(kanji.utf8)
    var lo = 0
    var hi = reverseLookupTable.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let entry = reverseLookupTable[mid]
      let cmp = entry.key.withUnsafeBufferPointer { buf in
        compareUTF8(buf, kanjiUTF8)
      }
      if cmp < 0 {
        lo = mid + 1
      } else if cmp > 0 {
        hi = mid - 1
      } else {
        return parsedReadings(from: entry.lineIndices)
      }
    }
    return nil
  }

  // MARK: Private

  private struct RevLookupEntry: Sendable {
    let key: ContiguousArray<UInt8> // 漢字字符的 UTF-8 bytes
    let lineIndices: [Int] // 指向 valueLineOffsets 的索引
  }

  private struct KeyEntry: Sendable {
    let keyStart: Int
    let keyEnd: Int
    let startLine: Int
    let count: Int
  }

  private struct HeaderInfo {
    let separator: Character
    let isTyping: Bool
    let defaultProbs: [Int32: Double]
  }

  private struct SectionBounds {
    let headerContentStart: Int
    let valuesPragmaStart: Int
    let valuesContentStart: Int
    let keyMapPragmaStart: Int
    let keyMapContentStart: Int
  }

  private final class CachedEntriesBox: NSObject {
    // MARK: Lifecycle

    init(_ value: [Entry]) {
      self.value = value
    }

    // MARK: Internal

    let value: [Entry]
  }

  private static let groupedCellSeparator: Character = "|"
  private static let groupedCellEscape: Character = #"\"#
  private static let emptyGroupedCellPlaceholder: Character = "\u{7}"

  private let textMapData: Data
  private let isTyping: Bool
  private let defaultProbs: [Int32: Double]
  private let readingSeparator: Character
  private let valueLineOffsets: [Int]
  private let valuesEndOffset: Int
  private let sortedKeyEntries: [KeyEntry]
  private let valueLineToKeyEntryIndex: [Int32]
  private let reverseLookupTable: [RevLookupEntry]
  private let cachedEntries = NSCache<NSString, CachedEntriesBox>()

  private static func locateSectionBounds(in data: Data) throws -> SectionBounds {
    let headerPragma = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER".utf8)
    let valuesPragma = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES".utf8)
    let keyMapPragma = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP".utf8)

    var headerContentStart: Int?
    var valuesPragmaStart: Int?
    var valuesContentStart: Int?
    var keyMapPragmaStart: Int?
    var keyMapContentStart: Int?

    data.withUnsafeBytes { buf in
      let total = buf.count
      var i = 0
      while i < total {
        let lineStart = i
        while i < total, buf[i] != 0x0A { i += 1 }
        let nextLineStart = Swift.min(i + 1, total)
        if buf[lineStart] == 0x23 { // '#'
          // Trim trailing \r before comparison (CRLF tolerance).
          var lineEnd = i
          if lineEnd > lineStart, buf[lineEnd - 1] == 0x0D { lineEnd -= 1 }
          let lineLen = lineEnd - lineStart
          if matchPragmaBytes(buf, offset: lineStart, length: lineLen, pragma: headerPragma) {
            headerContentStart = nextLineStart
          } else if matchPragmaBytes(buf, offset: lineStart, length: lineLen, pragma: valuesPragma) {
            valuesPragmaStart = lineStart
            valuesContentStart = nextLineStart
          } else if matchPragmaBytes(buf, offset: lineStart, length: lineLen, pragma: keyMapPragma) {
            keyMapPragmaStart = lineStart
            keyMapContentStart = nextLineStart
          }
        }
        i = nextLineStart
      }
    }

    guard let headerContentStart,
          let valuesPragmaStart,
          let valuesContentStart,
          let keyMapPragmaStart,
          let keyMapContentStart
    else {
      throw NSError(
        domain: "FactoryTextMapLexicon",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "TextMap file is missing required pragma sections."]
      )
    }

    return .init(
      headerContentStart: headerContentStart,
      valuesPragmaStart: valuesPragmaStart,
      valuesContentStart: valuesContentStart,
      keyMapPragmaStart: keyMapPragmaStart,
      keyMapContentStart: keyMapContentStart
    )
  }

  private static func matchPragmaBytes(
    _ buf: UnsafeRawBufferPointer, offset: Int, length: Int, pragma: [UInt8]
  )
    -> Bool {
    guard length == pragma.count else { return false }
    for j in 0 ..< length {
      if buf[offset + j] != pragma[j] { return false }
    }
    return true
  }

  private static func parseHeader(_ rawHeader: String) -> HeaderInfo {
    var separator: Character = "-"
    var isTyping = false
    var defaultProbs: [Int32: Double] = [:]

    rawHeader.enumerateLines { line, _ in
      let columns = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
      guard columns.count >= 2 else { return }
      switch columns[0] {
      case "READING_SEPARATOR":
        if let character = columns[1].first {
          separator = character
        }
      case "TYPE":
        isTyping = columns[1] == "TYPING"
      default:
        guard columns[0].hasPrefix("DEFAULT_PROB_") else { return }
        let suffix = columns[0].dropFirst("DEFAULT_PROB_".count)
        guard let typeID = Int32(suffix), let probability = Double(columns[1]) else { return }
        defaultProbs[typeID] = probability
      }
    }

    return .init(separator: separator, isTyping: isTyping, defaultProbs: defaultProbs)
  }

  private static func scanValueLineOffsets(in data: Data, start: Int, end: Int) -> [Int] {
    guard end > start else { return [] }
    var offsets: [Int] = [start]
    for index in start ..< end where data[index] == 0x0A {
      let next = index + 1
      if next < end {
        offsets.append(next)
      }
    }
    return offsets
  }

  private static func parseKeyMapBytes(in data: Data, from start: Int, to end: Int) -> [KeyEntry] {
    var entries: [KeyEntry] = []
    var lineStart = start
    let tab = UInt8(0x09)
    let newline = UInt8(0x0A)

    for index in start ... end {
      if index == end || data[index] == newline {
        guard index > lineStart else {
          lineStart = index + 1
          continue
        }
        // Find first tab (end of key)
        var firstTab: Int?
        var secondTab: Int?
        for cursor in lineStart ..< index {
          if data[cursor] == tab {
            if firstTab == nil {
              firstTab = cursor
            } else {
              secondTab = cursor
              break
            }
          }
        }
        if let firstTab, let secondTab {
          let startLineStr = String(decoding: data[(firstTab + 1) ..< secondTab], as: UTF8.self)
          let countEnd = Swift.min(index, end)
          var countEndTrimmed = countEnd
          while countEndTrimmed > secondTab + 1, data[countEndTrimmed - 1] == 0x0D {
            countEndTrimmed -= 1
          }
          let countStr = String(decoding: data[(secondTab + 1) ..< countEndTrimmed], as: UTF8.self)
          if let startLine = Int(startLineStr), let count = Int(countStr) {
            entries.append(KeyEntry(keyStart: lineStart, keyEnd: firstTab, startLine: startLine, count: count))
          }
        }
        lineStart = index + 1
      }
    }

    entries.sort { lhs, rhs in
      data.compareUTF8Ranges(lhs.keyStart ..< lhs.keyEnd, rhs.keyStart ..< rhs.keyEnd) < 0
    }
    return entries
  }

  // 從 KeyEntries 建立 RevLookup 索引（漢字→line indices）
  private static func buildReverseLookupFromKeyEntries(
    textMapData: Data,
    keyEntries: [KeyEntry],
    valueLineOffsets: [Int],
    valuesEndOffset: Int,
    isTyping: Bool,
    defaultProbs: [Int32: Double],
    readingSeparator: Character
  )
    -> [RevLookupEntry] {
    // 單一讀音的 `@` 行納入 ideographic 字符；CNS 條目則一律納入。
    var charToLineIndices: [String: [Int]] = [:]

    // 遍歷每個 reading key 及其對應的 VALUES 行
    for keyEntry in keyEntries {
      let readingKey = String(decoding: textMapData[keyEntry.keyStart ..< keyEntry.keyEnd], as: UTF8.self)
      let segmentCount = readingKey.split(separator: readingSeparator).count

      // 解析該 reading key 對應的所有 VALUES 行
      let lastLine = Swift.min(keyEntry.startLine + keyEntry.count, valueLineOffsets.count)
      for lineIndex in keyEntry.startLine ..< lastLine {
        let start: Int = valueLineOffsets[lineIndex]
        var end: Int = (lineIndex + 1 < valueLineOffsets.count)
          ? valueLineOffsets[lineIndex + 1] - 1
          : valuesEndOffset
        while end > start, [UInt8(0x0A), UInt8(0x0D)].contains(textMapData[end - 1]) {
          end -= 1
        }
        guard end > start else { continue }

        let line = String(decoding: textMapData[start ..< end], as: UTF8.self)
        let includeGroupedTypingLine = line.first == "@" && segmentCount == 1
        let entries = parseValueLine(line, isTyping: isTyping, defaultProbs: defaultProbs)

        for entry in entries {
          let charactersToIndex: [String] = if entry.typeID == 7 {
            entry.value.map(String.init)
          } else if includeGroupedTypingLine {
            entry.value.filter { currentCharacter in
              currentCharacter.unicodeScalars.contains { $0.properties.isIdeographic }
            }.map(String.init)
          } else {
            []
          }

          for character in charactersToIndex {
            charToLineIndices[character, default: []].append(lineIndex)
          }
        }
      }
    }

    // 轉換為排序後的 RevLookupEntry 陣列
    var result: [RevLookupEntry] = []
    for (character, lineIndices) in charToLineIndices {
      let sortedLineIndices = lineIndices.sorted()
      var deduplicatedLineIndices: [Int] = []
      deduplicatedLineIndices.reserveCapacity(sortedLineIndices.count)
      for currentLineIndex in sortedLineIndices where deduplicatedLineIndices.last != currentLineIndex {
        deduplicatedLineIndices.append(currentLineIndex)
      }
      result.append(RevLookupEntry(
        key: ContiguousArray(character.utf8),
        lineIndices: deduplicatedLineIndices
      ))
    }

    // 按 UTF-8 byte 排序
    result.sort { lhs, rhs in
      lhs.key.withUnsafeBufferPointer { lBuf in
        rhs.key.withUnsafeBufferPointer { rBuf in
          compareUTF8Buffers(lBuf, rBuf) < 0
        }
      }
    }

    return result
  }

  private static func parseValueLine(
    _ line: String,
    isTyping: Bool,
    defaultProbs: [Int32: Double]
  )
    -> [Entry] {
    guard !line.isEmpty else { return [] }
    let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard !columns.isEmpty else { return [] }

    if let first = columns.first, first.hasPrefix(">"), columns.count >= 2 {
      let rawType = first.dropFirst()
      guard let typeID = Int32(rawType), let probability = defaultProbs[typeID] else { return [] }
      return decodeGroupedCell(columns[1]).map {
        Entry(value: $0, typeID: typeID, probability: probability)
      }
    }

    if isTyping, columns.count >= 3, let probability = parseTypingGroupedProbability(columns[0]) {
      var result: [Entry] = []
      result
        .append(contentsOf: decodeGroupedCell(columns[1]).map { Entry(value: $0, typeID: 5, probability: probability) })
      result
        .append(contentsOf: decodeGroupedCell(columns[2]).map { Entry(value: $0, typeID: 6, probability: probability) })
      return result
    }

    if columns.count >= 3,
       let probability = Double(columns[1]),
       let typeID = Int32(columns[2]) {
      return [Entry(value: columns[0], typeID: typeID, probability: probability)]
    }

    if isTyping, columns.count >= 4 {
      var result: [Entry] = []
      if !columns[0].isEmpty, let probability = Double(columns[1]) {
        result.append(.init(value: columns[0], typeID: 5, probability: probability))
      }
      if !columns[2].isEmpty, let probability = Double(columns[3]) {
        result.append(.init(value: columns[2], typeID: 6, probability: probability))
      }
      if !result.isEmpty {
        return result
      }
    }

    if isTyping, columns.count >= 3, let probability = Double(columns[0]), isLegacyTypingGroupedLine(columns) {
      var result: [Entry] = []
      result
        .append(contentsOf: decodeGroupedCell(columns[1]).map { Entry(value: $0, typeID: 5, probability: probability) })
      result
        .append(contentsOf: decodeGroupedCell(columns[2]).map { Entry(value: $0, typeID: 6, probability: probability) })
      return result
    }

    return []
  }

  private static func parseTypingGroupedProbability(_ rawValue: String) -> Double? {
    guard rawValue.first == "@" else { return nil }
    return Double(String(rawValue.dropFirst()))
  }

  private static func isLegacyTypingGroupedLine(_ columns: [String]) -> Bool {
    guard columns.count >= 3, Double(columns[0]) != nil else { return false }
    if columns[1].isEmpty || columns[2].isEmpty { return true }
    if columns[1] == String(emptyGroupedCellPlaceholder) || columns[2] == String(emptyGroupedCellPlaceholder) {
      return true
    }
    return columns[1].contains(groupedCellSeparator)
      || columns[2].contains(groupedCellSeparator)
      || columns[1].contains(groupedCellEscape)
      || columns[2].contains(groupedCellEscape)
      || columns[1].contains(" ")
      || columns[2].contains(" ")
      || Int32(columns[2]) == nil
  }

  private static func decodeGroupedCell(_ rawCell: String) -> [String] {
    guard !rawCell.isEmpty, rawCell != String(emptyGroupedCellPlaceholder) else { return [] }
    if rawCell.contains(groupedCellSeparator) || rawCell.contains(groupedCellEscape) {
      return splitEscapedGroupedCell(rawCell).map(unescapeGroupedCell)
    }
    if rawCell.contains(" ") {
      return rawCell.split(separator: " ").map(String.init)
    }
    return [rawCell]
  }

  private static func splitEscapedGroupedCell(_ rawCell: String) -> [String] {
    var result: [String] = []
    var current = ""
    var isEscaping = false

    for character in rawCell {
      if isEscaping {
        current.append(groupedCellEscape)
        current.append(character)
        isEscaping = false
        continue
      }

      if character == groupedCellEscape {
        isEscaping = true
        continue
      }

      if character == groupedCellSeparator {
        result.append(current)
        current.removeAll(keepingCapacity: true)
        continue
      }

      current.append(character)
    }

    if isEscaping {
      current.append(groupedCellEscape)
    }
    result.append(current)
    return result
  }

  private static func unescapeGroupedCell(_ rawValue: String) -> String {
    var result = ""
    var isEscaping = false

    for character in rawValue {
      if isEscaping {
        switch character {
        case groupedCellEscape:
          result.append(groupedCellEscape)
        case groupedCellSeparator:
          result.append(groupedCellSeparator)
        case "s":
          result.append(" ")
        case "a":
          result.append(emptyGroupedCellPlaceholder)
        default:
          result.append(groupedCellEscape)
          result.append(character)
        }
        isEscaping = false
        continue
      }

      if character == groupedCellEscape {
        isEscaping = true
        continue
      }

      result.append(character)
    }

    if isEscaping {
      result.append(groupedCellEscape)
    }

    return result
  }

  private static func containsContiguousSubsequence(_ haystack: [String], needle: [String]) -> Bool {
    guard !needle.isEmpty, haystack.count >= needle.count else { return false }
    if haystack.count == needle.count {
      return haystack == needle
    }

    let lastStart = haystack.count - needle.count
    for start in 0 ... lastStart where Array(haystack[start ..< (start + needle.count)]) == needle {
      return true
    }
    return false
  }

  /// 建立 valueLineIndex → keyEntryIndex 對應表，使 parsedReadings 可 O(1) 查詢。
  private static func buildLineOwnerIndex(
    keyEntries: [KeyEntry],
    valueLineCount: Int
  )
    -> [Int32] {
    guard valueLineCount > 0 else { return [] }
    var lineOwners = Array(repeating: Int32(-1), count: valueLineCount)
    for (keyEntryIndex, keyEntry) in keyEntries.enumerated() {
      let end = min(keyEntry.startLine + keyEntry.count, valueLineCount)
      for lineIndex in keyEntry.startLine ..< end {
        lineOwners[lineIndex] = Int32(keyEntryIndex)
      }
    }
    return lineOwners
  }

  // 從 line indices 解析讀音（按需解析，避免提前物化）
  private func parsedReadings(from lineIndices: [Int]) -> [String] {
    var readings: [String] = []
    var seen: Set<String> = []
    for lineIndex in lineIndices {
      guard lineIndex >= 0, lineIndex < valueLineToKeyEntryIndex.count else { continue }
      let keyEntryIndex = Int(valueLineToKeyEntryIndex[lineIndex])
      guard keyEntryIndex >= 0, keyEntryIndex < sortedKeyEntries.count else { continue }
      let keyEntry = sortedKeyEntries[keyEntryIndex]
      let readingKey = LMAssembly.LMInstantiator.restorePhonabetFromASCII(
        String(decoding: textMapData[keyEntry.keyStart ..< keyEntry.keyEnd], as: UTF8.self)
      )
      if seen.insert(readingKey).inserted {
        readings.append(readingKey)
      }
    }
    return readings
  }

  private func splitKey(_ key: String) -> [String] {
    key.split(separator: readingSeparator).map(String.init)
  }

  private func resolveKey(for entry: KeyEntry) -> String {
    String(decoding: textMapData[entry.keyStart ..< entry.keyEnd], as: UTF8.self)
  }

  private func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0
    var hi = sortedKeyEntries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let midEntry = sortedKeyEntries[mid]
      let cmp = textMapData.compareUTF8Range(midEntry.keyStart ..< midEntry.keyEnd, with: keyUTF8)
      if cmp < 0 {
        lo = mid + 1
      } else if cmp > 0 {
        hi = mid - 1
      } else {
        return mid
      }
    }
    return nil
  }

  private func parsedEntries(for keyEntry: KeyEntry) -> [Entry] {
    let cacheKey = NSString(
      bytes: (textMapData as NSData).bytes.advanced(by: keyEntry.keyStart),
      length: keyEntry.keyEnd - keyEntry.keyStart,
      encoding: String.Encoding.utf8.rawValue
    ) ?? NSString()
    if let cached = cachedEntries.object(forKey: cacheKey) {
      return cached.value
    }

    let lastLine = Swift.min(keyEntry.startLine + keyEntry.count, valueLineOffsets.count)
    var result: [Entry] = []
    result.reserveCapacity(keyEntry.count)

    for lineIndex in keyEntry.startLine ..< lastLine {
      result.append(contentsOf: Self.parseValueLine(
        extractValueLine(at: lineIndex),
        isTyping: isTyping,
        defaultProbs: defaultProbs
      ))
    }

    cachedEntries.setObject(CachedEntriesBox(result), forKey: cacheKey)
    return result
  }

  private func extractValueLine(at index: Int) -> String {
    guard index >= 0, index < valueLineOffsets.count else { return "" }
    let start = valueLineOffsets[index]
    var end = (index + 1 < valueLineOffsets.count) ? valueLineOffsets[index + 1] - 1 : valuesEndOffset
    while end > start, [UInt8(0x0A), UInt8(0x0D)].contains(textMapData[end - 1]) {
      end -= 1
    }
    guard end > start else { return "" }
    return String(decoding: textMapData[start ..< end], as: UTF8.self)
  }
}

// MARK: - UTF-8 Byte Comparison Helpers

private func compareUTF8(_ lhs: UnsafeBufferPointer<UInt8>, _ rhs: [UInt8]) -> Int {
  let count = Swift.min(lhs.count, rhs.count)
  for i in 0 ..< count {
    if lhs[i] < rhs[i] { return -1 }
    if lhs[i] > rhs[i] { return 1 }
  }
  if lhs.count < rhs.count { return -1 }
  if lhs.count > rhs.count { return 1 }
  return 0
}

private func compareUTF8Buffers(
  _ lhs: UnsafeBufferPointer<UInt8>,
  _ rhs: UnsafeBufferPointer<UInt8>
)
  -> Int {
  let count = Swift.min(lhs.count, rhs.count)
  for i in 0 ..< count {
    if lhs[i] < rhs[i] { return -1 }
    if lhs[i] > rhs[i] { return 1 }
  }
  if lhs.count < rhs.count { return -1 }
  if lhs.count > rhs.count { return 1 }
  return 0
}

extension Data {
  fileprivate func compareUTF8Range(_ range: Range<Int>, with rhs: [UInt8]) -> Int {
    let lhsCount = range.count
    let count = Swift.min(lhsCount, rhs.count)
    for i in 0 ..< count {
      let lByte = self[range.lowerBound + i]
      if lByte < rhs[i] { return -1 }
      if lByte > rhs[i] { return 1 }
    }
    if lhsCount < rhs.count { return -1 }
    if lhsCount > rhs.count { return 1 }
    return 0
  }

  fileprivate func compareUTF8Ranges(_ lhs: Range<Int>, _ rhs: Range<Int>) -> Int {
    let lhsCount = lhs.count
    let rhsCount = rhs.count
    let count = Swift.min(lhsCount, rhsCount)
    for i in 0 ..< count {
      let lByte = self[lhs.lowerBound + i]
      let rByte = self[rhs.lowerBound + i]
      if lByte < rByte { return -1 }
      if lByte > rByte { return 1 }
    }
    if lhsCount < rhsCount { return -1 }
    if lhsCount > rhsCount { return 1 }
    return 0
  }
}

// MARK: - LMAssembly.LMInstantiator.CoreColumn

extension LMAssembly.LMInstantiator {
  enum CoreColumn: Int32 {
    case theDataCHS = 1
    case theDataCHT = 2
    case theDataCNS = 3
    case theDataMISC = 4
    case theDataSYMB = 5
    case theDataCHEW = 6

    // MARK: Internal

    var defaultScore: Double {
      switch self {
      case .theDataCHEW: return -1
      case .theDataCNS: return -11
      case .theDataSYMB: return -13
      case .theDataMISC: return -10
      default: return -9.9
      }
    }

    // MARK: Fileprivate

    fileprivate var textMapTypeIDs: Set<Int32> {
      switch self {
      case .theDataCHS: return [5]
      case .theDataCHT: return [6]
      case .theDataCNS: return [7]
      case .theDataMISC: return [4, 8]
      case .theDataSYMB: return [9]
      case .theDataCHEW: return [10]
      }
    }
  }
}

extension LMAssembly.LMInstantiator {
  // Async factory dictionary loading to avoid UI freeze on startup.
  @discardableResult
  public static func connectFactoryDictionary(
    textMapPath: String,
    dropPreviousConnection: Bool = true
  )
    -> Bool {
    if dropPreviousConnection {
      disconnectFactoryDictionary()
    }

    guard let resolvedTextMapPath = resolveTextMapPath(from: textMapPath) else {
      vCLMLog("Factory TextMap path not found: \(textMapPath)")
      return false
    }

    if !Self.asyncLoadingUserData {
      // Synchronous path: used by unit tests and when async loading is disabled.
      do {
        let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
        factoryLexicon = try FactoryTextMapLexicon(textMapData: textMapData)
        vCLMLog("Factory TextMap loading complete: \(resolvedTextMapPath)")
        return true
      } catch {
        vCLMLog("Factory TextMap loading failed: \(error.localizedDescription)")
        factoryLexicon = nil
        return false
      }
    } else {
      // Async path: heavy Data read + FactoryTextMapLexicon init on background queue.
      LMAssembly.fileHandleQueue.async {
        asyncOnMain {
          do {
            let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
            let newLexicon = try FactoryTextMapLexicon(textMapData: textMapData)
            factoryLexicon = newLexicon
            vCLMLog("Factory TextMap async loading complete: \(resolvedTextMapPath)")
          } catch {
            vCLMLog("Factory TextMap async loading failed: \(error.localizedDescription)")
            factoryLexicon = nil
          }
        }
      }
      return true // Async dispatch accepted; actual result delivered later.
    }
  }

  public static func disconnectFactoryDictionary() {
    factoryLexicon = nil
  }

  @discardableResult
  public static func connectToTestFactoryDictionary(
    textMapData: String
  )
    -> Bool {
    guard !textMapData.isEmpty else { return false }
    guard !textMapData.contains("#PRAGMA:VANGUARD_REVLOOKUP_TSV") else {
      vCLMLog("External revlookup fixtures are no longer supported.")
      return false
    }

    do {
      factoryLexicon = try FactoryTextMapLexicon(textMapData: Data(textMapData.utf8))
      return true
    } catch {
      vCLMLog("Factory TextMap test fixture loading failed: \(error.localizedDescription)")
      factoryLexicon = nil
      return false
    }
  }

  public static func getFactoryReverseLookupData(with kanji: String) -> [String]? {
    factoryLexicon?.reverseLookup(for: kanji)
  }

  func getHaninSymbolMenuUnigrams() -> [Homa.Gram] {
    // `_punctuation_list` entries are typeID=4 (letterPunctuations),
    // which belongs to .theDataMISC column, not .theDataCHS / .theDataCHT.
    let entries = Self.factoryLexicon?.exactEntries(for: "_punctuation_list") ?? []
    return makeFactoryUnigrams(
      entries: entries,
      keyArray: ["_punctuation_list"],
      sourceKey: "_punctuation_list",
      column: .theDataMISC,
      includeHalfWidthVariants: false
    )
  }

  public func factoryCoreUnigramsFor(
    key: String,
    keyArray: [String],
    onlyFindSupersets: Bool = false
  )
    -> [Homa.Gram] {
    if onlyFindSupersets {
      return factorySupersetUnigramsFor(
        subsetKey: key,
        subsetKeyArray: keyArray,
        column: isCHS ? .theDataCHS : .theDataCHT
      )
    }
    return factoryUnigramsFor(
      key: key,
      keyArray: keyArray,
      column: isCHS ? .theDataCHS : .theDataCHT
    )
  }

  func factoryUnigramsFor(
    key: String,
    keyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Homa.Gram] {
    if key == "_punctuation_list" { return [] }
    let encryptedKey = Self.cnvPhonabetToASCII(key)
    let entries = Self.factoryLexicon?.exactEntries(for: encryptedKey) ?? []
    return makeFactoryUnigrams(
      entries: entries,
      keyArray: keyArray,
      sourceKey: encryptedKey,
      column: column,
      includeHalfWidthVariants: true
    )
  }

  func factorySupersetUnigramsFor(
    subsetKey: String,
    subsetKeyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Homa.Gram] {
    if subsetKey == "_punctuation_list" { return [] }
    let encryptedKey = Self.cnvPhonabetToASCII(subsetKey)
    let supersetEntries = Self.factoryLexicon?.supersetEntries(containing: encryptedKey) ?? []

    return supersetEntries.flatMap { current in
      let keyArray = Self.restorePhonabetFromASCII(current.key).split(separator: "-").map(String.init)
      return makeFactoryUnigrams(
        entries: current.entries,
        keyArray: keyArray,
        sourceKey: current.key,
        column: column,
        includeHalfWidthVariants: true
      )
    }
  }

  internal func factoryCNSFilterThreadFor(key: String) -> String? {
    if key == "_punctuation_list" { return nil }
    let encryptedKey = Self.cnvPhonabetToASCII(key)
    let exactEntries = Self.factoryLexicon?.exactEntries(for: encryptedKey) ?? []
    let result = exactEntries
      .filter { CoreColumn.theDataCNS.textMapTypeIDs.contains($0.typeID) }
      .map(\.value)
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func hasFactoryCoreUnigramsFor(keyArray: [String]) -> Bool {
    let encryptedKey = Self.cnvPhonabetToASCII(keyArray.joined(separator: "-"))
    let typeIDs = (isCHS ? CoreColumn.theDataCHS : CoreColumn.theDataCHT).textMapTypeIDs
    let exactEntries = Self.factoryLexicon?.exactEntries(for: encryptedKey) ?? []
    return exactEntries.contains(where: { typeIDs.contains($0.typeID) })
  }

  func checkCNSConformation(for unigram: Homa.Gram, keyArray: [String]) -> Bool {
    guard unigram.current.count == keyArray.count else { return true }
    let chars = unigram.current.map(\.description)
    for (index, key) in keyArray.enumerated() {
      guard !key.hasPrefix("_") else { continue }
      guard let matchedResult = factoryCNSFilterThreadFor(key: key) else { continue }
      guard matchedResult.contains(chars[index]) else { return false }
    }
    return true
  }

  fileprivate static func cnvPhonabetToASCII(_ incoming: String) -> String {
    guard !incoming.contains("_") else { return incoming }
    var result = ""
    result.reserveCapacity(incoming.unicodeScalars.count)
    for character in incoming {
      if let mapped = charPhonabet2ASCII[character] {
        result.append(mapped)
      } else {
        result.append(character)
      }
    }
    return result
  }

  fileprivate static func restorePhonabetFromASCII(_ incoming: String) -> String {
    guard !incoming.contains("_") else { return incoming }
    var result = ""
    result.reserveCapacity(incoming.unicodeScalars.count)
    for character in incoming {
      if let mapped = charPhonabet4ASCII[character] {
        result.append(mapped)
      } else {
        result.append(character)
      }
    }
    return result
  }

  private static let charPhonabet2ASCII: [Character: Character] = [
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g",
    "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c",
    "ㄙ": "s", "ㄧ": "i",
    "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M",
    "ㄡ": "F", "ㄢ": "D",
    "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
  ]

  private static let charPhonabet4ASCII: [Character: String] = [
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ",
    "k": "ㄎ", "h": "ㄏ",
    "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ",
    "s": "ㄙ", "i": "ㄧ",
    "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ",
    "F": "ㄡ", "D": "ㄢ",
    "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
  ]

  /// Automatically generated half-width punctuation aliases should stay selectable,
  /// but must rank behind the lexicon's canonical full-width entry.
  private static let generatedHalfWidthPunctuationPenalty = 0.0001

  private func makeFactoryUnigrams(
    entries: [FactoryTextMapLexicon.Entry],
    keyArray: [String],
    sourceKey: String,
    column: CoreColumn,
    includeHalfWidthVariants: Bool
  )
    -> [Homa.Gram] {
    var grams: [Homa.Gram] = []
    var extraHalfWidthGrams: [Homa.Gram] = []
    for entry in entries where column.textMapTypeIDs.contains(entry.typeID) {
      var score = entry.probability
      if score > 0 {
        score *= -1
      }

      grams.append(.init(keyArray: keyArray, value: entry.value, score: score))

      guard includeHalfWidthVariants, sourceKey.contains("_punctuation") else { continue }
      let halfWidthValue = entry.value.applyingTransformFW2HW(reverse: false)
      if halfWidthValue != entry.value {
        extraHalfWidthGrams.append(
          .init(
            keyArray: keyArray,
            value: halfWidthValue,
            score: score - Self.generatedHalfWidthPunctuationPenalty
          )
        )
      }
    }

    grams.append(contentsOf: extraHalfWidthGrams)
    return grams
  }

  private static func resolveTextMapPath(from incomingPath: String) -> String? {
    let manager = FileManager.default
    let incomingURL = URL(fileURLWithPath: incomingPath)

    if incomingURL.pathExtension == "txtMap", manager.isReadableFile(atPath: incomingURL.path) {
      return incomingURL.path
    }

    let sameStem = incomingURL.deletingPathExtension().appendingPathExtension("txtMap")
    if manager.isReadableFile(atPath: sameStem.path) {
      return sameStem.path
    }

    let fixedName = incomingURL.deletingLastPathComponent()
      .appendingPathComponent("VanguardFactoryDict4Typing")
      .appendingPathExtension("txtMap")
    if manager.isReadableFile(atPath: fixedName.path) {
      return fixedName.path
    }

    return nil
  }
}
