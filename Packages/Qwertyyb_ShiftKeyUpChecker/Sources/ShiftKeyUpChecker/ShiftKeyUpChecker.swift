// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Carbon
import Cocoa

extension Date {
  fileprivate static func - (lhs: Date, rhs: Date) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}

public struct ShiftKeyUpChecker {
  public init(useLShift: Bool) {
    alsoToggleWithLShift = useLShift
  }

  public var alsoToggleWithLShift = false
  public var lShiftKeyCode: UInt16 = 56
  public var rShiftKeyCode: UInt16 = 60

  private var checkModifier: NSEvent.ModifierFlags { NSEvent.ModifierFlags.shift }
  private var checkKeyCode: [UInt16] {
    alsoToggleWithLShift
      ? [lShiftKeyCode, rShiftKeyCode]
      : [rShiftKeyCode]
  }

  private let delayInterval = 0.3

  private var lastTime: Date = .init()

  private mutating func checkModifierKeyUp(event: NSEvent) -> Bool {
    if event.type == .flagsChanged,
      event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .init(rawValue: 0),
      Date() - lastTime <= delayInterval
    {
      // modifier keyup event
      lastTime = Date(timeInterval: -3600 * 4, since: Date())
      return true
    }
    return false
  }

  private mutating func checkModifierKeyDown(event: NSEvent) -> Bool {
    let isLeftShift = event.modifierFlags.rawValue & UInt(NX_DEVICELSHIFTKEYMASK) != 0
    let isRightShift = event.modifierFlags.rawValue & UInt(NX_DEVICERSHIFTKEYMASK) != 0
    print("isLeftShift: \(isLeftShift), isRightShift: \(isRightShift)")
    let isKeyDown =
      event.type == .flagsChanged
      && checkModifier.contains(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
      && checkKeyCode.contains(event.keyCode)
    if isKeyDown {
      // modifier keydown event
      lastTime = Date()
    } else {
      lastTime = Date(timeInterval: -3600 * 4, since: Date())
    }
    return false
  }

  // To confirm that the shift key is "pressed-and-released".
  public mutating func check(_ event: NSEvent) -> Bool {
    checkModifierKeyUp(event: event) || checkModifierKeyDown(event: event)
  }
}
