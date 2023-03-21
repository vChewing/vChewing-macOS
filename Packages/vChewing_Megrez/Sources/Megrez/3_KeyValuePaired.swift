// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation

public extension Megrez {
  /// 鍵值配對，乃索引鍵陣列與讀音的配對單元。
  struct KeyValuePaired: Equatable, Hashable, Comparable, CustomStringConvertible {
    /// 索引鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    public var keyArray: [String]
    /// 資料值。
    public var value: String
    /// 將當前鍵值列印成一個字串。
    public var description: String { "(" + keyArray.description + "," + value + ")" }
    /// 判斷當前鍵值配對是否合規。如果鍵與值有任一為空，則結果為 false。
    public var isValid: Bool { !keyArray.joined().isEmpty && !value.isEmpty }
    /// 將當前鍵值列印成一個字串，但如果該鍵值配對為空的話則僅列印「()」。
    public var toNGramKey: String { !isValid ? "()" : "(" + joinedKey() + "," + value + ")" }
    /// 通用陣列表達形式。
    public var tupletExpression: (keyArray: [String], value: String) { (keyArray, value) }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    public init(keyArray: [String], value: String = "N/A") {
      self.keyArray = keyArray.isEmpty ? ["N/A"] : keyArray
      self.value = value.isEmpty ? "N/A" : value
    }

    /// 初期化一組鍵值配對。
    /// - Parameter tupletExpression: 傳入的通用陣列表達形式。
    public init(_ tupletExpression: (keyArray: [String], value: String)) {
      keyArray = tupletExpression.keyArray.isEmpty ? ["N/A"] : tupletExpression.keyArray
      value = tupletExpression.value.isEmpty ? "N/A" : tupletExpression.value
    }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - key: 索引鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    public init(key: String = "N/A", value: String = "N/A") {
      keyArray = key.isEmpty ? ["N/A"] : key.components(separatedBy: Megrez.Compositor.theSeparator)
      self.value = value.isEmpty ? "N/A" : value
    }

    /// 做為預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
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
      (lhs.keyArray.count < rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value < rhs.value)
    }

    public static func > (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.count > rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value > rhs.value)
    }

    public static func <= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.count <= rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value <= rhs.value)
    }

    public static func >= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.keyArray.count >= rhs.keyArray.count)
        || (lhs.keyArray.count == rhs.keyArray.count && lhs.value >= rhs.value)
    }
  }
}

public extension Megrez.Compositor {
  /// 規定候選字陣列內容的獲取範圍類型：
  /// - all: 不只包含其它兩類結果，還允許游標穿插候選字。
  /// - beginAt: 僅獲取從當前游標位置開始的節點內的候選字。
  /// - endAt 僅獲取在當前游標位置結束的節點內的候選字。
  enum CandidateFetchFilter { case all, beginAt, endAt }

  /// 返回在當前位置的所有候選字詞（以詞音配對的形式）。如果組字器內有幅位、且游標
  /// 位於組字器的（文字輸入順序的）最前方（也就是游標位置的數值是最大合規數值）的
  /// 話，那麼這裡會對 location 的位置自動減去 1、以免去在呼叫該函式後再處理的麻煩。
  /// - Parameter location: 游標位置，必須是顯示的游標位置、不得做任何事先糾偏處理。
  /// - Returns: 候選字音配對陣列。
  func fetchCandidates(
    at givenLocation: Int? = nil, filter givenFilter: CandidateFetchFilter = .all
  ) -> [Megrez.KeyValuePaired] {
    var result = [Megrez.KeyValuePaired]()
    guard !keys.isEmpty else { return result }
    var location = max(min(givenLocation ?? cursor, keys.count), 0)
    var filter = givenFilter
    if filter == .endAt {
      if location == keys.count { filter = .all }
      location -= 1
    }
    location = max(min(location, keys.count - 1), 0)
    let anchors: [(location: Int, node: Megrez.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    anchors.forEach { theAnchor in
      let theNode = theAnchor.node
      theNode.unigrams.forEach { gram in
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          if !theNode.keyArray.contains(keyAtCursor) { return }
        case .beginAt:
          guard theAnchor.location == location else { return }
        case .endAt:
          guard theNode.keyArray.last == keyAtCursor else { return }
          switch theNode.spanLength {
          case 2... where theAnchor.location + theAnchor.node.spanLength - 1 != location: return
          default: break
          }
        }
        result.append(.init(keyArray: theNode.keyArray, value: gram.value))
      }
    }
    return result
  }

  /// 使用給定的候選字（詞音配對），將給定位置的節點的候選字詞改為與之一致的候選字詞。
  ///
  /// 該函式僅用作過程函式。
  /// - Parameters:
  ///   - candidate: 指定用來覆寫為的候選字（詞音鍵值配對）。
  ///   - location: 游標位置。
  ///   - overrideType: 指定覆寫行為。
  /// - Returns: 該操作是否成功執行。
  @discardableResult func overrideCandidate(
    _ candidate: Megrez.KeyValuePaired, at location: Int, overrideType: Megrez.Node.OverrideType = .withHighScore
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
  @discardableResult func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int, overrideType: Megrez.Node.OverrideType = .withHighScore
  ) -> Bool {
    overrideCandidateAgainst(keyArray: nil, at: location, value: candidate, type: overrideType)
  }

  // MARK: Internal implementations.

  /// 使用給定的候選字（詞音配對）、或給定的候選字詞字串，將給定位置的節點的候選字詞改為與之一致的候選字詞。
  /// - Parameters:
  ///   - keyArray: 索引鍵陣列，也就是詞音配對當中的讀音。
  ///   - location: 游標位置。
  ///   - value: 資料值。
  ///   - type: 指定覆寫行為。
  /// - Returns: 該操作是否成功執行。
  internal func overrideCandidateAgainst(keyArray: [String]?, at location: Int, value: String, type: Megrez.Node.OverrideType)
    -> Bool
  {
    let location = max(min(location, keys.count), 0) // 防呆
    var arrOverlappedNodes: [(location: Int, node: Megrez.Node)] = fetchOverlappingNodes(at: min(keys.count - 1, location))
    var overridden: (location: Int, node: Megrez.Node)?
    for anchor in arrOverlappedNodes {
      if keyArray != nil, anchor.node.keyArray != keyArray { continue }
      if !anchor.node.selectOverrideUnigram(value: value, type: type) { continue }
      overridden = anchor
      break
    }

    guard let overridden = overridden else { return false } // 啥也不覆寫。

    (overridden.location ..< min(spans.count, overridden.location + overridden.node.spanLength)).forEach { i in
      /// 咱們還得弱化所有在相同的幅位座標的節點的複寫權重。舉例說之前爬軌的結果是「A BC」
      /// 且 A 與 BC 都是被覆寫的結果，然後使用者現在在與 A 相同的幅位座標位置
      /// 選了「DEF」，那麼 BC 的覆寫狀態就有必要重設（但 A 不用重設）。
      arrOverlappedNodes = fetchOverlappingNodes(at: i)
      arrOverlappedNodes.forEach { anchor in
        if anchor.node == overridden.node { return }
        if !overridden.node.joinedKey(by: "\t").contains(anchor.node.joinedKey(by: "\t"))
          || !overridden.node.value.contains(anchor.node.value)
        {
          anchor.node.reset()
          return
        }
        anchor.node.overridingScore /= 4
      }
    }
    return true
  }
}
