// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsRoot.HomaTests_ContextualGrams

extension HomaTestsRoot {
  /// 語境加分（bigram／trigram）與上下文鞏固之互動。
  ///
  /// 兩支靶各釘住一個機制：
  /// - `testContextualBonusIsRecomputedByEveryAssembly`：語境加分是**當次推導**之結果，
  ///   不得於命中時把節點記成覆寫狀態——否則同一組鍵再組一次時加分不再重算、結果與分數
  ///   皆會漂移（`assemble()` 因此不冪等）。
  /// - `testConsolidationKeepsWordNodesOutsideOverrideRange`：上下文鞏固為保全節點內其餘各鍵
  ///   之值而拆開節點時，覆寫範圍**以外**之連續鍵仍須併回單一節點（辭典內有該詞時），
  ///   詞界不得因保全值而消失。
  struct HomaTests_ContextualGrams: HomaTestSuite {
    /// 甲、乙、丙三鍵：丙另有「乙＋甲」之二位前驅三元圖（權重高於其單元圖）。
    /// 「乙丙」為雙鍵詞，其權重足以在**無**語境加分時勝過「甲＋乙＋丙」。
    @Test("[Homa] Contextual Bonus Is Recomputed By Every Assembly")
    func testContextualBonusIsRecomputedByEveryAssembly() throws {
      let mockLX = TestLX(rawData: """
      ㄐㄧㄚˇ 甲 -5
      ㄧˇ 乙 -5
      ㄅㄧㄥˇ 丙 -5
      ㄧˇ-ㄅㄧㄥˇ 乙丙 -9
      ㄅㄧㄥˇ 丙 -0.5 乙 甲
      """)
      let assembler = Homa.Assembler(gramQuerier: { mockLX.queryGrams($0) })
      try ["ㄐㄧㄚˇ", "ㄧˇ", "ㄅㄧㄥˇ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["甲", "乙", "丙"])
      let firstScore = assembler.mostRecentPathScore
      // 同一組鍵再組一次：加分須重算，故結果與分數皆不變。
      #expect(assembler.assemble().values == ["甲", "乙", "丙"])
      #expect(assembler.mostRecentPathScore == firstScore)
    }

    /// 上下文鞏固：於「檔案室」之末鍵選「是」時，覆寫範圍以外之「ㄉㄤˇ ㄢˋ」兩鍵
    /// 須併回「檔案」一個節點，而非拆成「檔」「案」。
    @Test("[Homa] Consolidation Keeps Word Nodes Outside Override Range")
    func testConsolidationKeepsWordNodesOutsideOverrideRange() throws {
      // 權重逐筆取自出貨語料庫（`vChewing-VanguardLexicon/Build/Release/tsv/data-v4.8.5.txt`）。
      let mockLX = TestLX(rawData: """
      ㄉㄤˇ 黨 -5.120
      ㄉㄤˇ 檔 -5.185
      ㄢˋ 案 -5.108
      ㄕˋ 是 -5.004
      ㄕˋ 室 -5.164
      ㄉㄤˇ-ㄢˋ 檔案 -4.234
      ㄉㄤˇ-ㄢˋ-ㄕˋ 檔案室 -5.856
      """)
      let assembler = Homa.Assembler(gramQuerier: { mockLX.queryGrams($0) })
      try ["ㄉㄤˇ", "ㄢˋ", "ㄕˋ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["檔案室"])
      assembler.cursor = assembler.length

      let target = Homa.CandidatePair(keyArray: ["ㄕˋ"], value: "是")
      let cursorType = Homa.Assembler.CandidateCursor.placedFront
      try assembler.consolidateCandidateCursorContext(for: target, cursorType: cursorType)
      let logicalCursor = assembler.getLogicalCandidateCursorPosition(forCursor: cursorType)
      try assembler.overrideCandidate(
        target,
        at: logicalCursor,
        type: .withSpecified,
        isExplicitlyOverridden: true,
        enforceRetokenization: true
      )
      // 值之保全不變（檔、案、是），且詞界亦得保全（「檔案」為單一節點）。
      #expect(assembler.assembledSentence.map(\.value) == ["檔案", "是"])
      #expect(assembler.assembledSentence.map(\.keyArray) == [["ㄉㄤˇ", "ㄢˋ"], ["ㄕˋ"]])
    }
  }
}
