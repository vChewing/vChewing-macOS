// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension Megrez {
  /// 單元圖。
  @frozen public struct Unigram: Equatable, CustomStringConvertible, Hashable {
    /// 鍵值。
    public var keyValue: KeyValuePaired
    /// 權重。
    public var score: Double
    /// 將當前單元圖列印成一個字串。
    public var description: String {
      "(" + keyValue.description + "," + String(score) + ")"
    }

    /// 初期化一筆「單元圖」。一筆單元圖由一組鍵值配對與一筆權重數值組成。
    /// - Parameters:
    ///   - keyValue: 鍵值。
    ///   - score: 權重（雙精度小數）。
    public init(keyValue: KeyValuePaired, score: Double) {
      self.keyValue = keyValue
      self.score = score
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyValue)
      hasher.combine(score)
    }

    public static func == (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.keyValue == rhs.keyValue && lhs.score == rhs.score
    }

    public static func < (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.keyValue < rhs.keyValue || (lhs.keyValue == rhs.keyValue && lhs.score < rhs.score)
    }
  }
}

// MARK: - DumpDOT-related functions.

extension Array where Element == Megrez.Unigram {
  /// 將單元圖陣列列印成一個字串。
  public var description: String {
    var arrOutputContent = [""]
    for (index, gram) in enumerated() {
      arrOutputContent.append(contentsOf: [String(index) + "=>" + gram.description])
    }
    return "[" + String(count) + "]=>{" + arrOutputContent.joined(separator: ",") + "}"
  }
}
