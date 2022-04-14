// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

@objc extension KeyHandler {
	func handleInputSwift(
		input: keyParser,
		state: InputState,
		stateCallback: @escaping (InputState) -> Void,
		errorCallback: @escaping () -> Void
	) -> Bool {
		let charCode: UniChar = input.charCode
		// let emacsKey: vChewingEmacsKey = input.emacsKey
		let inputText: String = input.inputText ?? ""

		// Ignore the input if its inputText is empty.
		// Reason: such inputs may be functional key combinations.

		if (inputText).isEmpty {
			return false
		}

		// Ignore the input if the composing buffer is empty with no reading
		// and there is some function key combination.
		let isFunctionKey: Bool =
			input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNumericPad)
		if !(state is InputState.NotEmpty) && !(state is InputState.AssociatedPhrases) && isFunctionKey {
			return false
		}

		// MARK: - Caps Lock processing.
		// If Caps Lock is ON, temporarily disable bopomofo.
		// Note: Alphanumerical mode processing.
		if input.isBackSpace || input.isEnter || input.isAbsorbedArrowKey || input.isExtraChooseCandidateKey
			|| input.isExtraChooseCandidateKeyReverse || input.isCursorForward || input.isCursorBackward
		{
			// Do nothing if backspace is pressed -- we ignore the key
		} else if input.isCapsLockOn {
			// Process all possible combination, we hope.
			clear()
			let emptyState = InputState.Empty()
			stateCallback(emptyState)

			// When shift is pressed, don't do further processing...
			// ...since it outputs capital letter anyway.
			if input.isShiftHold {
				return false
			}

			// If ASCII but not printable, don't use insertText:replacementRange:
			// Certain apps don't handle non-ASCII char insertions.
			if charCode < 0x80 && !isPrintable(charCode) {
				return false
			}

			// Commit the entire input buffer.
			let committingState = InputState.Committing(poppedText: inputText.lowercased())
			stateCallback(committingState)
			stateCallback(emptyState)

			return true
		}

		// MARK: - Numeric Pad Processing.
		if input.isNumericPad {
			if !input.isLeft && !input.isRight && !input.isDown
				&& !input.isUp && !input.isSpace && isPrintable(charCode)
			{
				clear()
				let emptyState = InputState.Empty()
				stateCallback(emptyState)
				let committing = InputState.Committing(poppedText: inputText.lowercased())
				stateCallback(committing)
				stateCallback(emptyState)
				return true
			}
		}

		// MARK: - Still Nothing.
		// Still nothing? Then we update the composing buffer.
		// Note that some app has strange behavior if we don't do this,
		// "thinking" that the key is not actually consumed).
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
