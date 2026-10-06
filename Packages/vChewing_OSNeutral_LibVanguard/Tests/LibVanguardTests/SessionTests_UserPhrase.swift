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

// 就地加詞：升權／降權／過濾於當前組字器立即生效。

// MARK: - SS.UserPhrase

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 就地加詞（升權／降權／過濾）必須立刻在**當前的 Homa 組字器實例**內生效。
  ///
  /// 生效機制是使用者片語辭庫的「臨時資料插入」：`performUserPhraseOperation` 於寫檔之後
  /// 先 `insertTemporaryData`、再 `updateUnigramData()` 就地熱重載組字器。
  /// 次序若顛倒（或熱重載拿到過時快取），本測試即紅：組字器會停在舊的元圖快照上，
  /// 直到遞交組字區才改觀。
  @Test("SS-UserPhrase-001 In-place user phrase operations apply to current assembler immediately")
  func test_SS_UserPhrase_001_InPlaceUserPhraseOperationsApplyToCurrentAssemblerImmediately() throws {
    testHandler.prefs.useSCPCTypingMode = false
    let originalFilterabilityChecker = testHandler.filterabilityChecker
    testHandler.filterabilityChecker = { _ in true }
    // 復刻宿主（`UserPhraseImpl`）在 marking 按鍵下指派權重的契約：
    // 升權不填權重（視為 0）、降權賦以極端低權重、過濾不填權重。
    SessionHost.shared.updateUserPhraseWeight = { phrase, action in
      var phrase = phrase
      switch action {
      case .toBoost: phrase.weight = nil
      case .toNerf: phrase.weight = -114.514
      case .toFilter: phrase.weight = nil
      }
      return phrase
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.currentLM.clearTemporaryData(isFiltering: true)
      testHandler.filterabilityChecker = originalFilterabilityChecker
      SessionHost.shared.updateUserPhraseWeight = { phrase, _ in phrase }
    }

    /// 以較低權重預置「年中」後敲出該讀音，作為就地加詞的觀測對象。
    func prepareCompositionWithYearMid() -> String {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.currentLM.clearTemporaryData(isFiltering: true)
      testHandler.currentLM.insertTemporaryData(
        unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], current: "年中", probability: -4.329),
        isFiltering: false
      )
      return prepareBasicComposition(sequence: "su065j/ ")
    }

    /// 讀取當前組字器內「年中」一詞的元圖權重（無此記錄時回 nil）。
    func yearMidScore() -> Double? {
      let keyArray = ["ㄋㄧㄢˊ", "ㄓㄨㄥ"]
      for segment in testHandler.assembler.segments {
        for (_, node) in segment {
          for gram in node.grams where gram.keyArray == keyArray && gram.current == "年中" {
            return gram.probability
          }
        }
      }
      return nil
    }

    func enterMarkingState() {
      press(.shiftLeftEvent)
      press(.shiftLeftEvent)
      #expect(testSession.state.type == .ofMarking)
      #expect(testSession.state.markedRange == 0 ..< 2)
    }

    // ① 升權（Enter）：權重立刻升為臨時資料所給的 0。
    #expect(prepareCompositionWithYearMid() == "年中")
    #expect(yearMidScore() == -4.329)
    enterMarkingState()
    press(.dataEnterReturn)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == 0, "升權後，當前組字器節點內「年中」的權重應立刻變成臨時資料的 0。")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年中")

    // ② 降權（Shift+Command+Enter）：權重立刻降為 -114.514，組句立刻改用另一競品。
    #expect(prepareCompositionWithYearMid() == "年中")
    #expect(yearMidScore() == -4.329)
    enterMarkingState()
    var nerfEnter = KBEvent.KeyEventData.dataEnterReturn
    nerfEnter.flags = [.shift, .command]
    press(nerfEnter)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == -114.514, "降權後，當前組字器節點內「年中」的權重應立刻變成 -114.514。")
    #expect(
      testHandler.assembler.assembledSentence.map(\.value).joined() == "年終",
      "降權後，當前組字結果應立刻改用另一競品，無需遞交組字區。"
    )

    // ③ 過濾（Backspace）：該詞立刻自當前組字器節點內除名，組句立刻改用另一競品。
    #expect(prepareCompositionWithYearMid() == "年中")
    enterMarkingState()
    press(.backspaceEvent)
    #expect(testSession.state.type == .ofInputting)
    #expect(yearMidScore() == nil, "過濾後，當前組字器節點內不應再留有「年中」。")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "年終")
  }
}
