// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
  var candidateUI: (any CtlCandidateProtocol)? { get }
  var similarPhoneticUI: (any SimilarPhoneticUIProtocol)? { get }
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
  func setColor(state: TooltipColorState)
}

// MARK: - SimilarPhoneticUIProtocol

public protocol SimilarPhoneticUIProtocol: AnyObject {
  /// 顯示近音表視窗，依照 state 的 `similarPhoneticRows` 和 `selectedSimilarPhoneticRow` 渲染。
  /// - Parameters:
  ///   - state: 含有近音表資料的 `ofSimilarPhonetic` 狀態。
  ///   - lineHeightRect: 輸入游標行高矩形（螢幕座標），用於決定視窗顯示位置並作上下翻轉調整。
  func show(state: some IMEStateProtocol, at lineHeightRect: CGRect)
  /// 更新近音表顯示（列選擇變動時呼叫，不需要重定位視窗）。
  func update(state: some IMEStateProtocol)
  /// 隱藏視窗。
  func hide()
}
