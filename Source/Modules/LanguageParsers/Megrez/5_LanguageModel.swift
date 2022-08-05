// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

public protocol LangModelProtocol {
  /// 給定鍵，讓語言模型找給一組單元圖陣列。
  func unigramsFor(key: String) -> [Megrez.Unigram]

  /// 給定當前鍵與前述鍵，讓語言模型找給一組雙元圖陣列。
  func bigramsFor(precedingKey: String, key: String) -> [Megrez.Bigram]

  /// 給定鍵，確認是否有單元圖記錄在庫。
  func hasUnigramsFor(key: String) -> Bool
}

extension Megrez {
  /// 語言模型框架，回頭實際使用時需要派生一個型別、且重寫相關函式。
  open class LangModel: LangModelProtocol {
    public init() {}

    // 這裡寫了一點假內容，不然有些 Swift 格式化工具會破壞掉函式的參數設計。

    /// 給定鍵，讓語言模型找給一組單元圖陣列。
    open func unigramsFor(key: String) -> [Megrez.Unigram] {
      key.isEmpty ? [Megrez.Unigram]() : [Megrez.Unigram]()
    }

    /// 給定當前鍵與前述鍵，讓語言模型找給一組雙元圖陣列。
    open func bigramsFor(precedingKey: String, key: String) -> [Megrez.Bigram] {
      precedingKey == key ? [Megrez.Bigram]() : [Megrez.Bigram]()
    }

    /// 給定鍵，確認是否有單元圖記錄在庫。
    open func hasUnigramsFor(key: String) -> Bool {
      key.count != 0
    }
  }
}
