// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - Session + SessionProtocol

extension SessionProtocol {
  public var clientMitigationLevel: Int {
    var result = prefs.securityHardenedCompositionBuffer ? 2 : 0
    if isClientElectronBased {
      let newVal = prefs.alwaysUsePCBWithElectronBasedClients ? 2 : 1
      result = Swift.max(newVal, result)
    }
    let toMitigate = prefs.clientsIMKTextInputIncapable[clientBundleIdentifier]
    if let toMitigate = toMitigate {
      let mitigationValue = toMitigate ? 2 : 1
      result = Swift.max(mitigationValue, result)
    }
    return result
  }

  public func candidateController() -> CtlCandidateProtocol? { ui?.candidateUI }

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool {
    guard let inputHandler = inputHandler, state.type == .ofMarking else { return false }

    let kvPair = state.data.userPhraseKVPair
    var userPhrase = UserPhraseInsertable(
      keyArray: kvPair.keyArray,
      value: kvPair.value,
      inputMode: inputMode
    )
    var action = CandidateContextMenuAction.toBoost
    if Self.areWeNerfing { action = .toNerf }
    if addToFilter { action = .toFilter }
    userPhrase = SessionHost.shared.updateUserPhraseWeight(userPhrase, action)
    guard SessionHost.shared.writeUserPhrasesAtOnce(userPhrase, action == .toFilter) else { return false }

    // 後續操作。
    let valueCurrent = userPhrase.value
    let valueReversed = SessionHost.shared.crossConvert(valueCurrent)
    let separator = inputHandler.keySeparator.isEmpty
      ? Homa.Assembler.theSeparator
      : inputHandler.keySeparator
    let headReading = userPhrase.keyArray.joined(separator: separator)
    var candidateTargets = inputHandler.activePOMCandidateValues()
    if !valueCurrent.isEmpty {
      candidateTargets.append(valueCurrent)
    }
    let uniqueCandidateTargets = Array(Set(candidateTargets.filter { !$0.isEmpty }))

    // 更新組字器內的單元圖資料。
    // 註：如果已經排除的內容是該讀音下唯一的記錄的話，
    // 則該內容的節點會繼續殘留在組字區內，只是無法再重新輸入了。
    _ = inputHandler.updateUnigramData()

    // 因為上述操作不會立即生效（除非遞交組字區），所以暫時塞入臨時資料記錄。
    // 該臨時資料記錄會在接下來的語言模組資料重載過程中被自動清除。
    inputHandler.currentLM.insertTemporaryData(
      unigram: .init(
        keyArray: userPhrase.keyArray,
        value: userPhrase.value,
        score: userPhrase.weight ?? 0
      ),
      isFiltering: addToFilter
    )
    // 將清詞（bleach）延遲至 asyncOnMain 執行，避免同步 JSON encode + disk write 阻塞 main thread。
    let bleachTargets = uniqueCandidateTargets
    let bleachHeadReadings = headReading
    let bleachReversedValue = valueReversed
    if !bleachTargets.isEmpty || !bleachHeadReadings.isEmpty {
      asyncOnMain {
        if !bleachTargets.isEmpty {
          SessionHost.shared.bleachSpecifiedSuggestions(bleachTargets, nil, IMEApp.currentInputMode)
        }
        if !bleachHeadReadings.isEmpty {
          SessionHost.shared.bleachSpecifiedSuggestions([], [bleachHeadReadings], IMEApp.currentInputMode)
        }
        SessionHost.shared.bleachSpecifiedSuggestions(
          [bleachReversedValue], nil, IMEApp.currentInputMode.reversed
        )
      }
    }
    return true
  }
}

// MARK: - Session + CtlCandidateDelegate

extension SessionProtocol {
  public var isCandidateState: Bool { state.isCandidateContainer }
  public var showCodePointForCurrentCandidate: Bool { prefs.showCodePointInCandidateUI }

  /// 當前選字窗是否為縱向。（縱排輸入時，只會啟用縱排選字窗。）
  public var isVerticalCandidateWindow: Bool {
    isVerticalTyping
      || !prefs.useHorizontalCandidateList
      || isServiceMenuState
  }

  public var isCandidateWindowSingleLine: Bool {
    isVerticalTyping
      || prefs.candidateWindowShowOnlyOneLine
      || (prefs.enforceSingleLineCandidateWindowLayout4SCPC && prefs.useSCPCTypingMode)
      || state.type == .ofInputting && state.isCandidateContainer
      || isServiceMenuState
  }

  public var localeForFontFallbacks: String {
    switch inputMode {
    case .imeModeCHS: return "zh-Hans"
    case .imeModeCHT:
      if prefs.kanjiConversionPreferences == 0 {
        return "zh-Hant"
      }
      return "ja"
    default: return ""
    }
  }

  public var clientAccentColor: HSBA? {
    var nullResponse = !prefs.respectClientAccentColor
    nullResponse = nullResponse || prefs.kanjiConversionPreferences != 0
    guard !nullResponse else { return nil }
    guard !SessionHost.shared.isAccentColorCustomized() else { return nil }
    if #unavailable(macOS 10.14) { return nil }
    // 使用現成的 clientBundleIdentifier（已在 performServerActivation 期間記載）。
    return SessionHost.shared.findAccentColor(clientBundleIdentifier)
  }

  public var shouldAutoExpandCandidates: Bool {
    guard !prefs.alwaysExpandCandidateWindow else { return true }
    switch state.type {
    case .ofAssociates: return true
    case .ofCandidates:
      guard let candidateUI = ui?.candidateUI else { return false }
      return candidateUI.visible && candidateUI.expanded
    case .ofSymbolTable: return state.node.previous != nil
    default: return false
    }
  }

  public var isCandidateContextMenuEnabled: Bool {
    let blacklistedClients: Set<String> = [
      "com.apple.Spotlight",
      "com.raycast.macos",
    ]
    let conditions: [Bool] = [
      state.type == .ofCandidates,
      blacklistedClients.allSatisfy { !clientBundleIdentifier.contains($0) },
    ]
    return conditions.reduce(true) { $0 && $1 }
  }

  public var showReverseLookupResult: Bool { prefs.showReverseLookupInCandidateUI }

  public func getCandidate(at index: Int) -> CandidateInState? {
    guard state.candidates.indices.contains(index) else { return nil }
    return state.candidates[index]
  }

  public func checkIsMacroTokenResult(_ index: Int) -> Bool {
    guard state.isCandidateContainer else { return false }
    guard state.candidates.indices.contains(index) else { return false }
    let target = state.candidates[index]
    let keyChain = target.keyArray.joined(separator: "-")
    let hashKey = "\(keyChain)\t\(target.value)".hashValue
    let result = Set(inputMode.langModel.inputTokenHashesArray).contains(hashKey)
    if result { SessionHost.shared.soundBuzz() }
    return result
  }

  public func candidateToolTip(shortened: Bool) -> String {
    if state.type == .ofAssociates {
      return shortened ? "⇧" : "i18n:StateOfInputting.Tooltip.HoldShiftChooseAssociates".i18n
    } else if isFuriousCopilotCandidateWindowVisible {
      // 狂拼 copilot 候選窗：就地選字需 Shift＋選字鍵（IH117C 語義不變）。
      // 該窗常駐於 Inputting 狀態、與 tooltip 窗重疊，故以專屬 Shift 提示取代
      // 「⚡️ 快速候選」（後者原為非磁帶下 quick-candidates 分支的顯示內容）。
      return "i18n:CandidateWindow.Tooltip.HoldShiftToSelect".i18n
    } else if state.type == .ofInputting, state.isCandidateContainer {
      let useShift = inputMode.langModel.areCassetteCandidateKeysShiftHeld
      let theEmoji = useShift ? "⬆️" : "⚡️"
      return shortened ? theEmoji : "\(theEmoji) " + "i18n:StateOfInputting.Tooltip.QuickCandidates".i18n
    } else if prefs.cassetteEnabled {
      return shortened ? "📼" : "📼 " + "i18n:UserDef.kUsingHotKeyCassette.shortTitle".i18n
    } else if state.type == .ofSymbolTable, state.node.containsCandidateServices {
      return shortened ? "🌎" : "🌎 " + "i18n:Menu.ServiceMenu".i18n
    }
    return ""
  }

  @discardableResult
  public func reverseLookup(for value: String) -> [String] {
    let blankResult: [String] = []
    // 狂拼模式的讀音回顯：這是使用者自己敲入的字母流的即時回顯（tooltip 已因與
    // 候選窗重疊的問題被抑制，這是狂拼模式下敲鍵內容的唯一可見管道），並非反查，
    // 因此刻意不受 showReverseLookupInCandidateUI 總開關與 isVerticalTyping 守衛節制。
    if isFuriousCopilotCandidateWindowVisible,
       let romaji = inputHandler?.composer.romajiBuffer, !romaji.isEmpty {
      return [romaji]
    }
    // 這一段專門處理「反查」。
    if !prefs.showReverseLookupInCandidateUI { return blankResult }
    if state.type == .ofInputting, state.isCandidateContainer,
       inputHandler?.currentLM.nullCandidateInCassette == value {
      return blankResult
    }
    // 縱排輸入的場合，選字窗沒有足夠的空間顯示反查結果。
    if isVerticalTyping { return blankResult }
    if value.isEmpty { return blankResult } // 空字串沒有需要反查的東西。
    if value.contains("_") { return blankResult }
    // 因為唯音輸入法的反查結果僅由磁帶模組負責，所以相關運算挪至 LMInstantiator 內處理。
    return inputMode.langModel.cassetteReverseLookup(for: value)
  }

  public func candidatePairs(conv: Bool = false) -> [CandidateInState] {
    if !state.isCandidateContainer || state.candidates.isEmpty { return [] }
    let keyChainOfFirstCandidate = state.candidates[0].keyArray.joined()
    let punctuationKeyHeaderMatched = keyChainOfFirstCandidate.contains("_punctuation")
    if !conv || prefs.cns11643Enabled || punctuationKeyHeaderMatched {
      return state.candidates
    }
    let convertedCandidates = state.candidates.map {
      theCandidatePair -> (
        keyArray: [String],
        value: String
      ) in
      var theCandidatePair = theCandidatePair
      theCandidatePair.value = SessionHost.shared.kanjiConversionIfRequired(
        theCandidatePair.value
      )
      return theCandidatePair
    }
    return convertedCandidates
  }

  public func candidatePairHighlightChanged(at theIndex: Int?) {
    guard let inputHandler = inputHandler else { return }
    guard state.highlightedCandidateIndex != theIndex else { return }
    state.highlightedCandidateIndex = theIndex
    guard state.isCandidateContainer, let theIndex else { return }
    // 狂拼 copilot 窗：高亮即時反映到組字區（scratch 預覽、不計 POM、不動真組字器）。
    if isFuriousCopilotCandidateWindowVisible,
       (0 ..< state.candidates.count).contains(theIndex) {
      let candidate = state.candidates[theIndex]
      inputHandler.furiousHighlightOverride = candidate
      inputHandler.previewFuriousHighlightedCandidate(candidate)
      return
    }
    switch state.type {
    case .ofCandidates where (0 ..< state.candidates.count).contains(theIndex):
      inputHandler.previewCurrentCandidateAtCompositionBuffer()
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(theIndex):
      let node = state.node.members[theIndex]
      if node.members.isEmpty {
        state.data.displayTextSegments = [node.name] // 會同步更新 `displayedText`。
        state.data.cursor = node.name.count
        state.data.marker = state.data.cursor
      } else {
        state.data.displayTextSegments.removeAll() // 會同步更新 `displayedText`。
        state.data.cursor = 0
        state.data.marker = 0
      }
      updateCompositionBufferDisplay()
    default: break
    }

    voiceOverTask: if voiceOverIsOn() {
      let narratable = inputMode.langModel.prepareCandidateNarrationPair(state)
      guard let narratable else { break voiceOverTask }
      SessionHost.shared.narrate(narratable.readingToNarrate)
    }
  }

  public func candidatePairSelectionConfirmed(at index: Int) {
    guard let inputHandler = inputHandler else { return }
    guard state.isCandidateContainer else { return }
    switch state.type {
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(index):
      let node = state.node.members[index]
      if !node.members.isEmpty {
        switchState(.ofSymbolTable(node: node))
      } else if let serviceNode = node.asServiceMenuNode {
        switch serviceNode.service.value {
        case let .url(theURL):
          // 雖然 Safari 理論上是啟動速度最快的，但這裡還是尊重一下使用者各自電腦內的偏好設定好了。
          SessionHost.shared.openURL(theURL)
        case .selector:
          if let response = SessionHost.shared.responseFromSelector(serviceNode.service) {
            SessionHost.shared.setPasteboardString(response)
            SessionHost.shared
              .notify("i18n:candidateServiceMenu.selectorResponse.succeeded".i18n)
          } else {
            callError("4DFDC487: Candidate Text Service Selector Responsiveness Failure.")
            SessionHost.shared.notify("i18n:candidateServiceMenu.selectorResponse.failed".i18n)
          }
        }
        switchState(.ofAbortion())
      } else {
        switchState(.ofCommitting(textToCommit: node.name))
      }
    case .ofCandidates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      inputHandler.consolidateNode(
        candidate: selectedValue,
        respectCursorPushing: true,
        preConsolidate: prefs.consolidateContextOnCandidateSelection,
        skipObservation: !prefs.fetchSuggestionsFromPerceptionOverrideModel,
        explicitlyChosen: true
      )
      var result: State = inputHandler.generateStateOfInputting()
      defer { switchState(result) } // 這是最終輸出結果。
      if prefs.useSCPCTypingMode {
        switchState(.ofCommitting(textToCommit: inputHandler.committableDisplayText(sansReading: true)))
        // 此時是逐字選字模式，所以「selectedValue.value」是單個字、不用追加處理。
        if prefs.associatedPhrasesEnabled {
          let associates = inputHandler.generateStateOfAssociates(
            withPair: .init(keyArray: selectedValue.keyArray, value: selectedValue.value)
          )
          result = associates.candidates.isEmpty ? .ofEmpty() : associates
        } else {
          result = .ofEmpty()
        }
      }
    case .ofAssociates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      var result: State = .ofEmpty()
      defer { switchState(result) } // 這是最終輸出結果。
      switchState(.ofCommitting(textToCommit: selectedValue.value))
      guard prefs.associatedPhrasesEnabled else { return }
      // 此時是關聯詞語選字模式，所以「selectedValue.value」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.value.last?.description else { return }
      let associates = inputHandler.generateStateOfAssociates(
        withPair: .init(keyArray: selectedValue.keyArray, value: valueKept)
      )
      if !associates.candidates.isEmpty { result = associates }
    case .ofInputting where (0 ..< state.candidates.count).contains(index):
      // 狂拼模式：前方候選就地選字（滑鼠點選／Shift+選字鍵亦走這裡）。
      // 使用者顯式選字＝符合 POM 記憶的明確意志，故傳入 memorizePOM: true。
      if inputHandler.isFuriousTypingModeEffective {
        let selectedValue = state.candidates[index]
        inputHandler.confirmFuriousFrontCandidate(selectedValue, memorizePOM: true)
        switchState(inputHandler.generateStateOfInputting())
        return
      }
      // 以下為磁帶語義。
      let chosenStr = state.candidates[index].value
      guard !chosenStr.isEmpty, chosenStr != inputHandler.currentLM.nullCandidateInCassette else {
        callError("907F9F64")
        return
      }
      let strToCommitFirst = inputHandler.committableDisplayText(sansReading: true)
      switchState(.ofCommitting(textToCommit: strToCommitFirst + chosenStr))
    default: return
    }
  }

  public func candidatePairContextMenuActionTriggered(
    at index: Int, action: CandidateContextMenuAction
  ) {
    guard isCandidateContextMenuEnabled else { return }
    candidatePairManipulated(at: index, action: action)
  }

  public func candidatePairManipulated(
    at index: Int,
    action: CandidateContextMenuAction
  ) {
    guard let inputHandler = inputHandler else { return }

    let rawPair = state.candidates[index]
    var userPhrase = UserPhraseInsertable(
      keyArray: rawPair.keyArray,
      value: rawPair.value,
      inputMode: inputMode
    )
    userPhrase = SessionHost.shared.updateUserPhraseWeight(userPhrase, action)

    let succeeded = SessionHost.shared.writeUserPhrasesAtOnce(userPhrase, action == .toFilter)

    // 直接同步重載目前使用中的語言模組，以避免單元測試時不同 LM 實例之間資料不同步。
    if UserDefaults.pendingUnitTests {
      let phrasesPath = SessionHost.shared.userDictDataURL(inputMode, .thePhrases).path
      if action == .toFilter {
        inputHandler.currentLM.reloadUserFilterDirectly(
          path: SessionHost.shared.userDictDataURL(inputMode, .theFilter).path
        )
      } else {
        inputHandler.currentLM.loadUserPhrasesData(path: phrasesPath, filterPath: nil)
      }
    }

    // 後續操作。
    let valueCurrent = userPhrase.value
    let valueReversed = SessionHost.shared.crossConvert(valueCurrent)

    // 因為上述操作不會立即生效（除非遞交組字區），所以暫時塞入臨時資料記錄。
    // 該臨時資料記錄會在接下來的語言模組資料重載過程中被自動清除。
    inputMode.langModel.insertTemporaryData(
      unigram: .init(
        keyArray: userPhrase.keyArray,
        value: userPhrase.value,
        score: userPhrase.weight ?? 0
      ),
      isFiltering: action == .toFilter
    )

    // 開始針對使用者漸退模組的清詞處理
    SessionHost.shared.bleachSpecifiedSuggestions([valueCurrent], nil, IMEApp.currentInputMode)
    SessionHost.shared.bleachSpecifiedSuggestions(
      [valueReversed], nil, IMEApp.currentInputMode.reversed
    )
    // 更新組字器內的單元圖資料。
    let updateResult = inputHandler.updateUnigramData()
    // 清詞完畢

    var newState: State =
      updateResult
        ? inputHandler.generateStateOfCandidates(dodge: false)
        : .ofCommitting(textToCommit: inputHandler.committableDisplayText(sansReading: true))
    newState.tooltipDuration = 1.85
    var tooltipMessage = ""
    switch action {
    case .toBoost:
      newState.data.tooltipColorState = .normal
      tooltipMessage = succeeded
        ? "i18n:PhraseOperation.BoostCandidateSucceeded"
        : "i18n:PhraseOperation.BoostCandidateFailed"
    case .toNerf:
      newState.data.tooltipColorState = .succeeded
      tooltipMessage = succeeded
        ? "i18n:PhraseOperation.NerfCandidateSucceeded"
        : "i18n:PhraseOperation.NerfCandidateFailed"
    case .toFilter:
      newState.data.tooltipColorState = .warning
      tooltipMessage = succeeded
        ? "i18n:PhraseOperation.FilterCandidateSucceeded"
        : "i18n:PhraseOperation.FilterCandidateFailed"
    }
    if !succeeded { newState.data.tooltipColorState = .redAlert }
    newState.tooltip = tooltipMessage.i18n
    switchState(newState)
  }
}

extension SessionProtocol {
  // 0: Always Off, 1: Always On, 2: Only When VoiceOver is On
  private func voiceOverIsOn() -> Bool {
    switch prefs.candidateNarrationToggleType {
    case 1: return true
    case 2: return SessionHost.shared.isVoiceOverEnabled()
    default: return false
    }
  }
}
