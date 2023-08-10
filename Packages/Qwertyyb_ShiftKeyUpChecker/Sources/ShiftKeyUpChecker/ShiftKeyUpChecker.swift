// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import AppKit
import Carbon

private extension Date {
  static func - (lhs: Date, rhs: Date) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}

public struct ShiftKeyUpChecker {
  public init(useLShift: Bool = false, useRShift: Bool = false) {
    toggleWithLShift = useLShift
    toggleWithRShift = useRShift
  }

  public var toggleWithLShift = false
  public var toggleWithRShift = false
  public var lShiftKeyCode: UInt16 = 56
  public var rShiftKeyCode: UInt16 = 60

  public var enabled: Bool { toggleWithLShift || toggleWithRShift }

  private var checkModifier: NSEvent.ModifierFlags { NSEvent.ModifierFlags.shift }
  private var checkKeyCode: [UInt16] {
    var result = [UInt16]()
    if toggleWithLShift { result.append(lShiftKeyCode) }
    if toggleWithRShift { result.append(rShiftKeyCode) }
    return result
  }

  private let delayInterval = 0.3

  private var lastTime: Date = .init()

  private var shiftIsBeingPressed = false

  private mutating func checkModifierKeyUp(event: NSEvent) -> Bool {
    guard checkKeyCode.contains(event.keyCode) else { return false }
    if event.type == .flagsChanged,
       event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .init(rawValue: 0),
       Date() - lastTime <= delayInterval, shiftIsBeingPressed
    {
      // modifier keyup event
      lastTime = Date(timeInterval: -3600 * 4, since: Date())
      return true
    }
    return false
  }

  private mutating func checkModifierKeyDown(event: NSEvent) -> Bool {
    let isKeyDown =
      event.type == .flagsChanged
        && checkModifier.contains(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        && checkKeyCode.contains(event.keyCode)
    if isKeyDown {
      // modifier keydown event
      lastTime = Date()
      if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift { shiftIsBeingPressed = true }
    } else {
      lastTime = Date(timeInterval: -3600 * 4, since: Date())
      shiftIsBeingPressed = false
    }
    return false
  }

  // To confirm that the shift key is "pressed-and-released".
  public mutating func check(_ event: NSEvent) -> Bool {
    checkModifierKeyUp(event: event) || checkModifierKeyDown(event: event)
  }
}
