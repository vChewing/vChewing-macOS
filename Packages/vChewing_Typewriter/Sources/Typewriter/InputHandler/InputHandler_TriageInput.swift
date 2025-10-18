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

    // MARK: - 按鍵碼分診（Triage by KeyCode）

    func triageByKeyCode() -> Bool? {
      guard let keyCodeType = KeyCode(rawValue: input.keyCode) else { return nil }
      switch keyCodeType {
      case .kEscape: return handleEsc()
      case .kContextMenu, .kTab: return revolveCandidate(reverseOrder: input.isShiftHold)
      case .kDownArrow, .kLeftArrow, .kRightArrow, .kUpArrow:
        let rotation: Bool = (input.isOptionHold || input.isShiftHold) && state.type == .ofInputting
        handleArrowKey: switch (keyCodeType, session.isVerticalTyping) {
        case (.kLeftArrow, false), (.kUpArrow, true): return handleBackward(input: input)
        case (.kDownArrow, true), (.kRightArrow, false): return handleForward(input: input)
        case (.kLeftArrow, true), (.kUpArrow, false):
          return rotation ? revolveCandidate(reverseOrder: true) : handleClockKey()
        case (.kDownArrow, false), (.kRightArrow, true):
          return rotation ? revolveCandidate(reverseOrder: false) : handleClockKey()
        default: break handleArrowKey // 該情況應該不會發生，因為上面都有處理過。
        }
      case .kHome: return handleHome()
      case .kEnd: return handleEnd()
      case .kBackSpace: return handleBackSpace(input: input)
      case .kWindowsDelete: return handleDelete(input: input)
      case .kCarriageReturn, .kLineFeed:
        let frontNode = assembler.assembledSentence.last
        return handleEnter(input: input) {
          guard self.currentTypingMethod == .vChewingFactory else { return [] }
          guard let frontNode = frontNode else { return [] }
          let pair = KeyValuePaired(keyArray: frontNode.keyArray, value: frontNode.value)
          let associates = self.generateArrayOfAssociates(withPair: pair)
          return associates
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
          if !input.isOptionHold, !input.isControlHold, !input.isCommandHold {
            session.switchState(State.ofCommitting(textToCommit: input.isShiftHold ? "　" : " "))
            return true
          }
        case .ofInputting:
          // 臉書等網站會攔截 Tab 鍵，所以用 Shift+Command+Space 對候選字詞做正向/反向輪替。
          if input.isShiftHold, !input.isControlHold, !input.isOptionHold {
            return revolveCandidate(reverseOrder: input.isCommandHold)
          }
          if currentTypingMethod == .codePoint {
            errorCallback?("FDD88EDB")
            session.switchState(State.ofAbortion())
            return true
          }
          if assembler.cursor < assembler.length, assembler.insertKey(" ") {
            assemble()
            // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
            let textToCommit = commitOverflownComposition
            var inputting = generateStateOfInputting()
            inputting.textToCommit = textToCommit
            session.switchState(inputting)
          } else {
            let displayedText = state.displayedText
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

      // 如果當前組字器為空的話，就不再攔截某些修飾鍵，畢竟這些鍵可能會會用來觸發某些功能。
      let isFunctional: Bool = (input.isControlHold && input.beganWithLetter)
        || (input.isCommandHold || input.isOptionHotKey || input.isNonLaptopFunctionKey)
      if !state.hasComposition, isFunctional { return false }

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
        case (30, true), (33, false): return revolveCandidate(reverseOrder: true)
        case (30, false), (42, true): return revolveCandidate(reverseOrder: false)
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
      let queryStrings: [String] = punctuationQueryStrings(input: input)
      for queryString in queryStrings {
        guard !handlePunctuation(queryString) else { return true }
      }

      // 摁住 Shift+字母鍵 的處理
      if handleLettersWithShiftHold(input: input) { return true }
    }

    // 終末處理（Still Nothing）：
    // 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 SessionCtl。
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
