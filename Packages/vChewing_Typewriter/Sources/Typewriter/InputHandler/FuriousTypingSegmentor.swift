// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

/// 狂拼模式（Furious Typing Mode）的拼音字母流切分器。
///
/// 純函式設計：所有外部依賴（音節合法性判定、音節級分數）皆以閉包注入，
/// 不含任何 LM／Tekkon 具體型別，因此可以直接以小型音節表做單元測試。
/// 用途：把自動 chop 提交進組字器的拼音字母流重新枚舉成各種合法音節切分，
/// 供「語言模型引導的重切分」比較候選，藉此修正 greedy 最長匹配的邊界錯誤
/// （例如「fangan」被切為 fang|an，但使用者想要的是 fan|gan）。
public struct FuriousTypingSegmentor {
  // MARK: Lifecycle

  public init(
    isValidSyllable: @escaping (String) -> Bool,
    syllableScore: @escaping (String) -> Double,
    maxSyllableLength: Int = 6
  ) {
    self.isValidSyllable = isValidSyllable
    self.syllableScore = syllableScore
    self.maxSyllableLength = Swift.max(1, maxSyllableLength)
  }

  // MARK: Public

  /// 判定給定的字母串是否為完整音節。
  public var isValidSyllable: (String) -> Bool
  /// 給定音節的音節級分數（越高越佳）。無匹配的合法音節由呼叫方給定地板值。
  public var syllableScore: (String) -> Double
  /// 單個音節允許的最長字母數。
  public var maxSyllableLength: Int

  /// 枚舉給定字母流的所有合法音節切分，且僅保留總音節數等於 `syllableCount` 者。
  ///
  /// 以 DP／beam 進行：`dp[pos]` 記錄「到位置 pos 為止」的分數最高的前 `limit` 條路徑
  /// （blob 序列＋累加分數），轉移為往後取 1...maxSyllableLength 個字母且
  /// `isValidSyllable` 成立者。最終按分數降冪截取前 `limit` 條。
  /// - Parameters:
  ///   - letters: 待切分的拼音字母流。
  ///   - syllableCount: 只回傳總音節數等於此值的切分。
  ///   - limit: 每條 DP 路徑與最終結果的上限筆數。
  /// - Returns: 符合音節數約束的切分（blob 序列），按分數降冪排序。
  public func candidateSegmentations(
    of letters: String,
    syllableCount: Int,
    limit: Int = 8
  )
    -> [[String]] {
    let chars = Array(letters)
    let n = chars.count
    guard n > 0, syllableCount > 0, limit > 0 else { return [] }
    let safeLimit = Swift.max(1, limit)
    // dp[pos]：到位置 pos 為止的路徑，每位置僅保留分數最高的前 safeLimit 條。
    var dp = Array(repeating: [(blobs: [String], score: Double)](), count: n + 1)
    dp[0] = [([], 0)]
    for pos in 0 ..< n {
      guard !dp[pos].isEmpty else { continue }
      let maxLen = Swift.min(maxSyllableLength, n - pos)
      guard maxLen >= 1 else { continue }
      for length in 1 ... maxLen {
        let blob = String(chars[pos ..< pos + length])
        guard isValidSyllable(blob) else { continue }
        let blobScore = syllableScore(blob)
        for path in dp[pos] {
          let extended = (blobs: path.blobs + [blob], score: path.score + blobScore)
          keepTop(&dp[pos + length], entry: extended, limit: safeLimit)
        }
      }
    }
    let filtered = dp[n]
      .filter { $0.blobs.count == syllableCount }
      .sorted { $0.score > $1.score }
      .prefix(safeLimit)
    return filtered.map(\.blobs)
  }

  // MARK: Private

  /// 將條目插入陣列，陣列超過上限時只保留分數最高的前 `limit` 筆。
  private func keepTop(
    _ array: inout [(blobs: [String], score: Double)],
    entry: (blobs: [String], score: Double),
    limit: Int
  ) {
    array.append(entry)
    if array.count > limit {
      array.sort { $0.score > $1.score }
      array.removeLast(array.count - limit)
    }
  }
}
