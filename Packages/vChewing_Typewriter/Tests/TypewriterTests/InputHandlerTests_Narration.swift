// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import LangModelAssembly
import Shared
import Tekkon
import Testing
@testable import Typewriter

// MARK: - NarrationTests

extension InputHandlerTests {
  // MARK: A) 防禦性注音轉換

  @Test
  func testNarrationDefensivePinyinToBopomofo() throws {
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
  func testNarrationUsesActualKeysOnComposition() throws {
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
  func testRearIntonationOverrideTriggersNarration() throws {
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
}
