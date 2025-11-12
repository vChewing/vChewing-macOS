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
  var isSingleCommandBasedLetterHotKey: Bool { get }
  var isSymbolMenuPhysicalKey: Bool { get }
}

extension InputSignalProtocol {
  public var commonKeyModifierFlags: KBEvent.ModifierFlags {
    keyModifierFlags.subtracting([.function, .numericPad, .help])
  }
}
