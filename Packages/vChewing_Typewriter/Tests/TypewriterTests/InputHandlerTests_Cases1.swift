// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import XCTest

@testable import LangModelAssembly
@testable import Typewriter

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
    vCTestLog("測試組句：高科技公司的年中獎金")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "高科技公司的年中獎金")
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    XCTAssertEqual(testSession.recentCommissions.joined(), "高科技公司的年中獎金")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  ///
  /// 注意：Typewriter Tests 並無測試選字窗行為的條件。
  /// SCPC 打字的行為處理過程高度強調選字窗的參與，所以此處僅測試打一個字。
  /// 完整測試需在 MainAssembly 測試進行。
  func test_IH102_InputHandler_BasicSCPCTyping() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：高")
    testHandler.clear()
    typeSentence("el ") // 打「高」字的讀音：「ㄍㄠ」，最後空格是陰平聲調。
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertFalse(resultText1.isEmpty)
    let candidates = testHandler.generateArrayOfCandidates()
    XCTAssertTrue(resultText1.contains("高") || candidates.map { $0.value }.contains("高"))
    // 測試到此為止，於 MainAssembly 的同名測試繼續。
  }

  /// 測試就地輪替候選字。
  func test_IH103_InputHandler_RevolvingCandidates() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    vCTestLog("測試就地輪替候選字：高科技公司的年中獎金 -> 高科技公司的年終獎金")
    let eventDataChain: [KBEvent.KeyEventData] = [.dataArrowLeft, .dataArrowLeft, .dataTab]
    eventDataChain.map(\.asEvent).forEach { theEvent in
      _ = testHandler.triageInput(event: theEvent)
    }
    let resultText2 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText2)")
    XCTAssertEqual(resultText2, "高科技公司的年終獎金")
  }

  /// 測試漸退記憶模組的記憶資料生成與適用。
  func test_IH104_InputHandler_ManualCandidateSelectionAndPOM() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 1
    clearTestPOM()

    var sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence(sequenceChars)

    // Testing Manual Candidate Selection, POM Observation, and Post-Candidate-Selection Cursor Jumping.

    vCTestLog("測試選字窗選字：高科技公司的年終獎金 -> 高科技公司的年中獎金")
    vCTestLog("Pref=1 nodes before candidate: \(testHandler.assembler.assembledSentence.values)")
    vCTestLog(
      "Pref=1 cursor before candidate: \(testHandler.assembler.cursor)/length: \(testHandler.assembler.length)"
    )
    XCTAssertTrue(
      testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)
    )
    vCTestLog("Pref=1 candidates: \(testSession.state.candidates.map { $0.value })")
    testSession.candidatePairSelectionConfirmed(at: 1) // 「金」
    let resultText3 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText3)")
    XCTAssertEqual(resultText3, "高科技公司的年中獎金")
    XCTAssertEqual(testHandler.assembler.cursor, 10)

    // Continuing POM Tests (in the Current Context).

    vCTestLog("測試漸退記憶的適用範圍：「年終」的記憶應僅對下述給定上下文情形生效。")
    vCTestLog("- 該給定上下文情形為「(ㄍㄨㄥ-ㄙ,公司)&(ㄉㄜ˙,的)」且頭部讀音為「ㄋㄧㄢˊ-ㄓㄨㄥ」。")
    clearTestPOM()
    let eventDataChain1: [KBEvent.KeyEventData] = [
      .dataArrowLeft, .dataArrowLeft, .dataArrowDown,
    ]
    eventDataChain1.map(\.asEvent).forEach { theEvent in
      _ = testHandler.triageInput(event: theEvent)
    }
    testSession.candidatePairSelectionConfirmed(at: 1) // 「年終」
    let resultText4 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText4)")
    XCTAssertEqual(resultText4, "高科技公司的年終獎金")

    vCTestLog("- 清空組字區，重新打剛才那句話來測試。")
    testSession.switchState(.ofAbortion())
    typeSentence(sequenceChars)
    let resultText5 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText5)")
    XCTAssertEqual(resultText5, "高科技公司的年終獎金")
    vCTestLog("- 已成功證實「年終」的記憶對該給定上下文情形生效。")

    vCTestLog("- 清空組字區，重新打另一句話來測試。")
    testSession.switchState(.ofAbortion())

    sequenceChars = "ru4ej/ 2k7su065j/ ru;3rup "
    typeSentence(sequenceChars)
    let resultText6 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText6)")
    XCTAssertEqual(resultText6, "濟公的年中獎金")
    vCTestLog("- 已成功證實「年終」的記憶不會對除了給定上下文以外的情形生效。")
  }

  /// 測試在選字後復原游標位置的功能。
  func test_IH105_InputHandler_PostCandidateCursorPlacementRestore() throws {
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
  func test_IH106_InputHandler_MiscCommissionTest() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("el dk ru4ej/ n 2k7")
    guard let handler = testSession.inputHandler else {
      XCTAssertThrowsError("testSession.handler is nil.")
      return
    }
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    XCTAssertEqual(result, "ㄍㄠ ㄎㄜ ㄐㄧˋ ㄍㄨㄥ ㄙ ˙ㄉㄜ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    XCTAssertEqual(result, "高(ㄍㄠ)科(ㄎㄜ)技(ㄐㄧˋ)公(ㄍㄨㄥ)司(ㄙ)的(˙ㄉㄜ)")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>高<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby><ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>公<rp>(</rp><rt>ㄍㄨㄥ</rt><rp>)</rp></ruby><ruby>司<rp>(</rp><rt>ㄙ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>
    """
    XCTAssertEqual(result, expectedRubyResult)
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠅⠩⠄⠇⠮⠄⠅⠡⠐⠅⠯⠄⠑⠄⠙⠮⠁")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠛⠖⠁⠅⠢⠁⠛⠊⠆⠛⠲⠁⠎⠁⠙⠢")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  /// 測試磁帶模組的快速選字功能（單一結果）。
  func test_IH107_InputHandler_CassetteQuickPhraseSelection() throws {
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
  func test_IH108_InputHandler_CassetteQuickPhraseSymbolTableMultiple() throws {
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

  func test_IH109_InputHandler_CodePointInputCheck() throws {
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
      characters: "`KeyCode.kSymbolMenuPhysicalKeyIntl`",
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
}
