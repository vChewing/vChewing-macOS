// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - VanguardTrie.TrieIO

extension VanguardTrie {
  /// 提供 Trie 資料結構的高效二進位序列化與反序列化功能
  public enum TrieIO {
    // MARK: Public

    // MARK: - 例外型別

    /// Trie 輸入輸出操作可能發生的例外狀況
    public enum Exception: Swift.Error, LocalizedError {
      /// 序列化失敗
      case serializationFailed(Swift.Error)
      /// 反序列化失敗
      case deserializationFailed(Swift.Error)
      /// 檔案儲存失敗
      case fileSaveFailed(Swift.Error)
      /// 檔案載入失敗
      case fileLoadFailed(Swift.Error)

      // MARK: Public

      public var errorDescription: String? {
        switch self {
        case let .serializationFailed(error):
          return "序列化 Trie 失敗: \(error.localizedDescription)"
        case let .deserializationFailed(error):
          return "反序列化 Trie 失敗: \(error.localizedDescription)"
        case let .fileSaveFailed(error):
          return "儲存 Trie 至檔案失敗: \(error.localizedDescription)"
        case let .fileLoadFailed(error):
          return "從檔案載入 Trie 失敗: \(error.localizedDescription)"
        }
      }
    }

    // MARK: - 公開方法

    /// 將 Trie 序列化為二進位資料
    /// - Parameter trie: 要序列化的 Trie 結構
    /// - Returns: 二進位資料
    /// - Throws: 序列化過程中的例外狀況
    public static func serialize(_ trie: Trie) throws -> Data {
      do {
        // 使用 PropertyListEncoder 序列化為二進位格式
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(trie)
      } catch {
        throw Exception.serializationFailed(error)
      }
    }

    /// 從二進位資料反序列化 Trie 結構
    /// - Parameter data: 二進位資料
    /// - Returns: 反序列化的 Trie 結構
    /// - Throws: 反序列化過程中的例外狀況
    public static func deserialize(_ data: Data) throws -> Trie {
      do {
        // 使用 PropertyListDecoder 反序列化
        let decoder = PropertyListDecoder()
        return try decoder.decode(Trie.self, from: data)
      } catch {
        throw Exception.deserializationFailed(error)
      }
    }

    /// 將 Trie 儲存到指定路徑
    /// - Parameters:
    ///   - trie: 要儲存的 Trie 結構
    ///   - url: 儲存路徑
    /// - Throws: 序列化或檔案寫入過程中的例外狀況
    public static func save(_ trie: Trie, to url: URL) throws {
      let data = try serialize(trie)

      do {
        try data.write(to: url, options: .atomic)
      } catch {
        throw Exception.fileSaveFailed(error)
      }
    }

    /// 從指定路徑載入 Trie
    /// - Parameter url: Trie 檔案路徑
    /// - Returns: 載入的 Trie 結構
    /// - Throws: 檔案讀取或反序列化過程中的例外狀況
    public static func load(from url: URL) throws -> Trie {
      do {
        let data = try Data(contentsOf: url)
        return try deserialize(data)
      } catch let error as Exception {
        throw error
      } catch {
        throw Exception.fileLoadFailed(error)
      }
    }

    // MARK: - 驗證方法

    /// 驗證 Trie 結構的正確性
    /// - Parameter trie: 要驗證的 Trie 結構
    /// - Returns: 驗證結果與可能的錯誤資訊
    public static func validate(_ trie: Trie) -> (isValid: Bool, errors: [String]) {
      var errors = [String]()

      // 檢查根節點
      if trie.root.id != 1 {
        errors.append("根節點 ID 不正確：期望為 1，實際為 \(String(describing: trie.root.id))")
      }

      // 檢查節點辭典中的根節點
      if trie.nodes[1] == nil {
        errors.append("節點辭典中缺少根節點")
      }

      // 檢查節點關係的一致性
      for (id, node) in trie.nodes {
        // 檢查 ID 一致性
        if node.id != id {
          errors.append("節點 ID 不一致：辭典鍵為 \(id)，節點 ID 為 \(String(describing: node.id))")
        }

        // 檢查子節點關係
        for (_, childID) in node.children {
          if trie.nodes[childID] == nil {
            errors.append("節點 \(id) 引用了不存在的子節點 \(childID)")
          }
        }
      }

      return (errors.isEmpty, errors)
    }

    /// 將 Trie 序列化為 TextMap 格式字串
    /// - Parameter trie: 要序列化的 Trie 結構
    /// - Returns: TextMap 格式的字串
    public static func serializeToTextMap(_ trie: Trie) -> String {
      let nodesWithEntries = trie.nodes.values
        .filter {
          !$0.readingKey.isEmpty && $0.entries.contains(where: { $0.typeID != revLookupEntryType })
        }
        .sorted { $0.readingKey < $1.readingKey }

      // 計算每個 typeID 的預設機率。
      var probsByType: [Int32: Set<Double>] = [:]
      for node in nodesWithEntries {
        for entry in node.entries where entry.typeID != revLookupEntryType {
          probsByType[entry.typeID.rawValue, default: []].insert(entry.probability)
        }
      }
      var defaultProbs: [Int32: Double] = [:]
      for (typeID, probs) in probsByType where probs.count == 1 {
        defaultProbs[typeID] = probs.first!
      }

      var valueLines = [String]()
      var keyMapLines = [String]()

      for node in nodesWithEntries {
        let startLine = valueLines.count
        // 具有預設機率的條目按 typeID 合併為 `>typeID\tencodedCell` 格式。
        var groupedByType: [Int32: [String]] = [:]
        for entry in node.entries where entry.typeID != revLookupEntryType {
          if let defaultProb = defaultProbs[entry.typeID.rawValue],
             entry.probability == defaultProb, entry.previous == nil {
            groupedByType[entry.typeID.rawValue, default: []].append(entry.value)
          } else {
            var parts = [String]()
            parts.append(entry.value)
            parts.append(formatProbability(entry.probability))
            parts.append(entry.typeID.rawValue.description)
            if let previous = entry.previous {
              parts.append(previous)
            }
            valueLines.append(parts.joined(separator: "\t"))
          }
        }
        for (typeID, values) in groupedByType.sorted(by: { $0.key < $1.key }) {
          valueLines.append(">\(typeID)\t\(encodeGroupedValues(values))")
        }
        let count = valueLines.count - startLine
        if count > 0 {
          keyMapLines.append("\(node.readingKey)\t\(startLine)\t\(count)")
        }
      }

      var result = ""
      result += "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER\n"
      result += "VERSION\t1.1\n"
      result += "TYPE\tTRIE_TEXTMAP\n"
      result += "READING_SEPARATOR\t\(trie.readingSeparator)\n"
      result += "ENTRY_COUNT\t\(valueLines.count)\n"
      result += "KEY_COUNT\t\(keyMapLines.count)\n"
      for (typeID, prob) in defaultProbs.sorted(by: { $0.key < $1.key }) {
        result += "DEFAULT_PROB_\(typeID)\t\(formatProbability(prob))\n"
      }
      result += "#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\n"
      for line in valueLines {
        result += line
        result += "\n"
      }
      result += "#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP\n"
      for line in keyMapLines {
        result += line
        result += "\n"
      }
      return result
    }

    /// 從 TextMap 格式的 Data 反序列化 Trie 結構
    /// - Parameter data: TextMap 格式的 UTF-8 Data
    /// - Returns: 反序列化後的 Trie 結構
    /// - Throws: 反序列化過程中的例外狀況
    public static func deserializeFromTextMap(_ data: Data) throws -> Trie {
      guard let content = String(data: data, encoding: .utf8) else {
        throw Exception.deserializationFailed(
          NSError(domain: "VanguardTrie.TrieIO", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "TextMap data is not valid UTF-8.",
          ])
        )
      }
      return try deserializeFromTextMap(content)
    }

    /// 從 TextMap 格式的字串反序列化 Trie 結構
    /// - Parameter content: TextMap 格式字串
    /// - Returns: 反序列化後的 Trie 結構
    /// - Throws: 反序列化過程中的例外狀況
    public static func deserializeFromTextMap(_ content: String) throws -> Trie {
      do {
        return try parseTextMap(content)
      } catch {
        throw Exception.deserializationFailed(error)
      }
    }

    /// 從 TextMap 檔案載入 Trie
    /// - Parameter url: TextMap 檔案路徑
    /// - Returns: 載入的 Trie 結構
    /// - Throws: 檔案讀取或反序列化過程中的例外狀況
    public static func loadFromTextMap(url: URL) throws -> Trie {
      do {
        let data = try Data(contentsOf: url)
        return try deserializeFromTextMap(data)
      } catch let error as Exception {
        throw error
      } catch {
        throw Exception.fileLoadFailed(error)
      }
    }

    /// 從 TextMap 檔案以惰性模式載入 TextMapTrie。
    ///
    /// 初期化時僅解析 HEADER 與 KEY_LINE_MAP 建立索引，
    /// VALUES 區段的詞條在查詢時才按需解析。
    /// - Parameter url: TextMap 檔案路徑
    /// - Returns: 惰性載入的 TextMapTrie 結構
    /// - Throws: 檔案讀取或解析過程中的例外狀況
    public static func loadFromTextMapLazy(url: URL) throws -> TextMapTrie {
      do {
        let data = try Data(contentsOf: url)
        return try TextMapTrie(data: data)
      } catch let error as Exception {
        throw error
      } catch {
        throw Exception.fileLoadFailed(error)
      }
    }

    // MARK: Internal

    // MARK: - TextMap 解析實作

    /// 解析單一 VALUES 行為詞條元組陣列。
    ///
    /// 此方法由 `parseTextMap` 與 `TextMapTrie` 共用，
    /// 確保完整物化與惰性解析兩條路徑使用同一份解析邏輯。
    internal static func parseValueLine(
      _ line: String,
      isTyping: Bool,
      defaultProbs: [Int32: Double]
    )
      -> [(value: String, typeID: Trie.EntryType, probability: Double, previous: String?)] {
      guard !line.isEmpty else { return [] }
      let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)

      // 型別 A：`>typeID\tencodedCell`（預設機率由 HEADER 提供）。
      if let first = parts.first, first.hasPrefix(">"), parts.count >= 2 {
        let typeIDStr = String(first.dropFirst())
        guard let typeIDRaw = Int32(typeIDStr),
              let probability = defaultProbs[typeIDRaw] else { return [] }
        let typeID = Trie.EntryType(rawValue: typeIDRaw)
        return decodeGroupedValues(parts[1]).map { value in
          (value, typeID, probability, nil)
        }
      }

      // 型別 B：`@probability\tchsCell\tchtCell`（TYPING 專用）。
      if isTyping, parts.count >= 3, let prob = parseTypingGroupedProbability(parts[0]) {
        var results: [(String, Trie.EntryType, Double, String?)] = []
        for val in decodeGroupedValues(parts[1]) where !val.isEmpty {
          results.append((val, .init(rawValue: 5), prob, nil))
        }
        for val in decodeGroupedValues(parts[2]) where !val.isEmpty {
          results.append((val, .init(rawValue: 6), prob, nil))
        }
        return results
      }

      // 型別 C：`value\tprobability\ttypeID[\tprevious]`。
      if parts.count >= 3,
         let probability = Double(parts[1]),
         let typeIDRaw = Int32(parts[2]) {
        let value = parts[0]
        let previous: String? = parts.count >= 4 && !parts[3].isEmpty ? parts[3] : nil
        return [(value, Trie.EntryType(rawValue: typeIDRaw), probability, previous)]
      }

      // 舊四欄 CHS/CHT 合併格式（相容路徑）。
      if isTyping, parts.count >= 4 {
        var results: [(String, Trie.EntryType, Double, String?)] = []
        if !parts[0].isEmpty, let prob = Double(parts[1]) {
          results.append((parts[0], .init(rawValue: 5), prob, nil))
        }
        if !parts[2].isEmpty, let prob = Double(parts[3]) {
          results.append((parts[2], .init(rawValue: 6), prob, nil))
        }
        return results
      }

      // 舊 bare numeric grouped line（相容路徑）。
      if isTyping, parts.count >= 3, isLegacyTypingGroupedLine(parts),
         let prob = Double(parts[0]) {
        var results: [(String, Trie.EntryType, Double, String?)] = []
        for val in decodeGroupedValues(parts[1]) where !val.isEmpty {
          results.append((val, .init(rawValue: 5), prob, nil))
        }
        for val in decodeGroupedValues(parts[2]) where !val.isEmpty {
          results.append((val, .init(rawValue: 6), prob, nil))
        }
        return results
      }

      return []
    }

    // MARK: Private

    private static let typingGroupedLinePrefix: Character = "@"
    private static let groupedValueSeparator: Character = "|"
    private static let groupedValueEscape: Character = #"\"#
    private static let emptyGroupedCellPlaceholder: Character = "\u{7}"
    private static let revLookupEntryType = Trie.EntryType(rawValue: 3)
    private static let cnsEntryType = Trie.EntryType(rawValue: 7)

    // MARK: - TextMap 序列化方法

    /// 將 Double 機率值格式化為字串，若小數部分為零則以整數呈現。
    private static func formatProbability(_ value: Double) -> String {
      let str = value.description
      return str.hasSuffix(".0") ? String(str.dropLast(2)) : str
    }

    private static func encodeGroupedValues(_ values: [String]) -> String {
      guard !values.isEmpty else { return String(emptyGroupedCellPlaceholder) }
      return values.map(escapeGroupedValue).joined(separator: String(groupedValueSeparator))
    }

    private static func escapeGroupedValue(_ value: String) -> String {
      var result = ""
      result.reserveCapacity(value.count)
      for char in value {
        switch char {
        case groupedValueEscape:
          result.append(groupedValueEscape)
          result.append(groupedValueEscape)
        case groupedValueSeparator:
          result.append(groupedValueEscape)
          result.append(groupedValueSeparator)
        case " ":
          result.append(groupedValueEscape)
          result.append("s")
        case emptyGroupedCellPlaceholder:
          result.append(groupedValueEscape)
          result.append("a")
        default:
          result.append(char)
        }
      }
      return result
    }

    private static func decodeGroupedValues(_ rawCell: String) -> [String] {
      guard !rawCell.isEmpty, rawCell != String(emptyGroupedCellPlaceholder) else { return [] }
      if rawCell.contains(groupedValueSeparator) || rawCell.contains(groupedValueEscape) {
        return splitEscapedGroupedValues(rawCell).map(unescapeGroupedValue)
      }
      if rawCell.contains(" ") {
        return rawCell.split(separator: " ").map(String.init)
      }
      return [rawCell]
    }

    private static func splitEscapedGroupedValues(_ rawCell: String) -> [String] {
      var result: [String] = []
      var current = ""
      current.reserveCapacity(rawCell.count)
      var isEscaping = false
      for char in rawCell {
        if isEscaping {
          current.append(groupedValueEscape)
          current.append(char)
          isEscaping = false
          continue
        }
        if char == groupedValueEscape {
          isEscaping = true
          continue
        }
        if char == groupedValueSeparator {
          result.append(current)
          current.removeAll(keepingCapacity: true)
          continue
        }
        current.append(char)
      }
      if isEscaping {
        current.append(groupedValueEscape)
      }
      result.append(current)
      return result
    }

    private static func unescapeGroupedValue(_ rawValue: String) -> String {
      var result = ""
      result.reserveCapacity(rawValue.count)
      var isEscaping = false
      for char in rawValue {
        if isEscaping {
          switch char {
          case groupedValueEscape:
            result.append(groupedValueEscape)
          case groupedValueSeparator:
            result.append(groupedValueSeparator)
          case "s":
            result.append(" ")
          case "a":
            result.append(emptyGroupedCellPlaceholder)
          default:
            result.append(groupedValueEscape)
            result.append(char)
          }
          isEscaping = false
          continue
        }
        if char == groupedValueEscape {
          isEscaping = true
          continue
        }
        result.append(char)
      }
      if isEscaping {
        result.append(groupedValueEscape)
      }
      return result
    }

    private static func parseTypingGroupedProbability(_ rawValue: String) -> Double? {
      guard rawValue.first == typingGroupedLinePrefix else { return nil }
      return Double(String(rawValue.dropFirst()))
    }

    private static func isLegacyTypingGroupedLine(_ parts: [String]) -> Bool {
      guard parts.count >= 3, Double(parts[0]) != nil else { return false }
      if parts[1].isEmpty || parts[2].isEmpty { return true }
      if parts[1] == String(emptyGroupedCellPlaceholder) || parts[2] ==
        String(emptyGroupedCellPlaceholder) {
        return true
      }
      if parts[1].contains(" ") || parts[2].contains(" ") { return true }
      if parts[1].contains(groupedValueSeparator) || parts[2].contains(groupedValueSeparator) {
        return true
      }
      if parts[1].contains(groupedValueEscape) || parts[2].contains(groupedValueEscape) {
        return true
      }
      return Int32(parts[2]) == nil
    }

    private static func parseTextMap(_ content: String) throws -> Trie {
      let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        .map(String.init)
      var lineIndex = 0

      // 解析 HEADER
      guard lineIndex < lines.count,
            lines[lineIndex] == "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER" else {
        throw makeParseError("Missing #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER")
      }
      lineIndex += 1
      if lineIndex < lines.count {
        try rejectUnsupportedTextMapVersionLine(lines[lineIndex])
      }

      var separatorChar: Character = "-"
      var entryCount = 0
      var keyCount = 0
      var isTyping = false
      var defaultProbs: [Int32: Double] = [:]

      while lineIndex < lines.count, !lines[lineIndex].hasPrefix("#PRAGMA:") {
        let parts = lines[lineIndex].split(separator: "\t", maxSplits: 1).map(String.init)
        if parts.isEmpty { lineIndex += 1; continue }
        if parts.count >= 2 {
          switch parts[0] {
          case "READING_SEPARATOR":
            if let c = parts[1].first { separatorChar = c }
          case "ENTRY_COUNT":
            entryCount = Int(parts[1]) ?? 0
          case "KEY_COUNT":
            keyCount = Int(parts[1]) ?? 0
          case "TYPE":
            isTyping = parts[1] == "TYPING"
          default:
            if parts[0].hasPrefix("DEFAULT_PROB_") {
              let typeIDStr = String(parts[0].dropFirst("DEFAULT_PROB_".count))
              if let typeIDRaw = Int32(typeIDStr), let prob = Double(parts[1]) {
                defaultProbs[typeIDRaw] = prob
              }
            }
          }
        }
        lineIndex += 1
      }

      // 解析 VALUES
      guard lineIndex < lines.count,
            lines[lineIndex] == "#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES" else {
        throw makeParseError("Missing #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES")
      }
      lineIndex += 1

      var valueLines = [String]()
      valueLines.reserveCapacity(entryCount)
      while lineIndex < lines.count, !lines[lineIndex].hasPrefix("#PRAGMA:") {
        valueLines.append(lines[lineIndex])
        lineIndex += 1
      }

      // 解析 KEY_LINE_MAP
      guard lineIndex < lines.count,
            lines[lineIndex] == "#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP"
      else {
        throw makeParseError("Missing #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP")
      }
      lineIndex += 1

      var keyMapEntries = [(readingKey: String, startLine: Int, count: Int)]()
      keyMapEntries.reserveCapacity(keyCount)
      while lineIndex < lines.count {
        let line = lines[lineIndex]
        if line.isEmpty { lineIndex += 1; continue }
        let parts = line.split(separator: "\t").map(String.init)
        guard parts.count >= 3,
              let start = Int(parts[1]),
              let cnt = Int(parts[2]) else {
          lineIndex += 1
          continue
        }
        keyMapEntries.append((parts[0], start, cnt))
        lineIndex += 1
      }

      // 從解析結果重建 Trie。
      let trie = Trie(separator: separatorChar)
      for keyMapEntry in keyMapEntries {
        let readingArray = keyMapEntry.readingKey.split(separator: separatorChar).map(String.init)
        let end = min(keyMapEntry.startLine + keyMapEntry.count, valueLines.count)
        for i in keyMapEntry.startLine ..< end {
          let valueLine = valueLines[i]
          guard !valueLine.isEmpty else { continue }
          let parsed = parseValueLine(valueLine, isTyping: isTyping, defaultProbs: defaultProbs)
          for p in parsed {
            let entry = Trie.Entry(
              value: p.value,
              typeID: p.typeID,
              probability: p.probability,
              previous: p.previous
            )
            trie.insert(entry: entry, readings: readingArray)
          }
        }
      }

      let autoGeneratedRevLookup = buildAutoGeneratedRevLookup(
        valueLines: valueLines,
        keyMapEntries: keyMapEntries,
        isTyping: isTyping,
        defaultProbs: defaultProbs,
        separator: separatorChar
      )
      for (character, readings) in autoGeneratedRevLookup {
        let entry = Trie.Entry(
          value: readings.joined(separator: "\t"),
          typeID: revLookupEntryType,
          probability: 0,
          previous: nil
        )
        trie.insert(entry: entry, readings: [character])
      }

      return trie
    }

    private static func rejectUnsupportedTextMapVersionLine(_ versionLine: String) throws {
      guard !isUnsupportedLegacyTextMapVersionLine(versionLine) else {
        throw makeParseError("TextMap format versions below 1.1 are no longer supported.")
      }
    }

    private static func isUnsupportedLegacyTextMapVersionLine(_ versionLine: String) -> Bool {
      versionLine.hasPrefix("VERSION\t1") && !versionLine.contains(".")
    }

    private static func buildAutoGeneratedRevLookup(
      valueLines: [String],
      keyMapEntries: [(readingKey: String, startLine: Int, count: Int)],
      isTyping: Bool,
      defaultProbs: [Int32: Double],
      separator: Character
    )
      -> [(character: String, readings: [String])] {
      var charToReadings: [String: [String]] = [:]
      var charToSeenReadings: [String: Set<String>] = [:]

      for keyMapEntry in keyMapEntries {
        let segmentCount = keyMapEntry.readingKey.split(separator: separator).count
        let end = min(keyMapEntry.startLine + keyMapEntry.count, valueLines.count)
        for i in keyMapEntry.startLine ..< end {
          let valueLine = valueLines[i]
          guard !valueLine.isEmpty else { continue }
          let includeGroupedTypingLine = valueLine.first == "@" && segmentCount == 1
          let parsed = parseValueLine(valueLine, isTyping: isTyping, defaultProbs: defaultProbs)
          for parsedEntry in parsed {
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
              if charToSeenReadings[
                character, default: []
              ].insert(keyMapEntry.readingKey).inserted {
                charToReadings[character, default: []].append(keyMapEntry.readingKey)
              }
            }
          }
        }
      }

      return charToReadings.keys.sorted().compactMap { currentCharacter in
        guard let readings = charToReadings[currentCharacter], !readings.isEmpty else { return nil }
        return (currentCharacter, readings)
      }
    }

    private static func makeParseError(_ message: String) -> NSError {
      NSError(domain: "VanguardTrie.TrieIO.TextMap", code: -1, userInfo: [
        NSLocalizedDescriptionKey: message,
      ])
    }
  }
}
