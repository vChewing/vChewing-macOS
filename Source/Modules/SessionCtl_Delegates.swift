// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - KeyHandler Delegate

extension SessionCtl: KeyHandlerDelegate {
  var clientBundleIdentifier: String {
    guard let client = client() else { return "" }
    return client.bundleIdentifier() ?? ""
  }

  func candidateController() -> CtlCandidateProtocol { ctlCandidateCurrent }

  func candidateSelectionCalledByKeyHandler(at index: Int) {
    candidatePairSelected(at: index)
  }

  func performUserPhraseOperation(with state: IMEStateProtocol, addToFilter: Bool)
    -> Bool
  {
    guard state.type == .ofMarking else { return false }
    if !LMMgr.writeUserPhrase(
      state.data.userPhraseDumped, inputMode: inputMode,
      areWeDuplicating: state.data.doesUserPhraseExist,
      areWeDeleting: addToFilter
    )
      || !LMMgr.writeUserPhrase(
        state.data.userPhraseDumpedConverted, inputMode: inputMode.reversed,
        areWeDuplicating: false,
        areWeDeleting: addToFilter
      )
    {
      return false
    }
    // 開始針對使用者半衰模組的清詞處理
    let rawPair = state.data.userPhraseKVPair
    let valueCurrent = rawPair.1
    let valueReversed = ChineseConverter.crossConvert(rawPair.1)
    LMMgr.bleachSpecifiedSuggestions(targets: [valueCurrent], mode: IMEApp.currentInputMode)
    LMMgr.bleachSpecifiedSuggestions(targets: [valueReversed], mode: IMEApp.currentInputMode.reversed)
    // 清詞完畢
    return true
  }
}

// MARK: - Candidate Controller Delegate

extension SessionCtl: CtlCandidateDelegate {
  var selectionKeys: String {
    PrefMgr.shared.useIMKCandidateWindow ? "123456789" : PrefMgr.shared.candidateKeys
  }

  func candidatePairs(conv: Bool = false) -> [(String, String)] {
    if !state.isCandidateContainer || state.candidates.isEmpty { return [] }
    if !conv || PrefMgr.shared.cns11643Enabled || state.candidates[0].0.contains("_punctuation") {
      return state.candidates
    }
    let convertedCandidates: [(String, String)] = state.candidates.map { theCandidatePair -> (String, String) in
      let theCandidate = theCandidatePair.1
      let theConverted = ChineseConverter.kanjiConversionIfRequired(theCandidate)
      let result = (theCandidate == theConverted) ? theCandidate : "\(theConverted)(\(theCandidate))"
      return (theCandidatePair.0, result)
    }
    return convertedCandidates
  }

  func candidatePairSelected(at index: Int) {
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
