// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 狂打（狂拼／狂注）copilot 候選窗之閘門與「未完成讀音」顯示源：行為層測試。
//
// 本檔驗的是「注音狂打接入 copilot 窗」這條線：`hasFuriousFrontPending` 之兩側分流、
// `unfinishedReading` 之分流、以及既有 6 個前方讀取點在注音下之語義。
// 判準（何時自動切音節）之測試在 `InputHandlerTests_ZhuyinFurious.swift` 與
// `TekkonTests_PhonabetAutoChopPredicate.swift`（自 P261 起住 `Tests/TekkonTests/`）。
//
// - Note: 大千排列之鍵位：ㄍ＝`e`、ㄠ＝`l`。測試辭典內 `ㄍㄠ`＝高（同音 12 條）。

import Foundation
import Homa
import Shared
import Tekkon
import Testing

@testable import LibVanguard

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: - 環境設置

  /// 把測試環境切成注音狂打（其餘輸入法一律關閉），並重置組字狀態。
  private func enterZhuyinFuriousTestEnvironment(
    parser: Tekkon.MandarinParser = .ofDachen
  ) {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false // 免 POM 擾動置頂序。
    testHandler.composer.ensureParser(arrange: parser)
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 把測試環境切成拼音狂拼（其餘輸入法一律關閉），並重置組字狀態。
  private func enterPinyinFuriousTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.ensureKeyboardParser()
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 還原環境：兩側狂打開關歸零、鍵盤排列回標準注音。
  private func leaveFuriousTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  // MARK: - 未完成讀音之分流

  /// 注音狂打之「未完成讀音」顯示源即注拼槽內當前音節；空槽時為 `nil`。
  ///
  /// 並釘住判準之單一性：`hasFuriousFrontPending` 與 `furiousFrontUnfinishedReading != nil`
  /// 必須恆等（否則會出現「copilot 窗開了、頂部 pane 卻無讀音可示」之狀態）。
  @Test("[IH160] 注音狂打：未完成讀音之分流與判準一致性")
  func test_IH160_UnfinishedReadingIsTheComposerSyllableInZhuyinFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)

    // 空槽：無讀音可示 ⇒ 顯示源與旗子皆落。
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)

    // 只有聲調、尚無聲介韻：注拼槽「非空」但無讀音可示 —— 顯示源仍為 nil
    // （此即注音側「未完成讀音」與「注拼槽非空」之分野）。
    testHandler.composer.receiveKey(fromString: "3") // 大千排列之 3＝ˇ
    #expect(!testHandler.composer.isEmpty)
    #expect(testHandler.composer.getComposition() == "ˇ")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)

    // 逐鍵：ㄍ → ㄍㄠ，顯示源即該音節之注音原字串。
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("e")
    #expect(testHandler.composer.getComposition() == "ㄍ")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄍ")
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == "ㄍ")

    typeSentence("l")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄍㄠ")
    #expect(testSession.unfinishedReading == "ㄍㄠ")

    // 固化（空格）之後：顯示源與旗子同步落回 nil。
    typeSentence(" ")
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)
  }

  /// 拼音狂拼之 `hasFuriousFrontPending` 語意**不得**因注音側之分流而改變。
  @Test("[IH165] 拼音狂拼：未完成讀音語意不變（回歸護欄）")
  func test_IH165_PinyinFuriousPendingSemanticsUnchanged() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterPinyinFuriousTestEnvironment()
    #expect(testHandler.typingMode == .pinyinFuriousTyping)

    // 狂拼停用時：字母流非空亦不得視為「前方待確認讀音」（沿用舊語意）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    typeSentence("gao")
    #expect(testHandler.composer.romajiBuffer == "gao")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 狂拼啟用時：字母流即顯示源。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    typeSentence("gao")
    #expect(testHandler.composer.romajiBuffer == "gao")
    #expect(testHandler.furiousFrontUnfinishedReading == "gao")
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == "gao")

    // 固化後（空格）旗子落回。
    typeSentence(" ")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == nil)
  }

  // MARK: - copilot 窗與就地選字

  /// 注音狂打且有未完成音節時，copilot 候選窗成立、置頂為該音節之組句預覽；
  /// 就地選字（滑鼠點選／Shift＋選字鍵同此路徑）把該音節以所選值寫入組字器。
  @Test("[IH161] 注音狂打：copilot 窗成立與就地選字")
  func test_IH161_ZhuyinFuriousCopilotWindowAndInPlaceSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()

    // 空槽：窗不成立。
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)

    // ㄍㄠ 尚在注拼槽（未固化）⇒ copilot 窗成立，置頂為組句預覽「高」。
    typeSentence("el")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(testSession.unfinishedReading == "ㄍㄠ")
    guard testSession.state.candidates.count >= 2 else {
      Issue.record("ㄍㄠ 之 copilot 候選不足兩筆：\(testSession.state.candidates.map(\.value))")
      return
    }
    #expect(testSession.state.candidates.first?.value == "高")

    // 就地選字：挑一筆「非置頂」候選，確認後組字器須呈現該值（證明覆寫生效，
    // 而非僅是語言模型自己也會選的置頂值）。
    let target = testSession.state.candidates[1]
    testSession.candidatePairSelectionConfirmed(at: 1)
    #expect(testHandler.composer.isEmpty, "就地選字後注拼槽應清空。")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(generateDisplayedText() == target.value, "實得：\(generateDisplayedText())")
    // 音節既已入組字器，前方上下文消失 ⇒ copilot 窗不再成立。
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(testSession.unfinishedReading == nil)
  }

  // MARK: - 既有前方讀取點於注音下之語義

  /// 既有 6 個 `hasFuriousFrontPending` 讀取點，在注音狂打下逐一驗其語義。
  ///
  /// Tab／Enter／標點／方向鍵皆為「先固化前方讀音，再走各自既有語義」——注音側悉數沿用。
  /// **空格不在此列**（P260）：注音之五個聲調鍵為 `3`／`4`／`6`／`7` 與**空格**（陰平），
  /// 空格若被挪作固化之用則陰平無從指定 ⇒ 空格照常送入注拼槽當陰平（見 ①）。
  @Test("[IH162] 注音狂打：空格／Tab／Enter／標點／方向鍵之語義")
  func test_IH162_FrontReadPointsUnderZhuyinFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()

    /// 重置環境、鍵入 `ㄍㄠ`（前方待確認讀音成立）。
    func prepareTwoPendingKeys() {
      enterZhuyinFuriousTestEnvironment()
      typeSentence("el")
      #expect(testHandler.composer.getComposition() == "ㄍㄠ")
      #expect(testHandler.hasFuriousFrontPending)
    }

    // ① 空格（P260）：**空格即陰平鍵**，且陰平須確實被選用——測資刻意令去聲候選之分數遠高於
    //    陰平（−0.1 對 −9）：若空格仍走「無調讀音桶」之路徑（P256 之過寬語義），語言模型會
    //    挑走去聲者；本 phase 之後應得陰平者。
    [
      Homa.Gram(keyArray: ["ㄍㄠ"], value: "陰平測", score: -9),
      Homa.Gram(keyArray: ["ㄍㄠˊ"], value: "陽平測", score: -9),
      Homa.Gram(keyArray: ["ㄍㄠˇ"], value: "上聲測", score: -9),
      Homa.Gram(keyArray: ["ㄍㄠˋ"], value: "去聲測", score: -0.1),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    prepareTwoPendingKeys()
    typeSentence(" ")
    // 鍵須為陰平者（單鍵 ㄍㄠ）；顯示值則取決於辭庫內陰平鍵之分數，故不釘字面值——
    // 但**不得**為去聲者：若空格仍走無調桶之路徑，去聲候選（−0.1）必被選中（實測如此）。
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(generateDisplayedText() != "去聲測", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.isEmpty)
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    #expect(!generateDisplayedText().contains(" "))

    // ② Enter：固化前方讀音、停留在輸入狀態（不直接遞交全部內容）。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.type == .ofInputting, "實得：\(testSession.state.type)")

    // ③ Tab：先固化前方讀音，再讓本事件續走正常流程（注拼槽既空，輪替留給該流程）。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.type == .ofInputting, "實得：\(testSession.state.type)")

    // ④ 無修飾前後方向鍵（W3 規則）：固化前方讀音＋開出正常選字窗。
    prepareTwoPendingKeys()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")

    // ⑤ 標點：固化前方讀音之後才處理標點（未完成讀音不再擋下標點輸入）。
    // 註：大千排列之 `,` 本身就是注音符號鍵（ㄝ），故 `,` 走的是自動切音節鏈路、
    // 而非標點鏈路；標點讀取點須以「非注音鍵之標點」驅動。
    prepareTwoPendingKeys()
    typeSentence("[")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄠ", "_punctuation_["],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.composer.isEmpty,
      "實得：\(testHandler.composer.getComposition())；狀態：\(testSession.state.type)"
    )

    // ⑤′ 大千排列之 `,`＝ㄝ：新音節不可能接續 `ㄍㄠ` ⇒ 自動切音節先固化 `ㄍㄠ`，
    // 該鍵再作為新音節之韻母進入注拼槽（與標點鏈路無涉）。
    prepareTwoPendingKeys()
    typeSentence(",")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(
      testHandler.composer.getComposition() == "ㄝ",
      "實得：\(testHandler.composer.getComposition())"
    )
  }
}

// MARK: - 注音簡拼（P260）

extension LibVanguardTestsRoot.InputHandlerTests {
  /// 注音簡拼之 cells ＝「組字器尾段之單注音鍵（至多 3）＋ 注拼槽之當前讀音」。
  ///
  /// 三條界線同時釘住：① 少於 2 格不成立（單一格即整個聲母家族）；② 序列跨「已自動切出
  /// 之單注音」與「注拼槽內待確認者」；③ **遇完整音節即停**（該鍵不是任何讀音之起頭候選）。
  @Test("[IH166] 注音狂打：簡拼 cells 之還原與界線")
  func test_IH166_ZhuyinAbbreviationCells() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()

    // 空槽：無 cells。
    #expect(testHandler.furiousZhuyinAbbreviationCells == nil)

    // 僅一格（注拼槽內一個注音）：nil——單一格即整個聲母家族，作簡拼查詢無資訊量。
    typeSentence("e") // ㄍ
    #expect(testHandler.composer.getComposition() == "ㄍ")
    #expect(testHandler.furiousZhuyinAbbreviationCells == nil)

    // 兩格：ㄍ 已自動切出、注拼槽為 ㄋ。
    typeSentence("s") // ㄋ
    #expect(testHandler.assembler.actualKeys == ["ㄍ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.getComposition() == "ㄋ")
    #expect(
      testHandler.furiousZhuyinAbbreviationCells == ["ㄍ", "ㄋ"],
      "實得：\(testHandler.furiousZhuyinAbbreviationCells ?? [])"
    )

    // 三格：即事主之例「ㄍㄋㄋ」。
    typeSentence("s") // ㄋ
    #expect(
      testHandler.assembler.actualKeys == ["ㄍ", "ㄋ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.furiousZhuyinAbbreviationCells == ["ㄍ", "ㄋ", "ㄋ"],
      "實得：\(testHandler.furiousZhuyinAbbreviationCells ?? [])"
    )

    // 遇完整音節即停：先鍵入 ㄍㄠ（自動切出、兩符號），再鍵入 ㄋ ⇒ cells 不含 ㄍㄠ、且僅一格 ⇒ nil。
    enterZhuyinFuriousTestEnvironment()
    typeSentence("els") // ㄍㄠ → ㄋ
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.getComposition() == "ㄋ")
    #expect(testHandler.furiousZhuyinAbbreviationCells == nil)
    // 於該完整音節之後再續一個單注音：仍以「尾段單注音鏈」為界（不含 ㄍㄠ）。
    typeSentence("s")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ", "ㄋ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(
      testHandler.furiousZhuyinAbbreviationCells == ["ㄋ", "ㄋ"],
      "實得：\(testHandler.furiousZhuyinAbbreviationCells ?? [])"
    )
  }

  /// 注音簡拼之整詞候選：`ㄍㄋㄋ` ⇒ copilot 窗得 `狗男女`，就地選字後三段讀音與詞值一次就位。
  ///
  /// 此即事主之原始用例（「打 ㄍㄋㄋ 可以預覽到狗男女」）在**注音側**之落地。
  @Test("[IH167] 注音狂打：簡拼整詞候選與就地選字")
  func test_IH167_ZhuyinAbbreviationCandidatesAndInPlaceSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄍㄡˇ", "ㄋㄢˊ", "ㄋㄩˇ"], value: "狗男女", score: -6.6),
      isFiltering: false
    )

    typeSentence("ess") // ㄍㄋㄋ
    #expect(testHandler.composer.getComposition() == "ㄋ")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    // P261：三音節之真詞須**居首**——待確認音節 ㄋ 之讀音原字串回退值不得再置頂
    // （事主 2026-09-26 之實機：該回退值曾佔據第 1 名、把「狗男女」壓至第 2 名）。
    #expect(
      testSession.state.candidates.first?.value == "狗男女",
      "實得：\(testSession.state.candidates.map(\.value))"
    )
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "狗男女" }) else {
      Issue.record("簡拼候選「狗男女」未入 copilot 窗：\(testSession.state.candidates.map(\.value))")
      return
    }

    // 就地選字：三段讀音一次就位（尾段之單注音鍵一併被覆寫）、注拼槽清空。
    testSession.candidatePairSelectionConfirmed(at: index)
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄡˇ", "ㄋㄢˊ", "ㄋㄩˇ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(generateDisplayedText() == "狗男女", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.isEmpty)
  }

  /// 簡拼整詞候選**不得長於**當前 furious reading 所配對之格數（上界；P262）。
  ///
  /// 事主 2026-09-28 之實機：使用者語彙資料內有「科技獎 ㄎㄜ-ㄐㄧˋ-ㄐㄧㄤˇ」時，
  /// 注音狂打之 `ㄎㄐ`（大千 `dr`）與拼音狂打之 `kj` 皆為**兩格**，而 copilot 窗會出現
  /// **三音節**之「科技獎」——注音側居首（排序鍵為段數降冪）、拼音側居末（α 路徑照
  /// 語言模組序）。根因在使用者片語側之多位置前綴掃描忽略多出的段：簡拼查詢之兩分區
  /// 本應受同一上界約束（原廠側之 trie 查詢恆為等段）。
  ///
  /// 本靶四臂：兩模式 × （兩格＝不得出現／三格＝須出現），並以就地選字證明三格者確實
  /// 可套用（兩格情境下若仍顯示，選中即會寫入使用者從未敲下之音節）。
  @Test("[IH169] 狂打：簡拼整詞候選之等段界線（注音／拼音兩側）")
  func test_IH169_AbbreviationCandidatesStayWithinPairedSegmentCount() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    // 三音節者（＝事主所見之洩漏源）＋兩音節者（等段之正對照）＋近分競爭者
    // （後者令拼音側之 α 自動套用因「非明確勝出」而不觸發，窗與注拼槽得以留存）。
    [
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤˇ"], value: "科技獎", score: -6.0),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤ"], value: "科技江", score: -6.5),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科記", score: -6.2),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }

    // ① 注音狂打 `ㄎㄐ`（兩格）：兩音節者入窗、三音節者不得入窗。
    enterZhuyinFuriousTestEnvironment()
    typeSentence("dr")
    #expect(
      testHandler.furiousZhuyinAbbreviationCells == ["ㄎ", "ㄐ"],
      "實得：\(testHandler.furiousZhuyinAbbreviationCells ?? [])"
    )
    var values = testSession.state.candidates.map(\.value)
    #expect(values.contains("科記"), "實得：\(values)")
    #expect(!values.contains("科技獎"), "實得：\(values)")

    // ② 注音狂打 `ㄎㄐㄐ`（三格）：三音節者入窗、兩音節者退場；就地選字三段讀音一次就位。
    typeSentence("r")
    #expect(
      testHandler.furiousZhuyinAbbreviationCells == ["ㄎ", "ㄐ", "ㄐ"],
      "實得：\(testHandler.furiousZhuyinAbbreviationCells ?? [])"
    )
    values = testSession.state.candidates.map(\.value)
    #expect(values.contains("科技獎"), "實得：\(values)")
    #expect(!values.contains("科記"), "實得：\(values)")
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "科技獎" }) else {
      Issue.record("簡拼候選「科技獎」未入 copilot 窗：\(values)")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: index)
    #expect(
      testHandler.assembler.actualKeys == ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤˇ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(generateDisplayedText() == "科技獎", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.isEmpty)

    // ③ 拼音狂打 `kj`（兩格）：同上之界線（α 路徑之窗）。
    testSession.resetInputHandler(forceComposerCleanup: true)
    enterPinyinFuriousTestEnvironment()
    typeSentence("kj")
    #expect(
      testHandler.furiousAbbreviatedCells == ["ㄎ", "ㄐ"],
      "實得：\(testHandler.furiousAbbreviatedCells ?? [])"
    )
    values = testSession.state.candidates.map(\.value)
    #expect(values.contains("科記"), "實得：\(values)")
    #expect(!values.contains("科技獎"), "實得：\(values)")

    // ④ 拼音狂打 `kjj`（三格）：三音節者入窗（近分競爭者使之不觸發 α 自動套用）。
    typeSentence("j")
    #expect(
      testHandler.furiousAbbreviatedCells == ["ㄎ", "ㄐ", "ㄐ"],
      "實得：\(testHandler.furiousAbbreviatedCells ?? [])"
    )
    values = testSession.state.candidates.map(\.value)
    #expect(values.contains("科技獎"), "實得：\(values)")
    #expect(!values.contains("科記"), "實得：\(values)")
  }

  /// 簡拼整詞候選之順序與拼音 α 窗一致；該序即**分數序**（跨原廠與使用者片語兩來源合併）。
  ///
  /// 窗內同段數時：**語境候選**（由已提交鍵／待確認音節推得者）先於**簡拼整詞候選**；
  /// 簡拼整詞候選為一個區塊、其內依**語言模組回傳之分數序**——查詢已跨來源合併排序，
  /// 故分數更高之使用者片語命中得越過分數較低之原廠命中（事主 2026-09-28 之裁定）。
  /// 本靶以同一組語料驅動兩模式、比對共同候選之相對順序；拼音側（α 路徑＝單一來源）即基準。
  @Test("[IH170] 狂打：簡拼整詞候選之順序與拼音 α 窗一致")
  func test_IH170_AbbreviationCandidateOrderMatchesPinyinAlphaWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    // 兩音節之使用者片語（與測試辭典內之原廠命中「科技」「科際」同讀音）＋三音節者。
    [
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤˇ"], value: "科技獎", score: -6.0),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤ"], value: "科技江", score: -6.5),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科記", score: -6.2),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }

    // ① 拼音狂打 `kj`（α 路徑）：分數序——科記（−6.2，使用者片語）越過科際（−6.237，原廠）。
    enterPinyinFuriousTestEnvironment()
    typeSentence("kj")
    let pinyinValues = testSession.state.candidates.map(\.value)
    #expect(pinyinValues == ["科技", "科記", "科際"], "實得：\(pinyinValues)")

    // ② 注音狂打 `ㄎㄐ`：共同候選之相對順序須與拼音側逐項相同；待確認音節之讀音原字串
    //    回退值（桶釘候選）仍沉於同段數之真詞之後（P261 之裁定不變）。
    testSession.resetInputHandler(forceComposerCleanup: true)
    enterZhuyinFuriousTestEnvironment()
    typeSentence("dr")
    let zhuyinValues = testSession.state.candidates.map(\.value)
    #expect(zhuyinValues == ["科技", "科記", "科際", "ㄐ"], "實得：\(zhuyinValues)")
    let pinyinSet = Set(pinyinValues)
    let commonInZhuyin = zhuyinValues.filter { pinyinSet.contains($0) }
    #expect(commonInZhuyin == pinyinValues, "注音：\(commonInZhuyin)；拼音：\(pinyinValues)")
  }

  /// 控頻：**雷同之詞音配對**（同值同讀音）之權重以使用者辭典者為最優先——狂打 copilot 窗隨之改序。
  ///
  /// 事主 2026-09-28 之指示：「整詞簡拼查詢之同值去重的規則需要對狂打模式也適用：對於雷同的
  /// 詞音配對而言，其權重以使用者辭典內的權重為最優先。」通用查詢路徑本即以「使用者片語置前」
  /// 實現此語義，整詞簡拼查詢則否；本靶以測試辭典內既存之兩筆原廠命中（科技 ㄎㄜ-ㄐㄧˋ
  /// −3.311、科際 ㄎㄜ-ㄐㄧˋ −6.237）為雷同配對之對象，驗兩個方向：① **升頻**（科際 ⇒ −0.5）；
  /// ② **降頻**（科技 ⇒ −12.0）。
  /// - Important: 兩方向之可見效果皆以**分數序**呈現：被降頻之原廠配對必沉於分數更高之
  ///   使用者片語命中之後（事主 2026-09-28 之裁定），故兩臂之期望序皆為 `科際→科紀→科技`。
  ///
  /// - Important: 兩臂皆另注入一筆**近分競爭者**（科紀，使用者辭典）——否則「明確勝出」條件成立時，
  ///   R3-a 之自動套用會消費本拍並清空注拼槽，窗無從觀察（測試構造之條件，非生產碼之限制）。
  /// - Important: 有副作用之輔助函式（打鍵、切環境）**不得直接寫進 `#expect` 之運算式**——Swift
  ///   Testing 於診斷時會二次求值，該式將被執行兩遍（實錄：首遍得窗、次遍得空窗而誤報失敗）。
  @Test("[IH171] 狂打：控頻——雷同之詞音配對取使用者辭典之權重")
  func test_IH171_UserPhrasesControlFrequencyInFuriousWindows() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    enterZhuyinFuriousTestEnvironment()

    /// 以注音狂打 `ㄎㄐ` 取得窗內詞值序（副作用：重置組字狀態後打字）。
    func zhuyinWindowValues() -> [String] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      typeSentence("dr")
      return testSession.state.candidates.map(\.value)
    }

    /// 以拼音狂打 `kj` 取得 α 窗之詞值序（副作用：切環境、打字、再切回注音）。
    func pinyinWindowValues() -> [String] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      enterPinyinFuriousTestEnvironment()
      typeSentence("kj")
      let result = testSession.state.candidates.map(\.value)
      testSession.resetInputHandler(forceComposerCleanup: true)
      enterZhuyinFuriousTestEnvironment()
      return result
    }

    /// 以整詞簡拼查詢取得該詞之權重。
    func weight(of value: String) -> Double? {
      testHandler.currentLM.lxQuerier.abbreviatedWordCandidates(keysChopped: ["ㄎ", "ㄐ"])
        .first(where: { $0.current == value })?.probability
    }

    // ⓪ 基線：無使用者條目時，原廠側之兩筆命中（科技 −3.311 於科際 −6.237 之前）。
    let baselineZhuyin = zhuyinWindowValues()
    #expect(baselineZhuyin == ["科技", "科際", "ㄐ"], "實得：\(baselineZhuyin)")

    // ① 升頻：雷同配對（科際 ㄎㄜ-ㄐㄧˋ）之權重改取使用者側（−0.5）⇒ 躍居首位。
    [
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科際", score: -0.5),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科紀", score: -0.6),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    let boostedJi = weight(of: "科際")
    let boostedKe = weight(of: "科技")
    let boostedZhuyin = zhuyinWindowValues()
    let boostedPinyin = pinyinWindowValues()
    #expect(boostedJi == -0.5, "實得：\(boostedJi as Any)")
    #expect(boostedKe == -3.311, "非雷同者不受牽連；實得：\(boostedKe as Any)")
    #expect(boostedZhuyin == ["科際", "科紀", "科技", "ㄐ"], "實得：\(boostedZhuyin)")
    #expect(boostedPinyin == ["科際", "科紀", "科技"], "實得：\(boostedPinyin)")

    // ② 降頻：改把「科技」壓至 −12.0 ⇒ 沉於「科際」（−6.237）之下（覆寫為雙向）。
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    [
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科技", score: -12.0),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科紀", score: -6.5),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    let demotedKe = weight(of: "科技")
    let untouchedJi = weight(of: "科際")
    let demotedZhuyin = zhuyinWindowValues()
    let demotedPinyin = pinyinWindowValues()
    #expect(demotedKe == -12.0, "實得：\(demotedKe as Any)")
    #expect(untouchedJi == -6.237, "實得：\(untouchedJi as Any)")
    // 降頻之核心斷言：科技（−12.0）沉於科紀（−6.5）之後——分區陳列已不再遮蔽分數序。
    #expect(demotedZhuyin == ["科際", "科紀", "科技", "ㄐ"], "實得：\(demotedZhuyin)")
    #expect(demotedPinyin == ["科際", "科紀", "科技"], "實得：\(demotedPinyin)")
  }

  /// 「名次」一律**按分數取**，不看清單位置——α 固化（空格／Tab）與 R3-a 自動套用皆然。
  ///
  /// 名次即分數；本靶以「使用者專有詞（原廠無此詞）之分數高於所有原廠命中、且其讀音與
  /// 原廠命中互異」之構造，令兩者之判別成為可觀測之別（窗內首位即該詞，固化亦取之）：
  /// ① **固化**（空格）：取分數最高者之讀音 ⇒ 顯示該使用者詞；取清單首筆則會插入原廠命中
  ///    之讀音、顯示成原廠詞（修前實錄）；
  /// ② **自動套用**（明確勝出）：頂級候選按分數取——即使該使用者詞在清單末位。
  @Test("[IH172] 狂打：α 固化與自動套用之『名次』按分數取")
  func test_IH172_AbbreviationRankIsScoreBased() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    enterPinyinFuriousTestEnvironment()

    // ① 固化：使用者專有詞「科吉」（ㄎㄜ-ㄐㄧˊ，−0.5）之分數高於兩筆原廠命中，惟其位置
    //    在清單末（分區制）；且與次高者（科技 −3.311）之差 < 3.0 ⇒ 不觸發自動套用、留待空格固化。
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄎㄜ", "ㄐㄧˊ"], value: "科吉", score: -0.5),
      isFiltering: false
    )
    typeSentence("kj")
    let windowBeforeSolidify = testSession.state.candidates.map(\.value)
    typeSentence(" ")
    let keysAfterSolidify = testHandler.assembler.actualKeys
    let displayAfterSolidify = generateDisplayedText()
    #expect(windowBeforeSolidify == ["科吉", "科技", "科際"], "實得：\(windowBeforeSolidify)")
    #expect(keysAfterSolidify == ["ㄎㄜ", "ㄐㄧˊ"], "實得：\(keysAfterSolidify)")
    #expect(displayAfterSolidify == "科吉", "實得：\(displayAfterSolidify)")

    // ② 自動套用：把兩筆原廠命中降頻以撐開差距（−8.0／−8.5），使用者詞（−0.5）因而「明確勝出」
    //    ⇒ 末鍵即自動套用該詞之讀音（即使它在清單末位）。
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    [
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˊ"], value: "科吉", score: -0.5),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科技", score: -8.0),
      Homa.Gram(keyArray: ["ㄎㄜ", "ㄐㄧˋ"], value: "科際", score: -8.5),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("kj")
    let keysAfterAutoApply = testHandler.assembler.actualKeys
    let displayAfterAutoApply = generateDisplayedText()
    #expect(testHandler.composer.romajiBuffer.isEmpty, "自動套用應清空注拼槽。")
    #expect(keysAfterAutoApply == ["ㄎㄜ", "ㄐㄧˊ"], "實得：\(keysAfterAutoApply)")
    #expect(displayAfterAutoApply == "科吉", "實得：\(displayAfterAutoApply)")
  }

  /// 注音狂打：copilot 交棒至標準選字窗之後，整詞候選仍須可見且可就地選字。
  ///
  /// 交棒後組字器內只有單注音格鍵（含固化後之聲調變體桶），而標準窗之候選係由既成節點推得
  /// （`assembler.fetchCandidates` ⇒ full match 之檢索結果，多為注音文回聲條目）⇒ 整詞候選
  /// 會消失。本靶釘四事：① 標準窗可見「狗男女」；② 其選取走狂打之套用路徑（鍵鏈換成該詞之
  /// 讀音、顯示正確）；③ 非前方候選者不受此路由；④ **打字途中組字器鍵鏈不被 partial 候選
  /// 改寫**（`config.partialMatchEnabled` 恆為假）——此即與「直接開 partial match 旗標」之別。
  @Test("[IH173] 注音狂打：交棒後之標準選字窗仍見整詞候選")
  func test_IH173_StandardWindowKeepsAbbreviationCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    enterZhuyinFuriousTestEnvironment()
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄍㄡˇ", "ㄋㄢˊ", "ㄋㄩˇ"], value: "狗男女", score: -6.6),
      isFiltering: false
    )

    // ① copilot 窗顯示期間：整詞候選在列，且組字器鍵鏈即所敲之單注音鍵。
    typeSentence("ess") // ㄍㄋㄋ
    let copilotValues = testSession.state.candidates.map(\.value)
    #expect(copilotValues.contains("狗男女"), "實得：\(copilotValues)")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍ", "ㄋ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(!testHandler.currentLM.config.partialMatchEnabled, "本 phase 不得開啟 partial match 旗標。")

    // ② 交棒：無修飾方向鍵 ⇒ 固化前方讀音（併入聲調變體桶）＋開出標準選字窗。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")
    let standardValues = testSession.state.candidates.map(\.value)
    #expect(standardValues.contains("狗男女"), "實得：\(standardValues)")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍ", "ㄋ", "ㄋ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(!testHandler.currentLM.config.partialMatchEnabled, "鍵鏈不得因 partial 檢索而被改寫。")

    // ③ 非前方候選者不經狂打之路由。
    #expect(
      !testHandler.confirmFuriousAbbreviatedCandidateFromStandardWindow(
        (keyArray: ["ㄋ"], value: "ㄋ")
      ),
      "非簡拼整詞候選不得走狂打套用路徑。"
    )

    // ④ 就地選字：鍵鏈換成該詞之讀音、顯示正確、注拼槽清空。
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == "狗男女" }) else {
      Issue.record("標準窗內無「狗男女」：\(standardValues)")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: index)
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄡˇ", "ㄋㄢˊ", "ㄋㄩˇ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(generateDisplayedText() == "狗男女", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.isEmpty)
  }

  // MARK: - 中英混合輸入回退對注音狂打之否決（P265）

  /// 「中英混合輸入回退」一旦啟用，注音狂打即**一律被視為關閉**（即便其開關仍為真）。
  ///
  /// 事主 2026-09-26 之實機回報：注音狂打開啟後，注音之中英混合輸入回退失效。根因即
  /// `typingMode` 之舊判定只問狂打開關 ⇒ `handleComposition` 把 ASCII 按鍵全數派給
  /// `BPMFFullMatchTypewriter`，回退模式**根本沒有執行機會**（而非「兩者相爭、回退落敗」）。
  ///
  /// 本靶釘四件事：
  /// ① 兩側旗子之語義（`InputHandler` 側之 `typingMode` 與三個狂打閘門）；
  /// ② **行為層**：回退須真的活著——ASCII 序列依序累積於緩衝、空格遞交原文（行為即
  ///   「按鍵確實改走 `MixedAlphanumericalTypewriter`」之鐵證，勝於斷言型別）；
  /// ③ 否決可逆：關掉回退後狂打即刻復活（否決者為偏好、非一次性狀態）；
  /// ④ **拼音側不受牽連**：回退本即注音鍵盤專屬，故 `4Pinyin` 與之無涉。
  @Test("[IH168] 中英混合輸入回退否決注音狂打（拼音側不受牽連）")
  func test_IH168_MixedAlnumVetoesZhuyinFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    // 大千排列（＝測試環境之預設，同 `MockedInputHandlerAndStates`）：ㄑ＝`f`、ㄛ＝`i`、ㄠ＝`l`、
    // ㄩ＝`m`，故 `film` 非任何合法讀音序列 ⇒ 應落入 ASCII 緩衝。
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()
    #expect(!testHandler.prefs.mixedAlphanumericalEnabled, "回退之出廠預設為關，本靶之前提。")

    // ① 基線：回退未啟用 ⇒ 注音狂打成立。
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.isPinyinFuriousTypingModeEffective)

    // ② 啟用回退 ⇒ 狂打悉數為假（開關仍為真，被否決者為「有效」）。
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.prefs.furiousTypingEnabled4Zhuyin, "開關不動——本靶要驗的是否決、不是改寫偏好。")
    #expect(
      testHandler.typingMode == .bopomofoKeyblock,
      "實得：\(testHandler.typingMode)"
    )
    #expect(!testHandler.isFuriousTypingModeEffective)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)

    // ③ 行為層：ASCII 序列累積於緩衝（狂打若仍生效，這些鍵會被當注音吸收、緩衝恆空）。
    typeSentence("film ")
    #expect(
      testSession.recentCommissions.joined() == "film ",
      "實得：\(testSession.recentCommissions.joined())"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "遞交後緩衝應清空。")
    #expect(testHandler.composer.isEmpty, "回退模式下不得有讀音被吸收進注拼槽。")

    // ④ 否決可逆：關掉回退後狂打即刻復活，且同批次按鍵改由狂打吸收。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    typeSentence("el") // ㄍㄠ
    #expect(
      testHandler.composer.getComposition() == "ㄍㄠ",
      "實得：\(testHandler.composer.getComposition())"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    // ⑤ 拼音側不受牽連：回退啟用下，拼音狂打仍成立。
    enterPinyinFuriousTestEnvironment()
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.typingMode == .pinyinFuriousTyping, "實得：\(testHandler.typingMode)")
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isPinyinFuriousTypingModeEffective)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective)
  }
}
