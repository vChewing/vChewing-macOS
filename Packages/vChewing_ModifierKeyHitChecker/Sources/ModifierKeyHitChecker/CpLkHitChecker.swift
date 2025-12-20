// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

// MARK: - CpLkHitDetector

/// Caps Lock 單次敲擊偵測器
///
/// 設計前提（macOS 14+ 現實）：
/// - CpLk 可能只收到 KeyDown 或只收到 KeyUp
/// - 不同輸入法、不同 Host App（Electron）行為不一致
/// - Press-and-hold 必須整組作廢
/// - 同一組物理敲擊，最多只能觸發一次
public final class CpLkHitChecker {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  /// 判定是否為一次「有效的 Caps Lock 敲擊」
  ///
  /// - 注意：
  ///   - KeyDown / KeyUp 任一皆可觸發
  ///   - KeyDown → KeyUp 不得觸發兩次
  ///   - 長按（Press-and-hold）整次作廢
  public func check(_ event: some InputSignalProtocol) -> Bool {
    let now = Date().timeIntervalSinceReferenceDate

    // 僅關心 Caps Lock 實體鍵
    guard event.keyCode == KeyCode.kCapsLock.rawValue else {
      resetIfNeeded(by: event)
      return false
    }

    // 1. 長按判定（只要進入長按狀態，整組事件直接報廢）

    if isHolding {
      // 若長按期間仍有事件進來，僅等待結束
      if isReleaseEvent(event) {
        reset()
      }
      return false
    }

    // 2. KeyDown 偵測（可能是唯一事件）

    if isKeyDownEvent(event) {
      // 若在冷卻期內，直接忽略（防止重複）
      if isInRetriggerGuard(now: now) {
        return false
      }

      pressStartTime = now
      pending = true
      return false
    }

    // 3. KeyUp 偵測（可能是唯一事件）

    if isReleaseEvent(event) {
      // 若未曾看到 KeyDown，也允許作為一次敲擊
      if pressStartTime == nil {
        return commitTrigger(now: now)
      }

      guard let start = pressStartTime else { return false }

      // 長按 → 作廢
      if now - start > holdThreshold {
        reset()
        return false
      }

      // 正常 KeyDown → KeyUp
      return commitTrigger(now: now)
    }

    return false
  }

  // MARK: Private

  /// 是否正在追蹤一次潛在的 CpLk 敲擊
  private var pending: Bool = false

  /// CpLk 按下的時間點
  private var pressStartTime: TimeInterval?

  /// 最近一次成功觸發的時間（冷卻鎖）
  private var lastTriggerTime: TimeInterval?

  /// 是否已進入「長按狀態」
  private var isHolding: Bool = false

  /// 長按判定時間
  private let holdThreshold: TimeInterval = 0.3

  /// 觸發後冷卻時間（防止同一次物理敲擊被判兩次）
  private let retriggerGuardInterval: TimeInterval = 0.05

  // MARK: - Event Classification

  private func isKeyDownEvent(_ event: some InputSignalProtocol) -> Bool {
    event.typeID == KBEvent.EventType.keyDown.rawValue
  }

  private func isReleaseEvent(_ event: some InputSignalProtocol) -> Bool {
    event.typeID == KBEvent.EventType.keyUp.rawValue
      || (event.isFlagChanged && !event.isCapsLockOn)
  }

  // MARK: - Trigger Handling

  private func commitTrigger(now: TimeInterval) -> Bool {
    defer { reset() }

    // 冷卻鎖：防止雙重觸發
    if let last = lastTriggerTime,
       now - last < retriggerGuardInterval {
      return false
    }

    lastTriggerTime = now
    return true
  }

  // MARK: - Reset Logic

  private func reset() {
    pending = false
    pressStartTime = nil
    isHolding = false
  }

  /// 非 Caps Lock 事件進來時，用於判定是否進入長按
  private func resetIfNeeded(by event: some InputSignalProtocol) {
    guard pending, let start = pressStartTime else { return }

    let now = Date().timeIntervalSinceReferenceDate
    if now - start > holdThreshold {
      isHolding = true
    }
  }

  private func isInRetriggerGuard(now: TimeInterval) -> Bool {
    guard let last = lastTriggerTime else { return false }
    return now - last < retriggerGuardInterval
  }
}
