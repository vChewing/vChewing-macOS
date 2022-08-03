// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension Megrez {
  /// 鍵值配對。
  @frozen public struct KeyValuePaired: Equatable, Hashable, Comparable, CustomStringConvertible {
    /// 鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    public var key: String
    /// 資料值。
    public var value: String
    /// 將當前鍵值列印成一個字串。
    public var description: String { "(" + key + "," + value + ")" }
    /// 判斷當前鍵值配對是否合規。如果鍵與值有任一為空，則結果為 false。
    public var isValid: Bool { !key.isEmpty && !value.isEmpty }
    /// 將當前鍵值列印成一個字串，但如果該鍵值配對為空的話則僅列印「()」。
    public var toNGramKey: String { !isValid ? "()" : "(" + key + "," + value + ")" }

    /// 初期化一組鍵值配對。
    /// - Parameters:
    ///   - key: 鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    ///   - value: 資料值。
    public init(key: String = "", value: String = "") {
      self.key = key
      self.value = value
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(value)
    }

    public static func == (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      lhs.key == rhs.key && lhs.value == rhs.value
    }

    public static func < (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.key.count < rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value < rhs.value)
    }

    public static func > (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.key.count > rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value > rhs.value)
    }

    public static func <= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.key.count <= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value <= rhs.value)
    }

    public static func >= (lhs: KeyValuePaired, rhs: KeyValuePaired) -> Bool {
      (lhs.key.count >= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value >= rhs.value)
    }
  }
}
