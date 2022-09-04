// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃按鍵調度模組當中「用來規定當 IMK 接受按鍵訊號時且首次交給按鍵調度模組處理時、
/// 按鍵調度模組要率先處理」的部分。據此判斷是否需要將按鍵處理委派給其它成員函式。

import Foundation

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States)

extension KeyHandler {
  /// 對於輸入訊號的第一關處理均藉由此函式來進行。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - state: 給定狀態（通常為當前狀態）。
  ///   - stateCallback: 狀態回呼，交給對應的型別內的專有函式來處理。
  ///   - errorCallback: 錯誤回呼。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handle(
    input: InputSignalProtocol,
    state: IMEStateProtocol,
    stateCallback: @escaping (IMEStateProtocol) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    // 如果按鍵訊號內的 inputTest 是空的話，則忽略該按鍵輸入，因為很可能是功能修飾鍵。
    guard !input.text.isEmpty else { return false }

    let inputText: String = input.text
    var state = state  // 常數轉變數。

    // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
    if input.isInvalid {
      // 在「.Empty(IgnoringPreviousState) 與 .Deactivated」狀態下的首次不合規按鍵輸入可以直接放行。
      // 因為「.Abortion」會在處理之後被自動轉為「.Empty」，所以不需要單獨判斷。
      if state.type == .ofEmpty || state.type == .ofDeactivated {
        return false
      }
      IME.prtDebugIntel("550BCF7B: KeyHandler just refused an invalid input.")
      errorCallback()
      stateCallback(state)
      return true
    }

    // 如果當前組字器為空的話，就不再攔截某些修飾鍵，畢竟這些鍵可能會會用來觸發某些功能。
    let isFunctionKey: Bool =
      input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNonLaptopFunctionKey)
    if state.type != .ofAssociates, !state.hasComposition, !state.isCandidateContainer, isFunctionKey {
      return false
    }

    // MARK: Caps Lock processing.

    /// 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
    /// 這裡的處理原先是給威注音曾經有過的 Shift 切換英數模式來用的，但因為採 Chromium 核
    /// 心的瀏覽器會讓 IMK 無法徹底攔截對 Shift 鍵的單擊行為、導致這個模式的使用體驗非常糟
    /// 糕，故僅保留以 Caps Lock 驅動的英數模式。
    if input.isBackSpace || input.isEnter
      || input.isCursorClockLeft || input.isCursorClockRight
      || input.isCursorForward || input.isCursorBackward
    {
      // 略過對 BackSpace 的處理。
    } else if input.isCapsLockOn || input.isASCIIModeInput {
      // 但願能夠處理這種情況下所有可能的按鍵組合。
      stateCallback(IMEState.Empty())

      // 字母鍵摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
      if input.isUpperCaseASCIILetterKey {
        return false
      }

      /// 如果是 ASCII 當中的不可列印的字元的話，不使用「insertText:replacementRange:」。
      /// 某些應用無法正常處理非 ASCII 字符的輸入。
      if input.isASCII, !input.charCode.isPrintableASCII {
        return false
      }

      // 將整個組字區的內容遞交給客體應用。
      stateCallback(IMEState.Committing(textToCommit: inputText.lowercased()))
      stateCallback(IMEState.Empty())

      return true
    }

    // MARK: 處理數字小鍵盤 (Numeric Pad Processing)

    // 這裡的「isNumericPadKey」處理邏輯已經改成用 KeyCode 判定數字鍵區輸入、以鎖定按鍵範圍。
    // 不然、使用 Cocoa 內建的 flags 的話，會誤傷到在主鍵盤區域的功能鍵。
    // 我們先規定允許小鍵盤區域操縱選字窗，其餘場合一律直接放行。
    if input.isNumericPadKey {
      if !(state.type == .ofCandidates || state.type == .ofAssociates
        || state.type == .ofSymbolTable)
      {
        stateCallback(IMEState.Empty())
        stateCallback(IMEState.Committing(textToCommit: inputText.lowercased()))
        stateCallback(IMEState.Empty())
        return true
      }
    }

    // MARK: 處理候選字詞 (Handle Candidates)

    if [.ofCandidates, .ofSymbolTable].contains(state.type) {
      return handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: 處理聯想詞 (Handle Associated Phrases)

    if state.type == .ofAssociates {
      if handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      ) {
        return true
      } else {
        stateCallback(IMEState.Empty())
      }
    }

    // MARK: 處理標記範圍、以便決定要把哪個範圍拿來新增使用者(濾除)語彙 (Handle Marking)

    if state.type == .ofMarking {
      if handleMarkingState(
        state, input: input, stateCallback: stateCallback,
        errorCallback: errorCallback
      ) {
        return true
      }
      state = state.convertedToInputting
      stateCallback(state)
    }

    // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

    if let compositionHandled = handleComposition(
      input: input, stateCallback: stateCallback, errorCallback: errorCallback
    ) {
      return compositionHandled
    }

    // MARK: 用上下左右鍵呼叫選字窗 (Calling candidate window using Up / Down or PageUp / PageDn.)

    if state.hasComposition, composer.isEmpty, !input.isOptionHold,
      input.isCursorClockLeft || input.isCursorClockRight || input.isSpace
        || input.isPageDown || input.isPageUp || (input.isTab && mgrPrefs.specifyShiftTabKeyBehavior)
    {
      if input.isSpace {
        /// 倘若沒有在偏好設定內將 Space 空格鍵設為選字窗呼叫用鍵的話………
        if !mgrPrefs.chooseCandidateUsingSpace {
          if compositor.cursor >= compositor.length {
            let displayedText = state.displayedText
            if !displayedText.isEmpty {
              stateCallback(IMEState.Committing(textToCommit: displayedText))
            }
            stateCallback(IMEState.Committing(textToCommit: " "))
            stateCallback(IMEState.Empty())
          } else if currentLM.hasUnigramsFor(key: " ") {
            compositor.insertKey(" ")
            walk()
            let inputting = buildInputtingState
            stateCallback(inputting)
          }
          return true
        } else if input.isShiftHold {  // 臉書等網站會攔截 Tab 鍵，所以用 Shift+Command+Space 對候選字詞做正向/反向輪替。
          return handleInlineCandidateRotation(
            state: state, reverseModifier: input.isCommandHold, stateCallback: stateCallback,
            errorCallback: errorCallback
          )
        }
      }
      stateCallback(buildCandidate(state: state))
      return true
    }

    // MARK: -

    // MARK: Esc

    if input.isEsc { return handleEsc(state: state, stateCallback: stateCallback) }

    // MARK: Tab

    if input.isTab {
      return handleInlineCandidateRotation(
        state: state, reverseModifier: input.isShiftHold, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Cursor backward

    if input.isCursorBackward || input.emacsKey == EmacsKey.backward {
      return handleBackward(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Cursor forward

    if input.isCursorForward || input.emacsKey == EmacsKey.forward {
      return handleForward(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Home

    if input.isHome || input.emacsKey == EmacsKey.home {
      return handleHome(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: End

    if input.isEnd || input.emacsKey == EmacsKey.end {
      return handleEnd(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Ctrl+PgLf or Shift+PgLf

    if (input.isControlHold || input.isShiftHold) && (input.isOptionHold && input.isLeft) {
      return handleHome(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Ctrl+PgRt or Shift+PgRt

    if (input.isControlHold || input.isShiftHold) && (input.isOptionHold && input.isRight) {
      return handleEnd(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Clock-Left & Clock-Right

    if input.isCursorClockLeft || input.isCursorClockRight {
      if input.isOptionHold, state.type == .ofInputting {
        if input.isCursorClockRight {
          return handleInlineCandidateRotation(
            state: state, reverseModifier: false, stateCallback: stateCallback, errorCallback: errorCallback
          )
        }
        if input.isCursorClockLeft {
          return handleInlineCandidateRotation(
            state: state, reverseModifier: true, stateCallback: stateCallback, errorCallback: errorCallback
          )
        }
      }
      return handleClockKey(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Backspace

    if input.isBackSpace {
      return handleBackSpace(state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Delete

    if input.isDelete || input.emacsKey == EmacsKey.delete {
      return handleDelete(state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Enter

    if input.isEnter {
      return (input.isCommandHold && input.isControlHold)
        ? (input.isOptionHold
          ? handleCtrlOptionCommandEnter(state: state, stateCallback: stateCallback)
          : handleCtrlCommandEnter(state: state, stateCallback: stateCallback))
        : handleEnter(state: state, stateCallback: stateCallback)
    }

    // MARK: -

    // MARK: Punctuation list

    if input.isSymbolMenuPhysicalKey, !input.isShiftHold, !input.isControlHold, state.type != .ofDeactivated {
      if input.isOptionHold {
        if currentLM.hasUnigramsFor(key: "_punctuation_list") {
          if composer.isEmpty {
            compositor.insertKey("_punctuation_list")
            walk()
            let inputting = buildInputtingState
            stateCallback(inputting)
            stateCallback(buildCandidate(state: inputting))
          } else {  // 不要在注音沒敲完整的情況下叫出統合符號選單。
            IME.prtDebugIntel("17446655")
            errorCallback()
          }
          return true
        }
      } else {
        // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
        // 於是這裡用「模擬一次 Enter 鍵的操作」使其代為執行這個 commit buffer 的動作。
        // 這裡不需要該函式所傳回的 bool 結果，所以用「_ =」解消掉。
        _ = handleEnter(state: state, stateCallback: stateCallback)
        stateCallback(IMEState.SymbolTable(node: SymbolNode.root))
        return true
      }
    }

    // MARK: 全形/半形阿拉伯數字輸入 (FW / HW Arabic Numbers Input)

    if state.type == .ofEmpty {
      if input.isMainAreaNumKey, input.isShiftHold, input.isOptionHold, !input.isControlHold, !input.isCommandHold {
        // NOTE: 將來棄用 macOS 10.11 El Capitan 支援的時候，把這裡由 CFStringTransform 改為 StringTransform:
        // https://developer.apple.com/documentation/foundation/stringtransform
        guard let stringRAW = input.mainAreaNumKeyChar else { return false }
        let string = NSMutableString(string: stringRAW)
        CFStringTransform(string, nil, kCFStringTransformFullwidthHalfwidth, true)
        stateCallback(
          IMEState.Committing(textToCommit: mgrPrefs.halfWidthPunctuationEnabled ? stringRAW : string as String)
        )
        stateCallback(IMEState.Empty())
        return true
      }
    }

    // MARK: Punctuation

    /// 如果仍無匹配結果的話，先看一下：
    /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
    /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

    let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
    let parser = currentMandarinParser
    let arrCustomPunctuations: [String] = [punctuationNamePrefix, parser, input.text]
    let customPunctuation: String = arrCustomPunctuations.joined(separator: "")
    if handlePunctuation(
      customPunctuation,
      state: state,
      usingVerticalTyping: input.isTypingVertical,
      stateCallback: stateCallback,
      errorCallback: errorCallback
    ) {
      return true
    }

    /// 如果仍無匹配結果的話，看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。

    let arrPunctuations: [String] = [punctuationNamePrefix, input.text]
    let punctuation: String = arrPunctuations.joined(separator: "")

    if handlePunctuation(
      punctuation,
      state: state,
      usingVerticalTyping: input.isTypingVertical,
      stateCallback: stateCallback,
      errorCallback: errorCallback
    ) {
      return true
    }

    // MARK: 全形/半形空白 (Full-Width / Half-Width Space)

    /// 該功能僅可在當前組字區沒有任何內容的時候使用。
    if state.type == .ofEmpty {
      if input.isSpace, !input.isOptionHold, !input.isControlHold, !input.isCommandHold {
        stateCallback(IMEState.Committing(textToCommit: input.isShiftHold ? "　" : " "))
        stateCallback(IMEState.Empty())
        return true
      }
    }

    // MARK: 摁住 Shift+字母鍵 的處理 (Shift+Letter Processing)

    if input.isUpperCaseASCIILetterKey, !input.isCommandHold, !input.isControlHold {
      if input.isShiftHold {  // 這裡先不要判斷 isOptionHold。
        switch mgrPrefs.upperCaseLetterKeyBehavior {
          case 1:
            stateCallback(IMEState.Empty())
            stateCallback(IMEState.Committing(textToCommit: inputText.lowercased()))
            stateCallback(IMEState.Empty())
            return true
          case 2:
            stateCallback(IMEState.Empty())
            stateCallback(IMEState.Committing(textToCommit: inputText.uppercased()))
            stateCallback(IMEState.Empty())
            return true
          default:  // 包括 case 0，直接塞給組字區。
            let letter = "_letter_\(inputText)"
            if handlePunctuation(
              letter,
              state: state,
              usingVerticalTyping: input.isTypingVertical,
              stateCallback: stateCallback,
              errorCallback: errorCallback
            ) {
              return true
            }
        }
      }
    }

    // MARK: - 終末處理 (Still Nothing)

    /// 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 ctlInputMethod。
    /// 否則的話，可能會導致輸入法行為異常：部分應用會阻止輸入法完全攔截某些按鍵訊號。
    /// 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    /// 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if state.hasComposition || !composer.isEmpty {
      IME.prtDebugIntel(
        "Blocked data: charCode: \(input.charCode), keyCode: \(input.keyCode)")
      IME.prtDebugIntel("A9BFF20E")
      errorCallback()
      stateCallback(state)
      return true
    }

    return false
  }
}
