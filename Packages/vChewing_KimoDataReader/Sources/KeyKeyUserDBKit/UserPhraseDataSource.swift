// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - KeyKeyUserDBKit.UserPhraseDataSource

extension KeyKeyUserDBKit {
  /// 使用者詞庫資料來源協定
  ///
  /// 此協定定義了讀取使用者詞庫資料的通用介面，
  /// 可由資料庫 (`UserDatabase`) 或文字檔案 (`UserPhraseTextFileObj`) 實作。
  public protocol UserPhraseDataSource: Sequence where Element == Gram {
    /// 候選字覆蓋記錄的預設權重
    static var candidateOverrideProbability: Double { get }

    /// 讀取所有使用者單元圖
    /// - Returns: 單元圖陣列
    /// - Throws: 讀取過程中發生的錯誤
    func fetchUnigrams() throws -> [Gram]

    /// 讀取使用者雙元圖快取
    /// - Parameter limit: 限制回傳筆數 (nil 表示全部)
    /// - Returns: 雙元圖陣列
    /// - Throws: 讀取過程中發生的錯誤
    func fetchBigrams(limit: Int?) throws -> [Gram]

    /// 讀取候選字覆蓋快取
    /// - Returns: 候選字覆蓋陣列
    /// - Throws: 讀取過程中發生的錯誤
    func fetchCandidateOverrides() throws -> [Gram]

    /// 讀取所有使用者資料，回傳包含所有 Unigram、Bigram 和 CandidateOverride 的陣列
    /// - Returns: 包含所有結果的 `[Gram]` 陣列
    /// - Throws: 讀取過程中發生的錯誤
    func fetchAllGrams() throws -> [Gram]
  }
}

// MARK: - Default Implementation

extension KeyKeyUserDBKit.UserPhraseDataSource {
  /// 預設實作：讀取所有使用者資料
  public func fetchAllGrams() throws -> [KeyKeyUserDBKit.Gram] {
    var allGrams: [KeyKeyUserDBKit.Gram] = []
    allGrams.append(contentsOf: try fetchUnigrams())
    allGrams.append(contentsOf: try fetchBigrams(limit: nil))
    allGrams.append(contentsOf: try fetchCandidateOverrides())
    return allGrams
  }
}
