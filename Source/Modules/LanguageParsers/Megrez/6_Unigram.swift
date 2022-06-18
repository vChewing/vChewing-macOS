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
  /// 單元圖。
  @frozen public struct Unigram: Equatable, CustomStringConvertible {
    /// 鍵值。
    public var keyValue: KeyValuePair
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
    public init(keyValue: KeyValuePair, score: Double) {
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
      lhs.keyValue < rhs.keyValue || (lhs.keyValue == rhs.keyValue && lhs.keyValue < rhs.keyValue)
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
