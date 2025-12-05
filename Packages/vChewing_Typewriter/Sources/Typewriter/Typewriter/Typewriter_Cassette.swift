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

    // 準備處理 `%quick` 選字行為。
    var handleQuickCandidate = true
    if currentLM.areCassetteCandidateKeysShiftHeld { handleQuickCandidate = input.isShiftHold }
    let hasQuickCandidates: Bool = state.type == .ofInputting && state.isCandidateContainer

    // 處理 `%symboldef` 選字行為。
    if handler.handleCassetteSymbolTable(input: input) {
      return true
    } else if hasQuickCandidates, input.text != currentLM.cassetteWildcardKey {
      // 處理 `%quick` 選字行為（當且僅當與 `%symboldef` 衝突的情況下）。
      let candidateHandled = handler.handleCandidate(input: input, ignoringModifiers: true)
      guard !(handleQuickCandidate && candidateHandled) else { return true }
    } else {
      // 處理 `%quick` 選字行為。
      let candidateHandled = handler.handleCandidate(input: input, ignoringModifiers: true)
      guard !(hasQuickCandidates && candidateHandled)
      else { return true }
    }

    // 正式處理。
    var wildcardKey: String { currentLM.cassetteWildcardKey } // 花牌鍵。
    let quickPhraseKey = currentLM.cassetteQuickPhraseCommissionKey
    let inputText = input.text
    let isQuickPhraseKeyInput: Bool = {
      guard let quickPhraseKey, !quickPhraseKey.isEmpty else { return false }
      return inputText == quickPhraseKey
    }()
    let isWildcardKeyInput: Bool = (inputText == wildcardKey && !wildcardKey.isEmpty)

    let skipStrokeHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isCommandHold // || input.isShiftHold
    var confirmCombination = input.isSpace

    var isLongestPossibleKeyFormed: Bool {
      guard !isWildcardKeyInput,
            prefs.autoCompositeWithLongestPossibleCassetteKey
      else { return false }
      return !currentLM.hasCassetteWildcardResultsFor(
        key: handler.calligrapher
      ) && !handler.calligrapher.isEmpty
    }

    var isStrokesFull: Bool {
      handler.calligrapher.count >= currentLM.maxCassetteKeyLength || isLongestPossibleKeyFormed
    }

    prehandling: if !skipStrokeHandling && currentLM.isThisCassetteKeyAllowed(key: inputText) {
      if handler.calligrapher.isEmpty, isWildcardKeyInput {
        errorCallback("3606B9C0")
        if input.beganWithLetter {
          var newEmptyState =
            handler.assembler.isEmpty
              ? State.ofEmpty()
              : handler.generateStateOfInputting()
          newEmptyState.tooltip = "Wildcard key cannot be the initial key.".localized
          newEmptyState.data.tooltipColorState = .redAlert
          newEmptyState.tooltipDuration = 1.0
          session.switchState(newEmptyState)
          return true
        }
        handler.notificationCallback?(
          "Wildcard key cannot be the initial key.".localized
        )
        return nil
      }
      if isStrokesFull {
        errorCallback("2268DD51: calligrapher is full, clearing calligrapher.")
        handler.calligrapher.removeAll()
      } else {
        handler.calligrapher.append(inputText)
      }
      if isWildcardKeyInput {
        break prehandling
      }

      if !isStrokesFull {
        var result = handler.generateStateOfInputting()
        if !handler.calligrapher.isEmpty,
           let fetched = currentLM.cassetteQuickSetsFor(key: handler.calligrapher)?.split(
             separator: "\t"
           ) {
          result.candidates = fetched.enumerated().map {
            (keyArray: [($0.offset + 1).description], value: $0.element.description)
          }
        }
        session.switchState(result)
        return true
      }
    }

    if isQuickPhraseKeyInput {
      guard !handler.calligrapher.isEmpty else {
        errorCallback("8E1F0B8C: Quick phrase key requires existing strokes.")
        return true
      }
      let phrases = currentLM.cassetteQuickPhrases(for: handler.calligrapher)
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

    if !(state.type == .ofInputting && state.isCandidateContainer) {
      confirmCombination = confirmCombination || input.isEnter
    }

    var combineStrokes =
      (isStrokesFull && prefs.autoCompositeWithLongestPossibleCassetteKey)
        || (isWildcardKeyInput && !handler.calligrapher.isEmpty)

    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 calligrapher 內的筆畫來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    combineStrokes = combineStrokes || (!handler.calligrapher.isEmpty && confirmCombination)
    ifCombineStrokes: if combineStrokes {
      // 警告：calligrapher 不能為空，否則組字引擎會炸。
      guard !handler.calligrapher.isEmpty else { break ifCombineStrokes }
      if input.isControlHold, input.isCommandHold, input.isEnter,
         !input.isOptionHold, !input.isShiftHold, handler.composer.isEmpty {
        return handler.handleEnter(input: input, readingOnly: true)
      }
      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(keyArray: [handler.calligrapher]) {
        errorCallback("B49C0979_Cassette：語彙庫內無「\(handler.calligrapher)」的匹配記錄。")
        handler.calligrapher.removeAll()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch handler.assembler.isEmpty {
        case false: session.switchState(handler.generateStateOfInputting())
        case true: session.switchState(State.ofAbortion())
        }
        return true // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
      if input.isInvalid {
        errorCallback("BFE387CC: 不合規的按鍵輸入。")
        return true
      } else if !handler.assembler.insertKey(handler.calligrapher) {
        errorCallback("61F6B11F: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
        return true
      }

      // 組句。
      handler.assemble()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = handler.commitOverflownComposition

      // 看看漸退記憶模組是否會對目前的狀態給出自動選字建議。
      handler.retrievePOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      handler.calligrapher.removeAll()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = handler.generateStateOfInputting()
      inputting.textToCommit = textToCommit
      session.switchState(inputting)

      /// 逐字選字模式的處理。
      if prefs.useSCPCTypingMode {
        let candidateState: State = handler.generateStateOfCandidates()
        switch candidateState.candidates.count {
        case 2...: session.switchState(candidateState)
        case 1:
          let firstCandidate = candidateState.candidates.first! // 一定會有，所以強制拆包也無妨。
          let reading: [String] = firstCandidate.keyArray
          let text: String = firstCandidate.value
          session.switchState(State.ofCommitting(textToCommit: text))

          if prefs.associatedPhrasesEnabled {
            let associatedCandidates = handler.generateArrayOfAssociates(
              withPairs: [
                .init(
                  keyArray: reading,
                  value: text
                ),
              ]
            )
            session.switchState(
              associatedCandidates.isEmpty
                ? State.ofEmpty()
                : State.ofAssociates(candidates: associatedCandidates)
            )
          }
        default: break
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 SessionCtl 回報給 IMK。
      return true
    }
    return nil
  }
}
