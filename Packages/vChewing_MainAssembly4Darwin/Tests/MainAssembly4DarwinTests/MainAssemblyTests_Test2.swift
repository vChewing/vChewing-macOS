// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import Megrez
import MegrezTestComponents
import OSFrameworkImpl
import Testing

@testable import LangModelAssembly
@testable import MainAssembly4Darwin
@testable import Typewriter

// 本文的單元測試用例從 201 起算。

extension MainAssemblyTests {
  @Test
  func test201_InputHandler_HomeEndAndClockKeys() throws {
    let originalText = prepareBasicComposition(sequence: "dk ru4204el ")
    #expect(!(originalText.isEmpty))

    let originalLength = testHandler.assembler.length
    let originalNodes = testHandler.assembler.assembledSentence.values
    #expect(testHandler.assembler.cursor == originalLength)

    _ = press(homeEvent)
    #expect(testHandler.assembler.cursor == 0)
    #expect(testHandler.assembler.assembledSentence.values == originalNodes)
    let homeState = testHandler.generateStateOfInputting()
    #expect(homeState.cursor == 0)
    #expect(homeState.displayedText == originalText)
    testSession.switchState(homeState)

    _ = press(endEvent)
    #expect(testHandler.assembler.cursor == originalLength)
    #expect(testHandler.assembler.assembledSentence.values == originalNodes)
    let endState = testHandler.generateStateOfInputting()
    #expect(endState.cursor == testHandler.convertCursorForDisplay(originalLength))
    #expect(endState.displayedText == originalText)
    testSession.switchState(endState)

    testSession.isVerticalTyping = false
    let cursorAfterEnd = testHandler.assembler.cursor
    let clockHorizontal = NSEvent.KeyEventData(
      chars: NSEvent.SpecialKey.upArrow.unicodeScalar.description,
      keyCode: KeyCode.kUpArrow.rawValue
    )
    _ = press(clockHorizontal)
    #expect(testHandler.assembler.cursor == cursorAfterEnd)
    let horizontalState = testHandler.generateStateOfInputting()
    #expect(horizontalState.cursor == endState.cursor)
    #expect(horizontalState.displayedText == originalText)
    testSession.switchState(horizontalState)

    testSession.isVerticalTyping = true
    let clockVertical = NSEvent.KeyEventData(
      chars: NSEvent.SpecialKey.rightArrow.unicodeScalar.description,
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

  @Test
  func test202_InputHandler_EscapeBehaviorVariants() throws {
    testHandler.prefs.escToCleanInputBuffer = true
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(escEvent)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.assembler.length == 0)
    #expect(testClient.toString().isEmpty)
    #expect(
      testSession.state.type == .ofAbortion || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.escToCleanInputBuffer = false
    let visibleBeforeEsc = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(escEvent)
    #expect(testClient.toString() == visibleBeforeEsc)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.assembler.length == 0)
    #expect(
      testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting
    )
    testClient.clear()

    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    typeSentenceOrCandidates("el")
    #expect(!(testHandler.isComposerOrCalligrapherEmpty))
    _ = press(escEvent)
    #expect(
      testSession.state.type == .ofAbortion || testSession.state.type == .ofEmpty
    )
    #expect(testHandler.isComposerOrCalligrapherEmpty)
    #expect(testHandler.currentTypingMethod == .vChewingFactory)
  }

  @Test
  func test203_InputHandler_BackspaceAndDeleteBranches() throws {
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    var nodesBeforeOptionBackspace = testHandler.assembler.assembledSentence.values
    _ = press(optionBackspaceEvent)
    let nodesAfterOptionBackspace = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterOptionBackspace.count == max(nodesBeforeOptionBackspace.count - 1, 0))
    var normalizedState = testHandler.generateStateOfInputting()
    #expect(testSession.state.type == normalizedState.type)
    #expect(testSession.state.displayedText == normalizedState.displayedText)

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    let stateBeforeBackspace = testHandler.generateStateOfInputting()
    _ = handleKeyEvent(backspaceEvent)
    normalizedState = testHandler.generateStateOfInputting()
    #expect(normalizedState.displayedText.count < stateBeforeBackspace.displayedText.count)

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testHandler.prefs.specifyShiftBackSpaceKeyBehavior = 1
    _ = press(shiftBackspaceEvent)
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
    _ = press(forwardDeleteEvent)
    normalizedState = testHandler.generateStateOfInputting()
    #expect(
      normalizedState.displayedText.count <
        stateBeforeForwardDelete.displayedText.count
    )

    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testHandler.assembler.cursor = 0
    testSession.switchState(testHandler.generateStateOfInputting())
    nodesBeforeOptionBackspace = testHandler.assembler.assembledSentence.values
    _ = press(optionForwardDeleteEvent)
    let nodesAfterOptionForward = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterOptionForward.count == max(nodesBeforeOptionBackspace.count - 1, 0))
    normalizedState = testHandler.generateStateOfInputting()
    #expect(testSession.state.displayedText == normalizedState.displayedText)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    press(symbolMenuKeyEventIntlWithOpt)
    #expect(testHandler.currentTypingMethod == .codePoint)

    typeSentenceOrCandidates("1A2")
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A2")

    _ = press(optionBackspaceEvent)
    #expect(testHandler.currentTypingMethod == .codePoint)
    #expect(testHandler.strCodePointBuffer == "")

    testSession.switchState(testHandler.generateStateOfInputting(guarded: true))
    typeSentenceOrCandidates("1A2")
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A2")

    _ = press(backspaceEvent)
    #expect(testHandler.strCodePointBuffer.uppercased() == "1A")
    #expect(testHandler.currentTypingMethod == .codePoint)

    _ = press(backspaceEvent)
    #expect(testHandler.strCodePointBuffer == "1")
    #expect(testHandler.currentTypingMethod == .codePoint)

    _ = press(backspaceEvent)
    #expect(testHandler.strCodePointBuffer == "")
    #expect(testHandler.currentTypingMethod == .vChewingFactory)
  }

  @Test
  func test204_SwitchStateEmptyCommitsComposition() throws {
    let prepared = prepareBasicComposition(sequence: "dk ru4204el ")
    #expect(!(prepared.isEmpty))

    let bufferedState = testSession.state
    #expect(bufferedState.type == .ofInputting)

    testClient.clear()
    testSession.switchState(.ofEmpty())

    #expect(testClient.toString() == bufferedState.displayedText)
    #expect(testSession.state.type == .ofEmpty)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
  }

  @Test
  func test205_InputHandler_PunctuationFeaturesAndSymbolMenus() throws {
    testHandler.prefs.useSCPCTypingMode = false

    let shiftPeriodEvent = NSEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: ">",
      charsSansModifiers: ".",
      keyCode: mapKeyCodesANSIForTests["."] ?? 47
    )

    resetToEmptyAndClear()
    testHandler.prefs.halfWidthPunctuationEnabled = false
    _ = press(shiftPeriodEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "。")
    testSession.switchState(.ofAbortion())

    resetToEmptyAndClear()
    testHandler.prefs.halfWidthPunctuationEnabled = true
    _ = press(shiftPeriodEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == ".")
    testSession.switchState(.ofAbortion())

    // 測試普通符號選單。
    resetToEmptyAndClear()
    testHandler.prefs.halfWidthPunctuationEnabled = false
    var symbolMenuEvent = symbolMenuKeyEventIntlWithOpt
    symbolMenuEvent.flags = []
    _ = press(symbolMenuEvent)
    #expect(testSession.state.type == .ofSymbolTable)
    testSession.switchState(.ofAbortion())

    // 測試漢音符號選單（Hanin Symbols）。注意測資裡面僅包含開頭幾個符號。
    resetToEmptyAndClear()
    symbolMenuEvent.flags = [.option, .shift]
    _ = press(symbolMenuEvent)
    #expect(testSession.state.type == .ofCandidates)
    #expect(!(testSession.state.candidates.isEmpty))
    #expect(testSession.state.candidates[1].value == "，")
    testSession.switchState(.ofAbortion())
  }

  @Test
  func test206_InputHandler_OptionNumberCommit() throws {
    testSession.switchState(.ofEmpty())
    testClient.clear()

    let optionOneEvent = NSEvent.KeyEventData(
      type: .keyDown,
      flags: .option,
      chars: "1",
      charsSansModifiers: "1",
      keyCode: mapKeyCodesANSIForTests["1"] ?? 18
    )
    _ = press(optionOneEvent)
    #expect(testClient.toString() == "1".applyingTransformFW2HW(reverse: false))
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClient.clear()

    testSession.switchState(.ofEmpty())
    testClient.clear()
    testHandler.prefs.halfWidthPunctuationEnabled = false
    let optionShiftTwoEvent = NSEvent.KeyEventData(
      type: .keyDown,
      flags: [.option, .shift],
      chars: "2",
      charsSansModifiers: "2",
      keyCode: mapKeyCodesANSIForTests["2"] ?? 19
    )
    _ = handleKeyEvent(optionShiftTwoEvent)
    #expect(testClient.toString() == "2".applyingTransformFW2HW(reverse: true))
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClient.clear()

    testSession.switchState(.ofEmpty())
    testClient.clear()
    testHandler.prefs.halfWidthPunctuationEnabled = true
    _ = press(optionShiftTwoEvent)
    #expect(testClient.toString() == "2".applyingTransformFW2HW(reverse: false))
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
  }

  @Test
  func test207_InputHandler_NumPadBehaviors() throws {
    testHandler.prefs.useSCPCTypingMode = false

    let keypadSeven = NSEvent.KeyEventData(
      type: .keyDown,
      flags: .numericPad,
      chars: "7",
      charsSansModifiers: "7",
      keyCode: 89
    )

    testHandler.prefs.numPadCharInputBehavior = 0
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testClient.toString() == "7")
    #expect(
      testSession.state.type == .ofCommitting || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.numPadCharInputBehavior = 1
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testClient.toString() == "7".applyingTransformFW2HW(reverse: true))
    #expect(
      testSession.state.type == .ofCommitting || testSession.state.type == .ofEmpty
    )

    testHandler.prefs.numPadCharInputBehavior = 2
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testSession.state.type == .ofInputting)
    #expect(testClient.toString().isEmpty)
    #expect(testSession.state.displayedText == "7")
    testSession.switchState(.ofAbortion())

    testHandler.prefs.numPadCharInputBehavior = 3
    resetToEmptyAndClear()
    _ = press(keypadSeven)
    #expect(testSession.state.type == .ofInputting)
    #expect(testClient.toString().isEmpty)
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

  @Test
  func test208_InputHandler_ShiftLetterKeyPreferences() throws {
    let shiftAEvent = NSEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: "A",
      charsSansModifiers: "A",
      keyCode: mapKeyCodesANSIForTests["a"] ?? 0
    )

    testHandler.prefs.upperCaseLetterKeyBehavior = 1
    let baseline1 = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(shiftAEvent)
    #expect(testClient.toString() == baseline1 + "a")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClient.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 2
    let baseline2 = prepareBasicComposition(sequence: "dk ru4204el ")
    _ = press(shiftAEvent)
    #expect(testClient.toString() == baseline2 + "A")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClient.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 3
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    _ = press(shiftAEvent)
    #expect(testClient.toString() == "a")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testClient.clear()

    testSession.switchState(.ofAbortion())
    testHandler.prefs.upperCaseLetterKeyBehavior = 4
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    _ = press(shiftAEvent)
    #expect(testClient.toString() == "A")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
  }

  @Test
  func test209_InputHandler_CandidateWindowExtendedOperations() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.chooseCandidateUsingSpace = false
    testHandler.prefs.specifyShiftTabKeyBehavior = false
    testHandler.prefs.specifyShiftSpaceKeyBehavior = false
    testHandler.prefs.dodgeInvalidEdgeCandidateCursorPosition = false

    testSession.clientBundleIdentifier = "org.atelierInmu.vChewing.MainAssembly.UnitTests"

    /// 「幽蝶能留一縷芳」的大千注音序列，無刻意字詞選擇操作。
    let sampleKeySequence = "u. 2u,6s/6xu.6u4xm3z; "

    // Candidate cancellation via Backspace.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: backspaceEvent)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Candidate cancellation via Escape.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: escapeEvent)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Candidate cancellation via Forward Delete.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: deleteForwardEvent)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Shift+Left cancels candidates then transitions into marking state.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: Swift.max(testHandler.assembler.length - 1, 1)) != nil {
      press(shiftLeftEvent)
      #expect(testSession.state.type == .ofMarking)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Option+Right moves cursor by segment while staying in candidate state.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: 1) != nil {
      let cursorBefore = testHandler.assembler.cursor
      press(optionRightEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(testHandler.assembler.cursor > cursorBefore)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Option+Shift+Right performs stepwise cursor advance.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: 1) != nil {
      let cursorBefore = testHandler.assembler.cursor
      press(optionShiftRightEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(testHandler.assembler.cursor == cursorBefore + 1)
    }
    testSession.switchState(.ofAbortion())
    testClient.clear()

    // Option+Command shortcuts trigger context menu actions (nerf & boost).
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      var repositionAttempts = 0
      while repositionAttempts < testHandler.assembler.assembledSentence.count {
        let hasEligibleCandidate = testSession.state.candidates.contains { pair in
          pair.value.count >= 2 && pair.keyArray.joined().count >= 2
        }
        if hasEligibleCandidate { break }
        press(optionLeftEvent)
        repositionAttempts += 1
      }

      // Highlight an eligible candidate (length >= 2 for both value and reading keys).
      highlightEligibleCandidate()

      press(optionCommandMinusEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(!(testSession.state.tooltip.isEmpty))
      #expect(testSession.state.data.tooltipColorState == .succeeded)

      // Refresh candidates after nerfing for the boost path.
      let refreshedState = testHandler.generateStateOfCandidates(dodge: false)
      testSession.switchState(refreshedState)
      testSession.toggleCandidateUIVisibility(true)
      highlightEligibleCandidate()

      press(optionCommandEqualEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(!(testSession.state.tooltip.isEmpty))
      #expect(testSession.state.data.tooltipColorState == .normal)
      #expect(testSession.state.data.tooltipColorState != .redAlert)
    }
  }

  @Test
  func test210_InputHandler_ServiceMenuInitiation() throws {
    prepareBasicComposition(sequence: "dk ru4204el ") // 科技蛋糕
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "科技蛋糕")
    #expect(testHandler.assembler.isCursorAtEdge(direction: .front))
    press(dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.first?.value == "蛋糕")
    press(symbolMenuKeyEventIntlWithOpt)
    #expect(testSession.state.type == .ofSymbolTable)
    #expect(testSession.state.candidates.first?.value.prefix(16) == "Unicode Metadata")
    // 該測試到此為止，僅確保服務選單能正常顯示即可。原因：無法就單元測試做剪貼簿沙箱處理。
  }

  @Test
  func test211_InputHandler_CallCandidateStateTriggers() throws {
    testHandler.prefs.chooseCandidateUsingSpace = true
    testHandler.prefs.specifyShiftTabKeyBehavior = true

    func verifyCandidateCall(with eventData: NSEvent.KeyEventData) {
      _ = prepareBasicComposition(sequence: "dk ru4204el ")
      _ = press(eventData)
      #expect(testSession.state.type == .ofCandidates)
      #expect(!(testSession.state.candidates.isEmpty))
      testSession.switchState(.ofAbortion())
    }
    verifyCandidateCall(with: spaceEvent)
    verifyCandidateCall(with: pageDownEvent)
    verifyCandidateCall(with: tabEvent)
  }

  @Test
  func test212_InputHandler_CandidatePreviewUpdates() throws {
    prepareBasicComposition(sequence: "dk ru4") // 科技
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "科技")
    #expect(testHandler.assembler.isCursorAtEdge(direction: .front))
    press(dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.displayedText == "科技")
    // 在選字窗內預設情況下用 Tab 會高亮選擇下一個候選字詞。
    #expect(press(tabEvent))
    #expect(testSession.state.displayedText == "科際") // 生效了。
  }

  @Test
  func test213_InputHandler_DodgeInvalidEdgeCursor() throws {
    testHandler.prefs.useRearCursorMode = true
    prepareBasicComposition(sequence: "dk ru4") // 科技
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "科技")
    #expect(testHandler.assembler.isCursorAtEdge(direction: .front))
    let cursorPriorToCandidateWindowCall = testSession.state.cursor
    press(dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    let cursorFollowingCandidateWindowCall = testSession.state.cursor
    #expect(cursorPriorToCandidateWindowCall != cursorFollowingCandidateWindowCall)
  }

  /// 測試在啟用逐字選字模式下的關聯詞語功能。
  @Test
  func test214_InputHandler_AssociatedPhraseTriggers_SCPC() throws {
    // 該測試已針對倚天中文DOS鍵盤排序更新過內容。
    testHandler.currentLM.injectTestData(
      associates: { lmAssociatesObj in
        lmAssociatesObj.replaceData(textData: "芳 苑 鄰 香 心 齡 訊 草 華 蹤 魂 名錄 名\n")
      }
    )
    testHandler.prefs.useSCPCTypingMode = true
    testHandler.prefs.associatedPhrasesEnabled = true
    #expect(!testHandler.currentLM.lmAssociates.strData.isEmpty)
    typeSentenceOrCandidates("z; ")
    #expect(testSession.state.candidates[1].value == "芳")
    typeSentenceOrCandidates("2")
    #expect(testClient.toString() == "芳")
    print(testSession.state.candidates)
    #expect(testSession.state.type == .ofAssociates)
    let shiftPlus3 = NSEvent.KeyEventData(
      flags: .shift,
      chars: "#",
      charsSansModifiers: "3",
      keyCode: 20
    )
    handleEvents(shiftPlus3.asPairedEvents)
    #expect(testClient.toString() == "芳香")
  }

  /// 測試在不啟用逐字選字模式下的關聯詞語功能。
  @Test
  func test215_InputHandler_AssociatedPhraseTriggers_NonSCPC() throws {
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.currentLM.injectTestData(
      associates: { lmAssociatesObj in
        lmAssociatesObj.replaceData(textData: "芳 苑 鄰 香 心 齡 訊 草 華 蹤 魂 名錄 名\n")
      }
    )
    testHandler.prefs.associatedPhrasesEnabled = true
    #expect(!testHandler.currentLM.lmAssociates.strData.isEmpty)
    typeSentenceOrCandidates("z; ") // 用 Revolver API 定位到「芳」。
    handleEvents([tabEvent, tabEvent, tabEvent].map { $0.asPairedEvents }.flatMap { $0 })
    #expect(testSession.state.displayedText == "芳")
    handleEvents(shiftEnterEvent.asPairedEvents)
    #expect(testClient.toString() == "芳")
    print(testSession.state.candidates)
    #expect(testSession.state.type == .ofAssociates)
    let shiftPlus3 = NSEvent.KeyEventData(
      flags: .shift,
      chars: "#",
      charsSansModifiers: "3",
      keyCode: 20
    )
    handleEvents(shiftPlus3.asPairedEvents)
    #expect(testClient.toString() == "芳香")
  }
}
