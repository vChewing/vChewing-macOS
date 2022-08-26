// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Cocoa

extension Date {
  static func - (lhs: Date, rhs: Date) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}

class ShiftKeyUpChecker {
  init() {}
  private static var checkModifier: NSEvent.ModifierFlags { NSEvent.ModifierFlags.shift }
  private static var checkKeyCode: [UInt16] {
    mgrPrefs.togglingAlphanumericalModeWithLShift
      ? [KeyCode.kShift.rawValue, KeyCode.kRightShift.rawValue]
      : [KeyCode.kRightShift.rawValue]
  }

  private static let delayInterval = 0.3

  private static var lastTime: Date = .init()

  private static func checkModifierKeyUp(event: NSEvent) -> Bool {
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

  private static func checkModifierKeyDown(event: NSEvent) -> Bool {
    let isLeftShift = event.modifierFlags.rawValue & UInt(NX_DEVICELSHIFTKEYMASK) != 0
    let isRightShift = event.modifierFlags.rawValue & UInt(NX_DEVICERSHIFTKEYMASK) != 0
    print("isLeftShift: \(isLeftShift), isRightShift: \(isRightShift)")
    let isKeyDown =
      event.type == .flagsChanged
      && checkModifier.contains(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
      && ShiftKeyUpChecker.checkKeyCode.contains(event.keyCode)
    if isKeyDown {
      // modifier keydown event
      lastTime = Date()
    } else {
      lastTime = Date(timeInterval: -3600 * 4, since: Date())
    }
    return false
  }

  // To confirm that the shift key is "pressed-and-released".
  public static func check(_ event: NSEvent) -> Bool {
    ShiftKeyUpChecker.checkModifierKeyUp(event: event) || ShiftKeyUpChecker.checkModifierKeyDown(event: event)
  }
}
