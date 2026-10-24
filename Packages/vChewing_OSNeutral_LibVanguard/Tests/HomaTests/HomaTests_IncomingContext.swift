// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsRoot.HomaTests_IncomingContext

extension HomaTestsRoot {
  /// 右文脈（incoming context）對組句的影響。
  ///
  /// 「右文脈」＝組句當下的左文脈還不足以定案，必須等**右邊**的詞進來才知道該選哪個
  /// 同音詞。本 suite 與 `Yukuaki` 側的 `YukuakiIncomingContextTests` 逐條對應
  /// （同一組魔術數字、同一組鍵、同一組斷言），兩個引擎的組句結果必須逐字相同。
  ///
  /// 這三支測試若改回「只以位置為 DP 狀態」的舊演算法，第二支會失敗：「再」在「要」
  /// 後面就先輸給「在」而被砍掉，之後「這樣」帶來的雙元圖加成永遠沒機會生效。
  struct HomaTests_IncomingContext: HomaTestSuite {
    /// 甲案：`curr = [這*] // expecting prev = 在 by default`。
    ///
    /// 沒有任何 n-gram 資料時，「在」以單元圖機率勝出（−5.009 優於 −5.5）。
    @Test("[Homa] Incoming Context: Default Selection Without N-Grams")
    func testDefaultSelectionWithoutNGrams() throws {
      let assembler = Self.makeAssembler(withBigram: false, withTrigram: false)
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄌㄧˇ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["不", "要", "在", "這裡"])
      #expect(abs(assembler.mostRecentPathScore - -19.009) < 1e-6)
    }

    /// 乙案：`curr = 這樣 // expecting prev = 再`，靠雙元圖 B01「這樣|再」翻盤。
    ///
    /// B01 的可選窗口為 `(−4.709, −3.209)`：低於 −4.709 則扳不過「在」，高於 −3.209
    /// 則丙案的三元圖 T01 再怎麼加分也扳不回來（T01 亦不得為正）。
    @Test("[Homa] Incoming Context: Bigram Flips Earlier Same-Sounding Word")
    func testBigramFlipsEarlierSameSoundingWord() throws {
      let assembler = Self.makeAssembler(withTrigram: false)
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄧㄤˋ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["不", "要", "再", "這樣"])
      #expect(abs(assembler.mostRecentPathScore - -18.0) < 1e-6)
    }

    /// 乙案之負控：拿掉 B01 之後必須退回「在」，證明翻盤確係 B01 所致。
    @Test("[Homa] Incoming Context: Without Bigram Falls Back")
    func testWithoutBigramFallsBack() throws {
      let assembler = Self.makeAssembler(withBigram: false, withTrigram: false)
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄧㄤˋ"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["不", "要", "在", "這樣"])
    }

    /// 丙案：`curr = 的 while prev = 這樣 // expecting anterior = 在`。
    ///
    /// 三元圖 T01「的|這樣,在」把「在」扳回來；此案僅靠負控才具鑑別力
    /// （正斷言在舊演算法下亦成立，因為「在」是左文脈的局部最優）。
    ///
    /// 總分反映計分模型（P326）：`的` 節點以單元圖基線 −1.5 起算，T01 的增益
    /// （原始機率 −0.5，較基線高 1.0）按鏈長 3 計兩次 ⇒ 節點分數 −1.5 + 2.0 = +0.5，
    /// 總分因而由舊模型的 −19.209 提高 1.0 至 −18.209。
    @Test("[Homa] Incoming Context: Trigram Restores Earlier Same-Sounding Word")
    func testTrigramRestoresEarlierSameSoundingWord() throws {
      let assembler = Self.makeAssembler()
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄧㄤˋ", "ㄉㄜ˙"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["不", "要", "在", "這樣", "的"])
      #expect(abs(assembler.mostRecentPathScore - -18.209) < 1e-6)
    }

    /// 丙案之負控：拿掉 T01 之後必須退回「再」。
    @Test("[Homa] Incoming Context: Without Trigram Falls Back")
    func testWithoutTrigramFallsBack() throws {
      let assembler = Self.makeAssembler(withTrigram: false)
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄧㄤˋ", "ㄉㄜ˙"].forEach { try assembler.insertKey($0) }
      #expect(assembler.assemble().values == ["不", "要", "再", "這樣", "的"])
    }

    /// 重複組句不得漂移：語境加分只移動選取、不記成覆寫狀態。
    @Test("[Homa] Incoming Context: Assembly Is Idempotent")
    func testAssemblyIsIdempotent() throws {
      let assembler = Self.makeAssembler()
      try ["ㄅㄨˋ", "ㄧㄠˋ", "ㄗㄞˋ", "ㄓㄜˋ", "ㄧㄤˋ", "ㄉㄜ˙"].forEach { try assembler.insertKey($0) }
      let first = assembler.assemble().values
      let second = assembler.assemble().values
      let third = assembler.assemble().values
      #expect(second == first)
      #expect(third == second)
    }

    /// 計分模型（P326）：`baseline + (chainLength − 1) × (probability − baseline)`。
    ///
    /// - 雙元圖的結果恰為原始機率，與舊模型逐位元相同（既有語料的計分不會漂移）。
    /// - 三元圖把增益算兩次；四階以上再由鏈長自然外推。
    /// - 鏈長數的是「詞鏈」而非讀音：多音節詞的單元圖仍是 1。
    @Test("[Homa] Incoming Context: Chain-Length Weighting")
    func testChainLengthWeighting() throws {
      let baseline = -1.5
      func gram(previous: String?, anterior: String?, probability: Double) -> Homa.Gram {
        .init(
          keyArray: ["ㄉㄜ˙"],
          current: "的",
          previous: previous,
          anterior: anterior,
          probability: probability
        )
      }
      let unigram = gram(previous: nil, anterior: nil, probability: -1.5)
      let bigram = gram(previous: "這樣", anterior: nil, probability: -0.6)
      let trigram = gram(previous: "這樣", anterior: "在", probability: -0.5)
      #expect(unigram.chainLength == 1)
      #expect(bigram.chainLength == 2)
      #expect(trigram.chainLength == 3)
      #expect(abs(unigram.weightedScore(against: baseline) - -1.5) < 1e-9)
      #expect(abs(bigram.weightedScore(against: baseline) - -0.6) < 1e-9)
      #expect(abs(trigram.weightedScore(against: baseline) - 0.5) < 1e-9)
    }
  }
}

// MARK: - HomaTests_IncomingContext.MockLexicon

extension HomaTestsRoot.HomaTests_IncomingContext {
  /// 與 `YukuakiIncomingContextTests` 相同的 mock 辭典（權重皆為示範值、非語料統計）。
  private static func makeAssembler(
    withBigram: Bool = true,
    withTrigram: Bool = true
  )
    -> Homa.Assembler {
    var lines = [
      "ㄅㄨˋ 不 -4.5",
      "ㄧㄠˋ 要 -4.0",
      "ㄗㄞˋ 在 -5.009",
      "ㄗㄞˋ 再 -5.5",
      "ㄓㄜˋ 這 -2.5",
      "ㄧㄤˋ 樣 -5.0",
      "ㄌㄧˇ 裡 -5.2",
      "ㄓㄜˋ-ㄧㄤˋ 這樣 -5.2",
      "ㄓㄜˋ-ㄌㄧˇ 這裡 -5.5",
      "ㄉㄜ˙ 的 -1.5",
    ]
    if withBigram { lines.append("ㄓㄜˋ-ㄧㄤˋ 這樣 -4.0 再") }
    if withTrigram { lines.append("ㄉㄜ˙ 的 -0.5 這樣 在") }
    let mockLX = TestLX(rawData: lines.joined(separator: "\n"))
    return Homa.Assembler(gramQuerier: { mockLX.queryGrams($0) })
  }
}
