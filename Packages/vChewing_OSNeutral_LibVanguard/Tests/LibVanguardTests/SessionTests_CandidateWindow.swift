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

// 選字窗與候選：標點與符號選單、關聯詞語、候選預覽、過濾快捷鍵。

// MARK: - SS.CandidateWindow

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  @Test("SS-CandidateWindow-001 Punctuation features and symbol menus")
  func test_SS_CandidateWindow_001_PunctuationFeaturesAndSymbolMenus() throws {
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

  @Test("SS-CandidateWindow-002 Candidate window extended operations")
  func test_SS_CandidateWindow_002_CandidateWindowExtendedOperations() throws {
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

  @Test("SS-CandidateWindow-003 Service menu initiation")
  func test_SS_CandidateWindow_003_ServiceMenuInitiation() throws {
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

  @Test("SS-CandidateWindow-004 Candidate preview updates")
  func test_SS_CandidateWindow_004_CandidatePreviewUpdates() throws {
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

  /// 測試在啟用逐字選字模式下的關聯詞語功能。
  @Test("SS-CandidateWindow-005 Associated phrase triggers SCPC")
  func test_SS_CandidateWindow_005_AssociatedPhraseTriggersSCPC() throws {
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
  @Test("SS-CandidateWindow-006 Associated phrase triggers non-SCPC")
  func test_SS_CandidateWindow_006_AssociatedPhraseTriggersNonSCPC() throws {
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

  @Test("SS-CandidateWindow-007 Candidate filter shortcuts")
  func test_SS_CandidateWindow_007_CandidateFilterShortcuts() throws {
    restoreExtremeUserPhraseWeightHostBehavior()
    // 生產環境下 `inputHandler.currentLM` 與 `inputMode.lexicon` 恆為同一實例
    // （見 `SessionHostWiring` 與 `InputSession.initInputHandler`）；可攜 harness 於
    // `init` 內另行建立了獨立的 LM 實例並指派給 `currentLM`，故在此還原該不變式：
    // 否則 `candidatePairManipulated` 內對 `inputMode.lexicon` 的過濾資料寫入
    // 將與組字器實際查詢的 `currentLM` 不同步，過濾結果無法反映於候選清單。
    testHandler.currentLM = Shared.InputMode.imeModeCHT.lexicon
    // 該實例隸屬 `Shared.InputMode` 的單元測試快取、會跨個案存活，
    // 故於本個案結束時清除暫存語彙資料，避免汙染其它個案。
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.currentLM.clearTemporaryData(isFiltering: true)
    }

    // Initial reset
    resetCandidateManipulationUserData()

    for (action, eventDef, target) in testCases4CandidateWindowItemManipulators {
      // Reset user data for each iteration to ensure clean state
      resetCandidateManipulationUserData()
      // Reset state for each iteration
      resetToAbortionAndClear()
      prepareBasicState4CandidateManipulationTests()
      highlightCandidateToValue(target)

      let writtenCountBefore = writtenUserPhrases.count
      let filteredCountBefore = recordedFilteredPhrases.count
      press(eventDef)

      // 原個案以子語言模組的 `strData` 是否變動來斷言「使用者語彙資料確實被改寫」。
      // 可攜 harness 以記憶體記錄取代磁碟 I/O：改以宿主端收到的寫入紀錄斷言同一件事。
      let recordedPhrase: UserPhraseInsertable?
      switch action {
      case .toBoost, .toNerf:
        #expect(writtenUserPhrases.count == writtenCountBefore + 1)
        #expect(recordedFilteredPhrases.count == filteredCountBefore)
        recordedPhrase = writtenUserPhrases.last
      case .toFilter:
        #expect(recordedFilteredPhrases.count == filteredCountBefore + 1)
        #expect(writtenUserPhrases.count == writtenCountBefore)
        recordedPhrase = recordedFilteredPhrases.last
      }
      #expect(recordedPhrase?.value == target)
      #expect(recordedPhrase?.keyArray == ["ㄋㄧㄢˊ", "ㄓㄨㄥ"])

      switch action {
      case .toBoost:
        #expect(recordedPhrase?.weight == nil)
        #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年終", "年中"])
      case .toNerf:
        #expect(recordedPhrase?.weight == -114.514)
        #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年終", "年中"])
      case .toFilter:
        #expect(recordedPhrase?.weight == nil)
        #expect(testSession.state.candidates.map(\.value).prefix(1) == ["年終"])
        #expect(testSession.state.candidates.map(\.value).prefix(2) != ["年終", "年中"])
      }
    }
  }

  // MARK: - Test harness

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

  /// 選字窗項目操作任務：動作、觸發熱鍵、欲先高亮的候選值。
  private typealias CandidateManipulatorTask = (
    action: CandidateContextMenuAction, key: KBEvent.KeyEventData, target: String
  )

  private var testCases4CandidateWindowItemManipulators: [CandidateManipulatorTask] {
    [
      (.toBoost, KBEvent.KeyEventData.optionCommandEqualEvent, "年終"),
      (.toNerf, KBEvent.KeyEventData.optionCommandMinusEvent, "年中"),
      (.toFilter, KBEvent.KeyEventData.optionCommandDeleteEventPC, "年中"),
      (.toFilter, KBEvent.KeyEventData.optionCommandBackspaceEventPC, "年中"),
      (.toFilter, KBEvent.KeyEventData.optionCommandBackspaceEventMacAsDelete, "年中"),
    ]
  }

  /// 依當前狀態開啟選字窗並斷言初始候選序。
  private func prepareBasicState4CandidateManipulationTests() {
    typeSentenceOrCandidates("su065j/ ") // Nian2 Zhong1.
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "年中") // Default value.
    // 真 IMK 選字窗每次開啟時高亮皆自首項起算；模擬控制器為單一實例、
    // 高亮索引會跨輪殘留，故於此還原「新開選字窗」的初始高亮狀態。
    testCandidateController.highlightedIndex = 0
    press(.dataArrowDown)
    #expect(testSession.state.type == .ofCandidates)
    #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年中", "年終"])
    syncCandidateControllerCount()
  }

  /// 重設使用者語彙資料。
  ///
  /// 原 MainAssembly 個案藉由 `replaceData(textData: "")` 清空子語言模組；
  /// 但可攜 harness 的使用者詞庫磁碟路徑恆為不存在的暫存路徑，故子語言模組的
  /// `rawData` 恆為空、`replaceData` 會提前返回而不清空暫存資料映射。
  /// 這裡額外呼叫 `clearTemporaryData`，以還原原個案「每輪皆為乾淨狀態」的前提。
  private func resetCandidateManipulationUserData() {
    testHandler.currentLM
      .injectTestData(
        userPhrases: { $0.replaceData(textData: "") },
        userFilter: { $0.replaceData(textData: "") },
        userSymbols: { $0.replaceData(textData: "") },
        replacements: { $0.replaceData(textData: "") },
        associates: { $0.replaceData(textData: "") }
      )
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    testHandler.currentLM.clearTemporaryData(isFiltering: true)
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], current: "年中", probability: -4.329),
      isFiltering: false
    )
  }

  /// 還原 MainAssembly 宿主端的權重指派契約。
  ///
  /// `SessionHost.updateUserPhraseWeight` 在可攜 harness 內被替換為
  /// 「原樣返回」的空操作；若缺此權重，降權（nerf）將與升權（boost）無異，
  /// 選字窗候選序便無法反映降權語義。此處依 `UserPhraseImpl.suggestNextFreq`
  /// 於「非單字讀音配對」時所用的極端值（升權 nil、降權 -114.514、過濾 nil）
  /// 復刻宿主端行為。本個案的所有候選皆為二字詞、讀音皆為兩段，
  /// 故僅需極端值分支。
  private func restoreExtremeUserPhraseWeightHostBehavior() {
    SessionHost.shared.updateUserPhraseWeight = { phrase, action in
      var phrase = phrase
      switch action {
      case .toBoost: phrase.weight = nil
      case .toNerf: phrase.weight = -114.514
      case .toFilter: phrase.weight = nil
      }
      return phrase
    }
  }
}
