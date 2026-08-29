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

// MARK: - POM 容錯查詢（.toneInsensitivePrefix，Phase 159 / S1-a）

private let tolerantNowTimeStamp: Double = 114_514 * 10_000
private let tolerantCapacity = 5
private let tolerantNullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMTestSuite.POMTolerantQueryTests

extension POMTestSuite {
  @Suite(.serialized)
  struct POMTolerantQueryTests {
    // MARK: Internal

    /// 容錯命中：query head 為無調形（狂拼聲調桶代表鍵）、記憶為具體調形。
    /// exact 模式下落空、容錯模式命中。
    @Test
    func testTolerant_ToneInsensitiveHeadHit() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(zai4,再)&(chuang4,創)&(shi4,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("zai4", "再"), ("chuang4", "創"), ("shi", "是")])
      let exact = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp
      )
      #expect(exact.isEmpty)
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.candidates.first?.value == "是")
    }

    /// 容錯命中（反向）：無調形記憶、帶調查詢。
    @Test
    func testTolerant_TonelessMemoryHitByTonedQuery() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(zai4,再)&(chuang4,創)&(shi,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("zai4", "再"), ("chuang4", "創"), ("shi4", "是")])
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.candidates.first?.value == "是")
    }

    /// head values 放寬：同讀音異字（十）也能召回記憶（是）——POM 修正用途。
    @Test
    func testTolerant_HeadValueRelaxedAllowsCorrection() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(zai4,再)&(chuang4,創)&(shi4,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("zai4", "再"), ("chuang4", "創"), ("shi4", "十")])
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.candidates.first?.value == "是")
    }

    /// 上下文 values 維持 exact：前後文不同 → 不命中。
    @Test
    func testTolerant_ContextValueMismatchRejected() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(zai4,再)&(chuang4,創)&(shi4,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("zai4", "在"), ("chuang4", "創"), ("shi4", "是")])
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.isEmpty)
    }

    /// 跨音節守衛：去聲調後仍須等值（ma ↔ mang 不誤配）。
    @Test
    func testTolerant_CrossSyllableGuard() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(ma,媽)&(mang,盲)", candidate: "盲"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("ma", "媽"), ("ma", "某")])
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 1, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.isEmpty)
    }

    /// `_` 前綴讀音（標點等）在容錯掃描中仍被忽略。
    @Test
    func testTolerant_UnderscoreReadingIgnored() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(_punctuation,，)&(shi4,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("shi4", "是")])
      let tolerant = pom.fetchSuggestion(
        assembledResult: grams, cursor: 0, timestamp: tolerantNowTimeStamp,
        matchMode: .toneInsensitivePrefix
      )
      #expect(tolerant.isEmpty)
    }

    /// 預設模式維持 .exact：無調形 head 在預設模式下不命中（現行行為零變更）。
    @Test
    func testTolerant_DefaultModeRemainsExact() {
      let pom = LMAssembly.LXPerceptor(capacity: tolerantCapacity, dataURL: tolerantNullURL)
      pom.memorizePerception(
        (ngramKey: "(zai4,再)&(chuang4,創)&(shi4,是)", candidate: "是"),
        timestamp: tolerantNowTimeStamp
      )
      let grams = makeAssembled([("zai4", "再"), ("chuang4", "創"), ("shi", "是")])
      let suggestion = pom.fetchSuggestion(
        assembledResult: grams, cursor: 2, timestamp: tolerantNowTimeStamp
      )
      #expect(suggestion.isEmpty)
    }

    // MARK: Private

    private func makeAssembled(_ pairs: [(key: String, value: String)]) -> [Homa.GramInPath] {
      pairs.map { pair in
        .init(
          gram: .init(keyArray: [pair.key], current: pair.value, probability: -1),
          isExplicit: false
        )
      }
    }
  }
}
