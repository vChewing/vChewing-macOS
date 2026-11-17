// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import SwiftExtension
import Testing

@testable import MainAssembly4Darwin

// MARK: - SecurityAgentSessionLedgerTests

/// 心跳／墓碑帳本之判定：死亡只能由下一輪起動反推，故每一種「上一輪怎麼結束」皆須有定論。
struct SecurityAgentSessionLedgerTests {
  /// 固定時基：本套房不碰真實時鐘。
  static let base = Date(timeIntervalSince1970: 1_800_000_000)

  @Test
  func testFreshInstallIsNeitherAbnormalNorSafeMode() {
    let fresh = SecurityAgentSessionLedger()
    #expect(!fresh.previousSessionEndedAbnormally)
    #expect(fresh.previousSessionLifespan == 0)
    let started = fresh.startingNewSession(at: Self.base)
    #expect(started.isSafeMode == false)
    #expect(started.ledger.abnormalDeathStreak == 0)
    #expect(started.ledger.bootedAt == Self.base)
    #expect(started.ledger.cleanExitAt == .distantPast)
  }

  @Test
  func testCleanExitResetsTheStreak() {
    let previous = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base.addingTimeInterval(60),
      cleanExitAt: Self.base.addingTimeInterval(600),
      abnormalDeathStreak: 2
    )
    #expect(!previous.previousSessionEndedAbnormally)
    let started = previous.startingNewSession(at: Self.base.addingTimeInterval(900))
    #expect(started.isSafeMode == false)
    #expect(started.ledger.abnormalDeathStreak == 0)
  }

  @Test
  func testQuickAbnormalDeathIncrementsTheStreak() {
    let previous = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base.addingTimeInterval(120),
      cleanExitAt: .distantPast,
      abnormalDeathStreak: 0
    )
    #expect(previous.previousSessionEndedAbnormally)
    #expect(previous.previousSessionLifespan == 120)
    let started = previous.startingNewSession(at: Self.base.addingTimeInterval(180))
    #expect(started.isSafeMode == false)
    #expect(started.ledger.abnormalDeathStreak == 1)
    // 本輪起動即把乾淨結束時刻抹去——下一輪若見此帳，即知本輪亦未善終。
    #expect(started.ledger.cleanExitAt == .distantPast)
  }

  @Test
  func testMatureSessionEndingIsTreatedAsNormalAgeing() {
    let previous = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base.addingTimeInterval(SecurityAgentSessionLedger.maturityInterval),
      cleanExitAt: .distantPast,
      abnormalDeathStreak: 2
    )
    #expect(previous.previousSessionEndedAbnormally)
    let started = previous.startingNewSession(at: Self.base.addingTimeInterval(4_000))
    #expect(started.isSafeMode == false)
    #expect(started.ledger.abnormalDeathStreak == 0)
  }

  @Test
  func testReachingTheLimitEntersSafeModeAndResetsTheStreak() {
    let previous = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base,
      cleanExitAt: .distantPast,
      abnormalDeathStreak: SecurityAgentSessionLedger.abnormalDeathLimit - 1
    )
    let started = previous.startingNewSession(at: Self.base.addingTimeInterval(30))
    #expect(started.isSafeMode)
    // 若計數不歸零，安全模式將永不解封（本輪不可能再累加、亦無從回落）。
    #expect(started.ledger.abnormalDeathStreak == 0)
  }

  @Test
  func testHeartbeatIsThrottled() {
    let ledger = SecurityAgentSessionLedger(bootedAt: Self.base, heartbeatAt: Self.base)
    #expect(ledger.beatingHeart(at: Self.base.addingTimeInterval(100)) == ledger)
    let beaten = ledger.beatingHeart(at: Self.base.addingTimeInterval(300))
    #expect(beaten.heartbeatAt == Self.base.addingTimeInterval(300))
    #expect(beaten.bootedAt == ledger.bootedAt)
  }

  @Test
  func testRecordingCleanExitClearsEverything() {
    let ledger = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base,
      cleanExitAt: .distantPast,
      abnormalDeathStreak: 2
    )
    let exited = ledger.recordingCleanExit(at: Self.base.addingTimeInterval(60))
    #expect(exited.cleanExitAt == Self.base.addingTimeInterval(60))
    #expect(exited.abnormalDeathStreak == 0)
    #expect(!exited.previousSessionEndedAbnormally)
  }

  @Test
  func testLedgerRoundTripsThroughInjectedStore() {
    let prefs = PrefMgr(store: InMemoryDefaultsStore())
    let ledger = SecurityAgentSessionLedger(
      bootedAt: Self.base,
      heartbeatAt: Self.base.addingTimeInterval(60),
      cleanExitAt: .distantPast,
      abnormalDeathStreak: 2
    )
    ledger.persist(to: prefs)
    #expect(SecurityAgentSessionLedger(prefs: prefs) == ledger)
  }

  @Test
  func testEmptyStoreReadsAsAFreshLedger() {
    let prefs = PrefMgr(store: InMemoryDefaultsStore())
    let restored = SecurityAgentSessionLedger(prefs: prefs)
    #expect(restored == SecurityAgentSessionLedger())
    #expect(restored.bootedAtStamp == 0)
  }
}
