// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

// MARK: - CpLkHitChecker

/// Caps Lock 單次敲擊偵測器（macOS 14 / Electron 穩定版）
///
/// 設計原則：
/// - **只依賴 flagsChanged**
/// - **只檢查 keyCode == CapsLock**
/// - 不嘗試判定 KeyDown / KeyUp
/// - 使用時間節流防止同一次物理敲擊被觸發多次
///
/// 工程現實：
/// - 這是目前唯一在 Electron / Discord 下始終成立的模型
public final class CpLkHitChecker: HitCheckerProtocol {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public func check(_ event: some InputSignalProtocol) -> Bool {
    // 只接受 Caps Lock 的 flagsChanged
    guard event.isFlagChanged,
          event.keyCode == KeyCode.kCapsLock.rawValue
    else {
      return false
    }

    let now = Date().timeIntervalSinceReferenceDate

    // 時間節流：防止連續觸發
    if let last = lastTriggerTime,
       now - last < throttleInterval {
      return false
    }

    lastTriggerTime = now
    return true
  }

  // MARK: Private

  /// 最近一次成功觸發的時間
  private var lastTriggerTime: TimeInterval?

  /// 觸發節流時間（防止 flagsChanged 重複注入）
  private let throttleInterval: TimeInterval = 0.08
}
