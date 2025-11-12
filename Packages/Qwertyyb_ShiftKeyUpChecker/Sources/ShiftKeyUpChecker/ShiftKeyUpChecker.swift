// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import AppKit
import Shared

extension Date {
  fileprivate static func - (lhs: Date, rhs: Date) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}

// MARK: - ShiftKeyUpChecker

public class ShiftKeyUpChecker: ShiftKeyUpCheckerProtocol {
  // MARK: Lifecycle

  // MARK: - 威注音輸入法專有部分

  public init(useLShift: Bool = false, useRShift: Bool = false) {
    self.toggleWithLShift = useLShift
    self.toggleWithRShift = useRShift
  }

  // MARK: Public

  public var toggleWithLShift = false
  public var toggleWithRShift = false
  public let lShiftKeyCodeFlag: UInt16 = 56
  public let rShiftKeyCodeFlag: UInt16 = 60
  public let cplkKeyCode: UInt16 = 57

  public var enabled: Bool { toggleWithLShift || toggleWithRShift }

  // To confirm that only the shift key is "pressed-and-released".
  public func check(_ event: some InputSignalProtocol) -> Bool {
    var met: Bool = event.typeID == NSEvent.EventType.flagsChanged.rawValue
    met = met && event.keyCode != cplkKeyCode
    met = met && checkKeyCodeFlags.contains(event.keyCode)
    met = met && event.keyCode == previousKeyCode // 檢查 KeyCode 一致性。
    met = met && event.keyModifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
    met = met && Date() - lastTime <= delayInterval
    _ = met ? lastTime = Date(timeInterval: .infinity * -1, since: Date()) :
      registerModifierKeyDown(event: event)
    return met
  }

  // MARK: Private

  // MARK: - 與業火五筆共用的內容

  /// 實現邏輯基本上是相同的，只是威注音這邊的行文風格習慣可能與業火五筆有不同。

  private let delayInterval = 0.2
  private var previousKeyCode: UInt16?
  private var lastTime: Date = .init()

  private var checkModifier: KBEvent.ModifierFlags { .shift }
  private var checkKeyCodeFlags: [UInt16] {
    var result = [UInt16]()
    if toggleWithLShift { result.append(lShiftKeyCodeFlag) }
    if toggleWithRShift { result.append(rShiftKeyCodeFlag) }
    return result
  }

  private func registerModifierKeyDown(event: some InputSignalProtocol) {
    var isKeyDown: Bool = event.typeID == NSEvent.EventType.flagsChanged.rawValue
    // 注意：ModifierFlags 是 OptionSet，在使用 contains 時會在給定參數是「空集合」的時候返回 true（明明你可能想要 false）。
    let intersected = event.keyModifierFlags.intersection(.deviceIndependentFlagsMask)
    isKeyDown = isKeyDown && intersected == checkModifier
    isKeyDown = isKeyDown && checkKeyCodeFlags.contains(event.keyCode)
    lastTime = isKeyDown ? .init() : .init(timeInterval: .infinity * -1, since: Date())
    previousKeyCode = isKeyDown ? event.keyCode : nil
  }
}
