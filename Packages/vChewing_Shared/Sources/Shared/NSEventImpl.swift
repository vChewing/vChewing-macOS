// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKUtils

// MARK: - NSEvent Extension - Reconstructors

public extension NSEvent {
  func reinitiate(
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
    let oldChars: String = text
    var characters = characters
    checkSpecialKey: if let matchedKey = KeyCode(rawValue: keyCode ?? self.keyCode) {
      let scalar = matchedKey.correspondedSpecialKeyScalar(flags: (modifierFlags ?? self.modifierFlags).toKB)
      guard let scalar = scalar else { break checkSpecialKey }
      characters = .init(scalar)
    }

    return NSEvent.keyEvent(
      with: type ?? self.type,
      location: location ?? locationInWindow,
      modifierFlags: modifierFlags ?? self.modifierFlags,
      timestamp: timestamp ?? self.timestamp,
      windowNumber: windowNumber ?? self.windowNumber,
      context: nil,
      characters: characters ?? oldChars,
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters ?? oldChars,
      isARepeat: isARepeat ?? self.isARepeat,
      keyCode: keyCode ?? self.keyCode
    )
  }

  /// 自 Emacs 熱鍵的 NSEvent 翻譯回標準 NSEvent。失敗的話則會返回原始 NSEvent 自身。
  /// - Parameter isVerticalTyping: 是否按照縱排來操作。
  /// - Returns: 翻譯結果。失敗的話則返回翻譯原文。
  func convertFromEmacsKeyEvent(isVerticalContext: Bool) -> NSEvent {
    guard isEmacsKey else { return self }
    let newKeyCode: UInt16 = {
      switch isVerticalContext {
      case false: return EmacsKey.charKeyMapHorizontal[charCode] ?? 0
      case true: return EmacsKey.charKeyMapVertical[charCode] ?? 0
      }
    }()
    guard newKeyCode != 0 else { return self }
    return reinitiate(modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil, keyCode: newKeyCode)
      ?? self
  }
}

// MARK: - NSEvent Extension - InputSignalProtocol

public extension NSEvent {
  var isTypingVertical: Bool { charactersIgnoringModifiers == "Vertical" }
  /// NSEvent.characters 的類型安全版。
  /// - Remark: 注意：必須針對 event.type == .flagsChanged 提前返回結果，
  /// 否則，每次處理這種判斷時都會因為讀取 event.characters? 而觸發 NSInternalInconsistencyException。
  var text: String { isFlagChanged ? "" : characters ?? "" }
  var inputTextIgnoringModifiers: String? {
    guard charactersIgnoringModifiers != nil else { return nil }
    return charactersIgnoringModifiers ?? characters ?? ""
  }

  var charCode: UInt16 {
    guard type != .flagsChanged else { return 0 }
    guard characters != nil else { return 0 }
    // 這裡不用「count > 0」，因為該整數變數只要「!isEmpty」那就必定滿足這個條件。
    guard !text.isEmpty else { return 0 }
    let scalars = text.unicodeScalars
    let result = scalars[scalars.startIndex].value
    return result <= UInt16.max ? UInt16(result) : UInt16.max
  }

  internal var keyModifierFlagsNS: ModifierFlags {
    modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
  }

  static var keyModifierFlags: ModifierFlags {
    Self.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
  }

  var isFlagChanged: Bool { type == .flagsChanged }

  var isEmacsKey: Bool {
    // 這裡不能只用 isControlHold，因為這裡對修飾鍵的要求有排他性。
    [6, 2, 1, 5, 4, 22].contains(charCode) && keyModifierFlagsNS == .control
  }

  // 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
  // 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
  // 這句用來返回換算結果。
  var mainAreaNumKeyChar: String? { mapMainAreaNumKey[keyCode] }

  // 除了 ANSI charCode 以外，其餘一律過濾掉，免得 InputHandler 被餵屎。
  var isInvalid: Bool {
    (0x20 ... 0xFF).contains(charCode) ? false : !(isReservedKey && !isKeyCodeBlacklisted)
  }

  var isKeyCodeBlacklisted: Bool {
    guard let code = KeyCodeBlackListed(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  var isReservedKey: Bool {
    guard let code = KeyCode(rawValue: keyCode) else { return false }
    return code.rawValue != KeyCode.kNone.rawValue
  }

  /// 單獨用 flags 來判定數字小鍵盤輸入的方法已經失效了，所以必須再增補用 KeyCode 判定的方法。
  var isJISAlphanumericalKey: Bool { KeyCode(rawValue: keyCode) == KeyCode.kJISAlphanumericalKey }
  var isJISKanaSwappingKey: Bool { KeyCode(rawValue: keyCode) == KeyCode.kJISKanaSwappingKey }
  var isNumericPadKey: Bool { arrNumpadKeyCodes.contains(keyCode) }
  var isMainAreaNumKey: Bool { mapMainAreaNumKey.keys.contains(keyCode) }
  var isShiftHold: Bool { keyModifierFlagsNS.contains(.shift) }
  var isCommandHold: Bool { keyModifierFlagsNS.contains(.command) }
  var isControlHold: Bool { keyModifierFlagsNS.contains(.control) }
  var beganWithLetter: Bool { text.first?.isLetter ?? false }
  var isOptionHold: Bool { keyModifierFlagsNS.contains(.option) }
  var isOptionHotKey: Bool { keyModifierFlagsNS.contains(.option) && text.first?.isLetter ?? false }
  var isCapsLockOn: Bool { modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) }
  var isFunctionKeyHold: Bool { keyModifierFlagsNS.contains(.function) }
  var isNonLaptopFunctionKey: Bool { keyModifierFlagsNS.contains(.numericPad) && !isNumericPadKey }
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

  var isCursorBackward: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kUpArrow
      : KeyCode(rawValue: keyCode) == .kLeftArrow
  }

  var isCursorForward: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kDownArrow
      : KeyCode(rawValue: keyCode) == .kRightArrow
  }

  var isCursorClockRight: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kRightArrow
      : KeyCode(rawValue: keyCode) == .kUpArrow
  }

  var isCursorClockLeft: Bool {
    isTypingVertical
      ? KeyCode(rawValue: keyCode) == .kLeftArrow
      : KeyCode(rawValue: keyCode) == .kDownArrow
  }

  var isASCII: Bool { charCode < 0x80 }

  // 這裡必須加上「flags == .shift」，否則會出現某些情況下輸入法「誤判當前鍵入的非 Shift 字符為大寫」的問題
  var isUpperCaseASCIILetterKey: Bool {
    (65 ... 90).contains(charCode) && keyModifierFlagsNS == .shift
  }

  // 以 .command 觸發的熱鍵（包括剪貼簿熱鍵）。
  var isSingleCommandBasedLetterHotKey: Bool {
    ((65 ... 90).contains(charCode) && keyModifierFlagsNS == [.shift, .command])
      || ((97 ... 122).contains(charCode) && keyModifierFlagsNS == .command)
  }

  // 這裡必須用 KeyCode，這樣才不會受隨 macOS 版本更動的 Apple 動態注音鍵盤排列內容的影響。
  // 只是必須得與 ![input isShiftHold] 搭配使用才可以（也就是僅判定 Shift 沒被摁下的情形）。
  var isSymbolMenuPhysicalKey: Bool {
    [KeyCode.kSymbolMenuPhysicalKeyIntl, KeyCode.kSymbolMenuPhysicalKeyJIS].contains(KeyCode(rawValue: keyCode))
  }
}

// MARK: - Apple ABC Keyboard Mapping

public extension NSEvent {
  func layoutTranslated(to layout: LatinKeyboardMappings = .qwerty) -> NSEvent {
    let mapTable = layout.mapTable
    if isFlagChanged { return self }
    guard keyModifierFlagsNS == .shift || keyModifierFlagsNS.isEmpty else { return self }
    if !mapTable.keys.contains(keyCode) { return self }
    guard let dataTuplet = mapTable[keyCode] else { return self }
    let result: NSEvent? = reinitiate(
      characters: isShiftHold ? dataTuplet.1 : dataTuplet.0,
      charactersIgnoringModifiers: dataTuplet.0
    )
    return result ?? self
  }
}
