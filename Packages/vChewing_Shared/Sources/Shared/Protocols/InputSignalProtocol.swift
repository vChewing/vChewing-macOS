// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
  var isShiftHold: Bool { get }
  var isCommandHold: Bool { get }
  var isControlHold: Bool { get }
  var beganWithLetter: Bool { get }
  var isOptionHold: Bool { get }
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

  public var isShiftHold: Bool { keyModifierFlags.contains(.shift) }
  public var isCommandHold: Bool { keyModifierFlags.contains(.command) }
  public var isControlHold: Bool { keyModifierFlags.contains(.control) }
  public var isOptionHold: Bool { keyModifierFlags.contains(.option) }
  public var isFunctionKeyHold: Bool { keyModifierFlags.contains(.function) }
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
