// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import Shared

// MARK: - VCLogGateTests

/// `vCLogIsEnabled(forced:)` 係「這則訊息真的會寫出去」的唯一判準（P354）。
///
/// 何以要為它立測試：昂貴的診斷訊息（堆疊符號化、`KBEvent` 描述）必須先問這一支才可動手建；
/// 若判準本身與 `vCLog` 之實際行為脫節，就會重演「先付錢、後丟棄」——每次狀態切換白白
/// 符號化一次堆疊，卻什麼都沒寫出去。
@Suite("VCLogGate")
final class VCLogGateTests {
  // MARK: Internal

  @Test("Debug mode off ⇒ disabled")
  func debugModeOffMeansDisabled() {
    withProbeEnvironment(debugMode: false, isRunningUnitTests: false) {
      #expect(!vCLogIsEnabled())
      #expect(!vCLogIsEnabled(forced: false))
    }
  }

  @Test("Debug mode on ⇒ enabled")
  func debugModeOnMeansEnabled() {
    withProbeEnvironment(debugMode: true, isRunningUnitTests: false) {
      #expect(vCLogIsEnabled())
    }
  }

  @Test("Forced logging bypasses the debug-mode gate")
  func forcedLoggingBypassesDebugMode() {
    withProbeEnvironment(debugMode: false, isRunningUnitTests: false) {
      #expect(vCLogIsEnabled(forced: true))
    }
  }

  /// 測試模式下，閘門是否敞開取決於「本輪是否帶了過濾參數」——故期望值由參數現算，
  /// 不寫死：整倉測試（無 `--filter`）時一律靜音，逐案例過濾時則照常輸出。
  @Test("Unit-test mode follows the filter argument")
  func unitTestModeFollowsTheFilterArgument() {
    let hasFilterArgument = ProcessInfo.processInfo.arguments.contains {
      $0.hasPrefix("--filter") || $0.hasPrefix("--skip") || $0.hasPrefix("-XCTest")
    }
    withProbeEnvironment(debugMode: true, isRunningUnitTests: true) {
      #expect(vCLogIsEnabled() == hasFilterArgument)
      #expect(vCLogIsEnabled(forced: true) == hasFilterArgument)
    }
  }

  // MARK: Private

  /// 以可還原之方式置換測試所涉之兩個行程級旗標。
  ///
  /// `OSUtils.isRunningUnitTests` 係行程級全域；`SharedTests` 之 suite 已標 `.serialized`，
  /// 故以 `defer` 還原即足。
  private func withProbeEnvironment(
    debugMode: Bool,
    isRunningUnitTests: Bool,
    _ body: () -> ()
  ) {
    let previousStore = OSUtils.defaultsStore
    let previousUnitTestFlag = OSUtils.isRunningUnitTests
    let store = InMemoryDefaultsStore()
    store.set(debugMode, forKey: "_DebugMode")
    OSUtils.defaultsStore = store
    OSUtils.isRunningUnitTests = isRunningUnitTests
    defer {
      OSUtils.defaultsStore = previousStore
      OSUtils.isRunningUnitTests = previousUnitTestFlag
    }
    body()
  }
}
