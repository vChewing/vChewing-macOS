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

// 基本組句、遞交與候選視窗之核心流程。

// MARK: - IH.Composition

extension LibVanguardTestsRoot.InputHandlerTests {
  /// 測試基本的打字組句（不是ㄅ半注音）。
  @Test("IH-Composition-001 Basic sentence composition")
  func test_IH_Composition_001_BasicSentenceComposition() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳，但這裡暫時先期待失敗結果「優跌能留意旅方」")
    testSession.resetInputHandler(forceComposerCleanup: true)
    // 打「幽蝶能留一縷芳」的讀音：「ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧ ㄌㄩˇ ㄈㄤ」，最後空白字元是陰平聲調。
    typeSentence("u. 2u,6s/6xu.6u4xm3z; ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(resultText1 == "優跌能留意旅方")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "優跌能留意旅方")
  }

  /// 測試基本的逐字選字（ㄅ半注音）：完整打完「幽蝶能留一縷芳」。
  ///
  /// 逐字選字的行為高度依賴選字窗的參與（方向鍵導航、選字鍵選取、以新讀音首鍵
  /// 自動確認當前高亮候選），所以此處安裝會實際導航的模擬選字窗控制器。
  @Test("IH-Composition-002 Basic SCPC typing")
  func test_IH_Composition_002_BasicSCPCTyping() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：幽蝶能留一縷芳")
    testSession.resetInputHandler(forceComposerCleanup: true)
    // 安裝可見、且會跟隨候選清單的模擬選字窗，讓選字流程得以如生產環境般進行。
    // 每行候選容量為 6：對應生產端 `prefs.candidateKeys` 的預設值 "123456"。
    testSession.installMockCandidateController(capacityPerPage: 6)
    defer { testSession.mockCandidateController = nil }

    func pressArrowDown(_ count: Int = 1) {
      (0 ..< count).forEach { _ in
        _ = testHandler.triageInput(event: KBEvent.KeyEventData.nextCandidateEvent.asEvent)
      }
    }

    typeSentence("u. 3")
    typeSentence("2u,62")
    typeSentence("s/6")
    typeSentence("xu.63")
    typeSentence("u4")
    pressArrowDown(3)
    typeSentence("3")
    typeSentence("xm3")
    pressArrowDown()
    typeSentence("1")
    typeSentence("z; ")
    typeSentence("2")

    let resultText1 = testSession.recentCommissions.joined()
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(resultText1 == "幽蝶能留一縷芳")
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  @Test("IH-Composition-003 Misc commission test")
  func test_IH_Composition_003_MiscCommissionTest() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("dk ru4204el ")
    guard let handler = testSession.inputHandler else {
      Issue.record("testSession.handler is nil.")
      return
    }
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    #expect(result == "ㄎㄜ ㄐㄧˋ ㄉㄢˋ ㄍㄠ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    #expect(result == "科(ㄎㄜ)技(ㄐㄧˋ)蛋(ㄉㄢˋ)糕(ㄍㄠ)")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>蛋<rp>(</rp><rt>ㄉㄢˋ</rt><rp>)</rp></ruby><ruby>糕<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby>
    """
    #expect(result == expectedRubyResult)
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "⠇⠮⠄⠅⠡⠐⠙⠧⠐⠅⠩⠄")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "⠅⠢⠁⠛⠊⠆⠙⠧⠆⠛⠖⠁")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 5
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "L!'K*\"DV\"K%'")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 6
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "K5AGI2DV2G6A")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  @Test("IH-Composition-004 Misc commission ButKo BPMFVS")
  func test_IH_Composition_004_MiscCommissionButKoBPMFVS() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }

    guard let handler = testSession.inputHandler else {
      Issue.record("testSession.handler is nil.")
      return
    }

    let vs1 = String(UnicodeScalar(0xE01E1)!)
    let result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "咱\(vs1)地\(vs1)")
  }

  @Test("IH-Composition-005 ButKo BPMFVS display reflection")
  func test_IH_Composition_005_ButKoBPMFVSDisplayReflection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = true
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }

    let vs1 = String(UnicodeScalar(0xE01E1)!)
    let reflectedState = testHandler.generateStateOfInputting()
    #expect(reflectedState.displayedText == "咱\(vs1)地\(vs1)")

    let rawCommitState = testHandler.generateStateOfInputting(sansReading: true)
    #expect(rawCommitState.displayedText == "咱地")

    let candidateState = testHandler.generateStateOfCandidates(dodge: false)
    #expect(candidateState.displayedText == "咱\(vs1)地\(vs1)")

    testHandler.prefs.reflectBPMFVSInCompositionBuffer = false
    let plainState = testHandler.generateStateOfInputting()
    #expect(plainState.displayedText == "咱地")
  }

  @Test("IH-Composition-006 ButKo BPMFVS plain Enter commits raw text")
  func test_IH_Composition_006_ButKoBPMFVSPlainEnterCommitsRawText() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = true
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }
    testSession.switchState(testHandler.generateStateOfInputting())

    let vs1 = String(UnicodeScalar(0xE01E1)!)
    #expect(testHandler.generateStateOfInputting().displayedText == "咱\(vs1)地\(vs1)")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "咱地")
  }

  /// 確認 BPMFVS 投影不會污染 marking state 的使用者加詞操作。
  @Test("IH-Composition-007 ButKo BPMFVS marking state does not pollute")
  func test_IH_Composition_007_ButKoBPMFVSMarkingStateDoesNotPollute() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = true
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }
    testSession.switchState(testHandler.generateStateOfInputting())

    // 確認 BPMFVS 投影在 display 中已啟用。
    let vs1 = String(UnicodeScalar(0xE01E1)!)
    #expect(testHandler.generateStateOfInputting().displayedText == "咱\(vs1)地\(vs1)")

    // 進入 marking state（Shift+Left 兩次，選取全部內容）。
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testSession.state.type == .ofMarking)
    #expect(testSession.state.markedRange == 0 ..< 2)

    // 確認 rawDisplayTextSegments 已正確傳入 ofMarking()，
    // 使 marking state 內的 userPhraseKVPair 能使用原始文字。
    // （tooltip 內容在 MainAssembly 層產生，LibVanguard 測試環境不連結 MainAssembly 故不檢查 tooltip 字串）
    #expect(
      testSession.state.data.rawDisplayTextSegments?.joined() == "咱地",
      "rawDisplayTextSegments should be correctly passed to ofMarking()"
    )

    // 取出 userPhraseKVPair，驗證值為原始文字（不含 Variation Selector）。
    let kvPair = testSession.state.data.userPhraseKVPair
    #expect(kvPair.value == "咱地")
    #expect(!kvPair.value.unicodeScalars.contains(where: {
      (0xE0100 ... 0xE01EF).contains($0.value)
    }))

    // 觸發使用者加詞操作（Enter），驗證寫入的是原始文字。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let fetchables = testHandler.currentLM.unigramsFor(keyArray: ["ㄗㄚˊ", "ㄉㄜ˙"])
    let addedUnigramExists = fetchables.contains(where: { $0.current == "咱地" })
    #expect(addedUnigramExists)
    // 確認沒有寫入含 Variation Selector 的髒資料。
    let taintedUnigramExists = fetchables.contains(where: {
      $0.current.unicodeScalars.contains(where: { (0xE0100 ... 0xE01EF).contains($0.value) })
    })
    #expect(!taintedUnigramExists)
  }

  /// 確認候選預覽不會讓 raw / display 狀態重新失去同步。
  @Test("IH-Composition-008 ButKo BPMFVS candidate preview keeps raw state in sync")
  func test_IH_Composition_008_ButKoBPMFVSCandidatePreviewKeepsRawStateInSync() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let grams: [Homa.Gram] = [
      .init(keyArray: ["ㄗㄚˊ"], value: "咱", score: 10),
      .init(keyArray: ["ㄗㄚˊ"], value: "雜", score: 9),
    ]
    grams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = true
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    testSession.switchState(testHandler.generateStateOfCandidates())

    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.data.rawDisplayedText == "咱")

    guard let previewIndex = testSession.state.candidates.firstIndex(where: { $0.value == "雜" }) else {
      Issue.record("Missing preview candidate: 雜")
      return
    }

    testSession.candidatePairHighlightChanged(at: previewIndex)

    #expect(testSession.state.highlightedCandidateIndex == previewIndex)
    #expect(testSession.state.data.rawDisplayedText == "雜")
  }

  /// 確認 marking state 的 rawDisplayTextSegments 參數正確傳遞至 ofMarking()。
  /// LibVanguard 測試層級驗證 raw text 傳遞正確性；tooltip 內容驗證由 MainAssembly 層測試負責。
  @Test("IH-Composition-009 Marking state raw text passing")
  func test_IH_Composition_009_MarkingStateRawTextPassing() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 不啟用 BPMFVS：raw text 應與 display text 相同。
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = false

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }
    testSession.switchState(testHandler.generateStateOfInputting())

    // 進入 marking state（Shift+Left 兩次）。
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testSession.state.type == .ofMarking)
    #expect(testSession.state.markedRange == 0 ..< 2)

    // 核心驗證：userPhraseKVPair.value 正確（透過 rawDisplayTextSegments 或 fallback displayedText）。
    // BPMFVS 關閉時 rawDisplayTextSegments 為 nil，value 取自 displayedText（此時兩者相同）。
    let kvPair = testSession.state.data.userPhraseKVPair
    #expect(kvPair.value == "咱地", "userPhraseKVPair.value should be '咱地', but got: \(kvPair.value)")
  }

  /// 測試就地輪替候選字。
  @Test("IH-Composition-010 Revolving candidates")
  func test_IH_Composition_010_RevolvingCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("u. 2u,6s/6xu.6u4xm3z; ")
    vCTestLog("測試就地輪替候選字：優跌能留意旅方 -> 幽蝶能留一縷芳")
    let eventDataChain: [KBEvent.KeyEventData] = [
      .dataArrowHome, .dataArrowRight, .dataTab, .dataTab,
      .dataArrowRight, .dataTab, .dataArrowRight, .dataArrowRight,
      .dataArrowRight, .dataArrowRight, .dataTab, .dataArrowRight,
      .dataTab, .dataTab, .dataTab,
    ]
    eventDataChain.map(\.asEvent).forEach { theEvent in
      _ = testHandler.triageInput(event: theEvent)
    }
    let resultText2 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText2)")
    #expect(resultText2 == "幽蝶能留一縷芳")

    // 測試一個特例。
    do {
      testHandler.clear()
      clearTestPOM()
      testHandler.currentLM.insertTemporaryData(
        unigram: .init(keyArray: ["ㄌㄧㄡˊ"], value: "流", score: -4, id: .init()),
        isFiltering: false
      )
      typeSentence("xu.6u4")
      #expect(testSession.state.displayedText == "留意")
      typeSentence("xm3")
      #expect(testSession.state.displayedText == "留意旅")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      #expect(testSession.state.displayedText == "流一縷")
    }
  }

  /// 測試在選字後復原游標位置的功能。
  @Test("IH-Composition-011 Cursor placement restore after selecting candidate")
  func test_IH_Composition_011_CursorPlacementRestoreAfterSelectingCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 2
    clearTestPOM()
    let sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence(sequenceChars)
    let eventDataChain1: [KBEvent.KeyEventData] = [
      .dataArrowLeft, .dataArrowLeft,
    ]
    eventDataChain1.map(\.asEvent).forEach { theEvent in
      _ = testHandler.triageInput(event: theEvent)
    }
    let nodesPriorToCandidateSelection = testHandler.assembler.assembledSentence.values
    #expect(!(nodesPriorToCandidateSelection.isEmpty))
    let readingCursorIndex = testHandler.actualNodeCursorPosition
    var nodeIndex: Int?
    var readingCursor = 0
    for (index, node) in testHandler.assembler.assembledSentence.enumerated() {
      let segmentLength = node.keyArray.count
      if readingCursorIndex < readingCursor + segmentLength
        || index == nodesPriorToCandidateSelection.count - 1 {
        nodeIndex = index
        break
      }
      readingCursor += segmentLength
    }
    guard let nodeIndex else {
      Issue.record("Unable to locate node for cursor position: \(readingCursorIndex)")
      return
    }
    let currentNodeValue = nodesPriorToCandidateSelection[nodeIndex]
    let cursorPriorToCandidateSelection = testHandler.assembler.cursor
    // 安裝可見、且會跟隨候選清單的模擬選字窗，讓選取實際經由選字窗的選字鍵完成。
    testSession.installMockCandidateController()
    defer { testSession.mockCandidateController = nil }
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.mockCandidateController?.visible == true)
    let candidateValues = testSession.state.candidates.map { $0.value }
    #expect(!(candidateValues.isEmpty))
    let targetCandidate = candidateValues.first { $0 != currentNodeValue } ?? currentNodeValue
    guard let candidateIndex = candidateValues.firstIndex(of: targetCandidate) else {
      Issue.record("Target candidate not found. Candidates: \(candidateValues)")
      return
    }
    let selectionKeys = Array(testSession.selectionKeys)
    #expect(selectionKeys.count > candidateIndex)
    // 以選字鍵選取候選（此處的候選即「年終」）。
    let selectionEvent = KBEvent.KeyEventData(chars: String(selectionKeys[candidateIndex])).asEvent
    #expect(testHandler.triageInput(event: selectionEvent))
    let nodesAfterSelectingCandidate = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterSelectingCandidate.count == nodesPriorToCandidateSelection.count)
    #expect(nodesAfterSelectingCandidate[nodeIndex] == targetCandidate)
    let expectedText = nodesAfterSelectingCandidate.joined()
    let resultText = testSession.state.displayedText
    #expect(resultText == expectedText)
    #expect(testHandler.assembler.cursor == cursorPriorToCandidateSelection)
    #expect(testHandler.backupCursor == nil)
  }

  @Test("IH-Composition-012 Drop key against an overridden candidate")
  func test_IH_Composition_012_DropKeyAgainstAnOverriddenCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    // 關掉這個開關就可以停用 POM，不需要再 clearTestPOM()。
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    // 使用大千（注音）解析器輸入三字詞「水果汁」。
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()

    // 定義 keyEventData
    let forwardDelete = KBEvent.KeyEventData.forwardDelete.asEvent
    let backspace = KBEvent.KeyEventData.backspace.asEvent

    // 重置並輸入對應「水果汁」的大千（注音）鍵序。
    func restoreTestState(manualCandidateSelection: Bool = true) throws {
      testSession.switchState(.ofAbortion())
      testSession.resetInputHandler(forceComposerCleanup: true)
      typeSentence("gjo3eji35 ") // 大千鍵序對應「水果汁」，尾端有空白鍵
      #expect(
        testHandler.assembler.assembledSentence.values.joined()
          == "水果汁"
      ) // 確認我們獲得預期的組字結果
      if manualCandidateSelection {
        // 選取候選以標記節點為手動覆寫（固化）狀態
        testSession.switchState(testHandler.generateStateOfCandidates())
        testSession.candidatePairSelectionConfirmed(at: 0)
        // 基本一致性檢查
        #expect(testHandler.assembler.assembledSentence.values == ["水果汁"])
      }
    }

    // 案例 A1 (ForwardDelete)：從節點後側向前刪除一個讀音鍵（Forward Delete），預期結果："果汁"
    do {
      try restoreTestState()
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      #expect(testHandler.triageInput(event: forwardDelete))
      #expect(
        testHandler.assembler.assembledSentence.values.joined()
          == "果汁",
        "向前方刪除一個讀音鍵後仍應保留剩餘子鍵的使用者覆寫結果。"
      )
      // 大千鍵序對應「水」
      typeSentence("gjo3")
      // 下述斷言可證明「水果汁」並未被算法選中。
      #expect(testHandler.assembler.assembledSentence.map(\.segLength) == [1, 2])
      // 取消強制手動候選字選擇。
      try restoreTestState(manualCandidateSelection: false)
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      #expect(testHandler.triageInput(event: forwardDelete))
      #expect(testHandler.assembler.assembledSentence.values.joined() == "果汁")
      typeSentence("gjo3")
      // 下述斷言可證明「水果汁」被算法選中。
      #expect(testHandler.assembler.assembledSentence.map(\.segLength) == [3])
    }

    // 案例 A2 (BackSpace)：從節點前側向後刪除一個讀音鍵（BackSpace），預期結果："水果"
    do {
      try restoreTestState()
      // 將游標移到尾端，並按下 BackSpace 鍵以刪除最後一個字
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      #expect(testHandler.triageInput(event: backspace))
      #expect(
        testHandler.assembler.assembledSentence.values.joined()
          == "水果",
        "向後方刪除一個讀音鍵後仍應保留剩餘子鍵的使用者覆寫結果。"
      )
      typeSentence("5 ") // 大千鍵序對應「汁」，尾端有空白鍵
      #expect(testHandler.assembler.assembledSentence.values.joined() != "水果汁")
      #expect(testHandler.assembler.assembledSentence.values.joined() == "水果之")
      // 取消強制手動候選字選擇。
      try restoreTestState(manualCandidateSelection: false)
      #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
      #expect(testHandler.triageInput(event: backspace))
      #expect(testHandler.assembler.assembledSentence.values.joined() == "水果")
      typeSentence("5 ") // 大千鍵序對應「汁」，尾端有空白鍵
      #expect(testHandler.assembler.assembledSentence.values.joined() == "水果汁")
      #expect(testHandler.assembler.assembledSentence.values.joined() != "水果之")
    }

    // 案例 B1 (ForwardDelete)：中間刪除（游標位於中間，前方刪除）→ 預期結果：「水|果汁」->「水汁」。
    // 中間刪除測試：將游標移至第二個位置（Home + RightArrow），執行前方刪除以移除第二個鍵。
    // 預期剩餘字元（第一與第三）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「果」後 -> 「水汁」。
    do {
      try restoreTestState()
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent))
      #expect(testHandler.triageInput(event: forwardDelete))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少一個，且左側字仍為「水」；右側字為「汁」。
      #expect(result.count == 2)
      #expect(result.hasPrefix("水"))
      #expect(result.hasSuffix("汁"))
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄓ"],
          value: result.suffix(1).description
        )
      )
    }

    // 案例 B2 (Backspace)：中間刪除（游標位於中間，後方刪除）→ 預期結果：「水果|汁」->「水汁」。
    // 中間刪除測試：將游標移至第二個位置的右側（End + LeftArrow），執行後方刪除以移除第二個鍵。
    // 預期剩餘字元（第一與第三）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「果」後 -> 「水汁」。
    do {
      try restoreTestState()
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent))
      #expect(testHandler.triageInput(event: backspace))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少一個，且左側字仍為「水」；右側字為「汁」。
      #expect(result.count == 2)
      #expect(result.hasPrefix("水"))
      #expect(result.hasSuffix("汁"))
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄓ"],
          value: result.suffix(1).description
        )
      )
    }

    // 案例 C1 (Opt+ForwardDelete)：中間刪除（游標位於中間，前方刪除）→ 預期結果：「水|果汁」->「水」。
    // 中間刪除測試：將游標移至第二個位置（Home + RightArrow），摁住 Option 執行前方刪除以移除第二個鍵。
    // 預期剩餘字元（第一）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「果汁」後 -> 「水」。
    do {
      try restoreTestState()
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent))
      #expect(testHandler.triageInput(event: forwardDelete.reinitiate(modifierFlags: .option)))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少2個，且只剩「水」。
      #expect(result.count == 1)
      #expect(result.hasPrefix("水"))
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      #expect(
        testHandler.assembler.assembledSentence.values.joined()
          == "水",
        "在 `水|果汁` 的位置按 Option+Delete 後，應保留左側節點，結果為 '水'。"
      )
    }

    // 案例 C2 (Opt+Backspace)：中間刪除（游標位於中間，後方刪除）→ 預期結果：「水果|汁」->「汁」。
    // 中間刪除測試：將游標移至第二個位置的右側（End + LeftArrow），摁住 Option 執行後方刪除以移除第二個鍵。
    // 預期剩餘字元（第三）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「水果」後 -> 「汁」。
    do {
      try restoreTestState()
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent))
      #expect(testHandler.triageInput(event: backspace.reinitiate(modifierFlags: .option)))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少2個，且只剩「汁」。
      #expect(result.count == 1)
      #expect(result.hasSuffix("汁"))
      #expect(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄓ"],
          value: result.suffix(1).description
        )
      )
      #expect(
        testHandler.assembler.assembledSentence.values.joined()
          == "汁",
        "在 `水果|汁` 的位置按 Option+Backspace 後，應保留右側節點，結果為 '汁'。"
      )
    }

    // 案例 D1 (Bksp, POM)：確保在重新打字沒有經過選字窗的確認的情況下的結果不受 POM 影響。
    do {
      clearTestPOM()
      #expect(testHandler.currentLM.lxPerceptor.getSavableData().isEmpty)
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      try restoreTestState(manualCandidateSelection: true) // 生成 POM 記憶
      let pomDesc = testHandler.currentLM.lxPerceptor.getSavableData()
      #expect(!(pomDesc.isEmpty))
      #expect(pomDesc.map(\.key).description.contains("ㄕㄨㄟˇ-ㄍㄨㄛˇ-ㄓ"))
      try restoreTestState(manualCandidateSelection: false)
      #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
      #expect(testHandler.triageInput(event: backspace))
      typeSentence("5 ") // 「ㄓ」+ 陰平聲調
      #expect(testHandler.assembler.assembledSentence.allSatisfy { !$0.isExplicit })
      #expect(testHandler.assembler.assembledSentence.map(\.value) != ["水", "果汁"])
      #expect(testHandler.assembler.assembledSentence.map(\.value) == ["水果汁"])
    }
  }

  // MARK: - 空白鍵插入內文組字區（`spaceKeyBehaviorAgainstICB == -1`，P294）

  /// ★ **組字區徹底為空時，值 -1 一概與值 0 看齊**（事主定則，P294）：按空白鍵即逕出半形
  /// 空白、**不得**以 `_SPACE_HW` 在組字器內留下一個待遞交的節點。
  ///
  /// 這條定則之來由：若空組字區時把空白插進組字器，同一顆空白鍵在第一拍（插節點）與第二拍
  /// （該節點令 `isConsideredEmptyForNow` 為假、遂被混打／狂打層當成「已有內容」而一次遞交）
  /// 便分屬兩種語義，實測會生出「一次遞交兩顆空白」之怪異結果。插入語義只在**組字區已有
  /// 內容**時成立（見 015／016）；此亦與微軟新注音之實際行為一致（事主實測確認）。
  @Test("IH-Composition-013 Empty buffer Space commits half-width space immediately")
  func test_IH_Composition_013_EmptyBufferSpaceCommitsHalfWidthSpaceImmediately() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = -1
    defer {
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.assembler.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.isEmpty,
      "空組字區按空白鍵不得以 `_SPACE_HW` 留下節點，實際得到 \(testHandler.assembler.actualKeys)"
    )
    #expect(testSession.recentCommissions == [" "], "空組字區之空白鍵應逕出半形空白字元")

    // 第二拍亦然：兩顆空白＝兩次遞交，不得合併成一次遞交兩顆。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testSession.recentCommissions == [" ", " "],
      "連按空白鍵應得兩次各一顆空白之遞交，實際得到 \(testSession.recentCommissions)"
    )
    #expect(testHandler.assembler.isEmpty)
  }

  /// ★ 空組字區下 Shift+Space 之寬度一概由 `specifyShiftSpaceKeyBehavior4EmptyState` 決定
  /// （與值 0 之既有語義同一條路徑），**不因值 -1 而異**——即值 -1 在此不插入 `_SPACE_FW`。
  @Test("IH-Composition-014 Empty buffer Shift+Space follows the empty-state width preference")
  func test_IH_Composition_014_EmptyBufferShiftSpaceFollowsTheEmptyStateWidthPreference() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = -1
    let formerWidthPreference = testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState
    defer {
      testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = formerWidthPreference
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)

    var shiftSpace = KBEvent.KeyEventData.spaceEvent
    shiftSpace.flags = [.shift]

    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = false
    #expect(testHandler.triageInput(event: shiftSpace.asEvent))
    #expect(testHandler.assembler.isEmpty, "空組字區之 Shift+Space 不得插入 `_SPACE_FW`")
    #expect(testSession.recentCommissions == ["　"], "該偏好為假時應逕出全形空白字元")

    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = true
    #expect(testHandler.triageInput(event: shiftSpace.asEvent))
    #expect(
      testSession.recentCommissions == ["　", " "],
      "該偏好為真時應逕出半形空白字元，實際得到 \(testSession.recentCommissions)"
    )
    #expect(testHandler.assembler.isEmpty)
  }

  /// 值 -1 之下，組字區已有內容時按空白鍵／Shift+Space：空白應接在既有節點之後
  /// （而非先遞交既有內容），且 Shift 者為全形（`_SPACE_FW`）、不帶 Shift 者為半形。
  @Test("IH-Composition-015 Space and Shift+Space append to existing composition buffer content")
  func test_IH_Composition_015_SpaceAndShiftSpaceAppendToExistingCompositionBufferContent() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = -1
    let cleanup = {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧˇ"], value: "你", score: -1, id: .init()),
      isFiltering: false
    )
    defer { cleanup() }
    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentence("su3")

    var shiftSpace = KBEvent.KeyEventData.spaceEvent
    shiftSpace.flags = [.shift]
    #expect(testHandler.triageInput(event: shiftSpace.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧˇ", "_SPACE_FW"],
      "Shift+Space 應以全形 `_SPACE_FW` 接在漢字節點之後，實際得到 \(testHandler.assembler.actualKeys)"
    )
    #expect(testSession.recentCommissions.isEmpty, "值 -1 之下不得先遞交既有內容")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧˇ", "_SPACE_FW", "_SPACE_HW"],
      "不帶 Shift 者應為半形 `_SPACE_HW`，實際得到 \(testHandler.assembler.actualKeys)"
    )
    #expect(testSession.recentCommissions.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(
      testSession.recentCommissions == ["你　 "],
      "漢字與兩顆空白應一次遞交，實際得到 \(testSession.recentCommissions)"
    )
  }

  /// 值 -1 之下，組字區內的空白與既有的漢字一同遞交：兩者之間不得被拆成兩次遞交。
  @Test("IH-Composition-016 Space stays with kanji in a single commit")
  func test_IH_Composition_016_SpaceStaysWithKanjiInASingleCommit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = -1
    let cleanup = {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧˇ"], value: "你", score: -1, id: .init()),
      isFiltering: false
    )
    defer { cleanup() }
    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentence("su3")
    #expect(testHandler.committableDisplayText(sansReading: true) == "你")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(
      testHandler.assembler.actualKeys == ["ㄋㄧˇ", "_SPACE_HW"],
      "空白應接在漢字節點之後，實際得到 \(testHandler.assembler.actualKeys)"
    )
    #expect(testSession.recentCommissions.isEmpty, "值 -1 之下按下空白鍵不得遞交既有內容")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(
      testSession.recentCommissions == ["你 "],
      "漢字與空白應一次遞交，實際得到 \(testSession.recentCommissions)"
    )
  }

  /// 對照組：值 0（「先遞交當前內容、再插入空白字元」）之下，空組字區按空白鍵仍是**即刻遞交**
  /// 一顆半形空白字元——既有語義不因新增 -1 而變動。
  @Test("IH-Composition-017 Value 0 still commits a space immediately")
  func test_IH_Composition_017_ValueZeroStillCommitsASpaceImmediately() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 0
    defer {
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.spaceEvent.asEvent))
    #expect(testSession.recentCommissions == [" "])
    #expect(testHandler.assembler.isEmpty, "值 0 之下空白不得留在組字器內")
  }

  /// 值 -1 之下，按住 Option／Control／Command 者不屬「插入空白字元」——組字區為空時該鍵
  /// 應逕行放行給客體（交由系統處置），不得被本偏好攔下。
  @Test("IH-Composition-018 Space with Command-family modifiers is left to the client")
  func test_IH_Composition_018_SpaceWithCommandFamilyModifiersIsLeftToTheClient() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = -1
    defer {
      testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
      testHandler.clear()
    }
    testSession.resetInputHandler(forceComposerCleanup: true)

    var optionSpace = KBEvent.KeyEventData.spaceEvent
    optionSpace.flags = [.option]
    #expect(
      !testHandler.triageInput(event: optionSpace.asEvent),
      "帶 Option 的空白鍵不屬值 -1 之範疇，應放行給客體"
    )
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }
}
