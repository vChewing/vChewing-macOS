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

import Cocoa
import SwiftUI

// MARK: - § Handle Input with States.

extension KeyHandler {
  func handle(
    input: InputSignal,
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping () -> Void
  ) -> Bool {
    let charCode: UniChar = input.charCode
    var state = state  // Turn this incoming constant into variable.

    // Ignore the input if its inputText is empty.
    // Reason: such inputs may be functional key combinations.
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

    // Ignore the input if the composing buffer is empty with no reading
    // and there is some function key combination.
    let isFunctionKey: Bool =
      input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNumericPad)
    if !(state is InputState.NotEmpty) && !(state is InputState.AssociatedPhrases) && isFunctionKey {
      return false
    }

    // MARK: Caps Lock processing.

    // If Caps Lock is ON, temporarily disable phonetic reading.
    // Note: Alphanumerical mode processing.
    if input.isBackSpace || input.isEnter || input.isAbsorbedArrowKey || input.isExtraChooseCandidateKey
      || input.isExtraChooseCandidateKeyReverse || input.isCursorForward || input.isCursorBackward
    {
      // Do nothing if backspace is pressed -- we ignore the key
    } else if input.isCapsLockOn {
      // Process all possible combination, we hope.
      clear()
      stateCallback(InputState.Empty())

      // When shift is pressed, don't do further processing...
      // ...since it outputs capital letter anyway.
      if input.isShiftHold {
        return false
      }

      // If ASCII but not printable, don't use insertText:replacementRange:
      // Certain apps don't handle non-ASCII char insertions.
      if charCode < 0x80, !CTools.isPrintable(charCode) {
        return false
      }

      // Commit the entire input buffer.
      stateCallback(InputState.Committing(poppedText: inputText.lowercased()))
      stateCallback(InputState.Empty())

      return true
    }

    // MARK: Numeric Pad Processing.

    if input.isNumericPad {
      if !input.isLeft, !input.isRight, !input.isDown,
        !input.isUp, !input.isSpace, CTools.isPrintable(charCode)
      {
        clear()
        stateCallback(InputState.Empty())
        stateCallback(InputState.Committing(poppedText: inputText.lowercased()))
        stateCallback(InputState.Empty())
        return true
      }
    }

    // MARK: Handle Candidates.

    if state is InputState.ChoosingCandidate {
      return handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Handle Associated Phrases.

    if state is InputState.AssociatedPhrases {
      if handleCandidate(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      ) {
        return true
      } else {
        stateCallback(InputState.Empty())
      }
    }

    // MARK: Handle Marking.

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

    // MARK: Handle BPMF Keys.

    var keyConsumedByReading = false
    let skipPhoneticHandling = input.isReservedKey || input.isControlHold || input.isOptionHold

    // See if Phonetic reading is valid.
    if !skipPhoneticHandling && composer.inputValidityCheck(key: charCode) {
      composer.receiveKey(fromCharCode: charCode)
      keyConsumedByReading = true

      // If we have a tone marker, we have to insert the reading to the
      // builder in other words, if we don't have a tone marker, we just
      // update the composing buffer.
      let composeReading = composer.hasToneMarker()
      if !composeReading {
        stateCallback(buildInputtingState)
        return true
      }
    }

    var composeReading = composer.hasToneMarker()  // 這裡不需要做排他性判斷。

    // See if we have composition if Enter/Space is hit and buffer is not empty.
    // We use "|=" conditioning so that the tone marker key is also taken into account.
    // However, Swift does not support "|=".
    composeReading = composeReading || (!composer.isEmpty && (input.isSpace || input.isEnter))
    if composeReading {
      if input.isSpace, !composer.hasToneMarker() {
        composer.receiveKey(fromString: " ")  // 補上空格。
      }
      let reading = composer.getComposition()

      // See whether we have a unigram for this...
      if !ifLangModelHasUnigrams(forKey: reading) {
        IME.prtDebugIntel("B49C0979：語彙庫內無「\(reading)」的匹配記錄。")
        errorCallback()
        composer.clear()
        stateCallback((builderLength == 0) ? InputState.EmptyIgnoringPreviousState() : buildInputtingState)
        return true
      }

      // ... and insert it into the grid...
      insertReadingToBuilderAtCursor(reading: reading)

      // ... then walk the grid...
      let poppedText = popOverflowComposingTextAndWalk

      // ... get and tweak override model suggestion if possible...
      // dealWithOverrideModelSuggestions()  // 暫時禁用，因為無法使其生效。

      // ... then update the text.
      composer.clear()

      let inputting = buildInputtingState
      inputting.poppedText = poppedText
      stateCallback(inputting)

      if mgrPrefs.useSCPCTypingMode {
        let choosingCandidates: InputState.ChoosingCandidate = buildCandidate(
          state: inputting,
          isTypingVertical: input.isTypingVertical
        )
        if choosingCandidates.candidates.count == 1 {
          clear()
          let text: String = choosingCandidates.candidates.first ?? ""
          stateCallback(InputState.Committing(poppedText: text))

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
      return true  // Telling the client that the key is consumed.
    }

    // The only possibility for this to be true is that the Phonetic reading
    // already has a tone marker but the last key is *not* a tone marker key. An
    // example is the sequence "6u" with the Standard layout, which produces "ㄧˊ"
    // but does not compose. Only sequences such as "ㄧˊ", "ˊㄧˊ", "ˊㄧˇ", or "ˊㄧ "
    // would compose.
    if keyConsumedByReading {
      stateCallback(buildInputtingState)
      return true
    }

    // MARK: Calling candidate window using Up / Down or PageUp / PageDn.

    if let currentState = state as? InputState.NotEmpty, composer.isEmpty,
      input.isExtraChooseCandidateKey || input.isExtraChooseCandidateKeyReverse || input.isSpace
        || input.isPageDown || input.isPageUp || (input.isTab && mgrPrefs.specifyShiftTabKeyBehavior)
        || (input.isTypingVertical && (input.isverticalTypingOnlyChooseCandidateKey))
    {
      if input.isSpace {
        // If the Space key is NOT set to be a selection key
        if input.isShiftHold || !mgrPrefs.chooseCandidateUsingSpace {
          if builderCursorIndex >= builderLength {
            let composingBuffer = currentState.composingBuffer
            if !composingBuffer.isEmpty {
              stateCallback(InputState.Committing(poppedText: composingBuffer))
            }
            clear()
            stateCallback(InputState.Committing(poppedText: " "))
            stateCallback(InputState.Empty())
          } else if ifLangModelHasUnigrams(forKey: " ") {
            insertReadingToBuilderAtCursor(reading: " ")
            let poppedText = popOverflowComposingTextAndWalk
            let inputting = buildInputtingState
            inputting.poppedText = poppedText
            stateCallback(inputting)
          }
          return true
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
      return handleTab(
        state: state, isShiftHold: input.isShiftHold, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Cursor backward

    if input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward {
      return handleBackward(
        state: state,
        input: input,
        stateCallback: stateCallback,
        errorCallback: errorCallback
      )
    }

    // MARK: Cursor forward

    if input.isCursorForward || input.emacsKey == vChewingEmacsKey.forward {
      return handleForward(
        state: state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
      )
    }

    // MARK: Home

    if input.isHome || input.emacsKey == vChewingEmacsKey.home {
      return handleHome(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
    }

    // MARK: End

    if input.isEnd || input.emacsKey == vChewingEmacsKey.end {
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

    if input.isDelete || input.emacsKey == vChewingEmacsKey.delete {
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
            insertReadingToBuilderAtCursor(reading: "_punctuation_list")
            let poppedText: String! = popOverflowComposingTextAndWalk
            let inputting = buildInputtingState
            inputting.poppedText = poppedText
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
        // 這裡不需要該函數所傳回的 bool 結果，所以用「_ =」解消掉。
        _ = handleEnter(state: state, stateCallback: stateCallback, errorCallback: errorCallback)
        stateCallback(InputState.SymbolTable(node: SymbolNode.root, isTypingVertical: input.isTypingVertical))
        return true
      }
    }

    // MARK: Punctuation

    // If nothing is matched, see if it's a punctuation key for current layout.

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

    // if nothing is matched, see if it's a punctuation key.
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

    // MARK: - Still Nothing.

    // Still nothing? Then we update the composing buffer.
    // Note that some app has strange behavior if we don't do this,
    // "thinking" that the key is not actually consumed.
    // 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    // 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
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
