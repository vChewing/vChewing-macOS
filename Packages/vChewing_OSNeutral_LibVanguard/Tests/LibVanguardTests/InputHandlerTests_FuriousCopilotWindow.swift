// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 狂打（狂拼／狂注）copilot 候選窗之閘門與「未完成讀音」顯示源：行為層測試。
//
// 本檔驗的是「注音狂打接入 copilot 窗」這條線：`hasFuriousFrontPending` 之兩側分流、
// `unfinishedReading` 之分流、以及既有 6 個前方讀取點在注音下之語義。
// 判準（何時自動切音節）之測試在 `InputHandlerTests_ZhuyinFurious.swift` 與
// `ZhuyinAutoChopPredicateTests.swift`。
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
