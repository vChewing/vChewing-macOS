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

  /// 跨音節數枚舉（R3-b）：`syllableCount: nil` 時回傳不同音節數的切分並列——
  /// 「xian」同時有 1 音節（xian）與 2 音節（xi|an）；「fangan」只有 2 音節切分
  /// （無 1 音節合法切分）。不同音節數候選的公平比較（每音節平均分）由呼叫方
  /// （重切分）負責，本結構體只負責枚舉與按總分排序。
  @Test
  func testCrossSyllableCountEnumeration() {
    let segmentor = makeSegmentor()
    // 「xian」：1 音節與 2 音節切分並列（xian -4 高於 xi+an -6，故 xian 在前）。
    let xian = segmentor.candidateSegmentations(of: "xian", syllableCount: nil)
    #expect(xian.contains(["xian"]))
    #expect(xian.contains(["xi", "an"]))
    #expect(xian.first == ["xian"])
    // 「fangan」：無 1 音節合法切分；2 音節切分皆在列（fan+gan -6 高於 fang+an -8）。
    let fangan = segmentor.candidateSegmentations(of: "fangan", syllableCount: nil)
    #expect(fangan.contains(["fan", "gan"]))
    #expect(fangan.contains(["fang", "an"]))
    #expect(fangan.first == ["fan", "gan"])
    // 指定音節數時的行為不變（既有語義）。
    #expect(segmentor.candidateSegmentations(of: "xian", syllableCount: 1) == [["xian"]])
  }

  /// 簡拼感知枚舉（R3-a）：`isValidSyllable` 接受「完整音節 OR 合法簡拼前綴」後，
  /// 段切分器可枚舉含簡拼段的切分；簡拼段的分數（α 整詞查詢注入）參與排序。
  @Test
  func testAbbreviationAwareEnumeration() {
    // 完整音節表（同 makeSegmentor）＋簡拼前綴段表（值為注入的 α 整詞查詢分數）。
    let abbreviationScores: [String: Double] = ["y": -1.0, "s": -1.0, "x": -1.0, "b": -1.0]
    let segmentor = FuriousTypingSegmentor(
      isValidSyllable: { syllableTable[$0] != nil || abbreviationScores[$0] != nil },
      syllableScore: { syllableTable[$0] ?? abbreviationScores[$0] ?? -12.0 },
      maxSyllableLength: 6
    )
    // 「ysxb」無完整音節切分；簡拼感知後整段切成 4 個簡拼段（每位置一個 initial 前綴）。
    let abbreviated = segmentor.candidateSegmentations(of: "ysxb", syllableCount: nil)
    #expect(abbreviated == [["y", "s", "x", "b"]])
    // 混合場景：「xian」除完整音節切分外，也可切出含簡拼段 x 的「x|ian」
    // （x -1 + ian -4 = -5，介於 xian -4 與 xi+an -6 之間）。
    let tableWithIan = syllableTable.merging(["ian": -4.0]) { _, new in new }
    let mixed = FuriousTypingSegmentor(
      isValidSyllable: { tableWithIan[$0] != nil || abbreviationScores[$0] != nil },
      syllableScore: { tableWithIan[$0] ?? abbreviationScores[$0] ?? -12.0 },
      maxSyllableLength: 6
    )
    let candidates = mixed.candidateSegmentations(of: "xian", syllableCount: nil)
    #expect(candidates.contains(["x", "ian"]))
    #expect(candidates.first == ["xian"]) // 完整音節匹配優先（分數最高者在前）。
    #expect(candidates.firstIndex(of: ["x", "ian"])! < candidates.firstIndex(of: ["xi", "an"])!)
    // 簡拼感知不影響既有「完整音節閉包」的行為（zh 仍非合法段）。
    let plain = makeSegmentor()
    #expect(plain.candidateSegmentations(of: "zh", syllableCount: nil).isEmpty)
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
