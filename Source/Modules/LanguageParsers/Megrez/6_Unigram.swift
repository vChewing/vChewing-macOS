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
  @frozen public struct Unigram: Equatable {
    public var keyValue: KeyValuePair
    public var score: Double
    // var paired: String

    public init(keyValue: KeyValuePair, score: Double) {
      self.keyValue = keyValue
      self.score = score
      // paired = "(" + keyValue.paired + "," + String(score) + ")"
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyValue)
      hasher.combine(score)
      // hasher.combine(paired)
    }

    // 這個函數不再需要了。
    public static func compareScore(a: Unigram, b: Unigram) -> Bool {
      a.score > b.score
    }

    //    static func getPairedUnigrams(grams: [Unigram]) -> String {
    //      var arrOutputContent = [""]
    //      var index = 0
    //      for gram in grams {
    //        arrOutputContent.append(contentsOf: [String(index) + "=>" + gram.paired])
    //        index += 1
    //      }
    //      return "[" + String(grams.count) + "]=>{" + arrOutputContent.joined(separator: ",") + "}"
    //    }

    public static func == (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.keyValue == rhs.keyValue && lhs.score == rhs.score
    }

    public static func < (lhs: Unigram, rhs: Unigram) -> Bool {
      lhs.keyValue < rhs.keyValue || (lhs.keyValue == rhs.keyValue && lhs.keyValue < rhs.keyValue)
    }

    var description: String {
      "\(keyValue):\(score)"
    }

    var debugDescription: String {
      "Unigram(keyValue: \(keyValue), score: \(score))"
    }
  }
}
