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

// Use KeyCodes as much as possible since its recognition won't be affected by macOS Base Keyboard Layouts.
// KeyCodes: https://eastmanreference.com/complete-list-of-applescript-key-codes
// Also: HIToolbox.framework/Versions/A/Headers/Events.h
@objc enum KeyCode: UInt16 {
	case kNone = 0
	case kCarriageReturn = 36  // Renamed from "kReturn" to avoid nomenclatural confusions.
	case kTab = 48
	case kSpace = 49
	case kSymbolMenuPhysicalKey = 50  // vChewing Specific
	case kBackSpace = 51  // Renamed from "kDelete" to avoid nomenclatural confusions.
	case kEscape = 53
	case kCommand = 55
	case kShift = 56
	case kCapsLock = 57
	case kOption = 58
	case kControl = 59
	case kRightShift = 60
	case kRightOption = 61
	case kRightControl = 62
	case kFunction = 63
	case kF17 = 64
	case kVolumeUp = 72
	case kVolumeDown = 73
	case kMute = 74
	case kLineFeed = 76  // Another keyCode to identify the Enter Key.
	case kF18 = 79
	case kF19 = 80
	case kF20 = 90
	case kF5 = 96
	case kF6 = 97
	case kF7 = 98
	case kF3 = 99
	case kF8 = 100
	case kF9 = 101
	case kF11 = 103
	case kF13 = 105
	case kF16 = 106
	case kF14 = 107
	case kF10 = 109
	case kF12 = 111
	case kF15 = 113
	case kHelp = 114
	case kHome = 115
	case kPageUp = 116
	case kWindowDelete = 117  // Renamed from "kForwardDelete" to avoid nomenclatural confusions.
	case kF4 = 118
	case kEnd = 119
	case kF2 = 120
	case kPageDown = 121
	case kF1 = 122
	case kLeftArrow = 123
	case kRightArrow = 124
	case kDownArrow = 125
	case kUpArrow = 126
}

// CharCodes: https://theasciicode.com.ar/ascii-control-characters/horizontal-tab-ascii-code-9.html
enum CharCode: UInt /*16*/ {
	case yajuusenpai = 114_514_19_19_810_893
	// CharCode is not reliable at all. KeyCode is the most appropriate choice due to its accuracy.
	// KeyCode doesn't give a phuque about the character sent through macOS keyboard layouts ...
	// ... but only focuses on which physical key is pressed.
}

class keyParser: NSObject {
	@objc private(set) var useVerticalMode: Bool
	@objc private(set) var inputText: String?
	@objc private(set) var inputTextIgnoringModifiers: String?
	@objc private(set) var charCode: UInt16
	@objc private(set) var keyCode: UInt16
	private var isFlagChanged: Bool
	private var flags: NSEvent.ModifierFlags
	private var cursorForwardKey: KeyCode
	private var cursorBackwardKey: KeyCode
	private var extraChooseCandidateKey: KeyCode
	private var extraChooseCandidateKeyReverse: KeyCode
	private var absorbedArrowKey: KeyCode
	private var verticalModeOnlyChooseCandidateKey: KeyCode
	@objc private(set) var emacsKey: vChewingEmacsKey

	@objc init(
		inputText: String?, keyCode: UInt16, charCode: UInt16, flags: NSEvent.ModifierFlags,
		isVerticalMode: Bool, inputTextIgnoringModifiers: String? = nil
	) {
		let inputText = AppleKeyboardConverter.cnvStringApple2ABC(inputText ?? "")
		let inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(
			inputTextIgnoringModifiers ?? inputText)
		self.inputText = inputText
		self.inputTextIgnoringModifiers = inputTextIgnoringModifiers
		self.flags = flags
		isFlagChanged = false
		useVerticalMode = isVerticalMode
		self.keyCode = keyCode
		self.charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
		emacsKey = EmacsKeyHelper.detect(
			charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: flags)
		// Define Arrow Keys
		cursorForwardKey = useVerticalMode ? .kDownArrow : .kRightArrow
		cursorBackwardKey = useVerticalMode ? .kUpArrow : .kLeftArrow
		extraChooseCandidateKey = useVerticalMode ? .kLeftArrow : .kDownArrow
		extraChooseCandidateKeyReverse = useVerticalMode ? .kRightArrow : .kUpArrow
		absorbedArrowKey = useVerticalMode ? .kRightArrow : .kUpArrow
		verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .kNone
		super.init()
	}

	@objc init(event: NSEvent, isVerticalMode: Bool) {
		inputText = AppleKeyboardConverter.cnvStringApple2ABC(event.characters ?? "")
		inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(
			event.charactersIgnoringModifiers ?? "")
		keyCode = event.keyCode
		flags = event.modifierFlags
		isFlagChanged = (event.type == .flagsChanged) ? true : false
		useVerticalMode = isVerticalMode
		let charCode: UInt16 = {
			guard let inputText = event.characters, inputText.count > 0 else {
				return 0
			}
			let first = inputText[inputText.startIndex].utf16.first!
			return first
		}()
		self.charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
		emacsKey = EmacsKeyHelper.detect(
			charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: flags)
		// Define Arrow Keys in the same way above.
		cursorForwardKey = useVerticalMode ? .kDownArrow : .kRightArrow
		cursorBackwardKey = useVerticalMode ? .kUpArrow : .kLeftArrow
		extraChooseCandidateKey = useVerticalMode ? .kLeftArrow : .kDownArrow
		extraChooseCandidateKeyReverse = useVerticalMode ? .kRightArrow : .kUpArrow
		absorbedArrowKey = useVerticalMode ? .kRightArrow : .kUpArrow
		verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .kNone
		super.init()
	}

	override var description: String {
		charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
		inputText = AppleKeyboardConverter.cnvStringApple2ABC(inputText ?? "")
		inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(
			inputTextIgnoringModifiers ?? "")
		return
			"<\(super.description) inputText:\(String(describing: inputText)), inputTextIgnoringModifiers:\(String(describing: inputTextIgnoringModifiers)) charCode:\(charCode), keyCode:\(keyCode), flags:\(flags), cursorForwardKey:\(cursorForwardKey), cursorBackwardKey:\(cursorBackwardKey), extraChooseCandidateKey:\(extraChooseCandidateKey), extraChooseCandidateKeyReverse:\(extraChooseCandidateKeyReverse), absorbedArrowKey:\(absorbedArrowKey),  verticalModeOnlyChooseCandidateKey:\(verticalModeOnlyChooseCandidateKey), emacsKey:\(emacsKey), useVerticalMode:\(useVerticalMode)>"
	}

	@objc var isShiftHold: Bool {
		flags.contains([.shift])
	}

	@objc var isCommandHold: Bool {
		flags.contains([.command])
	}

	@objc var isControlHold: Bool {
		flags.contains([.control])
	}

	@objc var isControlHotKey: Bool {
		flags.contains([.control]) && inputText?.first?.isLetter ?? false
	}

	@objc var isOptionHotKey: Bool {
		flags.contains([.option]) && inputText?.first?.isLetter ?? false
	}

	@objc var isOptionHold: Bool {
		flags.contains([.option])
	}

	@objc var isCapsLockOn: Bool {
		flags.contains([.capsLock])
	}

	@objc var isNumericPad: Bool {
		flags.contains([.numericPad])
	}

	@objc var isFunctionKeyHold: Bool {
		flags.contains([.function])
	}

	@objc var isReservedKey: Bool {
		guard let code = KeyCode(rawValue: keyCode) else {
			return false
		}
		return code.rawValue != KeyCode.kNone.rawValue
	}

	@objc var isTab: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kTab
	}

	@objc var isEnter: Bool {
		(KeyCode(rawValue: keyCode) == KeyCode.kCarriageReturn)
			|| (KeyCode(rawValue: keyCode) == KeyCode.kLineFeed)
	}

	@objc var isUp: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kUpArrow
	}

	@objc var isDown: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kDownArrow
	}

	@objc var isLeft: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kLeftArrow
	}

	@objc var isRight: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kRightArrow
	}

	@objc var isPageUp: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kPageUp
	}

	@objc var isPageDown: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kPageDown
	}

	@objc var isSpace: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kSpace
	}

	@objc var isBackSpace: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kBackSpace
	}

	@objc var isESC: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kEscape
	}

	@objc var isHome: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kHome
	}

	@objc var isEnd: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kEnd
	}

	@objc var isDelete: Bool {
		KeyCode(rawValue: keyCode) == KeyCode.kWindowDelete
	}

	@objc var isCursorBackward: Bool {
		KeyCode(rawValue: keyCode) == cursorBackwardKey
	}

	@objc var isCursorForward: Bool {
		KeyCode(rawValue: keyCode) == cursorForwardKey
	}

	@objc var isAbsorbedArrowKey: Bool {
		KeyCode(rawValue: keyCode) == absorbedArrowKey
	}

	@objc var isExtraChooseCandidateKey: Bool {
		KeyCode(rawValue: keyCode) == extraChooseCandidateKey
	}

	@objc var isExtraChooseCandidateKeyReverse: Bool {
		KeyCode(rawValue: keyCode) == extraChooseCandidateKeyReverse
	}

	@objc var isVerticalModeOnlyChooseCandidateKey: Bool {
		KeyCode(rawValue: keyCode) == verticalModeOnlyChooseCandidateKey
	}

	@objc var isUpperCaseASCIILetterKey: Bool {
		// 這裡必須加上「flags == .shift」，否則會出現某些情況下輸入法「誤判當前鍵入的非 Shift 字符為大寫」的問題。
		charCode >= 65 && charCode <= 90 && flags == .shift
	}

	@objc var isSymbolMenuPhysicalKey: Bool {
		// 這裡必須用 KeyCode，這樣才不會受隨 macOS 版本更動的 Apple 動態注音鍵盤排列內容的影響。
		// 只是必須得與 ![input isShift] 搭配使用才可以（也就是僅判定 Shift 沒被摁下的情形）。
		KeyCode(rawValue: keyCode) == KeyCode.kSymbolMenuPhysicalKey
	}

}

@objc enum vChewingEmacsKey: UInt16 {
	case none = 0
	case forward = 6  // F
	case backward = 2  // B
	case home = 1  // A
	case end = 5  // E
	case delete = 4  // D
	case nextPage = 22  // V
}

class EmacsKeyHelper: NSObject {
	@objc static func detect(charCode: UniChar, flags: NSEvent.ModifierFlags) -> vChewingEmacsKey {
		let charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
		if flags.contains(.control) {
			return vChewingEmacsKey(rawValue: charCode) ?? .none
		}
		return .none
	}
}
