/*
 *  KeyHandlerInput.swift
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

enum KeyCode: UInt16 {
    case none = 0
    case enter = 76
    case up = 126
    case down = 125
    case left = 123
    case right = 124
    case pageUp = 116
    case pageDown = 121
    case home = 115
    case end = 119
    case delete = 117
}

class KeyHandlerInput: NSObject {
    @objc private (set) var useVerticalMode: Bool
    @objc private (set) var inputText: String?
    @objc private (set) var charCode: UInt16
    private var keyCode: UInt16
    private var flags: NSEvent.ModifierFlags
    private var cursorForwardKey: KeyCode
    private var cursorBackwardKey: KeyCode
    private var extraChooseCandidateKey: KeyCode
    private var absorbedArrowKey: KeyCode
    private var verticalModeOnlyChooseCandidateKey: KeyCode
    @objc private (set) var emacsKey: vChewingEmacsKey

    @objc init(inputText: String?, keyCode: UInt16, charCode: UInt16, flags: NSEvent.ModifierFlags, isVerticalMode: Bool) {
        self.inputText = inputText
        self.keyCode = keyCode
        self.charCode = charCode
        self.flags = flags
        useVerticalMode = isVerticalMode
        emacsKey = EmacsKeyHelper.detect(charCode: charCode, flags: flags)
        cursorForwardKey = useVerticalMode ? .down : .right
        cursorBackwardKey = useVerticalMode ? .up : .left
        extraChooseCandidateKey = useVerticalMode ? .left : .down
        absorbedArrowKey = useVerticalMode ? .right : .up
        verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .none
        super.init()
    }

    @objc init(event: NSEvent, isVerticalMode: Bool) {
        inputText = event.characters
        keyCode = event.keyCode
        flags = event.modifierFlags
        useVerticalMode = isVerticalMode
        let charCode: UInt16 = {
            guard let inputText = event.characters, inputText.count > 0 else {
                return 0
            }
            let first = inputText[inputText.startIndex].utf16.first!
            return first
        }()
        self.charCode = charCode
        emacsKey = EmacsKeyHelper.detect(charCode: charCode, flags: event.modifierFlags)
        cursorForwardKey = useVerticalMode ? .down : .right
        cursorBackwardKey = useVerticalMode ? .up : .left
        extraChooseCandidateKey = useVerticalMode ? .left : .down
        absorbedArrowKey = useVerticalMode ? .right : .up
        verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .none
        super.init()
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

    @objc var isOptionHold: Bool {
        flags.contains([.option])
    }

    @objc var isCapsLockOn: Bool {
        flags.contains([.capsLock])
    }

    @objc var isNumericPad: Bool {
        flags.contains([.numericPad])
    }

    @objc var isEnter: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.enter
    }

    @objc var isUp: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.up
    }

    @objc var isDown: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.down
    }

    @objc var isLeft: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.left
    }

    @objc var isRight: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.right
    }

    @objc var isPageUp: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.pageUp
    }

    @objc var isPageDown: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.pageDown
    }

    @objc var isHome: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.home
    }

    @objc var isEnd: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.end
    }

    @objc var isDelete: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.delete
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

    @objc var isVerticalModeOnlyChooseCandidateKey: Bool {
        KeyCode(rawValue: keyCode) == verticalModeOnlyChooseCandidateKey
    }

}

@objc enum vChewingEmacsKey: UInt16 {
    case none = 0
    case forward = 6 // F
    case backward = 2 // B
    case home = 1 // A
    case end = 5 // E
    case delete = 4 // D
    case nextPage = 22 // V
}

class EmacsKeyHelper: NSObject {
    @objc static func detect(charCode: UniChar, flags: NSEvent.ModifierFlags) -> vChewingEmacsKey {
        if flags.contains(.control) {
            return vChewingEmacsKey(rawValue: charCode) ?? .none
        }
        return .none;
    }
}
