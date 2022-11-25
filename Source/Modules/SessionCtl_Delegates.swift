// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: - InputHandler Delegate

extension SessionCtl: InputHandlerDelegate {
  public var clientBundleIdentifier: String {
    guard let client = client() else { return "" }
    return client.bundleIdentifier() ?? ""
  }

  public func candidateController() -> CtlCandidateProtocol { Self.ctlCandidateCurrent }

  public func candidateSelectionCalledByInputHandler(at index: Int) {
    candidatePairSelected(at: index)
  }

  public func callError(_ logMessage: String) {
    vCLog(logMessage)
    IMEApp.buzz()
  }

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool {
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
  public var showReverseLookupResult: Bool {
    !isVerticalTyping && PrefMgr.shared.showReverseLookupInCandidateUI
  }

  @discardableResult public func reverseLookup(for value: String) -> [String] {
    let blankResult: [String] = []
    // 這一段專門處理「反查」。
    if !PrefMgr.shared.showReverseLookupInCandidateUI { return blankResult }
    if isVerticalTyping { return blankResult }  // 縱排輸入的場合，選字窗沒有足夠的空間顯示反查結果。
    if value.isEmpty { return blankResult }  // 空字串沒有需要反查的東西。
    if value.contains("_") { return blankResult }
    guard var lookupResult = LMMgr.currentLM.currentCassette.reverseLookupMap[value] else { return blankResult }
    for i in 0..<lookupResult.count {
      lookupResult[i] = lookupResult[i].trimmingCharacters(in: .newlines)
    }
    return lookupResult.stableSort(by: { $0.count < $1.count }).stableSort {
      LMMgr.currentLM.currentCassette.unigramsFor(key: $0).count
        < LMMgr.currentLM.currentCassette.unigramsFor(key: $1).count
    }
  }

  public var selectionKeys: String {
    PrefMgr.shared.useIMKCandidateWindow ? "123456789" : PrefMgr.shared.candidateKeys
  }

  public func candidatePairs(conv: Bool = false) -> [(String, String)] {
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

  public func candidatePairSelected(at index: Int) {
    if state.type == .ofSymbolTable, (0..<state.node.members.count).contains(index) {
      let node = state.node.members[index]
      if !node.members.isEmpty {
        switchState(IMEState.ofEmpty())  // 防止縱橫排選字窗同時出現
        switchState(IMEState.ofSymbolTable(node: node))
      } else {
        switchState(IMEState.ofCommitting(textToCommit: node.name))
        switchState(IMEState.ofEmpty())
      }
      return
    }

    if [.ofCandidates, .ofSymbolTable].contains(state.type) {
      let selectedValue = state.candidates[index]
      if state.type == .ofCandidates {
        Self.inputHandler.consolidateNode(
          candidate: selectedValue, respectCursorPushing: true,
          preConsolidate: PrefMgr.shared.consolidateContextOnCandidateSelection
        )
      }

      let inputting = Self.inputHandler.generateStateOfInputting()

      if PrefMgr.shared.useSCPCTypingMode {
        switchState(IMEState.ofCommitting(textToCommit: inputting.displayedText))
        // 此時是逐字選字模式，所以「selectedValue.1」是單個字、不用追加處理。
        if PrefMgr.shared.associatedPhrasesEnabled {
          let associates = Self.inputHandler.generateStateOfAssociates(
            withPair: .init(key: selectedValue.0, value: selectedValue.1)
          )
          switchState(associates.candidates.isEmpty ? IMEState.ofEmpty() : associates)
        } else {
          switchState(IMEState.ofEmpty())
        }
      } else {
        switchState(inputting)
      }
      return
    }

    if state.type == .ofAssociates {
      let selectedValue = state.candidates[index]
      switchState(IMEState.ofCommitting(textToCommit: selectedValue.1))
      // 此時是聯想詞選字模式，所以「selectedValue.1」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.1.last else {
        switchState(IMEState.ofEmpty())
        return
      }
      if PrefMgr.shared.associatedPhrasesEnabled {
        let associates = Self.inputHandler.generateStateOfAssociates(
          withPair: .init(key: selectedValue.0, value: String(valueKept))
        )
        if !associates.candidates.isEmpty {
          switchState(associates)
          return
        }
      }
      switchState(IMEState.ofEmpty())
    }
  }
}
