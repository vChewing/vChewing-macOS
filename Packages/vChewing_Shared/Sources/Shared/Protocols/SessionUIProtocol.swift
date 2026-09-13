// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - SessionUIProtocol

public protocol SessionUIProtocol: AnyObject {
  /// 僅用來決定 UI 面板先照顧哪個 Session 用，不宜用來判斷 isActivated。
  var currentSessionID: UUID { get set }
  var shiftKeyUpChecker: (any ShiftKeyUpCheckerProtocol)? { get }
  var capsLockHitChecker: (any HitCheckerProtocol)? { get }
  var capsLockToggler: (any CapsLockTogglerProtocol)? { get }
  var pcb: (any PCBProtocol)? { get }
  var tooltipUI: (any TooltipUIProtocol)? { get }
  /// 打字模式提示專用的輔助工具提示副本（`StatusUI` 實例；隨 close-all 隱藏、由 setValue 於提示期重發）。
  var statusUI: (any TooltipUIProtocol)? { get }
  var candidateUI: (any CtlCandidateProtocol)? { get }
}

// MARK: - HitCheckerProtocol

public protocol HitCheckerProtocol: AnyObject {
  func check(_ event: some InputSignalProtocol) -> Bool
}

// MARK: - ShiftKeyUpCheckerProtocol

public protocol ShiftKeyUpCheckerProtocol: AnyObject {
  var toggleWithLShift: Bool { get set }
  var toggleWithRShift: Bool { get set }
  func check(_ event: some InputSignalProtocol) -> Bool
}

extension ShiftKeyUpCheckerProtocol {
  public var enabled: Bool { toggleWithLShift || toggleWithRShift }
}

// MARK: - CapsLockTogglerProtocol

public protocol CapsLockTogglerProtocol {
  var isOn: Bool { get set }
}

// MARK: - PCBProtocol

public protocol PCBProtocol: AnyObject {
  var isTypingDirectionVertical: Bool { get set }
  /// 浮動組字窗目前是否顯示中。
  var isShown: Bool { get }
  /// 浮動組字窗目前的視窗 frame（螢幕座標）；僅於 `isShown` 時有意義。
  var frame: CGRect? { get }
  func show(state: some IMEStateProtocol, at point: CGPoint)
  func hide()
  func sync(accent: HSBA?, locale: String)
}

// MARK: - TooltipUIProtocol

public protocol TooltipUIProtocol {
  func show(
    tooltip: String, at point: CGPoint,
    bottomOutOfScreenAdjustmentHeight heightDelta: Double,
    direction: UILayoutOrientation, duration: Double
  )

  func hide()
  /// 視窗目前是否顯示中。
  var isShown: Bool { get }
  func setColor(state: TooltipColorState)
  /// 依 accent／locale 同步外觀（文字色與視圖背景色）。TooltipUI 以顯式 no-op 滿足；
  /// StatusUI 實作之（背景為實色、不透明，無 visualEffect／glassEffect）。
  func sync(accent: HSBA?, locale: String)
}
