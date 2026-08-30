// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaTestsCartesianBudget

extension HomaTestsRoot {
  /// Phase 156（R1）笛卡爾積防禦精化相關的組字測試。
  ///
  /// 過往的防禦是「窗內任一鍵有多讀音 → 直接將 maxSegLength 縮減為 4」，
  /// 導致全拼長詞（>4 音節）永遠無法在單一節點組出。
  /// 精化後改以「窗內各鍵讀音數的乘積」判斷，乘積超過預算（625）才縮減，
  /// 讓免聲調的 4 音節組合（5⁴ = 625）得以整詞組出，同時保留 5 音節以上的防禦。
  @Suite(.serialized)
  public struct HomaTestsCartesianBudget: HomaTestSuite {
    /// 免聲調 4 音節（每鍵 5 個聲調桶、乘積 625 ≤ 625）：
    /// 不觸發縮減，四字詞得以在單一節點組出（P167 實測校準點：末代 Intel 上
    /// 4,000 仍卡頓、625 順暢——預算即「最長四字 × 每字五讀音」）。
    @Test("[Homa] CartesianBudget_ToneFreeFourSyllableAssemblesAsOneSegment")
    func testToneFreeFourSyllableAssemblesAsOneSegment() async throws {
      let variantLetters = ["a", "b", "c", "d", "e"]
      var mockData = "K1a-K2a-K3a-K4a 筆墨紙硯 -1.0\n"
      for index in 1 ... 4 {
        for letter in variantLetters {
          mockData += "K\(index)\(letter) 硯 -5.0\n"
        }
      }
      let mockLM = TestLM(rawData: mockData)
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      let keys: [Homa.PossibleKey] = (1 ... 4).map { index in
        .multipleKeys(variantLetters.map { "K\(index)\($0)" })
      }
      try assembler.insertKeys(keys)
      let result = assembler.assemble().compactMap(\.value)
      #expect(result == ["筆墨紙硯"])
      #expect(assembler.assembledSentence.count == 1)
    }

    /// 全拼 7 音節（每鍵單一讀音、乘積 = 1）：長詞可在單一節點組出。
    /// 單元測試內嚴禁使用任何國號，故以「七見斷滅智論抄」為例。
    @Test("[Homa] CartesianBudget_FullSpelledSevenSyllableAssemblesAsOneSegment")
    func testFullSpelledSevenSyllableAssemblesAsOneSegment() async throws {
      var mockData = "K1-K2-K3-K4-K5-K6-K7 七見斷滅智論抄 -1.0\n"
      for index in 1 ... 7 {
        mockData += "K\(index) 斷 -5.0\n"
      }
      let mockLM = TestLM(rawData: mockData)
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      let keys: [Homa.PossibleKey] = (1 ... 7).map { .singleKey("K\($0)") }
      try assembler.insertKeys(keys)
      let result = assembler.assemble().compactMap(\.value)
      #expect(result == ["七見斷滅智論抄"])
      #expect(assembler.assembledSentence.count == 1)
    }

    /// 免聲調 6 音節（乘積 5⁶ = 15,625 > 625）：防禦仍生效，
    /// maxSegLength 縮減至 4、長詞無法在單一節點組出（此為避免笛卡爾積卡死的回歸防護）。
    @Test("[Homa] CartesianBudget_ToneFreeSixSyllableStaysSegmented")
    func testToneFreeSixSyllableStaysSegmented() async throws {
      let variantLetters = ["a", "b", "c", "d", "e"]
      var mockData = "K1a-K2a-K3a-K4a-K5a-K6a 六字組詞 -1.0\n"
      for index in 1 ... 6 {
        for letter in variantLetters {
          mockData += "K\(index)\(letter) 詞 -5.0\n"
        }
      }
      let mockLM = TestLM(rawData: mockData)
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) }
      )
      let keys: [Homa.PossibleKey] = (1 ... 6).map { index in
        .multipleKeys(variantLetters.map { "K\(index)\($0)" })
      }
      try assembler.insertKeys(keys)
      let result = assembler.assemble().compactMap(\.value)
      // 無法以單一節點組出，至少得切成兩個節點。
      #expect(result.count >= 2)
    }
  }
}
