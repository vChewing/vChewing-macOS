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

// MARK: - § State managements.

@objc extension KeyHandler {
	// MARK: - 構築狀態（State Building）

	func buildInputtingState() -> InputState.Inputting {
		// 觸發資料封裝更新，否則下文拿到的數據會是錯的。
		packageBufferStateMaterials()
		// 獲取封裝好的資料
		let composedText = getComposedText()
		let packagedCursorIndex = UInt(getPackagedCursorIndex())
		let resultOfBefore = getStrLocationResult(isAfter: false)
		let resultOfAfter = getStrLocationResult(isAfter: true)

		// 初期化狀態
		let newState = InputState.Inputting(composingBuffer: composedText, cursorIndex: packagedCursorIndex)

		// 組建提示文本
		var tooltip = ""
		if resultOfBefore == "", resultOfAfter != "" {
			tooltip = String(format: NSLocalizedString("Cursor is after \"%@\".", comment: ""), resultOfAfter)
		}
		if resultOfBefore != "", resultOfAfter == "" {
			tooltip = String(format: NSLocalizedString("Cursor is before \"%@\".", comment: ""), resultOfBefore)
		}
		if resultOfBefore != "", resultOfAfter != "" {
			tooltip = String(
				format: NSLocalizedString("Cursor is between \"%@\" and \"%@\".", comment: ""),
				resultOfAfter, resultOfBefore
			)
		}

		// 給新狀態安插配置好的提示文本、且送出新狀態
		newState.tooltip = tooltip
		return newState
	}

	// MARK: - 用以生成候選詞數組及狀態

	func _buildCandidateState(
		_ currentState: InputState.NotEmpty,
		useVerticalMode: Bool
	) -> InputState.ChoosingCandidate {
		let candidatesArray = getCandidatesArray()

		let state = InputState.ChoosingCandidate(
			composingBuffer: currentState.composingBuffer,
			cursorIndex: currentState.cursorIndex,
			candidates: candidatesArray,
			useVerticalMode: useVerticalMode
		)
		return state
	}

	// MARK: - 用以接收聯想詞數組且生成狀態

	// MARK: - 用以處理就地新增自訂語彙時的行為

	func _handleMarkingState(
		_ state: InputState.Marking,
		input: InputHandler,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if input.isESC {
			let inputting = buildInputtingState()
			stateCallback(inputting)
			return true
		}

		// Enter
		if input.isEnter {
			if let keyHandlerDelegate = delegate {
				if !keyHandlerDelegate.keyHandler(self, didRequestWriteUserPhraseWith: state) {
					IME.prtDebugIntel("5B69CC8D")
					errorCallback()
					return true
				}
			}

			let inputting = buildInputtingState()
			stateCallback(inputting)
			return true
		}

		// Shift + Left
		if input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward, input.isShiftHold {
			var index = state.markerIndex
			if index > 0 {
				index = UInt((state.composingBuffer as NSString).previousUtf16Position(for: Int(index)))
				let marking = InputState.Marking(
					composingBuffer: state.composingBuffer,
					cursorIndex: state.cursorIndex,
					markerIndex: index,
					readings: state.readings
				)
				marking.tooltipForInputting = state.tooltipForInputting

				if marking.markedRange.length == 0 {
					let inputting = marking.convertToInputting()
					stateCallback(inputting)
				} else {
					stateCallback(marking)
				}
			} else {
				IME.prtDebugIntel("1149908D")
				errorCallback()
				stateCallback(state)
			}
			return true
		}

		// Shift + Right
		if input.isCursorForward || input.emacsKey == vChewingEmacsKey.forward, input.isShiftHold {
			var index = state.markerIndex
			// 這裡繼續用 NSString 是為了與 Zonble 之前引入的 NSStringUtils 相容。
			// 不然的話，這行判斷會失敗、引發「9B51408D」錯誤。
			if index < ((state.composingBuffer as NSString).length) {
				index = UInt((state.composingBuffer as NSString).nextUtf16Position(for: Int(index)))
				let marking = InputState.Marking(
					composingBuffer: state.composingBuffer,
					cursorIndex: state.cursorIndex,
					markerIndex: index,
					readings: state.readings
				)
				marking.tooltipForInputting = state.tooltipForInputting
				if marking.markedRange.length == 0 {
					let inputting = marking.convertToInputting()
					stateCallback(inputting)
				} else {
					stateCallback(marking)
				}
			} else {
				IME.prtDebugIntel("9B51408D")
				errorCallback()
				stateCallback(state)
			}
			return true
		}
		return false
	}

	// MARK: - 標點輸入處理

	func _handlePunctuation(
		_ customPunctuation: String,
		state: InputState,
		usingVerticalMode useVerticalMode: Bool,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !ifLangModelHasUnigrams(forKey: customPunctuation) {
			return false
		}

		if isPhoneticReadingBufferEmpty() {
			insertReadingToBuilder(atCursor: customPunctuation)
			let poppedText = _popOverflowComposingTextAndWalk()
			let inputting = buildInputtingState()
			inputting.poppedText = poppedText
			stateCallback(inputting)

			if mgrPrefs.useSCPCTypingMode, isPhoneticReadingBufferEmpty() {
				let candidateState = _buildCandidateState(
					inputting, useVerticalMode: useVerticalMode
				)
				if candidateState.candidates.count == 1 {
					clear()
					if let strPoppedText: String = candidateState.candidates.first {
						let committing =
							InputState.Committing(poppedText: strPoppedText) as InputState.Committing
						stateCallback(committing)
						let empty = InputState.Empty()
						stateCallback(empty)
					} else {
						stateCallback(candidateState)
					}
				} else {
					stateCallback(candidateState)
				}
			}
			return true
		} else {
			// If there is still unfinished bpmf reading, ignore the punctuation
			IME.prtDebugIntel("A9B69908D")
			errorCallback()
			stateCallback(state)
			return true
		}
	}

	// MARK: - Enter 鍵處理

	@discardableResult func _handleEnterWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback _: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		clear()

		if let current = state as? InputState.Inputting {
			let composingBuffer = current.composingBuffer

			let committing = InputState.Committing(poppedText: composingBuffer)
			stateCallback(committing)
		}

		let empty = InputState.Empty()
		stateCallback(empty)
		return true
	}

	// MARK: - CMD+Enter 鍵處理

	func _handleCtrlCommandEnterWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback _: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		let readings: [String] = _currentReadings()
		let composingBuffer =
			(IME.areWeUsingOurOwnPhraseEditor)
			? readings.joined(separator: "-")
			: readings.joined(separator: " ")

		clear()

		let committing = InputState.Committing(poppedText: composingBuffer)
		stateCallback(committing)
		let empty = InputState.Empty()
		stateCallback(empty)
		return true
	}

	// MARK: - 處理 Backspace (macOS Delete) 按鍵行為

	func _handleBackspaceWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		if isPhoneticReadingBufferEmpty() {
			if getBuilderCursorIndex() >= 0 {
				deleteBuilderReadingInFrontOfCursor()
				_walk()
			} else {
				IME.prtDebugIntel("9D69908D")
				errorCallback()
				stateCallback(state)
				return true
			}
		} else {
			doBackSpaceToPhoneticReadingBuffer()
		}

		if isPhoneticReadingBufferEmpty(), getBuilderLength() == 0 {
			let empty = InputState.EmptyIgnoringPreviousState()
			stateCallback(empty)
		} else {
			let inputting = buildInputtingState()
			stateCallback(inputting)
		}
		return true
	}

	// MARK: - 處理 PC Delete (macOS Fn+BackSpace) 按鍵行為

	func _handleDeleteWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		if isPhoneticReadingBufferEmpty() {
			if getBuilderCursorIndex() != getBuilderLength() {
				deleteBuilderReadingAfterCursor()
				_walk()
				let inputting = buildInputtingState()
				// 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
				if !inputting.composingBuffer.isEmpty {
					let empty = InputState.EmptyIgnoringPreviousState()
					stateCallback(empty)
				} else {
					stateCallback(inputting)
				}
			} else {
				IME.prtDebugIntel("9B69938D")
				errorCallback()
				stateCallback(state)
			}
		} else {
			IME.prtDebugIntel("9C69908D")
			errorCallback()
			stateCallback(state)
		}

		return true
	}

	// MARK: - 處理與當前文字輸入排版前後方向呈 90 度的那兩個方向鍵的按鍵行為

	func _handleAbsorbedArrowKeyWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}
		if !isPhoneticReadingBufferEmpty() {
			IME.prtDebugIntel("9B6F908D")
			errorCallback()
		}
		stateCallback(state)
		return true
	}

	// MARK: - 處理 Home 鍵行為

	func _handleHomeWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		if !isPhoneticReadingBufferEmpty() {
			IME.prtDebugIntel("ABC44080")
			errorCallback()
			stateCallback(state)
			return true
		}

		if getBuilderCursorIndex() != 0 {
			setBuilderCursorIndex(0)
			let inputting = buildInputtingState()
			stateCallback(inputting)
		} else {
			IME.prtDebugIntel("66D97F90")
			errorCallback()
			stateCallback(state)
		}

		return true
	}

	// MARK: - 處理 End 鍵行為

	func _handleEndWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) {
			return false
		}

		if !isPhoneticReadingBufferEmpty() {
			IME.prtDebugIntel("9B69908D")
			errorCallback()
			stateCallback(state)
			return true
		}

		if getBuilderCursorIndex() != getBuilderLength() {
			setBuilderCursorIndex(getBuilderLength())
			let inputting = buildInputtingState()
			stateCallback(inputting)
		} else {
			IME.prtDebugIntel("9B69908E")
			errorCallback()
			stateCallback(state)
		}

		return true
	}

	// MARK: - 處理 Esc 鍵行為

	func _handleEscWithState(
		_ state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback _: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) { return false }

		let escToClearInputBufferEnabled: Bool = mgrPrefs.escToCleanInputBuffer

		if escToClearInputBufferEnabled {
			// If the option is enabled, we clear everything in the buffer.
			// This includes walked nodes and the reading. Note that this convention
			// is by default in macOS 10.0-10.5 built-in Panasonic Hanin and later macOS Zhuyin.
			// Some Windows users hate this design, hence the option here to disable it.
			clear()
			let empty = InputState.EmptyIgnoringPreviousState()
			stateCallback(empty)
		} else {
			// If reading is not empty, we cancel the reading.
			if !isPhoneticReadingBufferEmpty() {
				clearPhoneticReadingBuffer()
				if getBuilderLength() == 0 {
					let empty = InputState.Empty()
					stateCallback(empty)
				} else {
					let inputting = buildInputtingState()
					stateCallback(inputting)
				}
			}
		}
		return true
	}

	// MARK: - 處理向前方向鍵的行為

	func _handleForwardWithState(
		_ state: InputState,
		input: InputHandler,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) { return false }

		if !isPhoneticReadingBufferEmpty() {
			IME.prtDebugIntel("B3BA5257")
			errorCallback()
			stateCallback(state)
			return true
		}

		if let currentState = state as? InputState.Inputting {
			if input.isShiftHold {
				// Shift + Right
				if currentState.cursorIndex < (currentState.composingBuffer as NSString).length {
					let nextPosition = (currentState.composingBuffer as NSString).nextUtf16Position(
						for: Int(currentState.cursorIndex))
					let marking: InputState.Marking! = InputState.Marking(
						composingBuffer: currentState.composingBuffer,
						cursorIndex: currentState.cursorIndex,
						markerIndex: UInt(nextPosition),
						readings: _currentReadings()
					)
					marking.tooltipForInputting = currentState.tooltip
					stateCallback(marking)
				} else {
					IME.prtDebugIntel("BB7F6DB9")
					errorCallback()
					stateCallback(state)
				}
			} else {
				if getBuilderCursorIndex() < getBuilderLength() {
					setBuilderCursorIndex(getBuilderCursorIndex() + 1)
					let inputting = buildInputtingState()
					stateCallback(inputting)
				} else {
					IME.prtDebugIntel("A96AAD58")
					errorCallback()
					stateCallback(state)
				}
			}
		}

		return true
	}

	// MARK: - 處理向後方向鍵的行為

	func _handleBackwardWithState(
		_ state: InputState,
		input: InputHandler,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		if !(state is InputState.Inputting) { return false }

		if !isPhoneticReadingBufferEmpty() {
			IME.prtDebugIntel("6ED95318")
			errorCallback()
			stateCallback(state)
			return true
		}

		if let currentState = state as? InputState.Inputting {
			if input.isShiftHold {
				// Shift + left
				if currentState.cursorIndex > 0 {
					let previousPosition = (currentState.composingBuffer as NSString).previousUtf16Position(
						for: Int(currentState.cursorIndex))
					let marking: InputState.Marking! = InputState.Marking(
						composingBuffer: currentState.composingBuffer,
						cursorIndex: currentState.cursorIndex,
						markerIndex: UInt(previousPosition),
						readings: _currentReadings()
					)
					marking.tooltipForInputting = currentState.tooltip
					stateCallback(marking)
				} else {
					IME.prtDebugIntel("D326DEA3")
					errorCallback()
					stateCallback(state)
				}
			} else {
				if getBuilderCursorIndex() > 0 {
					setBuilderCursorIndex(getBuilderCursorIndex() - 1)
					let inputting = buildInputtingState()
					stateCallback(inputting)
				} else {
					IME.prtDebugIntel("7045E6F3")
					errorCallback()
					stateCallback(state)
				}
			}
		}

		return true
	}
}
