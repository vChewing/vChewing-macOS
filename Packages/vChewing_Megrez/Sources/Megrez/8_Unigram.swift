// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez {
  /// 單元圖。
  @frozen public struct Unigram: Equatable, CustomStringConvertible, Hashable {
    /// 鍵值。
    public var value: String
    /// 權重。
    public var score: Double
    /// 將當前單元圖列印成一個字串。
    public var description: String {
      "(" + value.description + "," + String(score) + ")"
    }

    /// 初期化一筆「單元圖」。一筆單元圖由一組鍵值配對與一筆權重數值組成。
    /// - Parameters:
    ///   - value: 鍵值。
    ///   - score: 權重（雙精度小數）。
    public init(value: String = "", score: Double = 0) {
      self.value = value
      self.score = score
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(value)
      hasher.combine(score)
    }

    public static func == (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.value == rhs.value && lhs.score == rhs.score
    }

    public static func < (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.value < rhs.value || (lhs.value == rhs.value && lhs.score < rhs.score)
    }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.Unigram {
  /// 給定過濾清單，讓單元圖陣列自我過濾。
  public mutating func consolidate(filter theFilter: Set<String> = .init()) {
    var inserted: [String: Double] = [:]
    var insertedArray: [Megrez.Unigram] = []
    for neta in filter({ !theFilter.contains($0.value) }) {
      if inserted.keys.contains(neta.value) { continue }
      inserted[neta.value] = neta.score
      insertedArray.append(neta)
    }
    self = insertedArray
  }
}
