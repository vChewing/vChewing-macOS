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
  public var clientMitigationLevel: Int {
    guard
      let result = PrefMgr.shared.clientsIMKTextInputIncapable[clientBundleIdentifier]
    else {
      return 0
    }
    return result ? 2 : 1
  }

  public func candidateController() -> CtlCandidateProtocol? { candidateUI }

  public func candidateSelectionCalledByInputHandler(at index: Int) {
    candidatePairSelected(at: index)
  }

  public func callError(_ logMessage: String) {
    vCLog(logMessage)
    IMEApp.buzz()
  }

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool {
    guard let inputHandler = inputHandler, state.type == .ofMarking else { return false }
    var succeeded = true

    let kvPair = state.data.userPhraseKVPair
    var userPhrase = LMMgr.UserPhrase(
      keyArray: kvPair.keyArray, value: kvPair.value, inputMode: inputMode
    )
    if Self.areWeNerfing { userPhrase.weight = -114.514 }
    LMMgr.writeUserPhrasesAtOnce(userPhrase, areWeFiltering: addToFilter) {
      succeeded = false
    }
    if !succeeded { return false }

    // 後續操作。
    let valueCurrent = userPhrase.value
    let valueReversed = ChineseConverter.crossConvert(valueCurrent)

    // 更新組字器內的單元圖資料。
    // 註：如果已經排除的內容是該讀音下唯一的記錄的話，
    // 則該內容的節點會繼續殘留在組字區內，只是無法再重新輸入了。
    _ = inputHandler.updateUnigramData()

    // 因為上述操作不會立即生效（除非遞交組字區），所以暫時塞入臨時資料記錄。
    // 該臨時資料記錄會在接下來的語言模組資料重載過程中被自動清除。
    LMMgr.currentLM.insertTemporaryData(
      keyArray: userPhrase.keyArray,
      unigram: .init(value: userPhrase.value, score: userPhrase.weight ?? 0),
      isFiltering: addToFilter
    )
    // 開始針對使用者半衰模組的清詞處理
    LMMgr.bleachSpecifiedSuggestions(targets: [valueCurrent], mode: IMEApp.currentInputMode)
    LMMgr.bleachSpecifiedSuggestions(targets: [valueReversed], mode: IMEApp.currentInputMode.reversed)
    // 清詞完畢
    return true
  }
}

// MARK: - Candidate Controller Delegate

extension SessionCtl: CtlCandidateDelegate {
  public var isCandidateState: Bool { state.isCandidateContainer }
  public var isCandidateContextMenuEnabled: Bool {
    state.type == .ofCandidates && !clientBundleIdentifier.contains("com.apple.Spotlight")
      && !clientBundleIdentifier.contains("com.raycast.macos")
  }

  public var showReverseLookupResult: Bool { PrefMgr.shared.showReverseLookupInCandidateUI }

  @discardableResult public func reverseLookup(for value: String) -> [String] {
    let blankResult: [String] = []
    // 這一段專門處理「反查」。
    if !PrefMgr.shared.showReverseLookupInCandidateUI { return blankResult }
    if isVerticalTyping { return blankResult } // 縱排輸入的場合，選字窗沒有足夠的空間顯示反查結果。
    if value.isEmpty { return blankResult } // 空字串沒有需要反查的東西。
    if value.contains("_") { return blankResult }
    // 因為威注音輸入法的反查結果僅由磁帶模組負責，所以相關運算挪至 LMInstantiator 內處理。
    return LMMgr.currentLM.cassetteReverseLookup(for: value)
  }

  public var selectionKeys: String {
    PrefMgr.shared.useIMKCandidateWindow ? "123456789" : PrefMgr.shared.candidateKeys
  }

  public func candidatePairs(conv: Bool = false) -> [(keyArray: [String], value: String)] {
    if !state.isCandidateContainer || state.candidates.isEmpty { return [] }
    if !conv || PrefMgr.shared.cns11643Enabled || state.candidates[0].keyArray.joined().contains("_punctuation") {
      return state.candidates
    }
    let convertedCandidates = state.candidates.map { theCandidatePair -> (keyArray: [String], value: String) in
      var theCandidatePair = theCandidatePair
      theCandidatePair.value = ChineseConverter.kanjiConversionIfRequired(theCandidatePair.value)
      return theCandidatePair
    }
    return convertedCandidates
  }

  public func candidatePairSelected(at index: Int) {
    guard let inputHandler = inputHandler else { return }
    if state.type == .ofSymbolTable, (0 ..< state.node.members.count).contains(index) {
      let node = state.node.members[index]
      if !node.members.isEmpty {
        switchState(IMEState.ofEmpty()) // 防止縱橫排選字窗同時出現
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
        inputHandler.consolidateNode(
          candidate: selectedValue, respectCursorPushing: true,
          preConsolidate: PrefMgr.shared.consolidateContextOnCandidateSelection
        )
      }

      let inputting = inputHandler.generateStateOfInputting()

      if PrefMgr.shared.useSCPCTypingMode {
        switchState(IMEState.ofCommitting(textToCommit: inputting.displayedText))
        // 此時是逐字選字模式，所以「selectedValue.value」是單個字、不用追加處理。
        if PrefMgr.shared.associatedPhrasesEnabled {
          let associates = inputHandler.generateStateOfAssociates(
            withPair: .init(keyArray: selectedValue.keyArray, value: selectedValue.value)
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
      switchState(IMEState.ofCommitting(textToCommit: selectedValue.value))
      // 此時是聯想詞選字模式，所以「selectedValue.value」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.value.last else {
        switchState(IMEState.ofEmpty())
        return
      }
      if PrefMgr.shared.associatedPhrasesEnabled {
        let associates = inputHandler.generateStateOfAssociates(
          withPair: .init(keyArray: selectedValue.keyArray, value: String(valueKept))
        )
        if !associates.candidates.isEmpty {
          switchState(associates)
          return
        }
      }
      switchState(IMEState.ofEmpty())
    }
  }

  public func candidatePairRightClicked(at index: Int, action: CandidateContextMenuAction) {
    guard let inputHandler = inputHandler, isCandidateContextMenuEnabled else { return }
    var succeeded = true

    let rawPair = state.candidates[index]
    var userPhrase = LMMgr.UserPhrase(
      keyArray: rawPair.keyArray, value: rawPair.value, inputMode: inputMode
    )
    if action == .toNerf { userPhrase.weight = -114.514 }
    LMMgr.writeUserPhrasesAtOnce(userPhrase, areWeFiltering: action == .toFilter) {
      succeeded = false
    }

    // 後續操作。
    let valueCurrent = userPhrase.value
    let valueReversed = ChineseConverter.crossConvert(valueCurrent)

    // 因為上述操作不會立即生效（除非遞交組字區），所以暫時塞入臨時資料記錄。
    // 該臨時資料記錄會在接下來的語言模組資料重載過程中被自動清除。
    LMMgr.currentLM.insertTemporaryData(
      keyArray: userPhrase.keyArray,
      unigram: .init(value: userPhrase.value, score: userPhrase.weight ?? 0),
      isFiltering: action == .toFilter
    )

    // 開始針對使用者半衰模組的清詞處理
    LMMgr.bleachSpecifiedSuggestions(targets: [valueCurrent], mode: IMEApp.currentInputMode)
    LMMgr.bleachSpecifiedSuggestions(targets: [valueReversed], mode: IMEApp.currentInputMode.reversed)
    // 更新組字器內的單元圖資料。
    let updateResult = inputHandler.updateUnigramData()
    // 清詞完畢

    var newState: IMEStateProtocol = updateResult
      ? inputHandler.generateStateOfCandidates()
      : IMEState.ofCommitting(textToCommit: state.displayedText)
    newState.tooltipDuration = 1.85
    var tooltipMessage = ""
    switch action {
    case .toBoost:
      newState.data.tooltipColorState = .normal
      tooltipMessage = succeeded ? "+ Succeeded in boosting a candidate." : "⚠︎ Failed from boosting a candidate."
    case .toNerf:
      newState.data.tooltipColorState = .succeeded
      tooltipMessage = succeeded ? "- Succeeded in nerfing a candidate." : "⚠︎ Failed from nerfing a candidate."
    case .toFilter:
      newState.data.tooltipColorState = .warning
      tooltipMessage = succeeded ? "! Succeeded in filtering a candidate." : "⚠︎ Failed from filtering a candidate."
    }
    if !succeeded { newState.data.tooltipColorState = .redAlert }
    newState.tooltip = NSLocalizedString(tooltipMessage, comment: "")
    switchState(newState)
  }
}
