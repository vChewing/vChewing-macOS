// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

// Use KeyCodes as much as possible since its recognition won't be affected by macOS Base Keyboard Layouts.
// KeyCodes: https://eastmanreference.com/complete-list-of-applescript-key-codes
@objc enum KeyCode: UInt16 {
    case none = 0
    case space = 49
    case backSpace = 51
    case esc = 53
    case tab = 48
    case enterLF = 76
    case enterCR = 36
    case up = 126
    case down = 125
    case left = 123
    case right = 124
    case pageUp = 116
    case pageDown = 121
    case home = 115
    case end = 119
    case delete = 117
    case leftShift = 56
    case rightShift = 60
    case capsLock = 57
}

// CharCodes: https://theasciicode.com.ar/ascii-control-characters/horizontal-tab-ascii-code-9.html
enum CharCode: UInt16 {
    case symbolMenuKey_ABC = 96
}

class KeyHandlerInput: NSObject {
    @objc private (set) var useVerticalMode: Bool
    @objc private (set) var inputText: String?
    @objc private (set) var inputTextIgnoringModifiers: String?
    @objc private (set) var charCode: UInt16
    @objc private (set) var keyCode: UInt16
    private var isFlagChanged: Bool
    private var flags: NSEvent.ModifierFlags
    private var cursorForwardKey: KeyCode
    private var cursorBackwardKey: KeyCode
    private var extraChooseCandidateKey: KeyCode
    private var extraChooseCandidateKeyReverse: KeyCode
    private var absorbedArrowKey: KeyCode
    private var verticalModeOnlyChooseCandidateKey: KeyCode
    @objc private (set) var emacsKey: vChewingEmacsKey

    @objc init(inputText: String?, keyCode: UInt16, charCode: UInt16, flags: NSEvent.ModifierFlags, isVerticalMode: Bool, inputTextIgnoringModifiers: String? = nil) {
        let inputText = AppleKeyboardConverter.cnvStringApple2ABC(inputText ?? "")
        let inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(inputTextIgnoringModifiers ?? inputText)
        self.inputText = inputText
        self.inputTextIgnoringModifiers = inputTextIgnoringModifiers
        self.keyCode = keyCode
        self.charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
        self.flags = flags
        self.isFlagChanged = false
        useVerticalMode = isVerticalMode
        emacsKey = EmacsKeyHelper.detect(charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: flags)
        cursorForwardKey = useVerticalMode ? .down : .right
        cursorBackwardKey = useVerticalMode ? .up : .left
        extraChooseCandidateKey = useVerticalMode ? .left : .down
        extraChooseCandidateKeyReverse = useVerticalMode ? .right : .up
        absorbedArrowKey = useVerticalMode ? .right : .up
        verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .none
        super.init()
    }

    @objc init(event: NSEvent, isVerticalMode: Bool) {
        inputText = AppleKeyboardConverter.cnvStringApple2ABC(event.characters ?? "")
        inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(event.charactersIgnoringModifiers ?? "")
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
        emacsKey = EmacsKeyHelper.detect(charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: event.modifierFlags)
        cursorForwardKey = useVerticalMode ? .down : .right
        cursorBackwardKey = useVerticalMode ? .up : .left
        extraChooseCandidateKey = useVerticalMode ? .left : .down
        extraChooseCandidateKeyReverse = useVerticalMode ? .right : .up
        absorbedArrowKey = useVerticalMode ? .right : .up
        verticalModeOnlyChooseCandidateKey = useVerticalMode ? absorbedArrowKey : .none
        super.init()
    }

    override var description: String {
        charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
        inputText = AppleKeyboardConverter.cnvStringApple2ABC(inputText ?? "")
        inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(inputTextIgnoringModifiers ?? "")
        return "<\(super.description) inputText:\(String(describing: inputText)), inputTextIgnoringModifiers:\(String(describing: inputTextIgnoringModifiers)) charCode:\(charCode), keyCode:\(keyCode), flags:\(flags), cursorForwardKey:\(cursorForwardKey), cursorBackwardKey:\(cursorBackwardKey), extraChooseCandidateKey:\(extraChooseCandidateKey), extraChooseCandidateKeyReverse:\(extraChooseCandidateKeyReverse), absorbedArrowKey:\(absorbedArrowKey),  verticalModeOnlyChooseCandidateKey:\(verticalModeOnlyChooseCandidateKey), emacsKey:\(emacsKey), useVerticalMode:\(useVerticalMode)>"
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

    @objc var isReservedKey: Bool {
        guard let code = KeyCode(rawValue: keyCode) else {
            return false
        }
        return code.rawValue != KeyCode.none.rawValue
    }

    @objc var isTab: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.tab
    }

    @objc var isEnter: Bool {
        (KeyCode(rawValue: keyCode) == KeyCode.enterCR) || (KeyCode(rawValue: keyCode) == KeyCode.enterLF)
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

    @objc var isSpace: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.space
    }

    @objc var isBackSpace: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.backSpace
    }

    @objc var isESC: Bool {
        KeyCode(rawValue: keyCode) == KeyCode.esc
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

    @objc var isExtraChooseCandidateKeyReverse: Bool {
        KeyCode(rawValue: keyCode) == extraChooseCandidateKeyReverse
    }

    @objc var isVerticalModeOnlyChooseCandidateKey: Bool {
        KeyCode(rawValue: keyCode) == verticalModeOnlyChooseCandidateKey
    }

    @objc var isSymbolMenuKey: Bool {
        // 這裡用 CharCode 更合適，不然就無法輸入波浪鍵了。
        CharCode(rawValue: charCode) == CharCode.symbolMenuKey_ABC
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
        let charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
        if flags.contains(.control) {
            return vChewingEmacsKey(rawValue: charCode) ?? .none
        }
        return .none;
    }
}
