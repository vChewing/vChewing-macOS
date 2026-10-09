// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import SwiftExtension
import Tekkon
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard

// 事件分診：方向鍵／時鐘鍵、Esc、退格與刪除、小鍵盤、Shift 字母鍵、候選狀態呼叫。

// MARK: - SS.EventTriage

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  @Test("SS-EventTriage-001 Home/End and clock keys")
  func test_SS_EventTriage_001_HomeEndAndClockKeys() throws {
    let originalText = prepareBasicComposition(sequence: "dk ru4204el ")
    #expect(!(originalText.isEmpty))

    let originalLength = testHandler.assembler.length
    let originalNodes = testHandler.assembler.assembledSentence.values
    #expect(testHandler.assembler.cursor == originalLength)

    _ = press(.homeEvent)
    #expect(testHandler.assembler.cursor == 0)
    #expect(testHandler.assembler.assembledSentence.values == originalNodes)
    let homeState = testHandler.generateStateOfInputting()
    #expect(homeState.cursor == 0)
    #expect(homeState.displayedText == originalText)
    testSession.switchState(homeState)

    _ = press(.endEvent)
    #expect(testHandler.assembler.cursor == originalLength)
    #expect(testHandler.assembler.assembledSentence.values == originalNodes)
    let endState = testHandler.generateStateOfInputting()
    #expect(endState.cursor == testHandler.convertCursorForDisplay(originalLength))
    #expect(endState.displayedText == originalText)
    testSession.switchState(endState)

    testSession.isVerticalTyping = false
    let cursorAfterEnd = testHandler.assembler.cursor
    let clockHorizontal = KBEvent.KeyEventData(
      chars: KBEvent.SpecialKey.upArrow.unicodeScalar.description,
      keyCode: KeyCode.kUpArrow.rawValue
    )
    _ = press(clockHorizontal)
    #expect(testHandler.assembler.cursor == cursorAfterEnd)
    let horizontalState = testHandler.generateStateOfInputting()
    #expect(horizontalState.cursor == endState.cursor)
    #expect(horizontalState.displayedText == originalText)
    testSession.switchState(horizontalState)

    testSession.isVerticalTyping = true
    let clockVertical = KBEvent.KeyEventData(
      chars: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
      keyCode: KeyCode.kRightArrow.rawValue
    )
    _ = press(clockVertical)
    #expect(testHandler.assembler.cursor == cursorAfterEnd)
    let verticalState = testHandler.generateStateOfInputting()
    #expect(verticalState.cursor == endState.cursor)
    #expect(verticalState.displayedText == originalText)
    testSession.switchState(verticalState)
    testSession.isVerticalTyping = false
  }

  @Test("SS-EventTriage-002 Escape behavior variants")
  func test_SS_EventTriage_002_EscapeBehaviorVariants() throws {
    testHandler.prefs.escToCleanInputBuffer = true
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(.escEvent)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.assembler.length == 0)
    #expect(testClientProxy.toString().isEmpty)
    #expect(
      testSession.state.type == .ofAbortion || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.escToCleanInputBuffer = false
    let visibleBeforeEsc = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(.escEvent)
    #expect(testClientProxy.toString() == visibleBeforeEsc)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.assembler.length == 0)
    #expect(
      testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting
    )
    testClientProxy.clear()

    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    typeSentenceOrCandidates("el")
    #expect(!(testHandler.isComposerOrCalligrapherEmpty))
    _ = press(.escEvent)
    #expect(
      testSession.state.type == .ofAbortion || testSession.state.type == .ofEmpty
    )
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.currentTypingMethod == .vChewingFactory)
  }

  @Test("SS-EventTriage-003 Backspace and Delete branches")
  func test_SS_EventTriage_003_BackspaceAndDeleteBranches() throws {
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    var nodesBeforeOptionBackspace = testHandler.assembler.assembledSentence.values
    _ = press(.optionBackspaceEvent)
    let nodesAfterOptionBackspace = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterOptionBackspace.count == max(nodesBeforeOptionBackspace.count - 1, 0))
    var normalizedState = testHandler.generateStateOfInputting()
    #expect(testSession.state.type == normalizedState.type)
    #expect(testSession.state.displayedText == normalizedState.displayedText)

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    let stateBeforeBackspace = testHandler.generateStateOfInputting()
    _ = handleKeyEvent(.backspaceEvent)
    normalizedState = testHandler.generateStateOfInputting()
    #expect(normalizedState.displayedText.count < stateBeforeBackspace.displayedText.count)

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testHandler.prefs.specifyShiftBackSpaceKeyBehavior = 1
    _ = press(.shiftBackspaceEvent)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.assembler.length == 0)
    #expect(
      testSession.state.type == .ofAbortion || testSession.state.type == .ofEmpty
    )
    testHandler.prefs.specifyShiftBackSpaceKeyBehavior = 0 // Default value.

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testHandler.assembler.cursor = 0
    testSession.switchState(testHandler.generateStateOfInputting())
    let stateBeforeForwardDelete = testHandler.generateStateOfInputting()
    _ = press(.deleteForwardEvent)
    normalizedState = testHandler.generateStateOfInputting()
    #expect(
      normalizedState.displayedText.count <
        stateBeforeForwardDelete.displayedText.count
    )

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testHandler.assembler.cursor = 0
    testSession.switchState(testHandler.generateStateOfInputting())
    nodesBeforeOptionBackspace = testHandler.assembler.assembledSentence.values
    _ = press(.optionForwardDeleteEvent)
    let nodesAfterOptionForward = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterOptionForward.count == max(nodesBeforeOptionBackspace.count - 1, 0))
    normalizedState = testHandler.generateStateOfInputting()
    #expect(testSession.state.displayedText == normalizedState.displayedText)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    press(.symbolMenuKeyEventIntlWithOpt)
    #expect(testHandler.currentTypingMethod == .codePoint)

    typeSentenceOrCandidates("1A2")
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A2")

    _ = press(.optionBackspaceEvent)
    #expect(testHandler.currentTypingMethod == .codePoint)
    #expect(testHandler.strCodePointBuffer == "")

    testSession.switchState(testHandler.generateStateOfInputting(guarded: true))
    typeSentenceOrCandidates("1A2")
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A2")

    _ = press(.backspaceEvent)
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A")
    #expect(testHandler.currentTypingMethod == .codePoint)

    _ = press(.backspaceEvent)
    #expect(testHandler.strCodePointBuffer == "1")
    #expect(testHandler.currentTypingMethod == .codePoint)

    _ = press(.backspaceEvent)
    #expect(testHandler.strCodePointBuffer == "")
    #expect(testHandler.currentTypingMethod == .vChewingFactory)
  }

  @Test("SS-EventTriage-004 NumPad behaviors")
  func test_SS_EventTriage_004_NumPadBehaviors() throws {
    testHandler.prefs.useSCPCTypingMode = false

    let keypadSeven = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .numericPad,
      chars: "7",
      charsSansModifiers: "7",
      keyCode: 89
    )

    testHandler.prefs.numPadCharInputBehavior = 0
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testClientProxy.toString() == "7")
    #expect(
      testSession.state.type == .ofCommitting || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.numPadCharInputBehavior = 1
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testClientProxy.toString() == "7".applyingTransformFW2HW(reverse: true))
    #expect(
      testSession.state.type == .ofCommitting || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.numPadCharInputBehavior = 2
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testSession.state.type == .ofInputting)
    #expect(testClientProxy.toString().isEmpty)
    #expect(testSession.state.displayedText == "7")
    testSession.switchState(.ofAbortion())

    testHandler.prefs.numPadCharInputBehavior = 3
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testSession.state.type == .ofInputting)
    #expect(testClientProxy.toString().isEmpty)
    #expect(testSession.state.displayedText == "7".applyingTransformFW2HW(reverse: true))
    testSession.switchState(.ofAbortion())

    testHandler.prefs.numPadCharInputBehavior = 4
    let baseline = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(keypadSeven)
    var updatedState = testHandler.generateStateOfInputting()
    #expect(updatedState.displayedText == baseline + "7")
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)

    testHandler.prefs.numPadCharInputBehavior = 5
    let baselineFull = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(keypadSeven)
    updatedState = testHandler.generateStateOfInputting()
    #expect(
      updatedState.displayedText ==
        baselineFull + "7".applyingTransformFW2HW(reverse: true)
    )
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)
  }

  @Test("SS-EventTriage-005 Shift letter key preferences")
  func test_SS_EventTriage_005_ShiftLetterKeyPreferences() throws {
    let shiftAEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: "A",
      charsSansModifiers: "A",
      keyCode: mapKeyCodesANSIForTests["a"] ?? 0
    )

    testHandler.prefs.upperCaseLetterKeyBehavior = 1
    let baseline1 = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(shiftAEvent)
    #expect(testClientProxy.toString() == baseline1 + "a")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClientProxy.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 2
    let baseline2 = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(shiftAEvent)
    #expect(testClientProxy.toString() == baseline2 + "A")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClientProxy.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 3
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    _ = press(shiftAEvent)
    #expect(testClientProxy.toString() == "a")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClientProxy.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 4
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClientProxy.clear()
    _ = press(shiftAEvent)
    #expect(testClientProxy.toString() == "A")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
  }

  @Test("SS-EventTriage-006 Call-candidate state triggers")
  func test_SS_EventTriage_006_CallCandidateStateTriggers() throws {
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 1
    testHandler.prefs.specifyShiftTabKeyBehavior = true

    func verifyCandidateCall(with eventData: KBEvent.KeyEventData) {
      _ = prepareBasicComposition(sequence: "dk ru4204el ")
      _ = press(eventData)
      #expect(testSession.state.type == .ofCandidates)
      #expect(!(testSession.state.candidates.isEmpty))
      testSession.switchState(.ofAbortion())
    }
    verifyCandidateCall(with: .spaceEvent)
    verifyCandidateCall(with: .pageDownEvent)
    verifyCandidateCall(with: .tabEvent)
  }

  @Test("SS-EventTriage-007 Dodge invalid edge cursor")
  func test_SS_EventTriage_007_DodgeInvalidEdgeCursor() throws {
    testHandler.prefs.useRearCursorMode = true
    prepareBasicComposition(sequence: "dk ru4") // 科技
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "科技")
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
    let cursorPriorToCandidateWindowCall = testSession.state.cursor
    press(.dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    let cursorFollowingCandidateWindowCall = testSession.state.cursor
    #expect(cursorPriorToCandidateWindowCall != cursorFollowingCandidateWindowCall)
  }

  @Test("SS-EventTriage-008 Revolver rare case: ji hu qi keng")
  func test_SS_EventTriage_008_RevolverRareCaseJiHuQiKeng() throws {
    let mockLX = TestLX(rawData: HomaTests.strLXSampleData_JiHuQiKeng)
    let originalQuerier = testHandler.assembler.gramQuerier
    let originalChecker = testHandler.assembler.gramAvailabilityChecker
    defer {
      testHandler.assembler.gramQuerier = originalQuerier
      testHandler.assembler.gramAvailabilityChecker = originalChecker
      testHandler.clear()
      testClientProxy.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.useRearCursorMode = false
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.assembler.gramQuerier = { mockLX.queryGrams($0) }
    testHandler.assembler.gramAvailabilityChecker = nil

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ji1") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("hu1") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("qi4") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("keng1") }
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["幾乎", "氣", "坑"])

    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(testSession.state.displayedText == "幾乎氣坑")
    #expect(press(.dataArrowLeft))
    #expect(testHandler.assembler.cursor == 3)
    #expect(testSession.state.displayedText == "幾乎氣坑")

    let allCandidates = testHandler.assembler.fetchCandidates(filter: .endAt).map(\.pair.value)
    #expect(allCandidates.prefix(4) == ["呼氣", "氣", "迄", "棄"])
    guard let firstCandidate = allCandidates.first, allCandidates.count > 1 else {
      Issue.record("JiHuQiKeng rare-case test requires at least two candidates.")
      return
    }

    let expectedCycle = allCandidates + [firstCandidate]
    for expectedValue in expectedCycle {
      #expect(press(.tabEvent))
      let expectedNodes: [String] = expectedValue == "呼氣" ? ["幾", expectedValue, "坑"] : ["幾", "呼", expectedValue, "坑"]
      #expect(testHandler.assembler.assembledSentence.map(\.value) == expectedNodes)
      #expect(testSession.state.displayedText == expectedNodes.joined())
    }
  }

  /// 驗證一般打字且輸入狀態為 empty 時，Shift+空白鍵之輸出寬度由偏好決定、且預設為全形。
  @Test("SS-EventTriage-009 Shift+Space empty state width")
  func test_SS_EventTriage_009_ShiftSpaceEmptyStateWidth() throws {
    let spaceEvent = KBEvent.KeyEventData(chars: " ", keyCode: KeyCode.kSpace.rawValue)
    let shiftSpaceEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: " ",
      keyCode: KeyCode.kSpace.rawValue
    )

    // 不帶 Shift 的空白鍵：恆為半形，不受偏好影響。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = true
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(spaceEvent)
    #expect(testClientProxy.toString() == " ")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    // 帶 Shift 的空白鍵：預設（偏好為 false）為全形。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = false
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(shiftSpaceEvent)
    #expect(testClientProxy.toString() == "　")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    // 帶 Shift 的空白鍵：偏好為 true 時改為半形。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = true
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(shiftSpaceEvent)
    #expect(testClientProxy.toString() == " ")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = false
  }
}
