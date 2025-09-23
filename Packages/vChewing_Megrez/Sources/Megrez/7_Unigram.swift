// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Unigram

extension Megrez {
  /// 語言模型的基礎資料單位結構。
  public struct Unigram: Equatable, CustomStringConvertible, Hashable, Codable {
    // MARK: Lifecycle

    /// 建立語言模型基礎資料單位副本。基礎資料單位由詞彙內容與統計權重組成。
    /// - Parameters:
    ///   - value: 詞彙內容。
    ///   - score: 統計權重（雙精度浮點數）。
    public init(value: String = "", score: Double = 0) {
      self.value = value
      self.score = score
    }

    // MARK: Public

    /// 詞彙內容，可以是單字或詞組。
    public var value: String
    /// 統計權重。
    public var score: Double

    /// 將當前單元圖列印成一個字串。
    public var description: String {
      "(" + value.description + "," + String(score) + ")"
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.hashValue == rhs.hashValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.value < rhs.value || (lhs.value == rhs.value && lhs.score < rhs.score)
    }

    /// 做為預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(value)
      hasher.combine(score)
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
