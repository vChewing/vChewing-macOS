// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

extension Megrez {
  /// 鍵值配對。
  @frozen public struct KeyValuePair: Equatable, Hashable, Comparable, CustomStringConvertible {
    /// 鍵。一般情況下用來放置讀音等可以用來作為索引的內容。
    public var key: String
    /// 資料值。
    public var value: String
    /// 將當前鍵值列印成一個字串。
    public var description: String {
      "(" + key + "," + value + ")"
    }

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

    public static func == (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
      lhs.key.count == rhs.key.count && lhs.value == rhs.value
    }

    public static func < (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
      (lhs.key.count < rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value < rhs.value)
    }

    public static func > (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
      (lhs.key.count > rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value > rhs.value)
    }

    public static func <= (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
      (lhs.key.count <= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value <= rhs.value)
    }

    public static func >= (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
      (lhs.key.count >= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value >= rhs.value)
    }
  }
}
