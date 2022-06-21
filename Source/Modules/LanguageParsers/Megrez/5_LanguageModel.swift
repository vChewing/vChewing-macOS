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

public protocol LanguageModelProtocol {
  /// 給定鍵，讓語言模型找給一組單元圖陣列。
  func unigramsFor(key: String) -> [Megrez.Unigram]

  /// 給定當前鍵與前述鍵，讓語言模型找給一組雙元圖陣列。
  func bigramsForKeys(precedingKey: String, key: String) -> [Megrez.Bigram]

  /// 給定鍵，確認是否有單元圖記錄在庫。
  func hasUnigramsFor(key: String) -> Bool
}

extension Megrez {
  /// 語言模型框架，回頭實際使用時需要派生一個型別、且重寫相關函式。
  open class LanguageModel: LanguageModelProtocol {
    public init() {}

    // 這裡寫了一點假內容，不然有些 Swift 格式化工具會破壞掉函式的參數設計。

    /// 給定鍵，讓語言模型找給一組單元圖陣列。
    open func unigramsFor(key: String) -> [Megrez.Unigram] {
      key.isEmpty ? [Megrez.Unigram]() : [Megrez.Unigram]()
    }

    /// 給定當前鍵與前述鍵，讓語言模型找給一組雙元圖陣列。
    open func bigramsForKeys(precedingKey: String, key: String) -> [Megrez.Bigram] {
      precedingKey == key ? [Megrez.Bigram]() : [Megrez.Bigram]()
    }

    /// 給定鍵，確認是否有單元圖記錄在庫。
    open func hasUnigramsFor(key: String) -> Bool {
      key.count != 0
    }
  }
}
