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

@Suite("SimilarPhoneticRules")
struct SimilarPhoneticRulesTests {

  // MARK: - splitTone

  @Test("splitTone: 無聲調標記 → 視為一聲，tone = \"\"")
  func testSplitToneFirstTone() {
    let (base, tone) = SimilarPhoneticRules.splitTone("ㄘㄢ")
    #expect(base == "ㄘㄢ")
    #expect(tone == "")
  }

  @Test("splitTone: 帶 ˊ（二聲）")
  func testSplitToneSecondTone() {
    let (base, tone) = SimilarPhoneticRules.splitTone("ㄇㄡˊ")
    #expect(base == "ㄇㄡ")
    #expect(tone == "ˊ")
  }

  @Test("splitTone: 帶 ˇ（三聲）")
  func testSplitToneThirdTone() {
    let (base, tone) = SimilarPhoneticRules.splitTone("ㄎㄨˇ")
    #expect(base == "ㄎㄨ")
    #expect(tone == "ˇ")
  }

  @Test("splitTone: 帶 ˋ（四聲）")
  func testSplitToneFourthTone() {
    let (base, tone) = SimilarPhoneticRules.splitTone("ㄅㄛˋ")
    #expect(base == "ㄅㄛ")
    #expect(tone == "ˋ")
  }

  @Test("splitTone: 帶 ˙（輕聲）")
  func testSplitToneLightTone() {
    let (base, tone) = SimilarPhoneticRules.splitTone("ㄅㄛ˙")
    #expect(base == "ㄅㄛ")
    #expect(tone == "˙")
  }

  // MARK: - allReadings

  @Test("allReadings: ㄘㄢ → 五個聲調版本，ㄘㄢ 排第一")
  func testAllReadingsFirstTone() {
    let readings = SimilarPhoneticRules.allReadings(of: "ㄘㄢ")
    #expect(readings.first == "ㄘㄢ")
    #expect(readings.contains("ㄘㄢˊ"))
    #expect(readings.contains("ㄘㄢˇ"))
    #expect(readings.contains("ㄘㄢˋ"))
    #expect(readings.contains("ㄘㄢ˙"))
    #expect(readings.count == 5)
  }

  @Test("allReadings: ㄇㄡˊ → 五個，ㄇㄡˊ 排第一")
  func testAllReadingsSecondTone() {
    let readings = SimilarPhoneticRules.allReadings(of: "ㄇㄡˊ")
    #expect(readings.first == "ㄇㄡˊ")
    #expect(readings.contains("ㄇㄡ"))
    #expect(readings.count == 5)
  }

  // MARK: - nearVowelBase

  @Test("nearVowelBase: ㄇㄡ → ㄇㄛ (ㄡ↔ㄛ)")
  func testNearVowelMouMo() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄇㄡ") == "ㄇㄛ")
  }

  @Test("nearVowelBase: ㄇㄛ → ㄇㄡ (ㄛ↔ㄡ)")
  func testNearVowelMoMou() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄇㄛ") == "ㄇㄡ")
  }

  @Test("nearVowelBase: ㄙㄨㄣ → ㄙㄨㄥ (ㄨㄣ↔ㄨㄥ)")
  func testNearVowelSunSong() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄙㄨㄣ") == "ㄙㄨㄥ")
  }

  @Test("nearVowelBase: ㄧㄣ → ㄧㄥ (ㄧㄣ↔ㄧㄥ)")
  func testNearVowelYinYing() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄧㄣ") == "ㄧㄥ")
  }

  @Test("nearVowelBase: ㄘㄢ → ㄘㄤ (ㄢ↔ㄤ)")
  func testNearVowelCanCang() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄘㄢ") == "ㄘㄤ")
  }

  @Test("nearVowelBase: ㄅㄛ → nil (無韻母近音對)")
  func testNearVowelBoNil() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄅㄛ") == nil)
  }

  @Test("nearVowelBase: ㄦ → nil (無韻母對)")
  func testNearVowelErNil() {
    #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄦ") == nil)
  }

  // MARK: - nearConsonantBase

  @Test("nearConsonantBase: ㄘㄢ → ㄔㄢ (ㄘ↔ㄔ)")
  func testNearConsonantCanChan() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄘㄢ") == "ㄔㄢ")
  }

  @Test("nearConsonantBase: ㄙㄨㄣ → ㄕㄨㄣ (ㄙ↔ㄕ)")
  func testNearConsonantSunShun() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄙㄨㄣ") == "ㄕㄨㄣ")
  }

  @Test("nearConsonantBase: ㄍㄣ → ㄎㄣ (ㄍ↔ㄎ)")
  func testNearConsonantGenKen() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄍㄣ") == "ㄎㄣ")
  }

  @Test("nearConsonantBase: ㄎㄨ → ㄍㄨ (ㄎ↔ㄍ)")
  func testNearConsonantKuGu() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄎㄨ") == "ㄍㄨ")
  }

  @Test("nearConsonantBase: ㄦ → nil（零聲母無近音聲母）")
  func testNearConsonantErNil() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄦ") == nil)
  }

  @Test("nearConsonantBase: ㄅ 系列 → nil（ㄅ不在白名單）")
  func testNearConsonantBoNil() {
    #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄅㄛ") == nil)
  }
}
