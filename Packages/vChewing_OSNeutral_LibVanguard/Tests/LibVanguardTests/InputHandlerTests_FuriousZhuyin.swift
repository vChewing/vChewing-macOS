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

// 狂注（注音狂打）之行為層測試：自動切音節、簡拼整詞候選、未完成讀音之顯示源，
// 乃至其與中英混輸回退並存時之語義。
//
// 判準（何時自動切音節）本身之逐條移植與全排列實測見 `TekkonTests_PhonabetAutoChopPredicate.swift`
// （自 P261 起住 `Tests/TekkonTests/`）；此處驗的是「判準接上 Handler 之後」之行為。
// 所用讀音一律取自**測試辭典素材自身**（`vanguardTextMap_test.txtMap` 內確有之詞條）。
//
// - Note: 大千排列之鍵位：ㄍ＝`e`、ㄠ＝`l`、ㄨ＝`j`、ㄥ＝`/`、ㄅ＝`1`、ㄧ＝`u`、ㄢ＝`0`。

// MARK: - IH.FuriousZhuyin

extension LibVanguardTestsRoot.InputHandlerTests {
  /// **本 phase 之功能底線**：注音狂打下連續鍵入兩個完整音節，**不必敲聲調、不必按空格**，
  /// 即應各自成鍵入組字器。
  @Test("IH-FuriousZhuyin-001 Zhuyin furious auto-chops two consecutive syllables")
  func test_IH_FuriousZhuyin_001_ZhuyinFuriousAutoChopsConsecutiveSyllables() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    // `el`＝ㄍㄠ；再敲 `e`（ㄍ）時，`ㄍㄠ` 已不可能再延伸 ⇒ 應自動固化，注拼槽重設為 `ㄍ`；
    // 續敲 `j/`＝ㄨㄥ ⇒ 第二音節 `ㄍㄨㄥ`。全程未敲聲調、未按空格。
    var keys = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: true)
    // 第三拍（`e`）時 `ㄍㄠ` 已不可能再延伸 ⇒ 已固化；第二音節 `ㄍㄨㄥ` 尚在注拼槽內
    // （末音節之固化須待下一拍或空格——此與拼音狂拼之末端語義一致）。
    #expect(keys == ["ㄍㄠ"], "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄍㄨㄥ", "實得：\(testHandler.composer.getComposition())")
    #expect(generateDisplayedText().contains("高"), "組字結果：\(generateDisplayedText())")

    // 以空格固化末音節 ⇒ 兩音節皆入組字器。
    typeSentence(" ")
    keys = testHandler.assembler.actualKeys
    #expect(keys == ["ㄍㄠ", "ㄍㄨㄥ"], "實得：\(keys)")
    let displayed = generateDisplayedText()
    #expect(displayed.contains("高"), "組字結果：\(displayed)")
    #expect(!testSession.recentCommissions.isEmpty || !displayed.isEmpty)
  }

  /// 完整音節之逐鍵不得被誤切：`ㄅㄧ` ＋ `ㄢ` 須續接為 `ㄅㄧㄢ`（§3.2 之條件 ③）。
  @Test("IH-FuriousZhuyin-002 Incomplete syllable is not chopped")
  func test_IH_FuriousZhuyin_002_IncompleteSyllableIsNotChopped() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    // `1`＝ㄅ、`u`＝ㄧ、`0`＝ㄢ。三拍皆不得觸發切音節。
    let keys = typeZhuyinAndCollectReadingKeys("1u0", zhuyinFurious: true)
    #expect(keys.isEmpty, "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄅㄧㄢ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 動態排列之逐槽覆寫不得被誤切：大千26 之 `qquu`＝ㄅㄚ（§3.2 之 ④d）。
  @Test("IH-FuriousZhuyin-003 Dynamic layout slot overwrite is not chopped")
  func test_IH_FuriousZhuyin_003_DynamicLayoutSlotOverwriteIsNotChopped() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    let keys = typeZhuyinAndCollectReadingKeys("qquu", zhuyinFurious: true, parser: .ofDachen26)
    #expect(keys.isEmpty, "實得：\(keys)")
    #expect(testHandler.composer.getComposition() == "ㄅㄚ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 聲調鍵之語義不變：判準**永不**對聲調鍵切音節（§3.2 之條件 ②）。
  @Test("IH-FuriousZhuyin-004 Tone keys never trigger auto-chop")
  func test_IH_FuriousZhuyin_004_ToneKeysNeverTriggerAutoChop() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.composer.ensureParser(arrange: .ofDachen)
    // 先令注拼槽非空（ㄍㄠ），否則 ① 會先擋掉。
    testHandler.composer.receiveKey(fromString: "e")
    testHandler.composer.receiveKey(fromString: "l")
    #expect(testHandler.composer.getComposition() == "ㄍㄠ")
    // 大千排列之五個聲調鍵：3＝ˇ、4＝ˋ、6＝ˊ、7＝˙、空格＝陰平。
    for tone in ["3", "4", "6", "7", " "] {
      #expect(
        !testHandler.composer.shouldAutoChopPhonabets(byTyping: Character(tone)),
        "聲調鍵 \(tone) 誤判為切"
      )
    }
  }

  /// SCPC（逐字選字）下注音狂打不生效（沿用既有之 `!prefs.useSCPCTypingMode` 條件）。
  @Test("IH-FuriousZhuyin-005 Zhuyin furious is inactive under SCPC")
  func test_IH_FuriousZhuyin_005_ZhuyinFuriousIsInactiveUnderSCPC() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.prefs.useSCPCTypingMode = false
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testHandler.prefs.useSCPCTypingMode = false
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    testHandler.prefs.useSCPCTypingMode = true
    #expect(testHandler.typingMode == .bopomofoKeyblock)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective)
  }

  // MARK: - 未完成讀音之分流

  /// 注音狂打之「未完成讀音」顯示源即注拼槽內當前音節；空槽時為 `nil`。
  ///
  /// 並釘住判準之單一性：`hasFuriousFrontPending` 與 `furiousFrontUnfinishedReading != nil`
  /// 必須恆等（否則會出現「copilot 窗開了、頂部 pane 卻無讀音可示」之狀態）。
  @Test("IH-FuriousZhuyin-006 Unfinished reading is the composer syllable in zhuyin furious")
  func test_IH_FuriousZhuyin_006_UnfinishedReadingIsTheComposerSyllableInZhuyinFurious() throws {
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

  // MARK: - copilot 窗與就地選字

  /// 注音狂打且有未完成音節時，copilot 候選窗成立、置頂為該音節之組句預覽；
  /// 就地選字（滑鼠點選／Shift＋選字鍵同此路徑）把該音節以所選值寫入組字器。
  @Test("IH-FuriousZhuyin-007 Zhuyin furious copilot window and in-place selection")
  func test_IH_FuriousZhuyin_007_ZhuyinFuriousCopilotWindowAndInPlaceSelection() throws {
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
  @Test("IH-FuriousZhuyin-008 Front read points under zhuyin furious")
  func test_IH_FuriousZhuyin_008_FrontReadPointsUnderZhuyinFurious() throws {
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

  /// 注音狂打**不**寫 `furiousTrail`——trail 是拼音字母 blob，注音鍵流無此概念。
  @Test("IH-FuriousZhuyin-009 Zhuyin furious does not record trail")
  func test_IH_FuriousZhuyin_009_ZhuyinFuriousDoesNotRecordTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    _ = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: true)
    #expect(testHandler.furiousTrail.isEmpty, "實得：\(testHandler.furiousTrail)")
  }

  /// 註音狂打**關閉**時，行為須與今日完全一致：連打兩音節不會自動切音節。
  @Test("IH-FuriousZhuyin-010 Behaviour unchanged when zhuyin furious is off")
  func test_IH_FuriousZhuyin_010_BehaviourUnchangedWhenZhuyinFuriousIsOff() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testSession.resetInputHandler(forceComposerCleanup: true) }

    let keys = typeZhuyinAndCollectReadingKeys("elej/", zhuyinFurious: false)
    // 未開狂打 ⇒ 不自動切音節；`e` 覆寫聲母（同值，無觀測變化）、`j` 覆寫介母、`/` 覆寫韻母
    // ⇒ 組字器一個鍵都沒有，且注拼槽停在最後一組按鍵之合成（ㄍㄨㄥ）。
    #expect(keys.isEmpty, "實得：\(keys)")
    // 且注拼槽停在最後一組按鍵之內容（ㄍ 被覆寫為 ㄍ、韻母由 ㄠ 變 ㄥ）。
    #expect(testHandler.composer.getComposition() == "ㄍㄨㄥ", "實得：\(testHandler.composer.getComposition())")
  }

  /// 拼音狂拼之 `hasFuriousFrontPending` 語意**不得**因注音側之分流而改變。
  @Test("IH-FuriousZhuyin-011 Pinyin furious pending semantics unchanged")
  func test_IH_FuriousZhuyin_011_PinyinFuriousPendingSemanticsUnchanged() throws {
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

  /// 注音簡拼之 cells ＝「組字器尾段之單注音鍵（至多 3）＋ 注拼槽之當前讀音」。
  ///
  /// 三條界線同時釘住：① 少於 2 格不成立（單一格即整個聲母家族）；② 序列跨「已自動切出
  /// 之單注音」與「注拼槽內待確認者」；③ **遇完整音節即停**（該鍵不是任何讀音之起頭候選）。
  @Test("IH-FuriousZhuyin-012 Zhuyin abbreviation cells")
  func test_IH_FuriousZhuyin_012_ZhuyinAbbreviationCells() throws {
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
  @Test("IH-FuriousZhuyin-013 Zhuyin abbreviation candidates and in-place selection")
  func test_IH_FuriousZhuyin_013_ZhuyinAbbreviationCandidatesAndInPlaceSelection() throws {
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

  // MARK: - 中英混合輸入回退與注音狂打之相容（P273）

  /// 「中英混合輸入回退」與「注音狂打」自 P273 起**並存**：回退之 ASCII 緩衝區即狂打之
  /// 讀音素材，故 copilot 候選窗照常顯示；而**連續注音**之狂打特性（自動切音節、簡拼）
  /// 仍封印於回退之下（彼等會把逐鍵累積中的緩衝區提早固化）。
  ///
  /// 本靶釘五件事：
  /// ① 模式判定不再互斥（`typingMode` 之注音臂不再讀回退）；
  /// ② 讀音素材之住處分流（`mixedAlnumZhuyinFuriousInEffect` 與 `isZhuyinFuriousTypingModeEffective` 互斥）；
  /// ③ **行為層**：回退須真的活著——ASCII 序列依序累積於緩衝、空格遞交原文（行為即
  ///   「按鍵確實改走 `MixedAlphanumericalTypewriter`」之鐵證，勝於斷言型別）；
  /// ④ 撤除可逆：關掉回退後狂打即刻恢復「讀音素材住注拼槽」之形態；
  /// ⑤ **拼音側不受牽連**：回退本即注音鍵盤專屬，故 `4Pinyin` 與之無涉。
  @Test("IH-FuriousZhuyin-014 Mixed alnum coexists with zhuyin furious")
  func test_IH_FuriousZhuyin_014_MixedAlnumCoexistsWithZhuyinFurious() throws {
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

    // ① 基線：回退未啟用 ⇒ 注音狂打成立、讀音素材住注拼槽。
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.mixedAlnumZhuyinFuriousInEffect)
    #expect(!testHandler.isPinyinFuriousTypingModeEffective)
    #expect(testHandler.isFuriousCopilotEligible)

    // ② 啟用回退 ⇒ 狂打之模式判定**不動**；素材之住處改為混打緩衝；
    //    「連續注音」之閘門（含簡拼）讓位給回退。
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.prefs.furiousTypingEnabled4Zhuyin, "開關不動——本靶要驗的是並存、不是改寫偏好。")
    #expect(
      testHandler.typingMode == .zhuyinFuriousTyping,
      "實得：\(testHandler.typingMode)"
    )
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.mixedAlnumZhuyinFuriousInEffect)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective, "連續注音之特性仍封印於回退之下。")
    #expect(testHandler.isFuriousCopilotEligible)

    // ③ 行為層：ASCII 序列依序累積於緩衝（回退若失效，這些鍵會被當注音吸收、緩衝恆空）。
    //    讀音素材隨之住在緩衝：ㄑ 自成一拍時即為素材（單聲母之未完成前綴）；窗頂 pane
    //    兼示該緩衝之原文與其讀音（並存態專有之顯示形式）。
    typeSentence("f")
    #expect(testHandler.mixedAlphanumericalBuffer == "f")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄑ")
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testSession.unfinishedReading == "f → ㄑ")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    typeSentence("i") // `fi`：ㄑㄛ 非任何讀音之起頭 ⇒ 素材落回 nil、窗不開。
    #expect(testHandler.mixedAlphanumericalBuffer == "fi")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)
    typeSentence("lm")
    #expect(testHandler.mixedAlphanumericalBuffer == "film")

    // 空格：`film` 非讀音 ⇒ 無物可固化，照舊遞交整段 ASCII ＋ 半形空格。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions.joined() == "film ",
      "實得：\(testSession.recentCommissions.joined())"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "遞交後緩衝應清空。")

    // ④ 撤除可逆：關掉回退後狂打即刻恢復「素材住注拼槽」之形態，同批次按鍵改由狂打吸收。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.mixedAlnumZhuyinFuriousInEffect)
    typeSentence("el") // ㄍㄠ
    #expect(
      testHandler.composer.getComposition() == "ㄍㄠ",
      "實得：\(testHandler.composer.getComposition())"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    // ⑤ 拼音側不受牽連：回退啟用下，拼音狂打仍成立且素材住 romajiBuffer。
    enterPinyinFuriousTestEnvironment()
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.typingMode == .pinyinFuriousTyping, "實得：\(testHandler.typingMode)")
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isPinyinFuriousTypingModeEffective)
    #expect(!testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.mixedAlnumZhuyinFuriousInEffect, "回退本即注音鍵盤專屬。")
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
  @Test("IH-FuriousZhuyin-015 Abbreviation candidates stay within paired segment count")
  func test_IH_FuriousZhuyin_015_AbbreviationCandidatesStayWithinPairedSegmentCount() throws {
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
  @Test("IH-FuriousZhuyin-016 Abbreviation candidate order matches pinyin alpha window")
  func test_IH_FuriousZhuyin_016_AbbreviationCandidateOrderMatchesPinyinAlphaWindow() throws {
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
  @Test("IH-FuriousZhuyin-017 User phrases control frequency in furious windows")
  func test_IH_FuriousZhuyin_017_UserPhrasesControlFrequencyInFuriousWindows() throws {
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
  @Test("IH-FuriousZhuyin-018 Abbreviation rank is score-based")
  func test_IH_FuriousZhuyin_018_AbbreviationRankIsScoreBased() throws {
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
  /// 會消失。本靶釘五事：① 標準窗可見「狗男女」；② 其選取走狂打之套用路徑（鍵鏈換成該詞之
  /// 讀音、顯示正確）；③ 非前方候選者不受此路由；④ **打字途中組字器鍵鏈不被 partial 候選
  /// 改寫**（`config.partialMatchEnabled` 恆為假）——此即與「直接開 partial match 旗標」之別；
  /// ⑤ **固化即取該詞之讀音**：交棒之固化改以窗內整詞簡拼候選之首的實際讀音入庫（P266），
  /// 故鍵鏈與組字區顯示自交棒當拍起即為該詞（修前：鍵鏈為 `ㄍㄋㄋ`、顯示為讀音原文）。
  ///
  /// - Note: 對齊不成立時之交棒語義（只併入聲調變體桶）由 IH-FuriousZhuyin-021 把守。
  @Test("IH-FuriousZhuyin-019 Standard window keeps abbreviation candidates")
  func test_IH_FuriousZhuyin_019_StandardWindowKeepsAbbreviationCandidates() throws {
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

    // ② 交棒：無修飾方向鍵 ⇒ 固化前方讀音（改取窗內整詞簡拼候選之首的讀音）＋開出標準選字窗。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")
    let standardValues = testSession.state.candidates.map(\.value)
    #expect(standardValues.contains("狗男女"), "實得：\(standardValues)")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄡˇ", "ㄋㄢˊ", "ㄋㄩˇ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(generateDisplayedText() == "狗男女", "實得：\(generateDisplayedText())")
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

  // MARK: - 控頻配對與自動套用（P266）

  /// 狂打：**控頻之雷同配對不得自動套用**——copilot 窗改由使用者定奪。
  ///
  /// R3-a 之自動套用（明確勝出即於末鍵套用該詞之讀音、清空注拼槽）在 P262～P264 收斂簡拼
  /// 查詢之後出現了 regression：使用者辭典內與原廠**同值同讀音**之條目（控頻用）經 P263 之
  /// 權重覆寫與 P264 之分數排序升為首選，其與次高者之差距動輒超過 3.0 ⇒ 自動套用連 copilot
  /// 窗都來不及開。故新增閘門：該配對兩倉皆有（＝控頻對象）時不自動套用，改為開窗待選。
  ///
  /// 本靶釘三事：① 該配對確為控頻對象（兩倉皆有）；② 其為首選且差距遠超門檻時仍**不**自動
  /// 套用——copilot 窗在列、組字器鍵鏈不動；③ **對照組**：使用者專有詞（原廠無此讀音）之
  /// 自動套用語義不變（此閘門只管雷同配對，不得變成全域停用）。
  @Test("IH-FuriousZhuyin-020 Frequency controlled pair skips auto apply")
  func test_IH_FuriousZhuyin_020_FrequencyControlledPairSkipsAutoApply() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let textMap = makeTypingTextMap([
      ("ㄎㄜ-ㄐㄧˋ-ㄐㄧㄤˇ", [("科技獎", -6.0, factoryTypeID)]),
      ("ㄎㄜ-ㄐㄧˋ-ㄐㄧㄤ", [("科技江", -6.5, factoryTypeID)]),
    ])
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      LXAssembly.LXFacade.disconnectFactoryDictionary()
      #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData))
      leaveFuriousTestEnvironment()
    }
    clearTestPOM()
    LXAssembly.LXFacade.disconnectFactoryDictionary()
    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: textMap))
    enterPinyinFuriousTestEnvironment()

    // ① 控頻配對：同值同讀音、兩倉皆有（使用者側權重遠高於原廠側）。
    let controlledPair: (keyArray: [String], value: String) = (
      keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤˇ"], value: "科技獎"
    )
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: controlledPair.keyArray, value: controlledPair.value, score: -0.5),
      isFiltering: false
    )
    #expect(
      testHandler.currentLM.isFrequencyControlledPair(controlledPair),
      "同值同讀音且兩倉皆有者即控頻配對。"
    )

    // ② 末鍵之自動套用：首選（−0.5）與次高者（−6.0）差距 5.5 > 3.0，惟該配對為控頻對象
    //    ⇒ 不套用：注拼槽保留原文、組字器鍵鏈不動、copilot 窗照常開出。
    typeSentence("kjj")
    let windowAfterTyping = testSession.state.candidates.map(\.value)
    #expect(windowAfterTyping == ["科技獎", "科技江"], "實得：\(windowAfterTyping)")
    #expect(testHandler.assembler.actualKeys.isEmpty, "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.romajiBuffer == "kjj", "實得：\(testHandler.composer.romajiBuffer)")
    #expect(generateDisplayedText().isEmpty, "實得：\(generateDisplayedText())")

    // ③ 對照組：使用者專有詞（讀音 ㄎㄜ-ㄐㄧˋ-ㄐㄧㄤˋ，原廠無此條目）仍走自動套用。
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    let userOnlyPair: (keyArray: [String], value: String) = (
      keyArray: ["ㄎㄜ", "ㄐㄧˋ", "ㄐㄧㄤˋ"], value: "科記獎"
    )
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: userOnlyPair.keyArray, value: userOnlyPair.value, score: -0.5),
      isFiltering: false
    )
    #expect(
      !testHandler.currentLM.isFrequencyControlledPair(userOnlyPair),
      "原廠無此配對者不是控頻對象。"
    )
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("kjj")
    #expect(
      testHandler.assembler.actualKeys == userOnlyPair.keyArray,
      "實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(generateDisplayedText() == "科記獎", "實得：\(generateDisplayedText())")
    #expect(testHandler.composer.romajiBuffer.isEmpty, "自動套用應清空注拼槽。")
  }

  /// 注音狂打：**對齊不成立時**之交棒仍只併入聲調變體桶（P266 之退回語義）。
  ///
  /// IH-FuriousZhuyin-019 ② 之交棒固化取「窗內整詞簡拼候選之首」而入庫；若該首選之讀音數與格鏈鍵數不
  /// 對位（此處：辭典內無 ㄍㄋㄋ 起頭之整詞候選）⇒ 退回既有語義：單注音鍵 ＋ 聲調變體桶。
  @Test("IH-FuriousZhuyin-021 Handover without aligned word still inserts bucket")
  func test_IH_FuriousZhuyin_021_HandoverWithoutAlignedWordStillInsertsBucket() throws {
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

    typeSentence("ess") // ㄍㄋㄋ
    #expect(
      testHandler.currentLM.lxQuerier.abbreviatedWordCandidates(
        keysChopped: testHandler.furiousZhuyinAbbreviationCells ?? []
      ).isEmpty,
      "本靶之辭典內不得有 ㄍㄋㄋ 起頭之整詞候選。"
    )
    let copilotValues = testSession.state.candidates.map(\.value)
    #expect(!copilotValues.contains("狗男女"), "實得：\(copilotValues)")

    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍ", "ㄋ", "ㄋ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
  }

  // MARK: - 未完成前綴之讀音桶展開（P267）

  /// 注音狂打：**單聲母（未完成之合法前綴）之窗與拼音側同構**。
  ///
  /// 拼音側敲單字母時，桶由字母流反推之可能音節構成（`zhuyinReadings(forPinyinFragment:)`）⇒
  /// 窗內是「以該聲母起首之全部完整讀音」的真候選；注音側原逕行展開未完成音節之聲調變體，
  /// 而單聲母本身不是任何詞條之讀音 ⇒ 桶內全屬無效鍵、窗內只剩讀音回聲（實測：注音 ㄎ 之窗
  /// 僅一筆「ㄎ」，拼音 `k` 則有 376 筆）。本靶釘三事：① 注音單聲母之窗不再只有回聲、並含
  /// 真候選；② 兩側之候選集**同一**（同一桶、同一語言模組）、首選亦同；③ **完整音節不展開**
  /// （ㄎㄜ 之窗不得出現 ㄎㄞ 等更長讀音之字）。
  @Test("IH-FuriousZhuyin-022 Incomplete prefix bucket matches pinyin side")
  func test_IH_FuriousZhuyin_022_IncompletePrefixBucketMatchesPinyinSide() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    clearTestPOM()

    // ① 拼音側之基準（`k`）。
    enterPinyinFuriousTestEnvironment()
    typeSentence("k")
    let pinyinValues = testSession.state.candidates.map(\.value)
    #expect(pinyinValues.count > 100, "實得：\(pinyinValues.count)")
    #expect(pinyinValues.contains("科"), "實得：\(pinyinValues.prefix(8))")

    // ② 注音側之單聲母（大千 `d` ＝ ㄎ）：候選集與首選皆與拼音側一致。
    enterZhuyinFuriousTestEnvironment()
    typeSentence("d")
    let zhuyinValues = testSession.state.candidates.map(\.value)
    #expect(zhuyinValues.count > 100, "實得：\(zhuyinValues.count)")
    #expect(zhuyinValues != ["ㄎ"], "單聲母不得只給讀音回聲。")
    #expect(Set(zhuyinValues) == Set(pinyinValues), "兩側之候選集須同一。")
    #expect(zhuyinValues.first == pinyinValues.first, "實得：\(zhuyinValues.first ?? "nil")")

    // ③ 完整音節不展開：ㄎㄜ（大千 `dk`）之窗不含 ㄎㄞ 等更長讀音之字。
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("dk")
    let completeValues = testSession.state.candidates.map(\.value)
    #expect(completeValues.contains("科"), "實得：\(completeValues.prefix(8))")
    #expect(!completeValues.contains("開"), "完整音節不得展開為更長之讀音。")
    #expect(!completeValues.contains("顆顆"), "完整音節不得展開為更長之讀音。")
  }

  /// 注音狂打：**單聲母之固化與拼音側同構**——仍可提交，且結果同一。
  ///
  /// 桶展開之後，單聲母之固化不再是「插入一批無效鍵」而是「插入該聲母家族之真讀音鍵」⇒
  /// `Tekkon.SyllableIndex.isComplete(_:)` 之紅線（**不得**以之為「可否提交」之依據）由此靶
  /// 守住：注音 ㄎ＋方向鍵（交棒固化）與拼音 `k`＋空格（無調確認組字）必須得到同一結果。
  @Test("IH-FuriousZhuyin-023 Incomplete prefix solidify matches pinyin side")
  func test_IH_FuriousZhuyin_023_IncompletePrefixSolidifyMatchesPinyinSide() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    clearTestPOM()

    // ① 拼音側之基準：`k` ＋ 空格（無調確認組字）。
    enterPinyinFuriousTestEnvironment()
    typeSentence("k")
    typeSentence(" ")
    let pinyinKeys = testHandler.assembler.actualKeys
    let pinyinDisplay = generateDisplayedText()

    // ② 注音側：ㄎ ＋ 無修飾方向鍵（交棒固化）。
    enterZhuyinFuriousTestEnvironment()
    typeSentence("d")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent)
    let zhuyinKeys = testHandler.assembler.actualKeys
    let zhuyinDisplay = generateDisplayedText()
    #expect(testSession.state.isCandidateContainer, "實得：\(testSession.state.type)")
    #expect(zhuyinKeys == ["ㄎㄜ"], "實得：\(zhuyinKeys)")
    #expect(zhuyinDisplay != "ㄎ", "固化不得停留在讀音原文。")
    #expect(zhuyinKeys == pinyinKeys, "實得：\(zhuyinKeys) vs \(pinyinKeys)")
    #expect(zhuyinDisplay == pinyinDisplay, "實得：\(zhuyinDisplay) vs \(pinyinDisplay)")
  }

  // MARK: - 中英混合輸入回退之 copilot 候選窗（P273）

  /// 混打之 ASCII 緩衝即狂打之讀音素材：窗內須有該讀音之真候選、頂部 pane 須有
  /// 「原文 → 讀音」。
  ///
  /// 大千排列：ㄋ＝`s`、ㄧ＝`u`、ㄑ＝`f`、ㄛ＝`i`。`s` 為單聲母（合法前綴，桶內展開為該
  /// 聲母起首之全部讀音）、`su` 為完整音節；`fi` 則非任何讀音之起頭 ⇒ 窗即收。
  @Test("IH-FuriousZhuyin-024 Mixed alnum buffer serves as unfinished reading")
  func test_IH_FuriousZhuyin_024_MixedAlnumBufferServesAsUnfinishedReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    #expect(testHandler.mixedAlnumZhuyinFuriousInEffect, "本靶之前提：兩者並存。")

    // 起手式：兩者皆無素材 ⇒ 窗不開。
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)

    // 單聲母 `s`（ㄋ）：素材成立、窗可見、頂部 pane 顯示「原文 → 讀音」。
    typeSentence("s")
    #expect(testHandler.mixedAlphanumericalBuffer == "s")
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄋ",
      "判準本身仍只回讀音——顯示用之原文不得滲入。"
    )
    #expect(testHandler.hasFuriousFrontPending)
    #expect(
      testSession.unfinishedReading == "s → ㄋ",
      "窗頂 pane 須兼示原文與讀音，實得：\(testSession.unfinishedReading ?? "nil")"
    )
    #expect(
      testSession.isFuriousCopilotCandidateWindowVisible,
      "緩衝為讀音素材時 copilot 窗須可見。"
    )
    #expect(
      testSession.state.candidates.contains { $0.value == "妮" },
      "窗內須有該讀音之真候選，實得：\(testSession.state.candidates.map(\.value))"
    )

    // 續鍵成完整音節 `su`（ㄋㄧ）：素材改為該音節、窗隨之更新。
    typeSentence("u")
    #expect(testHandler.mixedAlphanumericalBuffer == "su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")
    #expect(
      testSession.unfinishedReading == "su → ㄋㄧ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)

    // 第三鍵：`sul` 恰為完整讀音 ㄋㄧㄠ（非其聲介韻之原鍵序，惟音節索引認其為完整讀音）
    // ⇒ 素材仍成立、窗續開。此即「讀音素材之判準與注拼槽之投影無涉」之實證。
    typeSentence("l")
    #expect(testHandler.mixedAlphanumericalBuffer == "sul")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧㄠ")
    #expect(
      testSession.unfinishedReading == "sul → ㄋㄧㄠ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 窗之關閉即「素材不再是任何讀音之起頭」之鏡像：`fi`＝ㄑㄛ 雖可發音，卻非任何讀音之
    // 起頭（`fi`＝ㄑㄛ 不完整；完整者另有其鍵序）⇒ 素材落回 nil、窗即收。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    typeSentence("f")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄑ")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    typeSentence("i")
    #expect(testHandler.mixedAlphanumericalBuffer == "fi")
    #expect(testHandler.furiousFrontUnfinishedReading == nil)
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)
  }

  /// 並存時空格＝固化該讀音；固化後本拍結束，其後每一鍵照常。
  ///
  /// - Important: 純注音狂打之空白鍵為陰平鍵（P260），本情境**不適用**——素材住混打緩衝、
  ///   聲調一律經數字鍵（`su3`）進入，故空格無「挪用即陰平無從指定」之虞；反之若不固化，
  ///   本鍵會落入混打之「整段緩衝 ＋ 半形空格」而把讀音當英文遞交（正是 P258 之病灶）。
  @Test("IH-FuriousZhuyin-025 Space solidifies mixed alnum reading")
  func test_IH_FuriousZhuyin_025_SpaceSolidifiesMixedAlnumReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    // 測試辭典無 ㄋㄧ 之陰平條目（實查），故自備一條——`su ` 之語義為「以陰平確認該讀音」，
    // 須有該條目方能落地（否則該讀音於辭典內無匹配、注音路徑會保留讀音而不成字）。
    let cleanup = insertRealLexiconGrams(testHandler)
    defer { cleanup() }

    // 空格：以陰平確認該讀音（不遞交任何 ASCII）。
    typeSentence("su")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions.isEmpty,
      "固化不得遞交原文，實得：\(testSession.recentCommissions)"
    )
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "固化後緩衝須被消費（否則同一批 ASCII 會被當英文再遞交一次）。"
    )
    #expect(testHandler.composer.isEmpty, "固化後注拼槽須清空。")
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧ"],
      "讀音須進組字器，實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(
      testSession.state.type == .ofInputting,
      "固化後停留於輸入狀態，實得：\(testSession.state.type.rawValue)"
    )

    // 再按空格：緩衝已空 ⇒ 遞交「已組字之中文 ＋ 半形空格」。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    let committedCodes = testSession.recentCommissions
      .map { $0.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: ",") }
      .joined(separator: " / ")
    print("DBG codes=" + committedCodes)
    #expect(
      testSession.recentCommissions.count == 1 && testSession.recentCommissions[0].hasSuffix(" "),
      "第二次空格應遞交「已組字之中文 ＋ 半形空格」，實得：\(testSession.recentCommissions)"
    )
    #expect(
      testSession.recentCommissions[0].hasPrefix("妮"),
      "所遞交之漢字應為該讀音於真語料庫內之陰平首選（妮），實得：\(committedCodes)"
    )

    // 原文續鍵之後按 Enter：遞交「仍在緩衝之原文 ASCII」。
    typeSentence("su")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(
      testSession.recentCommissions.count == 2
        && testSession.recentCommissions[0].hasSuffix(" ")
        && testSession.recentCommissions[1] == "su",
      "Enter 遞交仍在緩衝之原文 ASCII，實得：\(testSession.recentCommissions)"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// copilot 窗之首選可循標準候選路徑就地套用（該窗為唯讀顯示、選取走選字窗之路由）。
  @Test("IH-FuriousZhuyin-026 Mixed alnum copilot candidate applies in-place")
  func test_IH_FuriousZhuyin_026_MixedAlnumCopilotCandidateAppliesInPlace() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    testSession.installMockCandidateController()

    typeSentence("su")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    guard let firstCandidate = testSession.state.candidates.first else {
      Issue.record("copilot 窗內應有候選。")
      return
    }
    #expect(
      firstCandidate.value.unicodeScalars.first?.value == 0x6CE5,
      "大千 `su`（ㄋㄧˊ）於辭典中之首選，實得：\(firstCandidate.value)"
    )

    testSession.candidatePairSelectionConfirmed(at: 0)
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "就地套用後緩衝須被消費。"
    )
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄧ"])
    #expect(
      testHandler.committableDisplayText(sansReading: true).unicodeScalars.first?.value == 0x6CE5
    )
  }

  /// 回退之下「連續注音」之狂打特性**仍封印**：不得自動切音節。
  ///
  /// 對照組即純注音狂打（同一組按鍵會於第二鍵自動切出前一音節）。
  @Test("IH-FuriousZhuyin-027 Auto chop remains sealed under mixed alnum")
  func test_IH_FuriousZhuyin_027_AutoChopRemainsSealedUnderMixedAlnum() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()

    #expect(!testHandler.isZhuyinFuriousTypingModeEffective, "並存時連續注音之閘門為假。")

    // `els` ＝ ㄍㄠ ＋ ㄋ：若自動切音節成立，ㄍㄠ 會被固化進組字器。
    typeSentence("els")
    #expect(testHandler.mixedAlphanumericalBuffer == "els")
    #expect(
      testHandler.assembler.isEmpty,
      "回退之下不得自動切音節，實得：\(testHandler.assembler.actualKeys)"
    )
  }

  /// 對照組：純注音狂打（回退關）之下同一組按鍵**必須**自動切音節。
  @Test("IH-FuriousZhuyin-028 Auto chop still works without mixed alnum")
  func test_IH_FuriousZhuyin_028_AutoChopStillWorksWithoutMixedAlnum() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveFuriousTestEnvironment() }
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()

    #expect(testHandler.isZhuyinFuriousTypingModeEffective)
    #expect(!testHandler.mixedAlnumZhuyinFuriousInEffect)

    typeSentence("els")
    #expect(
      testHandler.assembler.actualKeys == ["ㄍㄠ"],
      "純狂打之下 ㄍㄠ 應被自動切出，實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  // MARK: - 讀音欄與 Tooltip／copilot 窗之分流（P273 之行為調整）

  /// 混打之 pending alnum 內容**全局**顯示於 composition buffer 之讀音欄（與注音狂打之
  /// 開關無涉）；此前該內容只以 Tooltip 呈現。
  ///
  /// 讀音欄之語義因而與純注音／拼音一致：它顯示「當前正在組裝的讀音」——混打側就是那段
  /// ASCII。顯示本即 `readingForDisplay` 對「注拼槽為空」之既有兜底，故本項只把該兜底
  /// 由「僅 Tooltip」改為「讀音欄優先」。
  @Test("IH-FuriousZhuyin-029 Mixed alnum buffer shows in composition reading area")
  func test_IH_FuriousZhuyin_029_MixedAlnumBufferShowsInCompositionReadingArea() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    // 群一：注音狂打**關**（僅回退生效）。
    enterMixedAlnumOnlyTestEnvironment()
    typeSentence("f")
    #expect(testHandler.mixedAlphanumericalBuffer == "f")
    #expect(
      testHandler.generateStateOfInputting().displayedText == "f",
      "讀音欄即該 ASCII 原文，實得：\(testHandler.generateStateOfInputting().displayedText)"
    )
    typeSentence("ilm")
    #expect(testHandler.mixedAlphanumericalBuffer == "film")
    #expect(
      testHandler.generateStateOfInputting().displayedText == "film",
      "注拼槽為空時讀音欄即 ASCII 原文，實得：\(testHandler.generateStateOfInputting().displayedText)"
    )
    #expect(testSession.state.type == .ofInputting)

    // 群二：注音狂打**開**（並存）——同一段原文亦顯示於讀音欄。
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("s")
    #expect(testHandler.mixedAlphanumericalBuffer == "s")
    #expect(
      testHandler.generateStateOfInputting().displayedText == "s",
      "讀音欄即該 ASCII 原文，實得：\(testHandler.generateStateOfInputting().displayedText)"
    )
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
  }

  /// copilot 候選窗在場時，混打之注音原文由該窗**頂端之未完成讀音**承載，Tooltip 讓位
  /// （兩者本即重疊於畫面同一處）；窗不在場時 Tooltip 只承載讀音——原文自 P273 起已由
  /// 組字區之讀音欄全局承載，故任何一態下該原文都只出現一次。
  @Test("IH-FuriousZhuyin-030 Mixed alnum reading goes to the copilot window or the tooltip")
  func test_IH_FuriousZhuyin_030_MixedAlnumReadingGoesToCopilotOrTooltip() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }

    // 群一：狂打關 ⇒ 無 copilot 候選 ⇒ Tooltip 承載讀音（原文則在讀音欄）。
    enterMixedAlnumOnlyTestEnvironment()
    typeSentence("f")
    let plainState = testHandler.generateStateOfInputting()
    #expect(plainState.candidates.isEmpty)
    #expect(plainState.tooltip == "ㄑ", "Tooltip 應只承載讀音，實得：\(plainState.tooltip)")
    #expect(
      plainState.displayedText == "f",
      "混打原文應由組字區讀音欄承載，實得：\(plainState.displayedText)"
    )

    // 群二：狂打開（並存）⇒ copilot 窗在場 ⇒ 原文改由該窗頂端之 pane 承載、Tooltip 讓位。
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("s")
    #expect(testHandler.mixedAlphanumericalBuffer == "s")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    let copilotState = testHandler.generateStateOfInputting()
    #expect(!copilotState.candidates.isEmpty, "copilot 窗須有候選")
    #expect(
      copilotState.tooltip.isEmpty,
      "copilot 窗在場時 Tooltip 應讓位，實得：\(copilotState.tooltip)"
    )
    #expect(
      testSession.unfinishedReading == "s → ㄋ",
      "原文（`s`）連同其讀音改由該窗頂端之 pane 承載，實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群三：拼音狂打之讀音來源仍是注拼槽（混打緩衝為空），故該側語義不變。
    enterPinyinFuriousTestEnvironment()
    typeSentence("gao")
    let pinyinState = testHandler.generateStateOfInputting()
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "拼音側之素材住 romajiBuffer、不住混打緩衝")
    #expect(
      pinyinState.displayedText == "高",
      "拼音側之組字區仍由 copilot 之預覽接管（與混打側之「讀音欄顯示原文」有別），實得：\(pinyinState.displayedText)"
    )
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
  }

  /// 混打＋注音狂打之空白鍵＝**陰平聲調確認鍵**（與純注音狂打看齊，`P258`／`P260`）。
  ///
  /// 此前混打路徑會把該待調音節固化為**無調**聲調桶而後遞交 ASCII（實測：`su` 按空格
  /// 得 `["ㄋㄧ"]` ＋ 遞交 `su `），遂令陰平無從指定。修正後之語義與純狂打同源：把該
  /// 讀音之**整組聲調變體桶**插入組字器、不覆寫，故語言模型得於窗內自行挑調。
  @Test("IH-FuriousZhuyin-031 Mixed alnum Space confirms pending reading with first tone")
  func test_IH_FuriousZhuyin_031_MixedAlnumSpaceConfirmsPendingReadingWithFirstTone() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    // 陰平確認須有該讀音之陰平條目方能落地（測試辭典無之，實查）⇒ 自備真語料庫之 ㄋㄧ 族。
    let cleanup = insertRealLexiconGrams(testHandler)
    defer { cleanup() }

    // `su`＝ㄋㄧ（尚未帶聲調）：素材成立、注拼槽有該讀音之投影。
    typeSentence("su")
    #expect(testHandler.mixedAlphanumericalBuffer == "su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")

    // 空格：以陰平確認該讀音——整組聲調桶入組字器、緩衝與注拼槽俱清、**零遞交 ASCII**。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧ"],
      "應插入該讀音之整組聲調變體桶，實得：\(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "確認後緩衝須被消費，實得：\(testHandler.mixedAlphanumericalBuffer)"
    )
    #expect(testHandler.composer.isEmpty, "確認後注拼槽須清空。")
    #expect(
      testSession.recentCommissions.isEmpty,
      "確認讀音不得遞交 ASCII 原文，實得：\(testSession.recentCommissions)"
    )
    #expect(!testHandler.hasFuriousFrontPending, "窗即收。")

    // 對照組：同組按鍵於**純注音狂打**（回退關）下亦得同一鍵鏈——兩側語義同源之憑據。
    // （其後之遞交與否取決於語言模型之組句，與鍵鏈本身無涉，故不在此斷言。）
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()
    let cleanup2 = insertRealLexiconGrams(testHandler)
    defer { cleanup2() }
    typeSentence("su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧ"],
      "純狂打之對照，實得：\(testHandler.assembler.actualKeys)"
    )
  }

  /// 已帶聲調者之空白鍵語義不變：聲調一旦進入，讀音即為唯一解，空格照舊為「送字 ＋ 空格」。
  ///
  /// 此即「本修正只及待調讀音那一態」之護欄。
  @Test("IH-FuriousZhuyin-032 A toned reading keeps Space as the commit key")
  func test_IH_FuriousZhuyin_032_TonedReadingKeepsSpaceAsCommit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()

    // `su3`＝ㄋㄧˇ：聲調鍵一到，該音節即成字、緩衝清空。
    typeSentence("su3")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄧˇ"], "實得：\(testHandler.assembler.actualKeys)")

    // 空格：無待調讀音 ⇒ 照舊「送字 ＋ 半形空格」。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions == ["你 "],
      "實得：\(testSession.recentCommissions)"
    )
  }

  /// 殘段（非「恰為一個讀音」之緩衝）不得充作讀音素材：空白鍵照舊遞交整段 ASCII。
  ///
  /// 事主實機回報：混打＋狂打下敲 `us` 再按空格，期望遞交 `us `，實得未遞交而顯示漢字。
  /// 根因有二，皆屬同一件事（「殘段被誤認」）：① 供讀音之投影（`syncComposerWithMixedAlphanumericalBuffer`）
  /// 未強制槽序，遂把「以另一鍵補滿槽位」之殘段就地吸納（`us` 之槽值成 ㄋㄧ，與 `su` 無從
  /// 分辨）；② 讀音素材之判準只問「可發音 ∧ 是某讀音之起頭」，未問「該緩衝是否**恰為**
  /// 一個讀音」。兩者皆已收緊：前者強制 CSVT 順序、後者加「鍵數 == 佔用槽數」之核對。
  @Test("IH-FuriousZhuyin-033 Fragment buffer is not a reading")
  func test_IH_FuriousZhuyin_033_FragmentBufferIsNotAReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()

    // `us`＝ㄧㄡ ＋ ㄋ：兩音節之鍵，非「恰為一個讀音」⇒ 無讀音素材、窗不開。
    typeSentence("us")
    #expect(testHandler.mixedAlphanumericalBuffer == "us")
    #expect(
      testHandler.furiousFrontUnfinishedReading == nil,
      "殘段不得充作讀音素材，實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    #expect(!testHandler.hasFuriousFrontPending)
    #expect(!testSession.isFuriousCopilotCandidateWindowVisible)

    // 空格：無物可固化 ⇒ 遞交整段 ASCII ＋ 半形空格。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions == ["us "],
      "殘段應照舊遞交原文，實得：\(testSession.recentCommissions)"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.assembler.isEmpty, "殘段不得被固化進組字器。")

    // 對照組：`su`＝ㄋㄧ 為完整音節（恰為一個讀音）⇒ 素材成立、窗可開。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    typeSentence("su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
  }

  /// 注音狂打之空格**不得**兼任「確認 copilot 當前候選」——它是陰平聲調鍵。
  ///
  /// 事主原文：「注音狂打模式的空格不要觸發 copilot 的 confirm current candidate 的動作。
  /// 這是注音狂打與拼音狂打的行為差異之一，因為空格鍵是陰平。」故空格之語義為「把該讀音
  /// **定為陰平**、寫入組字器」；候選之選定仍歸 `Shift+選字鍵` 等明示路徑。
  /// 本靶只驗「該音節被陰平地消費」與「窗內當前候選未被寫死」；字詞層之取捨見 `IH-FuriousZhuyin-035`
  /// （該靶以真語料庫之權重為據，測試辭典之 ㄋㄧ 族與真者不同）。
  @Test("IH-FuriousZhuyin-034 Space is the first-tone key, not candidate confirmation")
  func test_IH_FuriousZhuyin_034_SpaceIsFirstToneNotCandidateConfirmation() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    // 測試辭典無 ㄋㄧ 族之陰平條目（實查：該族條目之聲調標記不含陰平形），故自備一條，
    // 俾本靶得以驗「該音節被陰平地消費」而不受辭典內容之偶然性影響。
    let cleanup = insertRealLexiconGrams(testHandler)
    defer { cleanup() }

    typeSentence("su")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))

    // 該音節已被**陰平地**消費：注拼槽與緩衝俱清、且該拍**零遞交**（既未遞交 ASCII，
    // 亦未遞交窗內當前候選之詞值）。
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "緩衝須已消費，實得：\(testHandler.mixedAlphanumericalBuffer)"
    )
    #expect(testHandler.composer.isEmpty, "注拼槽須已清空。")
    #expect(
      testSession.recentCommissions.isEmpty,
      "空格不得遞交任何內容，實得：\(testSession.recentCommissions)"
    )
    #expect(!testHandler.hasFuriousFrontPending, "窗即收。")
  }

  /// 真語料庫之迴歸：混打＋狂打下 `su ` 須得該讀音於真辭典內之陰平單字。
  ///
  /// 語料取自 `vChewing-VanguardLexicon/Build/Release/tsv/data-v4.8.5.txt` 之實錄（ㄋㄧ 族）：
  /// `ㄋㄧ`（妮 −5.314）、`ㄋㄧˊ`（泥 −5.23）、`ㄋㄧˇ`（你 −5.074）、`ㄋㄧˋ`（膩 −5.26）。
  /// 陰平被確認後，組句**只**能在 `ㄋㄧ` 一族內挑字 ⇒ 得妮；若插入整組聲調變體桶，
  /// 則由分數更高之 ㄋㄧˇ 之你勝出（此即修正前之實況）。
  @Test("IH-FuriousZhuyin-035 Space pins reading to first tone")
  func test_IH_FuriousZhuyin_035_SpacePinsReadingToFirstTone() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    // 逐字取自真語料庫（`insertTemporaryData` 之 keyArray 為完整讀音、含聲調）。
    let cleanup = insertRealLexiconGrams(testHandler)
    defer { cleanup() }

    typeSentence("su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.keys == [.singleKey("ㄋㄧ")],
      "陰平單鍵，實得：\(testHandler.assembler.keys)"
    )
    #expect(
      testHandler.committableDisplayText(sansReading: true) == "妮",
      "陰平確認後應得妮（該族之陰平首選），實得：\(testHandler.committableDisplayText(sansReading: true))"
    )
    #expect(testSession.recentCommissions.isEmpty, "不得遞交任何內容。")

    // 對照組：純注音狂打之同一序列、同一語料 —— 亦得妮。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()
    let cleanup2 = insertRealLexiconGrams(testHandler)
    defer { cleanup2() }
    typeSentence("su")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.committableDisplayText(sansReading: true) == "妮",
      "純狂打之對照，實得：\(testHandler.committableDisplayText(sansReading: true))"
    )
  }

  /// 停用「依槽序鍵入判定讀音」後，混打＋狂打之讀音素材亦須回到舊制：亂序短令牌（`ls`）
  /// 照舊為讀音（ㄋㄠ）⇒ copilot 窗應顯示、空白鍵為其聲調鍵（不遞交原文）。此為 P274 之
  /// 回歸：P273 起 `mixedAlnumPendingReading` 之量測無條件以 CSVT 消化，遂令停用者之
  /// `ls` 不被認作讀音素材（`furiousFrontUnfinishedReading == nil`、窗不開）——
  /// 該開關於狂打並存態亦應被貫徹，不得受注音狂打特性開關影響。
  @Test("IH-FuriousZhuyin-036 Slot order switch off restores furious reading source")
  func test_IH_FuriousZhuyin_036_SlotOrderSwitchOffRestoresFuriousReadingSource() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer {
      testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = true
      leaveMixedAlnumTestEnvironment()
    }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = false
    let cleanup = insertRealLexiconGrams(
      testHandler,
      "ㄋㄠ 腦 -1\nㄋㄧ 妮 -5.314\nㄧㄡ 優 -1"
    )
    defer { cleanup() }

    typeSentence("ls")
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄋㄠ",
      "停用槽序檢定後 `ls` 應為讀音素材，實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    typeSentence(" ")
    #expect(
      testSession.recentCommissions.isEmpty,
      "空白鍵為其聲調鍵、不遞交原文，實得：\(testSession.recentCommissions)"
    )
    #expect(testHandler.assembler.actualKeys == ["ㄋㄠ"], "實得：\(testHandler.assembler.actualKeys)")
  }

  /// 窗頂 pane 之顯示字串：**當且僅當**中英混合輸入回退與注音狂打並存時，於消化後之
  /// 讀音之前補上混打緩衝之原文（`原文 → 讀音`）。
  ///
  /// - Important: 併存時素材住在混打之 ASCII 緩衝區，而窗頂 pane 在此之前只顯示消化後之
  ///   讀音 ⇒ 使用者敲下的鍵在畫面上無處可尋（實錄：`u` 之後只見 ㄧ、`s` 之後只見 ㄋ）。
  ///   本屬性只改**顯示**：`furiousFrontUnfinishedReading`（讀音桶生成與語言模型查詢之
  ///   素材）一字不動，故四組對照之其餘三組（純狂注、純狂拼、僅回退）一律無箭頭。
  /// - Note: 箭頭前後之原文由本處供給，`✍️ ` 前綴仍由選字窗側（`CandidatePool4AppKit`）統一
  ///   添加，故本靶只驗到箭頭形式為止。
  @Test("IH-FuriousZhuyin-037 Mixed alnum pane text shows raw then reading")
  func test_IH_FuriousZhuyin_037_MixedAlnumPaneTextShowsRawThenReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }

    // 群一：並存態（本 phase 之唯一有效情境）。事主所報之兩例逐鍵實錄。
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("u")
    #expect(testHandler.mixedAlphanumericalBuffer == "u")
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄧ",
      "素材仍只回讀音，實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    #expect(
      testSession.unfinishedReading == "u → ㄧ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    typeSentence("s")
    #expect(testHandler.mixedAlphanumericalBuffer == "s")
    #expect(
      testSession.unfinishedReading == "s → ㄋ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
    typeSentence("u")
    #expect(
      testSession.unfinishedReading == "su → ㄋㄧ",
      "續鍵後原文亦隨之延長，實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群二：純注音狂打（素材住注拼槽）——讀音即顯示字串、不得出現箭頭。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    // 本檔之純狂注環境 helper 不動回退開關，故須自行關閉（否則仍屬並存態）。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    enterZhuyinFuriousTestEnvironment()
    typeSentence("e")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "純狂注之素材不住混打緩衝。")
    #expect(
      testSession.unfinishedReading == "ㄍ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群三：純拼音狂拼——字母流原樣顯示、不得出現箭頭。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    enterPinyinFuriousTestEnvironment()
    typeSentence("gao")
    #expect(
      testSession.unfinishedReading == "gao",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群四：僅中英混合輸入回退（狂打關）——窗不開，pane 一併無資料；
    // 該原文仍見於組字區之讀音欄（Tooltip 自 P277 起只承載讀音、不再重述原文）。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    enterMixedAlnumOnlyTestEnvironment()
    typeSentence("f")
    #expect(testHandler.mixedAlphanumericalBuffer == "f")
    #expect(
      !testSession.isFuriousCopilotCandidateWindowVisible,
      "狂打關時無 copilot 窗，原文仍由組字區之讀音欄承載。"
    )
    let mixedOnlyState = testHandler.generateStateOfInputting()
    #expect(
      mixedOnlyState.displayedText == "f",
      "混打原文應由組字區讀音欄承載，實得：\(mixedOnlyState.displayedText)"
    )
    #expect(
      !mixedOnlyState.tooltip.contains("f"),
      "Tooltip 不得重述混打之 ASCII 原文，實得：\(mixedOnlyState.tooltip)"
    )
    #expect(testSession.unfinishedReading == nil, "實得：\(testSession.unfinishedReading ?? "nil")")
  }

  // MARK: - 「拼音並擊」對未完成讀音之呈現（P277）

  /// 窗頂 pane 之讀音呈現須隨「拼音並擊（組字區內顯示漢語拼音）」偏好：啟用時，注音素材
  /// 改以**組字區讀音欄那一式**之漢語拼音呈現（數字標調附於尾端、`ü` 作 `v`、無調者不附）；
  /// 該偏好停用、或素材本即拼音字母流時一律照舊。
  ///
  /// - Important: 該 pane 恆由選字窗以單一橫排文字繪製（不隨直排輸入而轉向），故其轉換
  ///   **不問呈現方向**——此與 Tooltip 之規則（另須問方向）刻意不同。
  ///   判準屬性（`furiousFrontUnfinishedReading`）一字不動，只有顯示改。
  /// - Important: 採組字區讀音欄之式，**不**轉教材式標調、**不**補陰平記號：注音素材可能是
  ///   **前綴**（單聲母），補記即得 `g1` 這類無母音可附調號之殘形；教材式另會把 `nv3` 寫成
  ///   `nǚ`、與組字區所見不一致（事主 2026-09-29 明示）。
  @Test("IH-FuriousZhuyin-038 Pane reading follows Hanyu pinyin preference")
  func test_IH_FuriousZhuyin_038_PaneReadingFollowsHanyuPinyinPreference() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalPinyinDisplay = testHandler.prefs.showHanyuPinyinInCompositionBuffer
    defer {
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = originalPinyinDisplay
      leaveMixedAlnumTestEnvironment()
    }

    // 群一：純注音狂打（大千：ㄍ＝`e`、ㄠ＝`l`）。
    enterZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("e")
    #expect(testSession.unfinishedReading == "ㄍ", "實得：\(testSession.unfinishedReading ?? "nil")")
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    #expect(
      testSession.unfinishedReading == "g",
      "單聲母之前綴不得補陰平記號，實得：\(testSession.unfinishedReading ?? "nil")"
    )
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄍ",
      "判準屬性不得隨顯示偏好變動，實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    typeSentence("l")
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄍㄠ",
      "實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    #expect(
      testSession.unfinishedReading == "gao",
      "無調記之讀音與組字區讀音欄同式（皆不補陰平記號），實得：\(testSession.unfinishedReading ?? "nil")"
    )
    // 帶聲調者：聲調附於尾端、`ü` 作 `v`（仍與組字區讀音欄逐字同式，非教材式標調）。
    // 註：注音狂打之「聲調鍵」本即音節確認鍵（讀音固化進組字器、注拼槽清空），
    //     故帶調之未完成讀音無從以打字取得——此處直驅注拼槽（與 `SS-TooltipAndMarking-002` 同法）。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    var composer = testHandler.composer
    composer.clear()
    composer.receiveSequence("ai3", isRomaji: false)
    #expect(composer.getComposition(isHanyuPinyin: false) == "ㄇㄛˇ")
    #expect(
      composer.getComposition(isHanyuPinyin: true) == "mo3",
      "本靶之前提：組字區讀音欄即此式"
    )
    testHandler.composer = composer
    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(
      testHandler.furiousFrontUnfinishedReading == "ㄇㄛˇ",
      "實得：\(testHandler.furiousFrontUnfinishedReading ?? "nil")"
    )
    #expect(
      testSession.unfinishedReading == "mo3",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
    // ㄩ 一族：`v` 拼法與尾端聲調（教材式會作 `nǚ`，本 phase 不採）。
    composer = testHandler.composer
    composer.clear()
    for scalar in "ㄋㄩˇ".unicodeScalars { composer.receiveKey(fromPhonabet: scalar) }
    #expect(
      composer.getComposition(isHanyuPinyin: true) == "nv3",
      "本靶之前提：組字區讀音欄即此式"
    )
    testHandler.composer = composer
    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(
      testSession.unfinishedReading == "nv3",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群二：並存態——箭頭前之原文不受轉換，箭頭後之讀音方以漢語拼音呈現。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("s")
    #expect(
      testSession.unfinishedReading == "s → n",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
    typeSentence("u")
    #expect(
      testSession.unfinishedReading == "su → ni",
      "續鍵後原文與讀音一併延長，實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群三：純拼音狂拼——素材本即拼音字母流，不得再經注音→拼音之轉換。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    testHandler.prefs.mixedAlphanumericalEnabled = false
    enterPinyinFuriousTestEnvironment()
    typeSentence("gao")
    #expect(
      testSession.unfinishedReading == "gao",
      "拼音素材仍須原樣顯示（不得多添陰平記號），實得：\(testSession.unfinishedReading ?? "nil")"
    )

    // 群四：偏好停用時，注音素材照舊以注音呈現。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
    // 群三已把鍵盤排列切成漢語拼音，故須顯式切回大千（`enterZhuyinFuriousTestEnvironment`
    // 只換注拼槽之 parser、不動 `prefs.keyboardParser`）。
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    enterZhuyinFuriousTestEnvironment()
    typeSentence("el")
    #expect(
      testSession.unfinishedReading == "ㄍㄠ",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
  }

  /// 中英混打之 Tooltip 讀音亦隨「拼音並擊」偏好：啟用且橫排時改以漢語拼音呈現（**組字區
  /// 讀音欄那一式**：數字標調附於尾端、`ü` 作 `v`）；直排時退回注音。轉換與窗頂 pane 同源
  /// ——不轉教材式標調、不補陰平記號，故單聲母前綴得 `m`、而非 `m1`。
  @Test("IH-FuriousZhuyin-039 Mixed tooltip reading follows Hanyu pinyin preference")
  func test_IH_FuriousZhuyin_039_MixedTooltipReadingFollowsHanyuPinyinPreference() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalPinyinDisplay = testHandler.prefs.showHanyuPinyinInCompositionBuffer
    let originalAlwaysHorizontal = testHandler.prefs.alwaysShowTooltipTextsHorizontally
    defer {
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = originalPinyinDisplay
      testHandler.prefs.alwaysShowTooltipTextsHorizontally = originalAlwaysHorizontal
      leaveMixedAlnumTestEnvironment()
    }
    enterMixedAlnumOnlyTestEnvironment()
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    // Tooltip 之方向判定走 `InputSession.isVerticalTyping`；本檔之會話為 mock、無從綁定
    // `InputSession.current`，故逕以「強制橫排」鎖定橫排那一態（方向規則本身由 `SS-TooltipAndMarking-002` 釘住）。
    testHandler.prefs.alwaysShowTooltipTextsHorizontally = true

    // 單聲母前綴（大千：`a`＝ㄇ）：不得補陰平記號而得 `m1`。
    typeSentence("a")
    let prefixState = testHandler.generateStateOfInputting()
    #expect(prefixState.tooltip == "m", "實得：\(prefixState.tooltip)")

    // 直驅注拼槽至「ㄇㄛˇ」，避開混輸 auto-split 對鍵序之依賴（與 `SS-TooltipAndMarking-002` 同法）。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    var composer = testHandler.composer
    composer.clear()
    composer.receiveSequence("ai3", isRomaji: false)
    #expect(composer.getComposition(isHanyuPinyin: false) == "ㄇㄛˇ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "mo3")
    testHandler.composer = composer
    testHandler.mixedAlphanumericalBuffer = "ai3"
    let tonedState = testHandler.generateStateOfInputting()
    #expect(tonedState.tooltip == "mo3", "實得：\(tonedState.tooltip)")
    #expect(
      tonedState.displayedText.contains("ai3"),
      "混打原文應由組字區讀音欄承載，實得：\(tonedState.displayedText)"
    )
  }

  /// 混打 Tooltip 之讀音來源須為**緩衝區之量測**、非注拼槽之投影。
  ///
  /// - Important: 注拼槽只是混打緩衝之投影，而該投影於「整段未被詞庫採納」時即被打字機
  ///   清空（大千：`su;`＝ㄋㄧㄤ 之投影已空、緩衝仍在；對照 `1u,`＝ㄅㄧㄝ 之投影倖存）。
  ///   只讀注拼槽者，凡多鍵之混打緩衝皆無讀音可示 ⇒ P277 起「Tooltip 只承載讀音」之語義
  ///   退化成「整窗收起」（事主 2026-09-29 回報：`su;` 之 Tooltip 為空、應示 `niang`）。
  @Test("IH-FuriousZhuyin-040 Mixed tooltip reading comes from buffer")
  func test_IH_FuriousZhuyin_040_MixedTooltipReadingComesFromBuffer() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let originalPinyinDisplay = testHandler.prefs.showHanyuPinyinInCompositionBuffer
    defer {
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = originalPinyinDisplay
      leaveMixedAlnumTestEnvironment()
    }

    // 群一：僅中英混合輸入回退（狂打關）＋「拼音並擊」啟用。
    enterMixedAlnumOnlyTestEnvironment()
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    typeSentence("su;")
    #expect(
      testHandler.mixedAlphanumericalBuffer == "su;",
      "實得：\(testHandler.mixedAlphanumericalBuffer)"
    )
    #expect(
      testHandler.composer.getComposition(isHanyuPinyin: false).isEmpty,
      "本靶之前提：該緩衝之注拼槽投影已被打字機清空"
    )
    #expect(
      testHandler.mixedAlnumPendingReading == nil,
      "狂打關時狂打側之素材量測恆為 nil（併存閘）"
    )
    #expect(
      testHandler.mixedAlnumBufferPendingReading == "ㄋㄧㄤ",
      "緩衝側之量測不拘狂打開關，實得：\(testHandler.mixedAlnumBufferPendingReading ?? "nil")"
    )
    let longState = testHandler.generateStateOfInputting()
    #expect(longState.tooltip == "niang", "實得：\(longState.tooltip)")
    #expect(
      longState.displayedText == "su;",
      "混打原文仍由組字區讀音欄承載，實得：\(longState.displayedText)"
    )
    // 非讀音之緩衝（`fi`＝ㄑㄛ 可發音卻非任何讀音之起頭）：讀音無從示起 ⇒ Tooltip 為空。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    typeSentence("fi")
    #expect(testHandler.mixedAlnumBufferPendingReading == nil)
    #expect(
      testHandler.generateStateOfInputting().tooltip.isEmpty,
      "非讀音之緩衝不得充作讀音"
    )

    // 群二：同一情境但「拼音並擊」停用 ⇒ 該讀音以注音呈現。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
    typeSentence("su;")
    let zhuyinState = testHandler.generateStateOfInputting()
    #expect(zhuyinState.tooltip == "ㄋㄧㄤ", "實得：\(zhuyinState.tooltip)")

    // 群三：兩者並存 ⇒ 窗在場（Tooltip 讓位）、原文與讀音由窗頂 pane 承載。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    typeSentence("su;")
    #expect(
      testHandler.mixedAlnumPendingReading == testHandler.mixedAlnumBufferPendingReading,
      "併存時狂打側之素材即緩衝側之量測"
    )
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    let copilotState = testHandler.generateStateOfInputting()
    #expect(!copilotState.candidates.isEmpty, "copilot 窗須有候選")
    #expect(
      copilotState.tooltip.isEmpty,
      "窗在場時 Tooltip 讓位，實得：\(copilotState.tooltip)"
    )
    #expect(
      testSession.unfinishedReading == "su; → niang",
      "實得：\(testSession.unfinishedReading ?? "nil")"
    )
  }

  // MARK: - Shift+Space 之逃生口（P280）

  /// 混打＋注音狂打並存時，**Shift+Space** 之意義為「放棄注音處理」：整段混打緩衝以原文
  /// 遞交、其後附一個半形空格；待確認之讀音**不得**被固化、亦不得被當成陰平確認鍵。
  ///
  /// - Important: 空格之陰平語義（`IH-FuriousZhuyin-031`／`IH-FuriousZhuyin-034`）只屬**不帶修飾鍵**之空格。Shift 是使用者
  ///   明示之「英文意圖」——混打模式下它本即「整段 ASCII ＋ 半形空格」之逃生口
  ///   （見 `MixedAlphanumericalTypewriter` 之既有語義）；若令陰平確認搶先消費本鍵，該逃生口
  ///   即無從觸發（事主實機回報：`su` 之後按 Shift+Space 得陰平確認，而非遞交 `su `）。
  @Test("IH-FuriousZhuyin-041 Mixed alnum Shift+Space commits ASCII")
  func test_IH_FuriousZhuyin_041_MixedAlnumShiftSpaceCommitsASCII() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    enterMixedAlnumZhuyinFuriousTestEnvironment()
    clearTestPOM()
    let cleanup = insertRealLexiconGrams(testHandler)
    defer { cleanup() }

    let shiftSpaceEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: " ",
      keyCode: KeyCode.kSpace.rawValue
    ).asEvent

    // 待調讀音（`su`＝ㄋㄧ）：素材成立、copilot 窗在場。
    typeSentence("su")
    #expect(testHandler.mixedAlphanumericalBuffer == "su")
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄋㄧ")
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)

    // Shift+Space：放棄注音處理 ⇒ 遞交整段原文 ＋ 半形空格，且零固化。
    #expect(testHandler.triageInput(event: shiftSpaceEvent))
    #expect(
      testSession.recentCommissions == ["su "],
      "Shift+Space 應遞交整段 ASCII ＋ 半形空格，實得：\(testSession.recentCommissions)"
    )
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "實得：\(testHandler.mixedAlphanumericalBuffer)"
    )
    #expect(testHandler.composer.isEmpty, "實得：\(testHandler.composer.getComposition())")
    #expect(testHandler.assembler.isEmpty, "Shift+Space 不得把待調讀音固化進組字器。")
    #expect(!testHandler.hasFuriousFrontPending, "本拍過後素材即散、窗即收。")

    // 對照組：不帶 Shift 之空格仍為陰平確認鍵（`IH-FuriousZhuyin-031`／`IH-FuriousZhuyin-034` 之語義一字不動）。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.clear()
    typeSentence("su")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions == ["su "],
      "不帶 Shift 之空格不得遞交任何內容（遞交紀錄應與前一組相同），實得：\(testSession.recentCommissions)"
    )
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧ"],
      "實得：\(testHandler.assembler.actualKeys)"
    )
  }

  // MARK: - 並存態之遞交內容（P287）

  /// 混打＋注音狂打並存時，**任何遞交路徑之內容皆為「已組字之中文 ＋ 混打緩衝之原文」**：
  /// copilot 對該待確認讀音之**投機預覽**（語言模型之猜測）一概不得進入遞交——該讀音未經
  /// 使用者確認（確認只走空格之陰平、固化與顯式選字三途），且組字區讀音欄所示者本即緩衝
  /// 原文，故遞交內容與顯示同源。
  ///
  /// - Important: 三條路徑皆曾把投機預覽連同原文一併遞交（實測 `你你泥su`）：① 符號選單
  ///   實體鍵；② `resetInputHandler()`（IME 切換、`commitComposition` 之同一條路）；
  ///   ③ 未認領之 Command 系熱鍵（P282 之 `releaseUnclaimedCommandChord()` 亦走②）。
  @Test("IH-FuriousZhuyin-042 Mixed alnum exit paths drop the speculating preview")
  func test_IH_FuriousZhuyin_042_MixedAlnumExitPathsDropSpeculatingPreview() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { leaveMixedAlnumTestEnvironment() }
    let symbolMenuEvent = KBEvent.KeyEventData.symbolMenuKeyEventIntl.asEvent
    let cmdChordEvent = KBEvent.KeyEventData(flags: [.command, .control], chars: "c").asEvent
    let exits: [(tag: String, act: () -> ())] = [
      ("符號選單實體鍵", { _ = testHandler.triageInput(event: symbolMenuEvent) }),
      ("resetInputHandler", { testSession.resetInputHandler() }),
      ("未認領之 Command 熱鍵", { _ = testHandler.triageInput(event: cmdChordEvent) }),
    ]
    for (tag, act) in exits {
      enterMixedAlnumZhuyinFuriousTestEnvironment()
      clearTestPOM()
      testSession.recentCommissions.removeAll()
      typeSentence("su3su3")
      typeSentence("su")
      let mainText = testHandler.assembler.assembledSentence.values.joined()
      let speculation = testHandler.furiousTypingPreviewedReading ?? ""
      // 前提：待確認讀音在場、投機預覽確有其值（否則本靶無從判別其去留）。
      #expect(
        testHandler.mixedAlphanumericalBuffer == "su",
        "\(tag)：實得 `\(testHandler.mixedAlphanumericalBuffer)`。"
      )
      #expect(
        testHandler.furiousFrontUnfinishedReading == "ㄋㄧ",
        "\(tag)：實得 `\(testHandler.furiousFrontUnfinishedReading ?? "nil")`。"
      )
      #expect(testSession.isFuriousCopilotCandidateWindowVisible, "\(tag)：copilot 窗應在場。")
      #expect(!speculation.isEmpty, "\(tag)：投機預覽應在場。")
      #expect(
        testSession.state.displayedTextConverted == mainText + "su",
        "\(tag)：讀音欄應顯示緩衝原文，實得 `\(testSession.state.displayedTextConverted)`。"
      )
      act()
      #expect(
        testSession.recentCommissions == [mainText + "su"],
        "\(tag)：並存態之遞交內容應恰為「已組字之中文 ＋ 緩衝原文」，實得 \(testSession.recentCommissions)。"
      )
      #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "\(tag)：緩衝應已清空。")
    }
  }

  // MARK: - Test harness

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

  /// 進入「中英混合輸入回退 ＋ 注音狂打」之測試環境：兩顆偏好皆開、狂拼關、POM 關
  /// （免置頂序被擾動）、鍵盤排列為大千，並重置組字狀態。
  private func enterMixedAlnumZhuyinFuriousTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 進入「**僅**中英混合輸入回退」之測試環境：回退開、兩側狂打皆關、POM 關、排列為大千。
  ///
  /// 與 `enterMixedAlnumZhuyinFuriousTestEnvironment` 成對：本檔驗混打之顯示語義時，
  /// 須能單獨取「狂打關」那一態（`InputHandlerTests_MixedAlnum` 之同名環境為 fileprivate）。
  private func enterMixedAlnumOnlyTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  /// 以真語料庫之實錄（`vChewing-VanguardLexicon` 之 `data-v4.8.5.txt`）注入臨時元圖。
  ///
  /// - Parameter kanjiData: 逐行 `<帶調讀音鍵>\t或空格<詞值><分數>`；供靶以**真辭典之權重**
  ///   驗字詞之取捨（測試辭典之 ㄋㄧ 族與真者不同，見 `IH-FuriousZhuyin-035`）。
  /// 逐字取自真語料庫之 ㄋㄧ 族（`data-v4.8.5.txt`）：`ㄋㄧ`（妮 −5.314）／`ㄋㄧˊ`（泥 −5.23）／
  /// `ㄋㄧˇ`（你 −5.074）／`ㄋㄧˋ`（膩 −5.26）。**測試辭典無 `ㄋㄧ` 之陰平條目**（實查：該族
  /// 條目之聲調標記不含陰平形），故凡驗「陰平確認」之靶皆須自備之。
  private static let realLexiconNiFamily = """
  ㄋㄧ 妮 -5.314
  ㄋㄧˊ 泥 -5.23
  ㄋㄧˇ 你 -5.074
  ㄋㄧˋ 膩 -5.26
  """

  private func insertRealLexiconGrams(
    _ handler: MockInputHandler,
    _ kanjiData: String = realLexiconNiFamily
  )
    -> () -> () {
    extractGrams(from: kanjiData).forEach {
      handler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    return { handler.currentLM.clearTemporaryData(isFiltering: false) }
  }

  /// 還原：回退關、兩側狂打關、排列回標準注音、POM 回出廠。
  private func leaveMixedAlnumTestEnvironment() {
    guard let testHandler, let testSession else { return }
    testHandler.prefs.mixedAlphanumericalEnabled = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    leaveFuriousTestEnvironment()
  }

  /// 以注音狂打鍵入，回傳「組字器實際收到之讀音鍵」。
  ///
  /// - Parameters:
  ///   - keys: 鍵序（大千排列）。
  ///   - zhuyinFurious: 是否開啟注音狂打。
  ///   - parser: 注音排列。
  private func typeZhuyinAndCollectReadingKeys(
    _ keys: String,
    zhuyinFurious: Bool,
    parser: Tekkon.MandarinParser = .ofDachen
  )
    -> [String] {
    guard let testHandler, let testSession else { return [] }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = zhuyinFurious
    testHandler.composer.ensureParser(arrange: parser)
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence(keys)
    return testHandler.assembler.actualKeys
  }
}
