// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation

extension Megrez.Compositor {
  public struct KeyValuePaired: Equatable, Hashable, Comparable, CustomStringConvertible {
    /// 鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    public var keyArray: [String]
    /// 資料值。
    public var value: String
    /// 將當前鍵值列印成一個字串。
    public var description: String { "(" + keyArray.description + "," + value + ")" }
    /// 判斷當前鍵值配對是否合規。如果鍵與值有任一為空，則結果為 false。
    public var isValid: Bool { !keyArray.joined().isEmpty && !value.isEmpty }
    /// 將當前鍵值列印成一個字串，但如果該鍵值配對為空的話則僅列印「()」。
    public var toNGramKey: String { !isValid ? "()" : "(" + joinedKey() + "," + value + ")" }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - key: 鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    public init(keyArray: [String], value: String = "N/A") {
      self.keyArray = keyArray.isEmpty ? ["N/A"] : keyArray
      self.value = value.isEmpty ? "N/A" : value
    }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - key: 鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    public init(key: String = "N/A", value: String = "N/A") {
      keyArray = key.isEmpty ? ["N/A"] : key.components(separatedBy: Megrez.Compositor.theSeparator)
      self.value = value.isEmpty ? "N/A" : value
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(value)
    }

    public func joinedKey(by separator: String = Megrez.Compositor.theSeparator) -> String {
      keyArray.joined(separator: separator)
    }

    public static func == (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      lhs.keyArray == rhs.keyArray && lhs.value == rhs.value
    }

    public static func < (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.joined().count < rhs.keyArray.joined().count)
        || (lhs.keyArray.joined().count == rhs.keyArray.joined().count && lhs.value < rhs.value)
    }

    public static func > (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.joined().count > rhs.keyArray.joined().count)
        || (lhs.keyArray.joined().count == rhs.keyArray.joined().count && lhs.value > rhs.value)
    }

    public static func <= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.joined().count <= rhs.keyArray.joined().count)
        || (lhs.keyArray.joined().count == rhs.keyArray.joined().count && lhs.value <= rhs.value)
    }

    public static func >= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.joined().count >= rhs.keyArray.joined().count)
        || (lhs.keyArray.joined().count == rhs.keyArray.joined().count && lhs.value >= rhs.value)
    }
  }

  public enum CandidateFetchFilter { case all, beginAt, endAt }

  /// 返回在當前位置的所有候選字詞（以詞音配對的形式）。如果組字器內有幅位、且游標
  /// 位於組字器的（文字輸入順序的）最前方（也就是游標位置的數值是最大合規數值）的
  /// 話，那麼這裡會用到 location - 1、以免去在呼叫該函式後再處理的麻煩。
  /// - Parameter location: 游標位置。
  /// - Returns: 候選字音配對陣列。
  public func fetchCandidates(at location: Int, filter: CandidateFetchFilter = .all) -> [KeyValuePaired] {
    var result = [KeyValuePaired]()
    guard !keys.isEmpty else { return result }
    let location = max(min(location, keys.count - 1), 0)  // 防呆
    let anchors: [NodeAnchor] = fetchOverlappingNodes(at: location).stableSorted {
      // 按照讀音的長度來給節點排序。
      $0.spanLength > $1.spanLength
    }
    let keyAtCursor = keys[location]
    for theNode in anchors.map(\.node) {
      if theNode.keyArray.joined(separator: separator).isEmpty { continue }
      for gram in theNode.unigrams {
        switch filter {
          case .all:
            // 得加上這道篩選，所以會出現很多無效結果。
            if !theNode.keyArray.contains(keyAtCursor) { continue }
          case .beginAt:
            if theNode.keyArray[0] != keyAtCursor { continue }
          case .endAt:
            if theNode.keyArray.reversed()[0] != keyAtCursor { continue }
        }
        result.append(.init(keyArray: theNode.keyArray, value: gram.value))
      }
    }
    return result
  }

  /// 使用給定的候選字（詞音配對），將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 該函式可以僅用作過程函式。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（詞音配對）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  /// - Returns: 該操作是否成功執行。
  @discardableResult public func overrideCandidate(
    _ candidate: KeyValuePaired, at location: Int, overrideType: Node.OverrideType = .withHighScore
  )
    -> Bool
  {
    overrideCandidateAgainst(keyArray: candidate.keyArray, at: location, value: candidate.value, type: overrideType)
  }

  /// 使用給定的候選字詞字串，將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 注意：如果有多個「單元圖資料值雷同、卻讀音不同」的節點的話，該函式的行為結果不可控。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（字串）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  /// - Returns: 該操作是否成功執行。
  @discardableResult public func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int, overrideType: Node.OverrideType = .withHighScore
  ) -> Bool {
    overrideCandidateAgainst(keyArray: nil, at: location, value: candidate, type: overrideType)
  }

  // MARK: Internal implementations.

  /// 使用給定的候選字（詞音配對）、或給定的候選字詞字串，將給定位置的節點的候選字詞改為與之一致的候選字詞。
  /// - Parameters:
  ///   - key: 索引鍵，也就是詞音配對當中的讀音。
  ///   - location: 游標位置。
  ///   - value: 資料值。
  ///   - type: 指定覆寫行為。
  /// - Returns: 該操作是否成功執行。
  internal func overrideCandidateAgainst(keyArray: [String]?, at location: Int, value: String, type: Node.OverrideType)
    -> Bool
  {
    let location = max(min(location, keys.count), 0)  // 防呆
    var arrOverlappedNodes: [NodeAnchor] = fetchOverlappingNodes(at: min(keys.count - 1, location))
    var overridden: NodeAnchor?
    for anchor in arrOverlappedNodes {
      if let keyArray = keyArray,
        anchor.node.keyArray.joined(separator: separator) != keyArray.joined(separator: separator)
      {
        continue
      }
      if anchor.node.selectOverrideUnigram(value: value, type: type) {
        overridden = anchor
        break
      }
    }

    guard let overridden = overridden else { return false }  // 啥也不覆寫。

    for i in overridden.spanIndex..<min(spans.count, overridden.spanIndex + overridden.node.spanLength) {
      /// 咱們還得弱化所有在相同的幅位座標的節點的複寫權重。舉例說之前爬軌的結果是「A BC」
      /// 且 A 與 BC 都是被覆寫的結果，然後使用者現在在與 A 相同的幅位座標位置
      /// 選了「DEF」，那麼 BC 的覆寫狀態就有必要重設（但 A 不用重設）。
      arrOverlappedNodes = fetchOverlappingNodes(at: i)
      for anchor in arrOverlappedNodes {
        if anchor.node == overridden.node { continue }
        if !overridden.node.keyArray.joined(separator: separator).contains(
          anchor.node.keyArray.joined(separator: separator)) || !overridden.node.value.contains(anchor.node.value)
        {
          anchor.node.reset()
          continue
        }
        anchor.node.overridingScore /= 4
      }
    }
    return true
  }
}

// MARK: - Stable Sort Extension

// Reference: https://stackoverflow.com/a/50545761/4162914

extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  fileprivate func stableSorted(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}
