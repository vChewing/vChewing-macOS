// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing
@testable import Typewriter

// MARK: - FuriousTypingSegmentorTests

/// 狂拼切分器的純函式單元測試：以小型音節表閉包注入，不依賴任何 LM／Tekkon 實體。
@Suite("FuriousTypingSegmentorTests")
struct FuriousTypingSegmentorTests {
  // MARK: Internal

  /// 歧義案例「fangan」：fang|an 與 fan|gan 皆為兩音節切分，應同時被列舉；
  /// 同音節數約束生效——請求 1 或 3 音節時不得回傳任何切分。
  @Test
  func testAmbiguousFangan() {
    let segmentor = makeSegmentor()
    let twoSyllable = segmentor.candidateSegmentations(of: "fangan", syllableCount: 2)
    #expect(twoSyllable.contains(["fang", "an"]))
    #expect(twoSyllable.contains(["fan", "gan"]))
    #expect(twoSyllable.count == 2)
    // 跨音節數的切分被過濾：無 1 或 3 音節的合法切分。
    #expect(segmentor.candidateSegmentations(of: "fangan", syllableCount: 1).isEmpty)
    #expect(segmentor.candidateSegmentations(of: "fangan", syllableCount: 3).isEmpty)
  }

  /// 「xian」存在 1 音節（xian）與 2 音節（xi|an）兩種切分；
  /// 請求特定音節數時只回傳該數量的切分，不得混雜。
  @Test
  func testXianFiltersCrossSyllableCount() {
    let segmentor = makeSegmentor()
    let oneSyllable = segmentor.candidateSegmentations(of: "xian", syllableCount: 1)
    #expect(oneSyllable == [["xian"]])
    #expect(!oneSyllable.contains(["xi", "an"]))
    let twoSyllable = segmentor.candidateSegmentations(of: "xian", syllableCount: 2)
    #expect(twoSyllable == [["xi", "an"]])
    #expect(!twoSyllable.contains(["xian"]))
  }

  /// 非法音節不參與切分：「zh」不是完整音節，不得單獨成段；
  /// 「zhi」只能以 zhi 單段切分，不會產生 zh|i 之類的非法組合。
  @Test
  func testInvalidSyllableExcluded() {
    let segmentor = makeSegmentor()
    // 「zh」整體不是音節 → 無合法切分。
    #expect(segmentor.candidateSegmentations(of: "zh", syllableCount: 1).isEmpty)
    // 「zhi」只有 zhi 單段合法（zh 與 i 皆不在表內）。
    let zhi = segmentor.candidateSegmentations(of: "zhi", syllableCount: 1)
    #expect(zhi == [["zhi"]])
    #expect(segmentor.candidateSegmentations(of: "zhi", syllableCount: 2).isEmpty)
    // 含非法段的路徑不得混入任何結果。
    let fangan = segmentor.candidateSegmentations(of: "fangan", syllableCount: 2)
    #expect(!fangan.contains { $0.contains("zh") })
  }

  /// 分數較高的切分應排在前面（fan|gan 的 -6 高於 fang|an 的 -8）。
  @Test
  func testRankingBySyllableScore() {
    let segmentor = makeSegmentor()
    let candidates = segmentor.candidateSegmentations(of: "fangan", syllableCount: 2)
    #expect(candidates.first == ["fan", "gan"])
  }

  /// limit 截斷：請求 limit=1 時只回傳分數最高的一條。
  @Test
  func testLimitTruncation() {
    let segmentor = makeSegmentor()
    let candidates = segmentor.candidateSegmentations(of: "fangan", syllableCount: 2, limit: 1)
    #expect(candidates == [["fan", "gan"]])
  }

  // MARK: Private

  /// 小型音節表（值為音節級分數；「zh」刻意不在表內，以測試非法音節不參與切分）。
  private let syllableTable: [String: Double] = [
    "fang": -4.0, "an": -4.0, "fan": -3.0, "gan": -3.0,
    "xian": -4.0, "xi": -3.0, "yi": -3.0, "zhi": -4.0,
  ]

  private func makeSegmentor(maxSyllableLength: Int = 6) -> FuriousTypingSegmentor {
    let table = syllableTable
    return FuriousTypingSegmentor(
      isValidSyllable: { table[$0] != nil },
      syllableScore: { table[$0] ?? -12.0 },
      maxSyllableLength: maxSyllableLength
    )
  }
}
