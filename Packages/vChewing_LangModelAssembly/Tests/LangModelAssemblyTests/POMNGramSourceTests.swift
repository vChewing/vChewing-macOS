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

// MARK: - POM 記憶作為 bigram 統計來源（Phase 160 / S2）

@Suite(.serialized)
struct POMNGramSourceTests {
  /// 開關開啟時：head 讀音命中記憶 → unigramsFor 注入帶 previous 的 bigram gram。
  @Test
  func testNGramSource_InjectsBigramGramsWhenEnabled() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    lmi.setOptions { $0.pomAsNGramSourceEnabled = true }
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

  /// 開關預設關閉：記憶存在但不注入（現行行為逐位元組一致）。
  @Test
  func testNGramSource_DisabledByDefault() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator() // pomAsNGramSourceEnabled 預設 false
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
    lmi.setOptions { $0.pomAsNGramSourceEnabled = true }
    lmi.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let grams = lmi.unigramsFor(keyArray: ["ㄇㄚˋ"]) // 帶調查詢
    #expect(grams.contains { $0.current == "媽" && $0.previous == "是" })
  }

  /// 快取指紋納入 POM 世代：記憶更新後查詢即反映新記憶。
  @Test
  func testNGramSource_CacheFingerprintTracksPOMGeneration() {
    defer { LMAssembly.LMInstantiator.disconnectFactoryDictionary() }
    let lmi = LMAssembly.LMInstantiator()
    lmi.setOptions { $0.pomAsNGramSourceEnabled = true }
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
