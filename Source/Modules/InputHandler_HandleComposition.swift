// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。

import Shared
import Tekkon

extension InputHandler {
  /// 用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameters:
  ///   - input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(input: InputSignalProtocol) -> Bool? {
    prefs.cassetteEnabled ? handleCassetteComposition(input: input) : handlePhonabetComposition(input: input)
  }

  // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

  /// 用來處理 InputHandler.HandleInput() 當中的與注音输入有關的組字行為。
  /// - Parameters:
  ///   - input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  private func handlePhonabetComposition(input: InputSignalProtocol) -> Bool? {
    guard let delegate = delegate else { return nil }

    var keyConsumedByReading = false
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
      || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold
    let confirmCombination = input.isSpace || input.isEnter

    // 這裡 inputValidityCheck() 是讓注拼槽檢查 charCode 這個 UniChar 是否是合法的注音輸入。
    // 如果是的話，就將這次傳入的這個按鍵訊號塞入注拼槽內且標記為「keyConsumedByReading」。
    // 函式 composer.receiveKey() 可以既接收 String 又接收 UniChar。
    if (!skipPhoneticHandling && composer.inputValidityCheck(key: input.charCode)) || confirmCombination {
      // 引入 macOS 內建注音輸入法的行為，允許用除了陰平以外的聲調鍵覆寫前一個漢字的讀音。
      // 但如果要覆寫的內容會導致游標身後的字音沒有對應的辭典記錄的話，那就只蜂鳴警告一下。
      proc: if [0, 1].contains(prefs.specifyIntonationKeyBehavior), composer.isEmpty, !input.isSpace {
        // prevReading 的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
        guard let prevReading = previousParsableReading, isIntonationKey(input) else { break proc }
        var theComposer = composer
        prevReading.0.charComponents.forEach { theComposer.receiveKey(fromPhonabet: $0) }
        // 發現要覆寫的聲調與覆寫對象的聲調雷同的情況的話，直接跳過處理。
        let oldIntonation: Tekkon.Phonabet = theComposer.intonation
        theComposer.receiveKey(fromString: input.text)
        if theComposer.intonation == oldIntonation, prefs.specifyIntonationKeyBehavior == 1 { break proc }
        theComposer.intonation.clear()
        // 檢查新的漢字字音是否在庫。
        let temporaryReadingKey = theComposer.getComposition()
        if currentLM.hasUnigramsFor(keyArray: [temporaryReadingKey]) {
          compositor.dropKey(direction: .rear)
          walk()  // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
          composer = theComposer
          // 這裡不需要回呼 generateStateOfInputting()，因為當前輸入的聲調鍵一定是合規的、會在之後回呼 generateStateOfInputting()。
        } else {
          delegate.callError("4B0DD2D4：語彙庫內無「\(temporaryReadingKey)」的匹配記錄，放棄覆寫游標身後的內容。")
          return true
        }
      }

      // 鐵恨引擎並不具備對 Enter (CR / LF) 鍵的具體判斷能力，所以在這裡單獨處理。
      composer.receiveKey(fromString: confirmCombination ? " " : input.text)
      keyConsumedByReading = true

      // 沒有調號的話，只需要 setInlineDisplayWithCursor() 且終止處理（return true）即可。
      // 有調號的話，則不需要這樣，而是轉而繼續在此之後的處理。
      if !composer.hasIntonation() {
        delegate.switchState(generateStateOfInputting())
        return true
      }
    }

    let readingKey = composer.getComposition()  // 拿取用來進行索引檢索用的注音。
    // 如果輸入法的辭典索引是漢語拼音的話，要注意上一行拿到的內容得是漢語拼音。
    var composeReading = composer.hasIntonation() && composer.inputValidityCheck(key: input.charCode)  // 這裡不需要做排他性判斷。
    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 composer 內的注音來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    // 這裡必須使用 composer.value.isEmpty，因為只有這樣才能真正檢測 composer 是否已經有陰平聲調了。
    composeReading = composeReading || (!composer.isEmpty && confirmCombination)
    // readingKey 不能為空。
    composeReading = composeReading && !readingKey.isEmpty
    if composeReading {
      if input.isControlHold, input.isCommandHold, input.isEnter,
        !input.isOptionHold, !input.isShiftHold, compositor.isEmpty
      {
        return handleCtrlCommandEnter()
      }
      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(keyArray: [readingKey]) {
        delegate.callError("B49C0979：語彙庫內無「\(readingKey)」的匹配記錄。")

        if prefs.keepReadingUponCompositionError {
          composer.intonation.clear()  // 砍掉聲調。
          delegate.switchState(generateStateOfInputting())
          return true
        }

        composer.clear()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch compositor.isEmpty {
          case false: delegate.switchState(generateStateOfInputting())
          case true: delegate.switchState(IMEState.ofAbortion())
        }
        return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      if !compositor.insertKey(readingKey) {
        delegate.callError("3CF278C9: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
        return true
      }

      // 讓組字器反爬軌格。
      walk()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = commitOverflownComposition

      // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議。
      retrieveUOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      composer.clear()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = generateStateOfInputting()
      inputting.textToCommit = textToCommit
      delegate.switchState(inputting)

      /// 逐字選字模式的處理。
      if prefs.useSCPCTypingMode {
        let candidateState: IMEStateProtocol = generateStateOfCandidates()
        switch candidateState.candidates.count {
          case 2...: delegate.switchState(candidateState)
          case 1:
            let firstCandidate = candidateState.candidates.first!  // 一定會有，所以強制拆包也無妨。
            let reading: String = firstCandidate.0.joined(separator: compositor.separator)
            let text: String = firstCandidate.1
            delegate.switchState(IMEState.ofCommitting(textToCommit: text))

            if !prefs.associatedPhrasesEnabled {
              delegate.switchState(IMEState.ofEmpty())
            } else {
              let associatedPhrases = generateStateOfAssociates(withPair: .init(keyArray: [reading], value: text))
              delegate.switchState(associatedPhrases.candidates.isEmpty ? IMEState.ofEmpty() : associatedPhrases)
            }
          default: break
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 SessionCtl 回報給 IMK。
      return true
    }

    /// 是說此時注拼槽並非為空、卻還沒組音。這種情況下只可能是「注拼槽內只有聲調」。
    /// 但這裡不處理陰平聲調。
    if keyConsumedByReading {
      if readingKey.isEmpty {
        composer.clear()
        return nil
      }
      // 以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      delegate.switchState(generateStateOfInputting())
      return true
    }
    return nil
  }
}

// MARK: - 磁帶模式的組字支援。

extension InputHandler {
  /// 用來處理 InputHandler.HandleInput() 當中的與磁帶模組有關的組字行為。
  /// - Parameters:
  ///   - input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  private func handleCassetteComposition(input: InputSignalProtocol) -> Bool? {
    guard let delegate = delegate else { return nil }
    var wildcardKey: String { currentLM.cassetteWildcardKey }  // 花牌鍵。
    let isWildcardKeyInput: Bool = (input.text == wildcardKey && !wildcardKey.isEmpty)

    var keyConsumedByStrokes = false
    let skipStrokeHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
      || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold
    let confirmCombination = input.isSpace || input.isEnter

    var isLongestPossibleKeyFormed: Bool {
      guard !isWildcardKeyInput, prefs.autoCompositeWithLongestPossibleCassetteKey else { return false }
      return !currentLM.hasCassetteWildcardResultsFor(key: calligrapher) && !calligrapher.isEmpty
    }

    var isStrokesFull: Bool {
      calligrapher.count >= currentLM.maxCassetteKeyLength || isLongestPossibleKeyFormed
    }

    prehandling: if !skipStrokeHandling && currentLM.isThisCassetteKeyAllowed(key: input.text) {
      if calligrapher.isEmpty, isWildcardKeyInput {
        delegate.callError("3606B9C0")
        var newEmptyState = compositor.isEmpty ? IMEState.ofEmpty() : generateStateOfInputting()
        newEmptyState.tooltip = NSLocalizedString("Wildcard key cannot be the initial key.", comment: "") + "　　"
        newEmptyState.data.tooltipColorState = .redAlert
        newEmptyState.tooltipDuration = 1.0
        delegate.switchState(newEmptyState)
        return true
      }
      if isStrokesFull {
        delegate.callError("2268DD51: calligrapher is full, clearing calligrapher.")
        calligrapher.removeAll()
      } else {
        calligrapher.append(input.text)
      }
      if isWildcardKeyInput {
        break prehandling
      }
      keyConsumedByStrokes = true

      if !isStrokesFull {
        delegate.switchState(generateStateOfInputting())
        return true
      }
    }

    var combineStrokes =
      (isStrokesFull && prefs.autoCompositeWithLongestPossibleCassetteKey)
      || (isWildcardKeyInput && !calligrapher.isEmpty)

    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 calligrapher 內的筆畫來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    combineStrokes = combineStrokes || (!calligrapher.isEmpty && confirmCombination)
    if combineStrokes {
      if input.isControlHold, input.isCommandHold, input.isEnter,
        !input.isOptionHold, !input.isShiftHold, composer.isEmpty
      {
        return handleCtrlCommandEnter()
      }
      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(keyArray: [calligrapher]) {
        delegate.callError("B49C0979_Cassette：語彙庫內無「\(calligrapher)」的匹配記錄。")

        calligrapher.removeAll()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch compositor.isEmpty {
          case false: delegate.switchState(generateStateOfInputting())
          case true: delegate.switchState(IMEState.ofAbortion())
        }
        return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      if !compositor.insertKey(calligrapher) {
        delegate.callError("61F6B11F: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
        return true
      }

      // 讓組字器反爬軌格。
      walk()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = commitOverflownComposition

      // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議。
      retrieveUOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      calligrapher.removeAll()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = generateStateOfInputting()
      inputting.textToCommit = textToCommit
      delegate.switchState(inputting)

      /// 逐字選字模式的處理，與注音輸入的部分完全雷同。
      if prefs.useSCPCTypingMode {
        let candidateState: IMEStateProtocol = generateStateOfCandidates()
        switch candidateState.candidates.count {
          case 2...: delegate.switchState(candidateState)
          case 1:
            let firstCandidate = candidateState.candidates.first!  // 一定會有，所以強制拆包也無妨。
            let reading: String = firstCandidate.0.joined(separator: compositor.separator)
            let text: String = firstCandidate.1
            delegate.switchState(IMEState.ofCommitting(textToCommit: text))

            if !prefs.associatedPhrasesEnabled {
              delegate.switchState(IMEState.ofEmpty())
            } else {
              let associatedPhrases = generateStateOfAssociates(withPair: .init(keyArray: [reading], value: text))
              delegate.switchState(associatedPhrases.candidates.isEmpty ? IMEState.ofEmpty() : associatedPhrases)
            }
          default: break
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 SessionCtl 回報給 IMK。
      return true
    }

    /// 是說此時注拼槽並非為空、卻還沒組音。這種情況下只可能是「注拼槽內只有聲調」。
    if keyConsumedByStrokes {
      // 以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      delegate.switchState(generateStateOfInputting())
      return true
    }
    return nil
  }
}
