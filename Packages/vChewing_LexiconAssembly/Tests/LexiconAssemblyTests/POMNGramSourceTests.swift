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

@testable import LexiconAssembly

// MARK: - POM 記憶作為 Homa n-gram 統計來源（Phase 160 / S2；P182 起隨主開關）

@Suite(.serialized)
struct POMNGramSourceTests {
  /// 預設（鏡像 `kFetchSuggestionsFromPerceptionOverrideModel` 主開關）即注入：
  /// head 讀音命中記憶 → unigramsFor 注入帶 previous 的 bigram gram。
  @Test
  func testNGramSource_InjectsContextualGramsByDefault() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade() // fetchSuggestionsFromPerceptionOverrideModel 預設 true
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    guard let pomGram = grams.first(where: { $0.current == "媽" && $0.previous == "是" }) else {
      Issue.record("POM bigram gram not injected for head ㄇㄚ.")
      return
    }
    #expect(pomGram.probability < 0) // 衰減權重為負
  }

  /// 主開關關閉（fetch 鏡像 config=false）時，POM 不向組字引擎提供任何 n-gram 資料。
  @Test
  func testNGramSource_MasterSwitchOffDisablesFeeding() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.setOptions { $0.fetchSuggestionsFromPerceptionOverrideModel = false }
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(!grams.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// head 讀音需**逐段逐字等值、含聲調（含第一聲）**（引擎注入恆為具體讀音）：跨聲調記憶不得注入
  /// （「打『有』(ㄧㄡˇ) 出『右』(ㄧㄡˋ)」與「打ㄕㄥ 出 聖(ㄕㄥˋ)」類故障的根因——錯調 gram
  /// keyArray 與節點鍵不符，仍可能被 DP 以 reading-mismatch 選中）；同調記憶照常注入。
  /// 註：注音第一聲讀音字串無聲調記號（ㄇㄚ／ㄕㄥ），但屬具體讀音、非聲調桶——跨調記憶不得命中；
  /// 真正的聲調桶容錯見 `testNGramSource_BucketAlternativesKeepsCrossToneTolerance`。
  @Test
  func testNGramSource_ExactToneHeadMatchRequired() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄧㄡˋ,右)", candidate: "右"),
      timestamp: Date().timeIntervalSince1970
    )
    // 跨調查詢（ㄇㄚˋ／ㄧㄡˇ）：不得注入（媽=ㄇㄚ 一調、右=ㄧㄡˋ 四調）。
    #expect(!lxFacade.unigramsFor(keyArray: ["ㄇㄚˋ"]).contains { $0.current == "媽" && $0.previous == "是" })
    #expect(!lxFacade.unigramsFor(keyArray: ["ㄧㄡˇ"]).contains { $0.current == "右" && $0.previous == "是" })
    // 同調查詢（ㄇㄚ／ㄧㄡˋ）：照常注入（ㄇㄚ＝第一聲具體讀音、非無調桶）。
    #expect(lxFacade.unigramsFor(keyArray: ["ㄇㄚ"]).contains { $0.current == "媽" && $0.previous == "是" })
    #expect(lxFacade.unigramsFor(keyArray: ["ㄧㄡˋ"]).contains { $0.current == "右" && $0.previous == "是" })
    // 單鍵「ㄇㄚ」＝第一聲具體讀音：跨調記憶（麻＝ㄇㄚˊ）不得注入。
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚˊ,麻)", candidate: "麻"),
      timestamp: Date().timeIntervalSince1970
    )
    #expect(!lxFacade.unigramsFor(keyArray: ["ㄇㄚ"]).contains { $0.current == "麻" && $0.previous == "是" })
  }

  /// 第一聲（字串無聲調記號）單鍵查詢不得被跨聲調 contextual 記憶綁架（issue #610：
  /// 打「ㄕㄥ」組字預設變「聖(ㄕㄥˋ)」）。同調（ㄕㄥ）記憶照常注入。
  @Test
  func testNGramSource_FirstToneQueryRejectsCrossToneMemory() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.memorizePerception(
      (ngramKey: "(ㄏㄨㄛˊ,活)&(ㄕㄥˋ,聖)", candidate: "聖"),
      timestamp: Date().timeIntervalSince1970
    )
    // 單鍵 ㄕㄥ（第一聲）查詢：聖（ㄕㄥˋ）記憶不得注入。
    #expect(!lxFacade.unigramsFor(keyArray: ["ㄕㄥ"]).contains { $0.current == "聖" && $0.previous == "活" })
    // 對照：同調（ㄕㄥ）記憶照常注入。
    lxFacade.memorizePerception(
      (ngramKey: "(ㄏㄨㄛˊ,活)&(ㄕㄥ,甥)", candidate: "甥"),
      timestamp: Date().timeIntervalSince1970
    )
    #expect(lxFacade.unigramsFor(keyArray: ["ㄕㄥ"]).contains { $0.current == "甥" && $0.previous == "活" })
  }

  /// 聲調桶（`[Homa.PossibleKey]` alternatives）路徑：跨調記憶仍容錯注入——桶查詢本就不能釘定聲調
  /// （狂拼 trail／拼音無調擴桶依賴），由 alternatives 路徑顯式以去聲調等值進行、與單鍵嚴格並行。
  @Test
  func testNGramSource_BucketAlternativesKeepsCrossToneTolerance() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚˊ,麻)", candidate: "麻"),
      timestamp: Date().timeIntervalSince1970
    )
    let bucketQuery: [Homa.PossibleKey] = [
      .multipleKeys(["ㄇㄚ", "ㄇㄚˊ", "ㄇㄚˇ", "ㄇㄚˋ"]),
    ]
    #expect(
      lxFacade.unigramsFor(keyArray: bucketQuery, partiallyMatch: false)
        .contains { $0.current == "麻" && $0.previous == "是" }
    )
  }

  /// unigram 記憶（無前後文）不進入引擎 n-gram 餵入：bare gram 對 DP 無貢獻（節點
  /// unigramScore 取陣列首筆、不選中尾端注入），只會污染選字窗原始候選清單——故由
  /// OSNeutralAssembly 建議通道浮現（受 fetch／「以固定順序陳列」等把守）。驗證方式：記憶
  /// bare unigram 前後，unigramsFor 回傳內容必須完全一致（同讀音字元可能本已存在於
  /// 內建詞庫，因此以「前後等值」而非「不含該字」斷言）。
  @Test
  func testNGramSource_UnigramMemoryStaysOutOfEngineFeed() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    let gramsBefore = lxFacade.unigramsFor(keyArray: ["ㄈㄤ"])
    lxFacade.memorizePerception(
      (ngramKey: "()&(ㄈㄤ,芳)", candidate: "芳"),
      timestamp: Date().timeIntervalSince1970
    )
    let gramsAfter = lxFacade.unigramsFor(keyArray: ["ㄈㄤ"])
    #expect(gramsAfter == gramsBefore) // bare unigram 記憶不改變引擎回傳內容。
    // 對照：帶前後文（previous）的記憶仍照常餵入（contextual n-gram 語義）。
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams2 = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(grams2.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// 錯位記憶（候選字數 ≠ head 讀音段數，如「體式」記在單 ㄕˊ 下）不得餵入引擎——
  /// 否則單鍵輸入會被錯位記憶綁架（客訴「打時出體式」）。
  @Test
  func testNGramSource_MisalignedCandidateNotFed() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.memorizePerception(
      (ngramKey: "(ㄊㄧˇ,體)&(ㄕˊ,體式)", candidate: "體式"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lxFacade.unigramsFor(keyArray: ["ㄕˊ"])
    #expect(!grams.contains { $0.current == "體式" && $0.previous == "體" })
    // 對照：等長候選（時）照常注入。
    lxFacade.memorizePerception(
      (ngramKey: "(ㄊㄧˇ,體)&(ㄕˊ,時)", candidate: "時"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams2 = lxFacade.unigramsFor(keyArray: ["ㄕˊ"])
    #expect(grams2.contains { $0.current == "時" && $0.previous == "體" })
  }

  /// 快取指紋納入 POM 世代：記憶更新後查詢即反映新記憶。
  @Test
  func testNGramSource_CacheFingerprintTracksPOMGeneration() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    // 首次查詢（建立快取）。
    #expect(lxFacade.unigramsFor(keyArray: ["ㄇㄚ"]).contains { $0.current == "媽" })
    // 追加第二筆記憶（世代遞增→快取失效）。
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,麻)", candidate: "麻"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    #expect(grams.contains { $0.current == "媽" && $0.previous == "是" })
    #expect(grams.contains { $0.current == "麻" && $0.previous == "是" })
  }
}
