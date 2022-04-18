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

// MARK: - § Handle Input with States.

@objc extension KeyHandler {
	func handle(
		input: InputHandler,
		state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		let charCode: UniChar = input.charCode
		var state = state  // Turn this incoming constant into variable.
		let inputText: String = input.inputText ?? ""

		// Ignore the input if its inputText is empty.
		// Reason: such inputs may be functional key combinations.

		if inputText.isEmpty {
			return false
		}

		// Ignore the input if the composing buffer is empty with no reading
		// and there is some function key combination.
		let isFunctionKey: Bool =
			input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNumericPad)
		if !(state is InputState.NotEmpty) && !(state is InputState.AssociatedPhrases) && isFunctionKey {
			return false
		}

		// MARK: Caps Lock processing.

		// If Caps Lock is ON, temporarily disable bopomofo.
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
			if charCode < 0x80, !isPrintable(charCode) {
				return false
			}

			// Commit the entire input buffer.
			let committingState = InputState.Committing(poppedText: inputText.lowercased())
			stateCallback(committingState)
			stateCallback(InputState.Empty())

			return true
		}

		// MARK: Numeric Pad Processing.

		if input.isNumericPad {
			if !input.isLeft, !input.isRight, !input.isDown,
				!input.isUp, !input.isSpace, isPrintable(charCode)
			{
				clear()
				stateCallback(InputState.Empty())
				let committing = InputState.Committing(poppedText: inputText.lowercased())
				stateCallback(committing)
				stateCallback(InputState.Empty())
				return true
			}
		}

		// MARK: Handle Candidates.

		if state is InputState.ChoosingCandidate {
			return _handleCandidateState(
				state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
			)
		}

		// MARK: Handle Associated Phrases.

		if state is InputState.AssociatedPhrases {
			let result = _handleCandidateState(
				state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
			)
			if result {
				return true
			} else {
				stateCallback(InputState.Empty())
			}
		}

		// MARK: Handle Marking.

		if state is InputState.Marking {
			let marking = state as! InputState.Marking

			if _handleMarkingState(
				state as! InputState.Marking, input: input, stateCallback: stateCallback,
				errorCallback: errorCallback
			) {
				return true
			}

			state = marking.convertToInputting()
			stateCallback(state)
		}

		// MARK: Handle BPMF Keys.

		var composeReading = false
		let skipPhoneticHandling = input.isReservedKey || input.isControlHold || input.isOptionHold

		// See if Phonetic reading is valid.
		if !skipPhoneticHandling && chkKeyValidity(charCode) {
			combinePhoneticReadingBufferKey(charCode)

			// If we have a tone marker, we have to insert the reading to the
			// builder in other words, if we don't have a tone marker, we just
			// update the composing buffer.
			composeReading = checkWhetherToneMarkerConfirmsPhoneticReadingBuffer()
			if !composeReading {
				let inputting = buildInputtingState()
				stateCallback(inputting)
				return true
			}
		}

		// See if we have composition if Enter/Space is hit and buffer is not empty.
		// We use "|=" conditioning so that the tone marker key is also taken into account.
		// However, Swift does not support "|=".
		composeReading = composeReading || (!isPhoneticReadingBufferEmpty() && (input.isSpace || input.isEnter))
		if composeReading {
			let reading = getSyllableCompositionFromPhoneticReadingBuffer()

			if !ifLangModelHasUnigrams(forKey: reading) {
				IME.prtDebugIntel("B49C0979")
				errorCallback()
				let inputting = buildInputtingState()
				stateCallback(inputting)
				return true
			}

			// ... and insert it into the lattice grid...
			insertReadingToBuilder(atCursor: reading)

			// ... then walk the lattice grid...
			let poppedText = _popOverflowComposingTextAndWalk()

			// ... get and tweak override model suggestion if possible...
			dealWithOverrideModelSuggestions()

			// ... then update the text.
			clearPhoneticReadingBuffer()

			let inputting = buildInputtingState()
			inputting.poppedText = poppedText
			stateCallback(inputting)

			if mgrPrefs.useSCPCTypingMode {
				let choosingCandidates: InputState.ChoosingCandidate = _buildCandidateState(
					inputting,
					useVerticalMode: input.useVerticalMode
				)
				if choosingCandidates.candidates.count == 1 {
					clear()
					let text: String = choosingCandidates.candidates.first ?? ""
					let committing = InputState.Committing(poppedText: text)
					stateCallback(committing)

					if !mgrPrefs.associatedPhrasesEnabled {
						stateCallback(InputState.Empty())
					} else {
						let associatedPhrases =
							buildAssociatePhraseState(
								withKey: text,
								useVerticalMode: input.useVerticalMode
							) as? InputState.AssociatedPhrases
						if let associatedPhrases = associatedPhrases {
							stateCallback(associatedPhrases)
						} else {
							stateCallback(InputState.Empty())
						}
					}
				} else {
					stateCallback(choosingCandidates)
				}
			}
			return true
		}

		// MARK: Calling candidate window using Space or Down or PageUp / PageDn.

		if isPhoneticReadingBufferEmpty() && (state is InputState.NotEmpty)
			&& (input.isExtraChooseCandidateKey || input.isExtraChooseCandidateKeyReverse || input.isSpace
				|| input.isPageDown || input.isPageUp || input.isTab
				|| (input.useVerticalMode && (input.isVerticalModeOnlyChooseCandidateKey)))
		{
			if input.isSpace {
				// If the Space key is NOT set to be a selection key
				if input.isShiftHold || !mgrPrefs.chooseCandidateUsingSpace {
					if getBuilderCursorIndex() >= getBuilderLength() {
						let composingBuffer = (state as! InputState.NotEmpty).composingBuffer
						if (composingBuffer.count) != 0 {
							let committing = InputState.Committing(poppedText: composingBuffer)
							stateCallback(committing)
						}
						clear()
						let committing = InputState.Committing(poppedText: " ")
						stateCallback(committing)
						let empty = InputState.Empty()
						stateCallback(empty)
					} else if ifLangModelHasUnigrams(forKey: " ") {
						insertReadingToBuilder(atCursor: " ")
						let poppedText = _popOverflowComposingTextAndWalk()
						let inputting = buildInputtingState()
						inputting.poppedText = poppedText
						stateCallback(inputting)
					}
					return true
				}
			}
			let choosingCandidates = _buildCandidateState(
				state as! InputState.NotEmpty,
				useVerticalMode: input.useVerticalMode
			)
			stateCallback(choosingCandidates)
			return true
		}

		// MARK: -

		// MARK: Esc

		if input.isESC { return _handleEscWithState(state, stateCallback: stateCallback, errorCallback: errorCallback) }

		// MARK: Cursor backward

		if input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward {
			return _handleBackwardWithState(
				state,
				input: input,
				stateCallback: stateCallback,
				errorCallback: errorCallback
			)
		}

		// MARK: Cursor forward

		if input.isCursorForward || input.emacsKey == vChewingEmacsKey.forward {
			return _handleForwardWithState(
				state, input: input, stateCallback: stateCallback, errorCallback: errorCallback
			)
		}

		// MARK: Home

		if input.isHome || input.emacsKey == vChewingEmacsKey.home {
			return _handleHomeWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: End

		if input.isEnd || input.emacsKey == vChewingEmacsKey.end {
			return _handleEndWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: Ctrl+PgLf or Shift+PgLf

		if (input.isControlHold || input.isShiftHold) && (input.isOptionHold && input.isLeft) {
			return _handleHomeWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: Ctrl+PgRt or Shift+PgRt

		if (input.isControlHold || input.isShiftHold) && (input.isOptionHold && input.isRight) {
			return _handleEndWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: AbsorbedArrowKey

		if input.isAbsorbedArrowKey || input.isExtraChooseCandidateKey || input.isExtraChooseCandidateKeyReverse {
			return _handleAbsorbedArrowKeyWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: Backspace

		if input.isBackSpace {
			return _handleBackspaceWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: Delete

		if input.isDelete || input.emacsKey == vChewingEmacsKey.delete {
			return _handleDeleteWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: Enter

		if input.isEnter {
			return (input.isCommandHold && input.isControlHold)
				? _handleCtrlCommandEnterWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
				: _handleEnterWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
		}

		// MARK: -

		// MARK: Punctuation list

		if input.isSymbolMenuPhysicalKey && !input.isShiftHold {
			if !input.isOptionHold {
				if ifLangModelHasUnigrams(forKey: "_punctuation_list") {
					if isPhoneticReadingBufferEmpty() {
						insertReadingToBuilder(atCursor: "_punctuation_list")
						let poppedText: String! = _popOverflowComposingTextAndWalk()
						let inputting = buildInputtingState()
						inputting.poppedText = poppedText
						stateCallback(inputting)
						let choosingCandidate =
							_buildCandidateState(inputting, useVerticalMode: input.useVerticalMode)
						stateCallback(choosingCandidate)
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
				_ = _handleEnterWithState(state, stateCallback: stateCallback, errorCallback: errorCallback)
				let root: SymbolNode! = SymbolNode.root
				let symbolState =
					InputState.SymbolTable(node: root, useVerticalMode: input.useVerticalMode)
				stateCallback(symbolState)
				return true
			}
		}

		// MARK: Punctuation

		// if nothing is matched, see if it's a punctuation key for current layout.

		var punctuationNamePrefix = ""

		if input.isOptionHold {
			punctuationNamePrefix = "_alt_punctuation_"
		} else if input.isControlHold {
			punctuationNamePrefix = "_ctrl_punctuation_"
		} else if mgrPrefs.halfWidthPunctuationEnabled {
			punctuationNamePrefix = "_half_punctuation_"
		} else {
			punctuationNamePrefix = "_punctuation_"
		}

		let parser = getCurrentMandarinParser()
		let arrCustomPunctuations: [String] = [
			punctuationNamePrefix, parser, String(format: "%c", CChar(charCode)),
		]
		let customPunctuation: String = arrCustomPunctuations.joined(separator: "")
		if _handlePunctuation(
			customPunctuation,
			state: state,
			usingVerticalMode: input.useVerticalMode,
			stateCallback: stateCallback,
			errorCallback: errorCallback
		) {
			return true
		}

		// if nothing is matched, see if it's a punctuation key.
		let arrPunctuations: [String] = [punctuationNamePrefix, String(format: "%c", CChar(charCode))]
		let punctuation: String = arrPunctuations.joined(separator: "")

		if _handlePunctuation(
			punctuation,
			state: state,
			usingVerticalMode: input.useVerticalMode,
			stateCallback: stateCallback,
			errorCallback: errorCallback
		) {
			return true
		}

		// 這裡不使用小麥注音 2.2 版的組字區處理方式，而是直接由詞庫負責。
		if input.isUpperCaseASCIILetterKey {
			let letter: String! = String(format: "%@%c", "_letter_", CChar(charCode))
			if _handlePunctuation(
				letter,
				state: state,
				usingVerticalMode: input.useVerticalMode,
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
		if (state is InputState.NotEmpty) || !isPhoneticReadingBufferEmpty() {
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
