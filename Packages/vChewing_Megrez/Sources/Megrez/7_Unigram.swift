// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Unigram

extension Megrez {
  /// 語言模型的基礎資料單位類型。
  public struct Unigram: Codable, CustomStringConvertible, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    /// 建立語言模型基礎資料單位副本。基礎資料單位由索引鍵陣列、詞彙內容與統計權重組成。
    /// - Parameters:
    ///   - keyArray: 對應的索引鍵陣列。
    ///   - value: 詞彙內容。
    ///   - score: 統計權重（雙精度浮點數）。
    ///   - id: 指定識別碼，預設會自動生成。
    public init(
      keyArray: [String] = [],
      value: String = "",
      score: Double = 0,
      id: FIUUID = .init()
    ) {
      self.id = id
      self.keyArray = keyArray
      self.value = value
      self.score = score
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyArray = try container.decode([String].self, forKey: .keyArray)
      self.value = try container.decode(String.self, forKey: .value)
      self.score = try container.decode(Double.self, forKey: .score)
      self.id = .init()
    }

    // MARK: Public

    /// 單元圖識別碼。
    public let id: FIUUID
    /// 對應的索引鍵陣列。
    public let keyArray: [String]
    /// 詞彙內容，可以是單字或詞組。
    public let value: String
    /// 統計權重。
    public let score: Double

    /// 段長（索引鍵陣列的元素數量）。
    public var segLength: Int { keyArray.count }

    /// 檢查是否「讀音字長與候選字字長不一致」。
    public var isReadingMismatched: Bool { keyArray.count != value.count }

    /// 將當前單元圖列印成一個字串。
    public var description: String {
      "(\(keyArray.joined(separator: "-")),\(value),\(score))"
    }

    /// 單元圖的淺層複製品（保持相同的索引鍵陣列）。
    public var copy: Self { copy(withKeyArray: nil) }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.keyArray == rhs.keyArray && lhs.value == rhs.value && lhs.score == rhs.score
    }

    /// 建立一個新的單元圖副本。
    /// - Parameter keyArrayOverride: 若指定，則使用新的索引鍵陣列。
    /// - Returns: 單元圖副本。
    public func copy(withKeyArray keyArrayOverride: [String]? = nil) -> Self {
      .init(keyArray: keyArrayOverride ?? keyArray, value: value, score: score)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(value)
      hasher.combine(score)
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(keyArray, forKey: .keyArray)
      try container.encode(value, forKey: .value)
      try container.encode(score, forKey: .score)
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
      case keyArray
      case value
      case score
    }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.Unigram {
  /// 給定過濾清單，讓單元圖陣列自我過濾。
  public mutating func consolidate(filter theFilter: Set<String> = .init()) {
    var inserted: [String: Double] = [:]
    var insertedArray: [Megrez.Unigram] = []
    filter { !theFilter.contains($0.value) }.forEach { neta in
      if inserted.keys.contains(neta.value) { return }
      inserted[neta.value] = neta.score
      insertedArray.append(neta)
    }
    self = insertedArray
  }
}
