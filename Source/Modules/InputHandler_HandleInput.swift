// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃按鍵調度模組當中「用來規定當 IMK 接受按鍵訊號時且首次交給按鍵調度模組處理時、
/// 按鍵調度模組要率先處理」的部分。據此判斷是否需要將按鍵處理委派給其它成員函式。

import CocoaExtension
import LangModelAssembly
import Shared

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States)

extension InputHandler {
  /// 對於輸入訊號的第一關處理均藉由此函式來進行。
  /// - Remark: 送入該函式處理之前，先用 inputHandler.handleEvent() 分診、來判斷是否需要交給 IMKCandidates 處理。
  /// - Parameters:
  ///   - input: 輸入訊號。
  ///   - state: 給定狀態（通常為當前狀態）。
  ///   - stateCallback: 狀態回呼，交給對應的型別內的專有函式來處理。
  ///   - errorCallback: 錯誤回呼。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleInput(
    event input: InputSignalProtocol,
    state: IMEStateProtocol,
    stateCallback: @escaping (IMEStateProtocol) -> Void,
    errorCallback: @escaping (String) -> Void
  ) -> Bool {
    // 如果按鍵訊號內的 inputTest 是空的話，則忽略該按鍵輸入，因為很可能是功能修飾鍵。
    guard !input.text.isEmpty, input.charCode.isPrintable else { return false }

    let inputText: String = input.text
    var state = state  // 常數轉變數。

    // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
    if input.isInvalid {
      // 在「.Empty(IgnoringPreviousState) 與 .Deactivated」狀態下的首次不合規按鍵輸入可以直接放行。
      // 因為「.Abortion」會在處理之後被自動轉為「.Empty」，所以不需要單獨判斷。
      if state.type == .ofEmpty || state.type == .ofDeactivated {
        return false
      }
      errorCallback("550BCF7B: InputHandler just refused an invalid input.")
      stateCallback(state)
      return true
    }

    // 如果當前組字器為空的話，就不再攔截某些修飾鍵，畢竟這些鍵可能會會用來觸發某些功能。
    let isFunctionKey: Bool =
      input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNonLaptopFunctionKey)
    if state.type != .ofAssociates, !state.hasComposition, !state.isCandidateContainer, isFunctionKey {
      return false
    }

    // MARK: Caps Lock 處理

    /// 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
    /// 這裡的處理仍舊有用，不然 Caps Lock 英文模式無法直接鍵入小寫字母。
    if input.isBackSpace || input.isEnter
      || input.isCursorClockLeft || input.isCursorClockRight
      || input.isCursorForward || input.isCursorBackward
    {
      // 略過對 BackSpace 的處理。
    } else if input.isCapsLockOn || state.isASCIIMode {
      // 但願能夠處理這種情況下所有可能的按鍵組合。
      stateCallback(IMEState.ofEmpty())

      // 字母鍵摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
      if (input.isUpperCaseASCIILetterKey && state.isASCIIMode)
        || (input.isCapsLockOn && input.isShiftHold)
      {
        return false
      }

      /// 如果是 ASCII 當中的不可列印的字元的話，不使用「insertText:replacementRange:」。
      /// 某些應用無法正常處理非 ASCII 字符的輸入。
      if input.isASCII, !input.charCode.isPrintableASCII {
        return false
      }

      // 將整個組字區的內容遞交給客體應用。
      stateCallback(IMEState.ofCommitting(textToCommit: inputText.lowercased()))
      stateCallback(IMEState.ofEmpty())

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
        stateCallback(IMEState.ofEmpty())
        stateCallback(IMEState.ofCommitting(textToCommit: inputText.lowercased()))
        stateCallback(IMEState.ofEmpty())
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
        stateCallback(IMEState.ofEmpty())
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
        || input.isPageDown || input.isPageUp || (input.isTab && prefs.specifyShiftTabKeyBehavior)
    {
      if input.isSpace {
        /// 倘若沒有在偏好設定內將 Space 空格鍵設為選字窗呼叫用鍵的話………
        if !prefs.chooseCandidateUsingSpace {
          if compositor.cursor >= compositor.length {
            let displayedText = state.displayedText
            if !displayedText.isEmpty {
              stateCallback(IMEState.ofCommitting(textToCommit: displayedText))
            }
            stateCallback(IMEState.ofCommitting(textToCommit: " "))
            stateCallback(IMEState.ofEmpty())
          } else if currentLM.hasUnigramsFor(key: " ") {
            compositor.insertKey(" ")
            walk()
            // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
            let textToCommit = commitOverflownComposition
            var inputting = generateStateOfInputting()
            inputting.textToCommit = textToCommit
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
      let candidateState: IMEStateProtocol = generateStateOfCandidates(state: state)
      if candidateState.candidates.isEmpty {
        errorCallback("3572F238")
      } else {
        stateCallback(candidateState)
      }
      return true
    }

    // MARK: 批次集中處理某些常用功能鍵

    if let keyCodeType = KeyCode(rawValue: input.keyCode) {
      switch keyCodeType {
        case .kEscape: return handleEsc(state: state, stateCallback: stateCallback)
        case .kTab:
          return handleInlineCandidateRotation(
            state: state, reverseModifier: input.isShiftHold, stateCallback: stateCallback, errorCallback: errorCallback
          )
        case .kUpArrow, .kDownArrow, .kLeftArrow, .kRightArrow:
          if (input.isControlHold || input.isShiftHold) && (input.isOptionHold) {
            if input.isLeft {  // Ctrl+PgLf / Shift+PgLf
              return handleHome(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
            } else if input.isRight {  // Ctrl+PgRt or Shift+PgRt
              return handleEnd(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
            }
          }
          if input.isCursorBackward {  // Forward
            return handleBackward(
              state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
            )
          }
          if input.isCursorForward {  // Backward
            return handleForward(
              state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
            )
          }
          if input.isCursorClockLeft || input.isCursorClockRight {  // Clock keys
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
        case .kHome: return handleHome(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
        case .kEnd: return handleEnd(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
        case .kBackSpace:
          return handleBackSpace(state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback)
        case .kWindowsDelete:
          return handleDelete(state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback)
        case .kCarriageReturn, .kLineFeed:
          return (input.isCommandHold && input.isControlHold)
            ? (input.isOptionHold
              ? handleCtrlOptionCommandEnter(state: state, stateCallback: stateCallback)
              : handleCtrlCommandEnter(state: state, stateCallback: stateCallback))
            : handleEnter(state: state, stateCallback: stateCallback)
        default: break
      }
    }

    // MARK: Punctuation list

    if input.isSymbolMenuPhysicalKey, !input.isShiftHold, !input.isControlHold, state.type != .ofDeactivated {
      if input.isOptionHold {
        if currentLM.hasUnigramsFor(key: "_punctuation_list") {
          if composer.isEmpty {
            compositor.insertKey("_punctuation_list")
            walk()
            // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
            let textToCommit = commitOverflownComposition
            var inputting = generateStateOfInputting()
            inputting.textToCommit = textToCommit
            stateCallback(inputting)
            let candidateState = generateStateOfCandidates(state: inputting)
            if candidateState.candidates.isEmpty {
              errorCallback("B5127D8A")
            } else {
              stateCallback(candidateState)
            }
          } else {  // 不要在注音沒敲完整的情況下叫出統合符號選單。
            errorCallback("17446655")
          }
          return true
        }
      } else {
        // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
        // 於是這裡用「模擬一次 Enter 鍵的操作」使其代為執行這個 commit buffer 的動作。
        // 這裡不需要該函式所傳回的 bool 結果，所以用「_ =」解消掉。
        _ = handleEnter(state: state, stateCallback: stateCallback)
        stateCallback(IMEState.ofSymbolTable(node: CandidateNode.root))
        return true
      }
    }

    // MARK: 全形/半形阿拉伯數字輸入 (FW / HW Arabic Numbers Input)

    if state.type == .ofEmpty {
      if input.isMainAreaNumKey, input.modifierFlags == [.shift, .option] {
        guard let stringRAW = input.mainAreaNumKeyChar else { return false }
        let newStringFW = stringRAW.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? stringRAW
        let newStringHW = stringRAW.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? stringRAW
        stateCallback(
          IMEState.ofCommitting(textToCommit: prefs.halfWidthPunctuationEnabled ? newStringHW : newStringFW)
        )
        stateCallback(IMEState.ofEmpty())
        return true
      }
    }

    // MARK: Punctuation

    /// 如果仍無匹配結果的話，先看一下：
    /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
    /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

    let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
    let parser = currentKeyboardParser
    let arrCustomPunctuations: [String] = [punctuationNamePrefix, parser, input.text]
    let customPunctuation: String = arrCustomPunctuations.joined()
    if handlePunctuation(
      customPunctuation,
      state: state,
      stateCallback: stateCallback,
      errorCallback: errorCallback
    ) {
      return true
    }

    /// 如果仍無匹配結果的話，看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。

    let arrPunctuations: [String] = [punctuationNamePrefix, input.text]
    let punctuation: String = arrPunctuations.joined()

    if handlePunctuation(
      punctuation,
      state: state,
      stateCallback: stateCallback,
      errorCallback: errorCallback
    ) {
      return true
    }

    // MARK: 全形/半形空白 (Full-Width / Half-Width Space)

    /// 該功能僅可在當前組字區沒有任何內容的時候使用。
    if state.type == .ofEmpty {
      if input.isSpace, !input.isOptionHold, !input.isControlHold, !input.isCommandHold {
        stateCallback(IMEState.ofCommitting(textToCommit: input.isShiftHold ? "　" : " "))
        stateCallback(IMEState.ofEmpty())
        return true
      }
    }

    // MARK: 摁住 Shift+字母鍵 的處理 (Shift+Letter Processing)

    if input.isUpperCaseASCIILetterKey, !input.isCommandHold, !input.isControlHold {
      if input.isShiftHold {  // 這裡先不要判斷 isOptionHold。
        switch prefs.upperCaseLetterKeyBehavior {
          case 1:
            stateCallback(IMEState.ofEmpty())
            stateCallback(IMEState.ofCommitting(textToCommit: inputText.lowercased()))
            stateCallback(IMEState.ofEmpty())
            return true

          case 2:
            stateCallback(IMEState.ofEmpty())
            stateCallback(IMEState.ofCommitting(textToCommit: inputText.uppercased()))
            stateCallback(IMEState.ofEmpty())
            return true
          default:  // 包括 case 0，直接塞給組字區。
            let letter = "_letter_\(inputText)"
            if handlePunctuation(
              letter,
              state: state,
              stateCallback: stateCallback,
              errorCallback: errorCallback
            ) {
              return true
            }
        }
      }
    }

    // MARK: - 終末處理 (Still Nothing)

    /// 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 SessionCtl。
    /// 否則的話，可能會導致輸入法行為異常：部分應用會阻止輸入法完全攔截某些按鍵訊號。
    /// 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    /// 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if state.hasComposition || !composer.isEmpty {
      errorCallback(
        "Blocked data: charCode: \(input.charCode), keyCode: \(input.keyCode)")
      errorCallback("A9BFF20E")
      stateCallback(state)
      return true
    }

    return false
  }
}
