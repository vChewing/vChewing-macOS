// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - CassetteTypewriter

/// 磁帶模式的組字支援。
@frozen
public struct CassetteTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  /// 用來處理 InputHandler.HandleInput() 當中的與磁帶模組有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    let state = session.state
    let currentLM = handler.currentLM
    let prefs = handler.prefs
    let wildcardKey = currentLM.cassetteWildcardKey
    let quickPhraseCommissionKey = currentLM.cassetteQuickPhraseCommissionKey

    // 先處理快選（%quick 與 %symboldef），避免後續流程誤吞按鍵。
    if processCassetteQuickSelection(input: input, state: state, wildcardKey: wildcardKey) {
      return true
    }

    let inputText = input.text
    let isWildcardKeyInput = inputText == wildcardKey && !wildcardKey.isEmpty
    let isQuickPhraseKeyInput = matchesQuickPhraseKey(inputText, key: quickPhraseCommissionKey)
    var confirmCombination = input.isSpace

    let skipStrokeHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isCommandHold

    let isLongestPossibleKeyFormed = shouldFormLongestCassetteKey(
      isWildcardKeyInput: isWildcardKeyInput
    )
    let isStrokesFull = handler.calligrapher.count >= currentLM.maxCassetteKeyLength
      || isLongestPossibleKeyFormed

    // 進行筆畫預處理：阻擋非法按鍵、處理花牌開頭、更新組筆狀態與快選清單。
    if let handled = handleStrokePreprocessing(
      inputText: inputText,
      isWildcardKeyInput: isWildcardKeyInput,
      isStrokesFull: isStrokesFull,
      skipStrokeHandling: skipStrokeHandling,
      beganWithLetter: input.beganWithLetter,
      session: session
    ) {
      return handled
    }

    // 快句鍵：在組筆區已有內容時直接觸發，支援唯一候選快速提交或進入符號表。
    if isQuickPhraseKeyInput {
      return handleQuickPhraseKey(
        session: session,
        quickPhraseKey: quickPhraseCommissionKey,
        phrases: currentLM.cassetteQuickPhrases(for: handler.calligrapher)
      )
    }

    if !(state.type == .ofInputting && state.isCandidateContainer) {
      confirmCombination = confirmCombination || input.isEnter
    }

    // 決定是否要進行組字：滿筆長自動組字、花牌搭配筆畫、或空白/Enter 強制組字。
    var combineStrokes =
      (isStrokesFull && prefs.autoCompositeWithLongestPossibleCassetteKey)
        || (isWildcardKeyInput && !handler.calligrapher.isEmpty)
    combineStrokes = combineStrokes || (!handler.calligrapher.isEmpty && confirmCombination)

    if combineStrokes {
      return handleCassetteCombination(
        input: input,
        isWildcardKeyInput,
        session: session,
        prefs: prefs
      )
    }
    return nil
  }

  // MARK: Private

  private func processCassetteQuickSelection(
    input: some InputSignalProtocol,
    state: State,
    wildcardKey: String
  )
    -> Bool {
    let currentLM = handler.currentLM
    let hasQuickCandidates = state.type == .ofInputting && state.isCandidateContainer
    var handleQuickCandidate = true
    if currentLM.areCassetteCandidateKeysShiftHeld { handleQuickCandidate = input.isShiftHold }

    if handler.handleCassetteSymbolTable(input: input) { return true }

    let candidateHandled = handler.handleCandidate(input: input, ignoringModifiers: true)
    if hasQuickCandidates, input.text != wildcardKey {
      return handleQuickCandidate && candidateHandled
    }
    return hasQuickCandidates && candidateHandled
  }

  private func matchesQuickPhraseKey(_ inputText: String, key: String?) -> Bool {
    guard let key, !key.isEmpty else { return false }
    return inputText == key
  }

  private func shouldFormLongestCassetteKey(
    isWildcardKeyInput: Bool
  )
    -> Bool {
    guard !isWildcardKeyInput, handler.prefs.autoCompositeWithLongestPossibleCassetteKey else {
      return false
    }
    return !handler.currentLM.hasCassetteWildcardResultsFor(key: handler.calligrapher)
      && !handler.calligrapher.isEmpty
  }

  private func handleStrokePreprocessing(
    inputText: String,
    isWildcardKeyInput: Bool,
    isStrokesFull: Bool,
    skipStrokeHandling: Bool,
    beganWithLetter: Bool,
    session: Session
  )
    -> Bool? {
    let currentLM = handler.currentLM
    guard !skipStrokeHandling, currentLM.isThisCassetteKeyAllowed(key: inputText) else {
      return nil
    }
    if handler.calligrapher.isEmpty, isWildcardKeyInput {
      return handleLeadingWildcard(session: session, beganWithLetter: beganWithLetter)
    }
    if isStrokesFull {
      errorCallback("2268DD51: calligrapher is full, clearing calligrapher.")
      handler.calligrapher.removeAll()
    } else {
      handler.calligrapher.append(inputText)
    }
    if isWildcardKeyInput { return nil }
    return renderQuickSetsIfNeeded(session: session, isStrokesFull: isStrokesFull)
  }

  private func handleLeadingWildcard(session: Session, beganWithLetter: Bool) -> Bool? {
    errorCallback("3606B9C0")
    if beganWithLetter {
      var newEmptyState = handler.assembler.isEmpty ? State.ofEmpty() : handler.generateStateOfInputting()
      newEmptyState.tooltip = "i18n:Validation.wildcardKeyCannotBeInitialKey".localized
      newEmptyState.data.tooltipColorState = .redAlert
      newEmptyState.tooltipDuration = 1.0
      session.switchState(newEmptyState)
      return true
    }
    handler.notificationCallback?("i18n:Validation.wildcardKeyCannotBeInitialKey".localized)
    return nil
  }

  private func renderQuickSetsIfNeeded(session: Session, isStrokesFull: Bool) -> Bool? {
    guard !isStrokesFull else { return nil }
    var result = handler.generateStateOfInputting()
    if !handler.calligrapher.isEmpty,
       let fetched = handler.currentLM.cassetteQuickSetsFor(key: handler.calligrapher)?.split(
         separator: "\t"
       ) {
      result.candidates = fetched.enumerated().map {
        (keyArray: [($0.offset + 1).description], value: $0.element.description)
      }
    }
    session.switchState(result)
    return true
  }

  private func handleQuickPhraseKey(
    session: Session,
    quickPhraseKey: String?,
    phrases: [String]?
  )
    -> Bool {
    guard !handler.calligrapher.isEmpty else {
      errorCallback("8E1F0B8C: Quick phrase key requires existing strokes.")
      return true
    }
    guard let phrases, !phrases.isEmpty else {
      errorCallback("ABF4A62D: No quick phrases for key \(handler.calligrapher).")
      return true
    }
    if let quickPhraseKey, !quickPhraseKey.isEmpty, phrases.count == 1,
       let phrase = phrases.first {
      handler.calligrapher.removeAll()
      session.switchState(State.ofCommitting(textToCommit: phrase))
      return true
    }
    let phraseNode = CandidateNode(
      name: handler.calligrapher,
      members: phrases.map { CandidateNode(name: $0) }
    )
    session.switchState(State.ofSymbolTable(node: phraseNode))
    return true
  }

  private func handleCassetteCombination(
    input: some InputSignalProtocol,
    _ isWildcardKeyInput: Bool,
    session: Session,
    prefs: some PrefMgrProtocol
  )
    -> Bool? {
    // 執行真正的組字：插入讀音、呼叫組句、處理溢出、刷新狀態並考慮逐字選字模式。
    let currentLM = handler.currentLM
    guard !handler.calligrapher.isEmpty else { return nil }
    if input.isControlHold, input.isCommandHold, input.isEnter,
       !input.isOptionHold, !input.isShiftHold, handler.composer.isEmpty {
      return handler.handleEnter(input: input, readingOnly: true)
    }
    if !currentLM.hasUnigramsFor(keyArray: [handler.calligrapher]) {
      errorCallback("B49C0979_Cassette：語彙庫內無「\(handler.calligrapher)」的匹配記錄。")
      handler.calligrapher.removeAll()
      switch handler.assembler.isEmpty {
      case false: session.switchState(handler.generateStateOfInputting())
      case true: session.switchState(State.ofAbortion())
      }
      return true
    }
    if input.isInvalid {
      errorCallback("BFE387CC: 不合規的按鍵輸入。")
      return true
    }
    guard handler.assembler.insertKey(handler.calligrapher) else {
      errorCallback("61F6B11F: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
      return true
    }

    handler.assemble()
    let textToCommit = handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.calligrapher.removeAll()

    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)

    // 處理逐字選字。
    handler.handleTypewriterSCPCTasks()
    return true
  }
}
