// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - NSEvent Extension - Reconstructors

extension NSEvent {
  public func reinitiate(
    with type: NSEvent.EventType? = nil,
    location: CGPoint? = nil,
    modifierFlags: NSEvent.ModifierFlags? = nil,
    timestamp: TimeInterval? = nil,
    windowNumber: Int? = nil,
    characters: String? = nil,
    charactersIgnoringModifiers: String? = nil,
    isARepeat: Bool? = nil,
    keyCode: UInt16? = nil
  )
    -> NSEvent? {
    let oldChars: String = text
    var characters = characters
    checkSpecialKey: if let matchedKey = KeyCode(rawValue: keyCode ?? self.keyCode) {
      let scalar = matchedKey
        .correspondedSpecialKeyScalar(flags: (modifierFlags ?? self.modifierFlags).toKB)
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
  public func convertFromEmacsKeyEvent(isVerticalContext: Bool) -> NSEvent {
    guard isEmacsKey else { return self }
    let newKeyCode: UInt16 = {
      switch isVerticalContext {
      case false: return EmacsKey.charKeyMapHorizontal[charCode] ?? 0
      case true: return EmacsKey.charKeyMapVertical[charCode] ?? 0
      }
    }()
    guard newKeyCode != 0 else { return self }
    return reinitiate(
      modifierFlags: [],
      characters: nil,
      charactersIgnoringModifiers: nil,
      keyCode: newKeyCode
    )
      ?? self
  }
}

// MARK: - NSEvent Extension - InputSignalProtocol

extension NSEvent {
  public var isTypingVertical: Bool { charactersIgnoringModifiers == "Vertical" }
  /// NSEvent.characters 的類型安全版。
  /// - Remark: 注意：必須針對 event.type == .flagsChanged 提前返回結果，
  /// 否則，每次處理這種判斷時都會因為讀取 event.characters? 而觸發 NSInternalInconsistencyException。
  public var text: String { isFlagChanged ? "" : characters ?? "" }
  public var inputTextIgnoringModifiers: String? {
    guard charactersIgnoringModifiers != nil else { return nil }
    return charactersIgnoringModifiers ?? characters ?? ""
  }

  public var charCode: UInt16 {
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

  public static var keyModifierFlags: ModifierFlags {
    Self.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
  }

  public var isFlagChanged: Bool { type == .flagsChanged }

  public var isEmacsKey: Bool {
    // 這裡不能只用 isControlHold，因為這裡對修飾鍵的要求有排他性。
    [6, 2, 1, 5, 4, 22, 14, 16].contains(charCode) && keyModifierFlagsNS == .control
  }

  // 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
  // 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
  // 這句用來返回換算結果。
  // `mainAreaNumKeyChar` is supplied by InputSignalProtocol default implementation.

  // `isCapsLockOn` stays on concrete types because it needs `modifierFlags`
  // (which includes .capsLock), while the protocol's `keyModifierFlags` strips capsLock.
  public var isCapsLockOn: Bool {
    modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock)
  }
}

// MARK: - Apple ABC Keyboard Mapping

extension NSEvent {
  public func layoutTranslated(to layout: LatinKeyboardMappings = .qwerty) -> NSEvent {
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
