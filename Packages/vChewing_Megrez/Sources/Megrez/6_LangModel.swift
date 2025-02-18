// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - LangModelProtocol

/// 語言模組協定。
public protocol LangModelProtocol {
  /// 給定索引鍵陣列，讓語言模型找給一組單元圖陣列。
  func unigramsFor(keyArray: [String]) -> [Megrez.Unigram]
  /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
  func hasUnigramsFor(keyArray: [String]) -> Bool
}
