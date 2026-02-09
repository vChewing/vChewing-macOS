// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SessionUI

public final class SessionUI: SessionUIProtocol {
  public static let shared = SessionUI()

  public var currentSessionID: UUID = .init()

  /// Shift 按鍵事件分析器的副本。
  public let shiftKeyUpChecker: (any ShiftKeyUpCheckerProtocol)? = ShiftKeyUpChecker(
    useLShift: PrefMgr.shared.togglingAlphanumericalModeWithLShift,
    useRShift: PrefMgr.shared.togglingAlphanumericalModeWithRShift
  )

  /// CapsLock 按键事件分析器的副本。
  public let capsLockHitChecker: (any HitCheckerProtocol)? = CpLkHitChecker()

  /// 用來控制 CapsLock 狀態的模組的副本。
  public let capsLockToggler: (any CapsLockTogglerProtocol)? = CapsLockToggler.shared

  /// 浮動組字窗的副本。
  public let pcb: (any PCBProtocol)? = PopupCompositionBuffer()

  /// 工具提示視窗的副本。
  public let tooltipUI: (any TooltipUIProtocol)? = TooltipUI()

  /// 目前在用的的選字窗副本。Layout 預設值不再重要，因為使用時會就地重新賦值。
  public let candidateUI: (any CtlCandidateProtocol)? = CtlCandidateTDK()
}

extension SessionUI {
  public func resyncShiftKeyUpCheckerSettings() {
    shiftKeyUpChecker?.toggleWithLShift = PrefMgr.shared
      .togglingAlphanumericalModeWithLShift
    shiftKeyUpChecker?.toggleWithRShift = PrefMgr.shared
      .togglingAlphanumericalModeWithRShift
  }
}
