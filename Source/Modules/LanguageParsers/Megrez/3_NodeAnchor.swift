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
  /// 節锚。
  @frozen public struct NodeAnchor: Hashable {
    /// 用來判斷該節錨是否為空。
    public var isEmpty: Bool { node.key.isEmpty }
    /// 節點。一個節锚內不一定有節點。
    public var node: Node = .init()
    /// 指定的幅位長度。
    public var spanLength: Int { node.spanLength }
    /// 獲取用來比較的權重。
    public var scoreForSort: Double { node.score }
    /// 累計權重。
    public var mass: Double = 0.0
    /// 單元圖陣列。
    public var unigrams: [Unigram] { node.unigrams }
    /// 雙元圖陣列。
    public var bigrams: [Bigram] { node.bigrams }
    /// 鍵。
    public var key: String { node.key }

    /// 初期化一個節錨。
    public init(node: Node = .init(), mass: Double? = nil) {
      self.node = node
      self.mass = mass ?? self.node.score
    }

    /// 將該節錨雜湊化。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(node)
      hasher.combine(mass)
    }

    /// 將當前節锚列印成一個字串。
    public var description: String {
      var stream = ""
      stream += "{@(" + String(spanLength) + "),"
      if node.key.isEmpty {
        stream += node.description
      } else {
        stream += "null"
      }
      stream += "}"
      return stream
    }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.NodeAnchor {
  /// 將節锚陣列列印成一個字串。
  public var description: String {
    var arrOutputContent = [""]
    for anchor in self {
      arrOutputContent.append(anchor.description)
    }
    return arrOutputContent.joined(separator: "<-")
  }

  /// 從一個節錨陣列當中取出目前的自動選字字串陣列。
  public var values: [String] {
    map(\.node.currentPair.value)
  }

  /// 從一個節錨陣列當中取出目前的索引鍵陣列。
  public var keys: [String] {
    map(\.node.currentPair.key)
  }
}
