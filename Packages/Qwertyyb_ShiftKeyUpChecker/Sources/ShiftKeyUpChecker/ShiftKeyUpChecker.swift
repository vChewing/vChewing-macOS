// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import AppKit

private extension Date {
  static func - (lhs: Date, rhs: Date) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}

public struct ShiftKeyUpChecker {
  // MARK: - 威注音輸入法專有部分

  public init(useLShift: Bool = false, useRShift: Bool = false) {
    toggleWithLShift = useLShift
    toggleWithRShift = useRShift
  }

  public var toggleWithLShift = false
  public var toggleWithRShift = false
  public var lShiftKeyCode: UInt16 = 56
  public var rShiftKeyCode: UInt16 = 60

  public var enabled: Bool { toggleWithLShift || toggleWithRShift }

  private var checkModifier: NSEvent.ModifierFlags { .shift }
  private var checkKeyCode: [UInt16] {
    var result = [UInt16]()
    if toggleWithLShift { result.append(lShiftKeyCode) }
    if toggleWithRShift { result.append(rShiftKeyCode) }
    return result
  }

  // MARK: - 與業火五筆共用的內容

  /// 實現邏輯基本上是相同的，只是威注音這邊的行文風格習慣可能與業火五筆有不同。

  private let delayInterval = 0.3
  private var previousKeyCode: UInt16?
  private var lastTime: Date = .init()

  private mutating func registerModifierKeyDown(event: NSEvent) {
    var isKeyDown: Bool = event.type == .flagsChanged
    // 注意：ModifierFlags 是 OptionSet，在使用 contains 時會在給定參數是「空集合」的時候返回 true（明明你可能想要 false）。
    isKeyDown = isKeyDown && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == checkModifier
    isKeyDown = isKeyDown && checkKeyCode.contains(event.keyCode)
    lastTime = isKeyDown ? .init() : .init(timeInterval: .infinity * -1, since: Date())
    previousKeyCode = isKeyDown ? event.keyCode : nil
  }

  // To confirm that only the shift key is "pressed-and-released".
  public mutating func check(_ event: NSEvent) -> Bool {
    var met: Bool = event.type == .flagsChanged
    met = met && checkKeyCode.contains(event.keyCode)
    met = met && event.keyCode == previousKeyCode // 檢查 KeyCode 一致性。
    met = met && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
    met = met && Date() - lastTime <= delayInterval
    _ = met ? lastTime = Date(timeInterval: .infinity * -1, since: Date()) : registerModifierKeyDown(event: event)
    return met
  }
}
