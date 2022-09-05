// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - NSEvent Extension - Reconstructors

extension NSEvent {
  public func reinitiate(
    with type: NSEvent.EventType? = nil,
    location: NSPoint? = nil,
    modifierFlags: NSEvent.ModifierFlags? = nil,
    timestamp: TimeInterval? = nil,
    windowNumber: Int? = nil,
    characters: String? = nil,
    charactersIgnoringModifiers: String? = nil,
    isARepeat: Bool? = nil,
    keyCode: UInt16? = nil
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: type ?? self.type,
      location: location ?? locationInWindow,
      modifierFlags: modifierFlags ?? self.modifierFlags,
      timestamp: timestamp ?? self.timestamp,
      windowNumber: windowNumber ?? self.windowNumber,
      context: nil,
      characters: characters ?? self.characters ?? "",
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? self.characters ?? "",
      isARepeat: isARepeat ?? self.isARepeat,
      keyCode: keyCode ?? self.keyCode
    )
  }
}

// MARK: - NSEvent Extension - InputSignalProtocol

extension NSEvent: InputSignalProtocol {
  public var isASCIIModeInput: Bool { ctlInputMethod.isASCIIModeSituation }
  public var isTypingVertical: Bool { ctlInputMethod.isVerticalTypingSituation }
  public var text: String { AppleKeyboardConverter.cnvStringApple2ABC(characters ?? "") }
  public var inputTextIgnoringModifiers: String? {
    guard let charIgnoringModifiers = charactersIgnoringModifiers else { return nil }
    return AppleKeyboardConverter.cnvStringApple2ABC(charIgnoringModifiers)
  }

  public var charCode: UInt16 {
    // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
    guard !text.isEmpty else { return 0 }
    let scalars = text.unicodeScalars
    let result = scalars[scalars.startIndex].value
    return result <= UInt16.max ? UInt16(result) : UInt16.max
  }

  public var isFlagChanged: Bool { type == .flagsChanged }

  public var emacsKey: EmacsKey {
    NSEvent.detectEmacsKey(charCode: charCode, flags: modifierFlags)
  }

  // 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
  // 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
  // 這句用來返回換算結果。
  public var mainAreaNumKeyChar: String? { mapMainAreaNumKey[keyCode] }

  // 除了 ANSI charCode 以外，其餘一律過濾掉，免得純 Swift 版 KeyHandler 被餵屎。
  public var isInvalid: Bool {
    (0x20...0xFF).contains(charCode) ? false : !(isReservedKey && !isKeyCodeBlacklisted)
  }

  public var isKeyCodeBlacklisted: Bool {
    guard let code = KeyCodeBlackListed(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  public var isReservedKey: Bool {
    guard let code = KeyCode(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  public var isCandidateKey: Bool {
    mgrPrefs.candidateKeys.contains(text)
      || mgrPrefs.candidateKeys.contains(inputTextIgnoringModifiers ?? "114514")
  }

  /// 單獨用 flags 來判定數字小鍵盤輸入的方法已經失效了，所以必須再增補用 KeyCode 判定的方法。
  public var isNumericPadKey: Bool { arrNumpadKeyCodes.contains(keyCode) }
  public var isMainAreaNumKey: Bool { arrMainAreaNumKey.contains(keyCode) }
  public var isShiftHold: Bool { modifierFlags.contains([.shift]) }
  public var isCommandHold: Bool { modifierFlags.contains([.command]) }
  public var isControlHold: Bool { modifierFlags.contains([.control]) }
  public var isControlHotKey: Bool { modifierFlags.contains([.control]) && text.first?.isLetter ?? false }
  public var isOptionHold: Bool { modifierFlags.contains([.option]) }
  public var isOptionHotKey: Bool { modifierFlags.contains([.option]) && text.first?.isLetter ?? false }
  public var isCapsLockOn: Bool { modifierFlags.contains([.capsLock]) }
  public var isFunctionKeyHold: Bool { modifierFlags.contains([.function]) }
  public var isNonLaptopFunctionKey: Bool { modifierFlags.contains([.numericPad]) && !isNumericPadKey }
  public var isEnter: Bool { [KeyCode.kCarriageReturn, KeyCode.kLineFeed].contains(KeyCode(rawValue: keyCode)) }
  public var isTab: Bool { KeyCode(rawValue: keyCode) == KeyCode.kTab }
  public var isUp: Bool { KeyCode(rawValue: keyCode) == KeyCode.kUpArrow }
  public var isDown: Bool { KeyCode(rawValue: keyCode) == KeyCode.kDownArrow }
  public var isLeft: Bool { KeyCode(rawValue: keyCode) == KeyCode.kLeftArrow }
  public var isRight: Bool { KeyCode(rawValue: keyCode) == KeyCode.kRightArrow }
  public var isPageUp: Bool { KeyCode(rawValue: keyCode) == KeyCode.kPageUp }
  public var isPageDown: Bool { KeyCode(rawValue: keyCode) == KeyCode.kPageDown }
  public var isSpace: Bool { KeyCode(rawValue: keyCode) == KeyCode.kSpace }
  public var isBackSpace: Bool { KeyCode(rawValue: keyCode) == KeyCode.kBackSpace }
  public var isEsc: Bool { KeyCode(rawValue: keyCode) == KeyCode.kEscape }
  public var isHome: Bool { KeyCode(rawValue: keyCode) == KeyCode.kHome }
  public var isEnd: Bool { KeyCode(rawValue: keyCode) == KeyCode.kEnd }
  public var isDelete: Bool { KeyCode(rawValue: keyCode) == KeyCode.kWindowsDelete }

  public var isCursorBackward: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kUpArrow
      : KeyCode(rawValue: keyCode) == .kLeftArrow
  }

  public var isCursorForward: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kDownArrow
      : KeyCode(rawValue: keyCode) == .kRightArrow
  }

  public var isCursorClockRight: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kRightArrow
      : KeyCode(rawValue: keyCode) == .kUpArrow
  }

  public var isCursorClockLeft: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kLeftArrow
      : KeyCode(rawValue: keyCode) == .kDownArrow
  }

  public var isASCII: Bool { charCode < 0x80 }

  // 這裡必須加上「flags == .shift」，否則會出現某些情況下輸入法「誤判當前鍵入的非 Shift 字符為大寫」的問題
  public var isUpperCaseASCIILetterKey: Bool {
    (65...90).contains(charCode) && modifierFlags == .shift
  }

  // 這裡必須用 KeyCode，這樣才不會受隨 macOS 版本更動的 Apple 動態注音鍵盤排列內容的影響。
  // 只是必須得與 ![input isShiftHold] 搭配使用才可以（也就是僅判定 Shift 沒被摁下的情形）。
  public var isSymbolMenuPhysicalKey: Bool {
    [KeyCode.kSymbolMenuPhysicalKeyIntl, KeyCode.kSymbolMenuPhysicalKeyJIS].contains(KeyCode(rawValue: keyCode))
  }

  static func detectEmacsKey(charCode: UniChar, flags: NSEvent.ModifierFlags) -> EmacsKey {
    if flags.contains(.control) {
      return EmacsKey(rawValue: charCode) ?? .none
    }
    return .none
  }
}

// MARK: - InputSignalProtocol

public protocol InputSignalProtocol {
  var isASCIIModeInput: Bool { get }
  var isTypingVertical: Bool { get }
  var text: String { get }
  var inputTextIgnoringModifiers: String? { get }
  var charCode: UInt16 { get }
  var keyCode: UInt16 { get }
  var isFlagChanged: Bool { get }
  var emacsKey: EmacsKey { get }
  var mainAreaNumKeyChar: String? { get }
  var isASCII: Bool { get }
  var isInvalid: Bool { get }
  var isKeyCodeBlacklisted: Bool { get }
  var isReservedKey: Bool { get }
  var isCandidateKey: Bool { get }
  var isNumericPadKey: Bool { get }
  var isMainAreaNumKey: Bool { get }
  var isShiftHold: Bool { get }
  var isCommandHold: Bool { get }
  var isControlHold: Bool { get }
  var isControlHotKey: Bool { get }
  var isOptionHold: Bool { get }
  var isOptionHotKey: Bool { get }
  var isCapsLockOn: Bool { get }
  var isFunctionKeyHold: Bool { get }
  var isNonLaptopFunctionKey: Bool { get }
  var isEnter: Bool { get }
  var isTab: Bool { get }
  var isUp: Bool { get }
  var isDown: Bool { get }
  var isLeft: Bool { get }
  var isRight: Bool { get }
  var isPageUp: Bool { get }
  var isPageDown: Bool { get }
  var isSpace: Bool { get }
  var isBackSpace: Bool { get }
  var isEsc: Bool { get }
  var isHome: Bool { get }
  var isEnd: Bool { get }
  var isDelete: Bool { get }
  var isCursorBackward: Bool { get }
  var isCursorForward: Bool { get }
  var isCursorClockRight: Bool { get }
  var isCursorClockLeft: Bool { get }
  var isUpperCaseASCIILetterKey: Bool { get }
  var isSymbolMenuPhysicalKey: Bool { get }
}

// MARK: - Enums of Constants

// Use KeyCodes as much as possible since its recognition won't be affected by macOS Base Keyboard Layouts.
// KeyCodes: https://eastmanreference.com/complete-list-of-applescript-key-codes
// Also: HIToolbox.framework/Versions/A/Headers/Events.h
public enum KeyCode: UInt16 {
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

// 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
// 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
let mapMainAreaNumKey: [UInt16: String] = [
  18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
]

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

public enum EmacsKey: UInt16 {
  case none = 0
  case forward = 6  // F
  case backward = 2  // B
  case home = 1  // A
  case end = 5  // E
  case delete = 4  // D
  case nextPage = 22  // V
}
