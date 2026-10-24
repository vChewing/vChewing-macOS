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
  public struct Node: Codable {
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
      self.currentOverrideType = nil
    }

    /// 以指定字詞節點生成拷貝（識別碼全新）。
    internal init(node: Self) {
      self.id = FIUUID()
      self.overridingScore = node.overridingScore
      self.keyArray4Query = node.keyArray4Query
      self.allActualKeyArraysCached = node.allActualKeyArraysCached
      self.grams = node.grams
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
    // 與 `==` 的「內容等值、排除 ID」語義保持一致：ID 僅作為節點的身分標記
    // （新建節點 / copy 生成全新 ID、值拷貝共享 ID），不參與等值與雜湊，
    // 以免違反 Hashable 契約（相等物件必須具有相同雜湊值）。
    hasher.combine(overridingScore)
    hasher.combine(keyArray4Query)
    hasher.combine(grams)
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

  /// 生成自身的拷貝（識別碼全新）。
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

  /// 該節點在給定前文下的估值結果。
  ///
  /// 這是 `getScore(previous:anterior:)` 的純函式版本：**完全不改動節點狀態**，
  /// 只回報「該得多少分」與「該把選取移到哪一條元圖」。組句的動態規劃需要對同一個
  /// 節點以多組前文反覆估值（右文脈 DP），若估值帶副作用，則結果會取決於估值順序。
  internal struct Evaluation {
    /// 此次估值得出的分數。
    internal let score: Double
    /// 該把 `currentGramIndex` 移到哪一條元圖；`nil` 表示維持現有選取
    /// （弱釘選，以及節點內連一條單元圖都沒有的情形）。
    internal let targetIndex: Int?
  }

  /// 給出目前的最高權元圖當中的權重值（包括雙元圖與三元圖）。該結果可能會受節點覆寫狀態所影響。
  /// - Remark: 這個函式會根據比對到的前述節點內容，來查詢可能的雙元／三元圖資料。
  /// 一旦有比對到相符的雙元／三元圖資料，就會比較其權重與當前節點的權重，並選擇
  /// 權重較高的那個、然後**據此視情況移動這個節點的選取**。
  /// - Important: 這是「估值＋寫回」的合體版，只適合**單一路徑**的場合。需要同時評估
  ///   多條假設時（右文脈 DP），請改用 `evaluate(previous:anterior:)` 取得純量結果，
  ///   再於確定勝出路徑之後呼叫 `adopt(gram:)`；否則節點狀態會被「最後一次估值」污染。
  /// - Parameters:
  ///   - previous: 前述節點內容，用以查詢可能的雙元圖資料。
  ///   - anterior: 前述節點再往前一格的內容，用以查詢可能的三元圖資料（可選）。
  /// - Returns: 權重。
  internal mutating func getScore(previous: String?, anterior: String? = nil) -> Double {
    let evaluation = evaluate(previous: previous, anterior: anterior)
    if let targetIndex = evaluation.targetIndex { currentGramIndex = targetIndex }
    return evaluation.score
  }

  /// 以給定前文估值，但不改動任何狀態（`getScore(previous:anterior:)` 的純函式版本）。
  ///
  /// 右文脈 DP 需要對同一個節點以多組前文反覆估值（「在」與「再」兩條假設都得活到
  /// 右邊的詞進來），若估值本身帶副作用，結果就會取決於估值順序、無法重現。
  /// - Parameters:
  ///   - previous: 前述節點內容。
  ///   - anterior: 前述節點再往前一格的內容（可選）。
  /// - Returns: 分數與「該把選取移到哪一條元圖」。
  internal func evaluate(previous: String?, anterior: String? = nil) -> Evaluation {
    guard !grams.isEmpty else { return .init(score: 0, targetIndex: nil) }
    let hasPrevious = !(previous ?? "").isEmpty

    // 單次線性掃描元圖陣列：同步捕捉「陣列順序上的首個單元圖機率」、「前述內容相符的
    // 最高權重雙元圖」與「前驅二位相符的最高權重三元圖」。匹配不與 currentGram 綁定
    // （currentGram 可能因先前未匹配語境而指向 unigram）。
    var firstUnigramProbability: Double?
    var firstUnigramIndex: Int?
    var bestBigram: Homa.Gram?
    var bestTrigram: Homa.Gram?
    for (index, gram) in grams.enumerated() {
      if (gram.previous ?? "").isEmpty, (gram.anterior ?? "").isEmpty, firstUnigramProbability == nil {
        firstUnigramProbability = gram.probability
        firstUnigramIndex = index
      }
      guard hasPrevious, gram.previous == previous else { continue }
      // 三元圖：需 exact 匹配前驅二位（anterior 語境存在時才可比對）。
      if let anterior, !anterior.isEmpty, gram.anterior == anterior {
        guard let currentBest = bestTrigram else {
          bestTrigram = gram
          continue
        }
        if gram.probability > currentBest.probability { bestTrigram = gram }
        continue
      }
      // 雙元圖：僅要求 previous 匹配（anterior 非空的三元圖在此語境下不可用）。
      guard (gram.anterior ?? "").isEmpty else { continue }
      guard let currentBest = bestBigram else {
        bestBigram = gram
        continue
      }
      if gram.probability > currentBest.probability { bestBigram = gram }
    }
    let unigramBaseline = firstUnigramProbability ?? 0
    // 依序取「三元圖 → 雙元圖」中（按鏈長計次後）增益最高者作為加分項。
    // 取捨用計次後的分數：trigram 的增益算兩次（P326），故原始機率較低的 trigram 可能反而勝出。
    var bestBonus: Homa.Gram?
    if let bestTrigram { bestBonus = bestTrigram }
    if let bestBigram,
       bestBonus == nil
       || bestBigram.weightedScore(against: unigramBaseline)
       > (bestBonus?.weightedScore(against: unigramBaseline) ?? -.infinity) {
      bestBonus = bestBigram
    }
    switch currentOverrideType {
    case .withSpecified:
      return .init(score: overridingScore, targetIndex: nil)
    case .withTopGramScore:
      // 弱釘選語義（與既有行為一致）：維持既有選取（currentGramIndex 不動）、
      // 以 unigram 基線計分——`withTopGramScore` 只釘「選取了哪個 gram」、不釘分數。
      return .init(score: unigramBaseline, targetIndex: nil)
    default:
      // 無前述內容：語境無從確認，一律以陣列順序的首條單元圖計分（該節點連一條單元圖
      // 都沒有的話，退回首條 gram）。這裡刻意不讀任何殘留選取狀態：右文脈 DP 會對同一
      // 節點以多組前文反覆估值，無前文分數若隨 `currentGramIndex` 漂移，組句就不再可重現。
      guard hasPrevious else {
        let fallbackProbability = firstUnigramProbability ?? grams[0].probability
        return .init(score: fallbackProbability, targetIndex: firstUnigramIndex ?? 0)
      }
      // 有匹配加分且高於 unigram 基線 → 選中 bonus gram；否則將選取指向最佳單元圖
      // （未匹配語境的 top bigram／trigram 不應留駐輸出）。
      if let bestBonus, bestBonus.probability > unigramBaseline,
         let bonusIndex = grams.firstIndex(of: bestBonus) {
        // 語境加分是**當次推導**之結果，不得記成覆寫狀態：`withTopGramScore` 之計分臂
        // 逕以 unigram 基線計分，一旦記上，下一次組句就不會重算加分、該節點隨即退回
        // 無語境之選取（症狀：記憶詞只出現一拍、下一個按鍵即被詞庫長詞取代）。
        // 故這裡只回報「該把選取移到哪」，實際移動交給組句器在回溯勝出路徑時呼叫的
        // `adopt(gram:)`。
        return .init(score: bestBonus.weightedScore(against: unigramBaseline), targetIndex: bonusIndex)
      }
      return .init(score: unigramBaseline, targetIndex: firstUnigramIndex)
    }
  }

  /// 把 `currentGramIndex` 移到指定元圖上；只移動選取、不動覆寫狀態。
  /// - Remark: 右文脈 DP 只在**確定的勝出路徑**上呼叫此函式，且時機在整個動態規劃
  ///   結束之後——同一節點在推導期間會被多組前文估值，不得被任一組污染。
  internal mutating func adopt(gram: Homa.Gram) {
    guard let index = grams.firstIndex(of: gram) else { return }
    currentGramIndex = index
  }

  /// 重設該節點的覆寫狀態、及其內部的元圖索引位置指向。
  internal mutating func reset() {
    currentGramIndex = 0
    currentOverrideType = nil
    isExplicitlyOverridden = false
  }

  /// 置換掉該節點內的元圖陣列資料。
  /// 如果此時影響到了 currentUnigramIndex 所指的內容的話，則將其重設為 0。
  /// - Parameter source: 新的元圖陣列資料，必須不能為空（否則必定崩潰）。
  internal mutating func syncingGrams(from source: [Homa.Gram]) {
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
  ///   - anterior: 前述資料再往前一格（三元圖用，可選）。
  ///   - type: 覆寫行為種類。
  /// - Returns: 複寫成功的 Gram。
  @discardableResult
  internal mutating func selectOverrideGram(
    keyArray: [String]?,
    value: String,
    previous: String? = nil,
    anterior: String? = nil,
    type: Homa.Node.OverrideType
  ) throws
    -> Homa.Gram {
    for (i, gram) in grams.enumerated() {
      if let keyArray, keyArray != gram.keyArray { continue }
      if value != gram.current { continue }
      if let previous, !previous.isEmpty, previous != gram.previous { continue }
      if let anterior, !anterior.isEmpty, anterior != gram.anterior { continue }
      currentGramIndex = i
      currentOverrideType = type
      if overridingScore < 114_514 {
        overridingScore = 114_514
      }
      return gram
    }
    throw Homa.Exception.nothingOverriddenAtNode
  }

  /// 依語境選定該節點要展示的元圖（僅移動 `currentGramIndex`），**不改動覆寫狀態**。
  ///
  /// 供組句函式於「語境加分（bigram／trigram）命中」時使用。語境加分是**當次推導**之結果，
  /// 必須於每次組句時重新推導；記成 `.withTopGramScore` 覆寫狀態的話，下一次組句即改走該臂
  /// 之「以 unigram 基線計分」語義、加分不再重算，該節點遂退回無語境之選取。
  /// - Parameters:
  ///   - keyArray: 給定索引鍵陣列。
  ///   - value: 給定的元圖資料值。
  ///   - previous: 前述資料。
  ///   - anterior: 前述資料再往前一格（三元圖用，可選）。
  /// - Returns: 選定成功的 Gram。
  @discardableResult
  internal mutating func adoptGramForContext(
    keyArray: [String]?,
    value: String,
    previous: String? = nil,
    anterior: String? = nil
  ) throws
    -> Homa.Gram {
    for (i, gram) in grams.enumerated() {
      if let keyArray, keyArray != gram.keyArray { continue }
      if value != gram.current { continue }
      if let previous, !previous.isEmpty, previous != gram.previous { continue }
      if let anterior, !anterior.isEmpty, anterior != gram.anterior { continue }
      currentGramIndex = i
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
