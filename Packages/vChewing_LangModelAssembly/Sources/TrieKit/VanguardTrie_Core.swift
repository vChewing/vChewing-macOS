// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - VanguardTrie

public enum VanguardTrie {
  public final class Trie {
    // MARK: Lifecycle

    public init(separator: Character) {
      self.readingSeparator = separator
      self.root = .init(id: 0)
      self.nodes = [:]

      // 初期化時，將根節點加入到節點辭典中
      root.id = 0
      nodes[0] = root
      self.keyInitialsIDMap = [:]
    }

    // MARK: Public

    public final class TNode: Hashable, Identifiable {
      // MARK: Lifecycle

      public init(
        id: Int,
        entries: [Entry] = [],
        readingKey: String = ""
      ) {
        self.id = id
        self.entries = entries
        self.children = [:] // 重要：保證資料插入行為結果的準確性。
        self.readingKey = readingKey
      }

      // MARK: Public

      public internal(set) var id: Int = 0
      public internal(set) var entries: [Entry] = []
      public internal(set) var readingKey: String = ""
      public internal(set) var children: [String: Int] = [:] // 重要：保證資料插入行為結果的準確性。

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
        hasher.combine(readingKey)
        hasher.combine(children)
      }
    }

    public struct Entry: Hashable, Sendable {
      // MARK: Lifecycle

      public init(
        value: String,
        typeID: EntryType,
        probability: Double,
        previous: String?,
        anterior: String? = nil
      ) {
        self.value = value
        self.typeID = typeID
        self.probability = probability
        self.previous = previous
        self.anterior = anterior
      }

      // MARK: Public

      public let value: String
      public let typeID: EntryType
      public let probability: Double
      public let previous: String?
      public let anterior: String?
    }

    public struct EntryType: OptionSet, Sendable, Codable, Hashable {
      // MARK: Lifecycle

      public init(rawValue: Int32) {
        self.rawValue = rawValue
      }

      // MARK: Public

      public static let langNeutral = Self(rawValue: 1 << 0)

      public let rawValue: Int32 // TextMap 辭典格式與各查詢介面皆以 Int32 承載型別 ID。
    }

    public let readingSeparator: Character
    public let root: TNode
    public internal(set) var nodes: [Int: TNode] // 新增：節點辭典，以id為索引
    public internal(set) var keyInitialsIDMap: [String: Set<Int>]
  }

  /// 護摩（Homa）元圖資料的承載結構，用以取代先前的 5-元 tuple。
  ///
  /// 改用具名結構的理由：5-元 tuple 會觸發 `large_tuple` lint，且具名欄位較易讀。
  /// 記憶體佈局與原 tuple 完全相同（size／stride 皆 64 bytes、align 8），故無效能代價。
  ///
  /// - Note: 舊工具鏈（legacy 倉的 Xcode 15／`SWIFT_VERSION 5.0`）無法在時限內完成
  ///   type-check 的對象是 **5 元 tuple 的 `>` 比較運算式**，與 tuple 型別本身無關——
  ///   tuple 型別在該工具鏈下照常編譯。該比較已改寫為等價的逐欄條件分支
  ///   （見 `queryAssociatedPhrasesAsGrams`）。
  public struct TrieGram: Hashable, Sendable {
    // MARK: Lifecycle

    public init(
      keyArray: [String],
      value: String,
      probability: Double,
      previous: String?,
      anterior: String?
    ) {
      self.keyArray = keyArray
      self.value = value
      self.probability = probability
      self.previous = previous
      self.anterior = anterior
    }

    // MARK: Public

    public let keyArray: [String]
    public let value: String
    public let probability: Double
    public let previous: String?
    public let anterior: String?
  }
}

// MARK: - Extending Methods (Trie: Insert and Search API).

extension VanguardTrie.Trie {
  public func insert(entry: Entry, readings: [String]) {
    var currentNode = root
    var currentNodeID = 0

    let key = readings.joined(separator: readingSeparator.description)
    let keyCells = readings.compactMap {
      $0.first?.description
    }
    let keyInitialsStr = keyCells.joined()

    // 遍歷關鍵字的每個字元
    readings.forEach { nodeUnitStr in
      if let childNodeID = currentNode.children[nodeUnitStr],
         let matchedNode = nodes[childNodeID] {
        // 有效的子節點已存在，繼續遍歷
        currentNodeID = childNodeID
        currentNode = matchedNode
        return
      }
      // 創建新的子節點
      let newNodeID = nodes.count
      // ReadingKey 必須是完整的讀音鍵。
      let newNode = TNode(id: newNodeID, readingKey: key)

      // 更新關係
      currentNode.children[nodeUnitStr] = newNodeID
      nodes[newNodeID] = newNode

      // 更新當前節點
      currentNode = newNode
      currentNodeID = newNodeID
    }

    // 在最終節點添加詞條
    currentNode.readingKey = key // 必須保留。
    currentNode.entries.append(entry)
    keyInitialsIDMap[keyInitialsStr, default: []].insert(currentNodeID)
  }

  public func clearAllContents() {
    root.children.removeAll()
    root.entries.removeAll()
    root.id = 0
    nodes.removeAll()
    nodes[0] = root
    updateKeyInitialsIDMap()
  }

  internal func updateKeyInitialsIDMap() {
    // 清空現有映射以確保資料一致性
    keyInitialsIDMap.removeAll()

    // 遍歷所有節點和條目來重建映射
    nodes.forEach { nodeID, node in
      node.entries.forEach { _ in
        let keyInitialsStr = node.readingKey.split(separator: readingSeparator).compactMap {
          $0.first?.description
        }.joined()
        keyInitialsIDMap[keyInitialsStr, default: []].insert(nodeID)
      }
    }
  }
}
