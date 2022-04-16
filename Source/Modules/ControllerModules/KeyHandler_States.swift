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

	// MARK: 用以生成候選詞數組
	func _buildCandidateState(
		_ currentState: InputState.NotEmpty,
		useVerticalMode: Bool
	) -> InputState.ChoosingCandidate {
		let candidatesArray = getCandidatesArray()

		let state = InputState.ChoosingCandidate(
			composingBuffer: currentState.composingBuffer,
			cursorIndex: currentState.cursorIndex,
			candidates: candidatesArray as! [String],
			useVerticalMode: useVerticalMode)
		return state
	}

	// MARK: 用以處理就地新增自訂語彙時的行為
	func _handleMarkingState(
		_ state: InputState.Marking,
		input: keyParser,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {

		if input.isESC {
			let inputting = buildInputtingState() as! InputState.Inputting
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

			let inputting = buildInputtingState() as! InputState.Inputting
			stateCallback(inputting)
			return true
		}

		// Shift + Left
		if (input.isCursorBackward || input.emacsKey == vChewingEmacsKey.backward) && (input.isShiftHold) {
			var index = state.markerIndex
			if index > 0 {
				index = UInt((state.composingBuffer as NSString).previousUtf16Position(for: Int(index)))
				let marking = InputState.Marking(
					composingBuffer: state.composingBuffer,
					cursorIndex: state.cursorIndex,
					markerIndex: index,
					readings: state.readings)
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
		if (input.isCursorForward || input.emacsKey == vChewingEmacsKey.forward) && (input.isShiftHold) {
			var index = state.markerIndex
			// 這裡繼續用 NSString 是為了與 Zonble 之前引入的 NSStringUtils 相容。
			// 不然的話，這行判斷會失敗、引發「9B51408D」錯誤。
			if index < ((state.composingBuffer as NSString).length) {
				index = UInt((state.composingBuffer as NSString).nextUtf16Position(for: Int(index)))
				let marking = InputState.Marking(
					composingBuffer: state.composingBuffer,
					cursorIndex: state.cursorIndex,
					markerIndex: index,
					readings: state.readings)
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
}
