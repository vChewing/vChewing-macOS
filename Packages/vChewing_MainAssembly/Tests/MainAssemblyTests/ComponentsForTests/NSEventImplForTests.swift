// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension NSEvent {
  public struct KeyEventData {
    // MARK: Lifecycle

    public init(
      type: EventType = .keyDown,
      flags: ModifierFlags = [],
      chars: String,
      charsSansModifiers: String? = nil,
      keyCode: UInt16? = nil
    ) {
      self.type = type
      self.flags = flags
      self.chars = chars
      self.charsSansModifiers = charsSansModifiers ?? chars
      self.keyCode = keyCode ?? mapKeyCodesANSIForTests[chars] ?? 65_535
    }

    // MARK: Public

    public var type: EventType = .keyDown
    public var flags: ModifierFlags
    public var chars: String
    public var charsSansModifiers: String
    public var keyCode: UInt16

    public var asPairedEvents: [NSEvent] {
      NSEvent.keyEvents(data: self, paired: true)
    }

    public var asEvent: NSEvent? {
      NSEvent.keyEvent(data: self)
    }

    public func toEvents(paired: Bool = false) -> [NSEvent] {
      NSEvent.keyEvents(data: self, paired: paired)
    }
  }

  public static func keyEvents(data: KeyEventData, paired: Bool = false) -> [NSEvent] {
    var resultArray = [NSEvent]()
    if let eventA: NSEvent = Self.keyEvent(data: data) {
      resultArray.append(eventA)
      if paired, eventA.type == .keyDown,
         let eventB = eventA.reinitiate(
           with: .keyUp,
           characters: nil,
           charactersIgnoringModifiers: nil
         ) {
        resultArray.append(eventB)
      }
    }
    return resultArray
  }

  public static func keyEvent(data: KeyEventData) -> NSEvent? {
    Self.keyEventSimple(
      type: data.type,
      flags: data.flags,
      chars: data.chars,
      charsSansModifiers: data.charsSansModifiers,
      keyCode: data.keyCode
    )
  }

  public static func keyEventSimple(
    type: EventType,
    flags: ModifierFlags,
    chars: String,
    charsSansModifiers: String? = nil,
    keyCode: UInt16
  )
    -> NSEvent? {
    Self.keyEvent(
      with: type,
      location: .zero,
      modifierFlags: flags,
      timestamp: .init(),
      windowNumber: 0,
      context: nil,
      characters: chars,
      charactersIgnoringModifiers: charsSansModifiers ?? chars,
      isARepeat: false,
      keyCode: keyCode
    )
  }
}
