// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Extending Methods (Entry).

extension VanguardTrie.Trie.Entry {
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

// MARK: - VanguardTrie.Trie + VanguardTrieProtocol

extension VanguardTrie.Trie: VanguardTrieProtocol {
  /// 根據 keychain 字串查詢節點 ID
  public func getNodeIDsForKeyArray(_ keyArray: [String], longerSegment: Bool) -> [Int] {
    guard !keyArray.isEmpty, keyArray.allSatisfy({ !$0.isEmpty }) else { return [] }
    let keyInitialsStr = keyArray.compactMap { keyStr in
      TrieStringPool.shared.internKey(TrieStringOperationCache.shared.getCachedFirstChar(keyStr))
    }.joined()
    var matchedNodeIDs: Set<Int> = []
    if longerSegment {
      keyInitialsIDMap.forEach { thisKey, value in
        if thisKey.hasPrefix(keyInitialsStr) {
          matchedNodeIDs.formUnion(value)
        }
      }
    } else {
      matchedNodeIDs = keyInitialsIDMap[keyInitialsStr] ?? []
    }
    return matchedNodeIDs.sorted()
  }

  public func getNode(_ nodeID: Int) -> TNode? {
    guard let node = nodes[nodeID] else { return nil }
    return node.entries.isEmpty ? nil : node
  }

  public func getNodes(
    keyArray: [String],
    filterType: EntryType,
    partiallyMatch: Bool,
    longerSegment: Bool
  )
    -> [TNode] {
    let matchedNodeIDs: [Int] = getNodeIDsForKeyArray(
      keyArray,
      longerSegment: longerSegment
    )
    guard !matchedNodeIDs.isEmpty else { return [] }
    var handledNodeIDs: Set<Int> = []
    let matchedNodes: [TNode] = matchedNodeIDs.compactMap {
      if let theNode = getNode($0) {
        let nodeID = theNode.id
        if !handledNodeIDs.contains(nodeID) {
          handledNodeIDs.insert(nodeID)
          let nodeKeyArray = TrieStringOperationCache.shared.getCachedSplit(
            theNode.readingKey,
            separator: readingSeparator
          )
          if nodeMeetsFilter(theNode, filter: filterType) {
            var matched: Bool = longerSegment
              ? nodeKeyArray.count > keyArray.count
              : nodeKeyArray.count == keyArray.count
            switch partiallyMatch {
            case true:
              matched = matched && zip(nodeKeyArray, keyArray).allSatisfy { $0.hasPrefix($1) }
            case false:
              matched = matched && zip(nodeKeyArray, keyArray).allSatisfy(==)
            }
            return matched ? theNode : nil
          }
        }
      }
      return nil
    }
    let result = matchedNodes
    return result
  }
}
