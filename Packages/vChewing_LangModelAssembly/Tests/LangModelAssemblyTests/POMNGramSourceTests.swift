// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import Testing

@testable import LangModelAssembly

// MARK: - POM 記憶作為 Homa n-gram 統計來源（Phase 160 / S2；P182 起隨主開關）

@Suite(.serialized)
struct POMNGramSourceTests {
  /// 預設（鏡像 `kFetchSuggestionsFromPerceptionOverrideModel` 主開關）即注入：
  /// head 讀音命中記憶 → unigramsFor 注入帶 previous 的 bigram gram。
  @Test
  func testNGramSource_InjectsContextualGramsByDefault() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator() // fetchSuggestionsFromPerceptionOverrideModel 預設 true
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lmi.unigramsFor(keyArray: ["ㄇㄚ"])
    guard let pomGram = grams.first(where: { $0.current == "媽" && $0.previous == "是" }) else {
      Issue.record("POM bigram gram not injected for head ㄇㄚ.")
      return
    }
    #expect(pomGram.probability < 0) // 衰減權重為負
  }

  /// 主開關關閉（fetch 鏡像 config=false）時，POM 不向組字引擎提供任何 n-gram 資料。
  @Test
  func testNGramSource_MasterSwitchOffDisablesFeeding() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    lmi.setOptions { $0.fetchSuggestionsFromPerceptionOverrideModel = false }
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lmi.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(!grams.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// head 讀音容錯（逐段去聲調等值）：無調形記憶命中帶調查詢。
  @Test
  func testNGramSource_ToneInsensitiveHeadMatch() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lmi.unigramsFor(keyArray: ["ㄇㄚˋ"]) // 帶調查詢
    #expect(grams.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// unigram 記憶（無前後文）不進入引擎 n-gram 餵入：bare gram 對 DP 無貢獻（節點
  /// unigramScore 取陣列首筆、不選中尾端注入），只會污染選字窗原始候選清單——故由
  /// Typewriter 建議通道浮現（受 fetch／「以固定順序陳列」等把守）。驗證方式：記憶
  /// bare unigram 前後，unigramsFor 回傳內容必須完全一致（同讀音字元可能本已存在於
  /// 內建詞庫，因此以「前後等值」而非「不含該字」斷言）。
  @Test
  func testNGramSource_UnigramMemoryStaysOutOfEngineFeed() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    let gramsBefore = lmi.unigramsFor(keyArray: ["ㄈㄤ"])
    lmi.memorizePerception(
      (ngramKey: "()&(ㄈㄤ,芳)", candidate: "芳"),
      timestamp: Date().timeIntervalSince1970
    )
    let gramsAfter = lmi.unigramsFor(keyArray: ["ㄈㄤ"])
    #expect(gramsAfter == gramsBefore) // bare unigram 記憶不改變引擎回傳內容。
    // 對照：帶前後文（previous）的記憶仍照常餵入（contextual n-gram 語義）。
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams2 = lmi.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(grams2.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// 快取指紋納入 POM 世代：記憶更新後查詢即反映新記憶。
  @Test
  func testNGramSource_CacheFingerprintTracksPOMGeneration() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    // 首次查詢（建立快取）。
    #expect(lmi.unigramsFor(keyArray: ["ㄇㄚ"]).contains { $0.current == "媽" })
    // 追加第二筆記憶（世代遞增→快取失效）。
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,麻)", candidate: "麻"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lmi.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(grams.contains { $0.current == "媽" && $0.previous == "是" })
    #expect(grams.contains { $0.current == "麻" && $0.previous == "是" })
  }
}
