// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - KeyHandler Delegate

extension ctlInputMethod: KeyHandlerDelegate {
  var clientBundleIdentifier: String {
    guard let client = client() else { return "" }
    return client.bundleIdentifier() ?? ""
  }

  func ctlCandidate() -> ctlCandidateProtocol { ctlInputMethod.ctlCandidateCurrent }

  func candidateSelectionCalledByKeyHandler(at index: Int) {
    candidateSelected(at: index)
  }

  func performUserPhraseOperation(with state: IMEStateProtocol, addToFilter: Bool)
    -> Bool
  {
    guard state.type == .ofMarking else { return false }
    let refInputModeReversed: Shared.InputMode =
      (inputMode == .imeModeCHT) ? .imeModeCHS : .imeModeCHT
    if !LMMgr.writeUserPhrase(
      state.data.userPhraseDumped, inputMode: inputMode,
      areWeDuplicating: state.data.doesUserPhraseExist,
      areWeDeleting: addToFilter
    )
      || !LMMgr.writeUserPhrase(
        state.data.userPhraseDumpedConverted, inputMode: refInputModeReversed,
        areWeDuplicating: false,
        areWeDeleting: addToFilter
      )
    {
      return false
    }
    return true
  }
}

// MARK: - Candidate Controller Delegate

extension ctlInputMethod: ctlCandidateDelegate {
  func candidateCountForController(_ controller: ctlCandidateProtocol) -> Int {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if state.isCandidateContainer {
      return state.candidates.count
    }
    return 0
  }

  /// 直接給出全部的候選字詞的字音配對陣列
  /// - Parameter controller: 對應的控制器。因為有唯一解，所以填錯了也不會有影響。
  /// - Returns: 候選字詞陣列（字音配對）。
  func candidatesForController(_ controller: ctlCandidateProtocol) -> [(String, String)] {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if state.isCandidateContainer {
      return state.candidates
    }
    return .init()
  }

  func ctlCandidate(_ controller: ctlCandidateProtocol, candidateAtIndex index: Int)
    -> (String, String)
  {
    _ = controller  // 防止格式整理工具毀掉與此對應的參數。
    if state.isCandidateContainer {
      return state.candidates[index]
    }
    return ("", "")
  }

  func candidateSelected(at index: Int) {
    if state.type == .ofSymbolTable, (0..<state.node.members.count).contains(index) {
      let node = state.node.members[index]
      if !node.members.isEmpty {
        handle(state: IMEState.ofEmpty())  // 防止縱橫排選字窗同時出現
        handle(state: IMEState.ofSymbolTable(node: node))
      } else {
        handle(state: IMEState.ofCommitting(textToCommit: node.name))
        handle(state: IMEState.ofEmpty())
      }
      return
    }

    if [.ofCandidates, .ofSymbolTable].contains(state.type) {
      let selectedValue = state.candidates[index]
      keyHandler.fixNode(
        candidate: selectedValue, respectCursorPushing: true,
        preConsolidate: PrefMgr.shared.consolidateContextOnCandidateSelection
      )

      let inputting = keyHandler.buildInputtingState

      if PrefMgr.shared.useSCPCTypingMode {
        handle(state: IMEState.ofCommitting(textToCommit: inputting.displayedText))
        // 此時是逐字選字模式，所以「selectedValue.1」是單個字、不用追加處理。
        if PrefMgr.shared.associatedPhrasesEnabled {
          let associates = keyHandler.buildAssociatePhraseState(
            withPair: .init(key: selectedValue.0, value: selectedValue.1)
          )
          handle(state: associates.candidates.isEmpty ? IMEState.ofEmpty() : associates)
        } else {
          handle(state: IMEState.ofEmpty())
        }
      } else {
        handle(state: inputting)
      }
      return
    }

    if state.type == .ofAssociates {
      let selectedValue = state.candidates[index]
      handle(state: IMEState.ofCommitting(textToCommit: selectedValue.1))
      // 此時是聯想詞選字模式，所以「selectedValue.1」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.1.last else {
        handle(state: IMEState.ofEmpty())
        return
      }
      if PrefMgr.shared.associatedPhrasesEnabled {
        let associates = keyHandler.buildAssociatePhraseState(
          withPair: .init(key: selectedValue.0, value: String(valueKept))
        )
        if !associates.candidates.isEmpty {
          handle(state: associates)
          return
        }
      }
      handle(state: IMEState.ofEmpty())
    }
  }
}
