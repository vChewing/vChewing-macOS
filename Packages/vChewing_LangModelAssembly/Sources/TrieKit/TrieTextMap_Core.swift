// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - VanguardTrie.TextMapTrie

extension VanguardTrie {
  /// TextMap 專用的高效率 Trie backend。
  ///
  /// 此實作保留 `VanguardTrie.TextMapTrie` 既有的 public surface，
  /// 但內核改為 dedicated loader：
  /// - raw `Data` 常駐
  /// - sorted key index + binary search
  /// - prefix-range scan for longer-segment queries
  /// - eager reverse lookup table
  /// - key initials prefilter for partial match
  public final class TextMapTrie {
    // MARK: Lifecycle

    public init(data: Data) throws {
      self.rawData = data

      let bounds = try Self.locatePragmaBounds(in: data)
      let headerContent = Self.extractString(
        from: data,
        start: bounds.headerContentStart,
        end: bounds.valuesLineStart
      )
      try Self.validateMinimumSupportedTextMapVersion(in: headerContent)
      let header = Self.parseHeaderContent(headerContent)

      self.readingSeparator = header.separator
      self.isTyping = header.isTyping
      self.defaultProbs = header.defaultProbs

      self.valuesLineOffsets = Self.scanValueLineOffsets(
        in: data,
        from: bounds.valuesContentStart,
        to: bounds.keyMapLineStart
      )
      self.valuesEndOffset = bounds.keyMapLineStart

      let (parsedEntries, initialsMap) = Self.parseKeyLineMapContent(
        in: data,
        from: bounds.keyMapContentStart,
        to: data.count,
        separator: header.separator
      )
      self.keyEntries = parsedEntries
      self.keyInitialsIDMap = initialsMap
      self.valueLineToKeyEntryIndex = Self.buildLineOwnerIndex(
        keyEntries: parsedEntries,
        valueLineCount: valuesLineOffsets.count
      )
      self.reverseLookupTable = Self.buildReverseLookupTable(
        in: data,
        keyEntries: parsedEntries,
        valueLineOffsets: valuesLineOffsets,
        valuesEndOffset: valuesEndOffset,
        isTyping: header.isTyping,
        defaultProbs: header.defaultProbs,
        separator: header.separator
      )
      cachedEntries.countLimit = 8_192
    }

    // MARK: Public

    public let readingSeparator: Character

    public func reverseLookup(for kanji: String) -> [String]? {
      guard let index = reverseLookupIndex(for: kanji) else { return nil }
      let readings = parsedReadings(from: reverseLookupTable[index].lineIndices)
      return readings.isEmpty ? nil : readings
    }

    // MARK: Private

    private typealias Entry = VanguardTrie.Trie.Entry
    private typealias EntryGroup = (keyArray: [String], entries: [Entry])

    private struct KeyEntry {
      let keyStart: Int
      let keyEnd: Int
      let startLine: Int
      let count: Int
    }

    private struct RevLookupEntry {
      let key: ContiguousArray<UInt8>
      let lineIndices: [Int]
    }

    private struct PragmaBounds {
      let headerContentStart: Int
      let valuesLineStart: Int
      let valuesContentStart: Int
      let keyMapLineStart: Int
      let keyMapContentStart: Int
    }

    private struct HeaderInfo {
      let separator: Character
      let isTyping: Bool
      let defaultProbs: [Int32: Double]
    }

    private final class CachedEntriesBox: NSObject {
      // MARK: Lifecycle

      init(_ value: [Entry]) {
        self.value = value
      }

      // MARK: Internal

      let value: [Entry]
    }

    private static let revLookupEntryType = VanguardTrie.Trie.EntryType(rawValue: 3)
    private static let cnsEntryType = VanguardTrie.Trie.EntryType(rawValue: 7)

    private let rawData: Data
    private let isTyping: Bool
    private let defaultProbs: [Int32: Double]
    private let valuesLineOffsets: [Int]
    private let valuesEndOffset: Int
    private let keyEntries: [KeyEntry]
    private let keyInitialsIDMap: [String: [Int]]
    private let valueLineToKeyEntryIndex: [Int32]
    private let reverseLookupTable: [RevLookupEntry]

    private let cachedEntries = NSCache<NSNumber, CachedEntriesBox>()
    private let queryBuffer4Node: QueryBuffer<VanguardTrie.Trie.TNode?> = .init()
    private let queryBuffer4Nodes: QueryBuffer<[VanguardTrie.Trie.TNode]> = .init()
    private let queryBuffer4NodeIDs: QueryBuffer<[Int]> = .init()
    private let queryBuffer4EntryGroups: QueryBuffer<[EntryGroup]> = .init()
  }
}

// MARK: - Init Helpers

extension VanguardTrie.TextMapTrie {
  private static func locatePragmaBounds(in data: Data) throws -> PragmaBounds {
    let pragmaHeader = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER".utf8)
    let pragmaValues = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES".utf8)
    let pragmaKeyMap = Array("#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP".utf8)
    let newline: UInt8 = 0x0A

    var headerContentStart: Int?
    var valuesLineStart: Int?
    var valuesContentStart: Int?
    var keyMapLineStart: Int?
    var keyMapContentStart: Int?

    data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      let total = buffer.count
      var cursor = 0

      while cursor < total {
        let lineStart = cursor
        while cursor < total, buffer[cursor] != newline {
          cursor += 1
        }
        let nextLineStart = Swift.min(cursor + 1, total)

        if lineStart < total, buffer[lineStart] == 0x23 {
          if matchPrefix(buffer, at: lineStart, count: total, prefix: pragmaHeader) {
            headerContentStart = nextLineStart
          } else if matchPrefix(buffer, at: lineStart, count: total, prefix: pragmaValues) {
            valuesLineStart = lineStart
            valuesContentStart = nextLineStart
          } else if matchPrefix(buffer, at: lineStart, count: total, prefix: pragmaKeyMap) {
            keyMapLineStart = lineStart
            keyMapContentStart = nextLineStart
          }
        }
        cursor = nextLineStart
      }
    }

    guard let headerContentStart,
          let valuesLineStart,
          let valuesContentStart,
          let keyMapLineStart,
          let keyMapContentStart
    else {
      throw VanguardTrie.TrieIO.Exception.deserializationFailed(
        NSError(domain: "VanguardTrie.TextMapTrie", code: -1, userInfo: [
          NSLocalizedDescriptionKey: "TextMap missing required PRAGMA sections.",
        ])
      )
    }

    return .init(
      headerContentStart: headerContentStart,
      valuesLineStart: valuesLineStart,
      valuesContentStart: valuesContentStart,
      keyMapLineStart: keyMapLineStart,
      keyMapContentStart: keyMapContentStart
    )
  }

  private static func matchPrefix(
    _ buffer: UnsafeBufferPointer<UInt8>,
    at offset: Int,
    count: Int,
    prefix: [UInt8]
  )
    -> Bool {
    guard offset + prefix.count <= count else { return false }
    for index in 0 ..< prefix.count where buffer[offset + index] != prefix[index] {
      return false
    }
    return true
  }

  private static func validateMinimumSupportedTextMapVersion(in headerContent: String) throws {
    let versionLine = headerContent.split(
      omittingEmptySubsequences: false,
      whereSeparator: \.isNewline
    ).first.map(String.init) ?? ""
    guard !isUnsupportedLegacyTextMapVersionLine(versionLine) else {
      throw makeUnsupportedTextMapVersionError()
    }
  }

  private static func isUnsupportedLegacyTextMapVersionLine(_ versionLine: String) -> Bool {
    versionLine.hasPrefix("VERSION\t1") && !versionLine.contains(".")
  }

  private static func makeUnsupportedTextMapVersionError() -> VanguardTrie.TrieIO.Exception {
    VanguardTrie.TrieIO.Exception.deserializationFailed(
      NSError(domain: "VanguardTrie.TextMapTrie", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "TextMap format versions below 1.1 are no longer supported.",
      ])
    )
  }

  private static func parseHeaderContent(_ content: String) -> HeaderInfo {
    var separator: Character = "-"
    var isTyping = false
    var defaultProbs: [Int32: Double] = [:]

    content.enumerateLines { line, _ in
      let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
      guard parts.count >= 2 else { return }
      switch parts[0] {
      case "READING_SEPARATOR":
        if let character = parts[1].first {
          separator = character
        }
      case "TYPE":
        isTyping = parts[1] == "TYPING"
      default:
        guard parts[0].hasPrefix("DEFAULT_PROB_") else { return }
        let suffix = parts[0].dropFirst("DEFAULT_PROB_".count)
        guard let typeID = Int32(suffix), let probability = Double(parts[1]) else { return }
        defaultProbs[typeID] = probability
      }
    }

    return .init(separator: separator, isTyping: isTyping, defaultProbs: defaultProbs)
  }

  private static func scanValueLineOffsets(
    in data: Data,
    from start: Int,
    to end: Int
  )
    -> [Int] {
    guard end > start else { return [] }
    var offsets: [Int] = [start]
    data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      for index in start ..< end where buffer[index] == 0x0A {
        let nextLineStart = index + 1
        if nextLineStart < end {
          offsets.append(nextLineStart)
        }
      }
    }
    return offsets
  }

  private static func parseKeyLineMapContent(
    in data: Data,
    from start: Int,
    to end: Int,
    separator: Character
  )
    -> ([KeyEntry], [String: [Int]]) {
    guard end >= start else { return ([], [:]) }

    var entries: [KeyEntry] = []
    let tab: UInt8 = 0x09
    let newline: UInt8 = 0x0A

    data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var lineStart = start
      var cursor = start

      func processLine(_ lowerBound: Int, _ rawUpperBound: Int) {
        var upperBound = rawUpperBound
        while upperBound > lowerBound, buffer[upperBound - 1] == 0x0D {
          upperBound -= 1
        }
        guard upperBound > lowerBound else { return }

        var firstTab: Int?
        var secondTab: Int?
        var current = lowerBound
        while current < upperBound {
          if buffer[current] == tab {
            if firstTab == nil {
              firstTab = current
            } else {
              secondTab = current
              break
            }
          }
          current += 1
        }

        guard let firstTab, let secondTab, firstTab > lowerBound else { return }
        let startLineRaw = extractString(from: data, start: firstTab + 1, end: secondTab)
        let countRaw = extractString(from: data, start: secondTab + 1, end: upperBound)
        guard let startLine = Int(startLineRaw), let count = Int(countRaw) else { return }

        entries.append(
          .init(
            keyStart: lowerBound,
            keyEnd: firstTab,
            startLine: startLine,
            count: count
          )
        )
      }

      while cursor <= end {
        if cursor == end || buffer[cursor] == newline {
          processLine(lineStart, cursor)
          lineStart = cursor + 1
        }
        cursor += 1
      }
    }

    entries.sort { lhs, rhs in
      data.compareUTF8Ranges(lhs.keyStart ..< lhs.keyEnd, rhs.keyStart ..< rhs.keyEnd) < 0
    }

    var keyInitialsIDMap: [String: [Int]] = [:]
    for (nodeID, keyEntry) in entries.enumerated() {
      let readingKey = extractString(from: data, start: keyEntry.keyStart, end: keyEntry.keyEnd)
      let keyInitials = readingKey.split(separator: separator).compactMap {
        $0.first?.description
      }.joined()
      keyInitialsIDMap[keyInitials, default: []].append(nodeID)
    }

    return (entries, keyInitialsIDMap)
  }

  private static func buildLineOwnerIndex(
    keyEntries: [KeyEntry],
    valueLineCount: Int
  )
    -> [Int32] {
    guard valueLineCount > 0 else { return [] }
    var lineOwners = Array(repeating: Int32(-1), count: valueLineCount)
    for (keyEntryIndex, keyEntry) in keyEntries.enumerated() {
      let end = Swift.min(keyEntry.startLine + keyEntry.count, valueLineCount)
      for lineIndex in keyEntry.startLine ..< end {
        lineOwners[lineIndex] = Int32(keyEntryIndex)
      }
    }
    return lineOwners
  }

  private static func buildReverseLookupTable(
    in data: Data,
    keyEntries: [KeyEntry],
    valueLineOffsets: [Int],
    valuesEndOffset: Int,
    isTyping: Bool,
    defaultProbs: [Int32: Double],
    separator: Character
  )
    -> [RevLookupEntry] {
    var charToLineIndices: [String: [Int]] = [:]

    for keyEntry in keyEntries {
      let readingKey = extractString(from: data, start: keyEntry.keyStart, end: keyEntry.keyEnd)
      let segmentCount = readingKey.split(separator: separator).count
      let endLine = Swift.min(keyEntry.startLine + keyEntry.count, valueLineOffsets.count)

      for lineIndex in keyEntry.startLine ..< endLine {
        let start = valueLineOffsets[lineIndex]
        var end = lineIndex + 1 < valueLineOffsets.count
          ? valueLineOffsets[lineIndex + 1]
          : valuesEndOffset
        while end > start, data[end - 1] == 0x0A || data[end - 1] == 0x0D {
          end -= 1
        }
        guard end > start else { continue }

        let line = extractString(from: data, start: start, end: end)
        let includeGroupedTypingLine = line.first == "@" && segmentCount == 1
        let parsedEntries = VanguardTrie.TrieIO.parseValueLine(
          line,
          isTyping: isTyping,
          defaultProbs: defaultProbs
        )

        for parsedEntry in parsedEntries {
          let charactersToIndex: [String] = if parsedEntry.typeID == cnsEntryType {
            parsedEntry.value.map(String.init)
          } else if includeGroupedTypingLine {
            parsedEntry.value.filter { currentCharacter in
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

    var result: [RevLookupEntry] = []
    result.reserveCapacity(charToLineIndices.count)
    for (character, lineIndices) in charToLineIndices {
      let sortedLineIndices = lineIndices.sorted()
      var deduplicatedLineIndices: [Int] = []
      deduplicatedLineIndices.reserveCapacity(sortedLineIndices.count)
      for currentLineIndex in sortedLineIndices where deduplicatedLineIndices.last != currentLineIndex {
        deduplicatedLineIndices.append(currentLineIndex)
      }
      result.append(
        .init(
          key: ContiguousArray(character.utf8),
          lineIndices: deduplicatedLineIndices
        )
      )
    }

    result.sort { lhs, rhs in
      lhs.key.withUnsafeBufferPointer { lhsBuffer in
        rhs.key.withUnsafeBufferPointer { rhsBuffer in
          compareUTF8Buffers(lhsBuffer, rhsBuffer) < 0
        }
      }
    }
    return result
  }

  private static func extractString(from data: Data, start: Int, end: Int) -> String {
    guard end > start else { return "" }
    return String(decoding: data[start ..< end], as: UTF8.self)
  }
}

// MARK: - Query Helpers

extension VanguardTrie.TextMapTrie {
  private var reverseLookupNodeIDOffset: Int { keyEntries.count + 1 }

  private func resolveKey(for keyEntry: KeyEntry) -> String {
    TrieStringPool.shared.internKey(
      Self.extractString(from: rawData, start: keyEntry.keyStart, end: keyEntry.keyEnd)
    )
  }

  private func resolveKeyArray(for keyEntry: KeyEntry) -> [String] {
    TrieStringOperationCache.shared.getCachedSplit(
      resolveKey(for: keyEntry),
      separator: readingSeparator
    )
  }

  private func extractValueLine(at lineIndex: Int) -> String {
    guard lineIndex >= 0, lineIndex < valuesLineOffsets.count else { return "" }
    let start = valuesLineOffsets[lineIndex]
    var end = lineIndex + 1 < valuesLineOffsets.count
      ? valuesLineOffsets[lineIndex + 1]
      : valuesEndOffset
    while end > start, rawData[end - 1] == 0x0A || rawData[end - 1] == 0x0D {
      end -= 1
    }
    guard end > start else { return "" }
    return Self.extractString(from: rawData, start: start, end: end)
  }

  private func parsedEntries(for keyEntryIndex: Int) -> [Entry] {
    guard keyEntryIndex >= 0, keyEntryIndex < keyEntries.count else { return [] }
    let keyEntry = keyEntries[keyEntryIndex]
    let cacheKey = NSNumber(value: keyEntry.keyStart)
    if let cached = cachedEntries.object(forKey: cacheKey) {
      return cached.value
    }

    let endLine = Swift.min(keyEntry.startLine + keyEntry.count, valuesLineOffsets.count)
    var result: [Entry] = []
    result.reserveCapacity(keyEntry.count)
    for lineIndex in keyEntry.startLine ..< endLine {
      result.append(contentsOf: VanguardTrie.TrieIO.parseValueLine(
        extractValueLine(at: lineIndex),
        isTyping: isTyping,
        defaultProbs: defaultProbs
      ).map {
        Entry(value: $0.value, typeID: $0.typeID, probability: $0.probability, previous: $0.previous)
      })
    }

    cachedEntries.setObject(CachedEntriesBox(result), forKey: cacheKey)
    return result
  }

  private func filteredEntryGroup(
    for keyEntryIndex: Int,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> EntryGroup? {
    guard keyEntryIndex >= 0, keyEntryIndex < keyEntries.count else { return nil }
    let filteredEntries = switch filterType.isEmpty {
    case true: parsedEntries(for: keyEntryIndex)
    case false: parsedEntries(for: keyEntryIndex).filter { filterType.contains($0.typeID) }
    }
    guard !filteredEntries.isEmpty else { return nil }
    return (resolveKeyArray(for: keyEntries[keyEntryIndex]), filteredEntries)
  }

  private func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lowerBound = 0
    var upperBound = keyEntries.count - 1
    while lowerBound <= upperBound {
      let middle = lowerBound + (upperBound - lowerBound) / 2
      let middleEntry = keyEntries[middle]
      let comparison = rawData.compareUTF8Range(middleEntry.keyStart ..< middleEntry.keyEnd, with: keyUTF8)
      if comparison < 0 {
        lowerBound = middle + 1
      } else if comparison > 0 {
        upperBound = middle - 1
      } else {
        return middle
      }
    }
    return nil
  }

  private func lowerBoundIndex(for keyPrefix: [UInt8]) -> Int {
    var lowerBound = 0
    var upperBound = keyEntries.count
    while lowerBound < upperBound {
      let middle = lowerBound + (upperBound - lowerBound) / 2
      let middleEntry = keyEntries[middle]
      let comparison = rawData.compareUTF8Range(middleEntry.keyStart ..< middleEntry.keyEnd, with: keyPrefix)
      if comparison < 0 {
        lowerBound = middle + 1
      } else {
        upperBound = middle
      }
    }
    return lowerBound
  }

  private func reverseLookupIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lowerBound = 0
    var upperBound = reverseLookupTable.count - 1
    while lowerBound <= upperBound {
      let middle = lowerBound + (upperBound - lowerBound) / 2
      let currentEntry = reverseLookupTable[middle]
      let comparison = currentEntry.key.withUnsafeBufferPointer { currentBuffer in
        compareUTF8(currentBuffer, keyUTF8)
      }
      if comparison < 0 {
        lowerBound = middle + 1
      } else if comparison > 0 {
        upperBound = middle - 1
      } else {
        return middle
      }
    }
    return nil
  }

  private func parsedReadings(from lineIndices: [Int]) -> [String] {
    var readings: [String] = []
    var handledReadings = Set<String>()
    for lineIndex in lineIndices {
      guard lineIndex >= 0, lineIndex < valueLineToKeyEntryIndex.count else { continue }
      let keyEntryIndex = Int(valueLineToKeyEntryIndex[lineIndex])
      guard keyEntryIndex >= 0, keyEntryIndex < keyEntries.count else { continue }
      let reading = resolveKey(for: keyEntries[keyEntryIndex])
      if handledReadings.insert(reading).inserted {
        readings.append(reading)
      }
    }
    return readings
  }

  private func reverseLookupEntryGroup(for key: String) -> EntryGroup? {
    guard let readings = reverseLookup(for: key), !readings.isEmpty else { return nil }
    return (
      keyArray: [key],
      entries: [
        Entry(
          value: readings.joined(separator: "\t"),
          typeID: Self.revLookupEntryType,
          probability: 0,
          previous: nil
        ),
      ]
    )
  }

  private func exactEntryGroups(
    keyArray: [String],
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [EntryGroup] {
    let key = keyArray.joined(separator: String(readingSeparator))
    guard let index = binarySearchIndex(for: key),
          let group = filteredEntryGroup(for: index, filterType: filterType)
    else {
      return []
    }
    return [group]
  }

  private func supersetEntryGroups(
    prefixing keyArray: [String],
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [EntryGroup] {
    let prefixKey = keyArray.joined(separator: String(readingSeparator))
    guard !prefixKey.isEmpty else { return [] }

    let prefixBytes = Array((prefixKey + String(readingSeparator)).utf8)
    let startIndex = lowerBoundIndex(for: prefixBytes)
    guard startIndex < keyEntries.count else { return [] }

    var result: [EntryGroup] = []
    for currentIndex in startIndex ..< keyEntries.count {
      let keyEntry = keyEntries[currentIndex]
      guard rawData.hasUTF8Prefix(keyEntry.keyStart ..< keyEntry.keyEnd, prefixBytes) else { break }
      if let group = filteredEntryGroup(for: currentIndex, filterType: filterType) {
        result.append(group)
      }
    }
    return result
  }

  private func partiallyMatchedEntryGroups(
    keyArray: [String],
    filterType: VanguardTrie.Trie.EntryType,
    longerSegment: Bool
  )
    -> [EntryGroup] {
    let matchedNodeIDs = getNodeIDsForKeyArray(keyArray, longerSegment: longerSegment)
    guard !matchedNodeIDs.isEmpty else { return [] }

    var result: [EntryGroup] = []
    result.reserveCapacity(matchedNodeIDs.count)
    for nodeID in matchedNodeIDs {
      guard nodeID >= 0, nodeID < keyEntries.count else { continue }
      let keyEntry = keyEntries[nodeID]
      let currentKeyArray = resolveKeyArray(for: keyEntry)

      var matched = longerSegment
        ? currentKeyArray.count > keyArray.count
        : currentKeyArray.count == keyArray.count
      guard matched else { continue }

      matched = zip(currentKeyArray, keyArray).allSatisfy { $0.hasPrefix($1) }
      guard matched, let group = filteredEntryGroup(for: nodeID, filterType: filterType) else {
        continue
      }
      result.append(group)
    }
    return result
  }

  private func parseNodeEntries(_ nodeID: Int) -> VanguardTrie.Trie.TNode? {
    guard nodeID >= 0, nodeID < keyEntries.count else { return nil }
    let entries = parsedEntries(for: nodeID)
    guard !entries.isEmpty else { return nil }
    let node = VanguardTrie.Trie.TNode(id: nodeID, readingKey: resolveKey(for: keyEntries[nodeID]))
    node.entries.append(contentsOf: entries)
    return node
  }

  private func parseReverseLookupNode(_ reverseLookupIndex: Int) -> VanguardTrie.Trie.TNode? {
    guard reverseLookupIndex >= 0, reverseLookupIndex < reverseLookupTable.count else { return nil }
    let reverseLookupEntry = reverseLookupTable[reverseLookupIndex]
    let readingValues = parsedReadings(from: reverseLookupEntry.lineIndices)
    guard !readingValues.isEmpty else { return nil }

    let node = VanguardTrie.Trie.TNode(
      id: reverseLookupNodeIDOffset + reverseLookupIndex,
      readingKey: TrieStringPool.shared.internKey(
        String(decoding: reverseLookupEntry.key, as: UTF8.self)
      )
    )
    node.entries.append(
      Entry(
        value: readingValues.joined(separator: "\t"),
        typeID: Self.revLookupEntryType,
        probability: 0,
        previous: nil
      )
    )
    return node
  }
}

// MARK: - VanguardTrie.TextMapTrie + VanguardTrieProtocol

extension VanguardTrie.TextMapTrie: VanguardTrieProtocol {
  public func getNodes(
    keysChopped: [String],
    filterType: EntryType,
    partiallyMatch: Bool
  )
    -> [VanguardTrie.Trie.TNode] {
    getEntryGroups(
      keysChopped: keysChopped,
      filterType: filterType,
      partiallyMatch: partiallyMatch
    ).compactMap { group in
      let keyChain = group.keyArray.joined(separator: String(readingSeparator))
      return exactNodeByReadingKey(keyChain)
    }
  }

  public func getEntryGroups(
    keysChopped: [String],
    filterType: EntryType,
    partiallyMatch: Bool
  )
    -> [(keyArray: [String], entries: [VanguardTrie.Trie.Entry])] {
    guard keysChopped.joined().contains(chopCaseSeparator) else {
      return getEntryGroups(
        keyArray: keysChopped,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
    }

    let cacheKey: Int = {
      var hasher = Hasher()
      hasher.combine(keysChopped)
      hasher.combine(filterType)
      hasher.combine(partiallyMatch)
      hasher.combine("CHOPPED")
      return hasher.finalize()
    }()
    if let cached = queryBuffer4EntryGroups.get(hashKey: cacheKey) {
      return cached
    }

    let choppedColumns = parseChoppedColumns(keysChopped)
    guard !choppedColumns.isEmpty else {
      queryBuffer4EntryGroups.set(hashKey: cacheKey, value: [])
      return []
    }

    let candidateNodeIDs = candidateNodeIDsForChoppedColumns(choppedColumns)
    guard !candidateNodeIDs.isEmpty else {
      queryBuffer4EntryGroups.set(hashKey: cacheKey, value: [])
      return []
    }

    var handledNodeIDs = Set<Int>()
    var results: [EntryGroup] = []
    results.reserveCapacity(candidateNodeIDs.count)

    for nodeID in candidateNodeIDs {
      guard let node = getNode(nodeID) else { continue }
      guard handledNodeIDs.insert(node.id).inserted else { continue }
      let nodeKeyArray = TrieStringOperationCache.shared.getCachedSplit(
        node.readingKey,
        separator: readingSeparator
      )
      guard nodeKeyArray.count == choppedColumns.count else { continue }
      guard nodeMatchesChoppedColumns(nodeKeyArray, choppedColumns: choppedColumns, partiallyMatch: partiallyMatch)
      else { continue }

      let filteredEntries = filterType.isEmpty
        ? node.entries
        : node.entries.filter { filterType.contains($0.typeID) }
      guard !filteredEntries.isEmpty else { continue }
      results.append((nodeKeyArray, filteredEntries))
    }

    queryBuffer4EntryGroups.set(hashKey: cacheKey, value: results)
    return results
  }

  public func getNodeIDsForKeyArray(
    _ keyArray: [String],
    longerSegment: Bool
  )
    -> [Int] {
    guard !keyArray.isEmpty, keyArray.allSatisfy({ !$0.isEmpty }) else { return [] }
    let keyInitials = keyArray.compactMap { $0.first?.description }.joined()

    let cacheKey: Int = {
      var hasher = Hasher()
      hasher.combine(keyInitials)
      hasher.combine(longerSegment)
      return hasher.finalize()
    }()
    if let cached = queryBuffer4NodeIDs.get(hashKey: cacheKey) {
      return cached
    }

    var matchedNodeIDs = [Int]()
    if longerSegment {
      for (currentInitials, nodeIDs) in keyInitialsIDMap where currentInitials.hasPrefix(keyInitials) {
        matchedNodeIDs.append(contentsOf: nodeIDs)
      }
      matchedNodeIDs.sort()
    } else {
      matchedNodeIDs = keyInitialsIDMap[keyInitials] ?? []
    }

    queryBuffer4NodeIDs.set(hashKey: cacheKey, value: matchedNodeIDs)
    return matchedNodeIDs
  }

  public func getNode(_ nodeID: Int) -> VanguardTrie.Trie.TNode? {
    if let cached = queryBuffer4Node.get(hashKey: nodeID) {
      return cached
    }

    let result = if nodeID >= reverseLookupNodeIDOffset {
      parseReverseLookupNode(nodeID - reverseLookupNodeIDOffset)
    } else {
      parseNodeEntries(nodeID)
    }

    queryBuffer4Node.set(hashKey: nodeID, value: result)
    return result
  }

  public func getNodes(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  )
    -> [VanguardTrie.Trie.TNode] {
    if filterType == Self.revLookupEntryType {
      guard !partiallyMatch, !longerSegment, keyArray.count == 1,
            let matchedIndex = reverseLookupIndex(for: keyArray[0])
      else {
        return []
      }
      return getNode(reverseLookupNodeIDOffset + matchedIndex).map { [$0] } ?? []
    }

    let cacheKey: Int = {
      var hasher = Hasher()
      hasher.combine(keyArray)
      hasher.combine(filterType)
      hasher.combine(partiallyMatch)
      hasher.combine(longerSegment)
      return hasher.finalize()
    }()
    if let cached = queryBuffer4Nodes.get(hashKey: cacheKey) {
      return cached
    }

    let matchedNodeIDs = getNodeIDsForKeyArray(keyArray, longerSegment: longerSegment)
    guard !matchedNodeIDs.isEmpty else {
      queryBuffer4Nodes.set(hashKey: cacheKey, value: [])
      return []
    }

    var handledNodeIDs = Set<Int>()
    let matchedNodes = matchedNodeIDs.compactMap { currentNodeID -> VanguardTrie.Trie.TNode? in
      guard let node = getNode(currentNodeID) else { return nil }
      guard handledNodeIDs.insert(node.id).inserted else { return nil }
      let nodeKeyArray = TrieStringOperationCache.shared.getCachedSplit(
        node.readingKey,
        separator: readingSeparator
      )
      guard nodeMeetsFilter(node, filter: filterType) else { return nil }

      var matched = longerSegment
        ? nodeKeyArray.count > keyArray.count
        : nodeKeyArray.count == keyArray.count
      switch partiallyMatch {
      case true:
        matched = matched && zip(nodeKeyArray, keyArray).allSatisfy { $0.hasPrefix($1) }
      case false:
        matched = matched && zip(nodeKeyArray, keyArray).allSatisfy(==)
      }
      return matched ? node : nil
    }

    queryBuffer4Nodes.set(hashKey: cacheKey, value: matchedNodes)
    return matchedNodes
  }

  public func getEntryGroups(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  )
    -> [(keyArray: [String], entries: [VanguardTrie.Trie.Entry])] {
    guard !keyArray.isEmpty, keyArray.allSatisfy({ !$0.isEmpty }) else { return [] }

    if filterType == Self.revLookupEntryType {
      guard !partiallyMatch, !longerSegment, keyArray.count == 1,
            let group = reverseLookupEntryGroup(for: keyArray[0])
      else {
        return []
      }
      return [group]
    }

    let cacheKey: Int = {
      var hasher = Hasher()
      hasher.combine(keyArray)
      hasher.combine(filterType)
      hasher.combine(partiallyMatch)
      hasher.combine(longerSegment)
      return hasher.finalize()
    }()
    if let cached = queryBuffer4EntryGroups.get(hashKey: cacheKey) {
      return cached
    }

    let result: [EntryGroup] = switch (partiallyMatch, longerSegment) {
    case (false, false):
      exactEntryGroups(keyArray: keyArray, filterType: filterType)
    case (false, true):
      supersetEntryGroups(prefixing: keyArray, filterType: filterType)
    case (true, _):
      partiallyMatchedEntryGroups(keyArray: keyArray, filterType: filterType, longerSegment: longerSegment)
    }

    queryBuffer4EntryGroups.set(hashKey: cacheKey, value: result)
    return result
  }

  private func parseChoppedColumns(_ keysChopped: [String]) -> [[String]] {
    keysChopped.compactMap { currentCell in
      let cells = currentCell.split(separator: chopCaseSeparator).map(\.description)
      return cells.isEmpty ? nil : cells
    }
  }

  private func candidateNodeIDsForChoppedColumns(_ choppedColumns: [[String]]) -> [Int] {
    let initialSets: [Set<String>] = choppedColumns.map { candidates in
      Set(candidates.compactMap { $0.first?.description })
    }
    guard initialSets.allSatisfy({ !$0.isEmpty }) else { return [] }

    var matchedNodeIDs = [Int]()
    for (currentInitials, nodeIDs) in keyInitialsIDMap {
      let initialsArray = currentInitials.map(\.description)
      guard initialsArray.count == initialSets.count else { continue }
      var allMatched = true
      for index in initialsArray.indices where !initialSets[index].contains(initialsArray[index]) {
        allMatched = false
        break
      }
      if allMatched {
        matchedNodeIDs.append(contentsOf: nodeIDs)
      }
    }
    matchedNodeIDs.sort()
    return matchedNodeIDs
  }

  private func nodeMatchesChoppedColumns(
    _ nodeKeyArray: [String],
    choppedColumns: [[String]],
    partiallyMatch: Bool
  )
    -> Bool {
    for index in nodeKeyArray.indices {
      let nodeCell = nodeKeyArray[index]
      let candidates = choppedColumns[index]
      let matched: Bool = switch partiallyMatch {
      case true:
        candidates.contains { nodeCell.hasPrefix($0) }
      case false:
        candidates.contains(nodeCell)
      }
      if !matched { return false }
    }
    return true
  }

  private func exactNodeByReadingKey(_ readingKey: String) -> VanguardTrie.Trie.TNode? {
    let keyBytes = Array(readingKey.utf8)
    let totalCount = keyEntries.count
    var lower = 0
    var upper = totalCount

    while lower < upper {
      let mid = (lower + upper) / 2
      let keyEntry = keyEntries[mid]
      let compared: Int = rawData.withUnsafeBytes { rawBuffer in
        let buffer = rawBuffer.bindMemory(to: UInt8.self)
        let range = keyEntry.keyStart ..< keyEntry.keyEnd
        let slice = UnsafeBufferPointer(rebasing: buffer[range])
        return compareUTF8(slice, keyBytes)
      }
      if compared < 0 {
        lower = mid + 1
      } else {
        upper = mid
      }
    }

    guard lower < totalCount else { return nil }
    let keyEntry = keyEntries[lower]
    let isExactMatch: Bool = rawData.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      let range = keyEntry.keyStart ..< keyEntry.keyEnd
      let slice = UnsafeBufferPointer(rebasing: buffer[range])
      return compareUTF8(slice, keyBytes) == 0
    }
    guard isExactMatch else { return nil }
    return parseNodeEntries(lower + 1)
  }
}

// MARK: - UTF-8 Helpers

private func compareUTF8(_ lhs: UnsafeBufferPointer<UInt8>, _ rhs: [UInt8]) -> Int {
  let count = Swift.min(lhs.count, rhs.count)
  for index in 0 ..< count {
    if lhs[index] < rhs[index] { return -1 }
    if lhs[index] > rhs[index] { return 1 }
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
  for index in 0 ..< count {
    if lhs[index] < rhs[index] { return -1 }
    if lhs[index] > rhs[index] { return 1 }
  }
  if lhs.count < rhs.count { return -1 }
  if lhs.count > rhs.count { return 1 }
  return 0
}

extension Data {
  fileprivate func compareUTF8Range(_ range: Range<Int>, with rhs: [UInt8]) -> Int {
    let lhsCount = range.count
    let count = Swift.min(lhsCount, rhs.count)
    for index in 0 ..< count {
      let lhsByte = self[range.lowerBound + index]
      if lhsByte < rhs[index] { return -1 }
      if lhsByte > rhs[index] { return 1 }
    }
    if lhsCount < rhs.count { return -1 }
    if lhsCount > rhs.count { return 1 }
    return 0
  }

  fileprivate func compareUTF8Ranges(_ lhs: Range<Int>, _ rhs: Range<Int>) -> Int {
    let lhsCount = lhs.count
    let rhsCount = rhs.count
    let count = Swift.min(lhsCount, rhsCount)
    for index in 0 ..< count {
      let lhsByte = self[lhs.lowerBound + index]
      let rhsByte = self[rhs.lowerBound + index]
      if lhsByte < rhsByte { return -1 }
      if lhsByte > rhsByte { return 1 }
    }
    if lhsCount < rhsCount { return -1 }
    if lhsCount > rhsCount { return 1 }
    return 0
  }

  fileprivate func hasUTF8Prefix(_ range: Range<Int>, _ prefix: [UInt8]) -> Bool {
    guard range.count >= prefix.count else { return false }
    for index in 0 ..< prefix.count where self[range.lowerBound + index] != prefix[index] {
      return false
    }
    return true
  }
}
