// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// 該檔案乃按鍵調度模組當中「用來規定當 IMK 接受按鍵訊號時且首次交給按鍵調度模組處理時、
/// 按鍵調度模組要率先處理」的部分。據此判斷是否需要將按鍵處理委派給其它成員函式。

import Cocoa

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States)

extension KeyHandler {
  func handle(
    input: InputSignal,
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    let charCode: UniChar = input.charCode
    var state = state  // 常數轉變數。

    // 如果按鍵訊號內的 inputTest 是空的話，則忽略該按鍵輸入，因為很可能是功能修飾鍵。
    guard let inputText: String = input.inputText, !inputText.isEmpty else {
      return false
    }

    // 提前過濾掉一些不合規的按鍵訊號輸入，免得相關按鍵訊號被送給 Megrez 引發輸入法崩潰。
    if input.isInvalidInput {
      IME.prtDebugIntel("550BCF7B: KeyHandler just refused an invalid input.")
      errorCallback()
      stateCallback(state)
      return true
    }

    // 如果當前組字器為空的話，就不再攔截某些修飾鍵，畢竟這些鍵可能會會用來觸發某些功能。
    let isFunctionKey: Bool =
      input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNumericPad)
    if !(state is InputState.NotEmpty) && !(state is InputState.AssociatedPhrases) && isFunctionKey {
      return false
    }

    // MARK: Caps Lock processing.

    /// 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
    /// 這裡的處理原先是給威注音曾經有過的 Shift 切換英數模式來用的，但因為採 Chromium 核
    /// 心的瀏覽器會讓 IMK 無法徹底攔截對 Shift 鍵的單擊行為、導致這個模式的使用體驗非常糟
    /// 糕，故僅保留以 Caps Lock 驅動的英數模式。
    if input.isBackSpace || input.isEnter || input.isAbsorbedArrowKey || input.isExtraChooseCandidateKey
      || input.isExtraChooseCandidateKeyReverse || input.isCursorForward || input.isCursorBackward
    {
      // 略過對 BackSpace 的處理。
    } else if input.isCapsLockOn {
      // 但願能夠處理這種情況下所有可能的案件組合。
      clear()
      stateCallback(InputState.Empty())

      // 摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
      if input.isShiftHold {
        return false
      }

      /// 如果是 ASCII 當中的不可列印的字元的話，不使用「insertText:replacementRange:」。
      /// 某些應用無法正常處理非 ASCII 字符的輸入。
      /// 注意：這裡一定要用 Objective-C 的 isPrintable() 函式來處理，否則無效。
      /// 這個函式已經包裝在 CTools.h 裡面了，這樣就可以拿給 Swift 用。
      if charCode < 0x80, !CTools.isPrintable(charCode) {
        return false
      }

      // 將整個組字區的內容遞交給客體應用。
      stateCallback(InputState.Committing(textToCommit: inputText.lowercased()))
      stateCallback(InputState.Empty())

      return true
    }

    // MARK: 處理數字小鍵盤 (Numeric Pad Processing)

    if input.isNumericPad {
      if !input.isLeft, !input.isRight, !input.isDown,
        !input.isUp, !input.isSpace, CTools.isPrintable(charCode)
      {
        clear()
        stateCallback(InputState.Empty())
        stateCallback(InputState.Committing(textToCommit: inputText.lowercased()))
        stateCallback(InputState.Empty())
        return true
      }
    }

    // MARK: 處理候選字詞 (Handle Candidates)

    if state is InputState.ChoosingCandidate {
      return handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: 處理聯想詞 (Handle Associated Phrases)

    if state is InputState.AssociatedPhrases {
      if handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      ) {
        return true
      } else {
        stateCallback(InputState.Empty())
      }
    }

    // MARK: 處理標記範圍、以便決定要把哪個範圍拿來新增使用者(濾除)語彙 (Handle Marking)

    if let marking = state as? InputState.Marking {
      if handleMarkingState(
        marking, input: input, stateCallback: stateCallback,
        errorCallback: errorCallback
      ) {
        return true
      }
      state = marking.convertedToInputting
      stateCallback(state)
    }

    // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

    var keyConsumedByReading = false
    let skipPhoneticHandling = input.isReservedKey || input.isControlHold || input.isOptionHold

    // 這裡 inputValidityCheck() 是讓注拼槽檢查 charCode 這個 UniChar 是否是合法的注音輸入。
    // 如果是的話，就將這次傳入的這個按鍵訊號塞入注拼槽內且標記為「keyConsumedByReading」。
    // 函式 composer.receiveKey() 可以既接收 String 又接收 UniChar。
    if !skipPhoneticHandling && composer.inputValidityCheck(key: charCode) {
      composer.receiveKey(fromCharCode: charCode)
      keyConsumedByReading = true

      // 沒有調號的話，只需要 updateClientComposingBuffer() 且終止處理（return true）即可。
      // 有調號的話，則不需要這樣，而是轉而繼續在此之後的處理。
      let composeReading = composer.hasToneMarker()
      if !composeReading {
        stateCallback(buildInputtingState)
        return true
      }
    }

    var composeReading = composer.hasToneMarker()  // 這裡不需要做排他性判斷。

    // 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 _composer 內的注音來做檢查了。
    // 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
    composeReading = composeReading || (!composer.isEmpty && (input.isSpace || input.isEnter))
    if composeReading {
      if input.isSpace, !composer.hasToneMarker() {
        // 補上空格，否則倚天忘形與許氏排列某些音無法響應不了陰平聲調。
        // 小麥注音因為使用 OVMandarin，所以不需要這樣補。但鐵恨引擎對所有聲調一視同仁。
        composer.receiveKey(fromString: " ")
      }
      let reading = composer.getComposition()  // 拿取用來進行索引檢索用的注音。
      // 如果輸入法的辭典索引是漢語拼音的話，要注意上一行拿到的內容得是漢語拼音。

      // 向語言模型詢問是否有對應的記錄。
      if !ifLangModelHasUnigrams(forKey: reading) {
        IME.prtDebugIntel("B49C0979：語彙庫內無「\(reading)」的匹配記錄。")
        errorCallback()
        composer.clear()
        // 根據「組字器是否為空」來判定回呼哪一種狀態。
        stateCallback((compositorLength == 0) ? InputState.EmptyIgnoringPreviousState() : buildInputtingState)
        return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了。
      }

      // 將該讀音插入至組字器內的軌格當中。
      insertToCompositorAtCursor(reading: reading)

      // 讓組字器反爬軌格。
      let textToCommit = popOverflowComposingTextAndWalk

      // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議。
      fetchAndApplySuggestionsFromUserOverrideModel()

      // 將組字器內超出最大動態爬軌範圍的節錨都標記為「已經手動選字過」，減少之後的爬軌運算負擔。
      markNodesFixedIfNecessary()

      // 之後就是更新組字區了。先清空注拼槽的內容。
      composer.clear()

      // 再以回呼組字狀態的方式來執行 updateClientComposingBuffer()。
      let inputting = buildInputtingState
      inputting.textToCommit = textToCommit
      stateCallback(inputting)

      /// 逐字選字模式的處理。
      if mgrPrefs.useSCPCTypingMode {
        let choosingCandidates: InputState.ChoosingCandidate = buildCandidate(
          state: inputting,
          isTypingVertical: input.isTypingVertical
        )
        if choosingCandidates.candidates.count == 1 {
          clear()
          let text: String = choosingCandidates.candidates.first ?? ""
          stateCallback(InputState.Committing(textToCommit: text))

          if !mgrPrefs.associatedPhrasesEnabled {
            stateCallback(InputState.Empty())
          } else {
            if let associatedPhrases =
              buildAssociatePhraseState(
                withKey: text,
                isTypingVertical: input.isTypingVertical
              ), !associatedPhrases.candidates.isEmpty
            {
              stateCallback(associatedPhrases)
            } else {
              stateCallback(InputState.Empty())
            }
          }
        } else {
          stateCallback(choosingCandidates)
        }
      }
      // 將「這個按鍵訊號已經被輸入法攔截處理了」的結果藉由 ctlInputMethod 回報給 IMK。
      return true
    }

    /// 如果此時這個選項是 true 的話，可知當前注拼槽輸入了聲調、且上一次按鍵不是聲調按鍵。
    /// 比方說大千傳統佈局敲「6j」會出現「ˊㄨ」但並不會被認為是「ㄨˊ」，因為先輸入的調號
    /// 並非用來確認這個注音的調號。除非是：「ㄨˊ」「ˊㄨˊ」「ˊㄨˇ」「ˊㄨ 」等。
    if keyConsumedByReading {
      // 以回呼組字狀態的方式來執行 updateClientComposingBuffer()。
      stateCallback(buildInputtingState)
      return true
    }

    // MARK: Calling candidate window using Up / Down or PageUp / PageDn.

    // 用上下左右鍵呼叫選字窗。

    if let currentState = state as? InputState.NotEmpty, composer.isEmpty,
      input.isExtraChooseCandidateKey || input.isExtraChooseCandidateKeyReverse || input.isSpace
        || input.isPageDown || input.isPageUp || (input.isTab && mgrPrefs.specifyShiftTabKeyBehavior)
        || (input.isTypingVertical && (input.isVerticalTypingOnlyChooseCandidateKey))
    {
      if input.isSpace {
        /// 倘若沒有在偏好設定內將 Space 空格鍵設為選字窗呼叫用鍵的話………
        if !mgrPrefs.chooseCandidateUsingSpace {
          if compositorCursorIndex >= compositorLength {
            let composingBuffer = currentState.composingBuffer
            if !composingBuffer.isEmpty {
              stateCallback(InputState.Committing(textToCommit: composingBuffer))
            }
            clear()
            stateCallback(InputState.Committing(textToCommit: " "))
            stateCallback(InputState.Empty())
          } else if ifLangModelHasUnigrams(forKey: " ") {
            insertToCompositorAtCursor(reading: " ")
            let textToCommit = popOverflowComposingTextAndWalk
            let inputting = buildInputtingState
            inputting.textToCommit = textToCommit
            stateCallback(inputting)
          }
          return true
        } else if input.isShiftHold {  // 臉書等網站會攔截 Tab 鍵，所以用 Shift+CMD+Space 對候選字詞做正向/反向輪替。
          return handleInlineCandidateRotation(
            state: state, reverseModifier: input.isCommandHold, stateCallback: stateCallback,
            errorCallback: errorCallback
          )
        }
      }
      stateCallback(buildCandidate(state: currentState, isTypingVertical: input.isTypingVertical))
      return true
    }

    // MARK: -

    // MARK: Esc

    if input.isESC { return handleEsc(state: state, stateCallback: stateCallback, errorCallback: errorCallback) }

    // MARK: Tab

    if input.isTab {
      return handleInlineCandidateRotation(
        state: state, reverseModifier: input.isShiftHold, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Cursor backward

    if input.isCursorBackward || input.emacsKey == EmacsKey.backward {
      return handleBackward(
        state: state,
        input: input,
        stateCallback: stateCallback,
        errorCallback: errorCallback
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

    // MARK: AbsorbedArrowKey

    if input.isAbsorbedArrowKey || input.isExtraChooseCandidateKey || input.isExtraChooseCandidateKeyReverse {
      return handleAbsorbedArrowKey(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Backspace

    if input.isBackSpace {
      return handleBackspace(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Delete

    if input.isDelete || input.emacsKey == EmacsKey.delete {
      return handleDelete(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: Enter

    if input.isEnter {
      return (input.isCommandHold && input.isControlHold)
        ? (input.isOptionHold
          ? handleCtrlOptionCommandEnter(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
          : handleCtrlCommandEnter(state: state, stateCallback: stateCallback, errorCallback: errorCallback))
        : handleEnter(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: -

    // MARK: Punctuation list

    if input.isSymbolMenuPhysicalKey && !input.isShiftHold {
      if input.isOptionHold {
        if ifLangModelHasUnigrams(forKey: "_punctuation_list") {
          if composer.isEmpty {
            insertToCompositorAtCursor(reading: "_punctuation_list")
            let textToCommit: String! = popOverflowComposingTextAndWalk
            let inputting = buildInputtingState
            inputting.textToCommit = textToCommit
            stateCallback(inputting)
            stateCallback(buildCandidate(state: inputting, isTypingVertical: input.isTypingVertical))
          } else {  // If there is still unfinished bpmf reading, ignore the punctuation
            IME.prtDebugIntel("17446655")
            errorCallback()
          }
          return true
        }
      } else {
        // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
        // 於是這裡用「模擬一次 Enter 鍵的操作」使其代為執行這個 commit buffer 的動作。
        // 這裡不需要該函式所傳回的 bool 結果，所以用「_ =」解消掉。
        _ = handleEnter(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
        stateCallback(InputState.SymbolTable(node: SymbolNode.root, isTypingVertical: input.isTypingVertical))
        return true
      }
    }

    // MARK: Punctuation

    /// 如果仍無匹配結果的話，先看一下：
    /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
    /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。

    var punctuationNamePrefix = ""

    if input.isOptionHold && !input.isControlHold {
      punctuationNamePrefix = "_alt_punctuation_"
    } else if input.isControlHold && !input.isOptionHold {
      punctuationNamePrefix = "_ctrl_punctuation_"
    } else if input.isControlHold && input.isOptionHold {
      punctuationNamePrefix = "_alt_ctrl_punctuation_"
    } else if mgrPrefs.halfWidthPunctuationEnabled {
      punctuationNamePrefix = "_half_punctuation_"
    } else {
      punctuationNamePrefix = "_punctuation_"
    }

    let parser = currentMandarinParser
    let arrCustomPunctuations: [String] = [
      punctuationNamePrefix, parser, String(format: "%c", CChar(charCode)),
    ]
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

    let arrPunctuations: [String] = [punctuationNamePrefix, String(format: "%c", CChar(charCode))]
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

    // 這裡不使用小麥注音 2.2 版的組字區處理方式，而是直接由詞庫負責。
    if input.isUpperCaseASCIILetterKey {
      let letter: String! = String(format: "%@%c", "_letter_", CChar(charCode))
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

    // MARK: - 終末處理 (Still Nothing)

    /// 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 ctlInputMethod。
    /// 否則的話，可能會導致輸入法行為異常：部分應用會阻止輸入法完全攔截某些按鍵訊號。
    /// 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    /// 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if (state is InputState.NotEmpty) || !composer.isEmpty {
      IME.prtDebugIntel(
        "Blocked data: charCode: \(charCode), keyCode: \(input.keyCode)")
      IME.prtDebugIntel("A9BFF20E")
      errorCallback()
      stateCallback(state)
      return true
    }

    return false
  }
}
