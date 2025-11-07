// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。

import Foundation

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與組字有關的行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleComposition(input: InputSignalProtocol) -> Bool? {
    // 不處理任何包含不可列印字元的訊號。
    let hardRequirementMet = !input.text.isEmpty && input.charCode.isPrintableUniChar
    switch currentTypingMethod {
    case .codePoint where hardRequirementMet:
      return handleCodePointComposition(input: input)
    case .romanNumerals where hardRequirementMet:
      return handleRomanNumeralComposition(input: input)
    case .haninKeyboardSymbol where [[], .shift].contains(input.keyModifierFlags):
      return handleHaninKeyboardSymbolModeInput(input: input)
    case .vChewingFactory where hardRequirementMet && prefs.cassetteEnabled:
      return handleCassetteComposition(input: input)
    case .vChewingFactory where hardRequirementMet && !prefs.cassetteEnabled:
      return handlePhonabetComposition(input: input)
    default: return nil
    }
  }
}

// MARK: - 注音按鍵輸入處理 (Handle BPMF Keys)

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與注音输入有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  fileprivate func handlePhonabetComposition(input: InputSignalProtocol) -> Bool? {
    guard let session = session else { return nil }
    var inputText = (input.inputTextIgnoringModifiers ?? input.text)
    inputText = inputText.lowercased().applyingTransformFW2HW(reverse: false)
    let existedIntonation = composer.intonation
    var overrideHappened = false

    // 哪怕不啟用支援對「先輸入聲調、後輸入注音」的情況的支援，對 keyConsumedByReading 的處理得保留。
    // 不然的話，「敲 Space 叫出選字窗」的功能會失效。
    // 究其原因，乃是因為威注音所用的鐵恨注拼引擎「有在處理陰平聲調」的緣故。
    // 對於某些動態注音排列，威注音會依賴包括陰平聲調鍵在內的聲調按鍵做結算判斷。
    var keyConsumedByReading = false
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold
    let confirmCombination = input.isSpace || input.isEnter

    func narrateTheComposer(
      with maybeKey: String? = nil,
      when condition: Bool,
      allowDuplicates: Bool = true
    ) {
      guard condition, let narrator else { return }
      let maybeKey = maybeKey ?? composer
        .phonabetKeyForQuery(pronounceableOnly: prefs.acceptLeadingIntonations)
      guard var keyToNarrate = maybeKey else { return }
      if composer.intonation == Phonabet(" ") { keyToNarrate.append("ˉ") }
      narrator.narrate(keyToNarrate, allowDuplicates: allowDuplicates)
    }

    // 這裡 inputValidityCheck() 是讓注拼槽檢查 charCode 這個 UniChar 是否是合法的注音輸入。
    // 如果是的話，就將這次傳入的這個按鍵訊號塞入注拼槽內且標記為「keyConsumedByReading」。
    // 函式 composer.receiveKey() 可以既接收 String 又接收 UniChar。
    if (!skipPhoneticHandling && composer.inputValidityCheck(charStr: inputText)) ||
      confirmCombination {
      // 引入 macOS 內建注音輸入法的行為，允許用除了陰平以外的聲調鍵覆寫前一個漢字的讀音。
      // 但如果要覆寫的內容會導致游標身後的字音沒有對應的辭典記錄的話，那就只蜂鳴警告一下。
      proc: if [0, 1].contains(prefs.specifyIntonationKeyBehavior), composer.isEmpty,
               !input.isSpace {
        // prevReading 的內容分別是：「完整讀音」「去掉聲調的讀音」「是否有聲調」。
        guard let prevReading = previousParsableReading, isIntonationKey(input) else { break proc }
        var theComposer = composer
        prevReading.0.map(\.description).forEach {
          theComposer.receiveKey(fromPhonabet: $0.unicodeScalars.first)
        }
        // 發現要覆寫的聲調與覆寫對象的聲調雷同的情況的話，直接跳過處理。
        let oldIntonation: Phonabet = theComposer.intonation
        theComposer.receiveKey(fromString: inputText)
        if theComposer.intonation == oldIntonation,
           prefs.specifyIntonationKeyBehavior == 1 { break proc }
        if theComposer.hasIntonation() { theComposer.doBackSpace() }
        // 檢查新的漢字字音是否在庫。
        let temporaryReadingKey = theComposer.getComposition()
        if currentLM.hasUnigramsFor(keyArray: [temporaryReadingKey]) {
          assembler.dropKey(direction: .rear)
          assemble() // 這裡必須 Walk 一次、來更新目前被 walk 的內容。
          composer = theComposer
          // 這裡不需要回呼 generateStateOfInputting()，因為當前輸入的聲調鍵一定是合規的、會在之後回呼 generateStateOfInputting()。
          overrideHappened = true
        } else {
          errorCallback?("4B0DD2D4：語彙庫內無「\(temporaryReadingKey)」的匹配記錄，放棄覆寫游標身後的內容。")
          return true
        }
      }

      // 鐵恨引擎並不具備對 Enter (CR / LF) 鍵的具體判斷能力，所以在這裡單獨處理。
      composer.receiveKey(fromString: confirmCombination ? " " : inputText)
      keyConsumedByReading = true
      narrateTheComposer(
        when: !overrideHappened && prefs.readingNarrationCoverage >= 2,
        allowDuplicates: false
      )

      // 沒有調號的話，只需要 setInlineDisplayWithCursor() 且終止處理（return true）即可。
      // 有調號的話，則不需要這樣，而是轉而繼續在此之後的處理。
      if !composer.hasIntonation() {
        session.switchState(generateStateOfInputting())
        return true
      }
    }

    // 這裡不需要做排他性判斷。
    var composeReading = composer.hasIntonation() && composer.inputValidityCheck(charStr: inputText)
    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 composer 內的注音來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    composeReading = composeReading || (!composer.isEmpty && confirmCombination)
    ifComposeReading: if composeReading {
      if input.isControlHold, input.isCommandHold, input.isEnter,
         !input.isOptionHold, !input.isShiftHold, assembler.isEmpty {
        return handleEnter(input: input, readingOnly: true)
      }
      // 拿取用來進行索引檢索用的注音。這裡先不急著處理「僅有注音符號輸入」的情況。
      let maybeKey = composer.phonabetKeyForQuery(pronounceableOnly: prefs.acceptLeadingIntonations)
      guard let readingKey = maybeKey else { break ifComposeReading }
      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(keyArray: [readingKey]) {
        errorCallback?("B49C0979：語彙庫內無「\(readingKey)」的匹配記錄。")

        if prefs.keepReadingUponCompositionError {
          if composer.hasIntonation() { composer.doBackSpace() }
          session.switchState(generateStateOfInputting())
          return true
        }

        composer.clear()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch assembler.isEmpty {
        case false: session.switchState(generateStateOfInputting())
        case true: session.switchState(State.ofAbortion())
        }
        return true // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
      if input.isInvalid {
        errorCallback?("22017F76: 不合規的按鍵輸入。")
        return true
      } else if !assembler.insertKey(readingKey) {
        errorCallback?("3CF278C9: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
        return true
      } else {
        narrateTheComposer(with: readingKey, when: prefs.readingNarrationCoverage == 1)
      }

      // 組句。
      assemble()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = commitOverflownComposition

      // 看看漸退記憶模組是否會對目前的狀態給出自動選字建議。
      retrievePOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      composer.clear()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = generateStateOfInputting()
      inputting.textToCommit = textToCommit
      if overrideHappened {
        inputting.tooltip = "Previous intonation has been overridden.".localized
        inputting.tooltipDuration = 2
        inputting.data.tooltipColorState = .normal
      }
      session.switchState(inputting)

      /// 逐字選字模式的處理。
      if prefs.useSCPCTypingMode {
        let candidateState: State = generateStateOfCandidates()
        switch candidateState.candidates.count {
        case 2...: session.switchState(candidateState)
        case 1:
          let firstCandidate = candidateState.candidates.first! // 一定會有，所以強制拆包也無妨。
          let reading: [String] = firstCandidate.keyArray
          let text: String = firstCandidate.value
          session.switchState(State.ofCommitting(textToCommit: text))

          if prefs.associatedPhrasesEnabled {
            let associatedCandidates = generateArrayOfAssociates(withPairs: [.init(
              keyArray: reading,
              value: text
            )])
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

    /// 是說此時注拼槽並非為空、卻還沒組音。這種情況下只可能是「注拼槽內只有聲調」。
    /// 但這裡不處理陰平聲調。
    if keyConsumedByReading {
      // 此處將 strict 設為 false，以應對「僅有注音符號輸入」的情況。
      if composer.phonabetKeyForQuery(pronounceableOnly: false) == nil {
        // 將被空格鍵覆蓋掉的既有聲調塞入組字器。
        if !composer.isPinyinMode, input.isSpace,
           assembler.insertKey(existedIntonation.value) {
          assemble()
          var theInputting = generateStateOfInputting()
          theInputting.textToCommit = commitOverflownComposition
          composer.clear()
          session.switchState(theInputting)
          return true
        }
        composer.clear()
        return nil
      }
      // 以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var resultState = generateStateOfInputting()
      resultState.tooltip = tooltipForStandaloneIntonationMark
      resultState.tooltipDuration = 0
      resultState.data.tooltipColorState = .prompt
      session.switchState(resultState)
      return true
    }
    return nil
  }
}

// MARK: - 磁帶模式的組字支援。

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與磁帶模組有關的組字行為。（前置處理）
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  fileprivate func handleCassetteComposition(input: InputSignalProtocol) -> Bool? {
    guard let session = session else { return nil }
    let state = session.state

    // 準備處理 `%quick` 選字行為。
    var handleQuickCandidate = true
    if currentLM.areCassetteCandidateKeysShiftHeld { handleQuickCandidate = input.isShiftHold }
    let hasQuickCandidates: Bool = state.type == .ofInputting && state.isCandidateContainer

    // 處理 `%symboldef` 選字行為。
    if handleCassetteSymbolTable(input: input) {
      return true
    } else if hasQuickCandidates, input.text != currentLM.cassetteWildcardKey {
      // 處理 `%quick` 選字行為（當且僅當與 `%symboldef` 衝突的情況下）。
      guard !(handleQuickCandidate && handleCandidate(input: input, ignoringModifiers: true))
      else { return true }
    } else {
      // 處理 `%quick` 選字行為。
      guard !(hasQuickCandidates && handleQuickCandidate && handleCandidate(input: input))
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
            prefs.autoCompositeWithLongestPossibleCassetteKey else { return false }
      return !currentLM.hasCassetteWildcardResultsFor(key: calligrapher) && !calligrapher.isEmpty
    }

    var isStrokesFull: Bool {
      calligrapher.count >= currentLM.maxCassetteKeyLength || isLongestPossibleKeyFormed
    }

    prehandling: if !skipStrokeHandling && currentLM.isThisCassetteKeyAllowed(key: inputText) {
      if calligrapher.isEmpty, isWildcardKeyInput {
        errorCallback?("3606B9C0")
        if input.beganWithLetter {
          var newEmptyState = assembler.isEmpty ? State.ofEmpty() : generateStateOfInputting()
          newEmptyState.tooltip = NSLocalizedString(
            "Wildcard key cannot be the initial key.",
            comment: ""
          )
          newEmptyState.data.tooltipColorState = .redAlert
          newEmptyState.tooltipDuration = 1.0
          session.switchState(newEmptyState)
          return true
        }
        notificationCallback?(NSLocalizedString(
          "Wildcard key cannot be the initial key.",
          comment: ""
        ))
        return nil
      }
      if isStrokesFull {
        errorCallback?("2268DD51: calligrapher is full, clearing calligrapher.")
        calligrapher.removeAll()
      } else {
        calligrapher.append(inputText)
      }
      if isWildcardKeyInput {
        break prehandling
      }

      if !isStrokesFull {
        var result = generateStateOfInputting()
        if !calligrapher.isEmpty,
           let fetched = currentLM.cassetteQuickSetsFor(key: calligrapher)?.split(separator: "\t") {
          result.candidates = fetched.enumerated().map {
            (keyArray: [($0.offset + 1).description], value: $0.element.description)
          }
        }
        session.switchState(result)
        return true
      }
    }

    if isQuickPhraseKeyInput {
      guard !calligrapher.isEmpty else {
        errorCallback?("8E1F0B8C: Quick phrase key requires existing strokes.")
        return true
      }
      guard let phrases = currentLM.cassetteQuickPhrases(for: calligrapher), !phrases.isEmpty else {
        errorCallback?("ABF4A62D: No quick phrases for key \(calligrapher).")
        return true
      }
      if let quickPhraseKey, !quickPhraseKey.isEmpty, phrases.count == 1,
         let phrase = phrases.first {
        calligrapher.removeAll()
        session.switchState(State.ofCommitting(textToCommit: phrase))
        return true
      }
      let phraseNode = CandidateNode(
        name: calligrapher,
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
        || (isWildcardKeyInput && !calligrapher.isEmpty)

    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 calligrapher 內的筆畫來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    combineStrokes = combineStrokes || (!calligrapher.isEmpty && confirmCombination)
    ifCombineStrokes: if combineStrokes {
      // 警告：calligrapher 不能為空，否則組字引擎會炸。
      guard !calligrapher.isEmpty else { break ifCombineStrokes }
      if input.isControlHold, input.isCommandHold, input.isEnter,
         !input.isOptionHold, !input.isShiftHold, composer.isEmpty {
        return handleEnter(input: input, readingOnly: true)
      }
      // 向語言模型詢問是否有對應的記錄。
      if !currentLM.hasUnigramsFor(keyArray: [calligrapher]) {
        errorCallback?("B49C0979_Cassette：語彙庫內無「\(calligrapher)」的匹配記錄。")
        calligrapher.removeAll()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        switch assembler.isEmpty {
        case false: session.switchState(generateStateOfInputting())
        case true: session.switchState(State.ofAbortion())
        }
        return true // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
      if input.isInvalid {
        errorCallback?("BFE387CC: 不合規的按鍵輸入。")
        return true
      } else if !assembler.insertKey(calligrapher) {
        errorCallback?("61F6B11F: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
        return true
      }

      // 組句。
      assemble()

      // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
      let textToCommit = commitOverflownComposition

      // 看看漸退記憶模組是否會對目前的狀態給出自動選字建議。
      retrievePOMSuggestions(apply: true)

      // 之後就是更新組字區了。先清空注拼槽的內容。
      calligrapher.removeAll()

      // 再以回呼組字狀態的方式來執行 setInlineDisplayWithCursor()。
      var inputting = generateStateOfInputting()
      inputting.textToCommit = textToCommit
      session.switchState(inputting)

      /// 逐字選字模式的處理。
      if prefs.useSCPCTypingMode {
        let candidateState: State = generateStateOfCandidates()
        switch candidateState.candidates.count {
        case 2...: session.switchState(candidateState)
        case 1:
          let firstCandidate = candidateState.candidates.first! // 一定會有，所以強制拆包也無妨。
          let reading: [String] = firstCandidate.keyArray
          let text: String = firstCandidate.value
          session.switchState(State.ofCommitting(textToCommit: text))

          if prefs.associatedPhrasesEnabled {
            let associatedCandidates = generateArrayOfAssociates(withPairs: [.init(
              keyArray: reading,
              value: text
            )])
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

// MARK: - 內碼區位輸入處理 (Handle Code Point Input)

extension InputHandlerProtocol {
  /// 用來處理 InputHandler.HandleInput() 當中的與內碼區位輸入有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  fileprivate func handleCodePointComposition(input: InputSignalProtocol) -> Bool? {
    guard !input.isReservedKey else { return nil }
    guard let session = session, input.text.count == 1 else { return nil }
    guard !input.text.compactMap(\.hexDigitValue).isEmpty else {
      errorCallback?("05DD692C：輸入的字元並非 ASCII 字元。。")
      return true
    }
    switch strCodePointBuffer.count {
    case 0 ..< 4:
      if strCodePointBuffer.count < 3 {
        strCodePointBuffer.append(input.text)
        var updatedState = generateStateOfInputting(guarded: true)
        updatedState.tooltipDuration = 0
        updatedState.tooltip = TypingMethod.codePoint
          .getTooltip(vertical: session.isVerticalTyping)
        session.switchState(updatedState)
        return true
      }
      let hexSequence = "\(strCodePointBuffer)\(input.text)"
      let parsedChar = CodePointDecoder.decode(
        hexString: hexSequence,
        encodingID: IMEApp.currentInputMode.nonUTFEncoding,
        encodingHint: IMEApp.currentInputMode.nonUTFEncodingInitials
      )?.first?.description
      guard var char = parsedChar else {
        errorCallback?("D220B880：輸入的字碼沒有對應的字元。")
        var updatedState = State.ofAbortion()
        updatedState.tooltipDuration = 0
        updatedState.tooltip = "Invalid Code Point.".localized
        session.switchState(updatedState)
        currentTypingMethod = .codePoint
        return true
      }
      // 某些舊版 macOS 會在這裡生成的字元後面插入垃圾字元。這裡只保留起始字元。
      if char.count > 1 { char = char.map(\.description)[0] }
      session.switchState(State.ofCommitting(textToCommit: char))
      var updatedState = generateStateOfInputting(guarded: true)
      updatedState.tooltipDuration = 0
      updatedState.tooltip = TypingMethod.codePoint.getTooltip(vertical: session.isVerticalTyping)
      session.switchState(updatedState)
      currentTypingMethod = .codePoint
      return true
    default:
      session.switchState(generateStateOfInputting())
      currentTypingMethod = .codePoint
      return true
    }
  }
}

// MARK: - 處理羅馬數字輸入狀態（Handle Roman Numeral Inputs）

extension InputHandlerProtocol {
  /// 處理羅馬數字輸入。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  fileprivate func handleRomanNumeralComposition(input: InputSignalProtocol) -> Bool? {
    guard !input.isReservedKey else { return nil }
    guard let session = session, input.text.count == 1 else { return nil }
    let char = input.text

    func handleErrorState(msg: String) {
      var newErrorState = State.ofAbortion()
      if !msg.isEmpty {
        newErrorState.tooltip = msg
        newErrorState.tooltipDuration = 1.85
        session.switchState(newErrorState)
      }
    }

    // 驗證輸入：首位數字必須是 1-9，其餘數字可以是 0-9
    guard char.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil else {
      handleErrorState(msg: "typingMethod.romanNumerals.error.invalidCharacter".localized)
      errorCallback?("FC7EF8CD")
      return true
    }

    // 首位數字不能是 0
    if strCodePointBuffer.isEmpty && char == "0" {
      handleErrorState(msg: "typingMethod.romanNumerals.error.invalidCharacter".localized)
      errorCallback?("7B09F1E4")
      return true
    }

    // 將字元追加至緩衝區
    strCodePointBuffer.append(char)
    
    // 檢查是否需要自動提交（第 4 個字元時）
    if strCodePointBuffer.count >= 4 {
      return commitRomanNumeral(session: session)
    }
    
    // 更新狀態並顯示當前緩衝區內容
    var updatedState = generateStateOfInputting(guarded: true)
    updatedState.tooltipDuration = 0
    updatedState.tooltip = TypingMethod.romanNumerals.getTooltip(vertical: session.isVerticalTyping)
    session.switchState(updatedState)
    return true
  }
}

// MARK: - 處理漢音鍵盤符號輸入狀態（Handle Hanin Keyboard Symbol Inputs）

extension InputHandlerProtocol {
  /// 處理漢音鍵盤符號輸入。
  /// - Parameters:
  ///   - input: 輸入按鍵訊號。
  /// - Returns: 將按鍵行為「是否有處理掉」藉由 SessionCtl 回報給 IMK。
  fileprivate func handleHaninKeyboardSymbolModeInput(input: InputSignalProtocol) -> Bool {
    guard let session = session, session.state.type != .ofDeactivated else { return false }
    let charText = input.text.lowercased().applyingTransformFW2HW(reverse: false)
    guard CandidateNode.mapHaninKeyboardSymbols.keys.contains(charText) else {
      return revolveTypingMethod(to: .vChewingFactory)
    }
    guard charText.count == 1, let symbols = CandidateNode.queryHaninKeyboardSymbols(char: charText)
    else {
      errorCallback?("C1A760C7")
      return true
    }
    // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
    let textToCommit = generateStateOfInputting(sansReading: true).displayedText
    session.switchState(State.ofCommitting(textToCommit: textToCommit))
    if symbols.members.count == 1 {
      session
        .switchState(State.ofCommitting(textToCommit: symbols.members.map(\.name).joined()))
    } else {
      session.switchState(State.ofSymbolTable(node: symbols))
    }
    currentTypingMethod = .vChewingFactory // 用完就關掉，但保持選字窗開啟，所以這裡不用呼叫 toggle 函式。
    return true
  }
}
