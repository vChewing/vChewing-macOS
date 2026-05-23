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
        valueLineToKeyEntryIndex: valueLineToKeyEntryIndex,
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
      /// Precomputed reading-key segment count (number of `-`-separated sub-keys).
      /// A segment count of 1 means the key represents a single syllable.
      let segmentCount: UInt8
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

    private struct ChoppedColumnCandidate {
      let text: String
      let bytes: [UInt8]
    }

    private struct ChoppedColumn {
      let candidates: [ChoppedColumnCandidate]
      let firstBytes: Set<UInt8>
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
        // Early exit once all three pragmas are found.
        if headerContentStart != nil, valuesLineStart != nil, keyMapLineStart != nil {
          break
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
            count: count,
            segmentCount: 0 // filled below
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

    // Pointer-based comparisons via direct buffer access instead of Data subscript.
    data.withUnsafeBytes { rawBuffer in
      let sortBuf = rawBuffer.bindMemory(to: UInt8.self)
      entries.sort { lhs, rhs in
        let lhsLen = lhs.keyEnd - lhs.keyStart
        let rhsLen = rhs.keyEnd - rhs.keyStart
        let minLen = lhsLen < rhsLen ? lhsLen : rhsLen
        for i in 0 ..< minLen {
          let lb = sortBuf[lhs.keyStart + i]
          let rb = sortBuf[rhs.keyStart + i]
          if lb < rb { return true }
          if lb > rb { return false }
        }
        return lhsLen < rhsLen
      }
    }

    // Byte-level key initials extraction avoids String/split allocations.
    var keyInitialsIDMap: [String: [Int]] = [:]
    let sepByte = separator.asciiValue!
    data.withUnsafeBytes { rawBuffer in
      let initBuf = rawBuffer.bindMemory(to: UInt8.self)
      for (nodeID, idx) in entries.indices.enumerated() {
        let ks = entries[idx].keyStart
        let ke = entries[idx].keyEnd
        var segCount: UInt8 = 1
        var initialsBytes = [UInt8]()
        // Collect full first character (not first byte) of the initial segment.
        if ks < ke {
          let firstLen = utf8SequenceLength(initBuf[ks])
          let copyLen = Swift.min(firstLen, ke - ks)
          if copyLen > 0 { initialsBytes.append(contentsOf: initBuf[ks ..< ks + copyLen]) }
        }
        for pos in ks ..< ke {
          if initBuf[pos] == sepByte {
            segCount += 1
            let nextPos = pos + 1
            if nextPos < ke {
              let firstLen = utf8SequenceLength(initBuf[nextPos])
              let copyLen = Swift.min(firstLen, ke - nextPos)
              if copyLen >
                0 { initialsBytes.append(contentsOf: initBuf[nextPos ..< nextPos + copyLen]) }
            }
          }
        }
        let initials = String(decoding: initialsBytes, as: UTF8.self)
        keyInitialsIDMap[initials, default: []].append(nodeID)
        entries[idx] = .init(
          keyStart: ks,
          keyEnd: ke,
          startLine: entries[idx].startLine,
          count: entries[idx].count,
          segmentCount: segCount
        )
      }
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

  /// Sequential-pass reverse-lookup table builder.
  ///
  /// Replaces the previous random-access-per-key implementation.
  /// Now makes a single sequential walk over VALUES using the pre-built
  /// `valueLineToKeyEntryIndex` to look up the owning key for each line,
  /// and extracts ideographic characters via byte-level scanning (no full
  /// `parseValueLine` or per-line `String` allocation for the line body).
  private static func buildReverseLookupTable(
    in data: Data,
    keyEntries: [KeyEntry],
    valueLineOffsets: [Int],
    valuesEndOffset: Int,
    valueLineToKeyEntryIndex: [Int32],
    isTyping: Bool,
    defaultProbs: [Int32: Double],
    separator: Character
  )
    -> [RevLookupEntry] {
    // UInt32 scalar values as dictionary keys to avoid per-character String allocations.
    var charToLineIndices: [UInt32: [Int]] = [:]

    for lineIndex in 0 ..< valueLineOffsets.count {
      let keyEntryIndex = Int(valueLineToKeyEntryIndex[lineIndex])
      guard keyEntryIndex >= 0, keyEntryIndex < keyEntries.count else { continue }
      let keyEntry = keyEntries[keyEntryIndex]
      let isSingleSegment = keyEntry.segmentCount == 1

      let start = valueLineOffsets[lineIndex]
      var end = lineIndex + 1 < valueLineOffsets.count
        ? valueLineOffsets[lineIndex + 1]
        : valuesEndOffset
      while end > start, data[end - 1] == 0x0A || data[end - 1] == 0x0D {
        end -= 1
      }
      guard end > start else { continue }

      let chars = collectReverseLookupCharsFromLine(
        in: data,
        start: start,
        end: end,
        isTyping: isTyping,
        includeGroupedTypingLine: isSingleSegment
      )
      for sv in chars {
        charToLineIndices[sv, default: []].append(lineIndex)
      }
    }

    var result: [RevLookupEntry] = []
    result.reserveCapacity(charToLineIndices.count)
    for (scalarValue, lineIndices) in charToLineIndices {
      let sortedLineIndices = lineIndices.sorted()
      var deduplicatedLineIndices: [Int] = []
      deduplicatedLineIndices.reserveCapacity(sortedLineIndices.count)
      for currentLineIndex in sortedLineIndices
        where deduplicatedLineIndices.last != currentLineIndex {
        deduplicatedLineIndices.append(currentLineIndex)
      }
      guard let scalar = Unicode.Scalar(scalarValue) else { continue }
      result.append(
        .init(
          key: ContiguousArray(String(scalar).utf8),
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

  // MARK: - Byte-Level Reverse-Lookup Char Extraction

  /// Byte-level scanner that extracts ideographic characters from a single
  /// VALUES line without allocating a full `String` for the line body or
  /// building complete `Entry` structs.
  ///
  /// Handles all three TextMap line formats (A / B / C) and legacy compat
  /// formats directly on `Data` bytes.
  private static func collectReverseLookupCharsFromLine(
    in data: Data,
    start: Int,
    end: Int,
    isTyping: Bool,
    includeGroupedTypingLine: Bool
  )
    -> [UInt32] {
    guard end > start else { return [] }
    let tab: UInt8 = 0x09

    // --- Locate tab positions (up to 3 tabs needed) ---
    let tabPositions: [Int] = data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var tabs: [Int] = []
      var cursor = start
      while cursor < end, tabs.count < 4 {
        if buffer[cursor] == tab { tabs.append(cursor) }
        cursor += 1
      }
      return tabs
    }

    // --- Determine format by first byte ---
    let firstByte = data[start]

    if firstByte == 0x3E, tabPositions.count >= 1 { // '>' = Format A
      // `>typeID\tgroupedCell`
      let typeIDStart = start + 1
      let typeIDEnd = tabPositions[0]
      let typeIDRaw = parsePositiveInt32(from: data, start: typeIDStart, end: typeIDEnd) ?? -1

      let cellStart = tabPositions[0] + 1
      let cellEnd = end

      if typeIDRaw == cnsEntryType.rawValue {
        return collectCharsFromGroupedCellBytes(
          in: data, start: cellStart, end: cellEnd, ideographicOnly: false
        )
      } else if includeGroupedTypingLine {
        return collectCharsFromGroupedCellBytes(
          in: data, start: cellStart, end: cellEnd, ideographicOnly: true
        )
      }
      return []
    }

    if firstByte == 0x40, tabPositions.count >= 2, isTyping { // '@' = Format B
      // `@prob\tchsCell\tchtCell`
      guard includeGroupedTypingLine else { return [] }
      var chars: [UInt32] = []
      let chsStart = tabPositions[0] + 1
      let chsEnd = tabPositions[1]
      chars.append(contentsOf: collectCharsFromGroupedCellBytes(
        in: data, start: chsStart, end: chsEnd, ideographicOnly: true
      ))
      let chtStart = tabPositions[1] + 1
      let chtEnd = tabPositions.count >= 3 ? tabPositions[2] : end
      chars.append(contentsOf: collectCharsFromGroupedCellBytes(
        in: data, start: chtStart, end: chtEnd, ideographicOnly: true
      ))
      return chars
    }

    // --- Format C: `value\tprob\ttypeID[\tprevious]` ---
    // --- Legacy 4-column / bare numeric grouped (TYPING only) ---

    // Legacy bare numeric grouped: `prob\tchsCell\tchtCell` (TYPING, first cell parses as Double)
    if isTyping, includeGroupedTypingLine, tabPositions.count >= 2,
       data[start] >= 0x30, data[start] <= 0x39 || data[start] == 0x2D {
      var chars: [UInt32] = []
      let chsStart = tabPositions[0] + 1
      let chsEnd = tabPositions[1]
      chars.append(contentsOf: collectCharsFromGroupedCellBytes(
        in: data, start: chsStart, end: chsEnd, ideographicOnly: true
      ))
      let chtStart = tabPositions[1] + 1
      let chtEnd = tabPositions.count >= 3 ? tabPositions[2] : end
      chars.append(contentsOf: collectCharsFromGroupedCellBytes(
        in: data, start: chtStart, end: chtEnd, ideographicOnly: true
      ))
      return chars
    }

    // Legacy 4-column: `chsValue\tchsProb\tchtValue\tchtProb` (TYPING only)
    if isTyping, includeGroupedTypingLine, tabPositions.count >= 3 {
      var chars: [UInt32] = []
      let chsValEnd = tabPositions[0]
      chars.append(contentsOf: collectCharsFromPlainCellBytes(
        in: data, start: start, end: chsValEnd, ideographicOnly: true
      ))
      let chtValStart = tabPositions[1] + 1
      let chtValEnd = tabPositions[2]
      chars.append(contentsOf: collectCharsFromPlainCellBytes(
        in: data, start: chtValStart, end: chtValEnd, ideographicOnly: true
      ))
      return chars
    }

    // Format C: `value\tprob\ttypeID[\tprevious]` (minimum 2 tabs = 3 fields)
    if tabPositions.count >= 2 {
      let typeIDStart = tabPositions[1] + 1
      let typeIDEnd = tabPositions.count >= 3 ? tabPositions[2] : end
      let typeIDRaw = parsePositiveInt32(from: data, start: typeIDStart, end: typeIDEnd) ?? -1

      let valueStart = start
      let valueEnd = tabPositions[0]

      if typeIDRaw == cnsEntryType.rawValue {
        return collectCharsFromPlainCellBytes(
          in: data, start: valueStart, end: valueEnd, ideographicOnly: false
        )
      } else if includeGroupedTypingLine {
        return collectCharsFromPlainCellBytes(
          in: data, start: valueStart, end: valueEnd, ideographicOnly: true
        )
      }
      return []
    }

    return []
  }

  /// Extract characters from a **plain** cell (no pipe-escaping).
  /// - Parameter ideographicOnly: if `true`, only ideographic scalars are kept;
  ///   if `false`, every scalar is returned.
  /// - Returns: Array of UInt32 scalar values (avoids per-character String allocation).
  private static func collectCharsFromPlainCellBytes(
    in data: Data,
    start: Int,
    end: Int,
    ideographicOnly: Bool
  )
    -> [UInt32] {
    guard end > start else { return [] }
    var result: [UInt32] = []
    data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var i = start
      while i < end {
        let byte = buffer[i]
        let len = utf8SequenceLength(byte)
        guard len > 0, i + len <= end else { i += 1; continue }
        if len == 1 { i += 1; continue } // ASCII, skip
        // Decode raw UInt32 + fast CJK range check instead of Unicode.Scalar + isIdeographic.
        let sv = decodeUTF8ScalarValue(from: buffer, at: i, length: len)
        if !ideographicOnly || isFastCJKIdeographic(sv) {
          result.append(sv)
        }
        i += len
      }
    }
    return result
  }

  /// Extract characters from a **grouped** cell (pipe-separated, backslash-escaped).
  /// - Parameter ideographicOnly: if `true`, only ideographic scalars are kept;
  ///   if `false`, every decoded scalar is returned.
  /// - Returns: Array of UInt32 scalar values (single-pass scan, no pre-scan, no String allocation).
  private static func collectCharsFromGroupedCellBytes(
    in data: Data,
    start: Int,
    end: Int,
    ideographicOnly: Bool
  )
    -> [UInt32] {
    guard end > start else { return [] }
    var result: [UInt32] = []
    // Single-pass scan handles escape/separator inline; no pre-scan needed.
    data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var i = start
      while i < end {
        let byte = buffer[i]
        if byte == 0x5C { // '\\' escape: skip this and the next byte
          i += 2
          continue
        }
        if byte == 0x7C { // '|' separator
          i += 1
          continue
        }
        let len = utf8SequenceLength(byte)
        guard len > 0, i + len <= end else { i += 1; continue }
        if len == 1 { i += 1; continue }
        // Decode raw UInt32 + fast CJK range check.
        let sv = decodeUTF8ScalarValue(from: buffer, at: i, length: len)
        if !ideographicOnly || isFastCJKIdeographic(sv) {
          result.append(sv)
        }
        i += len
      }
    }
    return result
  }

  // MARK: - Lightweight Parsing Helpers

  /// Returns the length of a UTF-8 sequence given its leading byte.
  /// Returns 0 if the byte is a continuation byte or invalid.
  @inline(__always)
  private static func utf8SequenceLength(_ byte: UInt8) -> Int {
    if byte & 0x80 == 0 { return 1 }
    if byte & 0xE0 == 0xC0 { return 2 }
    if byte & 0xF0 == 0xE0 { return 3 }
    if byte & 0xF8 == 0xF0 { return 4 }
    return 0 // continuation byte or invalid
  }

  /// Decodes a Unicode scalar from a UTF-8 buffer at a given offset.
  @inline(__always)
  private static func decodeUTF8Scalar(
    from buffer: UnsafeBufferPointer<UInt8>,
    at offset: Int,
    length: Int
  )
    -> Unicode.Scalar {
    let fallback: Unicode.Scalar = "\u{FFFD}"
    switch length {
    case 2:
      return Unicode.Scalar(
        (UInt32(buffer[offset] & 0x1F) << 6) |
          UInt32(buffer[offset + 1] & 0x3F)
      ) ?? fallback
    case 3:
      return Unicode.Scalar(
        (UInt32(buffer[offset] & 0x0F) << 12) |
          (UInt32(buffer[offset + 1] & 0x3F) << 6) |
          UInt32(buffer[offset + 2] & 0x3F)
      ) ?? fallback
    case 4:
      return Unicode.Scalar(
        (UInt32(buffer[offset] & 0x07) << 18) |
          (UInt32(buffer[offset + 1] & 0x3F) << 12) |
          (UInt32(buffer[offset + 2] & 0x3F) << 6) |
          UInt32(buffer[offset + 3] & 0x3F)
      ) ?? fallback
    default:
      return fallback
    }
  }

  // Decodes raw UInt32 scalar value without Unicode.Scalar allocation.
  @inline(__always)
  private static func decodeUTF8ScalarValue(
    from buffer: UnsafeBufferPointer<UInt8>,
    at offset: Int,
    length: Int
  )
    -> UInt32 {
    switch length {
    case 2:
      return (UInt32(buffer[offset] & 0x1F) << 6) |
        UInt32(buffer[offset + 1] & 0x3F)
    case 3:
      return (UInt32(buffer[offset] & 0x0F) << 12) |
        (UInt32(buffer[offset + 1] & 0x3F) << 6) |
        UInt32(buffer[offset + 2] & 0x3F)
    case 4:
      return (UInt32(buffer[offset] & 0x07) << 18) |
        (UInt32(buffer[offset + 1] & 0x3F) << 12) |
        (UInt32(buffer[offset + 2] & 0x3F) << 6) |
        UInt32(buffer[offset + 3] & 0x3F)
    default:
      return 0xFFFD
    }
  }

  /// Fast CJK ideographic range check.
  /// Covers all CJK Unified Ideographs blocks (Extensions A–I) and compatibility blocks.
  /// CNS-only entries bypass this check entirely via `ideographicOnly: false`,
  /// so PUA / surrogate-pair CNS characters are always captured.
  @inline(__always)
  private static func isFastCJKIdeographic(_ scalarValue: UInt32) -> Bool {
    (scalarValue >= 0x3400 && scalarValue <= 0x4DBF) // Extension A
      || (scalarValue >= 0x4E00 && scalarValue <= 0x9FFF) // Unified
      || (scalarValue >= 0xF900 && scalarValue <= 0xFAFF) // Compatibility
      || (scalarValue >= 0x20000 && scalarValue <= 0x2A6DF) // Extension B
      || (scalarValue >= 0x2A700 && scalarValue <= 0x2B73F) // Extension C
      || (scalarValue >= 0x2B740 && scalarValue <= 0x2B81F) // Extension D
      || (scalarValue >= 0x2B820 && scalarValue <= 0x2CEAF) // Extension E
      || (scalarValue >= 0x2CEB0 && scalarValue <= 0x2EBEF) // Extension F
      || (scalarValue >= 0x30000 && scalarValue <= 0x3134F) // Extension G
      || (scalarValue >= 0x31350 && scalarValue <= 0x323AF) // Extension H
      || (scalarValue >= 0x2EBF0 && scalarValue <= 0x2EE5F) // Extension I
      || (scalarValue >= 0x2F800 && scalarValue <= 0x2FA1F) // Compatibility Supplement
  }

  /// Parses a positive Int32 from a byte range without String allocation.
  @inline(__always)
  private static func parsePositiveInt32(from data: Data, start: Int, end: Int) -> Int32? {
    guard end > start else { return nil }
    let count = end - start
    guard count <= 10 else { return nil } // Max digits for Int32
    return data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var result: Int32 = 0
      for i in start ..< end {
        let byte = buffer[i]
        guard byte >= 0x30, byte <= 0x39 else { return nil as Int32? } // '0'..'9'
        result = result &* 10 &+ Int32(byte &- 0x30)
      }
      return result
    }
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
        Entry(
          value: $0.value,
          typeID: $0.typeID,
          probability: $0.probability,
          previous: $0.previous
        )
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
    case false: parsedEntries(for: keyEntryIndex).filter {
        filterMatches(
          entryType: $0.typeID,
          filter: filterType
        )
      }
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
      let comparison = rawData.compareUTF8Range(
        middleEntry.keyStart ..< middleEntry.keyEnd,
        with: keyUTF8
      )
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
      let comparison = rawData.compareUTF8Range(
        middleEntry.keyStart ..< middleEntry.keyEnd,
        with: keyPrefix
      )
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
      guard nodeMatchesChoppedColumns(
        nodeKeyArray,
        choppedColumns: choppedColumns,
        partiallyMatch: partiallyMatch
      )
      else { continue }

      let filteredEntries = filterType.isEmpty
        ? node.entries
        : node.entries.filter { filterMatches(entryType: $0.typeID, filter: filterType) }
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
      for (currentInitials, nodeIDs) in keyInitialsIDMap
        where currentInitials.hasPrefix(keyInitials) {
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
      partiallyMatchedEntryGroups(
        keyArray: keyArray,
        filterType: filterType,
        longerSegment: longerSegment
      )
    }

    queryBuffer4EntryGroups.set(hashKey: cacheKey, value: result)
    return result
  }

  private func parseChoppedColumns(_ keysChopped: [String]) -> [ChoppedColumn] {
    keysChopped.compactMap { currentCell in
      let cells = currentCell.split(separator: chopCaseSeparator).map(\.description)
      guard !cells.isEmpty else { return nil }
      let candidates = cells.map { current in
        ChoppedColumnCandidate(text: current, bytes: Array(current.utf8))
      }
      let firstBytes = Set(candidates.compactMap { $0.bytes.first })
      guard !firstBytes.isEmpty else { return nil }
      return ChoppedColumn(candidates: candidates, firstBytes: firstBytes)
    }
  }

  private func candidateNodeIDsForChoppedColumns(_ choppedColumns: [ChoppedColumn]) -> [Int] {
    let initialSets: [Set<UInt8>] = choppedColumns.map(\.firstBytes)
    guard initialSets.allSatisfy({ !$0.isEmpty }) else { return [] }
    let canUseByteInitials = initialSets.allSatisfy { current in
      current.allSatisfy { $0 < 0x80 }
    }

    let initialStringSets: [Set<String>] = canUseByteInitials ? [] : choppedColumns.map { column in
      Set(column.candidates.compactMap { $0.text.first?.description })
    }
    if !canUseByteInitials, initialStringSets.contains(where: \ .isEmpty) {
      return []
    }

    var matchedNodeIDs = [Int]()
    for (currentInitials, nodeIDs) in keyInitialsIDMap {
      var allMatched = true
      if canUseByteInitials {
        let initialsBytes = Array(currentInitials.utf8)
        guard initialsBytes.count == initialSets.count else { continue }
        for index in initialsBytes.indices
          where !initialSets[index].contains(initialsBytes[index]) {
          allMatched = false
          break
        }
      } else {
        let initialsArray = currentInitials.map(\.description)
        guard initialsArray.count == initialStringSets.count else { continue }
        for index in initialsArray.indices
          where !initialStringSets[index].contains(initialsArray[index]) {
          allMatched = false
          break
        }
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
    choppedColumns: [ChoppedColumn],
    partiallyMatch: Bool
  )
    -> Bool {
    var nodeCellBytesCache: [String: [UInt8]] = [:]
    for index in nodeKeyArray.indices {
      let nodeCell = nodeKeyArray[index]
      let nodeBytes = nodeCellBytesCache[nodeCell] ?? {
        let bytes = Array(nodeCell.utf8)
        nodeCellBytesCache[nodeCell] = bytes
        return bytes
      }()

      var matched = false
      for candidate in choppedColumns[index].candidates {
        if candidate.bytes.isEmpty {
          matched = partiallyMatch ? nodeCell
            .hasPrefix(candidate.text) : (nodeCell == candidate.text)
        } else if partiallyMatch {
          matched = hasUTF8Prefix(nodeBytes, prefix: candidate.bytes)
        } else {
          matched = nodeBytes == candidate.bytes
        }
        if matched { break }
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
    return getNode(lower + 1)
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

private func hasUTF8Prefix(_ source: [UInt8], prefix: [UInt8]) -> Bool {
  guard source.count >= prefix.count else { return false }
  for index in 0 ..< prefix.count where source[index] != prefix[index] {
    return false
  }
  return true
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
