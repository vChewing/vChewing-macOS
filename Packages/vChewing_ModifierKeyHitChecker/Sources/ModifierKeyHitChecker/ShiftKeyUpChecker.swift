// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

// MARK: - ShiftKeyUpChecker

public final class ShiftKeyUpChecker: ShiftKeyUpCheckerProtocol {
  // MARK: Lifecycle

  public init(useLShift: Bool = false, useRShift: Bool = false) {
    self.toggleWithLShift = useLShift
    self.toggleWithRShift = useRShift
  }

  // MARK: Public

  public var toggleWithLShift: Bool
  public var toggleWithRShift: Bool

  /// 判定是否為「單獨敲擊 Shift 鍵」
  ///
  /// 設計原則：
  /// - 不依賴 flagsChanged / keyUp 的具體事件型別
  /// - 不信任 Electron / Chromium 的事件完整性
  /// - 只依賴「Shift 修飾鍵狀態是否發生躍遷」
  /// - 任何其它實體按鍵介入都會立刻取消
  /// - 透過冷卻鎖避免同一次物理釋放被判定為兩次敲擊
  public func check(_ event: some InputSignalProtocol) -> Bool {
    guard enabled else {
      reset()
      return false
    }

    let now = Date().timeIntervalSinceReferenceDate
    let keyCode = event.keyCode

    let isTargetShiftKey: Bool =
      (toggleWithLShift && keyCode == KeyCode.kShift.rawValue)
        || (toggleWithRShift && keyCode == KeyCode.kRightShift.rawValue)

    // 當前事件視角下：Shift 是否處於「邏輯按下」狀態
    let shiftNowDown = event.commonKeyModifierFlags.contains(.shift)

    // 1. 任何「非 Shift」的真實 KeyDown，都會立刻取消 Solo Shift

    if event.typeID == KBEvent.EventType.keyDown.rawValue, !isTargetShiftKey {
      reset()
      return false
    }

    // 2. Shift 狀態躍遷：未按 → 按下（Priming）

    if !shiftIsDown, shiftNowDown, isTargetShiftKey {
      // 冷卻鎖：防止同一次物理釋放後的回彈被再次視為新一輪敲擊
      if let lastTrigger = lastTriggerTime,
         now - lastTrigger < retriggerGuardInterval {
        return false
      }

      shiftIsDown = true
      lastShiftDownTime = now
      lastShiftKeyCode = keyCode
      return false
    }

    // 3. Shift 狀態躍遷：按下 → 釋放（Decision）

    if shiftIsDown, !shiftNowDown, isTargetShiftKey {
      defer { reset() }

      guard let startTime = lastShiftDownTime else { return false }
      guard lastShiftKeyCode == keyCode else { return false }

      // 超時則視為「按住不放」
      if now - startTime > timeThreshold {
        return false
      }

      // 冷卻鎖：避免同一次物理 Shift 被 Electron 拆成兩次完整週期
      if let lastTrigger = lastTriggerTime,
         now - lastTrigger < retriggerGuardInterval {
        return false
      }

      // 記錄本次成功觸發時間
      lastTriggerTime = now

      // 這才是一個合法、穩定、跨平台的一次「單獨敲擊 Shift」
      return true
    }

    // 4. 其餘情況一律忽略（包含 Electron 的冗餘 flagsChanged）
    return false
  }

  // MARK: Private

  /// 當前是否處於「Shift 已按下」的邏輯狀態
  private var shiftIsDown: Bool = false

  /// Shift 最近一次按下的時間點
  private var lastShiftDownTime: TimeInterval?

  /// 最近一次按下的 Shift KeyCode（用以區分左右）
  private var lastShiftKeyCode: UInt16?

  /// 最近一次成功觸發 Solo Shift 的時間
  /// 用於防止 Electron 的狀態回彈造成雙重觸發
  private var lastTriggerTime: TimeInterval?

  /// 允許的最大敲擊時間（超過視為長按）
  private let timeThreshold: TimeInterval = 0.2

  /// 觸發後的最小冷卻時間
  /// 人類不可能在此時間內完成兩次獨立 Shift 敲擊
  private let retriggerGuardInterval: TimeInterval = 0.05

  private func reset() {
    shiftIsDown = false
    lastShiftDownTime = nil
    lastShiftKeyCode = nil
    // 注意：lastTriggerTime 不在此重置，作為跨週期的冷卻鎖使用
  }
}
