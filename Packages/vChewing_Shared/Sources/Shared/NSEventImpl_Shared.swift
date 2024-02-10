// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - NSEvent - Conforming to InputSignalProtocol

extension NSEvent: InputSignalProtocol {
  public var keyModifierFlags: KBEvent.ModifierFlags {
    .init(rawValue: keyModifierFlagsNS.rawValue)
  }
}

// MARK: - NSEvent - Translating to KBEvent

public extension NSEvent? {
  var copyAsKBEvent: KBEvent? {
    self?.copyAsKBEvent ?? nil
  }
}

public extension NSEvent {
  var copyAsKBEvent: KBEvent? {
    guard let typeKB = type.toKB else { return nil }
    // NSEvent 只是個外表皮，裡面有好幾個影子 class。
    // 不是所有的影子 class 都有「characters」和「isARepeated」。
    // 貿然存取的話，會觸發 NSInternalInconsistencyException。
    // 已知 FlagsChanged 類型的事件是如此，那就對這個類型做例外處理。
    return .init(
      with: typeKB,
      modifierFlags: modifierFlags.toKB,
      timestamp: timestamp,
      windowNumber: windowNumber,
      characters: typeKB != .flagsChanged ? characters : nil,
      charactersIgnoringModifiers: typeKB != .flagsChanged ? charactersIgnoringModifiers : nil,
      isARepeat: typeKB != .flagsChanged ? isARepeat : nil,
      keyCode: keyCode
    )
  }
}

public extension NSEvent.EventType {
  var toKB: KBEvent.EventType? {
    switch self {
    case .flagsChanged: return .flagsChanged
    case .keyDown: return .keyDown
    case .keyUp: return .keyUp
    default: return nil
    }
  }
}

public extension NSEvent.ModifierFlags {
  var toKB: KBEvent.ModifierFlags {
    .init(rawValue: rawValue)
  }
}

// MARK: - KBEvent - Translating to NSEvent

public extension KBEvent? {
  var copyAsNSEvent: NSEvent? {
    self?.copyAsNSEvent ?? nil
  }
}

public extension KBEvent {
  var copyAsNSEvent: NSEvent? {
    NSEvent.keyEvent(
      with: type.toNS,
      location: .zero,
      modifierFlags: modifierFlags.toNS,
      timestamp: timestamp,
      windowNumber: windowNumber,
      context: nil,
      characters: characters ?? "",
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? "",
      isARepeat: isARepeat,
      keyCode: keyCode
    )
  }
}

public extension KBEvent.EventType {
  var toNS: NSEvent.EventType {
    switch self {
    case .flagsChanged: return .flagsChanged
    case .keyDown: return .keyDown
    case .keyUp: return .keyUp
    }
  }
}

public extension KBEvent.ModifierFlags {
  var toNS: NSEvent.ModifierFlags {
    .init(rawValue: rawValue)
  }
}
