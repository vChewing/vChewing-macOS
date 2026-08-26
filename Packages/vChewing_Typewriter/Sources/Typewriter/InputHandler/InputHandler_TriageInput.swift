// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組當中「用來規定當 IMK 接受按鍵訊號時且首次交給輸入調度模組處理時、
/// 輸入調度模組要率先處理」的部分。據此判斷是否需要將按鍵處理委派給其它成員函式。

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States) * Triage

extension InputHandlerProtocol {
  public func triageInput(event input: InputSignalProtocol) -> Bool {
    guard let session = session else { return false }
    var state: State { session.state }
    currentLM.syncPrefs()

    // 狂拼固化：尾段候選窗顯示中、按下「可能叫出選字窗」的鍵（Space／翻頁／候選導航
    // 方向鍵）時，先把尾段投機讀音固化進組字器（投機→實體：只插聲調桶、不覆寫，
    // trail 累積供重切分），再讓同一事件繼續走正常流程——正常流程自動開出正常選字窗
    // （方向鍵、翻頁、revlookup 皆由既有機制免費提供）。不重入、無遞迴風險；
    // Enter／數字鍵／字母鍵／編輯鍵不屬觸發集合。
    // 前後方向鍵不在此列——注拼槽有未完成讀音時由 handleForward/handleBackward
    // 的專屬規則接管（狂拼開窗或 error 退回）。
    // 空格觸發固化時記錄本拍「空格已用於插入讀音」：後續的 kSpace 分診依此直接
    // 消費本拍空格（不再輪替、不再遞交、不生成空格字符）——未完成讀音存在時，
    // 空格語義為「把讀音插入組字器」而非「輪替候選」。
    var spaceSolidifiedFuriousReading = false
    if session.isFuriousCopilotCandidateWindowVisible,
       !input.isHoldingAny([.control, .option, .command]),
       input.isSpace || input.isPageUp || input.isPageDown
       || input.isCursorClockLeft || input.isCursorClockRight {
      solidifyFuriousTailReading()
      spaceSolidifiedFuriousReading = input.isSpace
    }

    // MARK: - 按鍵碼分診（Triage by KeyCode）

    func triageByKeyCode() -> Bool? {
      guard let keyCodeType = KeyCode(rawValue: input.keyCode) else { return nil }
      switch keyCodeType {
      case .kEscape: return handleEsc()
      case .kContextMenu, .kTab: return revolveCandidate(
          reverseOrder: input.isShiftHeld,
          softRevolve: prefs.preferredRevolverForceLevel == 2
        )
      case .kDownArrow, .kLeftArrow, .kRightArrow, .kUpArrow:
        let revolution: Bool = input.isHoldingAny([.option, .shift]) && state.type == .ofInputting
        handleArrowKey: switch (keyCodeType, session.isVerticalTyping) {
        case (.kLeftArrow, false), (.kUpArrow, true): return handleBackward(input: input)
        case (.kDownArrow, true), (.kRightArrow, false): return handleForward(input: input)
        case (.kLeftArrow, true), (.kUpArrow, false):
          return revolution
            ? revolveCandidate(
              reverseOrder: true,
              softRevolve: prefs.preferredRevolverForceLevel == 2
            )
            : handleClockKey()
        case (.kDownArrow, false), (.kRightArrow, true):
          return revolution
            ? revolveCandidate(
              reverseOrder: false,
              softRevolve: prefs.preferredRevolverForceLevel == 2
            )
            : handleClockKey()
        default: break handleArrowKey // 該情況應該不會發生，因為上面都有處理過。
        }
      case .kHome: return handleHome()
      case .kEnd: return handleEnd()
      case .kBackSpace: return handleBackSpace(input: input)
      case .kWindowsDelete: return handleDelete(input: input)
      case .kCarriageReturn, .kLineFeed:
        let frontNode = assembler.assembledSentence.last
        let shouldEarlyBreak: Bool = currentTypingMethod != .vChewingFactory
        return handleEnter(input: input) { [currentLM = currentLM] in
          guard !shouldEarlyBreak else { return [] }
          guard let frontNode = frontNode else { return [] }
          let pair = KeyValuePaired(keyArray: frontNode.keyArray, value: frontNode.value)
          return currentLM.lookupHub.associatedCandidates(forPair: pair)
        }
      case .kSymbolMenuPhysicalKeyIntl, .kSymbolMenuPhysicalKeyJIS:
        let isJIS = keyCodeType == .kSymbolMenuPhysicalKeyJIS
        switch input.commonKeyModifierFlags {
        case []:
          return handlePunctuationList(alternative: false, isJIS: isJIS)
        case [.option, .shift]:
          return handlePunctuationList(alternative: true, isJIS: isJIS)
        case .option:
          return revolveTypingMethod()
        default: break
        }
      case .kSpace:
        // 倘若沒有在偏好設定內將 Space 空格鍵設為選字窗呼叫用鍵的話………
        // 空格字符輸入行為處理。
        switch state.type {
        case .ofEmpty:
          if !input.isHoldingAny([.option, .control, .command]) {
            session.switchState(State.ofCommitting(textToCommit: input.isShiftHeld ? "　" : " "))
            return true
          }
        case .ofInputting:
          // 空格已用於狂拼讀音固化：本拍空格被「插入讀音」消費——不再輪替候選、
          // 亦不落入後續的空格遞交路徑（否則會生成空格字符拆斷組字區、使之直接
          // 遞交）。behavior==1 的「空格呼叫選字窗」由更早的 callCandidateState
          // 提供、不受本守衛影響；此處以新狀態刷新顯示（清掉已失效的狂拼尾段預覽窗）。
          if spaceSolidifiedFuriousReading {
            session.switchState(generateStateOfInputting())
            return true
          }
          // 空格輪替守衛：注拼槽尚有未完成讀音時，停用空格輪替——未完成讀音存在時，
          // 空格語義為「把讀音插入組字器」、不兼任候選輪替。
          // （拼音模式下 composer.isEmpty 涵蓋 romajiBuffer；注音模式涵蓋聲介韻調。）
          let spaceRotationBanned = !composer.isEmpty
          // 臉書等網站會攔截 Tab 鍵，所以用 Shift+Command+Space 對候選字詞做正向/反向輪替。
          // Space 鍵就地輪替候選字（對應 spaceKeyBehaviorAgainstICB == 2）。
          if prefs.spaceKeyBehaviorAgainstICB == 2,
             input.keyModifierFlags.intersection([.control, .command, .option]).isEmpty,
             !spaceRotationBanned {
            // 此時 Shift+Space 反向輪替，仿 Shift+Tab 行為。
            // SPACE 啟動的輪替一律套用 soft revolve，避免毀掉鄰近已覆寫節點。
            return revolveCandidate(
              reverseOrder: input.isShiftHeld,
              softRevolve: prefs.preferredRevolverForceLevel != 0
            )
          }
          if input.isShiftHeld, !input.isHoldingAny([.control, .option]), !spaceRotationBanned {
            return revolveCandidate(
              reverseOrder: input.isCommandHeld,
              softRevolve: prefs.preferredRevolverForceLevel != 0
            )
          }
          if currentTypingMethod == .codePoint {
            errorCallback?("FDD88EDB")
            session.switchState(State.ofAbortion())
            return true
          }
          if currentTypingMethod == .romanNumerals {
            if strCodePointBuffer.isEmpty {
              errorCallback?("A8F3C5D2")
              session.switchState(State.ofAbortion())
              return true
            }
            return commitRomanNumeral(session: session)
          }
          // 中英混打模式：Space 按鍵交由 MixedAlphanumericalTypewriter 處理，
          // 避免直接進入組字區送字邏輯而將讀音字串以原文 commit。
          if currentTypingMethod == .vChewingFactory, prefs.mixedAlphanumericalEnabled,
             !mixedAlphanumericalBuffer.isEmpty {
            if let result = MixedAlphanumericalTypewriter(self).handle(input) {
              return result
            }
          }
          if assembler.cursor < assembler.length, (try? assembler.insertKey(" ")) != nil {
            // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
            let textToCommit = commitOverflownComposition
            var inputting = generateStateOfInputting()
            inputting.textToCommit = textToCommit
            session.switchState(inputting)
          } else {
            let displayedText = committableDisplayText()
            if !displayedText.isEmpty, !isConsideredEmptyForNow {
              session.switchState(State.ofCommitting(textToCommit: displayedText))
            }
            session.switchState(State.ofCommitting(textToCommit: " "))
          }
          return true
        default: break
        }
      default: break
      }
      return nil
    }

    // MARK: - 按狀態分診（Triage by States）

    triageByState: switch state.type {
    case .ofAbortion, .ofCommitting, .ofDeactivated: return false
    case .ofAssociates, .ofCandidates, .ofSymbolTable:
      let result = handleCandidate(input: input)
      guard !result, state.type == .ofAssociates else { return true }
      session.switchState(State.ofEmpty())
      return triageInput(event: input)
    case .ofMarking:
      if handleMarkingState(input: input) { return true }
      session.switchState(state.convertedToInputting)
      return triageInput(event: input)
    case .ofEmpty, .ofInputting:
      // 提前放行一些用不到的特殊按鍵輸入情形。
      guard !(input.isInvalid && state.type == .ofEmpty) else { return false }

      // 如果當前組字器為空的話，就不再攔截 Cmd / 非筆電功能鍵，
      // 畢竟這些鍵可能會用來觸發系統功能。
      if !state.hasComposition,
         input.isCommandHeld || input.isNonLaptopFunctionKey { return false }

      // 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
      // 這裡的處理仍舊有用，不然 Caps Lock 英文模式無法直接鍵入小寫字母。
      if let capsHandleResult = handleCapsLockAndAlphanumericalMode(input: input) {
        return capsHandleResult
      }

      // 處理九宮格數字鍵盤區域。
      if handleNumPadKeyInput(input: input) { return true }

      // 判斷是否響應傳統的漢音鍵盤符號模式熱鍵。
      haninSymbolInput: if prefs.classicHaninKeyboardSymbolModeShortcutEnabled {
        guard let x = input.inputTextIgnoringModifiers,
              "¥\\".contains(x), input.keyModifierFlags.isEmpty
        else { break haninSymbolInput }
        return revolveTypingMethod(to: .haninKeyboardSymbol)
      }

      // 注音/磁帶按鍵輸入與漢音鍵盤符號輸入處理。
      if let compositionHandled = handleComposition(input: input) {
        return compositionHandled
      }

      // 手動呼叫選字窗。
      if callCandidateState(input: input) { return true }

      // Ctrl+Command+[] 輪替候選字。
      // Shift+Command+[] 被 Chrome 系瀏覽器佔用，所以改用 Ctrl。
      let ctrlCMD: Bool = input.commonKeyModifierFlags == [.control, .command]
      let ctrlShiftCMD: Bool = input.commonKeyModifierFlags == [.control, .command, .shift]
      revolveCandidateWithBrackets: if ctrlShiftCMD || ctrlCMD {
        if state.type != .ofInputting { break revolveCandidateWithBrackets }
        // 此處 JIS 鍵盤判定無法用於螢幕鍵盤。所以，螢幕鍵盤的場合，系統會依照 US 鍵盤的判定方案。
        switch (input.keyCode, isJISKeyboard?() ?? false) {
        case (30, true), (33, false): return revolveCandidate(
            reverseOrder: true,
            softRevolve: prefs.preferredRevolverForceLevel == 2
          )
        case (30, false), (42, true): return revolveCandidate(
            reverseOrder: false,
            softRevolve: prefs.preferredRevolverForceLevel == 2
          )
        default: break
        }
      }

      // 根據 keyCode 進行分診處理。
      if let keyCodeTriaged = triageByKeyCode() { return keyCodeTriaged }

      // 磁帶模式：如果有定義 keysToDirectlyCommit 的話，對符合條件的輸入訊號不再作處理。
      var cinDirectlyCommit = prefs.cassetteEnabled && !currentLM.keysToDirectlyCommit.isEmpty
      cinDirectlyCommit = cinDirectlyCommit && [.ofInputting, .ofEmpty].contains(state.type)
      cinDirectlyCommit = cinDirectlyCommit && currentLM.keysToDirectlyCommit.contains(input.text)
      if cinDirectlyCommit,
         let quickPhraseKey = currentLM.cassetteQuickPhraseCommissionKey,
         quickPhraseKey == input.text {
        cinDirectlyCommit = false
      }
      guard !cinDirectlyCommit else { break triageByState }

      // 全形/半形阿拉伯數字輸入。
      if handleArabicNumeralInputs(input: input) { return true }

      // 標點符號。
      if let queryStrings = punctuationQueryStrings(input: input) {
        for queryString in queryStrings {
          guard !handlePunctuation(queryString) else { return true }
        }
      }

      // 摁住 Shift+字母鍵 的處理
      if handleLettersWithShiftHold(input: input) { return true }

      // 如果標點鏈路沒攔截到，且當前無組字內容，Ctrl/Option + 可列印 ASCII 視為熱鍵放行。
      if !state.hasComposition, input.isHotKeyOfAnyFlag([.control, .option]) { return false }
    }

    // 終末處理（Still Nothing）：
    // 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 InputSession。
    // 否則的話，可能會導致輸入法行為異常：部分應用會阻止輸入法完全攔截某些按鍵訊號。
    // 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    // 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if state.hasComposition || !isComposerOrCalligrapherEmpty {
      vCLog(
        "Blocked data: charCode: \(input.charCode), keyCode: \(input.keyCode), text: \(input.text)"
      )
      errorCallback?("A9BFF20E")
      return true
    }

    return false
  }
}
