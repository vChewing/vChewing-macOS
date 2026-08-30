// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import LMAssemblyMaterials4Tests

import Shared
import Tekkon
import Testing

import HomaSharedTestComponents
@testable import LangModelAssembly
@testable import Typewriter

// MARK: - 測試案例 Vol 1 (Basic Functions)

extension InputHandlerTests {
  /// 測試基本的打字組句（不是ㄅ半注音）。
  @Test
  func test_IH101_BasicSentenceComposition() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳，但這裡暫時先期待失敗結果「優跌能留意旅方」")
    testSession.resetInputHandler(forceComposerCleanup: true)
    // 打「幽蝶能留一縷芳」的讀音：「ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧ ㄌㄩˇ ㄈㄤ」，最後空格是陰平聲調。
    typeSentence("u. 2u,6s/6xu.6u4xm3z; ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(resultText1 == "優跌能留意旅方")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "優跌能留意旅方")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  ///
  /// 注意：Typewriter Tests 並無測試選字窗行為的條件。
  /// SCPC 打字的行為處理過程高度強調選字窗的參與，所以此處僅測試打一個字。
  /// 完整測試需在 MainAssembly 測試進行。
  @Test
  func test_IH102_BasicSCPCTyping() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：優")
    testHandler.clear()
    typeSentence("u. ") // 打「優」字的讀音：「ㄧㄡ」，最後空格是陰平聲調。
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(!resultText1.isEmpty)
    let candidates = testHandler.generateArrayOfCandidates()
    #expect(resultText1.contains("優") || candidates.map { $0.value }.contains("優"))
    // 測試到此為止，於 MainAssembly 的同名測試繼續。
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  @Test
  func test_IH103_MiscCommissionTest() throws {
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
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  @Test
  func test_IH103A_MiscCommissionButKoBPMFVS() throws {
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

  @Test
  func test_IH103B_ButKoBPMFVSDisplayReflection() throws {
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

  @Test
  func test_IH103C_ButKoBPMFVSPlainEnterCommitsRawText() throws {
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
  @Test
  func test_IH103D_ButKoBPMFVSMarkingStateDoesNotPollute() throws {
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
    // （tooltip 內容在 MainAssembly 層產生，Typewriter 測試環境不連結 MainAssembly 故不檢查 tooltip 字串）
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
  @Test
  func test_IH103E_ButKoBPMFVSCandidatePreviewKeepsRawStateInSync() throws {
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
  /// Typewriter 測試層級驗證 raw text 傳遞正確性；tooltip 內容驗證由 MainAssembly 層測試負責。
  @Test
  func test_IH103F_MarkingStateRawTextPassing() throws {
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

  /// 測試磁帶模組的快速選字功能（單一結果）。
  @Test
  func test_IH104_CassetteQuickPhraseSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    testHandler.currentTypingMethod = .vChewingFactory

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    let cassetteLM = LMAssembly.LMInstantiator.lmCassette
    #expect(cassetteLM.isLoaded)
    #expect(!cassetteLM.charDefMap.isEmpty)

    testHandler.clear()
    typeSentence(",,,")
    #expect(testHandler.calligrapher == ",,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    // 打完 QuickPhrase 確認鍵之後，組筆區的內容應該會被清空、且此時應該有結果遞交出去。
    let currentState = testSession.state
    #expect(
      currentState.type == .ofEmpty || currentState.type == .ofSymbolTable,
      "Quick phrase with single result should either commit directly or open a symbol table, got \(currentState.type)."
    )
    // ↑MockSession 會在遞交結果時回復為 .ofEmpty，因此此處允許 .ofEmpty。
    #expect(testHandler.calligrapher.isEmpty)
    // 只有單筆結果時，得立刻遞交出去。組筆區應該是有結果的。
    let result = generateDisplayedText()
    vCTestLog("Result after quick phrase: '\(testSession.recentCommissions.last ?? "NULL")'")
    #expect(testSession.recentCommissions.last == "米糕")
    // 單一結果的快速片語會立即遞交，因此組字器可能維持為空；此時仍需檢查狀態是否合理
    #expect(testSession.state.type == .ofEmpty || !result.isEmpty)
  }

  /// 測試磁帶模組的快速選字功能（符號表多選）。
  @Test
  func test_IH105_CassetteQuickPhraseSymbolTableMultiple() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    typeSentence(",,,,")
    #expect(testHandler.calligrapher == ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    vCTestLog("Testing symbol table multi-selection")
    vCTestLog("Calligrapher: \(testHandler.calligrapher)")

    #expect(testSession.state.type == .ofSymbolTable)
    #expect(testSession.state.node.name == ",,,,")
    #expect(testHandler.calligrapher == ",,,,")

    // 測試是否產生了多個候選字
    let symbolCandidates = testSession.state.node.members.map { $0.name }
    #expect(symbolCandidates == ["炎炎", "迷迷糊糊", "熒熒"])
    // 此時應該還沒有 Commit 才對，因為這時的狀態是選字窗顯示出來了。
    #expect(testSession.recentCommissions.last == nil)
    let stateCandidates = testSession.state.data.candidates.map { $0.value }
    #expect(stateCandidates == symbolCandidates)
    vCTestLog("Candidates: \(symbolCandidates)")
    // Typewriter 測試不會去測試選字窗的行為，這類行為的測試由 MainAssembly 測試負責。
    testSession.candidatePairSelectionConfirmed(at: 1)
    #expect(testSession.recentCommissions.last == "迷迷糊糊")
  }

  @Test
  func test_IH105A_CassetteAutoCompositeWithLongestPossibleKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    var reportedErrors = [String]()
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer { testHandler.errorCallback = nil }

    typeSentence("qqqq")

    #expect(testHandler.calligrapher.isEmpty)
    #expect(generateDisplayedText() == "金")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.recentCommissions.last == nil)
    #expect(reportedErrors.isEmpty)
  }

  @Test
  func test_IH105B_CassetteOverflowDoesNotLeakToBlockedDataTrap() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = false

    var reportedErrors = [String]()
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer { testHandler.errorCallback = nil }

    typeSentence("qqqq")
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testSession.state.type == .ofInputting)

    let overflowHandled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "q").asEvent)

    #expect(overflowHandled)
    #expect(testHandler.calligrapher.isEmpty)
    #expect(generateDisplayedText().isEmpty)
    #expect(testSession.state.type == .ofEmpty)
    #expect(reportedErrors.contains(where: { $0.contains("2268DD51") }))
    #expect(!reportedErrors.contains(where: { $0.contains("A9BFF20E") }))
  }

  @Test
  func test_IH105C_CassetteBackspaceWorksAtFullCalligrapherLength() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = false

    typeSentence("qqqq")
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testSession.state.type == .ofInputting)

    let backspaceHandled = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)

    #expect(backspaceHandled)
    #expect(testHandler.calligrapher == "qqq")
    #expect(testSession.state.type == .ofInputting)
  }

  @Test
  func test_IH105D_CassetteShiftBackspaceDisassemblesPreviousCalligraph() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    typeSentence("qqqq")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.length == 1)
    #expect(testSession.state.type == .ofInputting)

    let shiftBackspace = KBEvent.KeyEventData(
      flags: .shift,
      chars: KBEvent.SpecialKey.backspace.unicodeScalar.description,
      keyCode: KeyCode.kBackSpace.rawValue
    ).asEvent
    let shiftBackspaceHandled = testHandler.triageInput(event: shiftBackspace)

    #expect(shiftBackspaceHandled)
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testHandler.assembler.length == 0)
    #expect(testSession.state.type == .ofInputting)
  }

  /// 磁帶 quick-candidate 狀態下，敲任意單字元鍵（Shift+?）應錄入組筆區、而非叫出服務選單。
  @Test
  func test_IH105E_CassetteShiftQuestionTypesAnySingleCharKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)
    #expect(LMAssembly.LMInstantiator.lmCassette.anySingleCharKey == "?")

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.useShiftQuestionToCallServiceMenu = true

    // 裝上可見的模擬候選窗控制器，重現 quick candidate 已顯示的狀態。
    testSession.mockCandidateController = MockCandidateController(visible: true)
    defer { testSession.mockCandidateController = nil }

    // 敲「y」之後，array30 的 %quick 候選（立言裡新記該認說話就）應顯示。
    typeSentence("y")
    #expect(testHandler.calligrapher == "y")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.isCandidateContainer)

    // 以 Shift+/（輸出「?」）敲入任意單字元鍵。
    let shiftQuestion = KBEvent.KeyEventData(
      flags: .shift,
      chars: "?",
      charsSansModifiers: "/",
      keyCode: 44
    ).asEvent
    _ = testHandler.triageInput(event: shiftQuestion)

    // 任意單字元鍵應進入組筆區，且不應叫出服務選單（符號表）。
    #expect(testHandler.calligrapher == "y?")
    #expect(testSession.state.type != .ofSymbolTable)

    // 組字後組字區應直接顯示「熟」（`y,` 經任意單字元鍵匹配）。
    typeSentence(" ")
    #expect(testSession.state.displayedText == "熟")

    // 叫出選字窗，確認「熟」在候選清單內。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    #expect(testSession.state.candidates.map(\.value).contains("熟"))
  }

  @Test
  func test_IH105F_CassetteWildcardSandwichStaysInCalligrapher() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)
    #expect(LMAssembly.LMInstantiator.lmCassette.wildcardKey == "*")

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    // 敲到 `*` 時不得觸發立即組字，否則 `y*y` 這類三明治 pattern 永遠敲不出來。
    typeSentence("y*")
    #expect(testHandler.calligrapher == "y*")
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.type == .ofInputting)

    // 繼續敲 `y`，組筆區應保留完整的三明治 pattern（array30 的 `y*y*` 仍有匹配，故不自動組字）。
    typeSentence("y")
    #expect(testHandler.calligrapher == "y*y")
    #expect(testHandler.assembler.isEmpty)

    // 空白鍵組字：`y*y` 應能組出內容（匹配 yky 誰、yyy 譶 等）。
    typeSentence(" ")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(!testHandler.assembler.isEmpty)
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    let candidateValues = testSession.state.candidates.map(\.value)
    #expect(candidateValues.contains("誰"))
    #expect(candidateValues.contains("譶"))
  }

  @Test
  func test_IH106_CodePointInputCheck() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testCodes: [(Shared.InputMode, String)] = [
      (.imeModeCHS, "C8D0"),
      (.imeModeCHT, "A462"),
    ]

    // 模擬 `Opt+~` 熱鍵組合觸發碼點模式。
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )
    testSession.switchState(.ofAbortion())

    for (langMode, codePointHexStr) in testCodes {
      defer {
        // 切換至 Abortion 狀態會自動清理 Handler，此時會連帶重設 typingMethod。
        testSession.switchState(IMEState.ofAbortion())
      }
      PrefMgr.sharedSansDidSetOps.mostRecentInputMode = langMode.rawValue
      #expect(testHandler.currentTypingMethod == .vChewingFactory)
      #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
      #expect(testHandler.currentTypingMethod == .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeSentence(codePointHexStr)
      #expect(testSession.recentCommissions.last == "刃")
      vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }

  @Test
  func test_IH107_RomanNumeralInputCheck() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    // 模擬 `Opt+~` 熱鍵組合觸發羅馬數字模式。
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )

    func resetToRomanNumeralTypingMethod() throws {
      // 初始打字模式（TypingMethod）是唯音原廠模式。
      testSession.switchState(.ofAbortion())
      #expect(testHandler.currentTypingMethod == .vChewingFactory)
      // 開始輪替。
      var attempts = 0
      revolvingTypingMethod: while testHandler.currentTypingMethod != .romanNumerals {
        defer { attempts += 1 }
        #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
        if attempts > TypingMethod.allCases.count {
          break revolvingTypingMethod
        }
      }
      #expect(testHandler.currentTypingMethod == .romanNumerals)
    }

    vCTestLog("Testing roman numeral input: 1994")
    try resetToRomanNumeralTypingMethod()
    typeSentence("1994")
    #expect(testSession.recentCommissions.last == "MCMXCIV")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 另外測試一個數字。
    try resetToRomanNumeralTypingMethod()
    vCTestLog("Testing roman numeral input: 1042")
    typeSentence("1042")
    #expect(testSession.recentCommissions.last == "MXLII")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字輸入測試。")
  }

  /// 測試羅馬數字模式下的空格鍵功能
  @Test
  func test_IH108_RomanNumeralSpaceKeyHandling() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    // 建立空格鍵事件
    let spaceKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: [],
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: " ",
      charactersIgnoringModifiers: " ",
      isARepeat: false,
      keyCode: KeyCode.kSpace.rawValue
    )

    // 建立符號選單按鍵事件（Option + `）
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )

    testSession.switchState(.ofAbortion())

    // 進入羅馬數字模式
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .codePoint)
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .haninKeyboardSymbol)
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    // 測試一：空格鍵在緩衝區為空時應觸發 ofAbortion
    vCTestLog("測試一：空格鍵在緩衝區為空時")
    var errorCallbackTriggered = false
    testHandler.errorCallback = { errorID in
      vCTestLog("錯誤回呼被觸發，ID 為：\(errorID)")
      errorCallbackTriggered = true
    }
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(errorCallbackTriggered, "緩衝區為空時應觸發錯誤回呼")
    // ofAbortion() 狀態在狀態機中自動轉換為 ofEmpty()
    #expect(testSession.state.type == .ofEmpty, "狀態應在 ofAbortion 轉換後變為 ofEmpty")

    // 測試二：空格鍵在緩衝區有內容時應遞交羅馬數字
    vCTestLog("測試二：空格鍵鍵入 '42' 應遞交 'XLII'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("42")
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(testSession.recentCommissions.last == "XLII", "鍵入 '42' 應遞交 'XLII'")
    #expect(testSession.state.type == .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試三：空格鍵用於三位數
    vCTestLog("測試三：空格鍵鍵入 '999' 應遞交 'CMXCIX'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("999")
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(testSession.recentCommissions.last == "CMXCIX", "鍵入 '999' 應遞交 'CMXCIX'")
    #expect(testSession.state.type == .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試四：Enter 鍵仍應正常工作（既有功能）
    vCTestLog("測試四：Enter 鍵鍵入 '2023' 應遞交 'MMXXIII'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("2023")
    #expect(
      testSession.recentCommissions.last == "MMXXIII",
      "四位數輸入 '2023' 應自動遞交 'MMXXIII'"
    )
    #expect(testSession.state.type == .ofEmpty, "狀態應在自動遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字空格鍵測試。")
  }

  @Test
  func test_IH109_SymbolMenuKeyTablePreviewInCompositionBuffer() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    CandidateNode.load()
    let event4SymbolMenu = KBEvent.KeyEventData.symbolMenuKeyEventIntl.asEvent
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.triageInput(event: event4SymbolMenu))
    #expect(testSession.state.type == .ofSymbolTable)

    testSession.candidatePairHighlightChanged(at: 0)
    #expect(testSession.state.highlightedCandidateIndex == 0)
    #expect(testSession.state.displayedTextConverted == "　")

    testSession.candidatePairHighlightChanged(at: 1)
    #expect(testSession.state.highlightedCandidateIndex == 1)
    #expect(testSession.state.displayedTextConverted == "｀")

    testSession.candidatePairHighlightChanged(at: 2)
    #expect(testSession.state.highlightedCandidateIndex == 2)
    #expect(testSession.state.displayedTextConverted == "")
  }

  @Test
  func test_IH110_IntonationKeyBehavior() throws {
    /// IntonationKeyBehavior 分為 [0, 1, 2] 三個情況，這裡只測試前兩種情況：
    /// - 0: 嘗試對游標正後方的字音覆寫聲調，且重設其選字狀態。
    /// - 1: 僅在鍵入的聲調與游標正後方的字音不同時，嘗試覆寫。
    /// - 2: 始終在內文組字區內鍵入聲調符號。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    let testKanjiData = """
    ㄒㄧㄢ 先 -1
    ㄒㄧㄢˊ 嫌 -1
    ㄒㄧㄢˊ 鹹 -2
    ㄒㄧㄢˇ 顯 -1
    ㄒㄧㄢˋ 線 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    clearTestPOM()
    // 測試 pref case 0。
    do {
      testHandler.clear()
      testHandler.prefs.specifyIntonationKeyBehavior = 0
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空格是陰平聲調。
      #expect(testSession.state.displayedText == "嫌")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      #expect(testSession.state.displayedText == "鹹")
      typeSentence("6")
      #expect(testSession.state.displayedText == "嫌", "得復位")
      typeSentence("4")
      #expect(testSession.state.displayedText == "線")
    }
    // 測試 pref case 1。
    do {
      testHandler.clear()
      testHandler.prefs.specifyIntonationKeyBehavior = 1
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空格是陰平聲調。
      #expect(testSession.state.displayedText == "嫌")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      #expect(testSession.state.displayedText == "鹹")
      typeSentence("6")
      #expect(testSession.state.displayedText == "鹹ˊ", "不得復位")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
      typeSentence("4")
      #expect(testSession.state.displayedText == "線")
    }
  }

  @Test
  func test_IH111_ETenExclusiveCandidatesAppendAtTailWithoutReordering() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    clearTestPOM()

    let reading = "ㄅㄛ"
    let eTenSequence = uniqueSingleIdeographicValues(
      testHandler.currentLM.lookupHub.supplementalValues(for: reading, strategy: .configuredLookup)
    )
    guard eTenSequence.count >= 4 else {
      Issue.record("倚天中文 DOS 序列表測試資料不足：\(reading)")
      return
    }
    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let factoryValues = [eTenSequence[1], eTenSequence[0]]
    let expectedValues = factoryValues + eTenSequence.filter { !factoryValues.contains($0) }
    let textMapKey = "ㄅㄛ"
    let textMap = makeTypingTextMap([
      (
        textMapKey,
        factoryValues.enumerated().map {
          (value: $0.element, probability: -5 - Double($0.offset), typeID: factoryTypeID)
        }
      ),
    ])

    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testHandler.clear()
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testHandler.clear()
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    #expect(throws: Never.self) { try testHandler.assembler.insertKey(reading) }

    let candidateValues = testHandler.generateArrayOfCandidates().map(\.value)
    #expect(candidateValues == expectedValues)
  }

  @Test
  func test_IH112_ETenSequenceEnforcementStillReordersCandidates() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    clearTestPOM()

    let reading = "ㄅㄛ"
    let eTenSequence = uniqueSingleIdeographicValues(
      testHandler.currentLM.lookupHub.supplementalValues(for: reading, strategy: .configuredLookup)
    )
    guard eTenSequence.count >= 4 else {
      Issue.record("倚天中文 DOS 序列表測試資料不足：\(reading)")
      return
    }
    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let factoryValues = [eTenSequence[1], eTenSequence[0]]
    let textMapKey = "ㄅㄛ"
    let textMap = makeTypingTextMap([
      (
        textMapKey,
        factoryValues.enumerated().map {
          (value: $0.element, probability: -5 - Double($0.offset), typeID: factoryTypeID)
        }
      ),
    ])

    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testHandler.clear()
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testHandler.clear()
    testHandler.prefs.enforceETenDOSCandidateSequence = true
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    #expect(throws: Never.self) { try testHandler.assembler.insertKey(reading) }

    let candidateValues = testHandler.generateArrayOfCandidates().map(\.value)
    #expect(candidateValues == eTenSequence)
  }

  @Test
  func test_IH112B_ETenSequenceEnforcementWithZai4PreservesZai4ZaiOrder() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    clearTestPOM()

    let reading = "ㄗㄞˋ"
    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let textMap = makeTypingTextMap([
      (
        reading,
        [
          (value: "在", probability: -5.004, typeID: factoryTypeID),
          (value: "再", probability: -5.007, typeID: factoryTypeID),
        ]
      ),
    ])

    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testHandler.clear()
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testHandler.clear()
    testHandler.prefs.enforceETenDOSCandidateSequence = true
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    #expect(throws: Never.self) { try testHandler.assembler.insertKey(reading) }

    let candidateValues = testHandler.generateArrayOfCandidates().map(\.value)
    let zaiIndex = candidateValues.firstIndex(of: "在")
    let zai4Index = candidateValues.firstIndex(of: "再")
    guard let zaiIndex, let zai4Index else {
      Issue.record("Missing expected candidates. Got: \(candidateValues)")
      return
    }
    #expect(zaiIndex < zai4Index, "Expected 在 to precede 再, but got: \(candidateValues)")
  }

  @Test
  func test_IH113_FilterNonCNSReadingsStillAllowsSelectingDemotedSingleKanji() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let textMap = makeTypingTextMap([
      (
        "ㄅㄛ",
        [
          (value: "玻", probability: -5, typeID: 6),
          (value: "播", probability: -4.5, typeID: 6),
          (value: "玻", probability: -11, typeID: 7),
        ]
      ),
    ])

    defer {
      testHandler.prefs.filterNonCNSReadingsForCHTInput = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testHandler.currentLM.syncPrefs()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.filterNonCNSReadingsForCHTInput = true
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄅㄛ") }

    let candidateValues = testHandler.generateArrayOfCandidates().map(\.value)
    guard let conformingIndex = candidateValues.firstIndex(of: "玻") else {
      Issue.record("Missing conforming candidate: 玻. Candidates: \(candidateValues)")
      return
    }
    guard let demotedIndex = candidateValues.firstIndex(of: "播") else {
      Issue.record("Missing demoted candidate: 播. Candidates: \(candidateValues)")
      return
    }
    #expect(demotedIndex > conformingIndex)

    testSession.switchState(testHandler.generateStateOfCandidates())
    guard let selectedIndex = testSession.state.candidates.firstIndex(where: { $0.value == "播" }) else {
      Issue.record("Candidate state is missing 播. Candidates: \(testSession.state.candidates.map(\.value))")
      return
    }
    testSession.candidatePairSelectionConfirmed(at: selectedIndex)
    #expect(generateDisplayedText() == "播")
  }

  @Test
  func test_IH114A_PinyinTonelessQueryUsesStemPartialMatch() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let customTone2Value = "伯測"
    let customTone4Value = "播測"
    let textMap = makeTypingTextMap([
      ("ㄅㄛˊ", [(value: customTone2Value, probability: -5, typeID: factoryTypeID)]),
      ("ㄅㄛˋ", [(value: customTone4Value, probability: -4.5, typeID: factoryTypeID)]),
    ])

    defer {
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.currentLM.setOptions { config in
        config.partialMatchEnabled = false
      }
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    typeSentence("bo ")

    let candidateValues = Set(testHandler.generateArrayOfCandidates().map(\.value))
    #expect(candidateValues.contains(customTone2Value))
    #expect(candidateValues.contains(customTone4Value))
    #expect(!testHandler.currentLM.config.partialMatchEnabled)
  }

  @Test
  func test_IH114B_PinyinExplicitToneKeepsFullMatch() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let factoryTypeID: Int32 = testHandler.currentLM.isCHS ? 5 : 6
    let customTone2Value = "伯測"
    let customTone4Value = "播測"
    let textMap = makeTypingTextMap([
      ("ㄅㄛˊ", [(value: customTone2Value, probability: -5, typeID: factoryTypeID)]),
      ("ㄅㄛˋ", [(value: customTone4Value, probability: -4.5, typeID: factoryTypeID)]),
    ])

    defer {
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.currentLM.setOptions { config in
        config.partialMatchEnabled = false
      }
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData))
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    #expect(LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: textMap))
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    typeSentence("bo4")

    let candidateValues = testHandler.generateArrayOfCandidates().map(\.value)
    #expect(candidateValues.contains(customTone4Value))
    #expect(!candidateValues.contains(customTone2Value))
    #expect(!testHandler.currentLM.config.partialMatchEnabled)
  }

  @Test
  func test_IH114C_PinyinTonelessQueryDoesNotMatchLongerSyllableStem() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customTone2Value = "時測"
    let customTone4Value = "世測"
    let customLongerStemValue = "衰測"
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˊ"], value: customTone2Value, score: -5),
      .init(keyArray: ["ㄕˋ"], value: customTone4Value, score: -4.5),
      .init(keyArray: ["ㄕㄨㄞ"], value: customLongerStemValue, score: -4.2),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.currentLM.syncPrefs()

    typeSentence("shi ")

    let candidateValues = Set(testHandler.generateArrayOfCandidates().map(\.value))
    #expect(candidateValues.contains(customTone2Value))
    #expect(candidateValues.contains(customTone4Value))
    #expect(!candidateValues.contains(customLongerStemValue))
    #expect(!testHandler.currentLM.config.partialMatchEnabled)
  }

  @Test
  func test_IH114D_PinyinContinuousStemAutoChopsLeadingReadings() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    let customShiValue = "世測"
    let customJieValue = "界測"
    let customDaValue = "大測"
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: customShiValue, score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: customJieValue, score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: customDaValue, score: 8),
    ]

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()

    typeSentence("shijiedaz")

    #expect(generateDisplayedText() == customShiValue + customJieValue + customDaValue)
    #expect(testHandler.assembler.keys.count == 3)
    #expect(testHandler.composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "z")
    #expect(!testHandler.currentLM.config.partialMatchEnabled)
  }

  /// 測試單獨輸入聲調後敲 Enter 鍵能正確遞交聲調符號。
  ///
  /// 當唯音輸入法處於「允許單獨輸入聲調」模式時，使用者若先敲聲調鍵（如 ˊ）
  /// 再敲 Enter，則應將該聲調符號直接遞交，如同工具提示所述「敲 Enter 以遞交」。
  @Test
  func test_IH115_StandaloneIntonationEnterCommitsToneMark() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.acceptLeadingIntonations = true
    testHandler.prefs.specifyIntonationKeyBehavior = 0
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    clearTestPOM()
    defer { testHandler.clear() }

    // 先重置狀態。
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 模擬敲聲調鍵「6」（Dachen 佈局下映射到「ˊ」）。
    // 此時 composer 僅有聲調、無讀音，應觸發 standalone intonation 工具提示狀態。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData(chars: "6").asEvent))
    #expect(testHandler.composer.hasIntonation(withNothingElse: true))
    #expect(!testHandler.tooltipForStandaloneIntonationMark.isEmpty)

    // 敲 Enter：應將聲調符號「ˊ」直接遞交。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "ˊ")
  }

  // MARK: - 狂拼模式（Furious Typing Mode）前方預覽

  /// 狂拼模式啟用時，注拼槽內尚未完成拼寫的拼音會以組字器副本（copilot）試算前方組句，
  /// 並將最有可能的結果即時顯示於組字區；原始拼音字母流則改以 Tooltip 顯示。
  @Test
  func test_IH116A_FuriousTypingPreviewsFrontReading() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH116B_FuriousTypingDisabledKeepsRawPinyinDisplay() throws {
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
    testHandler.prefs.furiousTypingEnabled = false // 顯式停用狂拼（測試意圖為「關閉時」行為）。
    testHandler.currentLM.syncPrefs()

    typeSentence("shijiedaz")

    #expect(testHandler.assembler.keys.count == 3)
    // 狂拼模式關閉：前方維持原始拼音「z」顯示。
    #expect(testSession.state.displayedText == "世測界測大測z")
    #expect(testSession.state.tooltip.isEmpty)
  }

  /// 狂拼模式啟用時，Enter 先固化前方並停留 Inputting（不遞交）；
  /// 再按一次 Enter（注拼槽已空）才遞交「組字區內容＋前方預覽」。
  @Test
  func test_IH116C_FuriousTypingEnterSolidifiesThenCommitsPreviewedFront() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH117A_FuriousTypingAttachesFrontCandidates() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
    testHandler.prefs.furiousTypingEnabled = false
    testHandler.currentLM.syncPrefs()
    let stateSansFurious = testHandler.generateStateOfInputting()
    #expect(stateSansFurious.candidates.isEmpty)
  }

  /// 狂拼模式啟用時，Shift+選字鍵「1」就地選中置頂前方候選：
  /// 注拼槽清空、組字器尾端寫入對應讀音、組字區顯示「戰測」、狀態回到無候選的 Inputting。
  @Test
  func test_IH117B_FuriousTypingShiftSelection() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH117C_FuriousTypingPlainDigitKeyKeepsToneSemantics() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH117D_SCPCForcesFuriousTypingInert() throws {
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
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼模式：greedy chop 把「fangan」切成 fang|an 之後，語言模型引導的重切分
  /// 應把前方兩鍵換成 fan|gan 桶，使組句結果由「反感」勝出。
  @Test
  func test_IH118A_FuriousTypingResegmentsFangAn() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH118B_FuriousTypingNoResegmentationWhenDisabled() throws {
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
    testHandler.prefs.furiousTypingEnabled = false // 顯式停用狂拼（測試意圖為「關閉時」行為）。
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
  @Test
  func test_IH118C_FuriousTrailPopOnBackspace() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH118D_FuriousTrailInvalidatedByConsolidateNode() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 建立「shijie → 世界」固化測試用的詞庫：
  /// 支撐單字（世／界）與高分的「世界」雙音節詞。
  private func insertShiJieSolidificationFixture(testHandler: MockInputHandler?) {
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

  /// 打「shijie」後（注拼槽暫存 jie、候選窗顯示中），按 Space：
  /// 前方讀音被固化進組字器（鍵數＋1、注拼槽清空、trail 尾筆為 jie），
  /// 且同一事件繼續走正常流程、開出正常選字窗，候選涵蓋跨邊界詞「世界」。
  @Test
  func test_IH119A_FuriousTypingSpaceSolidifiesAndOpensCandidateWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH119B_FuriousTypingDownArrowSolidifiesAndOpensCandidateWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH119C_FuriousTypingLetterKeyNotSolidifiedButEnterSolidifies() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH119D_FuriousTypingSuppressesTooltipWhenCandidatesShow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    // 候選窗顯示中：tooltip 為空（抑制）、candidates 非空、組字區仍顯示預覽。
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testSession.state.tooltip.isEmpty)
    #expect(!testSession.state.displayedText.isEmpty)
  }

  /// 不完整前綴（例如「z」）被固化：固化成功但 trail 失效（清空），無崩潰。
  @Test
  func test_IH119E_FuriousTypingSolidifyingIncompletePrefixInvalidatesTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH120A_FuriousTypingCandidatesIncludeCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH120B_FuriousTypingShiftSelectionConfirmsCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼候選窗顯示中，反查欄位回傳注拼槽尚未固化的原始拼音字母流；
  /// 總開關、縱排守衛、狂拼關閉時皆回空。
  @Test
  func test_IH120C_FuriousTypingReverseLookupExposesPendingRomaji() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.prefs.showReverseLookupInCandidateUI = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(!testSession.state.candidates.isEmpty)

    // 狂拼候選窗顯示中：反查回傳注拼槽的原始拼音字母流。
    #expect(testSession.reverseLookup(for: "界") == ["jie"])

    // 狂拼讀音回顯刻意繞過總開關：總開關關閉時仍回傳字母流。
    testHandler.prefs.showReverseLookupInCandidateUI = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.reverseLookup(for: "界") == ["jie"])

    // 非狂拼時，總開關關閉仍回空（原守衛路徑不受影響）。
    testHandler.prefs.furiousTypingEnabled = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.reverseLookup(for: "界").isEmpty)
  }

  /// 首音節還在注拼槽（組字器為空）時，copilot 窗不查跨邊界：
  /// 候選僅為置頂預覽＋前方單音節，無雙讀音候選、無崩潰。
  @Test
  func test_IH120D_FuriousTypingNoCrossBoundaryWhenAssemblerEmpty() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH121A_FuriousTypingPinsCrossBoundaryWordAtTop() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH121B_FuriousTypingShiftOneConfirmsTopCrossBoundaryWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼讀音回顯：縱排模擬下仍回傳字母流（繞過縱排守衛）；
  /// 狂拼關閉時不進狂拼分支；非狂拼（總開關開啟）走原磁帶路徑（Mock 回空）。
  @Test
  func test_IH121C_FuriousTypingReadingEchoBypassesVerticalGuard() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.prefs.showReverseLookupInCandidateUI = true
    testHandler.currentLM.syncPrefs()

    typeSentence("shijie")
    #expect(!testSession.state.candidates.isEmpty)

    // 縱排模擬（isVerticalTyping = true）：狂拼讀音回顯仍回傳字母流。
    testSession.isVerticalTyping = true
    #expect(testSession.reverseLookup(for: "界") == ["jie"])
    testSession.isVerticalTyping = false

    // 狂拼關閉時不進狂拼分支：走原守衛路徑（Mock 回空）。
    testHandler.prefs.furiousTypingEnabled = false
    testHandler.currentLM.syncPrefs()
    #expect(testSession.reverseLookup(for: "界").isEmpty)

    // 非狂拼（總開關開啟）走原磁帶反查路徑（Mock 無磁帶資料，回空）。
    #expect(testSession.reverseLookup(for: "界").isEmpty)
  }

  // MARK: - 狂拼 copilot 全句組句顯示與遞交（Furious Joint Composition Display）

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

  /// 狂拼模式：composition buffer 主段與前方預覽同源於 copilot 全句組句——
  /// 打「shijie」顯示「世界」（而非 main 組字器的「是」＋前方「界」＝「是界」），
  /// 置頂候選仍為「世界」。
  @Test
  func test_IH122A_FuriousTypingDisplayUsesCopilotJointComposition() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH122B_FuriousTypingEnterSolidifiesThenCommitsCopilotJointText() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH122C_FuriousTypingBackwardArrowSolidifiesThenMovesCursor() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH123A_FuriousTypingHighlightPreviewReflectsCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  /// 套用結果。不切高亮時固化置頂候選（IH122B 語義不變）。
  @Test
  func test_IH123B_FuriousTypingEnterSolidifiesHighlightedCandidateThenCommits() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()
    typeSentence("shijie")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions.isEmpty)
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions == ["世界"])
  }

  /// W3：非狂拼（或狂拼窗不可見）時，注拼槽有未完成讀音按前後方向鍵 → error 退回、
  /// 游標不動、無遞交。
  @Test
  func test_IH123C_FuriousTypingCursorKeyRejectedWithoutCopilotWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
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
  @Test
  func test_IH123D_FuriousTypingCursorKeySolidifiesAndNavigatesCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH124A_FuriousTypingShiftBackwardSolidifiesThenMarks() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH124B_ShiftBackwardConfirmsCompletableReadingThenMarks() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
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
  @Test
  func test_IH124C_ShiftBackwardRejectsIncompleteReading() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = false // 顯式停用狂拼（測試意圖為「非狂拼」行為）。
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
  @Test
  func test_IH125A_FuriousTypingShiftBackwardDoesNotRecurseWithVisibleWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH125B_FuriousTypingSpaceConsumedAfterSolidify() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH126A_FuriousTypingBackspaceThenSpaceRevolves() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH126B_FuriousTypingAutoCommitCommitsCopilotJointText() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼 **Enter 固化候選**確認前方候選**不寫入 POM 記憶**：
  /// copilot 未經使用者逐字確認的最佳猜測不應寫入漸退記憶模組，否則記憶的短詞
  /// 會綁架長詞的組句（如「是嗎」綁架「是媽媽」→「是嗎嗎」）。測資：清空 POM 後
  /// 以預設語義（Enter 固化，`memorizePOM` 預設 false）確認前方候選，組字器仍在、
  /// 讀取 POM 建議應為空。
  @Test
  func test_IH127_FuriousEnterDirectCommitDoesNotMemorizePOM() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // POM 讀取閘門打開。
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    // 「shima」：auto-chop 提交 shi、前方 ma 暫存於注拼槽、copilot 候選窗顯示。
    typeSentence("shima")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(!testSession.state.candidates.isEmpty)

    // 以 Enter 直遞語義就地確認前方候選（預設 memorizePOM == false；保留組字器內容）。
    testHandler.confirmFuriousFrontCandidate(testSession.state.candidates.first!)
    #expect(testHandler.assembler.keys.count == 2)

    // Enter 直遞不得產生任何 POM 記憶：組字器仍在，若有記憶應能被建議查詢讀出。
    let pomPairs = testHandler.retrievePOMSuggestions(apply: false)
    #expect(pomPairs.isEmpty)
  }

  /// 狂拼**顯式選字**（Shift+選字鍵／滑鼠點選，`memorizePOM: true`）確認前方候選
  /// **會寫入 POM 記憶**：使用者顯式選字符合 POM 記憶的明確意志，與 Enter 直遞有別。
  /// 測資：清空 POM 後經 `candidatePairSelectionConfirmed`（模擬就地選字路由）
  /// 選中跨邊界候選「世界」，
  /// 漸退記憶模組應有新增記憶。
  @Test
  func test_IH128_FuriousExplicitSelectionMemorizesPOM() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // POM 讀取閘門打開。
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 提交 shi、前方 jie 暫存於注拼槽、copilot 候選窗顯示，
    // 置頂候選為跨邊界詞「世界」（keyArray [ㄕˋ, ㄐㄧㄝˋ]，可成功覆寫）。
    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(testSession.state.candidates.first?.value == "世界")

    // 經 session 就地選字路由（Shift+選字鍵／滑鼠點選同此路徑）：
    // MockSession 對應生產端 InputSession_Delegates，傳入 memorizePOM: true。
    testSession.candidatePairSelectionConfirmed(at: 0)
    #expect(generateDisplayedText() == "世界")

    // 顯式選字應寫入 POM 記憶：直接檢查漸退記憶模組的儲存內容。
    let pomData = testHandler.currentLM.lxPerceptor.getSavableData()
    #expect(!pomData.isEmpty)
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

  /// 空格固化只插聲調桶（不覆寫）：「xi 空格 an 空格」時 copilot 重切合併長詞
  /// 「西安」，不被單字「西」的覆寫釘死打斷；trail 持續累積供語言模型引導的
  /// 重切分（對治「長詞自動選取被短詞 override 打斷」）。
  @Test
  func test_IH129_FuriousTypingSpaceSolidificationMergesLongWord() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH130_FuriousTypingTabSolidifiesThenRevolves() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH131_FuriousTypingShiftTabSolidifiesThenRevolvesReverse() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH132_FuriousTypingAbbreviatedWholeWordCandidates() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH133_FuriousTypingAbbreviatedWholeWordSelectionWritesActualReadings() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    // 使用者造詞＋單音節 gram（供確認寫回的讀音存在性驗證）。
    // 與 IH132 相同：注入近分競爭者「一世雄霸」，使 ysxb 不觸發 R3-a 自動套用、
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH134_FuriousTypingAbbreviatedSpaceSolidifiesTopCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH135_FuriousTypingCopilotWindowFrontsPOMSuggestion() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼固化後 POM 建議套用（容錯模式）：空格固化前方聲調桶後，
  /// `retrievePOMSuggestions(apply: true)` 以容錯查詢召回記憶並就地覆寫——組句結果
  /// 由「是嗎」改為記憶的「是媽」。
  @Test
  func test_IH136_FuriousTypingSolidifyAppliesPOMSuggestionTolerantly() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

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
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shima」→ 空格：前方固化（插聲調桶）＋ POM 容錯套用（是嗎 → 是媽）。
    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
  }

  /// 狂拼 n-gram 來源（S2）：POM 記憶作為 bigram 統計來源時，即使關閉 POM 建議套用
  /// （fetchSuggestionsFromPerceptionOverrideModel = false），組句路徑亦自然選中記憶詞
  /// （是媽）而非語言模型最佳猜測（是嗎）——純統計路徑、無 override 介入。
  @Test
  func test_IH137_FuriousTypingNGramSourceGuidesPathSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.pomAsNGramSourceEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

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
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false // 關閉 POM 建議套用。
    testHandler.prefs.pomAsNGramSourceEnabled = true // 僅 n-gram 統計來源。
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shima」→ 空格固化前方：ㄇㄚ 桶查詢注入 POM bigram（previous=是），DP 自然選中「媽」。
    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
  }

  /// 狂拼 n-gram 來源＋POM 建議同時開啟時，固化後的自動套用被跳過（雙重加成收斂）：
  /// 記憶詞由 DP 以 n-gram 統計路徑自然選中（gram.previous 帶「是」），
  /// 而非自動 override 錨定的 bare unigram（previous 為 nil）。
  @Test
  func test_IH138_FuriousTypingNGramSourceSkipsAutoPOMApply() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.pomAsNGramSourceEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

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
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // POM 建議開啟。
    testHandler.prefs.pomAsNGramSourceEnabled = true // n-gram 來源開啟。
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
    // 選取來自 n-gram 統計路徑（previous 帶「是」），非自動 override 錨定的 bare unigram。
    #expect(testHandler.assembler.assembledSentence.last?.gram.previous == "是")
  }

  /// 狂拼 α 自動套用（R3-a）：注拼槽整段無法展開成完整音節序列（如「ysxb」）、
  /// 且整詞簡拼查詢的頂級候選「明確勝出」（唯一匹配）時，自動把其實際讀音以單鍵
  /// 序列寫入組字器——全程自動出整詞「野獸先輩」、不必等使用者 Shift+選字鍵確認。
  /// 自動套用為最佳猜測、非顯式選字：不觸發 POM 觀察、trail 失效（簡拼非完整音節）。
  @Test
  func test_IH139_FuriousTypingAbbreviationAutoAppliesClearWinner() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH142_FuriousTypingAbbreviationAmbiguousStays() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH143_FuriousTypingXianShengNotSplit() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH147_FuriousTypingCoSegmentedOffersEnterCopilotWindow() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH148_FuriousTypingSelectingCoSegmentedOfferReplacesTrail() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
  @Test
  func test_IH149_FuriousTypingCoSegmentedOfferRanksBeforeSingleSyllables() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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

  /// 狂拼 copilot 窗置頂候選就地選字的首段重合（P165）：`tama`＋POM「他媽的」記憶
  /// 時，copilot 窗置頂候選為「他媽的」（3 段、首段 ㄊㄚ 與組字器尾鍵 ㄊㄚ桶 重合）。
  /// 就地選中後，`applyFuriousFrontCandidate` 應只插入重合段以外的讀音並覆寫完整詞
  /// ——組字器「他媽的」、**不含重複「他」**（修復前：插入完整 keyArray →「他他媽的」）。
  @Test
  func test_IH150_FuriousTypingTamaPreviewNoDuplicate() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.pomAsNGramSourceEnabled = false
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
    testHandler.prefs.furiousTypingEnabled = true
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
    testHandler.prefs.pomAsNGramSourceEnabled = true
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.syncPrefs()

    typeSentence("tama")
    guard let idx = testSession.state.candidates.firstIndex(where: { $0.value == "他媽的" })
    else {
      Issue.record("POM-fronted '他媽的' candidate not found in copilot window.")
      return
    }
    #expect(testSession.state.candidates[idx].keyArray == ["ㄊㄚ", "ㄇㄚ", "ㄉㄜ˙"])

    // 就地選中置頂 POM 候選「他媽的」。
    testSession.candidatePairSelectionConfirmed(at: idx)

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
  @Test
  func test_IH151_FuriousCopilotWindowDedupsPOMFrontedCandidate() throws {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.pomAsNGramSourceEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    // 與 IH150 同源：真實 factory 詞庫相關詞條 grams＋三條使用者環境 POM 記憶。
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
    testHandler.prefs.furiousTypingEnabled = true
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
    testHandler.prefs.pomAsNGramSourceEnabled = true
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
}
