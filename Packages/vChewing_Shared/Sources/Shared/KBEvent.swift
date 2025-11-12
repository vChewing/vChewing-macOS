// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - KBEvent

public struct KBEvent: InputSignalProtocol, Hashable {
  // MARK: Lifecycle

  public init(
    with type: Self.EventType? = nil,
    modifierFlags: Self.ModifierFlags? = nil,
    timestamp: TimeInterval? = nil,
    windowNumber: Int? = nil,
    characters: String? = nil,
    charactersIgnoringModifiers: String? = nil,
    isARepeat: Bool? = nil,
    keyCode: UInt16? = nil
  ) {
    var characters = characters
    checkSpecialKey: if let matchedKey = KeyCode(rawValue: keyCode ?? 0),
                        let flags = modifierFlags {
      let scalar = matchedKey.correspondedSpecialKeyScalar(flags: flags)
      guard let scalar = scalar else { break checkSpecialKey }
      characters = .init(scalar)
    }
    self.type = type ?? .keyDown
    self.modifierFlags = modifierFlags ?? []
    self.timestamp = timestamp ?? Date().timeIntervalSince1970
    self.windowNumber = windowNumber ?? 0
    self.characters = characters ?? ""
    self.charactersIgnoringModifiers = charactersIgnoringModifiers ?? characters ?? ""
    self.isARepeat = isARepeat ?? false
    self.keyCode = keyCode ?? KeyCode.kNone.rawValue
  }

  // MARK: Public

  public private(set) var type: EventType
  public private(set) var modifierFlags: ModifierFlags
  public private(set) var timestamp: TimeInterval
  public private(set) var windowNumber: Int
  public private(set) var characters: String?
  public private(set) var charactersIgnoringModifiers: String?
  public private(set) var isARepeat: Bool
  public private(set) var keyCode: UInt16

  public var typeID: UInt { UInt(type.rawValue) }

  public func reinitiate(
    with type: Self.EventType? = nil,
    modifierFlags: Self.ModifierFlags? = nil,
    timestamp: TimeInterval? = nil,
    windowNumber: Int? = nil,
    characters: String? = nil,
    charactersIgnoringModifiers: String? = nil,
    isARepeat: Bool? = nil,
    keyCode: UInt16? = nil
  )
    -> Self {
    let oldChars: String = text
    return Self(
      with: type ?? .keyDown,
      modifierFlags: modifierFlags ?? self.modifierFlags,
      timestamp: timestamp ?? self.timestamp,
      windowNumber: windowNumber ?? self.windowNumber,
      characters: characters ?? oldChars,
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters ?? oldChars,
      isARepeat: isARepeat ?? self.isARepeat,
      keyCode: keyCode ?? self.keyCode
    )
  }
}

// MARK: - KBEvent Extension - SubTypes

extension KBEvent {
  public struct ModifierFlags: OptionSet, Hashable {
    // MARK: Lifecycle

    public init(rawValue: UInt) {
      self.rawValue = rawValue
    }

    // MARK: Public

    public static let capsLock =
      Self(rawValue: 1 << 16) // Set if Caps Lock key is pressed.
    public static let shift = Self(rawValue: 1 << 17) // Set if Shift key is pressed.
    public static let control = Self(rawValue: 1 << 18) // Set if Control key is pressed.
    public static let option =
      Self(rawValue: 1 << 19) // Set if Option or Alternate key is pressed.
    public static let command = Self(rawValue: 1 << 20) // Set if Command key is pressed.
    public static let numericPad =
      Self(rawValue: 1 << 21) // Set if any key in the numeric keypad is pressed.
    public static let help = Self(rawValue: 1 << 22) // Set if the Help key is pressed.
    public static let function =
      Self(rawValue: 1 << 23) // Set if any function key is pressed.
    public static let deviceIndependentFlagsMask = Self(rawValue: 0xFFFF_0000)

    public let rawValue: UInt
  }

  public enum EventType: UInt8 {
    case keyDown = 10
    case keyUp = 11
    case flagsChanged = 12
  }
}

// MARK: - KBEvent Extension - Emacs Key Conversions

extension KBEvent {
  /// 自 Emacs 熱鍵的 KBEvent 翻譯回標準 KBEvent。失敗的話則會返回原始 KBEvent 自身。
  /// - Parameter isVerticalTyping: 是否按照縱排來操作。
  /// - Returns: 翻譯結果。失敗的話則返回翻譯原文。
  public func convertFromEmacsKeyEvent(isVerticalContext: Bool) -> KBEvent {
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
  }
}

// MARK: - KBEvent Extension - InputSignalProtocol

extension KBEvent {
  public var isTypingVertical: Bool { charactersIgnoringModifiers == "Vertical" }
  /// KBEvent.characters 的類型安全版。
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

  public var keyModifierFlags: ModifierFlags {
    modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
  }

  public var isFlagChanged: Bool { type == .flagsChanged }

  public var isEmacsKey: Bool {
    // 這裡不能只用 isControlHold，因為這裡對修飾鍵的要求有排他性。
    [6, 2, 1, 5, 4, 22, 14, 16].contains(charCode) && keyModifierFlags == .control
  }

  // 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
  // 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
  // 這句用來返回換算結果。
  public var mainAreaNumKeyChar: String? { mapMainAreaNumKey[keyCode] }

  // 除了 ANSI charCode 以外，其餘一律過濾掉，免得 InputHandler 被餵屎。
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

  /// 單獨用 flags 來判定數字小鍵盤輸入的方法已經失效了，所以必須再增補用 KeyCode 判定的方法。
  public var isJISAlphanumericalKey: Bool {
    KeyCode(rawValue: keyCode) == KeyCode.kJISAlphanumericalKey
  }

  public var isJISKanaSwappingKey: Bool {
    KeyCode(rawValue: keyCode) == KeyCode.kJISKanaSwappingKey
  }

  public var isNumericPadKey: Bool { arrNumpadKeyCodes.contains(keyCode) }
  public var isMainAreaNumKey: Bool { mapMainAreaNumKey.keys.contains(keyCode) }
  public var isShiftHold: Bool { keyModifierFlags.contains(.shift) }
  public var isCommandHold: Bool { keyModifierFlags.contains(.command) }
  public var isControlHold: Bool { keyModifierFlags.contains(.control) }
  public var beganWithLetter: Bool { text.first?.isLetter ?? false }
  public var isOptionHold: Bool { keyModifierFlags.contains(.option) }
  public var isOptionHotKey: Bool {
    keyModifierFlags.contains(.option) && text.first?.isLetter ?? false
  }

  public var isCapsLockOn: Bool {
    modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock)
  }

  public var isFunctionKeyHold: Bool { keyModifierFlags.contains(.function) }
  public var isNonLaptopFunctionKey: Bool {
    keyModifierFlags.contains(.numericPad) && !isNumericPadKey
  }

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

  public var isASCII: Bool { charCode < 0x80 }

  // 這裡必須加上「flags == .shift」，否則會出現某些情況下輸入法「誤判當前鍵入的非 Shift 字符為大寫」的問題
  public var isUpperCaseASCIILetterKey: Bool {
    (65 ... 90).contains(charCode) && keyModifierFlags == .shift
  }

  // 以 .command 觸發的熱鍵（包括剪貼簿熱鍵）。
  public var isSingleCommandBasedLetterHotKey: Bool {
    ((65 ... 90).contains(charCode) && keyModifierFlags == [.shift, .command])
      || ((97 ... 122).contains(charCode) && keyModifierFlags == .command)
  }

  // 這裡必須用 KeyCode，這樣才不會受隨 macOS 版本更動的 Apple 動態注音鍵盤排列內容的影響。
  // 只是必須得與 ![input isShiftHold] 搭配使用才可以（也就是僅判定 Shift 沒被摁下的情形）。
  public var isSymbolMenuPhysicalKey: Bool {
    [KeyCode.kSymbolMenuPhysicalKeyIntl, KeyCode.kSymbolMenuPhysicalKeyJIS]
      .contains(KeyCode(rawValue: keyCode))
  }
}

// MARK: KBEvent.SpecialKey

extension KBEvent {
  public enum SpecialKey: UInt16 {
    case upArrow = 0xF700
    case downArrow = 0xF701
    case leftArrow = 0xF702
    case rightArrow = 0xF703
    case f1 = 0xF704
    case f2 = 0xF705
    case f3 = 0xF706
    case f4 = 0xF707
    case f5 = 0xF708
    case f6 = 0xF709
    case f7 = 0xF70A
    case f8 = 0xF70B
    case f9 = 0xF70C
    case f10 = 0xF70D
    case f11 = 0xF70E
    case f12 = 0xF70F
    case f13 = 0xF710
    case f14 = 0xF711
    case f15 = 0xF712
    case f16 = 0xF713
    case f17 = 0xF714
    case f18 = 0xF715
    case f19 = 0xF716
    case f20 = 0xF717
    case f21 = 0xF718
    case f22 = 0xF719
    case f23 = 0xF71A
    case f24 = 0xF71B
    case f25 = 0xF71C
    case f26 = 0xF71D
    case f27 = 0xF71E
    case f28 = 0xF71F
    case f29 = 0xF720
    case f30 = 0xF721
    case f31 = 0xF722
    case f32 = 0xF723
    case f33 = 0xF724
    case f34 = 0xF725
    case f35 = 0xF726
    case insert = 0xF727
    case deleteForward = 0xF728
    case home = 0xF729
    case begin = 0xF72A
    case end = 0xF72B
    case pageUp = 0xF72C
    case pageDown = 0xF72D
    case printScreen = 0xF72E
    case scrollLock = 0xF72F
    case pause = 0xF730
    case sysReq = 0xF731
    case `break` = 0xF732
    case reset = 0xF733
    case stop = 0xF734
    case menu = 0xF735
    case user = 0xF736
    case system = 0xF737
    case print = 0xF738
    case clearLine = 0xF739
    case clearDisplay = 0xF73A
    case insertLine = 0xF73B
    case deleteLine = 0xF73C
    case insertCharacter = 0xF73D
    case deleteCharacter = 0xF73E
    case prev = 0xF73F
    case next = 0xF740
    case select = 0xF741
    case execute = 0xF742
    case undo = 0xF743
    case redo = 0xF744
    case find = 0xF745
    case help = 0xF746
    case modeSwitch = 0xF747
    case enter = 0x03
    case backspace = 0x08
    case tab = 0x09
    case newline = 0x0A
    case formFeed = 0x0C
    case carriageReturn = 0x0D
    case backTab = 0x19
    case delete = 0x7F
    case lineSeparator = 0x2028
    case paragraphSeparator = 0x2029

    // MARK: Public

    public var unicodeScalar: Unicode.Scalar { .init(rawValue) ?? .init(0) }
  }
}

// MARK: - KeyCode

// Use KeyCodes as much as possible since its recognition won't be affected by macOS Base Keyboard Layouts.
// KeyCodes: https://eastmanreference.com/complete-list-of-applescript-key-codes
// Also: HIToolbox.framework/Versions/A/Headers/Events.h
public enum KeyCode: UInt16 {
  case kNone = 0
  case kCarriageReturn = 36 // Renamed from "kReturn" to avoid nomenclatural confusions.
  case kTab = 48
  case kSpace = 49
  case kSymbolMenuPhysicalKeyIntl = 50 // vChewing Specific (Non-JIS)
  case kBackSpace = 51 // Renamed from "kDelete" to avoid nomenclatural confusions.
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
  case kLineFeed = 76 // Another keyCode to identify the Enter Key, typable by Fn+Enter.
  case kF18 = 79
  case kF19 = 80
  case kF20 = 90
  case kYen = 93
  case kSymbolMenuPhysicalKeyJIS = 94 // vChewing Specific (JIS)
  case kJISNumPadComma = 95
  case kF5 = 96
  case kF6 = 97
  case kF7 = 98
  case kF3 = 99
  case kF8 = 100
  case kF9 = 101
  case kJISAlphanumericalKey = 102
  case kF11 = 103
  case kJISKanaSwappingKey = 104
  case kF13 = 105 // PrtSc
  case kF16 = 106
  case kF14 = 107
  case kF10 = 109
  case kContextMenu = 110
  case kF12 = 111
  case kF15 = 113
  case kHelp = 114 // Insert
  case kHome = 115
  case kPageUp = 116
  case kWindowsDelete = 117 // Renamed from "kForwardDelete" to avoid nomenclatural confusions.
  case kF4 = 118
  case kEnd = 119
  case kF2 = 120
  case kPageDown = 121
  case kF1 = 122
  case kLeftArrow = 123
  case kRightArrow = 124
  case kDownArrow = 125
  case kUpArrow = 126

  // MARK: Public

  public func toKBEvent() -> KBEvent {
    .init(
      modifierFlags: [],
      timestamp: TimeInterval(),
      windowNumber: 0,
      characters: "",
      charactersIgnoringModifiers: "",
      isARepeat: false,
      keyCode: rawValue
    )
  }

  public func correspondedSpecialKeyScalar(flags: KBEvent.ModifierFlags) -> Unicode.Scalar? {
    var rawData: KBEvent.SpecialKey? {
      switch self {
      case .kNone: return nil
      case .kCarriageReturn: return .carriageReturn
      case .kTab:
        return flags.contains(.shift) ? .backTab : .tab
      case .kSpace: return nil
      case .kSymbolMenuPhysicalKeyIntl: return nil
      case .kBackSpace: return .backspace
      case .kEscape: return nil
      case .kCommand: return nil
      case .kShift: return nil
      case .kCapsLock: return nil
      case .kOption: return nil
      case .kControl: return nil
      case .kRightShift: return nil
      case .kRightOption: return nil
      case .kRightControl: return nil
      case .kFunction: return nil
      case .kF17: return .f17
      case .kVolumeUp: return nil
      case .kVolumeDown: return nil
      case .kMute: return nil
      case .kLineFeed: return nil // TODO: return 待釐清
      case .kF18: return .f18
      case .kF19: return .f19
      case .kF20: return .f20
      case .kYen: return nil
      case .kSymbolMenuPhysicalKeyJIS: return nil
      case .kJISNumPadComma: return nil
      case .kF5: return .f5
      case .kF6: return .f6
      case .kF7: return .f7
      case .kF3: return .f7
      case .kF8: return .f8
      case .kF9: return .f9
      case .kJISAlphanumericalKey: return nil
      case .kF11: return .f11
      case .kJISKanaSwappingKey: return nil
      case .kF13: return .f13
      case .kF16: return .f16
      case .kF14: return .f14
      case .kF10: return .f10
      case .kContextMenu: return .menu
      case .kF12: return .f12
      case .kF15: return .f15
      case .kHelp: return .help
      case .kHome: return .home
      case .kPageUp: return .pageUp
      case .kWindowsDelete: return .deleteForward
      case .kF4: return .f4
      case .kEnd: return .end
      case .kF2: return .f2
      case .kPageDown: return .pageDown
      case .kF1: return .f1
      case .kLeftArrow: return .leftArrow
      case .kRightArrow: return .rightArrow
      case .kDownArrow: return .downArrow
      case .kUpArrow: return .upArrow
      }
    }
    return rawData?.unicodeScalar
  }
}

// MARK: - KeyCodeBlackListed

public enum KeyCodeBlackListed: UInt16 {
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
  case kF13 = 105 // PrtSc
  case kF16 = 106
  case kF14 = 107
  case kF10 = 109
  case kF12 = 111
  case kF15 = 113
  case kHelp = 114 // Insert
  case kF4 = 118
  case kF2 = 120
  case kF1 = 122
}

// 摁 Alt+Shift+主鍵盤區域數字鍵 的話，根據不同的 macOS 鍵盤佈局種類，會出現不同的符號結果。
// 然而呢，KeyCode 卻是一致的。於是這裡直接準備一個換算表來用。
public let mapMainAreaNumKey: [UInt16: String] = [
  18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
]

/// 數字小鍵盤區域的按鍵的 KeyCode。
///
/// 注意：第 95 號 Key Code（逗號）為 JIS 佈局特有的數字小鍵盤按鍵。
public let arrNumpadKeyCodes: [UInt16] = [
  65,
  67,
  69,
  71,
  75,
  78,
  81,
  82,
  83,
  84,
  85,
  86,
  87,
  88,
  89,
  91,
  92,
  95,
]

// MARK: - EmacsKey

public enum EmacsKey {
  public static let charKeyMapHorizontal: [UInt16: UInt16] = [
    6: 124,
    2: 123,
    1: 115,
    5: 119,
    4: 117,
    22: 121,
    14: 125,
    16: 126,
  ]
  public static let charKeyMapVertical: [UInt16: UInt16] = [
    6: 125,
    2: 126,
    1: 115,
    5: 119,
    4: 117,
    22: 121,
    14: 123,
    16: 124,
  ]
}

// MARK: - Apple ABC Keyboard Mapping

extension KBEvent {
  public func layoutTranslated(to layout: LatinKeyboardMappings = .qwerty) -> KBEvent {
    let mapTable = layout.mapTable
    if isFlagChanged { return self }
    guard keyModifierFlags == .shift || keyModifierFlags.isEmpty else { return self }
    if !mapTable.keys.contains(keyCode) { return self }
    guard let dataTuplet = mapTable[keyCode] else { return self }
    let result: KBEvent = reinitiate(
      characters: isShiftHold ? dataTuplet.1 : dataTuplet.0,
      charactersIgnoringModifiers: dataTuplet.0
    )
    return result
  }
}
