// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import LangModelAssembly
@testable import MainAssembly
import OSFrameworkImpl
import Shared
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
    PrefMgr.shared.useSCPCTypingMode = false
    clearTestUOM()
    vCTestLog("測試組句：高科技公司的年中獎金")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    let resultText1 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "高科技公司的年中獎金")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  func test102_InputHandler_BasicSCPCTyping() throws {
    PrefMgr.shared.useSCPCTypingMode = true
    clearTestUOM()
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
    PrefMgr.shared.useSCPCTypingMode = false
    PrefMgr.shared.useRearCursorMode = false
    clearTestUOM()

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

  /// 測試藉由選字窗選字、且同時測試半衰記憶模組在此情況下的記憶資料生成與適用情況。
  /// - Remark: 這裡順便測試一下「在選字窗選字後自動推進游標」這個有被預設啟用的功能。
  func test104_InputHandler_ManualCandidateSelectionAndUOM() throws {
    PrefMgr.shared.useSCPCTypingMode = false
    PrefMgr.shared.useRearCursorMode = false
    PrefMgr.shared.moveCursorAfterSelectingCandidate = true
    clearTestUOM()

    var sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates(sequenceChars)

    // Testing Manual Candidate Selection, UOM Observation, and Post-Candidate-Selection Cursor Jumping.

    vCTestLog("測試選字窗選字：高科技公司的年終獎金 -> 高科技公司的年中獎金")
    let keyOne = NSEvent.KeyEventData(chars: "1")
    [dataArrowDown, keyOne].map(\.asPairedEvents).flatMap { $0 }.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
    let resultText3 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText3)")
    XCTAssertEqual(resultText3, "高科技公司的年中獎金")
    XCTAssertEqual(testHandler.compositor.cursor, 10)

    // Continuing UOM Tests (in the Current Context).

    vCTestLog("測試半衰記憶的適用範圍：「年終」的記憶應僅對下述給定上下文情形生效。")
    vCTestLog("- 該給定上下文情形為「((ㄍㄨㄥ-ㄙ,公司),(ㄉㄜ˙,的),ㄋㄧㄢˊ-ㄓㄨㄥ)」。")
    clearTestUOM()
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

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  func test105_InputHandler_MiscCommissionTest() throws {
    PrefMgr.shared.useSCPCTypingMode = false
    clearTestUOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("el dk ru4ej/ n 2k7")
    guard let handler = testSession.inputHandler as? InputHandler else {
      XCTAssertThrowsError("testSession.handler is nil.")
      return
    }
    PrefMgr.shared.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    XCTAssertEqual(result, "ㄍㄠ ㄎㄜ ㄐㄧˋ ㄍㄨㄥ ㄙ ˙ㄉㄜ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    XCTAssertEqual(result, "高(ㄍㄠ)科(ㄎㄜ)技(ㄐㄧˋ)公(ㄍㄨㄥ)司(ㄙ)的(˙ㄉㄜ)")
    PrefMgr.shared.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>高<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby><ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>公<rp>(</rp><rt>ㄍㄨㄥ</rt><rp>)</rp></ruby><ruby>司<rp>(</rp><rt>ㄙ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>
    """
    XCTAssertEqual(result, expectedRubyResult)
    PrefMgr.shared.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠅⠩⠄⠇⠮⠄⠅⠡⠐⠅⠯⠄⠑⠄⠙⠮⠁")
    PrefMgr.shared.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠛⠖⠁⠅⠢⠁⠛⠊⠆⠛⠲⠁⠎⠁⠙⠢")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }
}
