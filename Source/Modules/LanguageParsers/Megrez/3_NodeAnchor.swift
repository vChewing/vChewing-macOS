// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
