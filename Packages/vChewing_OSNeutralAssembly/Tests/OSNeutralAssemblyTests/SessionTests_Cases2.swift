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
@testable import OSNeutralAssembly

// MARK: - Session 層個案（編號沿用 MainAssembly 測試案）

/// 本檔將原本以 `NSEvent` 驅動真 `InputSession` 的個案，移植到跨平台的
/// `SessionTests` harness（真 `InputSession` + 真 `InputHandler` + `MockClientProxy`）。
/// 個案編號沿用原檔，方便與 `MainAssembly4Darwin` 的既有案例互相對照。
extension InputHandlerTests.Session {
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
  /// 此測試防禦：ofMarking() 的 call site 在 OSNeutralAssembly 層（不連結 MainAssembly），
  /// 無法看到 generateTooltipForMarking()，因此 tooltip 須在 switchState 中產生。
  @Test
  func test214_MarkingStateTooltipGeneratedInSwitchState() throws {
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
}
