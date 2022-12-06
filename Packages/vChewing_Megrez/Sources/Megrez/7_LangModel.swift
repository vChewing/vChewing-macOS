// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// 語言模組協定。
public protocol LangModelProtocol {
  /// 給定鍵陣列，讓語言模型找給一組單元圖陣列。
  func unigramsFor(keyArray: [String]) -> [Megrez.Unigram]
  /// 給定鍵陣列，確認是否有單元圖記錄在庫。
  func hasUnigramsFor(keyArray: [String]) -> Bool
}

extension Megrez.Compositor {
  /// 一個套殼語言模型，用來始終返回經過排序的單元圖。
  public class LangModelRanked: LangModelProtocol {
    private let langModel: LangModelProtocol
    /// 一個套殼語言模型，用來始終返回經過排序的單元圖。
    /// - Parameter withLM: 用來對接的語言模型。
    public init(withLM: LangModelProtocol) {
      langModel = withLM
    }

    /// 給定索引鍵，讓語言模型找給一組經過穩定排序的單元圖陣列。
    /// - Parameter key: 給定的索引鍵字串。
    /// - Returns: 對應的經過穩定排序的單元圖陣列。
    public func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
      langModel.unigramsFor(keyArray: keyArray).stableSorted { $0.score > $1.score }
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      langModel.hasUnigramsFor(keyArray: keyArray)
    }
  }
}

// MARK: - Stable Sort Extension

// Reference: https://stackoverflow.com/a/50545761/4162914

extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  fileprivate func stableSorted(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}
