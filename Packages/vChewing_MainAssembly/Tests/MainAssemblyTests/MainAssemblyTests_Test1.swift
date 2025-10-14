// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
@testable import LangModelAssembly
@testable import MainAssembly
import Megrez
import MegrezTestComponents
import OSFrameworkImpl
import Shared
@testable import Typewriter
import XCTest

extension MainAssemblyTests {
  func test001_ClientTest_BundleIdentifier() throws {
    guard let identifier = testSession.client()?.bundleIdentifier() else {
      fatalError("致命錯誤：客體唯一標幟碼無效。")
    }
    vCTestLog("測試客體唯一標幟碼：\(identifier)")
  }

  func test002_ClientTest_TextInsertion() throws {
    testClient.clear()
    let testString = UUID().uuidString
    testSession.client().insertText(testString, replacementRange: .notFound)
    XCTAssertEqual(testClient.attributedString.string, testString)
    testClient.clear()
  }

  // MARK: - Input Handler Tests.

  /// 測試基本的打字組句（不是ㄅ半注音）。
  func test101_InputHandler_BasicSentenceComposition() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：高科技公司的年中獎金")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    let resultText1 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "高科技公司的年中獎金")
    guard let crlfEvent = dataEnterReturn.asEvent else { return }
    XCTAssertTrue(testHandler.triageInput(event: crlfEvent))
    XCTAssertEqual(testClient.toString(), "高科技公司的年中獎金")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  func test102_InputHandler_BasicSCPCTyping() throws {
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：高科技公司的年中獎金")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru44ej/ 2n ")
    dataArrowDown.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    typeSentenceOrCandidates("12k7su065j/ ru;3rup ")
    XCTAssert(testSession.candidateUI?.visible ?? false)
    dataEnterReturn.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    let resultText1 = testClient.toString()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "高科技公司的年中獎金")
    testClient.clear()
  }

  /// 測試就地輪替候選字。
  func test103_InputHandler_RevolvingCandidates() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru4ej/ n 2k7su065j/ ru;3rup ")

    // Testing Inline Candidate Revolver.

    vCTestLog("測試就地輪替候選字：高科技公司的年中獎金 -> 高科技公司的年終獎金")

    [dataArrowLeft, dataArrowLeft].map(\.asPairedEvents).flatMap { $0 }.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }

    dataTab.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    let resultText2 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText2)")
    XCTAssertEqual(resultText2, "高科技公司的年終獎金")
  }

  /// 測試藉由選字窗選字、且同時測試漸退記憶模組在此情況下的記憶資料生成與適用情況。
  /// - Remark: 這裡順便測試一下「在選字窗選字後自動推進游標」這個有被預設啟用的功能。
  func test104_InputHandler_ManualCandidateSelectionAndPOM() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 1
    clearTestPOM()

    var sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates(sequenceChars)

    // Testing Manual Candidate Selection, POM Observation, and Post-Candidate-Selection Cursor Jumping.

    vCTestLog("測試選字窗選字：高科技公司的年終獎金 -> 高科技公司的年中獎金")
    vCTestLog("Pref=1 nodes before candidate: \(testHandler.assembler.assembledSentence.values)")
    vCTestLog(
      "Pref=1 cursor before candidate: \(testHandler.assembler.cursor)/length: \(testHandler.assembler.length)"
    )
    dataArrowDown.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    vCTestLog("Pref=1 candidates: \(testSession.state.candidates.map { $0.value })")
    let keyOne = NSEvent.KeyEventData(chars: "1")
    keyOne.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    let resultText3 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText3)")
    XCTAssertEqual(resultText3, "高科技公司的年中獎金")
    XCTAssertEqual(testHandler.assembler.cursor, 10)

    // Continuing POM Tests (in the Current Context).

    vCTestLog("測試漸退記憶的適用範圍：「年終」的記憶應僅對下述給定上下文情形生效。")
    vCTestLog("- 該給定上下文情形為「(ㄍㄨㄥ-ㄙ,公司)&(ㄉㄜ˙,的)」且頭部讀音為「ㄋㄧㄢˊ-ㄓㄨㄥ」。")
    clearTestPOM()
    let keyTwo = NSEvent.KeyEventData(chars: "2")
    [dataArrowLeft, dataArrowLeft, dataArrowDown, keyTwo].map(\.asPairedEvents).flatMap { $0 }
      .forEach { theEvent in
        let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
        if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
      }
    let resultText4 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText4)")
    XCTAssertEqual(resultText4, "高科技公司的年終獎金")

    vCTestLog("- 清空組字區，重新打剛才那句話來測試。")
    testSession.switchState(IMEState.ofAbortion())
    typeSentenceOrCandidates(sequenceChars)
    let resultText5 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText5)")
    XCTAssertEqual(resultText5, "高科技公司的年終獎金")
    vCTestLog("- 已成功證實「年終」的記憶對該給定上下文情形生效。")

    vCTestLog("- 清空組字區，重新打另一句話來測試。")
    testSession.switchState(IMEState.ofAbortion())

    sequenceChars = "ru4ej/ 2k7su065j/ ru;3rup "
    typeSentenceOrCandidates(sequenceChars)
    let resultText6 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText6)")
    XCTAssertEqual(resultText6, "濟公的年中獎金")
    vCTestLog("- 已成功證實「年終」的記憶不會對除了給定上下文以外的情形生效。")
  }

  /// 測試在選字後復原游標位置的功能，確保游標會回到叫出選字窗前的位置。
  func test105_InputHandler_PostCandidateCursorPlacementRestore() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 2
    clearTestPOM()

    let sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates(sequenceChars)

    [dataArrowLeft, dataArrowLeft].map(\.asPairedEvents).flatMap { $0 }.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
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

    dataArrowDown.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }

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
    let targetKey = String(selectionKeys[candidateIndex])
    let keyEvent = NSEvent.KeyEventData(chars: targetKey)
    keyEvent.asPairedEvents.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == NSEvent.EventType.keyDown { XCTAssertFalse(dismissed) }
    }

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
  func test106_InputHandler_MiscCommissionTest() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru4ej/ n 2k7")
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

  func test107_InputHandler_CassetteQuickPhraseSelection() throws {
    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    LMMgr.syncLMPrefs()

    let cassetteURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // MainAssemblyTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_MainAssembly
      .deletingLastPathComponent() // Packages
      .appendingPathComponent("vChewing_LangModelAssembly")
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestCINData")
      .appendingPathComponent("array30.cin2")

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentenceOrCandidates(",,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,")

    let initialCandidates = testSession.state.candidates.map(\.value)
    XCTAssertFalse(initialCandidates.isEmpty)
    XCTAssertTrue(initialCandidates.allSatisfy { $0.count == 1 })

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      XCTFail("Quick phrase commission key missing")
      return
    }

    typeSentenceOrCandidates(quickPhraseKey)

    XCTAssertTrue(testHandler.calligrapher.isEmpty)
    XCTAssertEqual(testSession.state.type, .ofEmpty)
    XCTAssertEqual(testClient.toString(), "米糕")
  }

  func test108_InputHandler_CassetteQuickPhraseSymbolTableMultiple() throws {
    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    LMMgr.syncLMPrefs()

    let cassetteURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // MainAssemblyTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_MainAssembly
      .deletingLastPathComponent() // Packages
      .appendingPathComponent("vChewing_LangModelAssembly")
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestCINData")
      .appendingPathComponent("array30.cin2")

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentenceOrCandidates(",,,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      XCTFail("Quick phrase commission key missing")
      return
    }

    typeSentenceOrCandidates(quickPhraseKey)

    XCTAssertEqual(testSession.state.type, .ofSymbolTable)
    XCTAssertEqual(testSession.state.node.name, ",,,,")
    XCTAssertEqual(
      testSession.state.node.members.map(\.name),
      ["炎炎", "迷迷糊糊", "熒熒"]
    )
    XCTAssertEqual(
      testSession.state.candidates.map(\.value),
      ["炎炎", "迷迷糊糊", "熒熒"]
    )
    XCTAssertTrue(testClient.toString().isEmpty)

    let selectionKeys = Array(testSession.selectionKeys)
    XCTAssertGreaterThan(selectionKeys.count, 1)

    typeSentenceOrCandidates(String(selectionKeys[1]))

    XCTAssertTrue(testHandler.calligrapher.isEmpty)
    XCTAssertEqual(testSession.state.type, .ofEmpty)
    XCTAssertEqual(testClient.toString(), "迷迷糊糊")
  }

  func test109_InputHandler_CodePointInputCheck() throws {
    let testCodes: [(Shared.InputMode, String)] = [
      (.imeModeCHS, "C8D0"),
      (.imeModeCHT, "A462"),
    ]

    // 模擬 `Opt+~` 熱鍵組合觸發碼點模式。
    let symbolMenuKeyData = NSEvent.KeyEventData(
      type: .keyDown,
      flags: .option,
      chars: "`",
      charsSansModifiers: "`",
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )
    let symbolMenuKeyEvents = symbolMenuKeyData.asPairedEvents
    testSession.switchState(.ofAbortion())

    for (langMode, codePointHexStr) in testCodes {
      defer {
        // 切換至 Abortion 狀態會自動清理 Handler，此時會連帶重設 typingMethod。
        testSession.switchState(.ofAbortion())
        testClient.clear()
      }
      PrefMgr().mostRecentInputMode = langMode.rawValue
      XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory)
      for nsEv in symbolMenuKeyEvents {
        XCTAssertTrue(testSession.handleNSEvent(nsEv, client: testClient))
      }
      XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeSentenceOrCandidates(codePointHexStr)
      XCTAssertEqual(testClient.toString(), "刃")
      vCTestLog("-> Result: \(testClient.toString())")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }
}
