// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - InputSignalProtocol

public protocol InputSignalProtocol {
  var typeID: UInt { get }
  var keyModifierFlags: KBEvent.ModifierFlags { get }
  var isTypingVertical: Bool { get }
  var text: String { get }
  var inputTextIgnoringModifiers: String? { get }
  var charCode: UInt16 { get }
  var keyCode: UInt16 { get }
  var isFlagChanged: Bool { get }
  var mainAreaNumKeyChar: String? { get }
  var isASCII: Bool { get }
  var isInvalid: Bool { get }
  var isKeyCodeBlacklisted: Bool { get }
  var isReservedKey: Bool { get }
  var isJISAlphanumericalKey: Bool { get }
  var isJISKanaSwappingKey: Bool { get }
  var isNumericPadKey: Bool { get }
  var isMainAreaNumKey: Bool { get }
  var isShiftHeld: Bool { get }
  var isCommandHeld: Bool { get }
  var isControlHeld: Bool { get }
  var beganWithLetter: Bool { get }
  var isOptionHeld: Bool { get }
  var isCapsLockOn: Bool { get }
  var isFunctionKeyHeld: Bool { get }
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
  var isSingleCommandBasedLetterHotKey: Bool { get }
  var isSymbolMenuPhysicalKey: Bool { get }
}

// MARK: - Default Implementations

extension InputSignalProtocol {
  // MARK: Composite helpers

  public var commonKeyModifierFlags: KBEvent.ModifierFlags {
    keyModifierFlags.subtracting([.function, .numericPad, .help])
  }

  public func isHotKeyOfAnyFlag(_ flags: KBEvent.ModifierFlags) -> Bool {
    guard let first = text.first, let asciiVal = first.asciiValue else { return false }
    return !keyModifierFlags.isDisjoint(with: flags) && asciiVal >= 0x21 && asciiVal <= 0x7E
  }

  /// Check whether any given flag is being held.
  /// - Parameter flags: Given flags. If empty, this API will return false.
  /// - Returns: Bool result.
  public func isHoldingAny(_ flags: KBEvent.ModifierFlags) -> Bool {
    guard !flags.isEmpty else { return false }
    return !keyModifierFlags.isDisjoint(with: flags)
  }

  /// Check whether all given flags are being held.
  /// - Parameter flags: Given flags. If empty, this API will return false.
  /// - Returns: Bool result.
  public func isHoldingAll(_ flags: KBEvent.ModifierFlags) -> Bool {
    guard !flags.isEmpty else { return false }
    return keyModifierFlags.contains(flags)
  }

  // MARK: Modifier key queries

  public var isShiftHeld: Bool { keyModifierFlags.contains(.shift) }
  public var isCommandHeld: Bool { keyModifierFlags.contains(.command) }
  public var isControlHeld: Bool { keyModifierFlags.contains(.control) }
  public var isOptionHeld: Bool { keyModifierFlags.contains(.option) }
  public var isFunctionKeyHeld: Bool { keyModifierFlags.contains(.function) }
  public var beganWithLetter: Bool { text.first?.isLetter ?? false }

  public var isNonLaptopFunctionKey: Bool {
    keyModifierFlags.contains(.numericPad) && !isNumericPadKey
  }

  // MARK: KeyCode queries

  public var isJISAlphanumericalKey: Bool {
    KeyCode(rawValue: keyCode) == KeyCode.kJISAlphanumericalKey
  }

  public var isJISKanaSwappingKey: Bool {
    KeyCode(rawValue: keyCode) == KeyCode.kJISKanaSwappingKey
  }

  public var isNumericPadKey: Bool { arrNumpadKeyCodes.contains(keyCode) }

  /// 該按鍵是否為功能鍵（F1－F20）。
  public var isFunctionKey: Bool { KeyCode(rawValue: keyCode)?.isFunctionKey ?? false }

  public var isMainAreaNumKey: Bool { mapMainAreaNumKey.keys.contains(keyCode) }

  public var mainAreaNumKeyChar: String? { mapMainAreaNumKey[keyCode] }

  public var isEnter: Bool {
    [KeyCode.kCarriageReturn, KeyCode.kLineFeed].contains(KeyCode(rawValue: keyCode))
  }

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

  public var isSymbolMenuPhysicalKey: Bool {
    [KeyCode.kSymbolMenuPhysicalKeyIntl, KeyCode.kSymbolMenuPhysicalKeyJIS]
      .contains(KeyCode(rawValue: keyCode))
  }

  // MARK: Character queries

  public var isASCII: Bool { charCode < 0x80 }

  public var isUpperCaseASCIILetterKey: Bool {
    (65 ... 90).contains(charCode) && keyModifierFlags == .shift
  }

  public var isSingleCommandBasedLetterHotKey: Bool {
    ((65 ... 90).contains(charCode) && keyModifierFlags == [.shift, .command])
      || ((97 ... 122).contains(charCode) && keyModifierFlags == .command)
  }

  /// 該輸入訊號是否為「Command 系熱鍵組合」，即輸入法不得當作文字資料吃掉的按鍵組合。
  ///
  /// macOS 上任何帶 Command 的按鍵組合均屬選單／熱鍵語意：客體不會將其中的字元視為輸入
  /// 文字，也不可能藉此改寫輸入法持有的組字區。故輸入法自身未認領的 Command 系組合鍵一律
  /// 須交還客體——否則 Google Chrome 的 `Cmd+Ctrl+C`／`Cmd+Ctrl+W` 之類的客體熱鍵在組字
  /// 期間無從送達。此與 mozc 之 `-[MozcImkInputController handleEvent:client:]` 僅在引擎確有
  /// 消費時才回 `YES` 的行為一致。Ctrl／Option 系組合鍵不在此列：無 Command 時它們仍可能是
  /// 文字資料（控制字元），吃掉才不會污染客體文件。
  public var isCommandShortcutChord: Bool { isHoldingAny([.command]) }

  // MARK: Validation

  public var isInvalid: Bool {
    (0x20 ... 0xFF).contains(charCode) ? false : !(isReservedKey && !isKeyCodeBlacklisted)
  }

  public var isKeyCodeBlacklisted: Bool {
    guard let code = KeyCodeBlackListed(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  public var isReservedKey: Bool {
    guard let code = KeyCode(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }
}
