// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - VanguardTrieProtocol

public protocol VanguardTrieProtocol {
  typealias TNode = VanguardTrie.Trie.TNode
  typealias Entry = VanguardTrie.Trie.Entry
  typealias EntryType = VanguardTrie.Trie.EntryType

  var readingSeparator: Character { get }

  func getNodeIDsForKeyArray(
    _ keyArray: [String],
    longerSegment: Bool
  ) -> [Int]

  func getNode(_ nodeID: Int) -> TNode?

  func getNodes(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  ) -> [TNode]

  func getEntryGroups(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  ) -> [(keyArray: [String], entries: [Entry])]
}

extension VanguardTrieProtocol {
  public var chopCaseSeparator: Character { "&" }

  /// 特殊函式，專門用來處理那種單個讀音位置有兩個讀音的情況。
  ///
  /// 這只可能是前端打拼音串之後被 Tekkon.PinyinTrie 分析出了多個結果。
  /// 比如說敲了漢語拼音 s 的話會被分析成兩個結果「ㄕ」和「ㄙ」。
  /// 這會以「ㄕ\(chopCaseSeparator)ㄙ」的形式插入注拼引擎、然後再被傳到這個 Trie 內來查詢。
  private func getNodes(
    keysChopped: [String],
    filterType: EntryType,
    partiallyMatch: Bool
  )
    -> [TNode] {
    // 單個讀音位置的多個可能性以 chopCaseSeparator 區隔。
    guard keysChopped.joined().contains(chopCaseSeparator) else {
      let result = getNodes(
        keyArray: keysChopped,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
      return result
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

    var result = [TNode]()
    var handledNodeIDs = Set<Int>()
    possibleReadings.forEach { keyArray in
      let nodesFetched = getNodes(
        keyArray: keyArray,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
      nodesFetched.forEach { currentNode in
        let currentNodeID = currentNode.id
        guard !handledNodeIDs.contains(currentNodeID) else { return }
        handledNodeIDs.insert(currentNodeID)
        result.append(currentNode)
      }
    }
    return result
  }

  private func getEntryGroups(
    keysChopped: [String],
    filterType: EntryType,
    partiallyMatch: Bool
  )
    -> [(keyArray: [String], entries: [Entry])] {
    guard keysChopped.joined().contains(chopCaseSeparator) else {
      return getEntryGroups(
        keyArray: keysChopped,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
    }

    var possibleReadings = [[String]]()

    func generateCombinations(index: Int, current: [String]) {
      if index >= keysChopped.count {
        possibleReadings.append(current)
        return
      }

      let candidates = keysChopped[index].split(separator: chopCaseSeparator)
      for candidate in candidates {
        var newCombination = current
        newCombination.append(candidate.description)
        generateCombinations(index: index + 1, current: newCombination)
      }
    }

    generateCombinations(index: 0, current: [])

    var result = [(keyArray: [String], entries: [Entry])]()
    var handledKeyArrays = Set<[String]>()
    possibleReadings.forEach { keyArray in
      let groupsFetched = getEntryGroups(
        keyArray: keyArray,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
      groupsFetched.forEach { currentGroup in
        let currentKeyArray = currentGroup.keyArray
        guard handledKeyArrays.insert(currentKeyArray).inserted else { return }
        result.append(currentGroup)
      }
    }
    return result
  }

  internal func nodeMeetsFilter(_ theNode: TNode, filter: EntryType) -> Bool {
    filter.isEmpty || theNode.entries.contains(where: { filter.contains($0.typeID) })
  }

  internal func lazyMatch(keyArray: [String], matchAgainst targetKeyChain: String) -> Bool {
    zip(keyArray, targetKeyChain.split(separator: readingSeparator)).allSatisfy(verifyCell)
  }

  private func verifyCell(
    _ initialsChain: String,
    _ target: String.SubSequence
  )
    -> Bool {
    let initials = initialsChain.split(separator: chopCaseSeparator)
    for initial in initials {
      if target.unicodeScalars.first != initial.unicodeScalars.first { continue }
      let allMet = zip(target.unicodeScalars, initial.unicodeScalars).allSatisfy(==)
      if allMet {
        return Swift.min(target.count, initials.count) > 0
      }
    }
    return false
  }
}

extension VanguardTrieProtocol {
  public func getEntryGroups(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  )
    -> [(keyArray: [String], entries: [Entry])] {
    let fetchedNodes = getNodes(
      keyArray: keyArray,
      filterType: filterType,
      partiallyMatch: partiallyMatch,
      longerSegment: longerSegment
    )
    return fetchedNodes.compactMap { currentNode in
      let filteredEntries = switch filterType.isEmpty {
      case true: currentNode.entries
      case false: currentNode.entries.filter { filterType.contains($0.typeID) }
      }
      guard !filteredEntries.isEmpty else { return nil }
      let keyArrayActual = TrieStringOperationCache.shared.getCachedSplit(
        currentNode.readingKey,
        separator: readingSeparator
      )
      return (keyArrayActual, filteredEntries)
    }
  }

  public func hasGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool = false,
    partiallyMatchedKeysHandler: ((Set<[String]>) -> ())? = nil
  )
    -> Bool {
    guard !keys.isEmpty, keys.allSatisfy({ !$0.isEmpty }) else { return false }
    return if !partiallyMatch {
      !getEntryGroups(
        keyArray: keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      ).isEmpty
    } else {
      !getEntryGroups(
        keysChopped: keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch
      ).isEmpty
    }
  }

  public func queryGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool = false,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())? = nil
  )
    -> [(keyArray: [String], value: String, probability: Double, previous: String?)] {
    guard !keys.isEmpty, keys.allSatisfy({ !$0.isEmpty }) else { return [] }
    let fetchedGroups = if !partiallyMatch {
      getEntryGroups(
        keyArray: keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        longerSegment: false
      )
    } else {
      getEntryGroups(
        keysChopped: keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch
      )
    }
    var results = [(keyArray: [String], value: String, probability: Double, previous: String?)]()
    fetchedGroups.forEach { currentGroup in
      currentGroup.entries.forEach { currentEntry in
        results.append(
          (
            currentGroup.keyArray,
            currentEntry.value,
            currentEntry.probability,
            currentEntry.previous
          )
        )
      }
    }
    return results
  }
}

extension VanguardTrieProtocol {
  /// 關聯詞語檢索，返回 Gram Raw 結果，不去除重複結果。
  ///
  /// 此處不以 anterior 作為參數，以免影響到之後的組句結果。
  ///
  /// - Remark: 如果想只獲取沒有 anterior 的結果的話，請將 anterior 設定為空字串。
  public func queryAssociatedPhrasesAsGrams(
    _ previous: (keyArray: [String], value: String),
    anterior anteriorValue: String? = nil,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [(keyArray: [String], value: String, probability: Double, previous: String?)]? {
    let keys = previous.keyArray
    guard !keys.isEmpty, keys.allSatisfy({ !$0.isEmpty }) else { return nil }
    guard !previous.value.isEmpty else { return nil }
    let prevSegLength = previous.keyArray.count
    // 此時獲取的結果已經有了完全相符的讀音前綴（包括前綴的幅長）。
    let groups = getEntryGroups(
      keyArray: previous.keyArray,
      filterType: filterType,
      partiallyMatch: false,
      longerSegment: true
    )
    guard !groups.isEmpty else { return nil }
    var resultsMap = [
      Int: (keyArray: [String], value: String, probability: Double, previous: String?, seq: Int)
    ]()
    groups.forEach { currentGroup in
      currentGroup.entries.forEach { entry in
        // 故意略過那些 Entry Value 的長度不等於幅長的資料值。
        guard entry.value.count == currentGroup.keyArray.count else { return }
        // Value 的前綴也得與 previous.value 一致。
        guard entry.value.prefix(prevSegLength) == previous.value else { return }
        if let anteriorValue {
          if !anteriorValue.isEmpty {
            guard entry.previous == anteriorValue else { return }
          } else {
            guard entry.previous == nil else { return }
          }
        }
        let newResult = (
          keyArray: currentGroup.keyArray,
          value: entry.value,
          probability: entry.probability,
          previous: entry.previous,
          seq: resultsMap.count
        )
        let theHash: Int = {
          var hasher = Hasher()
          hasher.combine(newResult.keyArray)
          hasher.combine(newResult.value)
          hasher.combine(newResult.previous)
          return hasher.finalize()
        }()
        if let existingValue = resultsMap[theHash] {
          if existingValue.probability < newResult.probability {
            resultsMap[theHash] = newResult
          }
        } else {
          resultsMap[theHash] = newResult
        }
      }
    }
    guard !resultsMap.isEmpty else { return nil }
    var final = [(keyArray: [String], value: String, probability: Double, previous: String?)]()
    final = resultsMap.values.sorted {
      ($0.keyArray.count, $0.probability, $1.seq, $0.previous?.count ?? 0) > (
        $1.keyArray.count, $1.probability, $0.seq, $1.previous?.count ?? 0
      )
    }.map {
      (
        keyArray: $0.keyArray,
        value: $0.value,
        probability: $0.probability,
        previous: $0.previous
      )
    }
    guard !final.isEmpty else { return nil }
    return final
  }

  /// 關聯詞語檢索：僅用於ㄅ半輸入模式，有做過進階去重複處理。
  public func queryAssociatedPhrasesPlain(
    _ previous: (keyArray: [String], value: String),
    anterior anteriorValue: String? = nil,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [(keyArray: [String], value: String)]? {
    let rawResults = queryAssociatedPhrasesAsGrams(
      previous,
      anterior: anteriorValue,
      filterType: filterType
    )
    guard let rawResults else { return nil }
    let prevSegLength = previous.keyArray.count
    var results = [(keyArray: [String], value: String)]()
    var inserted = Set<Int>()
    rawResults.forEach { entry in
      let newKeyArray = Array(entry.keyArray[prevSegLength...])
      let newValue = entry.value.map(\.description)[prevSegLength...].joined()
      let newResult = (newKeyArray, newValue)
      let theHash = "\(newResult)".hashValue // 此處只能用基於 String 的 Hash。原因不明。
      guard !inserted.contains(theHash) else { return }
      inserted.insert("\(newResult)".hashValue)
      results.append(newResult)
    }
    guard !results.isEmpty else { return nil }
    return results
  }
}
