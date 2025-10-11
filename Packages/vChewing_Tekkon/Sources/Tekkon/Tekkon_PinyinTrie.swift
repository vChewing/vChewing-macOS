// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Tekkon.PinyinTrie

extension Tekkon {
  /// 用來處理拼音轉注音的字首樹實作。
  public final class PinyinTrie {
    // MARK: Lifecycle

    public init(parser: MandarinParser) {
      self.root = .init()
      self.nodes = [:]

      // 初始化時，將根節點加入到節點辭典中
      root.id = 0
      root.character = ""
      nodes[0] = root

      self.parser = parser
      self.allPossibleReadings = parser.allPossibleReadings.sorted {
        ($0.count, $1) > ($1.count, $0)
      }
      // Key 是注音，Value 是拼音，所以要反過來建樹。
      if let table = parser.mapZhuyinPinyin {
        for (pinyin, zhuyin) in table {
          insert(pinyin, entry: zhuyin)
        }
      }
    }

    // MARK: Public

    public final class TNode: Hashable, Identifiable {
      // MARK: Lifecycle

      public init(
        id: Int? = nil,
        entries: [String] = [],
        character: String = "",
        readingKey: String = ""
      ) {
        self.id = id
        self.entries = entries
        self.character = character
        self.children = [:]
        self.readingKey = readingKey
      }

      // MARK: Public

      public internal(set) var id: Int?
      public internal(set) var entries: [String] = []
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
        hasher.combine(character)
        hasher.combine(readingKey)
        hasher.combine(children)
      }
    }

    public let parser: MandarinParser
    public let root: TNode
    public var nodes: [Int: TNode] // 新增：節點辭典，以id為索引
    public internal(set) var allPossibleReadings: [String]

    // MARK: Private

    private enum CodingKeys: CodingKey {
      case nodes
    }
  }
}

extension Tekkon.PinyinTrie {
  func insert(_ key: String, entry: String) {
    var currentNode = root

    // 遍歷關鍵字的每個字元
    for char in key {
      let charStr = char.description
      if let childNodeID = currentNode.children[charStr],
         let matchedNode = nodes[childNodeID] {
        // 有效的子節點已存在，繼續遍歷
        currentNode = matchedNode
        continue
      }

      // 創建新的子節點
      let newNodeID = nodes.count
      let newNode = TNode(id: newNodeID, character: charStr)

      // 更新父節點與節點辭典
      currentNode.children[charStr] = newNodeID
      if let currentID = currentNode.id { nodes[currentID] = currentNode }
      nodes[newNodeID] = newNode

      // 更新當前節點
      currentNode = newNode
    }

    // 在最終節點添加詞條
    currentNode.readingKey = key
    currentNode.entries.append(entry)
    if let currentID = currentNode.id { nodes[currentID] = currentNode }
  }

  func search(_ key: String) -> [String] {
    var currentNode = root
    for char in key {
      let charStr = char.description
      guard let childNodeID = currentNode.children[charStr] else { return [] }
      guard let childNode = nodes[childNodeID] else { return [] }
      currentNode = childNode
    }

    return collectAllDescendantEntries(from: currentNode)
  }

  private func collectAllDescendantEntries(from node: TNode) -> [String] {
    var result = node.entries
    // 遍歷所有子節點
    node.children.values.forEach { childNodeID in
      guard let childNode = nodes[childNodeID] else { return }
      result.append(contentsOf: collectAllDescendantEntries(from: childNode))
    }
    return result
  }
}

extension Tekkon.PinyinTrie {
  /// 拿已經 chop 段切過的拼音來算出可能的注音 chop 結果。單個拼音 chop 可能會對應多個注音。
  ///
  /// 例：當前 parser 是漢語拼音的話，當給定參數如下時：
  /// ```swift
  /// `chopped: ["b", "yue", "z", "q", "s", "l", "l"]
  /// ```
  ///
  /// 期許結果是：
  ///
  /// ```swift
  /// ["ㄅ", "ㄩㄝ", "ㄓ&ㄗ", "ㄑ", "ㄕ&ㄙ", "ㄌ", "ㄌ"]
  /// ```
  public func deductChoppedPinyinToZhuyin(
    _ chopped: [String],
    chopCaseSeparator: Character = "&",
    initialZhuyinOnly: Bool = true
  )
    -> [String] {
    guard parser.isPinyin else { return chopped }

    // 為每個拼音切片找出所有可能的注音
    var choppedZhuyinCandidates: [String] = []

    for slice in chopped {
      let fetched = search(slice)

      // 對於其他情況，保持原有行為
      switch fetched.count {
      case 1:
        choppedZhuyinCandidates.append(fetched.joined(separator: chopCaseSeparator.description))
      case 2...:
        var uniqueFetched: [String] = Array(Set(fetched)).sorted()
        trimProcess: if initialZhuyinOnly {
          for i in (1 ... 3).reversed() {
            guard uniqueFetched.count > i else { break trimProcess }
            uniqueFetched = Set(fetched.map { $0.prefix(i).description }).sorted()
          }
        }
        choppedZhuyinCandidates
          .append(uniqueFetched.joined(separator: chopCaseSeparator.description))
      default:
        choppedZhuyinCandidates.append(slice)
      }
    }

    return choppedZhuyinCandidates
  }

  /// 用來像智能狂拼/搜狗拼音那樣處理一個連續的簡拼字串、切割成多個可能的合理讀音前綴。
  ///
  /// - 比如說全拼「shi4jie4da4zhan4」可能會簡拼成「shjdaz」。
  ///   此時的理想切片結果是：`["sh","j","da","z"]`。
  /// - 注音的話，「ㄕˋ ㄐㄧㄝˋ ㄉㄚˋ ㄓㄢˋ」可能會被簡拼成「ㄕㄐㄧㄉㄓ」。
  ///   此時的理想切片結果是：`["ㄕ","ㄐㄧ","ㄉ","ㄓ"]`。
  public func chop(_ readingComplex: String) -> [String] {
    let givenCharComplex: [Character] = readingComplex.map { $0.self }
    let complexLength = givenCharComplex.count
    var result = [String]()

    // 此處無須呼叫 updateAllPossibleReadings()，因為一定是被事先呼叫過的。
    // 每次 ensureParser() 的時候都會呼叫一次。

    let longestReadingLength = allPossibleReadings.first?.count ?? 1
    let maxScopeSize = min(complexLength, longestReadingLength)
    var currentPosition = 0

    while currentPosition < complexLength {
      var foundMatch = false

      // 嘗試從最長的可能前綴開始比對
      let longPossibleScopeSize = min(maxScopeSize, complexLength - currentPosition)
      checkPosition: for scopeSize in (1 ... longPossibleScopeSize).reversed() {
        let endPosition = currentPosition + scopeSize
        if endPosition > complexLength {
          continue
        }

        let currentBlob = String(givenCharComplex[currentPosition ..< endPosition])

        // 檢查是否有任何讀音以這個字串開頭
        for currentReading in allPossibleReadings {
          if currentReading.hasPrefix(currentBlob) {
            result.append(currentBlob)
            currentPosition = endPosition
            foundMatch = true
            break checkPosition
          }
        }
      }

      // 如果沒找到相符的條目，將當前字元作為單獨的一項
      if !foundMatch {
        result.append(String(givenCharComplex[currentPosition]))
        currentPosition += 1
      }
    }

    return result
  }
}
