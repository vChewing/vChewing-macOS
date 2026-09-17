// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LexiconAssembly
@testable import LibVanguard
import Shared
import Tekkon
import Testing

// MARK: - NarrationTests

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: A) 防禦性注音轉換

  @Test
  func test_IH501_NarrationDefensivePinyinToBopomofo() throws {
    guard let testHandler else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
    let narrator = MockSpeechNarrator()
    narrator.reset()
    testHandler.narrator = narrator

    let typewriter = BPMFFullMatchTypewriter(testHandler)
    // 直接傳入拼音，驗證被轉換為注音
    typewriter.narrateTheComposer(
      narrator: narrator,
      with: "nian2",
      when: true
    )
    #expect(narrator.lastNarratedText == "ㄋㄧㄢˊ")

    narrator.reset()
    // 傳入無調拼音，驗證被轉換為注音且補上陰平記號
    typewriter.narrateTheComposer(
      narrator: narrator,
      with: "ni",
      when: true
    )
    #expect(narrator.lastNarratedText == "ㄋㄧˉ")

    narrator.reset()
    // 傳入注音，驗證不變
    typewriter.narrateTheComposer(
      narrator: narrator,
      with: "ㄋㄧㄢˊ",
      when: true
    )
    #expect(narrator.lastNarratedText == "ㄋㄧㄢˊ")
  }

  // MARK: B) 正常組字路徑改以 actualKeys

  @Test
  func test_IH502_NarrationUsesActualKeysOnComposition() throws {
    guard let testHandler else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.clear()
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
    let narrator = MockSpeechNarrator()
    narrator.reset()
    testHandler.narrator = narrator
    testHandler.prefs.readingNarrationCoverage = 1

    // 插入臨時語料，使「ni3」能成功組字
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你測", score: -1.0),
      isFiltering: false
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }

    // 輸入 "ni3"（ㄋㄧˇ）
    typeSentence("ni3")

    // 驗證組字器有內容
    #expect(!testHandler.assembler.isEmpty)
    // 驗證朗讀被觸發且內容為注音（與 cursor 身前一筆的 actualKeys 一致）
    #expect(narrator.narrateCallCount == 1)
    let targetIndex = testHandler.assembler.cursor - 1
    let expectedKey = testHandler.assembler.actualKeys.indices.contains(targetIndex)
      ? testHandler.assembler.actualKeys[targetIndex] : nil
    #expect(narrator.lastNarratedText == expectedKey)
    #expect(narrator.lastNarratedText?.contains("ㄋㄧ") == true)
  }

  // MARK: C) 後置聲調覆寫補朗讀

  @Test
  func test_IH503_RearIntonationOverrideTriggersNarration() throws {
    guard let testHandler else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.clear()
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
    let narrator = MockSpeechNarrator()
    narrator.reset()
    testHandler.narrator = narrator
    testHandler.prefs.readingNarrationCoverage = 1

    // 插入臨時語料：原始讀音與覆寫目標讀音皆需存在
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你測", score: -1.0),
      isFiltering: false
    )
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄋㄧˋ"], value: "逆測", score: -1.0),
      isFiltering: false
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }

    // 先輸入 "ni3"（ㄋㄧˇ -> 你測）
    typeSentence("ni3")
    #expect(!testHandler.assembler.isEmpty)
    let originalReading = testHandler.assembler.actualKeys.last
    #expect(originalReading?.contains("ㄋㄧ") == true)

    // 重置朗讀記錄
    narrator.reset()

    // 輸入聲調鍵 "4"（ˋ）觸發後置聲調覆寫
    // 此時 composer 已清空，輸入聲調鍵會嘗試覆寫游標身後的讀音
    typeSentence("4")

    // 驗證覆寫後有觸發朗讀
    #expect(narrator.narrateCallCount >= 1)
    // 驗證朗讀內容為注音（實際覆寫後的讀音）
    #expect(narrator.lastNarratedText?.contains("ㄋㄧ") == true)
  }

  // MARK: D) 後置聲調覆寫的內文提示抑制

  @Test
  func test_IH511_RearIntonationOverrideTooltipSuppression() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    // 插入臨時語料：原始讀音與覆寫目標讀音皆需存在。
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你測", score: -1.0),
      isFiltering: false
    )
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄋㄧˋ"], value: "逆測", score: -1.0),
      isFiltering: false
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }

    /// 重置組字器、回到「已組好一個字、注拼槽已空」的狀態。
    func prepareOverrideScenario() {
      testHandler.clear()
      testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
      typeSentence("ni3")
      #expect(testHandler.assembler.actualKeys.last?.contains("ㄋㄧ") == true)
    }

    // 預設（偏好關閉）：覆寫成功時，既有的內文提示照常顯示。
    prepareOverrideScenario()
    typeSentence("4")
    #expect(
      testSession.state.tooltip == "i18n:StateOfInputting.Tooltip.PreviousIntonationOverridden".i18n
    )
    #expect(testSession.state.tooltipDuration == 2)

    // 偏好開啟：覆寫照常生效，但不再附加該內文提示。
    testHandler.prefs.suppressTooltipForIntonationKeyOverrideEvents = true
    defer { testHandler.prefs.suppressTooltipForIntonationKeyOverrideEvents = false }

    prepareOverrideScenario()
    let readingBeforeOverride = testHandler.assembler.actualKeys.last
    typeSentence("4")
    #expect(testHandler.assembler.actualKeys.last != readingBeforeOverride)
    #expect(testSession.state.tooltip.isEmpty)
  }
}
