// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.Node.OverrideType

extension Homa.Node {
  /// 對節點執行的三種不同覆寫操作模式。
  /// - withTopGramScore: 專用於雙元圖的自動選取功能，但效力低於 withSpecified 模式。
  /// 該覆寫行為無法防止其它節點被組句函式所支配。這種情況下就需要用到 overridingScore。
  /// - withSpecified: 強制覆寫節點權重為 overridingScore，
  /// 確保組句函式優先選擇該節點且不受其他節點影響。
  /// 但是這個選項也可以允許搭配過低的 overridingScore 來起到 demote 的效果。
  public enum OverrideType: Int, Codable {
    case withTopGramScore = 1
    case withSpecified = 2
  }
}

// MARK: - Homa.Node

extension Homa {
  public final class Node: Codable {
    // MARK: Lifecycle

    /// 生成一個字詞節點。
    ///
    /// 一個節點由這些內容組成：幅節長度、索引鍵、以及一組元圖。幅節長度就是指這個
    /// 節點在組字器內橫跨了多少個字長。組字器負責構築自身的節點。對於由多個漢字組成
    /// 的詞，組字器會將多個讀音索引鍵合併為一個讀音索引鍵、據此向語言模組請求對應的
    /// 元圖結果陣列。舉例說，如果一個詞有兩個漢字組成的話，那麼讀音也是有兩個、其
    /// 索引鍵也是由兩個讀音組成的，那麼這個節點的幅節長度就是 2。
    ///
    /// - Remark: 除非有必要，否則請盡量不要在 Assembler 外部直接與 Node 互動。
    /// GramInPath 是您理想的可互動物件。
    /// - Parameters:
    ///   - keyArray: 給定索引鍵陣列，不得為空。
    ///   - segLength: 給定幅節長度，一般情況下與給定索引鍵陣列內的索引鍵數量一致。
    ///   - grams: 給定元圖陣列，不得為空。
    internal init(keyArray: [String] = [], grams: [Homa.Gram] = []) {
      self.id = FIUUID()
      self.keyArray4Query = keyArray
      self.grams = grams
      self.allActualKeyArraysCached = Set(grams.map(\.keyArray))
      self.bigramMap = grams.allBigramsMap
      self.currentOverrideType = nil
    }

    /// 以指定字詞節點生成拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Assembler 被拷貝的時候無法被真實複製。
    /// 這樣一來，Assembler 複製品當中的 Node 的變化會被反應到原先的 Assembler 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    internal init(node: Node) {
      self.id = FIUUID()
      self.overridingScore = node.overridingScore
      self.keyArray4Query = node.keyArray4Query
      self.allActualKeyArraysCached = node.allActualKeyArraysCached
      self.grams = node.grams
      self.bigramMap = node.bigramMap
      self.currentOverrideType = node.currentOverrideType
      self.isExplicitlyOverridden = node.isExplicitlyOverridden
      self.currentGramIndex = node.currentGramIndex
    }

    // MARK: Public

    /// 節點的唯一識別符。
    public let id: FIUUID

    /// 一個用以覆寫權重的數值。該數值之高足以改變組句函式對該節點的讀取結果。這裡用
    /// 「0」可能看似足夠了，但仍會使得該節點的覆寫狀態有被組句函式忽視的可能。比方說
    /// 要針對索引鍵「a b c」複寫的資料值為「A B C」，使用大寫資料值來覆寫節點。這時，
    /// 如果這個獨立的 c 有一個可以拮抗權重的詞「bc」的話，可能就會導致組句函式的算法
    /// 找出「A->bc」的組句途徑（尤其是當 A 和 B 使用「0」作為複寫數值的情況下）。這樣
    /// 一來，「A-B」就不一定始終會是組句函式的青睞結果了。所以，這裡一定要用大於 0 的
    /// 數（比如野獸常數），以讓「c」更容易單獨被選中。
    public internal(set) var overridingScore: Double = 114_514

    /// 事先假設的索引鍵陣列，可能不完全。
    public private(set) var keyArray4Query: [String]
    /// 所有真實索引鍵陣列的快取。
    public private(set) var allActualKeyArraysCached: Set<[String]>
    /// 雙元圖快取。
    public private(set) var bigramMap: [String: [Homa.Gram]]
    /// 該節點目前的覆寫狀態種類。
    public private(set) var currentOverrideType: OverrideType?
    /// 是否為使用者明確覆寫（explicit override）、而非出於自動機制進行的複寫。
    public private(set) var isExplicitlyOverridden: Bool = false

    /// 節點覆寫狀態。
    public var overrideStatus: Homa.NodeOverrideStatus {
      get {
        .init(
          overridingScore: overridingScore,
          currentOverrideType: currentOverrideType,
          isExplicitlyOverridden: isExplicitlyOverridden,
          currentUnigramIndex: currentGramIndex
        )
      }
      set {
        overridingScore = newValue.overridingScore
        isExplicitlyOverridden = newValue.isExplicitlyOverridden
        // 防範 GramIndex 溢出，如果溢出則重設覆寫狀態
        if newValue.currentUnigramIndex >= 0, newValue.currentUnigramIndex < grams.count {
          currentOverrideType = newValue.currentOverrideType
          currentGramIndex = newValue.currentUnigramIndex
        } else {
          reset()
        }
      }
    }

    /// 當前候選字詞的真實完整索引鍵陣列。
    public var keyArray: [String] { currentGram?.keyArray ?? keyArray4Query }

    /// 元圖陣列。
    public private(set) var grams: [Homa.Gram] {
      didSet {
        bigramMap = grams.allBigramsMap
        allActualKeyArraysCached = Set(grams.map(\.keyArray))
      }
    }

    /// 當前該節點所指向的（元圖陣列內的）元圖索引位置。
    public private(set) var currentGramIndex: Int = 0 {
      didSet { currentGramIndex = max(min(grams.count - 1, currentGramIndex), 0) }
    }
  }
}

// MARK: - Homa.Node + Hashable

extension Homa.Node: Hashable {
  /// 預設雜湊函式。
  /// - Parameter hasher: 目前物件的雜湊碼。
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(overridingScore)
    hasher.combine(keyArray4Query)
    hasher.combine(grams)
    hasher.combine(bigramMap)
    hasher.combine(currentOverrideType)
    hasher.combine(isExplicitlyOverridden)
    hasher.combine(currentGramIndex)
    hasher.combine(allActualKeyArraysCached)
  }
}

// MARK: - Homa.Node + Equatable

extension Homa.Node: Equatable {
  public static func == (lhs: Homa.Node, rhs: Homa.Node) -> Bool {
    // 基於功能內容的等價性比較，排除 ID 字段
    lhs.overridingScore == rhs.overridingScore &&
      lhs.keyArray4Query == rhs.keyArray4Query &&
      lhs.grams == rhs.grams &&
      lhs.bigramMap == rhs.bigramMap &&
      lhs.currentOverrideType == rhs.currentOverrideType &&
      lhs.currentGramIndex == rhs.currentGramIndex &&
      lhs.isExplicitlyOverridden == rhs.isExplicitlyOverridden &&
      lhs.allActualKeyArraysCached == rhs.allActualKeyArraysCached
  }
}

extension Homa.Node {
  /// 幅節長度。
  public var segLength: Int { keyArray.count }

  /// 該節點當前狀態所展示的鍵值配對。
  public var currentPair: Homa.CandidatePair? {
    guard let currentGram else { return nil }
    return .init(keyArray: currentGram.keyArray, value: currentGram.current)
  }

  /// 生成自身的拷貝。
  /// - Remark: 因為 Node 不是 Struct，所以會在 Assembler 被拷貝的時候無法被真實複製。
  /// 這樣一來，Assembler 複製品當中的 Node 的變化會被反應到原先的 Assembler 身上。
  /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
  public var copy: Homa.Node { .init(node: self) }

  /// 檢查當前節點是否「讀音字長與候選字字長不一致」。
  public var isReadingMismatched: Bool {
    guard let value else { return false }
    return keyArray.count != value.count
  }

  /// 該節點是否處於被覆寫的狀態。
  public var isOverridden: Bool { currentOverrideType != nil }

  /// 給出該節點內部元圖陣列內目前被索引位置所指向的元圖。
  public var currentGram: Homa.Gram? {
    grams.isEmpty ? nil : grams[currentGramIndex]
  }

  /// 給出該節點內部元圖陣列內目前被索引位置所指向的元圖的資料值。
  public var value: String? { currentGram?.current }

  /// 給出目前的最高權重單元圖當中的權重值。該結果可能會受節點覆寫狀態所影響。
  private var unigramScore: Double {
    let unigrams = grams.filter { ($0.previous ?? "").isEmpty }
    guard let firstUnigram = unigrams.first else { return 0 }
    switch currentOverrideType {
    case .withSpecified: return overridingScore
    case .withTopGramScore: return firstUnigram.probability
    default: return currentGram?.probability ?? firstUnigram.probability
    }
  }

  /// 給出目前的最高權元圖當中的權重值（包括雙元圖）。該結果可能會受節點覆寫狀態所影響。
  /// - Remark: 這個函式會根據比對到的前述節點內容，來查詢可能的雙元圖資料。
  /// 一旦有比對到相符的雙元圖資料，就會比較雙元圖資料的權重與當前節點的權重，並選擇
  /// 權重較高的那個、然後**據此視情況自動修改這個節點的覆寫狀態種類**。
  /// - Parameter previous: 前述節點內容，用以查詢可能的雙元圖資料。
  /// - Returns: 權重。
  internal func getScore(previous: String?) -> Double {
    guard !grams.isEmpty else { return 0 }
    guard let previous, !previous.isEmpty else { return unigramScore }
    let bigram = bigramMap[previous]?.sorted {
      $0.probability > $1.probability
    }.first {
      $0.current == currentGram?.current
    }
    let currentScore = unigramScore
    let bigramScore = bigram?.probability
    guard let bigram, let bigramScore else { return currentScore }
    guard bigramScore > currentScore else { return currentScore }
    do {
      try selectOverrideGram(
        keyArray: bigram.keyArray,
        value: bigram.current,
        previous: bigram.previous,
        type: .withTopGramScore
      )
      return bigramScore
    } catch {
      return currentScore
    }
  }

  /// 重設該節點的覆寫狀態、及其內部的元圖索引位置指向。
  internal func reset() {
    currentGramIndex = 0
    currentOverrideType = nil
    isExplicitlyOverridden = false
  }

  /// 置換掉該節點內的元圖陣列資料。
  /// 如果此時影響到了 currentUnigramIndex 所指的內容的話，則將其重設為 0。
  /// - Parameter source: 新的元圖陣列資料，必須不能為空（否則必定崩潰）。
  internal func syncingGrams(from source: [Homa.Gram]) {
    let oldCurrentValue = grams[currentGramIndex].current
    grams = source
    // 保險，請按需啟用。
    // if unigrams.isEmpty { unigrams.append(.init(value: key, score: -114.514)) }
    currentGramIndex = max(min(grams.count - 1, currentGramIndex), 0)
    let newCurrentValue = grams[currentGramIndex].current
    if oldCurrentValue != newCurrentValue { reset() }
  }

  /// 指定要覆寫的元圖資料值、以及覆寫行為種類。
  /// - Parameters:
  ///   - keyArray: 給定索引鍵陣列。
  ///   - value: 給定的元圖資料值。
  ///   - previous: 前述資料。
  ///   - type: 覆寫行為種類。
  /// - Returns: 複寫成功的 Gram。
  @discardableResult
  internal func selectOverrideGram(
    keyArray: [String]?,
    value: String,
    previous: String? = nil,
    type: Homa.Node.OverrideType
  ) throws
    -> Homa.Gram {
    for (i, gram) in grams.enumerated() {
      if let keyArray, keyArray != gram.keyArray { continue }
      if value != gram.current { continue }
      if let previous, !previous.isEmpty, previous != gram.previous { continue }
      currentGramIndex = i
      currentOverrideType = type
      if overridingScore < 114_514 {
        overridingScore = 114_514
      }
      return gram
    }
    throw Homa.Exception.nothingOverriddenAtNode
  }
}

// MARK: - Array Extensions.

extension Array where Element == Homa.Node {
  var asGramChain: [Homa.GramInPath] {
    compactMap { node in
      guard let gram = node.currentGram else { return nil }
      return .init(gram: gram, isExplicit: node.isExplicitlyOverridden)
    }
  }
}

// MARK: - Homa.NodeOverrideStatus

extension Homa {
  /// 節點覆寫狀態結構，用於輕量化狀態鏡照。
  public struct NodeOverrideStatus: Codable, Hashable {
    // MARK: Lifecycle

    /// 建構子。
    /// - Parameters:
    ///   - overridingScore: 覆寫分數。
    ///   - currentOverrideType: 當前覆寫類型。
    ///   - currentUnigramIndex: 當前單元圖索引。
    public init(
      overridingScore: Double = 114_514,
      currentOverrideType: Homa.Node.OverrideType? = nil,
      isExplicitlyOverridden: Bool = false,
      currentUnigramIndex: Int = 0
    ) {
      self.overridingScore = overridingScore
      self.currentOverrideType = currentOverrideType
      self.isExplicitlyOverridden = isExplicitlyOverridden
      self.currentUnigramIndex = currentUnigramIndex
    }

    // MARK: Public

    /// 覆寫分數。
    public var overridingScore: Double
    /// 當前覆寫類型。
    public var currentOverrideType: Homa.Node.OverrideType?
    /// 使用者是否明確覆寫（explicit override）。
    public var isExplicitlyOverridden: Bool
    /// 當前單元圖索引。
    public var currentUnigramIndex: Int
  }
}
