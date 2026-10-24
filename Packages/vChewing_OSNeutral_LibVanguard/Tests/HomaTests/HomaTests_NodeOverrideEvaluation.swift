// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsRoot.HomaTests_NodeOverrideEvaluation

extension HomaTestsRoot {
  /// 節點覆寫型別在組句期間的語義。
  ///
  /// 與 `Yukuaki` 側的 `YukuakiNodeOverrideTests` 逐條對應：右文脈 DP 會對同一個節點以
  /// 多組前文反覆估值，故「得多少分」與「該選哪一條元圖」必須分開說清楚。兩引擎在這一層
  /// 若有分歧，Lexicon 倉庫組得出來的句子在輸入法裡就打不出來。
  struct HomaTests_NodeOverrideEvaluation: HomaTestSuite {
    /// 弱釘選（`withTopGramScore`）只把分數壓回 unigram 基線，**不得**改動當前選取。
    @Test("[Homa] Node Override: Weak Pin Keeps Selection")
    func testWeakPinKeepsSelection() throws {
      var node = Self.makeNode()
      let pinned = try node.selectOverrideGram(
        keyArray: ["ㄓㄜˋ"],
        value: "著",
        previous: "再",
        type: .withTopGramScore
      )
      let evaluation = node.evaluate(previous: "要")
      #expect(node.currentGram == pinned)
      #expect(evaluation.targetIndex == nil)
      // 分數仍是 unigram 基線（「這」的 −2.5），不是該 bigram 自己的 −1.0。
      #expect(abs(evaluation.score - -2.5) < 1e-6)
    }

    /// 強釘選（`withSpecified`）在**沒有前文**時仍取覆寫分數。
    ///
    /// 組句的第一個節點永遠沒有前文；若該臂繞過覆寫狀態，被 POM 釘住的節點就會輸給其它路徑。
    @Test("[Homa] Node Override: Strong Pin Scores Without Previous")
    func testStrongPinScoresWithoutPrevious() throws {
      var node = Self.makeNode()
      _ = try node.selectOverrideGram(
        keyArray: ["ㄓㄜˋ"],
        value: "著",
        previous: "再",
        type: .withSpecified
      )
      let evaluation = node.evaluate(previous: nil)
      #expect(evaluation.targetIndex == nil)
      #expect(abs(evaluation.score - node.overridingScore) < 1e-6)
      #expect(node.currentGram?.current == "著")
    }

    /// 一條「單讀音、兩條元圖」的節點：「這」（單元圖 −2.5）與「著」（`再` 之後的雙元圖、−1.0）。
    private static func makeNode() -> Homa.Node {
      Homa.Node(
        keyArray: ["ㄓㄜˋ"],
        grams: [
          .init(keyArray: ["ㄓㄜˋ"], current: "這", probability: -2.5),
          .init(keyArray: ["ㄓㄜˋ"], current: "著", previous: "再", probability: -1.0),
        ]
      )
    }
  }
}
