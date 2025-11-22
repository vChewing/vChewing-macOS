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

  func test_IH204_DropKeyAgainstAnOverriddenCandidate() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
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
      XCTAssertEqual(
        testHandler.assembler.assembledSentence.values.joined(),
        "水果汁"
      ) // 確認我們獲得預期的組字結果
      if manualCandidateSelection {
        // 選取候選以標記節點為手動覆寫（固化）狀態
        testSession.switchState(testHandler.generateStateOfCandidates())
        testSession.candidatePairSelectionConfirmed(at: 0)
        // 基本一致性檢查
        XCTAssertEqual(testHandler.assembler.assembledSentence.values, ["水果汁"])
      }
    }

    // 案例 A1 (ForwardDelete)：從節點後側向前刪除一個讀音鍵（Forward Delete），預期結果："果汁"
    do {
      try restoreTestState()
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: forwardDelete))
      XCTAssertEqual(
        testHandler.assembler.assembledSentence.values.joined(),
        "果汁",
        "向前方刪除一個讀音鍵後仍應保留剩餘子鍵的使用者覆寫結果。"
      )
      // 大千鍵序對應「水」
      typeSentence("gjo3")
      // 下述斷言可證明「水果汁」並未被算法選中。
      XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.segLength), [1, 2])
      // 取消強制手動候選字選擇。
      try restoreTestState(manualCandidateSelection: false)
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: forwardDelete))
      XCTAssertEqual(testHandler.assembler.assembledSentence.values.joined(), "果汁")
      typeSentence("gjo3")
      // 下述斷言可證明「水果汁」被算法選中。
      XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.segLength), [3])
    }

    // 案例 A2 (BackSpace)：從節點前側向後刪除一個讀音鍵（BackSpace），預期結果："水果"
    do {
      try restoreTestState()
      // 將游標移到尾端，並按下 BackSpace 鍵以刪除最後一個字
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: backspace))
      XCTAssertEqual(
        testHandler.assembler.assembledSentence.values.joined(),
        "水果",
        "向後方刪除一個讀音鍵後仍應保留剩餘子鍵的使用者覆寫結果。"
      )
      typeSentence("5 ") // 大千鍵序對應「汁」，尾端有空白鍵
      XCTAssertNotEqual(testHandler.assembler.assembledSentence.values.joined(), "水果汁")
      XCTAssertEqual(testHandler.assembler.assembledSentence.values.joined(), "水果之")
      // 取消強制手動候選字選擇。
      try restoreTestState(manualCandidateSelection: false)
      XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .front))
      XCTAssertTrue(testHandler.triageInput(event: backspace))
      XCTAssertEqual(testHandler.assembler.assembledSentence.values.joined(), "水果")
      typeSentence("5 ") // 大千鍵序對應「汁」，尾端有空白鍵
      XCTAssertEqual(testHandler.assembler.assembledSentence.values.joined(), "水果汁")
      XCTAssertNotEqual(testHandler.assembler.assembledSentence.values.joined(), "水果之")
    }

    // 案例 B1 (ForwardDelete)：中間刪除（游標位於中間，前方刪除）→ 預期結果：「水|果汁」->「水汁」。
    // 中間刪除測試：將游標移至第二個位置（Home + RightArrow），執行前方刪除以移除第二個鍵。
    // 預期剩餘字元（第一與第三）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「果」後 -> 「水汁」。
    do {
      try restoreTestState()
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: forwardDelete))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少一個，且左側字仍為「水」；右側字為「汁」。
      XCTAssertEqual(result.count, 2)
      XCTAssertTrue(result.hasPrefix("水"))
      XCTAssertTrue(result.hasSuffix("汁"))
      XCTAssertTrue(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      XCTAssertTrue(
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
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: backspace))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少一個，且左側字仍為「水」；右側字為「汁」。
      XCTAssertEqual(result.count, 2)
      XCTAssertTrue(result.hasPrefix("水"))
      XCTAssertTrue(result.hasSuffix("汁"))
      XCTAssertTrue(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      XCTAssertTrue(
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
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowHome.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowRight.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: forwardDelete.reinitiate(modifierFlags: .option)))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少2個，且只剩「水」。
      XCTAssertEqual(result.count, 1)
      XCTAssertTrue(result.hasPrefix("水"))
      XCTAssertTrue(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄕㄨㄟˇ"],
          value: result.prefix(1).description
        )
      )
      XCTAssertEqual(
        testHandler.assembler.assembledSentence.values.joined(),
        "水",
        "在 `水|果汁` 的位置按 Option+Delete 後，應保留左側節點，結果為 '水'。"
      )
    }

    // 案例 C2 (Opt+Backspace)：中間刪除（游標位於中間，後方刪除）→ 預期結果：「水果|汁」->「汁」。
    // 中間刪除測試：將游標移至第二個位置的右側（End + LeftArrow），摁住 Option 執行後方刪除以移除第二個鍵。
    // 預期剩餘字元（第三）仍為使用者原先手動覆寫的字詞，例如：「水果汁」刪除「水果」後 -> 「汁」。
    do {
      try restoreTestState()
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowEnd.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowLeft.asEvent))
      XCTAssertTrue(testHandler.triageInput(event: backspace.reinitiate(modifierFlags: .option)))
      let result = testHandler.assembler.assembledSentence.values.joined()
      // 驗證：組字結果長度應減少2個，且只剩「汁」。
      XCTAssertEqual(result.count, 1)
      XCTAssertTrue(result.hasSuffix("汁"))
      XCTAssertTrue(
        testHandler.currentLM.hasKeyValuePairFor(
          keyArray: ["ㄓ"],
          value: result.suffix(1).description
        )
      )
      XCTAssertEqual(
        testHandler.assembler.assembledSentence.values.joined(),
        "汁",
        "在 `水果|汁` 的位置按 Option+Backspace 後，應保留右側節點，結果為 '汁'。"
      )
    }

    // 案例 D1 (Bksp, POM)：確保在重新打字沒有經過選字窗的確認的情況下的結果不受 POM 影響。
    do {
      clearTestPOM()
      XCTAssertTrue(testHandler.currentLM.lmPerceptionOverride.getSavableData().isEmpty)
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      try restoreTestState(manualCandidateSelection: true) // 生成 POM 記憶
      let pomDesc = testHandler.currentLM.lmPerceptionOverride.getSavableData()
      XCTAssertFalse(pomDesc.isEmpty)
      XCTAssertTrue(pomDesc.map(\.key).description.contains("ㄕㄨㄟˇ-ㄍㄨㄛˇ-ㄓ"))
      try restoreTestState(manualCandidateSelection: false)
      XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .front))
      XCTAssertTrue(testHandler.triageInput(event: backspace))
      typeSentence("5 ") // 「ㄓ」+ 陰平聲調
      XCTAssert(testHandler.assembler.assembledSentence.allSatisfy { !$0.isExplicit })
      XCTAssertNotEqual(testHandler.assembler.assembledSentence.map(\.value), ["水", "果汁"])
      XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["水果汁"])
    }
  }
}
