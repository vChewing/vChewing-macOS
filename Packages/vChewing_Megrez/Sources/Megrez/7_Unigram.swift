// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// Walking algorithm (Dijkstra) implemented by (c) 2025 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// MARK: - Megrez.Unigram

extension Megrez {
  /// 單元圖。
  public struct Unigram: Equatable, CustomStringConvertible, Hashable, Codable {
    // MARK: Lifecycle

    /// 初期化一筆「單元圖」。一筆單元圖由一筆資料值與一筆權重數值組成。
    /// - Parameters:
    ///   - value: 資料值。
    ///   - score: 權重（雙精度小數）。
    public init(value: String = "", score: Double = 0) {
      self.value = value
      self.score = score
    }

    // MARK: Public

    /// 資料值，通常是詞語或單個字。
    public var value: String
    /// 權重。
    public var score: Double

    /// 將當前單元圖列印成一個字串。
    public var description: String {
      "(" + value.description + "," + String(score) + ")"
    }

    public static func == (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.value == rhs.value && lhs.score == rhs.score
    }

    public static func < (lhs: Unigram, rhs: Unigram) -> Bool {
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
