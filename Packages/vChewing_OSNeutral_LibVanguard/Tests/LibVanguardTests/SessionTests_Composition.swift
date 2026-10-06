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

// 狀態遞交：空狀態遞交組字內容與 BPMFVS 原文之雙軌一致性。

// MARK: - SS.Composition

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  @Test("SS-Composition-001 Switch state empty commits composition")
  func test_SS_Composition_001_SwitchStateEmptyCommitsComposition() throws {
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

  @Test("SS-Composition-002 Switch state empty commits raw text without BPMFVS leak")
  func test_SS_Composition_002_SwitchStateEmptyCommitsRawTextWithoutBPMFVSLeak() throws {
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

  @Test("SS-Composition-003 SCPC selection commits raw text without BPMFVS leak")
  func test_SS_Composition_003_SCPCSelectionCommitsRawTextWithoutBPMFVSLeak() throws {
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
}
