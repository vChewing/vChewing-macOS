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

// MARK: - 測試案例 Vol 2 (Candidates with POM Interactions)

extension InputHandlerTests {
  /// 測試就地輪替候選字。
  func test_IH201_RevolvingCandidates() throws {
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
  func test_IH202_ManualCandidateSelectionAndPOM() throws {
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

    // 測試手動候選選取、POM 觀察以及選字後游標恢復行為。

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

    // 繼續在目前上下文中測試 POM 相關功能。

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
  func test_IH203_PostCandidateCursorPlacementRestore() throws {
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
}
