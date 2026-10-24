// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.Gram

extension Homa {
  /// 進階組字引擎專屬的語法單位類型，支援單元語法、雙元語法與三元語法結構。
  /// - Remark: 進階組字引擎所運用的雙元／三元語法資料 `previous`／`anterior` 不包含讀音資訊。
  public struct Gram: Codable, CustomStringConvertible, Equatable, Sendable, Hashable {
    // MARK: Lifecycle

    public init(_ rawTuple: GramRAW, backoff: Double = 0, id: FIUUID = .init()) {
      self.id = id
      self.keyArray = rawTuple.keyArray
      self.current = rawTuple.value
      if let previous = rawTuple.previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      if let anterior = rawTuple.anterior, !anterior.isEmpty {
        self.anterior = anterior
      } else {
        self.anterior = nil
      }
      self.probability = rawTuple.probability
      self.backoff = backoff
    }

    public init(
      keyArray: [String],
      current: String,
      previous: String? = nil,
      anterior: String? = nil,
      probability: Double = 0,
      backoff: Double = 0,
      id: FIUUID = .init()
    ) {
      self.id = id
      self.keyArray = keyArray
      if let previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      if let anterior, !anterior.isEmpty {
        self.anterior = anterior
      } else {
        self.anterior = nil
      }
      self.current = current
      self.probability = probability
      self.backoff = backoff
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyArray = try container.decode([String].self, forKey: .keyArray)
      self.current = try container.decode(String.self, forKey: .current)
      self.previous = try container.decodeIfPresent(String.self, forKey: .previous)
      self.anterior = try container.decodeIfPresent(String.self, forKey: .anterior)
      self.probability = try container.decode(Double.self, forKey: .probability)
      self.backoff = try container.decode(Double.self, forKey: .backoff)
      self.id = .init()
    }

    // MARK: Public

    /// 元圖識別碼。
    public let id: FIUUID
    public let keyArray: [String]
    public let current: String
    public let previous: String?
    public let anterior: String?
    public let probability: Double
    public let backoff: Double // 最大單元圖機率

    public var isUnigram: Bool { previous == nil && anterior == nil }

    /// 該元圖的前文鏈長（1 = 單元圖、2 = 雙元圖、3 = 三元圖）。
    /// - Note: 這是「詞鏈」的長度，不是讀音長度：多音節詞的單元圖仍然是 1。
    public var chainLength: Int { 1 + (previous == nil ? 0 : 1) + (anterior == nil ? 0 : 1) }

    public var description: String {
      describe(keySeparator: "-")
    }

    public var descriptionSansReading: String {
      guard let previous else {
        return "P(\(current))=\(probability), BOW('\(current)')=\(backoff)" // 單元圖
      }
      if let anterior {
        return "P(\(current)|\(previous),\(anterior))=\(probability)" // 三元圖
      }
      return "P(\(current)|\(previous))=\(probability)" // 雙元圖
    }

    public var asTuple: GramRAW {
      (
        keyArray: keyArray,
        value: current,
        probability: probability,
        previous: previous,
        anterior: anterior
      )
    }

    /// 檢查是否「讀音字長與候選字字長不一致」。
    public var isReadingMismatched: Bool {
      keyArray.count != current.count
    }

    /// 幅長。
    public var segLength: Int {
      keyArray.count
    }

    public static func == (lhs: Homa.Gram, rhs: Homa.Gram) -> Bool {
      lhs.keyArray == rhs.keyArray &&
        lhs.current == rhs.current &&
        lhs.previous == rhs.previous &&
        lhs.anterior == rhs.anterior &&
        lhs.probability == rhs.probability &&
        lhs.backoff == rhs.backoff
    }

    /// 把 n-gram 的原始分數換算成「相對同名節點單元圖基線的增益」，並按鏈長計次。
    ///
    /// 計分模型（P326）：`baseline + (chainLength − 1) × (probability − baseline)`。
    /// - 雙元圖（chainLength = 2）的結果與舊行為完全相同：`probability`。
    /// - 三元圖（chainLength = 3）把增益算兩次：`2 × probability − baseline`。
    ///
    /// 之所以要按鏈長計次：在「總分 = 各節點分數之和」的模型裡，若高階 n-gram 的增益
    /// 只算一次，兩條假設的勝負就只取決於各自增益之比（PMI 之比），與詞鏈長度無關。
    /// 如此一來，長鏈證據與短鏈證據等權，右文脈即使成立也扳不動左文脈。
    /// - Parameter baseline: 同名節點之單元圖基線分數（通常是該節點最高分的單元圖）。
    public func weightedScore(against baseline: Double) -> Double {
      baseline + Double(chainLength - 1) * (probability - baseline)
    }

    /// 生成內容雷同、但識別碼（FIUUID）全新的一份拷貝。
    ///
    /// 組字器的查詢快取以讀音陣列為索引鍵，內容相同的讀音序列在不同位置上
    /// 會共享同批查詢結果。各節點收治這些結果時必須重新賦予識別碼，
    /// 才能確保每個元圖在組句結果當中的位置唯一性。
    public func withNewIdentity() -> Self {
      .init(
        keyArray: keyArray,
        current: current,
        previous: previous,
        anterior: anterior,
        probability: probability,
        backoff: backoff
      )
    }

    public func describe(keySeparator: String) -> String {
      let header = "[\(isUnigram ? "Unigram" : (anterior != nil ? "Trigram" : "Bigram"))]"
      let body = "'\(keyArray.joined(separator: keySeparator))', \(descriptionSansReading)"
      return "\(header) \(body)"
    }

    /// 預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(current)
      hasher.combine(previous)
      hasher.combine(anterior)
      hasher.combine(probability)
      hasher.combine(backoff)
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(keyArray, forKey: .keyArray)
      try container.encode(current, forKey: .current)
      try container.encodeIfPresent(previous, forKey: .previous)
      try container.encodeIfPresent(anterior, forKey: .anterior)
      try container.encode(probability, forKey: .probability)
      try container.encode(backoff, forKey: .backoff)
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
      case keyArray = "keys"
      case current = "curr"
      case previous = "prev"
      case anterior = "ante"
      case probability = "prob"
      case backoff = "bkof"
    }
  }
}

extension Array where Element == Homa.Gram {
  var asGramTypes: (unigrams: [Element], bigrams: [Element]) {
    reduce(into: ([Element](), [Element]())) { result, element in
      if element.isUnigram {
        result.0.append(element)
      } else {
        result.1.append(element)
      }
    }
  }
}
