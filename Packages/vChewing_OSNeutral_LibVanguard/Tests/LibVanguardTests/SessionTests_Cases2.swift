// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import HomaSharedTestComponents
import Shared
import SwiftExtension
import Tekkon
import Testing

@testable import LexiconAssembly
@testable import LibVanguard

// MARK: - Session 層個案（編號沿用 MainAssembly 測試案）

/// 本檔將原本以 `NSEvent` 驅動真 `InputSession` 的個案，移植到跨平台的
/// `SessionTests` harness（真 `InputSession` + 真 `InputHandler` + `MockClientProxy`）。
/// 個案編號沿用原檔，方便與 `MainAssembly4Darwin` 的既有案例互相對照。
extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 在候選清單內高亮至一個「值至少 `minValueCount` 字、讀音鍵至少 `minKeyLength` 鍵」的候選。
  /// 供選字窗的降權／升權操作使用（這兩種操作僅對多字詞生效）。
  func highlightEligibleCandidate(minValueCount: Int = 2, minKeyLength: Int = 2) {
    guard let controller = testSession.candidateController() else {
      Issue.record("Missing candidate controller while searching eligible candidate.")
      return
    }
    var highlightedIndex = controller.highlightedIndex
    guard testSession.state.candidates.indices.contains(highlightedIndex) else {
      Issue.record("Highlighted index out of candidate range.")
      return
    }
    var highlightedCandidate = testSession.state.candidates[highlightedIndex]
    var attempts = 0
    while attempts < testSession.state.candidates.count,
          highlightedCandidate.value.count < minValueCount
          || highlightedCandidate.keyArray.joined().count < minKeyLength {
      highlightNextCandidate()
      guard let updated = testSession.candidateController() else {
        Issue.record("Candidate controller unexpectedly nil during iteration.")
        return
      }
      highlightedIndex = updated.highlightedIndex
      guard testSession.state.candidates.indices.contains(highlightedIndex) else { break }
      highlightedCandidate = testSession.state.candidates[highlightedIndex]
      attempts += 1
    }
    #expect(highlightedCandidate.value.count >= minValueCount)
    #expect(highlightedCandidate.keyArray.joined().count >= minKeyLength)
  }

  @Test
  func test201_InputHandler_HomeEndAndClockKeys() throws {
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

  @Test
  func test202_InputHandler_EscapeBehaviorVariants() throws {
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

  @Test
  func test203_InputHandler_BackspaceAndDeleteBranches() throws {
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

  @Test
  func test204_SwitchStateEmptyCommitsComposition() throws {
    let prepared = prepareBasicComposition(sequence: "dk ru4204el ")
    #expect(!(prepared.isEmpty))

    let bufferedState = testSession.state
    #expect(bufferedState.type == .ofInputting)

    testClientProxy.clear()
    testSession.switchState(.ofEmpty())

    #expect(testClientProxy.toString() == bufferedState.displayedText)
    #expect(testSession.state.type == .ofEmpty)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
  }

  @Test
  func test204A_SwitchStateEmptyCommitsRawTextWithoutBPMFVSLeak() throws {
    let grams: [Homa.Gram] = [
      .init(keyArray: ["ㄗㄚˊ"], value: "咱", score: -1),
      .init(keyArray: ["ㄉㄜ˙"], value: "地", score: -1),
    ]
    grams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testClientProxy.clear()
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
    #expect(testSession.state.displayedText == "咱\(vs1)地\(vs1)")

    testClientProxy.clear()
    testSession.switchState(.ofEmpty())

    #expect(testClientProxy.toString() == "咱地")
    #expect(testSession.state.type == .ofEmpty)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
  }

  @Test
  func test204B_SCPCSelectionCommitsRawTextWithoutBPMFVSLeak() throws {
    let grams: [Homa.Gram] = [
      .init(keyArray: ["ㄗㄚˊ"], value: "咱", score: -1),
    ]
    grams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testClientProxy.clear()
    }

    clearTestPOM()
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.useSCPCTypingMode = true
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 4
    testHandler.prefs.reflectBPMFVSInCompositionBuffer = true
    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    testSession.switchState(testHandler.generateStateOfCandidates())

    guard let targetIndex = testSession.state.candidates.firstIndex(where: { $0.value == "咱" }) else {
      Issue.record("Missing target candidate: 咱")
      return
    }

    testClientProxy.clear()
    testSession.candidatePairSelectionConfirmed(at: targetIndex)

    #expect(testClientProxy.toString() == "咱")
    #expect(testSession.state.type == .ofEmpty)
    #expect(testHandler.isComposerOrCalligrapherEmpty)
  }

  @Test
  func test205_InputHandler_PunctuationFeaturesAndSymbolMenus() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue

    let shiftCommaEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: "<",
      charsSansModifiers: ",",
      keyCode: mapKeyCodesANSIForTests[","] ?? 43
    )

    let shiftPeriodEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: ">",
      charsSansModifiers: ".",
      keyCode: mapKeyCodesANSIForTests["."] ?? 47
    )

    resetToEmptyAndClear()
    testHandler.prefs.halfWidthPunctuationEnabled = false
    _ = press(shiftCommaEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "，")
    let commaCandidates = testHandler.generateStateOfCandidates()
    let commaValues = commaCandidates.candidates.map(\.value)
    let commaIndex = try #require(commaValues.firstIndex(of: "，"))
    let angleIndex = try #require(commaValues.firstIndex(of: "〈"))
    #expect(commaIndex < angleIndex)
    testSession.switchState(.ofAbortion())

    resetToEmptyAndClear()
    testHandler.prefs.halfWidthPunctuationEnabled = false
    _ = press(shiftPeriodEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "。")
    let punctuationCandidates = testHandler.generateStateOfCandidates()
    let punctuationValues = punctuationCandidates.candidates.map(\.value)
    let fullWidthIndex = try #require(punctuationValues.firstIndex(of: "。"))
    let halfWidthIndex = try #require(punctuationValues.firstIndex(of: "."))
    #expect(fullWidthIndex < halfWidthIndex)
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
    var symbolMenuEvent = KBEvent.KeyEventData.symbolMenuKeyEventIntlWithOpt
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
  func test207_InputHandler_NumPadBehaviors() throws {
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

  @Test
  func test208_InputHandler_ShiftLetterKeyPreferences() throws {
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

  @Test
  func test209_InputHandler_CandidateWindowExtendedOperations() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.spaceKeyBehaviorAgainstICB = 0
    testHandler.prefs.specifyShiftTabKeyBehavior = false
    testHandler.prefs.specifyShiftSpaceKeyBehavior4CandidateWindow = false
    testHandler.prefs.dodgeInvalidEdgeCandidateCursorPosition = false

    testSession.clientBundleIdentifier = "org.atelierInmu.vChewing.MainAssembly.UnitTests"

    /// 「幽蝶能留一縷芳」的大千注音序列，無刻意字詞選擇操作。
    let sampleKeySequence = "u. 2u,6s/6xu.6u4xm3z; "

    // Candidate cancellation via Backspace.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: .backspaceEvent)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Candidate cancellation via Escape.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: .escapeEvent)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Candidate cancellation via Forward Delete.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      cancelCandidateWindowState(with: .deleteForwardEvent)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Shift+Left cancels candidates then transitions into marking state.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: Swift.max(testHandler.assembler.length - 1, 1)) != nil {
      press(.shiftLeftEvent)
      #expect(testSession.state.type == .ofMarking)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Option+Right moves cursor by segment while staying in candidate state.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: 1) != nil {
      let cursorBefore = testHandler.assembler.cursor
      press(.optionRightEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(testHandler.assembler.cursor > cursorBefore)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Option+Shift+Right performs stepwise cursor advance.
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow(cursor: 1) != nil {
      let cursorBefore = testHandler.assembler.cursor
      press(.optionShiftRightEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(testHandler.assembler.cursor == cursorBefore + 1)
    }
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // Option+Command shortcuts trigger context menu actions (nerf & boost).
    _ = prepareBasicComposition(sequence: sampleKeySequence)
    if openCandidateWindow() != nil {
      var repositionAttempts = 0
      while repositionAttempts < testHandler.assembler.assembledSentence.count {
        let hasEligibleCandidate = testSession.state.candidates.contains { pair in
          pair.value.count >= 2 && pair.keyArray.joined().count >= 2
        }
        if hasEligibleCandidate { break }
        press(.optionLeftEvent)
        repositionAttempts += 1
      }

      // Highlight an eligible candidate (length >= 2 for both value and reading keys).
      highlightEligibleCandidate()

      press(.optionCommandMinusEvent)
      #expect(testSession.state.type == .ofCandidates)
      #expect(!(testSession.state.tooltip.isEmpty))
      #expect(testSession.state.data.tooltipColorState == .succeeded)

      // Refresh candidates after nerfing for the boost path.
      let refreshedState = testHandler.generateStateOfCandidates(dodge: false)
      testSession.switchState(refreshedState)
      testSession.toggleCandidateUIVisibility(true)
      highlightEligibleCandidate()

      press(.optionCommandEqualEvent)
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
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
    press(.dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.first?.value == "蛋糕")
    press(.symbolMenuKeyEventIntlWithOpt)
    #expect(testSession.state.type == .ofSymbolTable)
    #expect(testSession.state.candidates.first?.value.prefix(16) == "Unicode Metadata")
    // 該測試到此為止，僅確保服務選單能正常顯示即可。原因：無法就單元測試做剪貼簿沙箱處理。
  }

  @Test
  func test211_InputHandler_CallCandidateStateTriggers() throws {
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

  @Test
  func test212_InputHandler_CandidatePreviewUpdates() throws {
    prepareBasicComposition(sequence: "dk ru4") // 科技
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "科技")
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
    press(.dataArrowDown) // 叫出選字窗。
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.displayedText == "科技")
    // 模擬選字窗控制器需得知當前候選總數，其高亮導覽才有正確的邊界判定。
    syncCandidateControllerCount()
    // 在選字窗內預設情況下用 Tab 會高亮選擇下一個候選字詞。
    #expect(press(.tabEvent))
    #expect(testSession.state.displayedText == "科際") // 生效了。
  }

  @Test
  func test213_InputHandler_DodgeInvalidEdgeCursor() throws {
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

  /// 測試在啟用逐字選字模式下的關聯詞語功能。
  @Test
  func test214_InputHandler_AssociatedPhraseTriggers_SCPC() throws {
    // 該測試已針對倚天中文DOS鍵盤排序更新過內容。
    testHandler.currentLM.injectTestData(
      associates: { lxAssociatesObj in
        lxAssociatesObj.replaceData(textData: "芳 苑 鄰 香 心 齡 訊 草 華 蹤 魂 名錄 名\n")
      }
    )
    testHandler.prefs.useSCPCTypingMode = true
    testHandler.prefs.associatedPhrasesEnabled = true
    #expect(!testHandler.currentLM.lxAssociates.strData.isEmpty)
    typeSentenceOrCandidates("z; ")
    #expect(testSession.state.candidates[1].value == "芳")
    typeSentenceOrCandidates("2")
    #expect(testClientProxy.toString() == "芳")
    #expect(testSession.state.type == .ofAssociates)
    let shiftPlus3 = KBEvent.KeyEventData(
      flags: .shift,
      chars: "#",
      charsSansModifiers: "3",
      keyCode: 20
    )
    handleEvents(shiftPlus3.asPairedEvents)
    #expect(testClientProxy.toString() == "芳香")
  }

  /// 測試在不啟用逐字選字模式下的關聯詞語功能。
  @Test
  func test215_InputHandler_AssociatedPhraseTriggers_NonSCPC() throws {
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.currentLM.injectTestData(
      associates: { lxAssociatesObj in
        lxAssociatesObj.replaceData(textData: "芳 苑 鄰 香 心 齡 訊 草 華 蹤 魂 名錄 名\n")
      }
    )
    testHandler.prefs.associatedPhrasesEnabled = true
    #expect(!testHandler.currentLM.lxAssociates.strData.isEmpty)
    typeSentenceOrCandidates("z; ") // 用 Revolver API 定位到「芳」。
    let tabTrio: [KBEvent.KeyEventData] = [.tabEvent, .tabEvent, .tabEvent]
    handleEvents(tabTrio.map { $0.asPairedEvents }.flatMap { $0 })
    #expect(testSession.state.displayedText == "芳")
    handleEvents(KBEvent.KeyEventData.shiftEnterEvent.asPairedEvents)
    #expect(testClientProxy.toString() == "芳")
    #expect(testSession.state.type == .ofAssociates)
    let shiftPlus3 = KBEvent.KeyEventData(
      flags: .shift,
      chars: "#",
      charsSansModifiers: "3",
      keyCode: 20
    )
    handleEvents(shiftPlus3.asPairedEvents)
    #expect(testClientProxy.toString() == "芳香")
  }

  @Test
  func test216_InputHandler_RevolverRareCase_JiHuQiKeng() throws {
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

  /// 驗證 marking state 的 tooltip 在 switchState 中正確生成。
  /// 此測試防禦：ofMarking() 的 call site 在 LibVanguard 層（不連結 MainAssembly），
  /// 無法看到 generateTooltipForMarking()，因此 tooltip 須在 switchState 中產生。
  @Test
  func test217_MarkingStateTooltipGeneratedInSwitchState() throws {
    _ = prepareBasicComposition(sequence: "dk ru4204el ")
    testSession.switchState(.ofAbortion())
    testClientProxy.clear()

    // 使用雙字詞來測試 marking state（確保 markedRange 至少有 2 個字）。
    _ = prepareBasicComposition(sequence: "wu40j4qi4 ")
    // 確認有 composition 後，按 Shift+Left 進入 marking state。
    #expect(testSession.state.hasComposition)
    press(.shiftLeftEvent)
    press(.shiftLeftEvent)
    #expect(testSession.state.type == .ofMarking)
    #expect(!testSession.state.markedRange.isEmpty, "Marked range must be non-empty for tooltip to appear")

    // 核心驗證：tooltip 非空（若為空，showTooltip 會改為 hide）。
    let tooltip = testSession.state.tooltip
    #expect(!tooltip.isEmpty, "Tooltip should be non-empty after entering marking state, but was empty")
    // 驗證 tooltip 顏色狀態為正常（非 denial / error）。
    #expect(
      testSession.state.data.tooltipColorState == .normal || testSession.state.data.tooltipColorState == .prompt,
      "Tooltip color state should be normal or prompt for a new phrase"
    )
  }

  /// 中英混打模式 Tooltip 第二行之讀音呈現，須沿用 Tooltip 既有規則：
  /// 注音一律教科書式（輕聲前置）；僅當「以漢語拼音顯示組字區讀音」啟用、
  /// 且該 Tooltip 以橫排呈現時才改為漢語拼音教科書式標調。
  /// ※ 組字區自身仍維持原本之數字標調式拼音，兩者刻意不同（見既有 `readingThreadForDisplay`）。
  @Test
  func test218_InputHandler_MixedTooltipReadingPreviewStyle() throws {
    let originalCurrent = InputSession.current
    let originalMixed = testHandler.prefs.mixedAlphanumericalEnabled
    let originalHanyuPinyin = testHandler.prefs.showHanyuPinyinInCompositionBuffer
    let originalAlwaysHorizontal = testHandler.prefs.alwaysShowTooltipTextsHorizontally
    let originalVertical = testSession.isVerticalTyping
    defer {
      InputSession.current = originalCurrent
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixed
      testHandler.prefs.showHanyuPinyinInCompositionBuffer = originalHanyuPinyin
      testHandler.prefs.alwaysShowTooltipTextsHorizontally = originalAlwaysHorizontal
      testSession.isVerticalTyping = originalVertical
      testHandler.clear()
    }

    InputSession.current = testSession
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = false
    testSession.isVerticalTyping = false

    // 直驅注拼槽至「ㄇㄛˇ」，避開混輸 auto-split 對鍵序之依賴。
    var composer = testHandler.composer
    composer.clear()
    composer.receiveSequence("ai3", isRomaji: false)
    #expect(composer.getComposition(isHanyuPinyin: false) == "ㄇㄛˇ")
    testHandler.composer = composer
    testHandler.mixedAlphanumericalBuffer = "ai3"

    // 停用「以漢語拼音顯示組字區讀音」：第二行以教科書式注音呈現。
    let bpmfPreview = testHandler.generateStateOfInputting().tooltip
    #expect(bpmfPreview == "ai3\nㄇㄛˇ", "實際得到：\(bpmfPreview)")

    // 啟用該偏好且為橫排：第二行改以漢語拼音教科書式標調呈現。
    testHandler.prefs.showHanyuPinyinInCompositionBuffer = true
    let pinyinPreview = testHandler.generateStateOfInputting().tooltip
    #expect(pinyinPreview == "ai3\nmǒ", "實際得到：\(pinyinPreview)")
    // 對照：組字區自身仍為數字標調式，可見 Tooltip 走的是自家既有規則。
    #expect(composer.getComposition(isHanyuPinyin: true) == "mo3")

    // 直排輸入且未強制橫排 Tooltip 時，退回教科書式注音。
    testSession.isVerticalTyping = true
    let verticalPreview = testHandler.generateStateOfInputting().tooltip
    #expect(verticalPreview == "ai3\nㄇㄛˇ", "實際得到：\(verticalPreview)")

    // 直排但強制 Tooltip 橫排時，仍以漢語拼音呈現。
    testHandler.prefs.alwaysShowTooltipTextsHorizontally = true
    let verticalForcedHorizontal = testHandler.generateStateOfInputting().tooltip
    #expect(verticalForcedHorizontal == "ai3\nmǒ", "實際得到：\(verticalForcedHorizontal)")
    testHandler.prefs.alwaysShowTooltipTextsHorizontally = false
  }

  /// 驗證一般打字且輸入狀態為 empty 時，Shift+空格鍵之輸出寬度由偏好決定、且預設為全形。
  @Test
  func test219_InputHandler_ShiftSpaceEmptyStateWidth() throws {
    let spaceEvent = KBEvent.KeyEventData(chars: " ", keyCode: KeyCode.kSpace.rawValue)
    let shiftSpaceEvent = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .shift,
      chars: " ",
      keyCode: KeyCode.kSpace.rawValue
    )

    // 不帶 Shift 的空格鍵：恆為半形，不受偏好影響。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = true
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(spaceEvent)
    #expect(testClientProxy.toString() == " ")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    // 帶 Shift 的空格鍵：預設（偏好為 false）為全形。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = false
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(shiftSpaceEvent)
    #expect(testClientProxy.toString() == "　")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    // 帶 Shift 的空格鍵：偏好為 true 時改為半形。
    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = true
    testSession.switchState(.ofEmpty())
    testClientProxy.clear()
    _ = press(shiftSpaceEvent)
    #expect(testClientProxy.toString() == " ")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    testHandler.prefs.specifyShiftSpaceKeyBehavior4EmptyState = false
  }

  /// 中英混打模式下，內文 Tooltip 須錨在「未完成讀音（此際即 ASCII 緩衝區）後方之游標
  /// 位置」上——與選字窗之錨定（`u16MarkedRange.lowerBound`）同源，故能跟著該位置
  /// 同步移動自身的位置；而非恆錨在組字區最前方（既有行為）。
  ///
  /// 該位置另存於 `IMEState`：`.ofInputting` 狀態的 `marker` 會被 `getMitigatedState(_:)`
  /// 拉平至 `cursor`，故此測試同時釘死「marker 已拉平、錨點資訊仍在」之狀態形制。
  @Test
  func test220_MixedAlnumTooltipAnchorsAtCursorPosBehindReading() throws {
    let tooltipUI = MockTooltipUI()
    let originalTooltipUI = testUI.tooltipUI
    let originalMixed = testHandler.prefs.mixedAlphanumericalEnabled
    defer {
      testUI.tooltipUI = originalTooltipUI
      testHandler.prefs.mixedAlphanumericalEnabled = originalMixed
      testClientProxy.lineHeightRectProvider = nil
      testClientProxy.clear()
      testHandler.clear()
    }
    testUI.tooltipUI = tooltipUI
    testHandler.prefs.mixedAlphanumericalEnabled = true
    // 逐分量斷言錨點（`CGPoint` 於跨平台環境不一定遵從 `Equatable`）。
    func expectAnchor(_ expectedX: CGFloat, _ expectedY: CGFloat, _ label: String) {
      #expect(
        tooltipUI.shownPoint?.x == expectedX && tooltipUI.shownPoint?.y == expectedY,
        "\(label)：實際得到：\(String(describing: tooltipUI.shownPoint))"
      )
    }
    // 以座標自身作為行高矩形之 x 值（×10）與 y 值（100）：錨在哪個座標一目了然。
    // 如此亦與既有錨定（客體未提供量測值時的零矩形，x = 0、y = 0）可資區別。
    testClientProxy.lineHeightRectProvider = { u16CursorPos in
      CGRect(
        origin: CGPoint(x: CGFloat(u16CursorPos) * 10, y: 100),
        size: CGSize(width: 10, height: 20)
      )
    }

    resetToAbortionAndClear()

    // 先組出中文「你」（注音 ㄋㄧˇ），再鍵入大寫 ASCII「T」
    // （大寫不進注拼槽，故組字區顯示的就是該 ASCII 原文）。
    typeSentenceOrCandidates("su3")
    #expect(testSession.state.displayedText == "你", "實際得到：\(testSession.state.displayedText)")
    typeSentenceOrCandidates("T")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "你T", "實際得到：\(testSession.state.displayedText)")

    // 未完成讀音（ASCII 緩衝區）後方之游標位置 = 1（緊隨「你」之後）；marker 已被拉平至 cursor。
    #expect(testSession.state.data.cursorPosRightBehindTheUnfinishedReading == 1)
    #expect(testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == 1)
    #expect(
      testSession.state.marker == testSession.state.cursor,
      "`.ofInputting` 狀態之 marker 應已被拉平至 cursor，故該起點須另存一份"
    )

    // 錨點：該位置（u16 = 1）之矩形原點為 (10, 100)；若仍錨在組字區最前方則會得到 (0, 0)。
    #expect(tooltipUI.shownTooltip == "T", "實際得到：\(String(describing: tooltipUI.shownTooltip))")
    expectAnchor(10, 100, "混輸 Tooltip 應錨在未完成讀音後方之游標位置上")
    #expect(
      testClientProxy.queriedU16CursorPositions.contains(1),
      "應以混輸起點（u16 = 1）向客體量測行高矩形；實查座標：\(testClientProxy.queriedU16CursorPositions)"
    )

    // 對照組一：未完成讀音自組字區最前方起算時（空組字區），錨點 = 座標 0 之矩形。
    tooltipUI.hide()
    resetToAbortionAndClear()
    typeSentenceOrCandidates("T")
    #expect(testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == 0)
    expectAnchor(0, 100, "未完成讀音自組字區最前方起算時應錨在座標 0")

    // 對照組二：非輸入狀態（標記狀態）之 Tooltip 仍錨在既有錨定（組字區最前方之矩形）
    // ——該類狀態不由 `generateStateOfInputting()` 生成，故不帶「未完成讀音後方之游標位置」。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    _ = prepareBasicComposition(sequence: "wu40j4qi4 ")
    press(.shiftLeftEvent)
    #expect(testSession.state.type == .ofMarking)
    #expect(
      testSession.state.data.u16CursorPosRightBehindTheUnfinishedReading == nil,
      "標記狀態不應承載該游標位置"
    )
    expectAnchor(0, 0, "非輸入狀態應沿用既有錨定")

    // 對照組三：輸入狀態之未完成讀音為空時，該值繼承當前輸入游標位置，錨點隨之落在
    // 該游標位置上（而非組字區最前方）——此乃「輸入狀態一律賦值」之行為面。
    resetToAbortionAndClear()
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄋㄧˇ") }
    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "你", "實際得到：\(testSession.state.displayedText)")
    #expect(
      testSession.state.data.cursorPosRightBehindTheUnfinishedReading == testSession.state.cursor,
      "未完成讀音為空時應繼承當前輸入游標位置"
    )
    // 該狀態之 Tooltip 本為空（不開窗），故直接注入一段文案以驗證錨定路徑。
    var stateWithTooltip = testHandler.generateStateOfInputting()
    stateWithTooltip.tooltip = "injected"
    let anchorU16Pos = stateWithTooltip.data.u16CursorPosRightBehindTheUnfinishedReading ?? -1
    #expect(anchorU16Pos == 1, "繼承所得之 UTF-16 座標應為 1；實際得到：\(anchorU16Pos)")
    testSession.switchState(stateWithTooltip)
    #expect(tooltipUI.shownTooltip == "injected")
    expectAnchor(
      CGFloat(anchorU16Pos) * 10, 100,
      "未完成讀音為空時應錨在當前輸入游標位置上"
    )
  }
}
