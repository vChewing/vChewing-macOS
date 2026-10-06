// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard
@testable import Tekkon

// 狂拼（拼音狂打）之行為層測試：前方預覽、重切分、固化、copilot 候選窗、
// 簡拼整詞、以及固化後之漸退記憶套用。

// MARK: - IH.FuriousPinyin

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: - 狂拼模式（Furious Typing Mode）前方預覽

  /// 狂拼模式啟用時，注拼槽內尚未完成拼寫的拼音會以組字器副本（copilot）試算前方組句，
  /// 並將最有可能的結果即時顯示於組字區；原始拼音字母流則改以 Tooltip 顯示。
  @Test("IH-FuriousPinyin-001 Furious typing previews front reading")
  func test_IH_FuriousPinyin_001_FuriousTypingPreviewsFrontReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijiedaz」：前段自動 chop 提交（世測界測大測），注拼槽暫存「z」。
    typeSentence("shijiedaz")

    #expect(testHandler.assembler.keys.count == 3)
    #expect(testHandler.composer.romajiBuffer == "z")
    // 主組字器只有已提交的三個讀音，前方預覽不污染主組字器。
    #expect(generateDisplayedText() == "世測界測大測")
    // 前方預覽：暫存的「z」經 copilot 試算組句出「戰測」，即時顯示於組字區。
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "世測界測大測戰測")
    // 前方候選窗常駐顯示，且原始拼音字母流不再以 Tooltip 顯示（避免與候選窗重疊）。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.tooltip.isEmpty)
  }

  /// 狂拼模式關閉時（此處顯式停用，不再依賴預設值），注拼槽暫存的拼音維持原文顯示，既有行為不受影響。
  @Test("IH-FuriousPinyin-002 Furious typing disabled keeps raw pinyin display")
  func test_IH_FuriousPinyin_002_FuriousTypingDisabledKeepsRawPinyinDisplay() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 顯式停用狂拼（測試意圖為「關閉時」行為）。
    testHandler.currentLM.syncPrefs()

    typeSentence("shijiedaz")

    #expect(testHandler.assembler.keys.count == 3)
    // 狂拼模式關閉：前方維持原始拼音「z」顯示。
    #expect(testSession.state.displayedText == "世測界測大測z")
    #expect(testSession.state.tooltip.isEmpty)
  }

  /// 狂拼模式啟用時，Enter 先固化前方並停留 Inputting（不遞交）；
  /// 再按一次 Enter（注拼槽已空）才遞交「組字區內容＋前方預覽」。
  @Test("IH-FuriousPinyin-003 Furious typing Enter solidifies then commits previewed front")
  func test_IH_FuriousPinyin_003_FuriousTypingEnterSolidifiesThenCommitsPreviewedFront() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijiedaz")
    #expect(testSession.state.displayedText == "世測界測大測戰測")

    // 第一次 Enter：固化前方、停留 Inputting、不遞交。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
    // 第二次 Enter：注拼槽已空，遞交「組字區內容＋前方預覽」。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "世測界測大測戰測")
  }

  /// 狂拼模式啟用時，Inputting 狀態會常駐附掛前方候選清單：
  /// 置頂為 copilot 預覽猜測值「戰測」，其餘來自語言模組；狂拼關閉時不得附掛。
  @Test("IH-FuriousPinyin-004 Furious typing attaches front candidates")
  func test_IH_FuriousPinyin_004_FuriousTypingAttachesFrontCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijiedaz」：前段自動 chop 提交（世測界測大測），注拼槽暫存「z」。
    typeSentence("shijiedaz")

    #expect(testSession.state.type == .ofInputting)
    // 前方候選窗常駐顯示：候選清單非空、置頂為 copilot 預覽值「戰測」。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "戰測")
    // 其餘候選來自語言模組，且不得有空值。
    #expect(testSession.state.candidates.dropFirst().allSatisfy { !$0.value.isEmpty })
    #expect(testSession.state.candidates.count == (testHandler.furiousTypingFrontCandidates?.count ?? 0))

    // 狂拼關閉時不得附加候選（零行為差異）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.currentLM.syncPrefs()
    let stateSansFurious = testHandler.generateStateOfInputting()
    #expect(stateSansFurious.candidates.isEmpty)
  }

  /// 狂拼模式啟用時，Shift+選字鍵「1」就地選中置頂前方候選：
  /// 注拼槽清空、組字器尾端寫入對應讀音、組字區顯示「戰測」、狀態回到無候選的 Inputting。
  @Test("IH-FuriousPinyin-005 Furious typing Shift selection")
  func test_IH_FuriousPinyin_005_FuriousTypingShiftSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijiedaz")
    #expect(testSession.state.type == .ofInputting)
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "戰測")

    // 模擬候選窗已顯示（handleCandidate 需要 ctlCandidate.visible）。
    testSession.mockCandidateController = MockCandidateController(visible: true)

    // Shift+1（選字鍵「1」）選中置頂候選。
    let shift1 = KBEvent.KeyEventData(
      flags: .shift, chars: "!", charsSansModifiers: "1", keyCode: 18
    ).asEvent
    #expect(testHandler.triageInput(event: shift1))

    // 注拼槽已清空。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    // 組字器尾端插入對應讀音（3 個已提交讀音 + 1 個前方讀音位置）。
    #expect(testHandler.assembler.keys.count == 4)
    // 組字區顯示文字含「戰測」。
    #expect(generateDisplayedText().contains("戰測"))
    // 狀態回到無候選的 Inputting，且未發生任何遞交。
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.candidates.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 狂拼候選窗顯示中，不帶 Shift 的數字鍵仍走既有語義（聲調鍵處理），不觸發選字。
  @Test("IH-FuriousPinyin-006 Furious typing plain digit key keeps tone semantics")
  func test_IH_FuriousPinyin_006_FuriousTypingPlainDigitKeyKeepsToneSemantics() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijiedaz")
    #expect(testSession.state.type == .ofInputting)
    #expect(!testSession.state.candidates.isEmpty)

    // 模擬候選窗已顯示。
    testSession.mockCandidateController = MockCandidateController(visible: true)

    // 不帶 Shift 的「1」：走聲調/一般處理，不得觸發選字。
    let plain1 = KBEvent.KeyEventData(chars: "1", keyCode: 18).asEvent
    _ = testHandler.triageInput(event: plain1)

    // 未遞交任何內容。
    #expect(testSession.recentCommissions.isEmpty)
    // 置頂候選「戰測」未被寫入組字器（選字未觸發）。
    #expect(!testHandler.assembler.assembledSentence.values.joined().contains("戰測"))
    // 狀態仍是 Inputting。
    #expect(testSession.state.type == .ofInputting)
  }

  /// 逐字選字模式（SCPC）啟用時狂拼完全無效：預覽停用（維持原文拼音）、候選清單為空。
  @Test("IH-FuriousPinyin-007 SCPC forces furious typing inert")
  func test_IH_FuriousPinyin_007_SCPCForcesFuriousTypingInert() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.useSCPCTypingMode = true
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    testHandler.currentLM.syncPrefs()

    // 手動建構「shijiedaz」打完後的狀態：前段已提交、注拼槽暫存「z」。
    try? testHandler.assembler.insertKey(["ㄕˋ"])
    try? testHandler.assembler.insertKey(["ㄐㄧㄝˋ"])
    try? testHandler.assembler.insertKey(["ㄉㄚˋ"])
    testHandler.composer.replacePinyinBuffer(with: "z")
    let state = testHandler.generateStateOfInputting()

    // SCPC 啟用時狂拼完全無效：維持原文拼音「z」顯示、不附加候選。
    #expect(state.displayedText == "世測界測大測z")
    #expect(state.candidates.isEmpty)
  }

  // MARK: - 狂拼重切分（Furious Resegmentation）

  /// 狂拼模式：greedy chop 把「fangan」切成 fang|an 之後，語言模型引導的重切分
  /// 應把前方兩鍵換成 fan|gan 桶，使組句結果由「反感」勝出。
  @Test("IH-FuriousPinyin-008 Furious typing resegments fang an")
  func test_IH_FuriousPinyin_008_FuriousTypingResegmentsFangAn() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertFangAnResegmentationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「fanganz」：第一次 chop 提交 fang（暫存 a），第二次 chop 提交 an（暫存 z），
    // 隨後重切分把 trail 換成 fan|gan。
    typeSentence("fanganz")

    // trail 已被重切為 fan|gan。
    #expect(testHandler.furiousTrail == ["fan", "gan"])
    // 組字器尾端兩鍵變成 fan/gan 無調候選桶。
    #expect(testHandler.assembler.keys.count == 2)
    #expect(
      Array(testHandler.assembler.keys)
        == [
          .multipleKeys(furiousTestBucket(for: "ㄈㄢ")),
          .multipleKeys(furiousTestBucket(for: "ㄍㄢ")),
        ]
    )
    // 組句前方值為「反感」。
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["反感"])
    // 替換後路徑總分高於原地維持的 fang|an 切分。
    #expect(testHandler.assembler.mostRecentPathScore > -9)
  }

  /// 狂拼模式關閉時不記錄 trail、也不重切分：維持 greedy 的 fang|an 切分。
  @Test("IH-FuriousPinyin-009 Furious typing no resegmentation when disabled")
  func test_IH_FuriousPinyin_009_FuriousTypingNoResegmentationWhenDisabled() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertFangAnResegmentationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 顯式停用狂拼（測試意圖為「關閉時」行為）。
    testHandler.currentLM.syncPrefs()

    typeSentence("fanganz")

    // 無 trail、無重切：維持 fang|an 桶，組句不出現「反感」。
    #expect(testHandler.furiousTrail.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(
      Array(testHandler.assembler.keys)
        == [
          .multipleKeys(furiousTestBucket(for: "ㄈㄤ")),
          .multipleKeys(furiousTestBucket(for: "ㄢ")),
        ]
    )
    #expect(!testHandler.assembler.assembledSentence.map(\.value).contains("反感"))
  }

  /// BackSpace 在注拼槽為空時刪除組字器尾鍵：狂拼 trail 精確同步（pop 而非全清）。
  @Test("IH-FuriousPinyin-010 Furious trail pop on Backspace")
  func test_IH_FuriousPinyin_010_FuriousTrailPopOnBackspace() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertFangAnResegmentationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("fanganz")
    #expect(testHandler.furiousTrail == ["fan", "gan"])
    #expect(testHandler.composer.romajiBuffer == "z")

    // 第一次 BackSpace：注拼槽尚有「z」，只清注拼槽、不動組字器，trail 不變。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.furiousTrail == ["fan", "gan"])
    #expect(testHandler.assembler.keys.count == 2)

    // 第二次 BackSpace：注拼槽為空，刪除組字器尾鍵並同步 pop trail。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)
    #expect(testHandler.furiousTrail == ["fan"])
    #expect(testHandler.assembler.keys.count == 1)
  }

  /// 使用者顯式選字（consolidateNode）之後，狂拼 trail 失效（清空）。
  @Test("IH-FuriousPinyin-011 Furious trail invalidated by consolidate node")
  func test_IH_FuriousPinyin_011_FuriousTrailInvalidatedByConsolidateNode() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertFangAnResegmentationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("fanganz")
    #expect(testHandler.furiousTrail == ["fan", "gan"])

    // 選字（明確覆寫）之後 trail 必須失效，避免重切動到使用者確認過的內容。
    testHandler.consolidateNode(
      candidate: (keyArray: ["ㄈㄢˇ", "ㄍㄢˇ"], value: "反感"),
      respectCursorPushing: false,
      preConsolidate: false,
      skipObservation: true,
      explicitlyChosen: true
    )
    #expect(testHandler.furiousTrail.isEmpty)
  }

  // MARK: - 狂拼固化（Furious Solidification）

  /// 打「shijie」後（注拼槽暫存 jie、候選窗顯示中），按 Space：
  /// 前方讀音被固化進組字器（鍵數＋1、注拼槽清空、trail 尾筆為 jie），
  /// 且同一事件繼續走正常流程、開出正常選字窗，候選涵蓋跨邊界詞「世界」。
  @Test("IH-FuriousPinyin-012 Furious typing Space solidifies and opens candidate window")
  func test_IH_FuriousPinyin_012_FuriousTypingSpaceSolidifiesAndOpensCandidateWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 1 // Space 為選字窗呼叫鍵（預設值）。
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 在 'j' 提交 shi（注拼槽暫存 jie）。
    typeSentence("shijie")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(testHandler.furiousTrail == ["shi"])
    #expect(!testSession.state.candidates.isEmpty)

    // 按 Space：觸發鍵固化。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    // 固化完成：注拼槽清空、組字器尾端多一個讀音鍵。尾鍵維持整組聲調桶
    // （tone-fuzzy 保留——隨後選字窗仍陳列全調候選），顯示由真組字器組句
    // 決定（與 copilot 預覽同源；「世界」分數高於「世＋界」而勝出）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.assembler.keys.last == .multipleKeys(["ㄐㄧㄝ", "ㄐㄧㄝˊ", "ㄐㄧㄝˇ", "ㄐㄧㄝˋ", "ㄐㄧㄝ˙"]))
    #expect(generateDisplayedText() == "世界")
    // 空格固化（完整音節）累積 trail：auto-chop 的「shi」＋空格固化的「jie」。
    #expect(testHandler.furiousTrail == ["shi", "jie"])
    // 同一事件繼續走正常流程：開出正常選字窗，候選涵蓋跨邊界詞「世界」。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.contains { $0.value == "世界" })
  }

  /// 同前但按 Down 方向鍵（橫排時 Down＝isCursorClockLeft，正常流程會開選字窗）：
  /// 固化發生且後續為正常語義（候選窗涵蓋「世界」）。
  @Test("IH-FuriousPinyin-013 Furious typing down arrow solidifies and opens candidate window")
  func test_IH_FuriousPinyin_013_FuriousTypingDownArrowSolidifiesAndOpensCandidateWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 橫排（MockSession 預設 isVerticalTyping == false）：Down＝isCursorClockLeft。
    #expect(!testSession.isVerticalTyping)

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 按 Down：觸發鍵固化，同一事件開出正常選字窗。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    // 尾鍵維持聲調桶（tone-fuzzy 保留）；顯示由真組字器組句決定（同源於 copilot）。
    #expect(testHandler.assembler.keys.last == .multipleKeys(["ㄐㄧㄝ", "ㄐㄧㄝˊ", "ㄐㄧㄝˇ", "ㄐㄧㄝˋ", "ㄐㄧㄝ˙"]))
    #expect(generateDisplayedText() == "世界")
    // 空格固化（完整音節）累積 trail：auto-chop 的「shi」＋固化的「jie」。
    #expect(testHandler.furiousTrail == ["shi", "jie"])
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.contains { $0.value == "世界" })
  }

  /// 狂拼候選窗顯示中，字母鍵不走固化；Enter 固化前方並停留 Inputting（不遞交），
  /// 再按一次 Enter（注拼槽已空）才遞交全句。
  @Test("IH-FuriousPinyin-014 Furious typing letter key not solidified but Enter solidifies")
  func test_IH_FuriousPinyin_014_FuriousTypingLetterKeyNotSolidifiedButEnterSolidifies() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 字母鍵：不固化（不開候選窗）、維持既有 auto-chop 打字行為。
    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "a").asEvent)
    #expect(testSession.state.type == .ofInputting) // 未經固化＋開窗流程。
    #expect(testHandler.assembler.keys.count == 2) // 既有 auto-chop 提交 jie。
    #expect(testHandler.composer.romajiBuffer == "a")

    // Enter：固化前方、停留 Inputting、不遞交；再按一次 Enter 才遞交全句。
    testSession.switchState(IMEState.ofAbortion()) // 清空組字區與注拼槽，不遞交。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()
    typeSentence("shijie")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    // 第一次 Enter：固化前方（置頂候選語義＝只插聲調桶）、停留 Inputting。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(generateDisplayedText() == "世界")
    #expect(testSession.recentCommissions.isEmpty)
    // 第二次 Enter：注拼槽已空，遞交組字區全句「世界」。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions.joined() == "世界")
  }

  /// 狂拼候選窗顯示中，state 的 tooltip 被抑制（原文拼音不再以 tooltip 顯示）。
  @Test("IH-FuriousPinyin-015 Furious typing suppresses tooltip when candidates show")
  func test_IH_FuriousPinyin_015_FuriousTypingSuppressesTooltipWhenCandidatesShow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    // 候選窗顯示中：tooltip 為空（抑制）、candidates 非空、組字區仍顯示預覽。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.tooltip.isEmpty)
    #expect(!testSession.state.displayedText.isEmpty)
  }

  /// 不完整前綴（例如「z」）被固化：固化成功但 trail 失效（清空），無崩潰。
  @Test("IH-FuriousPinyin-016 Furious typing solidifying incomplete prefix invalidates trail")
  func test_IH_FuriousPinyin_016_FuriousTypingSolidifyingIncompletePrefixInvalidatesTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertFangAnResegmentationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「fanganz」：auto-chop 提交 fang／an，注拼槽暫存「z」（不完整前綴）。
    typeSentence("fanganz")
    #expect(testHandler.composer.romajiBuffer == "z")
    #expect(testHandler.furiousTrail == ["fan", "gan"])
    #expect(!testSession.state.candidates.isEmpty)

    // 按 Space：固化「z」前綴桶成功，但 trail 因不完整音節而失效。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 3) // 固化為前方新增一個讀音鍵。
    #expect(testHandler.furiousTrail.isEmpty) // 不完整前綴固化 → trail 失效。
  }

  // MARK: - 狂拼跨邊界候選與反查（Furious Cross-Boundary & Reverse Lookup）

  /// 打「shijie」時，copilot 候選窗須涵蓋跨邊界詞「世界」：
  /// 順序為置頂預覽之後、前方單音節候選之前，且全程按 value 去重。
  @Test("IH-FuriousPinyin-017 Furious typing candidates include cross-boundary word")
  func test_IH_FuriousPinyin_017_FuriousTypingCandidatesIncludeCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 提交 shi、注拼槽暫存 jie、copilot 候選窗顯示。
    typeSentence("shijie")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 置頂候選即為 copilot 的最佳猜測（含邊界文脈）「世界」，其後方無重複值。
    let values = testSession.state.candidates.map(\.value)
    #expect(testSession.state.candidates.first?.value == "世界")
    if let worldIndex = values.firstIndex(of: "世界") {
      #expect(worldIndex == 0) // 置頂。
    }
    // 全程按 value 去重（保留先出現者）。
    #expect(values.count == Set(values).count)
    // 置頂候選的 keyArray 為具體讀音（橫跨最後提交鍵＋前方的雙讀音）。
    #expect(testSession.state.candidates.first?.keyArray == ["ㄕˋ", "ㄐㄧㄝˋ"])
  }

  /// Shift+選字鍵選中跨邊界候選「世界」：注拼槽清空、組字器尾端雙鍵 span
  /// 被覆寫為單節點「世界」、trail 失效、狀態回到無候選的 Inputting。
  @Test("IH-FuriousPinyin-018 Furious typing Shift selection confirms cross-boundary word")
  func test_IH_FuriousPinyin_018_FuriousTypingShiftSelectionConfirmsCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.contains { $0.value == "世界" })
    // 世界為跨邊界候選（雙讀音）；選中它（第二位，置頂預覽之後）。
    let worldIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "世界" })
    )
    testSession.mockCandidateController = MockCandidateController(visible: true)

    // Shift + 對應選字鍵（1 為置頂預覽，worldIndex 位在第 worldIndex+1 個選字鍵）。
    let keyNumber = String(worldIndex + 1)
    let keyCode = mapKeyCodesANSIForTests[keyNumber] ?? 18
    let shiftKey = KBEvent.KeyEventData(
      flags: .shift, chars: keyNumber, charsSansModifiers: keyNumber, keyCode: keyCode
    ).asEvent
    #expect(testHandler.triageInput(event: shiftKey))

    // 跨邊界覆寫生效：注拼槽清空、組字器仍為雙鍵、組句為單節點「世界」。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["世界"])
    // 就地選字為使用者顯式干涉：trail 失效。
    #expect(testHandler.furiousTrail.isEmpty)
    // 狀態回到無候選的 Inputting，且未發生任何遞交。
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.candidates.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 狂拼候選窗顯示中，「未完成讀音」資料源（選字窗頂部 pane 用）回傳注拼槽尚未
  /// 固化的原始拼音字母流；該資料源由 data provider 單方把守、刻意繞過反查總開關，
  /// 且自 P184 起不再經由底部反查欄位回顯。
  @Test("IH-FuriousPinyin-019 Furious typing unfinished reading exposed via top pane")
  func test_IH_FuriousPinyin_019_FuriousTypingUnfinishedReadingExposedViaTopPane() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.showReverseLookupInCandidateUI = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.isVerticalTyping = false
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.showReverseLookupInCandidateUI = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 狂拼候選窗顯示中：unfinishedReading（頂部 pane 資料源）回傳注拼槽的字母流。
    #expect(testSession.unfinishedReading == "jie")

    // 讀音回顯已移交 unfinishedReading：底部反查欄位自此不再回傳字母流。
    #expect(testSession.reverseLookup(for: "界").isEmpty)

    // unfinishedReading 由 provider 單方把守、刻意繞過反查總開關。
    testHandler.prefs.showReverseLookupInCandidateUI = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.unfinishedReading == "jie")

    // 非狂拼時：provider 不提供 unfinishedReading（nil）；反查守衛路徑不受影響。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.unfinishedReading == nil)
    #expect(testSession.reverseLookup(for: "界").isEmpty)
  }

  /// 首音節還在注拼槽（組字器為空）時，copilot 窗不查跨邊界：
  /// 候選僅為置頂預覽＋前方單音節，無雙讀音候選、無崩潰。
  @Test("IH-FuriousPinyin-020 Furious typing no cross-boundary when assembler empty")
  func test_IH_FuriousPinyin_020_FuriousTypingNoCrossBoundaryWhenAssemblerEmpty() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 只打首音節「jie」（無 auto-chop 提交）：組字器為空、注拼槽暫存 jie。
    typeSentence("jie")
    #expect(testHandler.assembler.isEmpty)
    #expect(testHandler.composer.romajiBuffer == "jie")

    // 候選窗顯示（置頂＋前方單音節），但不含跨邊界的雙讀音候選。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(!testSession.state.candidates.contains { $0.keyArray.count == 2 })
    #expect(!testSession.state.candidates.map(\.value).contains("世界"))
  }

  // MARK: - 狂拼置頂最佳猜測與讀音回顯（Furious Top Guess & Reading Echo）

  /// 打「shijie」時，copilot 的最佳猜測（含邊界文脈）「世界」置頂，清單無重複值。
  @Test("IH-FuriousPinyin-021 Furious typing pins cross-boundary word at top")
  func test_IH_FuriousPinyin_021_FuriousTypingPinsCrossBoundaryWordAtTop() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)
    // 置頂為跨邊界完整詞「世界」（具體讀音 keyArray）。
    #expect(testSession.state.candidates.first?.value == "世界")
    #expect(testSession.state.candidates.first?.keyArray == ["ㄕˋ", "ㄐㄧㄝˋ"])
    // 清單無重複值。
    let values = testSession.state.candidates.map(\.value)
    #expect(values.count == Set(values).count)
  }

  /// Shift+1 選中置頂「世界」：雙鍵 span 覆寫生效（組字區單節點「世界」）、
  /// 注拼槽清空、trail 失效。
  @Test("IH-FuriousPinyin-022 Furious typing Shift one confirms top cross-boundary word")
  func test_IH_FuriousPinyin_022_FuriousTypingShiftOneConfirmsTopCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testSession.state.candidates.first?.value == "世界")
    testSession.mockCandidateController = MockCandidateController(visible: true)

    // Shift+1：選中置頂候選。
    let shift1 = KBEvent.KeyEventData(
      flags: .shift, chars: "!", charsSansModifiers: "1", keyCode: 18
    ).asEvent
    #expect(testHandler.triageInput(event: shift1))

    // 雙鍵 span 覆寫生效：注拼槽清空、組字器仍為雙鍵、組句為單節點「世界」。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["世界"])
    // 就地選字為使用者顯式干涉：trail 失效。
    #expect(testHandler.furiousTrail.isEmpty)
    // 狀態回到無候選的 Inputting，且未發生任何遞交。
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.candidates.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 狂拼未完成讀音（頂部 pane 資料源）：縱排模擬下仍提供字母流（繞過縱排守衛）；
  /// 狂拼關閉時 provider 不提供（回 nil）；反查欄位自此只走一般守衛路徑（Mock 回空）。
  @Test("IH-FuriousPinyin-023 Furious typing unfinished reading bypasses vertical guard")
  func test_IH_FuriousPinyin_023_FuriousTypingUnfinishedReadingBypassesVerticalGuard() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.showReverseLookupInCandidateUI = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.isVerticalTyping = false
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.showReverseLookupInCandidateUI = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)

    // 縱排模擬（isVerticalTyping = true）：unfinishedReading 仍提供字母流（繞過縱排守衛）。
    testSession.isVerticalTyping = true
    #expect(testSession.unfinishedReading == "jie")
    // 反查欄位自此只走一般守衛路徑：縱排時回空。
    #expect(testSession.reverseLookup(for: "界").isEmpty)
    testSession.isVerticalTyping = false

    // 狂拼關閉：provider 不提供 unfinishedReading；反查走一般守衛路徑（Mock 回空）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.unfinishedReading == nil)
    #expect(testSession.reverseLookup(for: "界").isEmpty)

    // 非狂拼（總開關開啟）走原磁帶反查路徑（Mock 無磁帶資料，回空）。
    #expect(testSession.reverseLookup(for: "界").isEmpty)
  }

  // MARK: - 狂拼 copilot 全句組句顯示與遞交（Furious Joint Composition Display）

  /// 狂拼模式：composition buffer 主段與前方預覽同源於 copilot 全句組句——
  /// 打「shijie」顯示「世界」（而非 main 組字器的「是」＋前方「界」＝「是界」），
  /// 置頂候選仍為「世界」。
  @Test("IH-FuriousPinyin-024 Furious typing display uses copilot joint composition")
  func test_IH_FuriousPinyin_024_FuriousTypingDisplayUsesCopilotJointComposition() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 提交 shi、注拼槽暫存 jie、copilot 候選窗顯示。
    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)
    // main 組字器單獨組句為「是」，但 copilot 全句組句以前方文脈重估邊界節點為「世界」。
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "是")
    #expect(testSession.state.displayedText == "世界") // 不再是「是界」。
    // 置頂候選仍為 copilot 最佳猜測「世界」。
    #expect(testSession.state.candidates.first?.value == "世界")
  }

  /// 同狀態按 Enter：第一次固化前方並停留 Inputting（不遞交），第二次（注拼槽已空）
  /// 遞交「copilot 主段＋前方預覽」＝「世界」（與所見一致）。
  @Test("IH-FuriousPinyin-025 Furious typing Enter solidifies then commits copilot joint text")
  func test_IH_FuriousPinyin_025_FuriousTypingEnterSolidifiesThenCommitsCopilotJointText() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testSession.state.displayedText == "世界")

    // 第一次 Enter：狂拼固化前方、停留 Inputting、不遞交。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(generateDisplayedText() == "世界")
    #expect(testSession.recentCommissions.isEmpty)

    // 第二次 Enter：注拼槽已空，遞交「copilot 主段＋前方預覽」＝「世界」。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions.joined() == "世界")
  }

  /// 打「shijie」後按後方向鍵（橫排 Left）：前方先被固化（注拼槽清空、組字器尾端
  /// 多一鍵），同一事件續走正常游標移動語義（游標左移）、狀態維持 Inputting、無遞交。
  @Test("IH-FuriousPinyin-026 Furious typing backward arrow solidifies then moves cursor")
  func test_IH_FuriousPinyin_026_FuriousTypingBackwardArrowSolidifiesThenMovesCursor() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 橫排（MockSession 預設 isVerticalTyping == false）：Left＝isCursorBackward。
    #expect(!testSession.isVerticalTyping)

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 模擬候選窗已顯示（handleCandidate 需要 ctlCandidate.visible）。
    let mockController = MockCandidateController(visible: true)
    testSession.mockCandidateController = mockController

    // 按後方向鍵（Left）：新規則——前方固化＋開正常選字窗＋同一事件導航候選高亮。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)

    // 前方已固化：注拼槽清空、組字器尾端多一個讀音鍵（固化前 1 鍵）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    // 尾鍵維持聲調桶（tone-fuzzy 保留）；顯示由真組字器組句決定（同源於 copilot）。
    #expect(testHandler.assembler.keys.last == .multipleKeys(["ㄐㄧㄝ", "ㄐㄧㄝˊ", "ㄐㄧㄝˇ", "ㄐㄧㄝˋ", "ㄐㄧㄝ˙"]))
    #expect(generateDisplayedText() == "世界")
    // 開出正常選字窗，候選涵蓋跨邊界詞「世界」。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.contains { $0.value == "世界" })
    // 游標不進行組字區移動（固化後仍在組字器最前端）。
    #expect(testHandler.assembler.cursor == testHandler.assembler.keys.count)
    // 該方向鍵事件被交給選字窗導航（高亮移動嘗試發生）。
    #expect(mockController.highlightNavigationCount > 0)
    // 空格固化（完整音節）累積 trail；無任何遞交。
    #expect(testHandler.furiousTrail == ["shi", "jie"])
    #expect(testSession.recentCommissions.isEmpty)
  }

  // MARK: - 狂拼高亮預覽與方向鍵規則（Furious Highlight Preview & Cursor Key Rules）

  /// W2：copilot 窗高亮即時反映到組字區（scratch 預覽）——高亮「世界」顯示「世界」、
  /// 高亮「界」顯示「是界」；真組字器鍵數與注拼槽不受影響。
  @Test("IH-FuriousPinyin-027 Furious typing highlight preview reflects candidate")
  func test_IH_FuriousPinyin_027_FuriousTypingHighlightPreviewReflectsCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)
    let keysBefore = testHandler.assembler.keys.count

    // 高亮「世界」（置頂）：組字區顯示套用結果「世界」。
    let worldIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "世界" })
    )
    testSession.candidatePairHighlightChanged(at: worldIndex)
    #expect(testSession.state.displayedText == "世界")
    #expect(testHandler.furiousHighlightOverride?.value == "世界")

    // 高亮「界」（前方單字候選）：組字區顯示套用結果（「是」＋覆寫的「界」＝「是界」）。
    let jieIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "界" })
    )
    testSession.candidatePairHighlightChanged(at: jieIndex)
    #expect(testSession.state.displayedText == "是界")
    #expect(testHandler.furiousHighlightOverride?.value == "界")

    // 預覽不觸碰真組字器、不動注拼槽。
    #expect(testHandler.assembler.keys.count == keysBefore)
    #expect(testHandler.composer.romajiBuffer == "jie")
  }

  /// W2：Enter 固化高亮候選並停留 Inputting；再按一次 Enter（注拼槽已空）才遞交
  /// 套用結果。不切高亮時固化置頂候選（IH-FuriousPinyin-025 語義不變）。
  @Test("IH-FuriousPinyin-028 Furious typing Enter solidifies highlighted candidate then commits")
  func test_IH_FuriousPinyin_028_FuriousTypingEnterSolidifiesHighlightedCandidateThenCommits() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 第一段：高亮「界」後按 Enter → 固化「界」、停留 Inputting、不遞交。
    typeSentence("shijie")
    let jieIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "界" })
    )
    testSession.candidatePairHighlightChanged(at: jieIndex)
    #expect(testHandler.furiousHighlightOverride?.value == "界")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(generateDisplayedText() == "是界")
    #expect(testSession.recentCommissions.isEmpty)
    // 再按 Enter：注拼槽已空，遞交套用結果「是界」。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions == ["是界"])

    // 第二段：不切高亮直接 Enter → 固化置頂「世界」、停留；再按 Enter 遞交「世界」。
    testSession.switchState(IMEState.ofAbortion())
    testSession.recentCommissions.removeAll()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()
    typeSentence("shijie")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions.isEmpty)
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions == ["世界"])
  }

  /// W3：非狂拼（或狂拼窗不可見）時，注拼槽有未完成讀音按前後方向鍵 → error 退回、
  /// 游標不動、無遞交。
  @Test("IH-FuriousPinyin-029 Furious typing cursor key rejected without copilot window")
  func test_IH_FuriousPinyin_029_FuriousTypingCursorKeyRejectedWithoutCopilotWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.errorCallback = nil
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
    testHandler.currentLM.syncPrefs()

    // 非狂拼：拼音模式注拼槽有未完成拼裝的字母。
    typeSentence("fan")
    #expect(testHandler.composer.romajiBuffer == "fan")
    var callbackFired = false
    testHandler.errorCallback = { _ in callbackFired = true }

    // 按後方向鍵（橫排 Left）：error 退回、游標不動、無遞交。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(callbackFired)
    #expect(testHandler.composer.romajiBuffer == "fan")
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// W3：狂拼 copilot 窗可見時，前後方向鍵 → 固化＋開正常選字窗＋同一事件導航高亮。
  @Test("IH-FuriousPinyin-030 Furious typing cursor key solidifies and navigates candidates")
  func test_IH_FuriousPinyin_030_FuriousTypingCursorKeySolidifiesAndNavigatesCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)
    let mockController = MockCandidateController(visible: true)
    testSession.mockCandidateController = mockController

    // 按前方向鍵（橫排 Right）：固化＋開正常選字窗＋導航高亮。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.contains { $0.value == "世界" })
    // 該方向鍵事件被交給選字窗導航（高亮移動嘗試發生）。
    #expect(mockController.highlightNavigationCount > 0)
    // 游標不進行組字區移動。
    #expect(testHandler.assembler.cursor == testHandler.assembler.keys.count)
    #expect(testSession.recentCommissions.isEmpty)
  }

  // MARK: - 狂拼標記模式與 Shift+方向鍵（Furious Marking & Shift Cursor Keys）

  /// Shift+前後方向鍵（注拼槽有未完成讀音）：狂拼 copilot 窗可見時，先固化前方、
  /// 再放行續走 Shift 標記流程（state 變 .ofMarking）、無遞交。
  @Test("IH-FuriousPinyin-031 Furious typing Shift backward solidifies then marks")
  func test_IH_FuriousPinyin_031_FuriousTypingShiftBackwardSolidifiesThenMarks() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // Shift+後方向鍵（橫排 Shift+Left）。
    let shiftLeft = KBEvent.KeyEventData.dataArrowLeft.asEvent.reinitiate(modifierFlags: .shift)
    _ = testHandler.triageInput(event: shiftLeft)

    // 前方已固化（注拼槽清空、組字器尾端多一個讀音鍵）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    // 放行續走標記流程：state 變 .ofMarking。
    #expect(testSession.state.type == .ofMarking)
    // 無任何遞交。
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// Shift+前後方向鍵（非狂拼）：維持 T8 前行為——注拼槽有未完成讀音時撞上既有
  /// `!isComposerOrCalligrapherEmpty` 守衛，errorCallback 退回、不插入、不進標記。
  @Test("IH-FuriousPinyin-032 Shift backward confirms completable reading then marks")
  func test_IH_FuriousPinyin_032_ShiftBackwardConfirmsCompletableReadingThenMarks() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.errorCallback = nil
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
    testHandler.currentLM.syncPrefs()

    // 非狂拼：拼音模式打入完整可唸讀音（注拼槽非空）。
    typeSentence("fan")
    #expect(testHandler.composer.romajiBuffer == "fan")
    #expect(testHandler.assembler.isEmpty)
    var callbackFired = false
    testHandler.errorCallback = { _ in callbackFired = true }

    // Shift+後方向鍵（橫排 Shift+Left）：落回既有守衛、errorCallback 退回。
    let shiftLeft = KBEvent.KeyEventData.dataArrowLeft.asEvent.reinitiate(modifierFlags: .shift)
    _ = testHandler.triageInput(event: shiftLeft)

    // 不插入、不進標記：注拼槽內容不變、組字器不變、維持 Inputting。
    #expect(callbackFired)
    #expect(testHandler.composer.romajiBuffer == "fan")
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// Shift+前後方向鍵（非狂拼）：不完整前綴（如 z）無法確認 → error 退回、
  /// 注拼槽仍為 z、組字器不變、無標記。
  @Test("IH-FuriousPinyin-033 Shift backward rejects incomplete reading")
  func test_IH_FuriousPinyin_033_ShiftBackwardRejectsIncompleteReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.errorCallback = nil
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
    testHandler.currentLM.syncPrefs()

    // 非狂拼：拼音模式注拼槽為不完整前綴「z」。
    typeSentence("z")
    #expect(testHandler.composer.romajiBuffer == "z")
    var callbackFired = false
    testHandler.errorCallback = { _ in callbackFired = true }

    // Shift+後方向鍵（橫排 Shift+Left）。
    let shiftLeft = KBEvent.KeyEventData.dataArrowLeft.asEvent.reinitiate(modifierFlags: .shift)
    _ = testHandler.triageInput(event: shiftLeft)

    // error 退回、注拼槽仍為 z、組字器不變、無標記。
    #expect(callbackFired)
    #expect(testHandler.composer.romajiBuffer == "z")
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 崩潰回歸（生產堆疊溢位）：狂拼 copilot 窗**可見**（復現生產條件）時，Shift+前後
  /// 方向鍵不得經路由器誤入 handleCandidate 的重 triage 循環——前方固化＋進標記、
  /// 事件正常終了。修復前此測試會堆疊溢位。
  @Test("IH-FuriousPinyin-034 Furious typing Shift backward does not recurse with visible window")
  func test_IH_FuriousPinyin_034_FuriousTypingShiftBackwardDoesNotRecurseWithVisibleWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieDisplayFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)

    // 復現生產條件：候選窗實際可見（handleCandidate 入口的 ctlCandidate.visible 通過）。
    testSession.mockCandidateController = MockCandidateController(visible: true)

    // Shift+後方向鍵（橫排 Shift+Left）：不得經路由器進 handleCandidate（非選字鍵），
    // 落回 T8 狂拼路徑——固化＋進標記，事件正常終了、無遞迴。
    let shiftLeft = KBEvent.KeyEventData.dataArrowLeft.asEvent.reinitiate(modifierFlags: .shift)
    _ = testHandler.triageInput(event: shiftLeft)

    // 前方已固化（注拼槽清空、組字器尾端多一個讀音鍵）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    // 放行續走標記流程：state 變 .ofMarking。
    #expect(testSession.state.type == .ofMarking)
    // 無任何遞交。
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 狂拼空格消費：注拼槽有未完成讀音（copilot 窗顯示）時，空格固化插入讀音
  /// （整組聲調桶＋copilot 選讀覆寫「媽」）並被本拍直接消費——不觸發候選輪替、
  /// 不落入遞交路徑（不再生成空格字符拆斷組字區）。測資：媽(ㄇㄚ,9)／罵(ㄇㄚˋ,8)，
  /// LM 初始選字為「媽」；若空格仍輪替（spaceKeyBehaviorAgainstICB == 2），
  /// 會輪到「罵」。消費後組字區維持 copilot 選讀「媽」、無任何遞交。
  @Test("IH-FuriousPinyin-035 Furious typing Space consumed after solidify")
  func test_IH_FuriousPinyin_035_FuriousTypingSpaceConsumedAfterSolidify() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: 9),
      .init(keyArray: ["ㄇㄚˋ"], value: "罵", score: 8),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 2 // Space 為候選輪替鍵。
    testHandler.currentLM.syncPrefs()

    // 「ma」為單一可唸音節：auto-chop 不觸發，整段暫存於注拼槽、copilot 窗顯示。
    typeSentence("ma")
    #expect(testHandler.assembler.keys.isEmpty)
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(!testSession.state.candidates.isEmpty)

    // 按 Space：固化插入 copilot 選讀（整組聲調桶＋顯示覆寫「媽」），且空格被消費
    // ——不輪替候選、不落入遞交路徑（不再生成空格字符拆斷組字區、使之直接遞交）。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    // 空格未輪替候選：組字區維持 copilot 選讀「媽」，而非輪替後的四聲「罵」。
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.assembler.keys.last == .multipleKeys(["ㄇㄚ", "ㄇㄚˊ", "ㄇㄚˇ", "ㄇㄚˋ", "ㄇㄚ˙"]))
    #expect(generateDisplayedText() == "媽")
    // 空格已被本拍消費：無任何遞交、無空格字符，組字區維持原狀（Inputting）。
    let committed = testSession.recentCommissions.joined()
    #expect(committed.isEmpty)
    #expect(!committed.contains("罵"))
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼 BackSpace 清空注拼槽後再按空格：空格應就地輪替候選（behavior==2）、
  /// 而非把已刪除的前方讀音重新組回（Tekkon doBackSpace 未同步清理 phonabet 槽位
  /// 的缺陷）。測資：打「shimama」後注拼槽暫存 ma、組字器 [shi, ma]（顯示失媽）；
  /// 兩次 BackSpace 清空注拼槽；空格輪替後組字器鍵數維持 2、顯示變為輪替結果
  /// 「失嗎」、無任何遞交。
  @Test("IH-FuriousPinyin-036 Furious typing Backspace then Space revolves")
  func test_IH_FuriousPinyin_036_FuriousTypingBackspaceThenSpaceRevolves() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 2 // Space 為候選輪替鍵。
    testHandler.currentLM.syncPrefs()

    // 「shimama」：自動 chop 提交 shi、ma 兩鍵，前方 ma 暫存於注拼槽、copilot 窗顯示。
    typeSentence("shimama")
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(!testSession.state.candidates.isEmpty)

    // 兩次 BackSpace：僅清空注拼槽（前方 ma 本就在槽內），組字器維持兩鍵。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(generateDisplayedText() == "失媽")

    // 按 Space：空格就地輪替候選——鍵數維持 2（不得重新組回已刪除的「ma」）、
    // 顯示為輪替後的「失嗎」、無任何遞交。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(generateDisplayedText() == "失嗎")
    #expect(testSession.recentCommissions.isEmpty)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
  }

  /// 狂拼 IMK 強制自動遞交（如 CpLk 切換 IME）：應遞交內文組字區顯示的 copilot
  /// 全句組句結果（主段＋前方預覽），而非組字器自身的組句結果——即便啟用了
  /// trimUnfinishedReadingsOnCommit（sansReading 剔除的是「未完成拼寫的原文拼音」、
  /// 不適用於狂拼的組句後中文前方預覽）。測資：打「shimama」後顯示「失媽媽」；
  /// 強制遞交內容須為「失媽媽」而非組字器自身的「失媽」。
  @Test("IH-FuriousPinyin-037 Furious typing auto commit commits copilot joint text")
  func test_IH_FuriousPinyin_037_FuriousTypingAutoCommitCommitsCopilotJointText() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.trimUnfinishedReadingsOnCommit = true
    testHandler.currentLM.syncPrefs()

    // 「shimama」：主段 [shi, ma] 組句「失媽」＋前方預覽「媽」＝顯示「失媽媽」。
    typeSentence("shimama")
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(generateDisplayedText() == "失媽")
    // 顯示（含前方預覽）為「失媽媽」。
    #expect(testSession.state.displayedText == "失媽媽")

    // 強制自動遞交（CpLk 切換 IME 等）：遞交內容＝顯示的 copilot 全句組句結果。
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler()
    #expect(testSession.recentCommissions.joined() == "失媽媽")
  }

  /// 空格固化只插聲調桶（不覆寫）：「xi 空格 an 空格」時 copilot 重切合併長詞
  /// 「西安」，不被單字「西」的覆寫釘死打斷；trail 持續累積供語言模型引導的
  /// 重切分（對治「長詞自動選取被短詞 override 打斷」）。
  @Test("IH-FuriousPinyin-038 Furious typing Space solidification merges long word")
  func test_IH_FuriousPinyin_038_FuriousTypingSpaceSolidificationMergesLongWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertXiAnLongWordFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 2 // 空格不作選字窗呼叫（聚焦固化語義）。
    testHandler.currentLM.syncPrefs()

    // 「xi」＋空格：只插 ㄒㄧ桶、不覆寫；trail 累積「xi」。
    typeSentence("xi")
    #expect(testHandler.composer.romajiBuffer == "xi")
    #expect(!testSession.state.candidates.isEmpty)
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.furiousTrail == ["xi"])
    #expect(generateDisplayedText() == "西")

    // 「an」＋空格：copilot 重切合併長詞「西安」，真組字器同源組句「西安」。
    typeSentence("an")
    #expect(testSession.state.displayedText == "西安") // copilot 全句顯示（西＋前方安）。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.furiousTrail == ["xi", "an"])
    #expect(generateDisplayedText() == "西安")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.recentCommissions.isEmpty)
  }

  /// 打「shijie」後（注拼槽暫存 jie、copilot 窗顯示中），按 Tab：
  /// 前方讀音先固化進組字器（如 Enter 般只插聲調桶、清空注拼槽、trail 累積），
  /// 同一事件續走正常流程觸發就地輪替（注拼槽已空、revolveCandidate 正常執行、
  /// 不再走 A2DAF7BC error 路徑），停留於 Inputting 狀態；再次 Tab 可繼續推進輪替。
  @Test("IH-FuriousPinyin-039 Furious typing Tab solidifies then revolves")
  func test_IH_FuriousPinyin_039_FuriousTypingTabSolidifiesThenRevolves() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.errorCallback = nil
    }

    var errorMessages: [String] = []
    testHandler.errorCallback = { errorMessages.append($0) }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 在 'j' 提交 shi（注拼槽暫存 jie）。
    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 按 Tab：狂拼前方先固化、再輪替。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "\t", keyCode: 48).asEvent)

    // 固化完成：注拼槽清空、組字器尾端多一個聲調桶鍵。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testHandler.assembler.keys.last == .multipleKeys(["ㄐㄧㄝ", "ㄐㄧㄝˊ", "ㄐㄧㄝˇ", "ㄐㄧㄝˋ", "ㄐㄧㄝ˙"]))
    // 輪替為使用者顯式干涉：revolveCandidate 使 trail 失效（清空）、不再重切分。
    #expect(testHandler.furiousTrail.isEmpty)
    // 就地輪替後停留於 Inputting 狀態（不開選字窗）；輪替不再走 error 路徑。
    #expect(testSession.state.type == .ofInputting)
    #expect(errorMessages.isEmpty)

    // 再次 Tab（注拼槽已空）：直接輪替、keys 不變、仍無 error。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "\t", keyCode: 48).asEvent)
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testSession.state.type == .ofInputting)
    #expect(errorMessages.isEmpty)
  }

  /// 同前但按 Shift+Tab：固化後反向輪替（revolveCandidate reverseOrder: true），
  /// 同樣停留於 Inputting 狀態、不 crash、不 error。
  @Test("IH-FuriousPinyin-040 Furious typing Shift+Tab solidifies then revolves reverse")
  func test_IH_FuriousPinyin_040_FuriousTypingShiftTabSolidifiesThenRevolvesReverse() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.errorCallback = nil
    }

    var errorMessages: [String] = []
    testHandler.errorCallback = { errorMessages.append($0) }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")

    // 按 Shift+Tab：固化後反向輪替。
    var tabEvent = KBEvent.KeyEventData(chars: "\t", keyCode: 48)
    tabEvent.flags.insert(.shift)
    _ = testHandler.triageInput(event: tabEvent.asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 2)
    // 輪替為使用者顯式干涉：trail 失效（清空）。
    #expect(testHandler.furiousTrail.isEmpty)
    #expect(testSession.state.type == .ofInputting)
    #expect(errorMessages.isEmpty)
  }

  /// 狂拼整詞簡拼（R2-α）：注拼槽整段無法展開成單一音節桶（如「ysxb」）時，
  /// copilot 窗改以整詞簡拼查詢生成候選——置頂為最佳整詞猜測、keyArray 為實際讀音。
  @Test("IH-FuriousPinyin-041 Furious typing abbreviated whole word candidates")
  func test_IH_FuriousPinyin_041_FuriousTypingAbbreviatedWholeWordCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 使用者造詞：ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ（以「ysxb」的 initial 類 cells 可整詞命中）。
    // 同時注入近分競爭者「一世雄霸」（R3-a 之後唯一整詞匹配會自動套用，
    // 此處以模稜兩可場景保留「copilot 窗顯示候選、不自動套用」的既有語義）。
    // 同時注入單音節 gram，供確認寫回時 insertKeys 的讀音存在性驗證。
    [
      .init(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩", score: 9),
      .init(keyArray: ["ㄧ", "ㄕˋ", "ㄒㄩㄥˊ", "ㄅㄚ"], value: "一世雄霸", score: 8),
      .init(keyArray: ["ㄧㄝ"], value: "椰", score: 0),
      .init(keyArray: ["ㄕㄡ"], value: "收", score: 0),
      .init(keyArray: ["ㄒㄧㄢ"], value: "先", score: 0),
      .init(keyArray: ["ㄅㄟ"], value: "杯", score: 0),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「ysxb」：無完整音節可自動 chop 提交，整段留在注拼槽。
    typeSentence("ysxb")
    #expect(testHandler.composer.romajiBuffer == "ysxb")
    #expect(testSession.state.type == .ofInputting)
    // 整詞簡拼候選窗：置頂為最佳整詞猜測、keyArray 為實際讀音（供單鍵寫回）。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "野獸先輩")
    #expect(testSession.state.candidates.first?.keyArray == ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"])
  }

  /// 狂拼整詞簡拼（R2-α）確認：Shift+選字鍵選中置頂整詞候選後，
  /// 以實際讀音單鍵序列寫回組字器、注拼槽清空、trail 失效（顯式選字＝顯式干涉）。
  @Test("IH-FuriousPinyin-042 Furious typing abbreviated whole word selection writes actual readings")
  func test_IH_FuriousPinyin_042_FuriousTypingAbbreviatedWholeWordSelectionWritesActualReadings() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 使用者造詞＋單音節 gram（供確認寫回的讀音存在性驗證）。
    // 與 IH-FuriousPinyin-041 相同：注入近分競爭者「一世雄霸」，使 ysxb 不觸發 R3-a 自動套用、
    // 保留「Shift+選字鍵確認整詞候選」的確認路徑。
    [
      .init(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩", score: 9),
      .init(keyArray: ["ㄧ", "ㄕˋ", "ㄒㄩㄥˊ", "ㄅㄚ"], value: "一世雄霸", score: 8),
      .init(keyArray: ["ㄧㄝ"], value: "椰", score: 0),
      .init(keyArray: ["ㄕㄡ"], value: "收", score: 0),
      .init(keyArray: ["ㄒㄧㄢ"], value: "先", score: 0),
      .init(keyArray: ["ㄅㄟ"], value: "杯", score: 0),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("ysxb")
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "野獸先輩")

    // 模擬候選窗已顯示（handleCandidate 需要 ctlCandidate.visible）。
    testSession.mockCandidateController = MockCandidateController(visible: true)
    defer { testSession.mockCandidateController = nil }

    // Shift+選字鍵「1」：就地選中置頂整詞候選（R2-α 確認路徑）。
    let shift1 = KBEvent.KeyEventData(
      flags: .shift, chars: "!", charsSansModifiers: "1", keyCode: 18
    ).asEvent
    #expect(testHandler.triageInput(event: shift1))

    // 注拼槽清空、組字器尾端寫入實際讀音單鍵序列（無桶、無 &）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 4)
    #expect(testHandler.assembler.keys == [
      .singleKey("ㄧㄝ"), .singleKey("ㄕㄡ"), .singleKey("ㄒㄧㄢ"), .singleKey("ㄅㄟ"),
    ])
    // 組字區顯示整詞；trail 失效（顯式選字＝使用者顯式干涉）。
    #expect(generateDisplayedText() == "野獸先輩")
    #expect(testHandler.furiousTrail.isEmpty)
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼整詞簡拼（R2-α）空格固化：注拼槽整段無法展開成單一音節桶（如「xqr」→
  /// 「星期日」）時，空格把整詞簡拼候選之首的實際讀音以單鍵插入組字器
  /// （不覆寫、保留 LM 重切分自由度）、清空注拼槽、trail 失效——不丟失前方上下文。
  @Test("IH-FuriousPinyin-043 Furious typing abbreviated Space solidifies top candidate")
  func test_IH_FuriousPinyin_043_FuriousTypingAbbreviatedSpaceSolidifiesTopCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 使用者造詞「星期日」＋單音節 gram（供固化插入的讀音存在性驗證）。
    // 另注入近分競爭者「星期人」，使 xqr 不觸發 R3-a 自動套用、保留
    // 「空格固化整詞候選之首的實際讀音」的既有確認路徑。
    [
      .init(keyArray: ["ㄒㄧㄥ", "ㄑㄧ", "ㄖˋ"], value: "星期日", score: 9),
      .init(keyArray: ["ㄒㄧㄥ", "ㄑㄧ", "ㄖㄣˊ"], value: "星期人", score: 8),
      .init(keyArray: ["ㄒㄧㄥ"], value: "星", score: 0),
      .init(keyArray: ["ㄑㄧ"], value: "期", score: 0),
      .init(keyArray: ["ㄖˋ"], value: "日", score: 0),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 2 // 空格不作選字窗呼叫（聚焦固化語義）。
    testHandler.currentLM.syncPrefs()

    // 「xqr」：多音節簡拼、copilot 窗顯示整詞候選「星期日」。
    typeSentence("xqr")
    #expect(testHandler.composer.romajiBuffer == "xqr")
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "星期日")

    // 空格：固化整詞簡拼候選之首的實際讀音（單鍵插入、不覆寫）。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys == [
      .singleKey("ㄒㄧㄥ"), .singleKey("ㄑㄧ"), .singleKey("ㄖˋ"),
    ])
    #expect(generateDisplayedText().contains("星期日"))
    #expect(testHandler.furiousTrail.isEmpty) // 簡拼前綴非完整音節：trail 失效。
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼 copilot 窗置頂 POM 建議（T1）：以組字器副本＋虛擬尾段做唯讀查詢，
  /// 容錯模式（逐段去聲調等值）召回記憶——聲調桶代表鍵（無調形）不致落空；
  /// 記憶詞（媽）置頂於語言模型最佳猜測（嗎）之上。
  @Test("IH-FuriousPinyin-044 Furious typing copilot window fronts POM suggestion")
  func test_IH_FuriousPinyin_044_FuriousTypingCopilotWindowFrontsPOMSuggestion() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 語料：ㄕˋ→是（主段）、ㄇㄚ 桶→媽(-8)／麻(-8)／嗎(-2，LM 最佳猜測)。
    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 記憶「是」之後的前方為「媽」（無調形 head；語境鍵 (ㄕˋ,是)）。
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shima」：auto-chop 提交「是」（ㄕˋ），注拼槽暫存 ma。
    typeSentence("shima")
    #expect(testHandler.composer.romajiBuffer == "ma")

    // copilot 窗候選：POM 記憶（媽）置頂於 LM 最佳猜測（嗎）之上。
    let candidates = testHandler.furiousTypingFrontCandidates
    #expect(!(candidates?.isEmpty ?? true))
    #expect(candidates?.first?.value == "媽")
  }

  /// 狂拼 α 自動套用（R3-a）：注拼槽整段無法展開成完整音節序列（如「ysxb」）、
  /// 且整詞簡拼查詢的頂級候選「明確勝出」（唯一匹配）時，自動把其實際讀音以單鍵
  /// 序列寫入組字器——全程自動出整詞「野獸先輩」、不必等使用者 Shift+選字鍵確認。
  /// 自動套用為最佳猜測、非顯式選字：不觸發 POM 觀察、trail 失效（簡拼非完整音節）。
  @Test("IH-FuriousPinyin-045 Furious typing abbreviation auto applies clear winner")
  func test_IH_FuriousPinyin_045_FuriousTypingAbbreviationAutoAppliesClearWinner() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 唯一整詞匹配（無近分競爭者）：「野獸先輩」＋單音節 gram（組句存在性驗證）。
    [
      .init(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩", score: 9),
      .init(keyArray: ["ㄧㄝ"], value: "椰", score: 0),
      .init(keyArray: ["ㄕㄡ"], value: "收", score: 0),
      .init(keyArray: ["ㄒㄧㄢ"], value: "先", score: 0),
      .init(keyArray: ["ㄅㄟ"], value: "杯", score: 0),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 打字「ysxb」：最後一鍵 b 觸發 α 自動套用（明確勝出）——注拼槽清空、
    // 組字器含實際讀音單鍵序列、組句顯示整詞、trail 失效。
    typeSentence("ysxb")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys == [
      .singleKey("ㄧㄝ"), .singleKey("ㄕㄡ"), .singleKey("ㄒㄧㄢ"), .singleKey("ㄅㄟ"),
    ])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["野獸先輩"])
    #expect(testHandler.furiousTrail.isEmpty)
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼 α 自動套用（R3-a）的「明確勝出」防禦：整詞簡拼查詢存在近分競爭者
  /// （如「一世雄霸」）時不得自動套用——注拼槽保留、組字器不受影響、copilot 窗
  /// 仍陳列候選供使用者 Shift+選字鍵確認。
  @Test("IH-FuriousPinyin-046 Furious typing abbreviation ambiguous stays")
  func test_IH_FuriousPinyin_046_FuriousTypingAbbreviationAmbiguousStays() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 近分競爭者：「一世雄霸」與「野獸先輩」分數差 1（< 明確勝出閾值 3.0）。
    [
      .init(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩", score: 9),
      .init(keyArray: ["ㄧ", "ㄕˋ", "ㄒㄩㄥˊ", "ㄅㄚ"], value: "一世雄霸", score: 8),
      .init(keyArray: ["ㄧㄝ"], value: "椰", score: 0),
      .init(keyArray: ["ㄕㄡ"], value: "收", score: 0),
      .init(keyArray: ["ㄒㄧㄢ"], value: "先", score: 0),
      .init(keyArray: ["ㄅㄟ"], value: "杯", score: 0),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("ysxb")
    // 模稜兩可：不自動套用——注拼槽保留整段、組字器空、copilot 窗仍陳列候選。
    #expect(testHandler.composer.romajiBuffer == "ysxb")
    #expect(testHandler.assembler.keys.isEmpty)
    #expect(testHandler.furiousTrail.isEmpty)
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.candidates.first?.value == "野獸先輩")
  }

  /// 狂拼「先生」回歸防護（P163 補修）：跨音節數重切在打字中途把單音節 trail 拆開，
  /// 會把「xiansheng」誤切為「西 安 生」——「xian」剛被 auto-chop 提交為單音節 trail
  /// 時即拆成「西」「安」，後續「生」只能接在其後。收斂後重切僅做「同音節數」且
  /// trail 至少兩段，且固化後不再觸發重切：「xiansheng」應穩定組句為「先生」。
  /// 本例刻意讓「西岸生」切分的每音節平均分（-2）高於「先生」（-3）——若跨音節數
  /// 重切回歸（枚舉不限音節數或平均化比較），本測試即失敗。
  @Test("IH-FuriousPinyin-047 Furious typing keeps xiansheng unsplit")
  func test_IH_FuriousPinyin_047_FuriousTypingXianShengNotSplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 「西」「安」「生」各 -2（西岸生 3 音節平均 -2）刻意高於「先生」(-4 + -2) / 2 = -3：
    // 跨音節數重切若回歸，會以平均分勝出把「先生」拆成「西 安 生」。
    [
      .init(keyArray: ["ㄒㄧㄢ"], value: "先", score: -4),
      .init(keyArray: ["ㄕㄥ"], value: "生", score: -2),
      .init(keyArray: ["ㄒㄧ"], value: "西", score: -2),
      .init(keyArray: ["ㄢ"], value: "安", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 2 // 空格不作選字窗呼叫（聚焦固化語義）。
    testHandler.currentLM.syncPrefs()

    // 「xiansheng」：auto-chop 在 's' 提交「先」（注拼槽暫存 sheng）；
    // 空格固化「生」後 trail 為 [xian, sheng]、組句維持「先生」不被拆開。
    typeSentence("xiansheng")
    #expect(testHandler.composer.romajiBuffer == "sheng")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["先", "生"])
    #expect(testHandler.assembler.keys == [
      .multipleKeys(Tekkon.makeToneInsensitiveVariants(of: "ㄒㄧㄢ")),
      .multipleKeys(Tekkon.makeToneInsensitiveVariants(of: "ㄕㄥ")),
    ])
    #expect(testHandler.furiousTrail == ["xian", "sheng"])
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼 copilot 窗聯合重切（P164 補修）：直接敲「fangan」連打（trail=fang、
  /// 注拼槽=an）時，copilot 窗即呈現「反感」（fan|gan）類替代切分整詞候選——
  /// 與「fan gan」分開打的體驗一致，不必先固化再開正常選字窗。
  @Test("IH-FuriousPinyin-048 Furious typing co-segmented offers Enter copilot window")
  func test_IH_FuriousPinyin_048_FuriousTypingCoSegmentedOffersEnterCopilotWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄈㄤ"], value: "方", score: -6),
      .init(keyArray: ["ㄢ"], value: "安", score: -6),
      .init(keyArray: ["ㄈㄢˇ"], value: "反", score: -6),
      .init(keyArray: ["ㄍㄢˇ"], value: "感", score: -6),
      .init(keyArray: ["ㄈㄢˇ", "ㄍㄢˇ"], value: "反感", score: -7),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「fangan」連打：auto-chop 提交「方」（trail=["fang"]）、注拼槽暫存 "an"。
    typeSentence("fangan")
    #expect(testHandler.composer.romajiBuffer == "an")
    #expect(testHandler.furiousTrail == ["fang"])
    #expect(testSession.state.type == .ofInputting)

    // copilot 窗候選：聯合重切 offer「反感」（fan|gan 整詞）入列。
    let offer = testSession.state.candidates.first(where: { $0.value == "反感" })
    #expect(offer != nil)
    #expect(offer?.keyArray == ["ㄈㄢˇ", "ㄍㄢˇ"])
    #expect(testHandler.furiousCoSegmentedOffers.first?.blobs == ["fan", "gan"])
  }

  /// 狂拼 copilot 窗聯合重切選取（P164 補修）：選中「反感」後，drop trail 的
  /// fang、insert [fan, gan] 音節桶、清空注拼槽、trail 更新為新切分、組句「反感」。
  @Test("IH-FuriousPinyin-049 Furious typing selecting co-segmented offer replaces trail")
  func test_IH_FuriousPinyin_049_FuriousTypingSelectingCoSegmentedOfferReplacesTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄈㄤ"], value: "方", score: -6),
      .init(keyArray: ["ㄢ"], value: "安", score: -6),
      .init(keyArray: ["ㄈㄢˇ"], value: "反", score: -6),
      .init(keyArray: ["ㄍㄢˇ"], value: "感", score: -6),
      .init(keyArray: ["ㄈㄢˇ", "ㄍㄢˇ"], value: "反感", score: -7),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("fangan")
    guard let offerIndex = testSession.state.candidates.firstIndex(where: { $0.value == "反感" })
    else {
      Issue.record("Co-segmented offer '反感' not found in copilot window.")
      return
    }

    // 模擬確認（copilot 窗 Shift+選字鍵／滑鼠點選 → mock ofInputting 分支）。
    testSession.candidatePairSelectionConfirmed(at: offerIndex)

    // trail 段替換為 fan|gan 音節桶、注拼槽清空、trail 更新、組句「反感」。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys == [
      .multipleKeys(Tekkon.makeToneInsensitiveVariants(of: "ㄈㄢ")),
      .multipleKeys(Tekkon.makeToneInsensitiveVariants(of: "ㄍㄢ")),
    ])
    #expect(testHandler.furiousTrail == ["fan", "gan"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["反感"])
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼 copilot 窗候選排序（P164）：候選（置頂組句預覽除外）按「詞長降冪、
  /// 再查詢分數降冪」stable-sort——替代切分整詞「反感」（2 段）浮於大量單音節
  /// 候選之前（僅次於置頂預覽），純鍵盤操作即可見、不必捲到清單末頁。
  @Test("IH-FuriousPinyin-050 Furious typing co-segmented offer ranks before single syllables")
  func test_IH_FuriousPinyin_050_FuriousTypingCoSegmentedOfferRanksBeforeSingleSyllables() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄈㄤ"], value: "方", score: -6),
      .init(keyArray: ["ㄢ"], value: "安", score: -6),
      .init(keyArray: ["ㄈㄢˇ"], value: "反", score: -6),
      .init(keyArray: ["ㄍㄢˇ"], value: "感", score: -6),
      .init(keyArray: ["ㄈㄢˇ", "ㄍㄢˇ"], value: "反感", score: -7),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    typeSentence("fangan")
    let candidates = testSession.state.candidates
    #expect(!candidates.isEmpty)
    // 置頂組句預覽（「安」）保持首位；「反感」（2 段整詞）緊隨其後——
    // 排序於所有 1 段候選（方／安等）之前。
    let fanGanIndex = candidates.firstIndex(where: { $0.value == "反感" })
    #expect(fanGanIndex != nil)
    #expect(fanGanIndex == 1)
    if let fanGanIndex {
      let firstSingleAfter = candidates[(fanGanIndex + 1)...]
        .firstIndex(where: { $0.keyArray.count == 1 })
      #expect(firstSingleAfter != nil)
      #expect(candidates[fanGanIndex].keyArray == ["ㄈㄢˇ", "ㄍㄢˇ"])
    }
  }

  /// 狂拼 copilot 窗置頂候選就地選字的首段重合（P165，P169 收斂）：`tama` 打完整
  /// （組字器 [ㄊㄚ桶]）後，直接以 POM「他媽的」（3 段、首段 ㄊㄚ 與組字器尾鍵 ㄊㄚ桶
  /// 重合）走就地確認路徑——`applyFuriousFrontCandidate` 應只插入重合段以外的讀音
  /// 並覆寫完整詞——組字器「他媽的」、**不含重複「他」**（修復前：插入完整 keyArray
  /// →「他他媽的」）。P169 收斂：此場景繞過 copilot 窗（3 段建議在 `tama` 時不再置頂，
  /// 見 IH-FuriousPinyin-053），直接驗證首段重合路徑的套用正確性。
  @Test("IH-FuriousPinyin-051 Furious typing tama preview no duplicate")
  func test_IH_FuriousPinyin_051_FuriousTypingTamaPreviewNoDuplicate() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 真實 factory 詞庫（mcbopomofo-cht 4.7.0）相關詞條的 grams（含分數）。
    [
      .init(keyArray: ["ㄊㄚ"], value: "他", score: -5.024),
      .init(keyArray: ["ㄊㄚ"], value: "她", score: -5.045),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -5.169),
      .init(keyArray: ["ㄇㄚ"], value: "嗎", score: -5.113),
      .init(keyArray: ["ㄉㄜ˙"], value: "的", score: -4.971),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ"], value: "他媽", score: -8.713),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"], value: "他媽的", score: -5.405),
      .init(keyArray: ["ㄇㄚ", "ㄇㄚ˙"], value: "媽媽", score: -3.195),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // POM 記憶（使用者實際環境，2026-08-30）：三條全注入。
    [
      ("()&()&(ㄨㄛˇ,我)", "我"),
      ("()&(ㄋㄧˇ,你)&(ㄊㄚ-ㄇㄚ-ㄉㄜ˙,他媽的)", "他媽的"),
      ("(ㄗㄞˋ,再)&(ㄍㄣ-ㄨㄛˇ-ㄕㄨㄛ,跟我說)&(ㄧ,一)", "一邊"),
    ].forEach {
      testHandler.currentLM.memorizePerception(
        (ngramKey: $0.0, candidate: $0.1),
        timestamp: Date().timeIntervalSince1970
      )
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.syncPrefs()

    // 打「tama」：組字器 [ㄊㄚ桶]＋注拼槽 "ma"。
    typeSentence("tama")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "ma")
    // 直接以 POM「他媽的」走就地確認（繞過 copilot 窗：3 段建議在 tama 時不再置頂）。
    testHandler.confirmFuriousFrontCandidate(
      (keyArray: ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"], value: "他媽的"), memorizePOM: true
    )

    // 修復後：只插重合段以外的讀音、覆寫完整詞——組字器「他媽的」、無重複「他」。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 3)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["他媽的"])
    #expect(!testHandler.assembler.assembledSentence.values.joined().contains("他他"))
  }

  /// 狂拼 copilot 窗去重：`tamade` 連打（ta、ma 已固化、de 在注拼槽）時，
  /// 置頂 POM 建議與組句橫跨節點（crossingPair）會對同一詞「他媽的」各回傳一次——
  /// `buildFuriousFrontCandidates` 的置頂段必須按 value 去重（保留先出現的 POM 建議），
  /// 選字窗只能出現一個「他媽的」。
  @Test("IH-FuriousPinyin-052 Furious copilot window dedups POM fronted candidate")
  func test_IH_FuriousPinyin_052_FuriousCopilotWindowDedupsPOMFrontedCandidate() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 與 IH-FuriousPinyin-051 同源：真實 factory 詞庫相關詞條 grams＋三條使用者環境 POM 記憶。
    [
      .init(keyArray: ["ㄊㄚ"], value: "他", score: -5.024),
      .init(keyArray: ["ㄊㄚ"], value: "她", score: -5.045),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -5.169),
      .init(keyArray: ["ㄇㄚ"], value: "嗎", score: -5.113),
      .init(keyArray: ["ㄉㄜ˙"], value: "的", score: -4.971),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ"], value: "他媽", score: -8.713),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"], value: "他媽的", score: -5.405),
      .init(keyArray: ["ㄇㄚ", "ㄇㄚ˙"], value: "媽媽", score: -3.195),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()
    [
      ("()&()&(ㄨㄛˇ,我)", "我"),
      ("()&(ㄋㄧˇ,你)&(ㄊㄚ-ㄇㄚ-ㄉㄜ˙,他媽的)", "他媽的"),
      ("(ㄗㄞˋ,再)&(ㄍㄣ-ㄨㄛˇ-ㄕㄨㄛ,跟我說)&(ㄧ,一)", "一邊"),
    ].forEach {
      testHandler.currentLM.memorizePerception(
        (ngramKey: $0.0, candidate: $0.1),
        timestamp: Date().timeIntervalSince1970
      )
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.syncPrefs()

    typeSentence("tamade")
    // 置頂候選仍為 POM 建議「他媽的」，且全窗僅出現一次。
    #expect(testSession.state.candidates.first?.value == "他媽的")
    #expect(testSession.state.candidates.filter { $0.value == "他媽的" }.count == 1)
    #expect(!testSession.state.candidates.contains {
      $0.value == "他媽的" && $0.keyArray != ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"]
    })
  }

  /// 狂拼 POM 建議段數上限（P169 fail-first）：`tama`（組字器 1 鍵＋注拼槽 1 鍵，
  /// copilot 2 鍵）時，copilot 窗**不得**置頂 3 段「他媽的」POM 建議——段數溢出
  /// （建議 3 段 > copilot 可承接 2 鍵）與組字器鍵數脫節，就地選中會造成讀音重疊。
  /// 對照 IH-FuriousPinyin-052（`tamade` 時 copilot 3 鍵、3 段建議 == 可承接鍵數、照常置頂）。
  @Test("IH-FuriousPinyin-053 Furious copilot window rejects oversized POM suggestion")
  func test_IH_FuriousPinyin_053_FuriousCopilotWindowRejectsOversizedPOMSuggestion() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    [
      .init(keyArray: ["ㄊㄚ"], value: "他", score: -5.024),
      .init(keyArray: ["ㄊㄚ"], value: "她", score: -5.045),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -5.169),
      .init(keyArray: ["ㄇㄚ"], value: "嗎", score: -5.113),
      .init(keyArray: ["ㄉㄜ˙"], value: "的", score: -4.971),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ"], value: "他媽", score: -8.713),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"], value: "他媽的", score: -5.405),
      .init(keyArray: ["ㄇㄚ", "ㄇㄚ˙"], value: "媽媽", score: -3.195),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()
    [
      ("()&()&(ㄨㄛˇ,我)", "我"),
      ("()&(ㄋㄧˇ,你)&(ㄊㄚ-ㄇㄚ-ㄉㄜ˙,他媽的)", "他媽的"),
      ("(ㄗㄞˋ,再)&(ㄍㄣ-ㄨㄛˇ-ㄕㄨㄛ,跟我說)&(ㄧ,一)", "一邊"),
    ].forEach {
      testHandler.currentLM.memorizePerception(
        (ngramKey: $0.0, candidate: $0.1),
        timestamp: Date().timeIntervalSince1970
      )
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.syncPrefs()

    // tama：copilot 2 鍵——3 段「他媽的」不得置頂。
    typeSentence("tama")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(!testSession.state.candidates.contains { $0.value == "他媽的" })

    // 對照：tamade（組字器 [ㄊㄚ,ㄇㄚ]＋注拼槽 de，copilot 3 鍵）——3 段建議照常置頂。
    testHandler.clearComposerAndCalligrapher()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.assembler.clear()
    typeSentence("tamade")
    #expect(testHandler.assembler.keys.count == 2)
    #expect(testSession.state.candidates.first?.value == "他媽的")
  }

  /// 狂拼模式下直接敲標點鍵不蜂鳴（P170 fail-first）：注拼槽尚有未完成讀音
  /// （如「tama」的「ma」）時敲問號等標點鍵，不得再以 A9B69908D 蜂鳴——
  /// 先以空格／Tab／Enter 同語義把前方讀音固化進組字器，再讓標點正常插入
  /// （注拼槽清空、標點鍵被消費、組句含標點）。
  @Test("IH-FuriousPinyin-054 Furious punctuation solidifies then inserts")
  func test_IH_FuriousPinyin_054_FuriousPunctuationSolidifiesThenInserts() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    var errorMessages: [String] = []
    defer {
      testHandler.errorCallback = nil
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 與 IH-FuriousPinyin-051/151/152 同源：真實 factory 詞庫相關詞條（ㄊㄚ／ㄇㄚ 桶）。
    [
      .init(keyArray: ["ㄊㄚ"], value: "他", score: -5.024),
      .init(keyArray: ["ㄊㄚ"], value: "她", score: -5.045),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -5.169),
      .init(keyArray: ["ㄇㄚ"], value: "嗎", score: -5.113),
      .init(keyArray: ["ㄊㄚ", "ㄇㄚ"], value: "他媽", score: -8.713),
      .init(keyArray: ["ㄇㄚ", "ㄇㄚ˙"], value: "媽媽", score: -3.195),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()
    testHandler.errorCallback = { errorMessages.append($0) }

    // 打「tama」：組字器 [ㄊㄚ桶]＋注拼槽 "ma"。
    typeSentence("tama")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "ma")

    // 直接敲「？」（無修飾鍵）：標點鍵被消費、不再蜂鳴 A9B69908D。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData(flags: [], chars: "?").asEvent))
    #expect(!errorMessages.contains("A9B69908D"))
    // 前方讀音已固化：注拼槽清空、組字器鍵數 1→3（固化ㄇㄚ桶＋標點鍵）。
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.keys.count == 3)
    // 組句顯示含全形問號。
    #expect(testSession.state.displayedText.contains("？"))
  }

  /// 狂拼長簡拼字母流不被注拼槽音頭丟棄截斷（「slliang」不得變成「lliang」）。
  ///
  /// 使用者回報：敲「slliang」只出現「力量」等「ㄌㄧˋ ㄌㄧㄤˋ」二字詞、且開頭的
  /// 「s」像沒敲過似的；敲「sllian」則正常。根因：Tekkon 注拼槽的 romajiBuffer
  /// 預設以「單音節最長 6 碼」為上限、超出即丟棄最早輸入的音頭——「slliang」
  /// 為 7 字元，敲入最後一個「g」時開頭的「s」被靜默截斷、buffer 變「lliang」，
  /// 後續簡拼整詞查詢便以「lliang」為準（命中「力量」類 ㄌ-ㄌㄧㄤ 詞）。修復：
  /// 狂拼模式（`isFuriousTypingModeEffective`）下注拼槽關閉音頭丟棄。
  @Test("IH-FuriousPinyin-055 Furious long abbreviation keeps front letters")
  func test_IH_FuriousPinyin_055_FuriousLongAbbreviationKeepsFrontLetters() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「slliang」＝7 字元、超過注拼槽預設 6 碼上限；修復前「s」被音頭丟棄、
    // buffer 變「lliang」。修復後完整保留「slliang」。
    typeSentence("slliang")
    #expect(testHandler.composer.romajiBuffer == "slliang")
    #expect(testSession.state.type == .ofInputting)
  }

  /// 狂拼執行期狀態之複位粒度：`clear()`（狀態重置）清整批；`invalidateFuriousTrail()`（顯式干涉）只清 trail。
  ///
  /// 前者防「上一輪殘留之高亮／重切 offers 跨過重置邊界、被下一輪當成當拍狀態消費」；
  /// 後者則須保留當拍尚在消費週期內之高亮與 offers（否則 copilot 窗之預覽與聯合重切會失效）。
  @Test("IH-FuriousPinyin-056 Furious config reset granularity")
  func test_IH_FuriousPinyin_056_FuriousConfigResetGranularity() throws {
    let (testHandler, _) = try prepareMixedModeHandler()
    defer { testHandler.clear() }

    let perPassOffer = FuriousCoSegmentedOffer(
      keyArray: ["ㄈㄢ", "ㄍㄢ"],
      value: "反感",
      blobs: ["fan", "gan"],
      weight: 1.0
    )

    func seedPerPassState() {
      testHandler.furiousConfig.trail = ["fan", "gan"]
      testHandler.furiousHighlightOverride = (["ㄈㄢ"], "反")
      testHandler.furiousConfig.coSegmentedOffers = [perPassOffer]
    }

    seedPerPassState()
    testHandler.invalidateFuriousTrail()
    #expect(testHandler.furiousConfig.trail.isEmpty, "顯式干涉應清空 trail")
    #expect(testHandler.furiousHighlightOverride?.value == "反", "顯式干涉不應清當拍高亮")
    #expect(testHandler.furiousConfig.coSegmentedOffers.count == 1, "顯式干涉不應清當拍重切 offers")

    testHandler.clear()
    #expect(
      testHandler.furiousConfig == FuriousTypingConfig(),
      "`clear()` 應將狂拼之整批執行期狀態複位（trail＋當拍狀態）"
    )
  }

  /// 狂拼 copilot 跨邊界整詞列舉（P183）：前段已提交為多鍵節點「電腦」、尾段打 `ban` 時，
  /// copilot 除了組句預覽（版）與尾段單字外，亦列出覆蓋「前段＋尾段」的整詞
  /// （電腦班／電腦版）——既有末鍵（L=1）雙鍵查詢涵蓋不到的長度。
  @Test("IH-FuriousPinyin-057 Furious copilot lists cross-boundary whole words")
  func test_IH_FuriousPinyin_057_FuriousCopilotListsCrossBoundaryWholeWords() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄉㄧㄢˋ"], value: "電", score: -6),
      .init(keyArray: ["ㄋㄠˇ"], value: "腦", score: -6),
      .init(keyArray: ["ㄅㄢ"], value: "班", score: -2),
      .init(keyArray: ["ㄅㄢˇ"], value: "版", score: -3),
      .init(keyArray: ["ㄉㄧㄢˋ", "ㄋㄠˇ"], value: "電腦", score: -9),
      .init(keyArray: ["ㄉㄧㄢˋ", "ㄋㄠˇ", "ㄅㄢ"], value: "電腦班", score: -10),
      .init(keyArray: ["ㄉㄧㄢˋ", "ㄋㄠˇ", "ㄅㄢˇ"], value: "電腦版", score: -11),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 記憶時戳一律以「現在」為基準。LXPerceptor.calculateWeight 對年齡達 wT（預設 8 天）
    // 的記憶直接淘汰（`daysDiff >= wT` → threshold - 0.001），故任何寫死的絕對時戳都會讓
    // 本測試在該時戳之後第 8 天起必然轉紅——P183 原版即寫死 `1_788_459_361`（2026-09-04），
    // 於 2026-09-12 屆期失效。
    let ts: Double = Date().timeIntervalSince1970 - 60
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄉㄧㄢˋ,電)&(ㄋㄠˇ,腦)&(ㄅㄢˇ,版)", candidate: "版"), timestamp: ts
    )
    testHandler.currentLM.memorizePerception(
      (ngramKey: "()&()&(ㄉㄧㄢˋ-ㄋㄠˇ,電腦)", candidate: "電腦"), timestamp: ts + 10
    )
    testHandler.currentLM.memorizePerception(
      (ngramKey: "()&(ㄉㄧㄢˋ-ㄋㄠˇ,電腦)&(ㄅㄢˇ,版)", candidate: "版"), timestamp: ts + 20
    )

    typeSentence("diannaoban")
    #expect(testHandler.composer.romajiBuffer == "ban")

    let candidates = testHandler.furiousTypingFrontCandidates ?? []
    // 置頂為組句預覽（版）；第二位起為覆蓋前段＋尾段的整詞（電腦班），並含電腦版。
    #expect(candidates.first?.value == "版")
    #expect(candidates.dropFirst().first?.value == "電腦班")
    #expect(candidates.contains { $0.value == "電腦版" })
  }

  // MARK: - Test harness

  /// 建立「fangan → 反感」重切分測試用的詞庫：
  /// 支撐單字（方／安／反／感）與高分的「反感」雙音節詞，讓兩種切分都能在庫組句。
  private func insertFangAnResegmentationFixture(testHandler: MockInputHandler?) {
    guard let testHandler else { return }
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄈㄤ"], value: "方", score: -6),
      .init(keyArray: ["ㄢ"], value: "安", score: -6),
      .init(keyArray: ["ㄈㄢˇ"], value: "反", score: -6),
      .init(keyArray: ["ㄍㄢˇ"], value: "感", score: -6),
      .init(keyArray: ["ㄈㄢˇ", "ㄍㄢˇ"], value: "反感", score: -7),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
  }

  /// 建構給定注音讀音的無調候選桶（與自動 chop 的展開語義一致）。
  private func furiousTestBucket(for zhuyin: String) -> [String] {
    Tekkon.allowedIntonations.map { tone in
      zhuyin + ((tone != " ") ? String(tone) : "")
    }
  }

  /// 建立「shijie → 世界」固化測試用的詞庫：
  /// 支撐單字（世／界）與高分的「世界」雙音節詞。
  func insertShiJieSolidificationFixture(testHandler: MockInputHandler?) {
    guard let testHandler else { return }
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世", score: -6),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界", score: -6),
      .init(keyArray: ["ㄕˋ", "ㄐㄧㄝˋ"], value: "世界", score: -7),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
  }

  /// 建立「shijie → 世界」顯示/遞交測試用的詞庫：
  /// [ㄕ] 單獨組句為高頻「是」，但 [ㄕˋ,ㄐㄧㄝˋ] 的「世界」雙音節詞更強，
  /// 使 main 組字器組句「是」、copilot 聯合組句「世界」。
  private func insertShiJieDisplayFixture(testHandler: MockInputHandler?) {
    guard let testHandler else { return }
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -5),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界", score: -6),
      .init(keyArray: ["ㄕˋ", "ㄐㄧㄝˋ"], value: "世界", score: -6.5),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
  }

  /// 建立「xi an → 西安」長詞合併測試用的詞庫：
  /// 支撐單字（西／安）與高分（勝過「西＋安」雙單字組句）的「西安」雙音節詞。
  private func insertXiAnLongWordFixture(testHandler: MockInputHandler?) {
    guard let testHandler else { return }
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄒㄧ"], value: "西", score: -6),
      .init(keyArray: ["ㄢ"], value: "安", score: -6),
      .init(keyArray: ["ㄒㄧ", "ㄢ"], value: "西安", score: -7),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
  }
}
