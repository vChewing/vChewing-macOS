// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import MegrezTestComponents
import Shared
import XCTest

@testable import LangModelAssembly
@testable import Typewriter

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// MARK: - 測試案例

extension InputHandlerTests {
  /// 測試基本的打字組句（不是ㄅ半注音）。
  func test_IH101_BasicSentenceComposition() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳，但這裡暫時先期待失敗結果「優跌能留意旅方」")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("u. 2u,6s/6xu.6u4xm3z; ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "優跌能留意旅方")
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    XCTAssertEqual(testSession.recentCommissions.joined(), "優跌能留意旅方")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  ///
  /// 注意：Typewriter Tests 並無測試選字窗行為的條件。
  /// SCPC 打字的行為處理過程高度強調選字窗的參與，所以此處僅測試打一個字。
  /// 完整測試需在 MainAssembly 測試進行。
  func test_IH102_BasicSCPCTyping() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：優")
    testHandler.clear()
    typeSentence("u. ") // 打「優」字的讀音：「ㄧㄡ」，最後空格是陰平聲調。
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertFalse(resultText1.isEmpty)
    let candidates = testHandler.generateArrayOfCandidates()
    XCTAssertTrue(resultText1.contains("優") || candidates.map { $0.value }.contains("優"))
    // 測試到此為止，於 MainAssembly 的同名測試繼續。
  }

  /// 測試就地輪替候選字。
  func test_IH103_RevolvingCandidates() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
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
    XCTAssertEqual(resultText2, "幽蝶能留一縷芳")
  }

  /// 測試漸退記憶模組的記憶資料生成與適用。
  func test_IH104_ManualCandidateSelectionAndPOM() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 1
    clearTestPOM()

    var sequenceChars = "u. 2u,6s/6xu.6u4xm3z; "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence(sequenceChars)
    XCTAssertEqual(testHandler.assembler.cursor, 7)

    // Testing Manual Candidate Selection, POM Observation, and Post-Candidate-Selection Cursor Jumping.

    vCTestLog("測試選字窗選字：優跌能留意旅方 -> 幽蝶能留一縷芳")
    vCTestLog("Pref=1 nodes before candidate: \(testHandler.assembler.assembledSentence.values)")
    vCTestLog(
      "Pref=1 cursor before candidate: \(testHandler.assembler.cursor)/length: \(testHandler.assembler.length)"
    )
    vCTestLog("Pref=1 candidates: \(testSession.state.candidates.map { $0.value })")
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent))
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    testSession.candidatePairSelectionConfirmed(at: 0) // 「一縷」
    // 此時游標應該有往前推進一格。
    XCTAssertEqual(testHandler.assembler.cursor, 7)
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    testSession.candidatePairSelectionConfirmed(at: 3) // 「芳」
    vCTestLog("- // 組字結果：\(testSession.state.displayedText)")
    XCTAssertEqual(testSession.state.displayedText, "優跌能留一縷芳")
    XCTAssertEqual(testHandler.assembler.cursor, 7)

    // 把頭兩個節點也做選字。
    XCTAssertEqual(testSession.state.type, .ofInputting)
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent))
    XCTAssertEqual(testHandler.assembler.cursor, 1)
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    testSession.candidatePairSelectionConfirmed(at: 2) // 「幽」
    XCTAssertEqual(testHandler.assembler.cursor, 2)
    XCTAssertEqual(testSession.state.displayedText, "幽跌能留一縷芳")
    testSession.switchState(testHandler.generateStateOfCandidates())
    testSession.candidatePairSelectionConfirmed(at: 1) // 「蝶」
    XCTAssertEqual(testSession.state.displayedText, "幽蝶能留一縷芳")
    XCTAssertEqual(testHandler.assembler.cursor, 4)

    // Continuing POM Tests (in the Current Context).

    vCTestLog("測試漸退記憶的適用範圍：此時已經生成的「芳」的記憶應僅對下述給定上下文情形生效。")
    vCTestLog("- 該給定上下文情形為「(ㄌㄧㄡˊ,留)&(ㄧˋ-ㄌㄩˇ,一縷)」且頭部讀音為「ㄈㄤ」。")
    vCTestLog("- 清空組字區，重新打剛才那句話來測試。")
    testSession.switchState(.ofAbortion())
    typeSentence(sequenceChars)
    let resultText5 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText5)")
    XCTAssertEqual(resultText5, "幽蝶能留一縷芳")
    vCTestLog("- 已成功證實「年終」的記憶對該給定上下文情形生效。")

    vCTestLog("- 清空組字區，重新打另一句話來測試。")
    testSession.switchState(.ofAbortion())

    sequenceChars = "u. 2u,6s/6xu.6z; "
    typeSentence(sequenceChars)
    vCTestLog("- // 組字結果：\(testSession.state.displayedText)")
    XCTAssertEqual(testSession.state.displayedText, "幽蝶能留方")
    XCTAssertNotEqual(testSession.state.displayedText, "幽蝶能留芳")
    vCTestLog("- 已成功證實「芳」的記憶不會對除了給定上下文以外的情形生效。")
  }

  /// 測試在選字後復原游標位置的功能。
  func test_IH105_PostCandidateCursorPlacementRestore() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
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
    let nodesBeforeCandidate = testHandler.assembler.assembledSentence.values
    XCTAssertFalse(nodesBeforeCandidate.isEmpty)
    let readingCursorIndex = testHandler.actualNodeCursorPosition
    var nodeIndex: Int?
    var readingCursor = 0
    for (index, node) in testHandler.assembler.assembledSentence.enumerated() {
      let segmentLength = node.keyArray.count
      if readingCursorIndex < readingCursor + segmentLength || index == nodesBeforeCandidate.count - 1 {
        nodeIndex = index
        break
      }
      readingCursor += segmentLength
    }
    guard let nodeIndex else {
      XCTFail("Unable to locate node for cursor position: \(readingCursorIndex)")
      return
    }
    let currentNodeValue = nodesBeforeCandidate[nodeIndex]
    let cursorBeforeCandidate = testHandler.assembler.cursor
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)
    XCTAssertEqual(testSession.state.type, .ofCandidates)
    let candidateValues = testSession.state.candidates.map { $0.value }
    XCTAssertFalse(candidateValues.isEmpty)
    let targetCandidate = candidateValues.first { $0 != currentNodeValue } ?? currentNodeValue
    guard let candidateIndex = candidateValues.firstIndex(of: targetCandidate) else {
      XCTFail("Target candidate not found. Candidates: \(candidateValues)")
      return
    }
    let selectionKeys = Array(testSession.selectionKeys)
    XCTAssertGreaterThan(selectionKeys.count, candidateIndex)
    testSession.candidatePairSelectionConfirmed(at: candidateIndex) // 「年終」
    let nodesAfterCandidate = testHandler.assembler.assembledSentence.values
    XCTAssertEqual(nodesAfterCandidate.count, nodesBeforeCandidate.count)
    XCTAssertEqual(nodesAfterCandidate[nodeIndex], targetCandidate)
    let expectedText = nodesAfterCandidate.joined()
    let resultText = testSession.state.displayedText
    XCTAssertEqual(resultText, expectedText)
    XCTAssertEqual(testHandler.assembler.cursor, cursorBeforeCandidate)
    XCTAssertNil(testHandler.backupCursor)
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  func test_IH106_MiscCommissionTest() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("dk ru4204el ")
    guard let handler = testSession.inputHandler else {
      XCTAssertThrowsError("testSession.handler is nil.")
      return
    }
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    XCTAssertEqual(result, "ㄎㄜ ㄐㄧˋ ㄉㄢˋ ㄍㄠ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    XCTAssertEqual(result, "科(ㄎㄜ)技(ㄐㄧˋ)蛋(ㄉㄢˋ)糕(ㄍㄠ)")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>蛋<rp>(</rp><rt>ㄉㄢˋ</rt><rp>)</rp></ruby><ruby>糕<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby>
    """
    XCTAssertEqual(result, expectedRubyResult)
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠇⠮⠄⠅⠡⠐⠙⠧⠐⠅⠩⠄")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠅⠢⠁⠛⠊⠆⠙⠧⠆⠛⠖⠁")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  /// 測試磁帶模組的快速選字功能（單一結果）。
  func test_IH107_CassetteQuickPhraseSelection() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    testHandler.currentTypingMethod = .vChewingFactory

    let cassetteURL = cassetteURL4Array30CIN2

    guard FileManager.default.fileExists(atPath: cassetteURL.path) else {
      vCTestLog("測試檔案不存在，跳過測試：\(cassetteURL.path)")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    let cassetteLM = LMAssembly.LMInstantiator.lmCassette
    XCTAssertTrue(cassetteLM.isLoaded)
    XCTAssertTrue(!cassetteLM.charDefMap.isEmpty)

    testHandler.clear()
    typeSentence(",,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    // 打完 QuickPhrase 確認鍵之後，組筆區的內容應該會被清空、且此時應該有結果遞交出去。
    let currentState = testSession.state
    XCTAssertTrue(
      currentState.type == .ofEmpty || currentState.type == .ofSymbolTable,
      "Quick phrase with single result should either commit directly or open a symbol table, got \(currentState.type)."
    )
    // ↑MockSession 會在遞交結果時回復為 .ofEmpty，因此此處允許 .ofEmpty。
    XCTAssertTrue(testHandler.calligrapher.isEmpty)
    // 只有單筆結果時，得立刻遞交出去。組筆區應該是有結果的。
    let result = generateDisplayedText()
    vCTestLog("Result after quick phrase: '\(testSession.recentCommissions.last ?? "NULL")'")
    XCTAssertEqual(testSession.recentCommissions.last, "米糕")
    // 單一結果的快速片語會立即遞交，因此組字器可能維持為空；此時仍需檢查狀態是否合理
    XCTAssertTrue(testSession.state.type == .ofEmpty || !result.isEmpty)
  }

  /// 測試磁帶模組的快速選字功能（符號表多選）。
  func test_IH108_CassetteQuickPhraseSymbolTableMultiple() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true

    let cassetteURL = cassetteURL4Array30CIN2

    guard FileManager.default.fileExists(atPath: cassetteURL.path) else {
      vCTestLog("測試檔案不存在，跳過測試：\(cassetteURL.path)")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    typeSentence(",,,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    vCTestLog("Testing symbol table multi-selection")
    vCTestLog("Calligrapher: \(testHandler.calligrapher)")

    XCTAssertEqual(testSession.state.type, .ofSymbolTable)
    XCTAssertEqual(testSession.state.node.name, ",,,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,,")

    // 測試是否產生了多個候選字
    let symbolCandidates = testSession.state.node.members.map { $0.name }
    XCTAssertEqual(symbolCandidates, ["炎炎", "迷迷糊糊", "熒熒"])
    // 此時應該還沒有 Commit 才對，因為這時的狀態是選字窗顯示出來了。
    XCTAssertEqual(testSession.recentCommissions.last, nil)
    let stateCandidates = testSession.state.data.candidates.map { $0.value }
    XCTAssertEqual(stateCandidates, symbolCandidates)
    vCTestLog("Candidates: \(symbolCandidates)")
    // Typewriter 測試不會去測試選字窗的行為，這類行為的測試由 MainAssembly 測試負責。
    testSession.candidatePairSelectionConfirmed(at: 1)
    XCTAssertEqual(testSession.recentCommissions.last, "迷迷糊糊")
  }

  func test_IH109_CodePointInputCheck() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
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
        testSession.switchState(MockIMEState.ofAbortion())
      }
      PrefMgr().mostRecentInputMode = langMode.rawValue
      XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory)
      XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
      XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeSentence(codePointHexStr)
      XCTAssertEqual(testSession.recentCommissions.last, "刃")
      vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }

  func test_IH110_POMBleacherIntegrationTest() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    var extractedGrams: [Megrez.Unigram] = []
    MegrezTestComponents.strLMSampleDataHutao.enumerateLines { currentLine, _ in
      let cells = currentLine.split(separator: " ")
      guard cells.count >= 3 else { return }
      guard ["liu2-yi4", "liu2", "yi4"].contains(cells[0]) else { return }
      let readingArray: [String] = cells[0]
        .replacingOccurrences(of: "liu2", with: "ㄌㄧㄡˊ")
        .replacingOccurrences(of: "yi4", with: "ㄧˋ")
        .split(separator: "-").map(\.description)
      let cellScoreStr = cells[2].description
      guard let cellScore = Double(cellScoreStr) else { return }
      let unigram = Megrez.Unigram(
        keyArray: readingArray, value: cells[1].description, score: cellScore
      )
      if unigram.segLength > 1 {
        extractedGrams.insert(
          .init(keyArray: readingArray, value: cells[1].description, score: cellScore),
          at: 0
        )
      } else {
        extractedGrams.append(
          .init(keyArray: readingArray, value: cells[1].description, score: cellScore)
        )
      }
    }
    extractedGrams = extractedGrams.filter {
      $0.segLength > 1 || $0.score > -6
    }
    extractedGrams.sort { $0.segLength > $1.segLength && $0.score > $1.score }
    let additionalUnigrams = extractedGrams
    additionalUnigrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    let fetchedExtraUnigrams1 = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    XCTAssert(Set(fetchedExtraUnigrams1).count == 4)
    XCTAssertEqual(Set(additionalUnigrams.prefix(4)), Set(fetchedExtraUnigrams1))
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = [.sortedKeys]
    let readingKeyChainStr = "xu.6u4"
    typeSentence(readingKeyChainStr)
    // 此時「留意」原始權重最高，會被自動選中。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "留意")
    XCTAssertEqual(testSession.state.displayedText, "留意")
    // let candidateCursor = testHandler.actualNodeCursorPosition
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(4)
    XCTAssertEqual(candidates1, ["留意", "流溢", "流易", "流議"])
    // 觸發選字窗選擇「流易」，該字詞在 Megrez 內的的頻分權重由常規區間（ -9.5 <= x <= 0）升至 114_514。
    testSession.candidatePairSelectionConfirmed(at: 2) // 「流易」
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流易")
    XCTAssertEqual(testSession.state.displayedText, "流易")
    // 此時應該有生成一些 POM 記憶。
    let pomData1 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON1 = try jsonEncoder.encode(pomData1)
    let encodedJSONStr1 = String(data: encodedJSON1, encoding: .utf8) ?? "N/A"
    // 每次跑測試時，ts 時間戳都不同。所以不將 ts 的資料值納入 Assertion 對象。
    XCTAssertTrue(encodedJSONStr1.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
    // 直接呼叫 EmptyState。這個過程會清空 InputHandler。
    testSession.switchState(.ofEmpty())
    XCTAssertTrue(testHandler.assembler.isEmpty)
    // 重新打字。
    typeSentence(readingKeyChainStr)
    // 此時「流易」權重最高，因為是 POM 推薦資料。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流易")
    XCTAssertEqual(testSession.state.displayedText, "流易")
    // 檢查 assembler 內部的 nodes 確保「流易」的 OverridingScore 必須不能是「114_514」。
    // 不然的話，會出現 POM 記憶劫持使用者片語的情況。
    // 判斷方法是：任何雙字詞節點都不該有「score == 114_514」。
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    let allNodes: [Megrez.Node] = testHandler.assembler.segments.compactMap { $0[2] }
    XCTAssertTrue(allNodes.allSatisfy { $0.score != 114_514 })
    // 嘗試觸發就地加詞的 method。這在目前的這個單元測試內不會實際加詞，但會嘗試清空相關的 POM 記憶。
    // 咱們先用 revolveCandidate 的功能將該節點換成別的雙字候選詞。
    let candidateStateTemporary1 = testHandler.generateStateOfCandidates()
    let candidatesAssumed = candidateStateTemporary1.candidates.prefix(4).map(\.value)
    XCTAssertEqual(candidatesAssumed, ["流易", "留意", "流溢", "流議"])
    // 第三個候選字詞是「流溢」，咱們用這個做實驗。於是讓 revolver API 往正極方向輪兩下。
    XCTAssertTrue(testHandler.revolveCandidate(reverseOrder: false))
    XCTAssertTrue(testHandler.revolveCandidate(reverseOrder: false))
    // Revolver 輪轉完畢。這個過程不會影響 POM。開始確認當前候選字詞是「流溢」。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流溢")
    XCTAssertEqual(testSession.state.displayedText, "流溢")
    XCTAssertEqual(testSession.state.type, .ofInputting)
    // 然後呼叫 .ofMarking 狀態、以便接下來的對就地加詞 API 的觸發。
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .front))
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    XCTAssertTrue(testHandler.triageInput(event: arrLeftEvent.asEvent))
    XCTAssertTrue(testHandler.triageInput(event: arrLeftEvent.asEvent))
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .rear, isMarker: true))
    XCTAssertEqual(testSession.state.type, .ofMarking)
    XCTAssertEqual(testSession.state.markedRange, 0 ..< 2)
    // 這一行會觸發 handleMarkingState(input: Enter) 所排定觸發的 `performUserPhraseOperation`。
    // 此過程在 MockSession 會觸發 `inputHandler.currentLM.bleachSpecifiedPOMSuggestions`。
    // 註：真實 Session 會通過 `LMMgr.bleachSpecifiedSuggestions` 間接觸發該 API。
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let fetchablesNow = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    let assumedNewUnigram = Megrez.Unigram(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"], value: "流溢", score: 0)
    XCTAssert(fetchablesNow.contains(assumedNewUnigram))
    // 現在應該假設 POM 當中任何妨礙 assumedNewUnigram 被選中的內容都被清掉了。
    // 看一下 POM 記憶。
    let pomData2 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON2 = try jsonEncoder.encode(pomData2)
    let encodedJSONStr2 = String(data: encodedJSON2, encoding: .utf8) ?? "N/A"
    // 到這一步如果 Asserts 都通過的話就證明手動加詞時的 Bleacher 是成功的。
    XCTAssertTrue(!encodedJSONStr2.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
  }

  func test_IH111_POMStopShortKeyArrFromHijackingLongKeyArr() throws {
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    // 備註：該測試用例沒必要鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：年中")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("su065j/ ")
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["年中"])
    XCTAssertTrue(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertTrue(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertFalse(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .rear))
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(3)
    XCTAssertEqual(candidates1, ["年", "黏", "粘"])
    testSession.candidatePairSelectionConfirmed(at: 2) // 黏
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["粘", "中"])
    testSession.switchState(.ofAbortion())
    // 模擬手動加詞的情況。
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], value: "年終", score: 0),
      isFiltering: false
    )
    typeSentence("su065j/ ")
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["年終"])
  }

  func test_IH112_RomanNumeralInputCheck() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
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
    testSession.switchState(.ofAbortion())

    // Test uppercase ASCII format (default)
    XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory)
    // First toggle to codePoint
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
    // Second toggle to haninKeyboardSymbol
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .haninKeyboardSymbol)
    // Third toggle to romanNumerals
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    vCTestLog("Testing roman numeral input: 1994")
    typeSentence("1994")
    XCTAssertEqual(testSession.recentCommissions.last, "MCMXCIV")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // Test another number
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    vCTestLog("Testing roman numeral input: 1042")
    typeSentence("1042")
    XCTAssertEqual(testSession.recentCommissions.last, "MXLII")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字輸入測試。")
  }

  /// 測試羅馬數字模式下的空格鍵功能
  func test_IH113_RomanNumeralSpaceKeyHandling() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    // Create a space key event
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

    // Create symbol menu key event (Option + `)
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

    // Enter Roman Numerals mode
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .haninKeyboardSymbol)
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)

    // Test 1: Space key with empty buffer should trigger ofAbortion
    vCTestLog("Test 1: Space key with empty buffer")
    var errorCallbackTriggered = false
    testHandler.errorCallback = { errorID in
      vCTestLog("Error callback triggered with ID: \(errorID)")
      errorCallbackTriggered = true
    }
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertTrue(errorCallbackTriggered, "Error callback should be triggered for empty buffer")
    // State transitions to ofAbortion and then immediately to ofEmpty
    XCTAssertEqual(testSession.state.type, .ofEmpty, "State should be ofEmpty after ofAbortion transition")

    // Test 2: Space key with buffer content should commit Roman numeral
    vCTestLog("Test 2: Space key with '42' should commit 'XLII'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    
    typeSentence("42")
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertEqual(testSession.recentCommissions.last, "XLII", "Should commit 'XLII' for input '42'")
    XCTAssertEqual(testSession.state.type, .ofEmpty, "State should be ofEmpty after successful commit")
    XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory, "Should return to vChewingFactory mode after commit")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // Test 3: Space key with 3-digit number
    vCTestLog("Test 3: Space key with '999' should commit 'CMXCIX'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    
    typeSentence("999")
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertEqual(testSession.recentCommissions.last, "CMXCIX", "Should commit 'CMXCIX' for input '999'")
    XCTAssertEqual(testSession.state.type, .ofEmpty, "State should be ofEmpty after successful commit")
    XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory, "Should return to vChewingFactory mode after commit")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // Test 4: Enter key should still work (existing functionality)
    vCTestLog("Test 4: Enter key with '2023' should commit 'MMXXIII'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    
    typeSentence("2023")
    XCTAssertEqual(testSession.recentCommissions.last, "MMXXIII", "Should auto-commit 'MMXXIII' for 4-digit input '2023'")
    XCTAssertEqual(testSession.state.type, .ofEmpty, "State should be ofEmpty after auto-commit")
    XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory, "Should return to vChewingFactory mode after commit")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字空格鍵測試。")
  }
}
