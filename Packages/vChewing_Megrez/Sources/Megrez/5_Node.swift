// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Node

extension Megrez {
  /// 組字引擎中資料處理的基礎單位。
  ///
  /// 節點物件整合了讀音索引鍵序列、涵蓋範圍長度、以及對應的單元圖資料集合。涵蓋範圍長度
  /// 表示此節點在完整讀音序列中所佔據的位置數量。組字引擎會根據輸入序列自動產生
  /// 對應的節點結構。對於包含多個字符的詞條，引擎會整合相關的多個讀音形成複合索引鍵，
  /// 並從語言模型中獲取相應的單元圖資料集合。例如，包含兩個字符的詞條對應兩個讀音，
  /// 其節點的涵蓋範圍長度為 2。
  public final class Node: Equatable, Hashable, Codable {
    // MARK: Lifecycle

    /// 建立新的節點物件副本。
    ///
    /// 節點物件整合了讀音索引鍵序列、涵蓋範圍長度、以及對應的單元圖資料集合。涵蓋範圍長度
    /// 表示此節點在完整讀音序列中所佔據的位置數量。組字引擎會根據輸入序列自動產生
    /// 對應的節點結構。對於包含多個字符的詞條，引擎會整合相關的多個讀音形成複合索引鍵，
    /// 並從語言模型中獲取相應的單元圖資料集合。例如，包含兩個字符的詞條對應兩個讀音，
    /// 其節點的涵蓋範圍長度為 2。
    /// - Parameters:
    ///   - keyArray: 輸入的索引鍵序列，不可為空集合。
    ///   - segLength: 節點涵蓋範圍長度，通常與索引鍵序列元素數量相等。
    ///   - unigrams: 關聯的單元圖資料集合，不可為空集合。
    public init(keyArray: [String] = [], segLength: Int = 0, unigrams: [Megrez.Unigram] = []) {
      self.id = FIUUID()
      self.keyArray = keyArray
      self.segLength = max(segLength, 0)
      self.unigrams = unigrams
      self.currentOverrideType = nil
    }

    /// 通過複製現有節點來建立新副本。
    /// - Remark: 由於 Node 採用類別設計而非結構體，因此在 Compositor 複製過程中無法自動執行深層複製。
    /// 這會導致複製後的 Composer 副本中的 Node 變更會影響到原始的 Composer 副本。
    /// 為了避免此類非預期的互動影響，特別提供此複製建構函數。
    public init(node: Node) {
      self.id = FIUUID()
      self.overridingScore = node.overridingScore
      self.keyArray = node.keyArray
      self.segLength = node.segLength
      self.unigrams = node.unigrams.map(\.copy)
      self.currentOverrideType = node.currentOverrideType
      self.isExplicitlyOverridden = node.isExplicitlyOverridden
      self.currentUnigramIndex = node.currentUnigramIndex
    }

    // MARK: Public

    /// 針對節點可能套用的覆寫行為種類。
    /// - withTopGramScore: 專用於雙元圖的自動選取功能，但效力低於 withSpecified 模式。
    /// 該覆寫行為無法防止其它節點被組句函式所支配。這種情況下就需要用到 overridingScore。
    /// - withSpecified: 將該節點權重覆寫為 overridingScore，使其被組句函式所青睞。
    /// 但是這個選項也可以允許搭配過低的 overridingScore 來起到 demote 的效果。
    public enum OverrideType: Int, Codable {
      case withTopGramScore = 1
      case withSpecified = 2
    }

    /// 節點的唯一識別符。
    public let id: FIUUID

    /// 一個用以覆寫權重的數值。該數值之高足以改變組句函式對該節點的讀取結果。這裡用
    /// 「0」可能看似足夠了，但仍會使得該節點的覆寫狀態有被組句函式忽視的可能。比方說
    /// 要針對索引鍵「a b c」複寫的資料值為「A B C」，使用大寫資料值來覆寫節點。這時，
    /// 如果這個獨立的 c 有一個可以拮抗權重的詞「bc」的話，可能就會導致組句函式的算法
    /// 找出「A->bc」的組句途徑（尤其是當 A 和 B 使用「0」作為複寫數值的情況下）。這樣
    /// 一來，「A-B」就不一定始終會是組句函式的青睞結果了。所以，這裡一定要用大於 0 的
    /// 數（比如野獸常數），以讓「c」更容易單獨被選中。
    public var overridingScore: Double = 114_514

    /// 索引鍵陣列。
    public private(set) var keyArray: [String]
    /// 幅節長度。
    public private(set) var segLength: Int
    /// 單元圖陣列。
    public private(set) var unigrams: [Megrez.Unigram]
    /// 該節點目前的覆寫狀態種類。為 `nil` 時表示無覆寫行為。
    public private(set) var currentOverrideType: Node.OverrideType?
    /// 是否為使用者明確覆寫（explicit override）、而非出於自動機制進行的複寫。
    public private(set) var isExplicitlyOverridden: Bool = false

    /// 當前該節點所指向的（單元圖陣列內的）單元圖索引位置。
    public private(set) var currentUnigramIndex: Int = 0 {
      didSet { currentUnigramIndex = max(min(unigrams.count - 1, currentUnigramIndex), 0) }
    }

    /// 該節點當前狀態所展示的鍵值配對。
    public var currentPair: Megrez.KeyValuePaired { .init(keyArray: keyArray, value: value) }

    /// 生成自身的拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
    /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public var copy: Node { .init(node: self) }

    /// 檢查當前節點是否「讀音字長與候選字字長不一致」。
    public var isReadingMismatched: Bool { keyArray.count != value.count }
    /// 該節點是否處於被覆寫的狀態。
    public var isOverridden: Bool { currentOverrideType != nil }

    /// 給出該節點內部單元圖陣列內目前被索引位置所指向的單元圖。
    public var currentUnigram: Megrez.Unigram {
      unigrams.isEmpty ? .init() : unigrams[currentUnigramIndex]
    }

    /// 給出該節點內部單元圖陣列內目前被索引位置所指向的單元圖的資料值。
    public var value: String { currentUnigram.value }

    /// 給出目前的最高權重單元圖當中的權重值。該結果可能會受節點覆寫狀態所影響。
    public var score: Double {
      guard !unigrams.isEmpty else { return 0 }
      guard let overrideType = currentOverrideType else { return currentUnigram.score }
      switch overrideType {
      case .withSpecified: return overridingScore
      case .withTopGramScore: return unigrams[0].score
      }
    }

    /// 節點覆寫狀態的動態屬性，允許直接讀取和設定覆寫狀態。
    public var overrideStatus: NodeOverrideStatus {
      get {
        NodeOverrideStatus(
          overridingScore: overridingScore,
          currentOverrideType: currentOverrideType,
          isExplicitlyOverridden: isExplicitlyOverridden,
          currentUnigramIndex: currentUnigramIndex
        )
      }
      set {
        overridingScore = newValue.overridingScore
        currentOverrideType = newValue.currentOverrideType
        isExplicitlyOverridden = newValue.isExplicitlyOverridden
        // 防範 UnigramIndex 溢出，如果溢出則重設覆寫狀態
        if newValue.currentUnigramIndex >= 0, newValue.currentUnigramIndex < unigrams.count {
          currentUnigramIndex = newValue.currentUnigramIndex
        } else {
          reset()
        }
      }
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
      // 基於功能內容的等價性比較，排除 ID 字段
      lhs.overridingScore == rhs.overridingScore &&
        lhs.keyArray == rhs.keyArray &&
        lhs.segLength == rhs.segLength &&
        lhs.unigrams == rhs.unigrams &&
        lhs.currentOverrideType == rhs.currentOverrideType &&
        lhs.currentUnigramIndex == rhs.currentUnigramIndex
    }

    /// 做為預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(overridingScore)
      hasher.combine(keyArray)
      hasher.combine(segLength)
      hasher.combine(unigrams)
      hasher.combine(currentOverrideType)
      hasher.combine(currentUnigramIndex)
    }

    /// 重設該節點的覆寫狀態、及其內部的單元圖索引位置指向。
    public func reset() {
      currentUnigramIndex = 0
      currentOverrideType = nil
    }

    /// 將索引鍵按照給定的分隔符銜接成一個字串。
    /// - Parameter separator: 給定的分隔符，預設值為 Compositor.theSeparator。
    /// - Returns: 已經銜接完畢的字串。
    public func joinedKey(by separator: String = Megrez.Compositor.theSeparator) -> String {
      keyArray.joined(separator: separator)
    }

    /// 置換掉該節點內的單元圖陣列資料。
    /// 如果此時影響到了 currentUnigramIndex 所指的內容的話，則將其重設為 0。
    /// - Parameter source: 新的單元圖陣列資料，必須不能為空（否則必定崩潰）。
    public func syncingUnigrams(from source: [Megrez.Unigram]) {
      let oldCurrentValue = unigrams[currentUnigramIndex].value
      unigrams = source
      // if unigrams.isEmpty { unigrams.append(.init(value: key, score: -114.514)) }  // 保險，請按需啟用。
      currentUnigramIndex = max(min(unigrams.count - 1, currentUnigramIndex), 0)
      let newCurrentValue = unigrams[currentUnigramIndex].value
      if oldCurrentValue != newCurrentValue { reset() }
    }

    /// 指定要覆寫的單元圖資料值、以及覆寫行為種類。
    /// - Parameters:
    ///   - value: 給定的單元圖資料值。
    ///   - type: 覆寫行為種類。
    /// - Returns: 操作是否順利完成。
    public func selectOverrideUnigram(value: String, type: Node.OverrideType) -> Bool {
      for (i, gram) in unigrams.enumerated() {
        if value != gram.value { continue }
        currentUnigramIndex = i
        currentOverrideType = type
        if overridingScore < 114_514 {
          overridingScore = 114_514
        }
        return true
      }
      return false
    }
  }
}

// MARK: - NodeOverrideStatus

/// 節點覆寫狀態封裝結構，用於記錄 Node 的覆寫相關狀態。
/// 這個結構體允許輕量級地複製和恢復節點狀態，避免完整複製整個 Compositor。
public struct NodeOverrideStatus: Codable, Hashable {
  // MARK: Lifecycle

  /// 初始化一個節點覆寫狀態
  /// - Parameters:
  ///   - overridingScore: 覆寫權重數值
  ///   - currentOverrideType: 當前覆寫狀態種類
  ///   - currentUnigramIndex: 當前單元圖索引位置
  public init(
    overridingScore: Double = 114_514,
    currentOverrideType: Megrez.Node.OverrideType? = nil,
    isExplicitlyOverridden: Bool = false,
    currentUnigramIndex: Int = 0
  ) {
    self.overridingScore = overridingScore
    self.currentOverrideType = currentOverrideType
    self.isExplicitlyOverridden = isExplicitlyOverridden
    self.currentUnigramIndex = currentUnigramIndex
  }

  // MARK: Public

  /// 覆寫權重數值
  public var overridingScore: Double
  /// 當前覆寫狀態種類
  public var currentOverrideType: Megrez.Node.OverrideType?
  /// 當前單元圖索引位置
  public var currentUnigramIndex: Int
  /// 使用者是否明確覆寫（explicit override）
  public var isExplicitlyOverridden: Bool
}
