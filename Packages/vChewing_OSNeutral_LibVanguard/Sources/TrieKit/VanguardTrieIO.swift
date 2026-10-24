// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - VanguardTrie.TrieIO

extension VanguardTrie {
  /// 提供 Trie 資料結構的 Vanguard Pragma TextMap 格式讀寫與結構驗證功能。
  public enum TrieIO {
    // MARK: Public

    // MARK: - 例外型別

    /// Trie 輸入輸出操作可能發生的例外狀況
    public enum Exception: Swift.Error, LocalizedError {
      /// 序列化失敗
      case serializationFailed(String)
      /// 反序列化失敗
      case deserializationFailed(Swift.Error)
      /// 檔案載入失敗
      case fileLoadFailed(Swift.Error)

      // MARK: Public

      public var errorDescription: String? {
        switch self {
        case let .serializationFailed(message):
          return "序列化 Trie 失敗: \(message)"
        case let .deserializationFailed(error):
          return "反序列化 Trie 失敗: \(error.localizedDescription)"
        case let .fileLoadFailed(error):
          return "從檔案載入 Trie 失敗: \(error.localizedDescription)"
        }
      }
    }

    // MARK: - 驗證方法

    /// 驗證 Trie 結構的正確性
    /// - Parameter trie: 要驗證的 Trie 結構
    /// - Returns: 驗證結果與可能的錯誤資訊
    public static func validate(_ trie: Trie) -> (isValid: Bool, errors: [String]) {
      var errors = [String]()

      // 檢查根節點（`Trie.init(separator:)` 與 `clearAllContents()` 皆把根節點固定為 ID 0。）
      if trie.root.id != 0 {
        errors.append("根節點 ID 不正確：期望為 0，實際為 \(String(describing: trie.root.id))")
      }

      // 檢查節點辭典中的根節點
      if trie.nodes[0] == nil {
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

    /// 將 Trie 序列化為 TextMap 格式字串。
    /// - Parameter trie: 要序列化的 Trie 結構。
    /// - Returns: TextMap 格式的字串。
    /// - Throws: 詞值或前文含控制字元、前文超過兩層、或機率不是有限數值時拋錯。
    public static func serializeToTextMap(_ trie: Trie) throws -> String {
      let nodesWithEntries = trie.nodes.values
        .filter {
          !$0.readingKey.isEmpty && $0.entries.contains(where: { $0.typeID != revLookupEntryType })
        }
        .sorted { $0.readingKey < $1.readingKey }

      // 預設機率只採計無前文條目；contextual entries 的權重是另一個統計條件下的數值。
      var probsByType: [Int32: Set<Double>] = [:]
      for node in nodesWithEntries {
        for entry in node.entries where entry.typeID != revLookupEntryType {
          try validateEntryForSerialization(entry)
          if entry.context.isEmpty {
            probsByType[entry.typeID.rawValue, default: []].insert(entry.probability)
          }
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
        // 具有預設機率的無前文條目按 typeID 合併為型別 A。
        var groupedByType: [Int32: [String]] = [:]
        var ungrouped: [Trie.Entry] = []
        for entry in node.entries where entry.typeID != revLookupEntryType {
          if let defaultProb = defaultProbs[entry.typeID.rawValue],
             entry.probability == defaultProb, entry.context.isEmpty {
            try validateGroupedToken(entry.value)
            groupedByType[entry.typeID.rawValue, default: []].append(entry.value)
          } else {
            ungrouped.append(entry)
          }
        }
        try appendSerializedEntries(ungrouped, to: &valueLines)
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
      result += "VERSION\t2.0\n"
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
    /// 初期化時建立索引並驗證全部 VALUES 行，
    /// 詞條物化仍在查詢時按需進行。
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

    /// 解析單一 VALUES 行為詞條陣列。
    ///
    /// 此方法由 `parseTextMap` 與 `TextMapTrie` 共用，
    /// 確保完整物化與惰性解析兩條路徑使用同一份解析邏輯。
    internal static func parseValueLine(
      _ line: String,
      isTyping: Bool,
      defaultProbs: [Int32: Double]
    )
      -> [Trie.Entry] {
      (try? parseValidatedValueLine(line, isTyping: isTyping, defaultProbs: defaultProbs)) ?? []
    }

    /// 嚴格解析單一 VALUES 行；語法錯誤與「合法但沒有詞條」不共用回傳值。
    internal static func parseValidatedValueLine(
      _ line: String,
      isTyping: Bool,
      defaultProbs: [Int32: Double]
    )
      throws -> [Trie.Entry] {
      guard !line.isEmpty else { throw makeParseError("Empty VALUES line.") }
      let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
      guard let first = parts.first else { throw makeParseError("Empty VALUES line.") }

      // 型別 A：`>typeID\tencodedCell`；三／四欄仍可能是以 `>` 起首的 C 裸詞值。
      if first.hasPrefix(">"), parts.count == 2 {
        guard let typeIDRaw = Int32(first.dropFirst()),
              let probability = defaultProbs[typeIDRaw], probability.isFinite
        else { throw makeParseError("Malformed type-A VALUES line.") }
        let values = try decodeGroupedValues(String(parts[1]))
        return values.map { value in
          Trie.Entry(
            value: value,
            typeID: Trie.EntryType(rawValue: typeIDRaw),
            probability: probability,
            previous: nil
          )
        }
      }

      // 型別 B：`@probability\tchsCell\tchtCell`（TYPING 專用）。
      // `@` 後不是有限機率時，仍可能是以 `@` 起首的 C 裸詞值。
      if isTyping, parts.count == 3, first.hasPrefix("@"),
         let probability = parseTypingGroupedProbability(String(first)), probability.isFinite {
        var results: [Trie.Entry] = []
        for value in try decodeGroupedValues(String(parts[1]), allowsEmptyCell: true) {
          results.append(Trie.Entry(value: value, typeID: .init(rawValue: 5), probability: probability, previous: nil))
        }
        for value in try decodeGroupedValues(String(parts[2]), allowsEmptyCell: true) {
          results.append(Trie.Entry(value: value, typeID: .init(rawValue: 6), probability: probability, previous: nil))
        }
        return results
      }

      // 型別 D：`!value\ttypeID\tprobability\tcontextCell[…]`。
      // 三／四欄仍優先依型別 C 解讀，讓裸詞值本身以 `!` 起首時不產生歧義。
      if first.hasPrefix("!"), parts.count > 4 {
        guard parts.count % 2 == 0 else { throw makeParseError("Type-D line requires probability/context pairs.") }
        let pairCount = (parts.count - 2) / 2
        guard (2 ... 16).contains(pairCount) else {
          throw makeParseError("Type-D line must contain 2...16 entries.")
        }
        let value = String(first.dropFirst())
        try validateBareValue(value)
        guard let typeIDRaw = Int32(parts[1]) else { throw makeParseError("Invalid type-D typeID.") }
        var results: [Trie.Entry] = []
        results.reserveCapacity(pairCount)
        for pairIndex in 0 ..< pairCount {
          let probabilityIndex = 2 + pairIndex * 2
          let probability = try parseFiniteProbability(String(parts[probabilityIndex]))
          let context = try decodeGroupedValues(String(parts[probabilityIndex + 1]))
          guard (1 ... 2).contains(context.count) else {
            throw makeParseError("TextMap v2.0 supports only one or two context tokens.")
          }
          results.append(Trie.Entry(
            value: value,
            typeID: Trie.EntryType(rawValue: typeIDRaw),
            probability: probability,
            context: context
          ))
        }
        return results
      }

      // 型別 C：`value\tprobability\ttypeID[\tcontextCell]`，前文最多兩層。
      if parts.count == 3 || parts.count == 4,
         let probability = try? parseFiniteProbability(String(parts[1])),
         let typeIDRaw = Int32(parts[2]) {
        let value = String(parts[0])
        try validateBareValue(value)
        let context = try parts.count == 4 ? decodeGroupedValues(String(parts[3])) : []
        guard context.count <= 2, parts.count == 3 || !context.isEmpty else {
          throw makeParseError("Type-C context must contain one or two tokens when present.")
        }
        return [
          Trie.Entry(
            value: value,
            typeID: Trie.EntryType(rawValue: typeIDRaw),
            probability: probability,
            context: context
          ),
        ]
      }

      // 舊四欄 CHS/CHT 合併格式：第三欄不是 Int32 才可能是此格式。
      if isTyping, parts.count == 4, Int32(parts[2]) == nil {
        var results: [Trie.Entry] = []
        if !parts[0].isEmpty {
          let value = String(parts[0])
          try validateBareValue(value)
          results.append(Trie.Entry(
            value: value,
            typeID: .init(rawValue: 5),
            probability: try parseFiniteProbability(String(parts[1])),
            previous: nil
          ))
        }
        if !parts[2].isEmpty {
          let value = String(parts[2])
          try validateBareValue(value)
          results.append(Trie.Entry(
            value: value,
            typeID: .init(rawValue: 6),
            probability: try parseFiniteProbability(String(parts[3])),
            previous: nil
          ))
        }
        return results
      }

      // 舊 bare numeric grouped line：嚴格限定三欄，且第二欄不得是數字。
      if isTyping, parts.count == 3, isLegacyTypingGroupedLine(parts) {
        let probability = try parseFiniteProbability(String(parts[0]))
        var results: [Trie.Entry] = []
        for value in try decodeLegacyTypingGroupedValues(String(parts[1])) {
          results.append(Trie.Entry(value: value, typeID: .init(rawValue: 5), probability: probability, previous: nil))
        }
        for value in try decodeLegacyTypingGroupedValues(String(parts[2])) {
          results.append(Trie.Entry(value: value, typeID: .init(rawValue: 6), probability: probability, previous: nil))
        }
        return results
      }

      throw makeParseError("Malformed VALUES line.")
    }

    // MARK: Private

    private struct ContextualGroupKey: Hashable {
      let value: String
      let typeID: Int32
    }

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
      // 必須逐 Unicode scalar 掃描：空白若與組合符相連，Character 迭代會將兩者併成單一字群。
      for scalar in value.unicodeScalars {
        switch scalar {
        case #"\"#:
          result.unicodeScalars.append(#"\"#)
          result.unicodeScalars.append(#"\"#)
        case "|":
          result.unicodeScalars.append(#"\"#)
          result.unicodeScalars.append("|")
        case " ":
          result.unicodeScalars.append(#"\"#)
          result.unicodeScalars.append("s")
        case "\u{7}":
          result.unicodeScalars.append(#"\"#)
          result.unicodeScalars.append("a")
        default:
          result.unicodeScalars.append(scalar)
        }
      }
      return result
    }

    private static func appendSerializedEntries(
      _ entries: [Trie.Entry],
      to lines: inout [String]
    )
      throws {
      var contextualGroups: [ContextualGroupKey: [Trie.Entry]] = [:]
      for entry in entries where !entry.context.isEmpty {
        let key = ContextualGroupKey(value: entry.value, typeID: entry.typeID.rawValue)
        contextualGroups[key, default: []].append(entry)
      }

      var emittedGroups: Set<ContextualGroupKey> = []
      for entry in entries {
        guard !entry.context.isEmpty else {
          lines.append(try makeTypeCLine(for: entry))
          continue
        }
        let key = ContextualGroupKey(value: entry.value, typeID: entry.typeID.rawValue)
        guard emittedGroups.insert(key).inserted, let group = contextualGroups[key] else { continue }
        try appendContextualGroup(group, to: &lines)
      }
    }

    private static func appendContextualGroup(
      _ entries: [Trie.Entry],
      to lines: inout [String]
    )
      throws {
      guard let first = entries.first else { return }
      if entries.count == 1 {
        lines.append(try makeTypeCLine(for: first))
        return
      }

      var start = 0
      while start < entries.count {
        let remaining = entries.count - start
        // 最後一組不可落單：17＝15＋2、33＝16＋15＋2。
        let chunkCount = remaining == 17 ? 15 : min(remaining, 16)
        let chunk = Array(entries[start ..< (start + chunkCount)])
        var cells = ["!\(first.value)", first.typeID.rawValue.description]
        for entry in chunk {
          cells.append(formatProbability(entry.probability))
          cells.append(encodeGroupedValues(entry.context))
        }
        lines.append(cells.joined(separator: "\t"))
        start += chunkCount
      }
    }

    private static func makeTypeCLine(for entry: Trie.Entry) throws -> String {
      try validateBareValue(entry.value)
      guard entry.context.count <= 2 else {
        throw Exception.serializationFailed("TextMap v2.0 supports at most two context tokens.")
      }
      var cells = [
        entry.value,
        formatProbability(entry.probability),
        entry.typeID.rawValue.description,
      ]
      if !entry.context.isEmpty {
        cells.append(encodeGroupedValues(entry.context))
      }
      return cells.joined(separator: "\t")
    }

    private static func validateEntryForSerialization(_ entry: Trie.Entry) throws {
      guard entry.probability.isFinite else {
        throw Exception.serializationFailed("Entry probability must be finite.")
      }
      guard !entry.value.isEmpty else {
        throw Exception.serializationFailed("Entry value must not be empty.")
      }
      for scalar in entry.value.unicodeScalars where scalar.value != 0x07 {
        guard !isStructuralControl(scalar) else {
          let scalarID = "U+" + String(scalar.value, radix: 16, uppercase: true)
          throw Exception.serializationFailed(
            "Entry value \(entry.value.debugDescription) contains raw control character \(scalarID)."
          )
        }
      }
      guard entry.context.count <= 2 else {
        throw Exception.serializationFailed("TextMap v2.0 supports at most two context tokens.")
      }
      for token in entry.context {
        try validateGroupedToken(token)
      }
    }

    private static func validateBareValue(_ value: String) throws {
      guard !value.isEmpty else { throw makeParseError("Entry value must not be empty.") }
      for scalar in value.unicodeScalars {
        guard !isStructuralControl(scalar) else {
          throw makeParseError("Entry value contains a raw control character.")
        }
      }
    }

    private static func validateGroupedToken(_ token: String) throws {
      guard !token.isEmpty else { throw makeParseError("Grouped cells must not contain empty tokens.") }
      for scalar in token.unicodeScalars where scalar.value != 0x07 {
        if isStructuralControl(scalar) {
          throw makeParseError("Grouped cells must not contain raw control characters.")
        }
      }
    }

    /// 只拒絕會破壞文字格式的 Cc／換行；ZWJ 等 Cf 是合法詞值成分。
    private static func isStructuralControl(_ scalar: UnicodeScalar) -> Bool {
      scalar.properties.generalCategory == .control || CharacterSet.newlines.contains(scalar)
    }

    private static func decodeGroupedValues(
      _ rawCell: String,
      allowsEmptyCell: Bool = false
    )
      throws -> [String] {
      if rawCell.isEmpty {
        if allowsEmptyCell { return [] }
        throw makeParseError("Empty grouped cell.")
      }
      if rawCell == String(emptyGroupedCellPlaceholder) { return [] }

      var result: [String] = []
      var currentBytes: [UInt8] = []
      currentBytes.reserveCapacity(rawCell.utf8.count)
      let escapeByte = UInt8(ascii: "\\")
      let separatorByte = UInt8(ascii: "|")
      var isEscaping = false

      func finishToken() throws {
        guard !currentBytes.isEmpty else { throw makeParseError("Grouped cells must not contain empty tokens.") }
        let token = String(decoding: currentBytes, as: UTF8.self)
        for scalar in token.unicodeScalars where scalar.value >= 0x80 {
          if isStructuralControl(scalar) {
            throw makeParseError("Grouped cells contain raw control characters.")
          }
        }
        result.append(token)
        currentBytes.removeAll(keepingCapacity: true)
      }

      for byte in rawCell.utf8 {
        if isEscaping {
          switch byte {
          case escapeByte:
            currentBytes.append(escapeByte)
          case separatorByte:
            currentBytes.append(separatorByte)
          case UInt8(ascii: "s"):
            currentBytes.append(UInt8(ascii: " "))
          case UInt8(ascii: "a"):
            currentBytes.append(0x07)
          default:
            throw makeParseError("Unknown grouped-cell escape sequence.")
          }
          isEscaping = false
          continue
        }
        if byte == escapeByte {
          isEscaping = true
          continue
        }
        if byte == separatorByte {
          try finishToken()
          continue
        }
        if byte <= 0x20 || byte == 0x7F {
          throw makeParseError("Grouped cells require escaped spaces and no raw control characters.")
        }
        currentBytes.append(byte)
      }
      guard !isEscaping else { throw makeParseError("Dangling grouped-cell escape.") }
      try finishToken()
      return result
    }

    private static func decodeLegacyTypingGroupedValues(_ rawCell: String) throws -> [String] {
      if rawCell.isEmpty || rawCell == String(emptyGroupedCellPlaceholder) { return [] }
      if rawCell.utf8.contains(UInt8(ascii: "|")) || rawCell.utf8.contains(UInt8(ascii: "\\")) {
        return try decodeGroupedValues(rawCell, allowsEmptyCell: true)
      }
      let values = rawCell.split(separator: " ").map(String.init)
      for value in values { try validateBareValue(value) }
      return values
    }

    private static func parseFiniteProbability(_ rawValue: String) throws -> Double {
      guard let probability = Double(rawValue), probability.isFinite else {
        throw makeParseError("Entry probability must be a finite Double.")
      }
      return probability
    }

    private static func parseTypingGroupedProbability(_ rawValue: String) -> Double? {
      guard rawValue.first == typingGroupedLinePrefix else { return nil }
      return Double(String(rawValue.dropFirst()))
    }

    private static func isLegacyTypingGroupedLine(_ parts: [Substring]) -> Bool {
      guard parts.count == 3,
            let probability = Double(parts[0]), probability.isFinite,
            Double(parts[1]) == nil
      else { return false }
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
      for (index, line) in valueLines.enumerated() {
        do {
          _ = try parseValidatedValueLine(line, isTyping: isTyping, defaultProbs: defaultProbs)
        } catch {
          throw makeParseError("Invalid VALUES line \(index): \(error.localizedDescription)")
        }
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
          for entry in parsed {
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
      let parts = versionLine.split(separator: "\t", omittingEmptySubsequences: false)
      guard parts.count == 2, parts[0] == "VERSION",
            parts[1].trimmingCharacters(in: .whitespaces) == "2.0"
      else {
        throw makeParseError("TextMap v2.0 requires an explicit `VERSION\\t2.0` header line.")
      }
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
