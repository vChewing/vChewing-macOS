// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import Homa

// MARK: - HomaTestSuite

public protocol HomaTestSuite {}

extension HomaTestSuite {
  public static func makeAssemblerUsingMockLM() -> Homa.Assembler {
    .init(
      gramQuerier: { keyArray in
        [
          Homa.Gram(
            keyArray: keyArray,
            current: keyArray.joined(separator: "-"),
            previous: nil,
            probability: -1
          ).asTuple,
        ]
      },
      gramAvailabilityChecker: {
        $0.reduce(0) { $1.isEmpty ? $0 : $0 + $1.count } != 0
      }
    )
  }

  public static func mustDone(_ task: @escaping () throws -> ()) -> Bool {
    do {
      try task()
      return true
    } catch {
      return false
    }
  }

  public static func mustFail(_ task: @escaping () throws -> ()) -> Bool {
    do {
      try task()
      return false
    } catch {
      return true
    }
  }

  public static func measureTime(_ task: @escaping () throws -> ()) rethrows -> Double {
    let startTime = Date().timeIntervalSince1970
    try task()
    return Date().timeIntervalSince1970 - startTime
  }
}

// MARK: - Assembler Extensions for Test Purposes Only.

extension Homa.Assembler {
  /// 該函式已被淘汰，因為有「仍有極端場合無法徹底清除 node-crossing 內容」的故障。
  /// 現僅用於單元測試、以確認其繼任者是否有給出所有該給出的正常結果。
  /// - Parameter location: 游標位置。
  /// - Returns: 候選字音配對陣列。
  public func fetchCandidatesDeprecated(
    at location: Int,
    filter: CandidateFetchFilter = .all
  )
    -> [Homa.CandidatePairWeighted] {
    var result = [Homa.CandidatePairWeighted]()
    guard !keys.isEmpty else { return result }
    let location = max(min(location, keys.count - 1), 0) // 防呆
    let anchors: [(location: Int, node: Homa.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    anchors.map(\.node).forEach { theNode in
      theNode.grams.forEach { gram in
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          if !theNode.keyArray.contains(keyAtCursor) { return }
        case .beginAt:
          if theNode.keyArray[0] != keyAtCursor { return }
        case .endAt:
          if theNode.keyArray.reversed()[0] != keyAtCursor { return }
        }
        result.append(.init(
          pair: .init(keyArray: theNode.keyArray, value: gram.current),
          weight: gram.probability
        ))
      }
    }
    var seen = Set<Homa.CandidatePairWeighted>()
    return result.filter {
      seen.insert($0).inserted
    }
  }
}

// MARK: - Dumping Unigrams from the Assembler.

extension Homa.Assembler {
  public func dumpUnigrams() -> String {
    segments.map { currentSegment in
      currentSegment.values.map { currentNode in
        currentNode.grams.map { currentGram in
          let readingChain = currentGram.keyArray.joined(separator: "-")
          let value = currentGram.current
          let score = currentGram.probability
          return "\(readingChain) \(value) \(score)"
        }
        .joined(separator: "\n")
      }
      .joined(separator: "\n")
    }
    .joined(separator: "\n")
  }
}

// MARK: - TestLM

public final class TestLM {
  // MARK: Lifecycle

  public init(
    rawData: String,
    readingSeparator: String = "-",
    valueSegmentationOnly: Bool = false
  ) {
    self.trie = SimpleTrie(separator: readingSeparator)
    rawData.split(whereSeparator: \.isNewline).forEach { line in
      let components = line.split(whereSeparator: \.isWhitespace)
      guard components.count >= 3 else { return }
      let value = String(components[1])
      guard let probability = Double(components[2].description) else { return }
      let previous = components.count > 3 ? String(components[3]) : nil
      let readings: [String] = valueSegmentationOnly
        ? value.map(\.description)
        : components[0].sliced(by: readingSeparator).map(\.description)
      let entry = SimpleTrie.Entry(
        value: value,
        probability: probability,
        previous: previous
      )
      trie.insert(entry: entry, readings: readings)
    }
  }

  // MARK: Public

  public var readingSeparator: String { trie.readingSeparator.description }

  public func hasGrams(
    _ keys: [String],
    partiallyMatch: Bool = false
  )
    -> Bool {
    guard !keys.isEmpty else { return false }
    return trie.hasGrams(
      keys,
      partiallyMatch: partiallyMatch
    )
  }

  public func queryGrams(
    _ keys: [String],
    partiallyMatch: Bool = false
  )
    -> [(keyArray: [String], value: String, probability: Double, previous: String?)] {
    guard !keys.isEmpty else { return [] }
    return trie.queryGrams(
      keys,
      partiallyMatch: partiallyMatch
    )
  }

  // MARK: Private

  private let trie: SimpleTrie
}

// MARK: - SimpleTrie

/// Literarily the Vanguard Trie sans EntryType and Codable support.
public final class SimpleTrie {
  // MARK: Lifecycle

  public init(separator: String) {
    self.readingSeparator = separator
    self.root = .init(id: 0)
    self.nodes = [:]

    // 初期化時，將根節點加入到節點辭典中
    root.id = 0
    root.parentID = nil
    root.character = ""
    nodes[0] = root
    self.keyChainIDMap = [:]
  }

  // MARK: Public

  public final class TNode: Hashable, Identifiable {
    // MARK: Lifecycle

    public init(
      id: Int,
      entries: [Entry] = [],
      parentID: Int? = nil,
      character: String = "",
      readingKey: String = ""
    ) {
      self.id = id
      self.entries = entries
      self.parentID = parentID
      self.character = character
      self.children = [:]
      self.readingKey = readingKey
    }

    // MARK: Public

    public internal(set) var id: Int = 0
    public internal(set) var entries: [Entry] = []
    public internal(set) var parentID: Int?
    public internal(set) var character: String = ""
    public internal(set) var readingKey: String = "" // 新增：存儲節點對應的讀音鍵
    public internal(set) var children: [String: Int] = [:] // 新的結構：字元 -> 子節點ID映射

    public static func == (
      lhs: TNode,
      rhs: TNode
    )
      -> Bool {
      lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(entries)
      hasher.combine(parentID)
      hasher.combine(character)
      hasher.combine(readingKey)
      hasher.combine(children)
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
      case id
      case entries
      case parentID
      case character
      case readingKey
      case children
    }
  }

  public struct Entry: Hashable, Sendable {
    // MARK: Lifecycle

    public init(
      value: String,
      probability: Double,
      previous: String?
    ) {
      self.value = value
      self.probability = probability
      self.previous = previous
    }

    // MARK: Public

    public let value: String
    public let probability: Double
    public let previous: String?

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      var stack = [String]()
      stack.append(value)
      stack.append(probability.description)
      if let previous {
        stack.append(previous)
      }
      try container.encode(stack.joined(separator: "\t"))
    }

    // MARK: Private

    private enum CodingKeysAlt: String, CodingKey {
      case value
      case probability
      case previous
    }
  }

  public let readingSeparator: String
  public let root: TNode
  public internal(set) var nodes: [Int: TNode] // 新增：節點辭典，以id為索引
  public internal(set) var keyChainIDMap: [String: Set<Int>]

  // MARK: Private

  private enum CodingKeys: CodingKey {
    case readingSeparator
    case nodes
  }
}

// MARK: - Extending Methods (Trie: Insert and Search API).

extension SimpleTrie {
  public func insert(entry: Entry, readings: [String]) {
    var currentNode = root
    var currentNodeID = 0

    let key = readings.joined(separator: readingSeparator)

    // 遍歷關鍵字的每個字元
    key.forEach { char in
      let charStr = char.description
      if let childNodeID = currentNode.children[charStr],
         let matchedNode = nodes[childNodeID] {
        // 有效的子節點已存在，繼續遍歷
        currentNodeID = childNodeID
        currentNode = matchedNode
        return
      }
      // 創建新的子節點
      let newNodeID = nodes.count
      let newNode = TNode(id: newNodeID, parentID: currentNodeID, character: charStr)

      // 更新關係
      currentNode.children[charStr] = newNodeID
      nodes[newNodeID] = newNode

      // 更新當前節點
      currentNode = newNode
      currentNodeID = newNodeID
    }

    // 在最終節點設定讀音鍵並添加詞條
    currentNode.readingKey = key
    currentNode.entries.append(entry)

    // 更新 keyChainIDMap
    keyChainIDMap[key, default: []].insert(currentNodeID)
  }

  public func clearAllContents() {
    root.children.removeAll()
    root.entries.removeAll()
    root.id = 0
    nodes.removeAll()
    nodes[0] = root
    updateKeyChainIDMap()
  }

  internal func updateKeyChainIDMap() {
    // 清空現有映射以確保資料一致性
    keyChainIDMap.removeAll()

    // 遍歷所有節點和條目來重建映射
    nodes.forEach { nodeID, node in
      node.entries.forEach { _ in
        let keyChainStr = node.readingKey
        keyChainIDMap[keyChainStr, default: []].insert(nodeID)
      }
    }
  }
}

// MARK: - Extending Methods (Entry).

extension SimpleTrie.Entry {
  public func asTuple(with readings: [String]) -> (
    keyArray: [String],
    value: String,
    probability: Double,
    previous: String?
  ) {
    (
      keyArray: readings,
      value: value,
      probability: probability,
      previous: previous
    )
  }

  public func isReadingValueLengthMatched(readings: [String]) -> Bool {
    readings.count == value.count
  }
}

extension SimpleTrie {
  public func search(_ key: String, partiallyMatch: Bool = false) -> [(
    readings: [String],
    entry: Entry
  )] {
    // 使用 keyChainIDMap 優化查詢效能，尤其對於精確比對的情況
    if !partiallyMatch {
      let nodeIDs = keyChainIDMap[key, default: []]
      if !nodeIDs.isEmpty {
        var results: [(readings: [String], entry: Entry)] = []
        for nodeID in nodeIDs {
          if let node = nodes[nodeID] {
            let readings = node.readingKey.sliced(by: readingSeparator).map(\.description)
            node.entries.forEach { entry in
              results.append((readings: readings, entry: entry))
            }
          }
        }
        return results
      }
    }

    var currentNode = root
    // 遍歷關鍵字的每個字元
    for char in key {
      let charStr = char.description
      // 查找對應字元的子節點
      guard let childNodeID = currentNode.children[charStr] else { return [] }
      guard let childNode = nodes[childNodeID] else { return [] }
      // 更新當前節點
      currentNode = childNode
    }

    return partiallyMatch ?
      collectAllDescendantEntriesWithReadings(from: currentNode) :
      collectEntriesWithReadings(from: currentNode)
  }

  private func collectEntriesWithReadings(from node: TNode) -> [(
    readings: [String],
    entry: Entry
  )] {
    let readings = node.readingKey.sliced(by: readingSeparator).map(\.description)
    return node.entries.map { (readings: readings, entry: $0) }
  }

  private func collectAllDescendantEntriesWithReadings(from node: TNode) -> [(
    readings: [String],
    entry: Entry
  )] {
    var result = collectEntriesWithReadings(from: node)
    // 遍歷所有子節點
    node.children.values.forEach { childNodeID in
      guard let childNode = nodes[childNodeID] else { return }
      result.append(contentsOf: collectAllDescendantEntriesWithReadings(from: childNode))
    }
    return result
  }
}

// MARK: - SimpleTrie + VanguardTrieProtocol

extension SimpleTrie {
  public func getNodeIDs(keys: [String], partiallyMatch: Bool) -> Set<Int> {
    switch partiallyMatch {
    case false:
      return keyChainIDMap[keys.joined(separator: readingSeparator.description)] ?? []
    case true:
      guard !keys.isEmpty else { return [] }

      // 使用 keyChainIDMap 來優化查詢
      var matchedNodeIDs = Set<Int>()

      // 從 keyChainIDMap 中查找所有鍵
      keyChainIDMap.forEach { keyChain, nodeIDs in
        // 只處理那些至少和首個查詢鍵相符的鍵鏈
        let keyComponents = keyChain.sliced(by: readingSeparator).map(\.description)

        // 檢查長度是否相符
        guard keyComponents.count == keys.count else { return }

        // 檢查每個元素是否以對應的前綴開頭
        guard zip(keys, keyComponents).allSatisfy({ $1.hasPrefix($0) }) else { return }

        // 檢查類型過濾條件
        matchedNodeIDs.formUnion(nodeIDs)
      }
      return matchedNodeIDs
    }
  }

  public func getNode(nodeID: Int) -> TNode? {
    nodes[nodeID]
  }

  public func getEntries(node: TNode) -> [Entry] {
    node.entries
  }

  public var chopCaseSeparator: Character { "&" }

  /// 特殊函式，專門用來處理那種單個讀音位置有兩個讀音的情況。
  ///
  /// 這只可能是前端打拼音串之後被 Tekkon.PinyinTrie 分析出了多個結果。
  /// 比如說敲了漢語拼音 s 的話會被分析成兩個結果「ㄕ」和「ㄙ」。
  /// 這會以「ㄕ\(chopCaseSeparator)ㄙ」的形式插入注拼引擎、然後再被傳到這個 Trie 內來查詢。
  public func getNodeIDs(
    keysChopped: [String],
    partiallyMatch: Bool
  )
    -> Set<Int> {
    // 單個讀音位置的多個可能性以 chopCaseSeparator 區隔。
    guard keysChopped.joined().contains(chopCaseSeparator) else {
      return getNodeIDs(
        keys: keysChopped,
        partiallyMatch: partiallyMatch
      )
    }

    var possibleReadings = [[String]]()

    // 遞歸函數生成所有組合可能性
    func generateCombinations(index: Int, current: [String]) {
      // 如果已經處理完所有切片，將當前組合加入結果
      if index >= keysChopped.count {
        possibleReadings.append(current)
        return
      }

      // 取得當前位置的所有候選項
      let candidates = keysChopped[index].split(separator: chopCaseSeparator)

      // 對每個候選項進行遞歸
      for candidate in candidates {
        var newCombination = current
        newCombination.append(candidate.description)
        generateCombinations(index: index + 1, current: newCombination)
      }
    }

    // 從索引0開始，使用空數組作為初始組合
    generateCombinations(index: 0, current: [])

    var result = Set<Int>()
    possibleReadings.forEach { keys in
      getNodeIDs(
        keys: keys,
        partiallyMatch: partiallyMatch
      ).forEach { nodeID in
        result.insert(nodeID)
      }
    }
    return result
  }

  public func partiallyMatchedKeys(
    _ keys: [String],
    nodeIDs: Set<Int>
  )
    -> Set<[String]> {
    guard !keys.isEmpty else { return [] }

    // 2. 準備收集結果與追蹤已處理節點，避免重複處理
    var result: Set<[String]> = []
    var processedNodes = Set<Int>()

    // 3. 對每個 NodeID 獲取對應節點、詞條和讀音
    for nodeID in nodeIDs {
      // 跳過已處理的節點
      guard !processedNodes.contains(nodeID),
            let node = getNode(nodeID: nodeID) else { continue }

      processedNodes.insert(nodeID)

      // 5. 提前獲取一次 entries 並重用
      let entries = getEntries(node: node)

      // 確保讀音數量比對
      let nodeReadings = node.readingKey.sliced(by: readingSeparator).map(\.description)
      guard nodeReadings.count == keys.count else { continue }
      // 確保每個讀音都以對應的前綴開頭
      let allPrefixMatched = zip(keys, nodeReadings).allSatisfy { $1.hasPrefix($0) }
      guard allPrefixMatched else { continue }

      // 6. 過濾出符合條件的詞條
      let firstMatchedEntry = entries.first

      guard firstMatchedEntry != nil else { continue }

      // 7. 收集讀音
      result.insert(nodeReadings)
    }

    return result
  }

  public func hasGrams(
    _ keys: [String],
    partiallyMatch: Bool = false,
    partiallyMatchedKeysHandler: ((Set<[String]>) -> ())? = nil
  )
    -> Bool {
    guard !keys.isEmpty else { return false }

    if !partiallyMatch {
      // 對於精確比對，直接用 getNodeIDs
      let nodeIDs = getNodeIDs(keysChopped: keys, partiallyMatch: false)
      return !nodeIDs.isEmpty
    } else {
      // 增加快速路徑：如果不需要處理比對結果，只需檢查是否有相符的節點
      if partiallyMatchedKeysHandler == nil {
        return !getNodeIDs(keysChopped: keys, partiallyMatch: true).isEmpty
      } else {
        let nodeIDs = getNodeIDs(keysChopped: keys, partiallyMatch: true)
        let partiallyMatchedResult = partiallyMatchedKeys(
          keys,
          nodeIDs: nodeIDs
        )
        partiallyMatchedKeysHandler?(partiallyMatchedResult)
        return !partiallyMatchedResult.isEmpty
      }
    }
  }

  public func queryGrams(
    _ keys: [String],
    partiallyMatch: Bool = false,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())? = nil
  )
    -> [(keyArray: [String], value: String, probability: Double, previous: String?)] {
    guard !keys.isEmpty else { return [] }

    if !partiallyMatch {
      // 精確比對 - 現在也使用緩存提高效能
      let nodeIDs = getNodeIDs(keysChopped: keys, partiallyMatch: false)
      var processedNodeEntries = [Int: [Entry]]()
      var results = [(keyArray: [String], value: String, probability: Double, previous: String?)]()

      for nodeID in nodeIDs {
        guard let node = getNode(nodeID: nodeID) else { continue }

        // 使用緩存避免重複查詢
        let entries: [Entry]
        if let cachedEntries = processedNodeEntries[nodeID] {
          entries = cachedEntries
        } else if let node = getNode(nodeID: nodeID) {
          entries = getEntries(node: node)
          processedNodeEntries[nodeID] = entries
        } else {
          continue
        }

        // 過濾符合類型的詞條
        var inserted = Set<Entry>()
        let filteredEntries = entries.filter { entry in
          inserted.insert(entry).inserted
        }

        results.append(contentsOf: filteredEntries.map { entry in
          entry.asTuple(
            with: node.readingKey.sliced(by: readingSeparator).map(\.description)
          )
        })
      }

      return results
    } else {
      // 1. 獲取所有節點IDs
      let nodeIDs = getNodeIDs(keysChopped: keys, partiallyMatch: true)
      guard !nodeIDs.isEmpty else { return [] }
      // 2. 獲取相符的讀音和節點，除非 handler 是 nil。
      defer {
        let partiallyMatchedResult = partiallyMatchedKeys(
          keys,
          nodeIDs: nodeIDs
        )
        if !partiallyMatchedResult.isEmpty {
          partiallyMatchedKeysPostHandler?(partiallyMatchedResult)
        }
      }

      // 使用緩存避免重複查詢
      var processedNodeEntries = [Int: [Entry]]()
      var results = [(keyArray: [String], value: String, probability: Double, previous: String?)]()

      // 3. 獲取每個節點的詞條
      for nodeID in nodeIDs {
        guard let node = getNode(nodeID: nodeID) else { continue }
        let nodeReadings = node.readingKey.sliced(by: readingSeparator).map(\.description)
        // 使用緩存避免重複查詢
        let entries: [Entry]
        if let cachedEntries = processedNodeEntries[nodeID] {
          entries = cachedEntries
        } else if let node = getNode(nodeID: nodeID) {
          entries = getEntries(node: node)
          processedNodeEntries[nodeID] = entries // 緩存結果
        } else {
          continue
        }
        guard nodeReadings.count == keys.count else { continue }
        guard zip(keys, nodeReadings).allSatisfy({
          let keyCases = $0.split(separator: chopCaseSeparator)
          for currentKeyCase in keyCases {
            if $1.hasPrefix(currentKeyCase) { return true }
          }
          return false
        }) else { continue }

        // 4. 過濾符合條件的詞條
        var inserted = Set<Entry>()
        let filteredEntries = entries.filter { entry in
          inserted.insert(entry).inserted
        }

        // 5. 將符合條件的詞條添加到結果中
        results.append(contentsOf: filteredEntries.map { entry in
          entry.asTuple(
            with: node.readingKey.sliced(by: readingSeparator).map(\.description)
          )
        })
      }

      return results
    }
  }
}
