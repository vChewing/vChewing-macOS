// (c) 2025 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftExtension

extension KBEvent {
  public init?(fcitxKeyCode: UInt32, fcitxModifierFlags: UInt32, isKeyDown: Bool? = true) {
    guard let matchedKeyCode = Self.mapFcitxToDarwin[fcitxKeyCode] else { return nil }
    let modifierFlagsRAW = FCITX5FlagsOfModifier(rawValue: fcitxModifierFlags)
    var modifierFlagsDarwin = KBEvent.ModifierFlags()
    if modifierFlagsRAW.contains(.shift) { modifierFlagsDarwin.insert(.shift) }
    if modifierFlagsRAW.contains(.capsLock) { modifierFlagsDarwin.insert(.capsLock) }
    if modifierFlagsRAW.contains(.ctrl) { modifierFlagsDarwin.insert(.control) }
    if modifierFlagsRAW.contains(.alt) { modifierFlagsDarwin.insert(.option) }
    if modifierFlagsRAW.contains(.linuxMetaKey) { modifierFlagsDarwin.insert(.option) }
    if modifierFlagsRAW.contains(.numLock) { modifierFlagsDarwin.insert(.numericPad) }
    if modifierFlagsRAW.contains(.hyper) { modifierFlagsDarwin.insert(.function) }
    if modifierFlagsRAW.contains(.gtkVirtualHyper) { modifierFlagsDarwin.insert(.function) }
    if modifierFlagsRAW.contains(.command) { modifierFlagsDarwin.insert(.command) }
    if modifierFlagsRAW.contains(.gtkVirtualSuper) { modifierFlagsDarwin.insert(.command) }

    let qwertyMap = LatinKeyboardMappings.qwerty.mapTable
    let shiftPressed = modifierFlagsDarwin.contains(.shift)

    var characters: String?
    var charactersIgnoringModifiers: String?
    handleCharacters: do {
      if let matched = qwertyMap[matchedKeyCode.0] {
        charactersIgnoringModifiers = matched.0
        characters = (shiftPressed ? matched.1 : matched.0)
        break handleCharacters
      }
      // 上述處理可能難以捕捉到某些與 JIS 鍵盤有關的漏網之魚。
      guard let scalar = matchedKeyCode.1 else {
        // 這裡直接填 nil，將 SpecialKeys 的構建由另一個 init 自動完成。
        break handleCharacters
      }
      let result = String(scalar)
      characters = result
      charactersIgnoringModifiers = result.lowercased()
    }

    let eventType: EventType = switch isKeyDown {
    case .none: .flagsChanged
    case let .some(isKeyDownEvent): isKeyDownEvent ? .keyDown : .keyUp
    }

    self = .init(
      with: eventType,
      modifierFlags: modifierFlagsDarwin,
      characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers,
      isARepeat: modifierFlagsRAW.isRepeat,
      keyCode: matchedKeyCode.0
    )
  }
}

extension KBEvent {
  private static let mapFcitxToDarwin: [UInt32: (UInt16, Unicode.Scalar?)] = [
    0x020: (0x31, " "),
    0x027: (0x27, "'"),
    0x02c: (0x2B, ","),
    0x02d: (0x1B, "-"),
    0x02e: (0x2F, "."),
    0x02f: (0x2C, "/"),
    0x030: (0x1D, "0"),
    0x031: (0x12, "1"),
    0x032: (0x13, "2"),
    0x033: (0x14, "3"),
    0x034: (0x15, "4"),
    0x035: (0x17, "5"),
    0x036: (0x16, "6"),
    0x037: (0x1A, "7"),
    0x038: (0x1C, "8"),
    0x039: (0x19, "9"),
    0x03b: (0x29, ";"),
    0x03d: (0x18, "="),
    0x041: (0x00, "A"),
    0x042: (0x0B, "B"),
    0x043: (0x08, "C"),
    0x044: (0x02, "D"),
    0x045: (0x0E, "E"),
    0x046: (0x03, "F"),
    0x047: (0x05, "G"),
    0x048: (0x04, "H"),
    0x049: (0x22, "I"),
    0x04A: (0x26, "J"),
    0x04B: (0x28, "K"),
    0x04C: (0x25, "L"),
    0x04D: (0x2E, "M"),
    0x04E: (0x2D, "N"),
    0x04F: (0x1F, "O"),
    0x050: (0x23, "P"),
    0x051: (0x0C, "Q"),
    0x052: (0x0F, "R"),
    0x053: (0x01, "S"),
    0x054: (0x11, "T"),
    0x055: (0x20, "U"),
    0x056: (0x09, "V"),
    0x057: (0x0D, "W"),
    0x058: (0x07, "X"),
    0x059: (0x10, "Y"),
    0x05A: (0x06, "Z"),
    0x05b: (0x21, "["),
    0x05c: (0x2A, #"\"#),
    0x05d: (0x1E, "]"),
    0x0a5: (0x5D, "¥"), // Yen (JIS)
    0x05f: (0x5E, "_"), // JIS
    0xffac: (0x5F, ","), // Num Pad Comma (JIS)
    0x060: (0x32, "`"),
    0xff09: (0x30, "\t"),
    0xff0d: (KeyCode.kCarriageReturn.rawValue, KBEvent.SpecialKey.carriageReturn.unicodeScalar),
    0xff08: (KeyCode.kBackSpace.rawValue, KBEvent.SpecialKey.backspace.unicodeScalar),
    0xff1b: (KeyCode.kEscape.rawValue, .init(0)),
    0xffff: (KeyCode.kWindowsDelete.rawValue, KBEvent.SpecialKey.delete.unicodeScalar),
    0xff50: (KeyCode.kHome.rawValue, KBEvent.SpecialKey.home.unicodeScalar),
    0xff57: (KeyCode.kEnd.rawValue, KBEvent.SpecialKey.end.unicodeScalar),
    0xff55: (KeyCode.kPageUp.rawValue, KBEvent.SpecialKey.pageUp.unicodeScalar),
    0xff56: (KeyCode.kPageDown.rawValue, KBEvent.SpecialKey.pageDown.unicodeScalar),
    0xff52: (KeyCode.kUpArrow.rawValue, KBEvent.SpecialKey.upArrow.unicodeScalar),
    0xff54: (KeyCode.kDownArrow.rawValue, KBEvent.SpecialKey.downArrow.unicodeScalar),
    0xff51: (KeyCode.kLeftArrow.rawValue, KBEvent.SpecialKey.leftArrow.unicodeScalar),
    0xff53: (KeyCode.kRightArrow.rawValue, KBEvent.SpecialKey.rightArrow.unicodeScalar),
    0xff20: (0x3f, nil),
    0xff30: (0x5e, nil),
    0xff67: (0x6e, nil),
    0xff6a: (0x72, nil),
    0xff7e: (0x66, nil), // Eisu (JIS)
    0xff7f: (0x68, nil), // Kana (JIS)
    0xff8d: (0x4c, nil),
    0xffb1: (0x7a, nil),
    0xffb2: (0x78, nil),
    0xffb3: (0x63, nil),
    0xffb4: (0x76, nil),
    0xffb5: (0x60, nil),
    0xffb6: (0x61, nil),
    0xffb7: (0x62, nil),
    0xffb8: (0x64, nil),
    0xffb9: (0x65, nil),
    0xffba: (0x6d, nil),
    0xffbb: (0x67, nil),
    0xffbc: (0x6f, nil),
    0xffbd: (0x69, nil),
    0xffbe: (0x6b, nil),
    0xffbf: (0x71, nil),
    0xffc3: (0x6a, nil),
    0xffcc: (0x40, nil),
    0xffcd: (0x4f, nil),
    0xffce: (0x50, nil),
    0xffcf: (0x5a, nil),
    0xffe1: (0x38, nil),
    0xffe2: (0x3c, nil),
    0xffe3: (0x3b, nil),
    0xffe4: (0x3e, nil),
    0xffe5: (0x39, nil),
    0xffe9: (0x3a, nil),
    0xffea: (0x3d, nil),
    0x1008ff11: (0x49, nil),
    0x1008ff12: (0x4a, nil),
    0x1008ff13: (0x48, nil),
  ]

  private struct FCITX5FlagsOfModifier: OptionSet, Codable, Hashable, Sendable {
    static let empty = Self([])
    static let shift = Self(rawValue: 1 << 0)
    static let capsLock = Self(rawValue: 1 << 1)
    static let ctrl = Self(rawValue: 1 << 2)
    static let alt = Self(rawValue: 1 << 3)
    static let numLock = Self(rawValue: 1 << 4)
    static let hyper = Self(rawValue: 1 << 5)
    static let command = Self(rawValue: 1 << 6) // also called Windows & Super Key.
    static let gtkVirtualSuper = Self(rawValue: 1 << 26) // Gtk virtual Super
    static let gtkVirtualHyper = Self(rawValue: 1 << 27) // Gtk virtual Hyper
    static let linuxMetaKey = Self(rawValue: 1 << 28)
    static let repeatKey = Self(rawValue: 1 << 31) // Since 5.0.4

    let rawValue: UInt32

    var isRepeat: Bool { contains(.repeatKey) }
  }
}
