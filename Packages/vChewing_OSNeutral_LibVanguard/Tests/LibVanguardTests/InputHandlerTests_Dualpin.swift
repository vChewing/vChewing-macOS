// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Arimitsu
import Foundation
import Homa
import Shared
import Testing

@testable import LibVanguard

// 雙拼（Dualpin）之行為層測試：兩鍵成碼與逐音節固化、待配首鍵之顯示、無效鍵序之示警、
// 同碼重碼詞幹之讀音併入、以及自訂方案之解析與退位。

// MARK: - IH.Dualpin

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: - 雙拼測試輔助

  /// 啟用雙拼輸入（並可一併給定自訂方案之 JSON 原文）。
  ///
  /// 雙拼之「方案槽」與「開關」各自獨立：`keyboardParser4Dualpin` 決定用哪一套方案，
  /// `dualpinEnabledForPinyinTyping` 決定拼音輸入是否走雙拼。此處先把拼音槽備妥
  /// （`keyboardParser` 之 setter 分流），再就雙拼槽與開關明寫。
  func activateDualpin(keyboardParserRawValue: Int, customSchemaJSON: String? = nil) {
    guard let testHandler else { return }
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.keyboardParser4Dualpin = keyboardParserRawValue
    testHandler.prefs.dualpinEnabledForPinyinTyping = true
    testHandler.prefs.dualpinSchemaJSON = customSchemaJSON ?? ""
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()
  }

  /// 還原雙拼測試所動過的偏好設定與暫存語彙。
  func deactivateDualpin() {
    guard let testHandler else { return }
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.prefs.keyboardParser4Dualpin = KeyboardParser.ofDualpinMSPY.rawValue
    testHandler.prefs.dualpinEnabledForPinyinTyping = false
    testHandler.prefs.dualpinSchemaJSON = ""
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    testSession?.resetInputHandler(forceComposerCleanup: true)
  }

  // MARK: - 兩鍵成碼

  /// 雙拼以「聲母鍵＋韻母鍵」兩鍵成碼；下一碼之首鍵到達時，先固化前一未決音節。
  @Test("IH-Dualpin-001 Two-key codes compose and solidify sequentially")
  func test_IH_Dualpin_001_TwoKeyCodesComposeSequentially() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer { deactivateDualpin() }

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄓㄨㄥ"], value: "中測", score: 9),
      .init(keyArray: ["ㄏㄠˇ"], value: "好測", score: 8),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    #expect(testHandler.typingMode == .DualPin)
    // 雙拼之組音區恆為漢語拼音。
    #expect(testHandler.composer.parser == .ofHanyuPinyin)

    // MSPY：「vs」＝「zhong」。
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
    #expect(generateDisplayedText().isEmpty)

    // 下一碼之首鍵到達：先固化「zhong」，再將「h」記為待配首鍵。
    typeSentence("h")
    #expect(testHandler.composer.isEmpty)
    #expect(generateDisplayedText() == "中測")
    #expect(testHandler.dualpinPendingDisplayText == "h")
    // 待配首鍵原樣顯示於組字區（雙拼使用者未必識得注音，故不展開）。
    #expect(testSession.state.displayedText == "中測h")

    // 第二鍵到達：成碼「hk」＝「hao」。
    typeSentence("k")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.romajiBuffer == "hao")

    // 聲調鍵與空白鍵照舊交由漢語拼音打字機處理。
    typeSentence("3")
    typeSentence(" ")
    #expect(testHandler.composer.isEmpty)
    #expect(generateDisplayedText() == "中測好測")
  }

  // MARK: - 無效鍵序

  /// 兩鍵不成碼時示警並同時丟棄兩鍵：既不進組音區，也不落為原文字元；
  /// 示警除鈴聲外，另以一過性之 Tooltip（redAlert 配色、1.2 秒）告知按鍵者該鍵序不合規。
  @Test("IH-Dualpin-002 Invalid key sequence buzzes and drops both keys")
  func test_IH_Dualpin_002_InvalidKeySequenceBuzzesAndDrops() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let tooltipUI = MockTooltipUI()
    let sessionUI = MockSessionUI()
    sessionUI.tooltipUI = tooltipUI
    testSession.ui = sessionUI
    defer {
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    // 尋一組「合法首鍵＋不可能次鍵」之實鍵序：不假設任何特定鍵位之細節。
    let report = DualpinParser.mspy.validate()
    guard let firstKey = report.codeToStems.keys.compactMap(\.first).min(),
          let secondKey = DualpinParser.mspy.alphabet.sorted().first(where: { candidate in
            !report.codeToStems.keys.contains("\(firstKey)\(candidate)")
              && !report.aliasCodeToStems.keys.contains("\(firstKey)\(candidate)")
          })
    else {
      Issue.record("無法自方案中尋得不成碼之鍵序。")
      return
    }
    let code = "\(firstKey)\(secondKey)"

    // 首鍵能起碼，故入待配之列；尚未成碼，故不得示警。
    typeSentence(String(firstKey))
    #expect(testHandler.dualpinPendingDisplayText == String(firstKey))
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.displayedText == String(firstKey))
    #expect(tooltipUI.showCount == 0, "首鍵待配不得發提示，實際 \(tooltipUI.showCount) 次")

    typeSentence(String(secondKey))
    #expect(reportedErrors.count == 1)
    #expect(reportedErrors.first?.contains(code) == true)
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.state.displayedText.isEmpty)
    #expect(tooltipUI.showCount == 1, "不成碼之兩鍵序應發一次提示，實際 \(tooltipUI.showCount) 次")
    #expect(
      tooltipUI.shownTooltip == "i18n:ErrorMessage.InvalidDualpinCode".i18n,
      "提示文案應為「雙拼碼不合規」，實際得到 `\(tooltipUI.shownTooltip ?? "nil")`"
    )
    #expect(
      tooltipUI.shownDuration == 1.2,
      "提示時長應為 1.2 秒，實際得到 \(tooltipUI.shownDuration ?? -1)"
    )
    #expect(
      tooltipUI.shownColorState == .redAlert,
      "提示配色應為 redAlert，實際得到 \(String(describing: tooltipUI.shownColorState))"
    )
  }

  // MARK: - 同碼重碼詞幹

  /// 同一組碼對應多條詞幹時（MSPY 之「lo」＝「lo」與「luo」），
  /// 首選詞幹進組音區，其餘詞幹之讀音於組字查詢時一併併入同一讀音節點。
  @Test("IH-Dualpin-003 Duplicate-code stems merge into one reading node")
  func test_IH_Dualpin_003_DuplicateCodeStemsMerge() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer { deactivateDualpin() }

    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄌㄛˇ"], value: "咯測", score: 9),
      .init(keyArray: ["ㄌㄨㄛˇ"], value: "裸測", score: 8),
    ]
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    typeSentence("lo")
    #expect(["lo", "luo"].contains(testHandler.composer.romajiBuffer))
    // 首選詞幹進組音區，其餘同碼詞幹駐留於翻譯器（此處首選為 "lo"，兄弟為 "luo"）。
    #expect(testHandler.dualpinConfig?.translator.siblingStems == ["luo"])
    typeSentence("3")
    typeSentence(" ")

    guard let firstKey = testHandler.assembler.keys.first else {
      Issue.record("組字器內應有讀音節點。")
      return
    }
    #expect(firstKey.isMultiple)
    #expect(Set(firstKey.allValues) == ["ㄌㄛˇ", "ㄌㄨㄛˇ"])
    // 駐留詞幹一經併入即消耗，不得殘留而錯配於下一音節。
    #expect(testHandler.dualpinConfig?.translator.siblingStems.isEmpty == true)
  }

  // MARK: - 退位與自訂方案

  /// 自訂方案之 JSON 無法解碼（或方案不可用）時，雙拼打字機退位予漢語拼音打字機：
  /// 按鍵不因而遭吞，亦不示警。
  @Test("IH-Dualpin-004 Unusable schema falls back to Hanyu Pinyin")
  func test_IH_Dualpin_004_UnusableSchemaFallsBack() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer {
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    // 自訂雙拼，但方案資料為空 ⇒ 無法解碼。
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinCustom.rawValue)

    #expect(testHandler.typingMode == .DualPin)
    #expect(testHandler.resolveDualpinConfigIfNeeded() == nil)
    #expect(testHandler.dualpinPendingDisplayText == nil)

    typeSentence("ni")
    // 退位後即一般漢語拼音：字母於組音區照常累積。
    #expect(testHandler.composer.romajiBuffer == "ni")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(reportedErrors.isEmpty)
  }

  /// 自訂雙拼之 JSON 原文可解碼且校驗無誤時，即以其為方案（此處以 GB/T 34947-2017 之資料為底、
  /// 換上自訂 rawID）。
  @Test("IH-Dualpin-005 Custom schema resolves from preference")
  func test_IH_Dualpin_005_CustomSchemaResolves() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer { deactivateDualpin() }
    testSession.resetInputHandler(forceComposerCleanup: true)

    let customJSON = DualpinParser.gbt17SchemaJSON
      .replacingOccurrences(of: "dualPin.GBT17", with: "dualPin.TestCustom")
    activateDualpin(
      keyboardParserRawValue: KeyboardParser.ofDualpinCustom.rawValue,
      customSchemaJSON: customJSON
    )

    guard let config = testHandler.resolveDualpinConfigIfNeeded() else {
      Issue.record("自訂方案應可解析。")
      return
    }
    #expect(config.isUsable)
    #expect(config.parser.rawID == "dualPin.TestCustom")

    // GB/T 34947-2017：「vs」＝「zhong」。
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
  }

  // MARK: - 分號尾鍵

  /// 分號是 MSPY 鍵位空間內之合法尾鍵（`ing`），而主機並未佔用它——故不經任何
  /// 按鍵分流手術即直抵打字機。此處以「b;」＝「bing」走一次完整歷程以坐實該結論。
  @Test("IH-Dualpin-006 Semicolon ending key needs no triage surgery")
  func test_IH_Dualpin_006_SemicolonEndingKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer {
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    typeSentence("b")
    #expect(testHandler.dualpinPendingDisplayText == "b")
    typeSentence(";")
    #expect(testHandler.composer.romajiBuffer == "bing")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(reportedErrors.isEmpty)
  }

  // MARK: - 方案槽與開關之分工

  /// 「雙拼模式」開關只決定拼音輸入是否走雙拼，不動雙拼之方案槽：
  /// 關閉後當前佈局退回拼音槽、再開啟即復歸同一雙拼方案。
  @Test("IH-Dualpin-007 Dualpin switch gates the scheme slot")
  func test_IH_Dualpin_007_SwitchGatesSchemeSlot() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer { deactivateDualpin() }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinGBT17.rawValue)

    #expect(testHandler.currentKeyboardParserType == .ofDualpinGBT17)
    #expect(testHandler.typingMode == .DualPin)
    // 拼音槽仍住一般漢語拼音：雙拼不曾挪用拼音方案之選擇。
    #expect(testHandler.prefs.keyboardParser == KeyboardParser.ofHanyuPinyin.rawValue)

    // 關閉雙拼開關：雙拼方案槽原樣不動，當前佈局退回拼音槽。
    testHandler.prefs.dualpinEnabledForPinyinTyping = false
    testHandler.ensureKeyboardParser()
    #expect(testHandler.prefs.keyboardParser4Dualpin == KeyboardParser.ofDualpinGBT17.rawValue)
    #expect(testHandler.currentKeyboardParserType == .ofHanyuPinyin)
    // 退回拼音家族（狂打與否由狂打開關另行決定），但絕不再是雙拼。
    #expect(testHandler.typingMode != .DualPin)

    // 一般漢語拼音下「b」逕入組音區，不落為雙拼之待配首鍵。
    typeSentence("b")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.romajiBuffer == "b")

    // 重開開關：復歸同一雙拼方案，兩鍵成碼之待配首鍵語義隨之回來。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.dualpinEnabledForPinyinTyping = true
    testHandler.ensureKeyboardParser()
    #expect(testHandler.currentKeyboardParserType == .ofDualpinGBT17)
    #expect(testHandler.typingMode == .DualPin)
    typeSentence("b")
    #expect(testHandler.dualpinPendingDisplayText == "b")
  }

  // MARK: - 刪除鍵

  /// 待配首鍵在場時按刪除鍵：應就地撤銷該首鍵，不得誤發蜂鳴、亦不得留下殘影。
  @Test("IH-Dualpin-008 Backspace consumes a pending first key")
  func test_IH_Dualpin_008_BackspaceConsumesPendingFirstKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    // 狂打開關之兩態皆然：本鍵該被雙拼自收，不許流入常規刪除流程而對空組字器誤發蜂鳴。
    for furious in [true, false] {
      testHandler.prefs.furiousTypingEnabled4Pinyin = furious
      typeSentence("h")
      #expect(testHandler.dualpinPendingDisplayText == "h")
      #expect(testSession.state.displayedText == "h")

      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
      #expect(testHandler.dualpinPendingDisplayText == nil)
      #expect(testSession.state.displayedText.isEmpty)
      #expect(reportedErrors.isEmpty)
    }

    // 未決碼所譯出之音節：退格以**整個音節**為粒度（見 `IH-Dualpin-014`），不逐字母刪。
    // 此態必自狂打開啟之側驗：非狂打模式下次鍵成碼即固化入組字器，組音區不留詞幹
    // （見 `IH-Dualpin-010`）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
    #expect(reportedErrors.isEmpty)
  }

  /// 未決碼所譯出之音節以整個音節為退格粒度：逐字母刪拼音只留半截讀音，既不成碼亦難查詞。
  @Test("IH-Dualpin-014 Backspace discards the whole translated syllable")
  func test_IH_Dualpin_014_BackspaceDiscardsWholeTranslatedSyllable() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)
    testHandler.prefs.furiousTypingEnabled4Pinyin = true

    // 組字器空：整個音節俱去，狀態收為空。
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.displayedText.isEmpty)
    #expect(reportedErrors.isEmpty)

    // 前有已固化之音節時，只撤未決碼之音節，已固化者不動。
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("vs")
    typeSentence("h")
    #expect(testHandler.assembler.keys.count == 1)
    typeSentence("k")
    #expect(testHandler.composer.romajiBuffer == "hao")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.keys.count == 1)
    #expect(reportedErrors.isEmpty)
  }

  // MARK: - 首鍵即成桶

  /// 首鍵（待配鍵）一按下即出窗：桶由「以該鍵為首之諸碼」推算，不必等次鍵成碼。
  /// 該窗即副駕（copilot）窗（事主 2026-10-14 裁定：雙拼之音節恆為兩鍵，故首鍵即未完成之讀音），
  /// 其頂部 pane 須示該首鍵之「原始碼 → 全等碼義」提示（即方案兩表中值等於該鍵之聲母／介母／
  /// 韻母，非前綴窮舉之詞幹；事主 2026-10-13 回報外觀上獨缺此特徵、2026-10-14 指正寬度）。
  @Test("IH-Dualpin-015 Copilot window appears on the pending first key")
  func test_IH_Dualpin_015_CopilotWindowAppearsOnPendingFirstKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    // 狂打關：首鍵不出桶（桶之源為未決碼，狂打關時不提供前方上下文），亦無 pane。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    typeSentence("v")
    #expect(testHandler.dualpinPendingDisplayText == "v")
    #expect(testSession.state.candidates.isEmpty)
    #expect(testSession.unfinishedReading == nil)
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))

    // 狂打開：首鍵即出桶；雙拼之音節恆為兩鍵，故該首鍵（半截之碼）即「未完成之讀音」
    // （事主 2026-10-14 裁定）⇒ 本窗**就是** copilot 窗、窗頂 pane 亦得示該首鍵之提示。
    // 惟該拍無讀音可固化（半截之碼不成音節、其桶含該首鍵所能開啟之全部詞幹之全部讀音），
    // 固化路徑一律讓位，而 Shift＋選字鍵則可提前選字（見 IH-Dualpin-016）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    typeSentence("v")
    #expect(testHandler.dualpinPendingDisplayText == "v")
    #expect(testHandler.composer.isEmpty)
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    let firstKeyPane = try #require(testSession.unfinishedReading)
    // pane 右側只列該鍵於**首鍵之位**之意義（微軟雙拼之 `v` 即聲母 `zh`；韻母 `ui` 雖亦以 `v`
    // 為鍵，然屬次鍵之位，不列），亦不列 `zhong` 之類之前綴詞幹——否則 pane 一寬即不可讀
    // （事主 2026-10-14 兩度指正）。
    #expect(firstKeyPane == "v → zh")

    // 次鍵成碼後，素材改由注拼槽供給，pane 回到（真正的）copilot 判準之路徑。
    typeSentence("s")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.romajiBuffer == "zhong")
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(testSession.unfinishedReading != firstKeyPane)
    #expect(reportedErrors.isEmpty)
  }

  /// 首鍵之拍即允許「Shift＋選字鍵」提前選字（copilot 之語意本就如此）：選中後翻譯狀態機之
  /// 待配首鍵即告消耗——否則緊接之次鍵會與同一首鍵再次成碼（同一音節重複入庫）；
  /// 而該拍之固化（Enter／Tab／方向鍵／標點）則一律讓位、不成音節。
  @Test("IH-Dualpin-016 Shift selection works on the pending first key")
  func test_IH_Dualpin_016_ShiftSelectionOnPendingFirstKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      testSession.mockCandidateController = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)
    testHandler.prefs.furiousTypingEnabled4Pinyin = true

    typeSentence("v")
    #expect(testHandler.dualpinPendingDisplayText == "v")
    #expect(testHandler.composer.isEmpty)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    let topCandidate = try #require(testSession.state.candidates.first)

    // 模擬候選窗已顯示（handleCandidate 需要 ctlCandidate.visible）。
    testSession.mockCandidateController = MockCandidateController(visible: true)
    let shift1 = KBEvent.KeyEventData(
      flags: .shift, chars: "!", charsSansModifiers: "1", keyCode: 18
    ).asEvent
    #expect(testHandler.triageInput(event: shift1))

    // 待配首鍵已消耗、注拼槽亦淨空。
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testSession.state.candidates.isEmpty)
    #expect(testSession.state.type == .ofInputting)
    // 置頂候選之讀音已入組字器。
    #expect(generateDisplayedText().contains(topCandidate.value))

    // 同一首鍵再按一次：成全新的待配首鍵（而非複用已消耗者）。
    typeSentence("v")
    #expect(testHandler.dualpinPendingDisplayText == "v")
    #expect(topCandidate.value.isEmpty == false)
    #expect(reportedErrors.isEmpty)
  }

  // MARK: - 狂打開關與雙拼

  /// 雙拼不另立狂打開關：狂打各特性之有無一律隨**拼音側**之狂打開關，
  /// 而雙拼之兩鍵成碼不受該開關影響。
  @Test("IH-Dualpin-009 Dualpin furious features follow the pinyin furious switch")
  func test_IH_Dualpin_009_FuriousFeaturesFollowPinyinSwitch() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    let originalFuriousZhuyin = testHandler.prefs.furiousTypingEnabled4Zhuyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.prefs.furiousTypingEnabled4Zhuyin = originalFuriousZhuyin
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    // 拼音側狂打開啟：雙拼共享狂打特性，惟打字模式仍是雙拼。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    #expect(testHandler.typingMode == .DualPin)
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isFuriousCopilotEligible)

    // 拼音側狂打關閉：雙拼之狂打特性隨之失效，打字模式不變。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    #expect(testHandler.typingMode == .DualPin)
    #expect(!testHandler.isFuriousTypingModeEffective)
    #expect(!testHandler.isFuriousCopilotEligible)

    // 注音側之狂打開關與雙拼無涉（雙拼恆屬拼音家族）。
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    #expect(!testHandler.isFuriousTypingModeEffective)

    // 兩鍵成碼照舊（狂打開啟之態：讀音續留組音區，固化時機見 `IH-Dualpin-010`）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
  }

  // MARK: - 次鍵即成桶

  /// 狂打關閉時：兩鍵既已成碼，該碼之讀音節點於**次鍵當下**即落入組字器，
  /// 組音區隨之清空——不待下一鍵之首鍵、亦不待空白鍵。
  /// 狂打開啟時則否：讀音續留組音區，固化交由狂打諸義處置。
  @Test("IH-Dualpin-010 A completed code lands in the assembler on its second key unless furious typing is on")
  func test_IH_Dualpin_010_SecondKeyAssemblesWhenNotFurious() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    // 狂打關閉：首鍵仍只作顯示，組音區與組字器俱空。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    typeSentence("v")
    #expect(testHandler.dualpinPendingDisplayText == "v")
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)

    // 次鍵成碼：本碼之讀音節點當即落入組字器，組音區清空、待配首鍵亦去。
    typeSentence("s")
    #expect(testHandler.dualpinPendingDisplayText == nil)
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.keys.count == 1)
    guard let key = testHandler.assembler.keys.first else {
      Issue.record("次鍵成碼後，組字器內應有讀音節點。")
      return
    }
    // 無調之拼音詞幹「zhong」⇒ 固化時展開為無調與諸聲調之諸讀音，皆住同一節點。
    #expect(Set(key.allValues).isSuperset(of: ["ㄓㄨㄥ", "ㄓㄨㄥˊ", "ㄓㄨㄥˇ", "ㄓㄨㄥˋ"]))

    // 狂打開啟：同一鍵序下讀音續留組音區，不即時固化——固化時機隨狂打開關而異。
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    typeSentence("vs")
    #expect(testHandler.composer.romajiBuffer == "zhong")
  }

  // MARK: - 非碼鍵一律比照非雙拼之拼音（P309）

  /// 狂打側之待配首鍵即「未完成之讀音」，故其非碼鍵之處置必須與**非雙拼之拼音**逐項一致
  /// （事主 2026-10-14 裁定：「雙拼的標點走漢語拼音標點處理方法；雙拼的非碼鍵全部按照漢語
  /// 拼音（非雙拼）的處理方式」）。本測試即該一致性之釘樁：同一顆非碼鍵分別落於
  /// 「雙拼之半碼待配（微軟雙拼之 `v`＝聲母 zh）」與「拼音之未完成前綴（`zh`）」之下，
  /// 比對其後之可觀察結果——是否被處理、示警、組字結果、狀態型別、顯示、素材是否被消費。
  ///
  /// - Note: 顯示之嚴格比對只在「素材確已被消費」時成立：素材未被消費時，兩側之未完成原文
  ///   （雙拼之半碼 vs 拼音之字母流）本即不同形，此差異非語義差異。
  @Test("IH-Dualpin-011 Non-code keys follow the non-dualpin pinyin path")
  func test_IH_Dualpin_011_NonCodeKeysFollowPinyinPath() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }

    func activatePinyin() {
      testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
      testHandler.prefs.dualpinEnabledForPinyinTyping = false
      testHandler.prefs.dualpinSchemaJSON = ""
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
      testHandler.currentLM.syncPrefs()
    }

    func observe(
      dualpin: Bool,
      furious: Bool,
      key: KBEvent.KeyEventData
    )
      -> (
        handled: Bool?, errors: [String], sentence: [String], display: String,
        stateType: String, consumed: Bool
      ) {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.furiousTypingEnabled4Pinyin = furious
      if dualpin {
        activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)
        typeSentence("v")
      } else {
        activatePinyin()
        typeSentence("zh")
      }
      reportedErrors.removeAll()
      let handled = testHandler.triageInput(event: key.asEvent)
      return (
        handled: handled,
        errors: reportedErrors,
        sentence: testHandler.assembler.assembledSentence.map(\.value),
        display: testSession.state.displayedText,
        stateType: "\(testSession.state.type)",
        consumed: dualpin
          ? testHandler.dualpinPendingDisplayText == nil
          : testHandler.composer.romajiBuffer.isEmpty
      )
    }

    // 非碼鍵：既不屬雙拼之碼鍵、亦不屬拼音之讀音字母。
    let nonCodeKeys: [(name: String, key: KBEvent.KeyEventData)] = [
      ("comma", .init(chars: ",")),
      ("slash", .init(chars: "/")),
      ("tab", .dataTab),
      ("arrowLeft", .dataArrowLeft),
      ("arrowRight", .dataArrowRight),
      ("digit9", .init(chars: "9")),
      ("forwardDelete", .forwardDelete),
      ("space", .init(chars: " ")),
      ("enter", .dataEnterReturn),
    ]
    // 狂打側之奇偶比對：素材為「未完成之讀音」時，非碼鍵之處置必須逐項與拼音狂打一致。
    for (name, key) in nonCodeKeys {
      let context = "（狂打、鍵＝\(name)）"
      let dp = observe(dualpin: true, furious: true, key: key)
      let py = observe(dualpin: false, furious: true, key: key)
      #expect(dp.handled == py.handled, "「是否被處理」不一致\(context)")
      #expect(
        dp.errors == py.errors,
        "示警不一致\(context)：雙拼 \(dp.errors) vs 拼音 \(py.errors)"
      )
      #expect(
        dp.sentence == py.sentence,
        "組字結果不一致\(context)：雙拼 \(dp.sentence) vs 拼音 \(py.sentence)"
      )
      #expect(dp.stateType == py.stateType, "狀態型別不一致\(context)")
      #expect(dp.consumed == py.consumed, "素材之消費不一致\(context)")
      if dp.consumed, py.consumed {
        #expect(
          dp.display == py.display,
          "顯示不一致\(context)：雙拼 \(dp.display) vs 拼音 \(py.display)"
        )
      }
      // 幽靈顯示之禁令：素材既已被消費，顯示不得再現該半截之碼。
      if dp.consumed {
        #expect(
          !dp.display.contains("v"),
          "首鍵既已消費，不得留幽靈讀音於顯示\(context)：\(dp.display)"
        )
      }
    }

    // 非狂打側**不**比照拼音：彼時之非碼鍵為音節邊界，雙拼於 P302 定為「逕捨半碼、本鍵交予
    // 使用者端」（拼音側則因未完成讀音仍在注拼槽而被示警吞下）。此差異係既有之設計抉擇，
    // 不屬 P309 之範疇，惟其不變量——**半碼不留存**——於兩側皆須成立。
    for (name, key) in nonCodeKeys {
      let dp = observe(dualpin: true, furious: false, key: key)
      #expect(dp.consumed, "非狂打之雙拼於非碼鍵後不得留存半碼（鍵＝\(name)）")
      #expect(
        !dp.display.contains("v"),
        "非狂打之雙拼於非碼鍵後不得留幽靈讀音（鍵＝\(name)）：\(dp.display)"
      )
    }
  }

  // MARK: - 不可能起碼之鍵序

  /// 微軟雙拼之零聲母前綴鍵為 `o`（啊＝`oa`），故**無任何碼起於 `a`**：首鍵「a」本身即不可能起碼
  /// （GB/T 34947-2017 之零聲母鍵為 `a`，同一鍵序於彼反倒是主碼）。
  /// ★ P310：該鍵於按下當場即示警（鈴聲＋redAlert 配色、1.2 秒之 Tooltip）並逕行丟棄——既不進
  /// 待配之列、亦不落原文；故「aa」永無湊碼之機會，尤不得被讀成 啊（零聲母讀音）。
  @Test("IH-Dualpin-012 First key that can start no code is alerted and dropped")
  func test_IH_Dualpin_012_ImpossibleFirstKeyIsRejected() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let sessionUI = MockSessionUI()
    testSession.ui = sessionUI
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    for furious in [true, false] {
      // 提示計數逐態清零，免得兩態互相污染。
      let tooltipUI = MockTooltipUI()
      sessionUI.tooltipUI = tooltipUI
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.furiousTypingEnabled4Pinyin = furious
      reportedErrors.removeAll()

      // 首鍵本身即不可能起碼：按下當場示警一次、逕行丟棄——不入待配之列、零讀音。
      typeSentence("a")
      #expect(!reportedErrors.isEmpty, "不可能起碼之首鍵應示警。")
      #expect(
        tooltipUI.showCount == 1,
        "不可能起碼之首鍵應發一次提示（furious＝\(furious)），實際 \(tooltipUI.showCount) 次"
      )
      #expect(tooltipUI.shownTooltip == "i18n:ErrorMessage.InvalidDualpinFirstKey".i18n)
      #expect(tooltipUI.shownDuration == 1.2)
      #expect(tooltipUI.shownColorState == .redAlert)
      #expect(
        testHandler.dualpinPendingDisplayText == nil,
        "該鍵不得入待配之列（furious＝\(furious)）"
      )
      #expect(testHandler.composer.isEmpty)
      #expect(testHandler.assembler.isEmpty)
      #expect(testSession.state.displayedText.isEmpty)

      // 再敲一次亦然：兩鍵永無湊成一碼之機會，尤不得落為 啊（零聲母讀音）。
      typeSentence("a")
      #expect(tooltipUI.showCount == 2, "（furious＝\(furious)）")
      #expect(testHandler.dualpinPendingDisplayText == nil)
      #expect(testHandler.composer.isEmpty)
      #expect(testHandler.assembler.isEmpty)
      #expect(testSession.state.displayedText.isEmpty)
    }

    // 對照：同一鍵序「aa」於 GB/T 34947-2017 反倒是主碼（其零聲母前綴鍵為 `a`）——足見此鍵序之
    // 不成碼係方案鍵位所致，而不得以別名另闢蹊徑。
    let gbTooltipUI = MockTooltipUI()
    sessionUI.tooltipUI = gbTooltipUI
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser4Dualpin = KeyboardParser.ofDualpinGBT17.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    reportedErrors.removeAll()
    typeSentence("aa")
    #expect(reportedErrors.isEmpty)
    #expect(gbTooltipUI.showCount == 0)
    #expect(testHandler.assembler.keys.count == 1)
  }

  // MARK: - 字面節點之後的數字連打

  /// 組字器尾端為字面標點節（如 `_punctuation_1`）時，其後之數字鍵不得被
  /// 「覆寫身後聲調」（`performRearIntonationOverrideIfNeeded`）之流程當作聲調鍵吞掉：
  /// 該流程須認出後節點並非讀音音節而放行，令數字續落標點鏈、逐鍵成節。
  /// 狂打開關之兩態皆然——本缺陷與狂打無涉，狂打只是叫它更容易被撞見。
  @Test("IH-Dualpin-013 Consecutive digit keys insert literal nodes")
  func test_IH_Dualpin_013_ConsecutiveDigitKeysInsertLiteralNodes() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    for furious in [true, false] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.furiousTypingEnabled4Pinyin = furious
      reportedErrors.removeAll()

      ["1", "2", "3"].forEach { typeSentence($0) }
      #expect(
        reportedErrors.isEmpty,
        "連打數字不得示警（furious＝\(furious)）：\(reportedErrors)"
      )
      #expect(
        testHandler.assembler.assembledSentence.map(\.value) == ["1", "2", "3"],
        "數字應逐鍵落為字面節（furious＝\(furious)）"
      )
    }
  }

  // MARK: - 待配首鍵期間之數字鍵（P309 之釘樁）

  /// 狂打側之待配首鍵即「未完成之讀音」：數字鍵到達時，先結算該讀音（與拼音側之
  /// `handlePunctuation` 同一條路：先固化前方讀音、再落本鍵），該數字仍落為一般字面節；
  /// 不示警、亦不留待配之首鍵（其素材已隨固化而去）。
  ///
  /// - Note: **非狂打側**不在此列——彼時無 copilot 候選窗、亦無「前方固化」之語義，
  ///   該首鍵純為顯示素材，故依 P302／P308 之口徑逕行作廢：素材不留、數字仍落字面節。
  ///   兩側之共同點（數字落字面節、狀態為 `.ofInputting` 而得為 BkSp 所刪）即
  ///   `SS-Lifecycle-012` 所關切之病灶之外緣。
  @Test("IH-Dualpin-017 Digit during a pending first key settles the front then lands literally")
  func test_IH_Dualpin_017_DigitDuringPendingFirstKeySettlesThenLands() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    for furious in [true, false] {
      for digit in ["2", "9"] {
        testSession.resetInputHandler(forceComposerCleanup: true)
        testHandler.prefs.furiousTypingEnabled4Pinyin = furious
        reportedErrors.removeAll()

        // 首鍵縱入待配之列，亦不得落任何讀音，且不得示警。
        typeSentence("s")
        #expect(testHandler.composer.isEmpty)
        #expect(testHandler.assembler.isEmpty)
        #expect(testHandler.dualpinPendingDisplayText == "s")

        typeSentence(digit)
        #expect(
          testHandler.dualpinPendingDisplayText == nil,
          "數字鍵落定後首鍵不得仍待配（furious＝\(furious)、鍵＝\(digit)）"
        )
        #expect(
          reportedErrors.isEmpty,
          "數字鍵不示警（furious＝\(furious)、鍵＝\(digit)）：\(reportedErrors)"
        )
        let sentence = testHandler.assembler.assembledSentence.map(\.value)
        #expect(
          sentence.last == digit,
          "數字應落為字面節（furious＝\(furious)、鍵＝\(digit)）：\(sentence)"
        )
        #expect(
          testSession.state.type == .ofInputting,
          "落定後應為組字中，方得為 BkSp 所刪（furious＝\(furious)、鍵＝\(digit)）"
        )
        // 狂打側：首鍵之讀音先結算入庫，故除數字節外尚有一格；非狂打側：首鍵逕行作廢，
        // 只餘數字節。
        #expect(
          sentence.count == (furious ? 2 : 1),
          "狂打側應先結算讀音桶（furious＝\(furious)、鍵＝\(digit)）：\(sentence)"
        )
      }
    }
  }

  // MARK: - 不可能起碼之首鍵與其後之數字鍵（P310 之釘樁）

  /// 事主 2026-10-15 報：首鍵不可能起碼時（微軟雙拼之 `a`／`e`／`;`），copilot 候選窗無由成立；
  /// 若任其入待配之列，其後之數字鍵即落於「有素材待結算、實則無物可結算」之窘境——標點路徑之
  /// 固化不成，反遭 `A9B69908D` 守衛吞鍵：noop＋蜂鳴。
  /// ★ P310：該首鍵按下當場即示警並丟棄，故隨後之數字鍵與平常無異——逕落字面節、不再蜂鳴。
  @Test("IH-Dualpin-018 Dead first key is dropped; a following digit lands literally")
  func test_IH_Dualpin_018_DeadFirstKeyThenDigit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    var reportedErrors: [String] = []
    testHandler.errorCallback = { reportedErrors.append($0) }
    let sessionUI = MockSessionUI()
    testSession.ui = sessionUI
    let originalFurious = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.furiousTypingEnabled4Pinyin = originalFurious
      testHandler.errorCallback = nil
      deactivateDualpin()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    activateDualpin(keyboardParserRawValue: KeyboardParser.ofDualpinMSPY.rawValue)

    for furious in [true, false] {
      for key in ["e", ";"] {
        let tooltipUI = MockTooltipUI()
        sessionUI.tooltipUI = tooltipUI
        testSession.resetInputHandler(forceComposerCleanup: true)
        testHandler.prefs.furiousTypingEnabled4Pinyin = furious
        reportedErrors.removeAll()

        // 不可能起碼之首鍵：當場示警並丟棄，既不入待配之列、亦不落任何讀音。
        typeSentence(key)
        #expect(tooltipUI.showCount == 1, "（furious＝\(furious)、鍵＝\(key)）")
        #expect(tooltipUI.shownTooltip == "i18n:ErrorMessage.InvalidDualpinFirstKey".i18n)
        #expect(tooltipUI.shownDuration == 1.2)
        #expect(tooltipUI.shownColorState == .redAlert)
        #expect(testHandler.dualpinPendingDisplayText == nil)
        #expect(
          testHandler.assembler.isEmpty,
          "首鍵不得落任何讀音（furious＝\(furious)、鍵＝\(key)）"
        )

        // 其後之數字鍵：首鍵既已作廢，本鍵即無待結算之素材——逕落字面節，不得 noop＋蜂鳴。
        reportedErrors.removeAll()
        typeSentence("9")
        #expect(
          reportedErrors.isEmpty,
          "首鍵既已作廢，數字鍵不得蜂鳴（furious＝\(furious)、鍵＝\(key)）：\(reportedErrors)"
        )
        let sentence = testHandler.assembler.assembledSentence.map(\.value)
        #expect(
          sentence == ["9"],
          "數字應落為字面節（furious＝\(furious)、鍵＝\(key)）：\(sentence)"
        )
        #expect(
          testSession.state.type == .ofInputting,
          "落定後應為組字中，方得為 BkSp 所刪（furious＝\(furious)、鍵＝\(key)）"
        )
      }
    }
  }
}
