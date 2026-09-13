// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Shared
import Testing

@testable import LexiconAssembly
@testable import OSNeutralAssembly

// MARK: - Session 層個案（編號沿用 MainAssembly 測試案）

/// 本檔將原本以 `NSEvent` 驅動真 `InputSession` 的個案，移植到跨平台的
/// `SessionTests` harness（真 `InputSession` + 真 `InputHandler` + `MockClientProxy`）。
/// 個案編號沿用原檔，方便與 `MainAssembly4Darwin` 的既有案例互相對照。
extension InputHandlerTests.Session {
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

  // To test: Boost, Nerf, and Filter.
  @Test
  func test301_InputHandler_CandidateFilterShortcuts() throws {
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

  @Test
  func test401_Session_AttrStrAPITests() throws {
    let markedClauseSegmentKey = NSAttributedString.Key(rawValue: "NSMarkedClauseSegment")
    let segments: [IMEStateParsed.AttrStrULStyle.StyledPair] = [
      ("", .single),
      ("甲", .single),
      ("", .thick),
      ("乙", .thick),
    ]
    let attributed = IMEStateParsed.AttrStrULStyle.pack(segments)
    #expect(attributed.string == "甲乙")

    var effectiveRange = NSRange(location: NSNotFound, length: 0)
    let firstValue = intValueOfAttribute(
      attributed.attribute(markedClauseSegmentKey, at: 0, effectiveRange: &effectiveRange)
    )
    #expect(firstValue == 0)
    #expect(effectiveRange.length == "甲".utf16.count)

    let secondIndex = max(0, attributed.string.utf16.count - "乙".utf16.count)
    var secondRange = NSRange(location: NSNotFound, length: 0)
    let secondValue = intValueOfAttribute(
      attributed.attribute(markedClauseSegmentKey, at: secondIndex, effectiveRange: &secondRange)
    )
    #expect(secondValue == 1)
    #expect(secondRange.length == "乙".utf16.count)
  }

  /// 跨平台讀取 `NSAttributedString` 屬性內的整數值。
  ///
  /// Darwin 端該值會橋接為 `NSNumber`；Linux／Windows 端則可能原樣保留為 `Int`。
  private func intValueOfAttribute(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    return value as? Int
  }

  @Test
  func test402_Session_QEMUCursorReleaseHotKeyOmission() throws {
    // QEMU relies on `Control+Option+G` to release the mouse cursor.
    // This test ensures that the input method ignores this hotkey (returns false).
    resetToEmptyAndClear()
    press(.ctrlOptionGEvent, shouldHandle: false)
  }
}
