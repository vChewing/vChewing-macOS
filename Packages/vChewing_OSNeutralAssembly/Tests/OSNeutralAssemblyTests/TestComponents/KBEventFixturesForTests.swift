// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import OSNeutralAssembly
import Shared
import SwiftExtension

// MARK: - 測試用 KBEvent 按鍵實例（補充集）

/// 與 `InputHandlerTests_Basics.swift` 既有的按鍵實例互補。
/// 這裡的命名沿用舊有 MainAssembly 測試的命名，方便跨模組對照。
extension KBEvent.KeyEventData {
  static let dataArrowUp = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.upArrow.unicodeScalar.description,
    keyCode: KeyCode.kUpArrow.rawValue
  )
  static let escEvent = KBEvent.KeyEventData(
    chars: String(UnicodeScalar(0x1B)!),
    charsSansModifiers: String(UnicodeScalar(0x1B)!),
    keyCode: KeyCode.kEscape.rawValue
  )
  static let escapeEvent = KBEvent.KeyEventData(
    type: .keyDown,
    chars: String(UnicodeScalar(0x1B)!),
    charsSansModifiers: String(UnicodeScalar(0x1B)!),
    keyCode: KeyCode.kEscape.rawValue
  )
  static let spaceEvent = KBEvent.KeyEventData(
    chars: " ",
    keyCode: KeyCode.kSpace.rawValue
  )
  static let pageDownEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.pageDown.unicodeScalar.description,
    keyCode: KeyCode.kPageDown.rawValue
  )
  static let pageUpEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.pageUp.unicodeScalar.description,
    keyCode: KeyCode.kPageUp.rawValue
  )
  static let tabEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.tab.unicodeScalar.description,
    keyCode: KeyCode.kTab.rawValue
  )
  static let homeEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.home.unicodeScalar.description,
    keyCode: KeyCode.kHome.rawValue
  )
  static let endEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.end.unicodeScalar.description,
    keyCode: KeyCode.kEnd.rawValue
  )
  static let nextCandidateEvent = KBEvent.KeyEventData(
    type: .keyDown,
    chars: KBEvent.SpecialKey.downArrow.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.downArrow.unicodeScalar.description,
    keyCode: KeyCode.kDownArrow.rawValue
  )
  static let backspaceEvent = KBEvent.KeyEventData(
    type: .keyDown,
    chars: KBEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  static let deleteForwardEvent = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  static let optionBackspaceEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: KBEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  static let shiftBackspaceEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: KBEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  static let optionForwardDeleteEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: KBEvent.SpecialKey.deleteForward.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  static let shiftLeftEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: KBEvent.SpecialKey.leftArrow.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  static let optionLeftEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: KBEvent.SpecialKey.leftArrow.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  static let optionRightEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
    keyCode: KeyCode.kRightArrow.rawValue
  )
  static let optionShiftRightEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .shift],
    chars: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
    keyCode: KeyCode.kRightArrow.rawValue
  )
  static let shiftEnterEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: KBEvent.SpecialKey.enter.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.enter.unicodeScalar.description,
    keyCode: KeyCode.kLineFeed.rawValue
  )
  static let symbolMenuKeyEventIntlWithOpt = KBEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: #"`"#,
    charsSansModifiers: #"`"#,
    keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
  )
  static let optionCommandMinusEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: "-",
    charsSansModifiers: "-",
    keyCode: mapKeyCodesANSIForTests["-"] ?? 27
  )
  static let optionCommandEqualEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: "=",
    charsSansModifiers: "=",
    keyCode: mapKeyCodesANSIForTests["="] ?? 24
  )
  static let optionCommandDeleteEventPC = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: KBEvent.SpecialKey.deleteForward.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  static let optionCommandBackspaceEventPC = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: KBEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  static let optionCommandBackspaceEventMacAsDelete = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command, .function],
    chars: KBEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: KBEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  static let ctrlOptionGEvent = KBEvent.KeyEventData(
    type: .keyDown,
    flags: [.control, .option],
    chars: "g",
    charsSansModifiers: "g",
    keyCode: mapKeyCodesANSIForTests["g"] ?? 5
  )
}
