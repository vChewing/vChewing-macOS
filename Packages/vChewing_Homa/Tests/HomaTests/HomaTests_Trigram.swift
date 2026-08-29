// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsRoot.HomaTests_Trigram

extension HomaTestsRoot {
  /// 三元語法（trigram）支援測試（Phase 161 / S3）。
  /// 語料格式：`讀音 詞值 權重 [previous] [anterior]`。
  struct HomaTests_Trigram: HomaTestSuite {
    /// 三元圖命中：前驅二位（甲＋乙）匹配時，三元圖權重壓過既有最佳單元圖（餅）→ 選「丙」。
    @Test("Trigram Path Selection")
    func testTrigramPathSelection() throws {
      let mockLM = TestLM(rawData: """
      ㄐㄧㄚˇ 甲 -1
      ㄧˇ 乙 -1
      ㄅㄧㄥˇ 餅 -1
      ㄅㄧㄥˇ 丙 -3
      ㄅㄧㄥˇ 丙 -0.5 乙 甲
      """)
      let assembler = Homa.Assembler(gramQuerier: { mockLM.queryGrams($0) })
      try ["ㄐㄧㄚˇ", "ㄧˇ", "ㄅㄧㄥˇ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["甲", "乙", "丙"])
    }

    /// 三元圖前驅二位不匹配（anterior 為「義」而非「甲」）時退回單元圖 → 選「餅」。
    @Test("Trigram Anterior Mismatch Falls Back")
    func testTrigramAnteriorMismatchFallsBack() throws {
      let mockLM = TestLM(rawData: """
      ㄧˋ 義 -1
      ㄧˇ 乙 -1
      ㄅㄧㄥˇ 餅 -1
      ㄅㄧㄥˇ 丙 -0.5 乙 甲
      """)
      let assembler = Homa.Assembler(gramQuerier: { mockLM.queryGrams($0) })
      try ["ㄧˋ", "ㄧˇ", "ㄅㄧㄥˇ"].forEach { try assembler.insertKey($0) }
      let assembled = assembler.assemble()
      print("DBG values:", assembled.values)
      print("DBG prev:", assembled.map { $0.gram.previous ?? "nil" })
      print("DBG ante:", assembled.map { $0.gram.anterior ?? "nil" })
      #expect(assembled.values == ["義", "乙", "餅"])
    }

    /// 三元圖不得現身選字窗（previous／anterior 非 nil 的 grams 被既有排除機制隔離）。
    @Test("Trigram Excluded From Candidate Window")
    func testTrigramExcludedFromCandidateWindow() throws {
      let mockLM = TestLM(rawData: """
      ㄅㄧㄥˇ 餅 -1
      ㄅㄧㄥˇ 丙 -0.5 乙 甲
      """)
      let assembler = Homa.Assembler(gramQuerier: { mockLM.queryGrams($0) })
      try assembler.insertKey("ㄅㄧㄥˇ")
      let candidates = assembler.fetchCandidates(filter: .endAt).map(\.pair.value)
      #expect(candidates.contains("餅"))
      #expect(!candidates.contains("丙")) // 三元圖不出現在選字窗。
    }
  }
}
