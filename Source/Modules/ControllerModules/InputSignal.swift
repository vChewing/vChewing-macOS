// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// Use KeyCodes as much as possible since its recognition won't be affected by macOS Base Keyboard Layouts.
// KeyCodes: https://eastmanreference.com/complete-list-of-applescript-key-codes
// Also: HIToolbox.framework/Versions/A/Headers/Events.h
enum KeyCode: UInt16 {
  case kNone = 0
  case kCarriageReturn = 36  // Renamed from "kReturn" to avoid nomenclatural confusions.
  case kTab = 48
  case kSpace = 49
  case kSymbolMenuPhysicalKeyIntl = 50  // vChewing Specific (Non-JIS)
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
  case kLineFeed = 76  // Another keyCode to identify the Enter Key, typable by Fn+Enter.
  case kF18 = 79
  case kF19 = 80
  case kF20 = 90
  case kSymbolMenuPhysicalKeyJIS = 94  // vChewing Specific (JIS)
  case kF5 = 96
  case kF6 = 97
  case kF7 = 98
  case kF3 = 99
  case kF8 = 100
  case kF9 = 101
  case kF11 = 103
  case kF13 = 105  // PrtSc
  case kF16 = 106
  case kF14 = 107
  case kF10 = 109
  case kF12 = 111
  case kF15 = 113
  case kHelp = 114  // Insert
  case kHome = 115
  case kPageUp = 116
  case kWindowsDelete = 117  // Renamed from "kForwardDelete" to avoid nomenclatural confusions.
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

enum KeyCodeBlackListed: UInt16 {
  case kF17 = 64
  case kVolumeUp = 72
  case kVolumeDown = 73
  case kMute = 74
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
  case kF13 = 105  // PrtSc
  case kF16 = 106
  case kF14 = 107
  case kF10 = 109
  case kF12 = 111
  case kF15 = 113
  case kHelp = 114  // Insert
  case kF4 = 118
  case kF2 = 120
  case kF1 = 122
}

/// 數字小鍵盤區域的按鍵的 KeyCode。
///
/// 注意：第 95 號 Key Code（逗號）為 JIS 佈局特有的數字小鍵盤按鍵。
let arrNumpadKeyCodes: [UInt16] = [65, 67, 69, 71, 75, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 95]

/// 主鍵盤區域的數字鍵的 KeyCode。
let arrMainAreaNumKey: [UInt16] = [18, 19, 20, 21, 22, 23, 25, 26, 28, 29]

// CharCodes: https://theasciicode.com.ar/ascii-control-characters/horizontal-tab-ascii-code-9.html
enum CharCode: UInt16 {
  case yajuusenpaiA = 114
  case yajuusenpaiB = 514
  case yajuusenpaiC = 1919
  case yajuusenpaiD = 810
  // CharCode is not reliable at all. KeyCode is the most appropriate choice due to its accuracy.
  // KeyCode doesn't give a phuque about the character sent through macOS keyboard layouts ...
  // ... but only focuses on which physical key is pressed.
}

struct InputSignal: CustomStringConvertible {
  private(set) var isTypingVertical: Bool
  private(set) var inputText: String
  private(set) var inputTextIgnoringModifiers: String?
  private(set) var charCode: UInt16
  private(set) var keyCode: UInt16
  private var isFlagChanged: Bool
  private var flags: NSEvent.ModifierFlags
  private var cursorForwardKey: KeyCode = .kNone  // 12 o'clock
  private var cursorBackwardKey: KeyCode = .kNone  // 6 o'clock
  private var cursorKeyClockRight: KeyCode = .kNone  // 3 o'clock
  private var cursorKeyClockLeft: KeyCode = .kNone  // 9 o'clock
  private(set) var emacsKey: EmacsKey
  public var isASCIIModeInput: Bool = false

  public init(
    inputText: String = "", keyCode: UInt16, charCode: UInt16, flags: NSEvent.ModifierFlags,
    isVerticalTyping: Bool = false, inputTextIgnoringModifiers: String? = nil
  ) {
    self.inputText = AppleKeyboardConverter.cnvStringApple2ABC(inputText)
    self.inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(
      inputTextIgnoringModifiers ?? inputText)
    self.flags = flags
    isFlagChanged = false
    isTypingVertical = isVerticalTyping
    self.keyCode = keyCode
    self.charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
    emacsKey = EmacsKeyHelper.detect(
      charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: flags
    )
    // Define Arrow Keys in the same way above.
    defineArrowKeys()
  }

  public init(event: NSEvent, isVerticalTyping: Bool = false) {
    inputText = AppleKeyboardConverter.cnvStringApple2ABC(event.characters ?? "")
    inputTextIgnoringModifiers = AppleKeyboardConverter.cnvStringApple2ABC(
      event.charactersIgnoringModifiers ?? inputText)
    keyCode = event.keyCode
    flags = event.modifierFlags
    isFlagChanged = (event.type == .flagsChanged)
    isTypingVertical = isVerticalTyping
    let charCode: UInt16 = {
      // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
      guard let inputText = event.characters, !inputText.isEmpty else {
        return 0
      }
      let first = inputText[inputText.startIndex].utf16.first!
      return first
    }()
    self.charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
    emacsKey = EmacsKeyHelper.detect(
      charCode: AppleKeyboardConverter.cnvApple2ABC(charCode), flags: flags
    )
    // Define Arrow Keys in the same way above.
    defineArrowKeys()
  }

  mutating func defineArrowKeys() {
    cursorForwardKey = isTypingVertical ? .kDownArrow : .kRightArrow
    cursorBackwardKey = isTypingVertical ? .kUpArrow : .kLeftArrow
    cursorKeyClockLeft = isTypingVertical ? .kRightArrow : .kUpArrow
    cursorKeyClockRight = isTypingVertical ? .kLeftArrow : .kDownArrow
  }

  var description: String {
    var result = "<[InputSignal] "
    result += "inputText:\(String(describing: inputText)), "
    result += "inputTextIgnoringModifiers:\(String(describing: inputTextIgnoringModifiers)), "
    result += "charCode:\(charCode), "
    result += "keyCode:\(keyCode), "
    result += "flags:\(flags), "
    result += "cursorForwardKey:\(cursorForwardKey), "
    result += "cursorBackwardKey:\(cursorBackwardKey), "
    result += "cursorKeyClockRight:\(cursorKeyClockRight), "
    result += "cursorKeyClockLeft:\(cursorKeyClockLeft), "
    result += "emacsKey:\(emacsKey), "
    result += "isTypingVertical:\(isTypingVertical)"
    result += ">"
    return result
  }

  // 除了 ANSI charCode 以外，其餘一律過濾掉，免得純 Swift 版 KeyHandler 被餵屎。
  var isInvalid: Bool { (0x20...0xFF).contains(charCode) ? false : !(isReservedKey && !isKeyCodeBlacklisted) }

  var isKeyCodeBlacklisted: Bool {
    guard let code = KeyCodeBlackListed(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  var isReservedKey: Bool {
    guard let code = KeyCode(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  // 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
  // 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
  let mapMainAreaNumKey: [UInt16: String] = [
    18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
  ]

  /// 單獨用 flags 來判定數字小鍵盤輸入的方法已經失效了，所以必須再增補用 KeyCode 判定的方法。
  var isNumericPadKey: Bool { arrNumpadKeyCodes.contains(keyCode) }
  var isMainAreaNumKey: Bool { arrMainAreaNumKey.contains(keyCode) }
  var isShiftHold: Bool { flags.contains([.shift]) }
  var isCommandHold: Bool { flags.contains([.command]) }
  var isControlHold: Bool { flags.contains([.control]) }
  var isControlHotKey: Bool { flags.contains([.control]) && inputText.first?.isLetter ?? false }
  var isOptionHold: Bool { flags.contains([.option]) }
  var isOptionHotKey: Bool { flags.contains([.option]) && inputText.first?.isLetter ?? false }
  var isCapsLockOn: Bool { flags.contains([.capsLock]) }
  var isFunctionKeyHold: Bool { flags.contains([.function]) }
  var isNonLaptopFunctionKey: Bool { flags.contains([.numericPad]) && !isNumericPadKey }
  var isEnter: Bool { [KeyCode.kCarriageReturn, KeyCode.kLineFeed].contains(KeyCode(rawValue: keyCode)) }
  var isTab: Bool { KeyCode(rawValue: keyCode) == KeyCode.kTab }
  var isUp: Bool { KeyCode(rawValue: keyCode) == KeyCode.kUpArrow }
  var isDown: Bool { KeyCode(rawValue: keyCode) == KeyCode.kDownArrow }
  var isLeft: Bool { KeyCode(rawValue: keyCode) == KeyCode.kLeftArrow }
  var isRight: Bool { KeyCode(rawValue: keyCode) == KeyCode.kRightArrow }
  var isPageUp: Bool { KeyCode(rawValue: keyCode) == KeyCode.kPageUp }
  var isPageDown: Bool { KeyCode(rawValue: keyCode) == KeyCode.kPageDown }
  var isSpace: Bool { KeyCode(rawValue: keyCode) == KeyCode.kSpace }
  var isBackSpace: Bool { KeyCode(rawValue: keyCode) == KeyCode.kBackSpace }
  var isEsc: Bool { KeyCode(rawValue: keyCode) == KeyCode.kEscape }
  var isHome: Bool { KeyCode(rawValue: keyCode) == KeyCode.kHome }
  var isEnd: Bool { KeyCode(rawValue: keyCode) == KeyCode.kEnd }
  var isDelete: Bool { KeyCode(rawValue: keyCode) == KeyCode.kWindowsDelete }
  var isCursorBackward: Bool { KeyCode(rawValue: keyCode) == cursorBackwardKey }
  var isCursorForward: Bool { KeyCode(rawValue: keyCode) == cursorForwardKey }
  var isCursorClockRight: Bool { KeyCode(rawValue: keyCode) == cursorKeyClockRight }
  var isCursorClockLeft: Bool { KeyCode(rawValue: keyCode) == cursorKeyClockLeft }

  // 這裡必須加上「flags == .shift」，否則會出現某些情況下輸入法「誤判當前鍵入的非 Shift 字符為大寫」的問題。
  var isUpperCaseASCIILetterKey: Bool { (65...90).contains(charCode) && flags == .shift }

  // 這裡必須用 KeyCode，這樣才不會受隨 macOS 版本更動的 Apple 動態注音鍵盤排列內容的影響。
  // 只是必須得與 ![input isShiftHold] 搭配使用才可以（也就是僅判定 Shift 沒被摁下的情形）。
  var isSymbolMenuPhysicalKey: Bool {
    [KeyCode.kSymbolMenuPhysicalKeyIntl, KeyCode.kSymbolMenuPhysicalKeyJIS].contains(KeyCode(rawValue: keyCode))
  }
}

enum EmacsKey: UInt16 {
  case none = 0
  case forward = 6  // F
  case backward = 2  // B
  case home = 1  // A
  case end = 5  // E
  case delete = 4  // D
  case nextPage = 22  // V
}

enum EmacsKeyHelper {
  static func detect(charCode: UniChar, flags: NSEvent.ModifierFlags) -> EmacsKey {
    let charCode = AppleKeyboardConverter.cnvApple2ABC(charCode)
    if flags.contains(.control) {
      return EmacsKey(rawValue: charCode) ?? .none
    }
    return .none
  }
}
