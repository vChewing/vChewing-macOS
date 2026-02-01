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
@testable import MainAssembly
@testable import Typewriter

// 本文的單元測試用例從 301 起算。

extension MainAssemblyTests {
  private typealias CandidateManipulatorTask = (
    action: CandidateContextMenuAction, key: NSEvent.KeyEventData, target: String
  )

  private var testCases4CandidateWinowItemManipulators: [CandidateManipulatorTask] {
    [
      (.toBoost, optionCommandEqualEvent, "年終"),
      (.toNerf, optionCommandMinusEvent, "年中"),
      (.toFilter, optionCommandDeleteEventPC, "年中"),
      (.toFilter, optionCommandBackspaceEventPC, "年中"),
      (.toFilter, optionCommandBackspaceEventMacAsDelete, "年中"),
    ]
  }

  // To test: Boost, Nerf, and Filter.
  @Test
  func test301_InputHandler_CandidateFilterShortcuts() throws {
    func prepareBasicState4ThisTest() {
      typeSentenceOrCandidates("su065j/ ") // Nian2 Zhong1.
      #expect(testSession.state.type == .ofInputting)
      #expect(testSession.state.displayedText == "年中") // Default value.
      press(dataArrowDown)
      #expect(testSession.state.type == .ofCandidates)
      #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年中", "年終"])
    }

    func navigateCandidateHighlightToValue(_ target: String) {
      let candidates = testSession.state.candidates
      guard !candidates.isEmpty else { return }
      #expect(candidates.map(\.value).contains(target))
      checkCandidates: for _ in 0 ..< candidates.count {
        guard testSession.state.displayedText != target else { break checkCandidates }
        press(tabEvent)
      }
      #expect(testSession.state.displayedText == target) // Default value.
    }

    func resetUserData() {
      testHandler.currentLM
        .injectTestData(
          userPhrases: { $0.replaceData(textData: "") },
          userFilter: { $0.replaceData(textData: "") },
          userSymbols: { $0.replaceData(textData: "") },
          replacements: { $0.replaceData(textData: "") },
          associates: { $0.replaceData(textData: "") }
        )
    }

    // Initial reset
    resetUserData()

    for (action, eventDef, target) in testCases4CandidateWinowItemManipulators {
      // Reset user data for each iteration to ensure clean state
      resetUserData()
      // Reset state for each iteration
      resetToAbortionAndClear()
      prepareBasicState4ThisTest()
      highlightCandidateToValue(target)
      func getSubLMDataFromMemory() -> String {
        switch action {
        case .toBoost, .toNerf: testHandler.currentLM.lmUserPhrases.strData
        case .toFilter: testHandler.currentLM.lmFiltered.strData
        }
      }
      let backupDataString = getSubLMDataFromMemory()
      press(eventDef)
      #expect(
        backupDataString != getSubLMDataFromMemory(),
        """
        If this assertion fails. First, confirm whether UTSIO (`test011_LMMgr_UnitTestSandboxIO`) fails.
        If fails, investige why LMMgr fails from writing data under its UnitTests mode.
        Maybe both Xcode and Swift Package Manager are barrierd by their Sandboxes regarding file I/O.
        Maybe the user dictionary path for the UniteTest mode of LMMgr and LMAssembly needs change.
        If UTSIO succeeded, then something else must be wrong with the interaction of LMMgr...
        ... or an internal issue in LMMgr.
        """
      )
      switch action {
      case .toBoost:
        #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年終", "年中"])
      case .toNerf:
        #expect(testSession.state.candidates.map(\.value).prefix(2) == ["年終", "年中"])
      case .toFilter:
        #expect(testSession.state.candidates.map(\.value).prefix(1) == ["年終"])
        #expect(testSession.state.candidates.map(\.value).prefix(2) != ["年終", "年中"])
      }
    }
  }
}
