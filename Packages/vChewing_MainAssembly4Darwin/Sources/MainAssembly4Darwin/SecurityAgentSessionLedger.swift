// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - SecurityAgentSessionLedger

/// 「心跳／墓碑」帳本：令下一輪起動得以反推上一輪是否死於非命。
/// ---------
/// 一旦行程被結束，它就再無機會留下遺言——訊號處理器對 `SIGKILL` 無能為力，而崩潰當下亦無可信
/// 之堆疊。故死亡只能**事後**反推：每一輪起動先寫下「起動時刻」、同時把「乾淨結束時刻」抹去；
/// 唯有走到正常終結路徑時，才補上「乾淨結束時刻」，並在存活期間定期更新「心跳時刻」。
///
/// 何以需要心跳：起動時刻本身只能量到「起動至下一輪起動」之總長，分不出「上一輪活了三分鐘就被
/// 殺」與「上一輪活了三小時、之後閒置三小時才被重新拉起」。有心跳即分得出——上一輪若活滿
/// ``maturityInterval``，其結束方式即屬正常老化，不計入崩潰迴圈。
public struct SecurityAgentSessionLedger: Equatable {
  // MARK: Lifecycle

  public init(
    bootedAt: Date = .distantPast,
    heartbeatAt: Date = .distantPast,
    cleanExitAt: Date = .distantPast,
    abnormalDeathStreak: Int = 0
  ) {
    self.bootedAt = bootedAt
    self.heartbeatAt = heartbeatAt
    self.cleanExitAt = cleanExitAt
    self.abnormalDeathStreak = max(0, abnormalDeathStreak)
  }

  /// 自三筆「`timeIntervalSince1970` 時刻」建帳；`0` 即「無紀錄」。
  public init(
    bootedAtStamp: Double,
    heartbeatAtStamp: Double,
    cleanExitAtStamp: Double,
    abnormalDeathStreak: Int
  ) {
    self.init(
      bootedAt: Self.date(fromStamp: bootedAtStamp),
      heartbeatAt: Self.date(fromStamp: heartbeatAtStamp),
      cleanExitAt: Self.date(fromStamp: cleanExitAtStamp),
      abnormalDeathStreak: abnormalDeathStreak
    )
  }

  // MARK: Public

  /// 上一輪若活滿此長度，其結束方式即視為「正常老化」，不計入崩潰迴圈。
  ///
  /// 輸入法行程常於登出、重開機一類由系統主導之場合被逕行收掉，而那並非缺陷。若不設此門檻，
  /// 每一輪都會被誤記為「死於非命」，安全模式遂永無寧日。
  public static let maturityInterval: TimeInterval = 600

  /// 連續非正常結束達此次數，即逕入安全模式。
  ///
  /// `imklaunchagent` 之封鎖條件是「died too many times recently」而不公布確切門檻；此處取三，
  /// 係取其下限而留一次餘裕——目的不是猜中系統的門檻，而是**永遠先於系統一步**收手。
  public static let abnormalDeathLimit = 3

  /// 心跳之寫入節流間隔。
  public static let heartbeatInterval: TimeInterval = 300

  public var bootedAt: Date
  public var heartbeatAt: Date
  public var cleanExitAt: Date
  public var abnormalDeathStreak: Int

  public var bootedAtStamp: Double { Self.stamp(from: bootedAt) }
  public var heartbeatAtStamp: Double { Self.stamp(from: heartbeatAt) }
  public var cleanExitAtStamp: Double { Self.stamp(from: cleanExitAt) }

  /// 上一輪是否留下「非正常結束」之痕跡。
  ///
  /// 判準為「乾淨結束時刻早於起動時刻」：起動時一律把乾淨結束時刻抹去，故上一輪若未走到正常
  /// 終結路徑，此值必然仍停在更早的時刻。
  public var previousSessionEndedAbnormally: Bool {
    guard bootedAt > .distantPast else { return false }
    return cleanExitAt < bootedAt
  }

  /// 上一輪自起動至最後一次心跳之長度；無心跳紀錄即為零。
  public var previousSessionLifespan: TimeInterval {
    guard heartbeatAt > .distantPast else { return 0 }
    return max(0, heartbeatAt.timeIntervalSince(bootedAt))
  }

  // MARK: Internal

  /// 以既存帳本推算本輪之起始帳本，並交回「本輪是否該逕入安全模式」。
  ///
  /// 進入安全模式時會把計數歸零：安全模式本身即為「本輪不再執行該危險路徑」之宣告，計數若
  /// 不歸零，則計數將永遠停在高位、安全模式便永不解封。
  func startingNewSession(at now: Date) -> (ledger: Self, isSafeMode: Bool) {
    let carriedStreak: Int
    if previousSessionEndedAbnormally {
      let isMature = previousSessionLifespan >= Self.maturityInterval
      carriedStreak = isMature ? 0 : abnormalDeathStreak + 1
    } else {
      carriedStreak = 0
    }
    let isSafeMode = carriedStreak >= Self.abnormalDeathLimit
    var next = Self(bootedAt: now, heartbeatAt: now)
    next.abnormalDeathStreak = isSafeMode ? 0 : carriedStreak
    return (next, isSafeMode)
  }

  /// 記一次心跳；距上次心跳未滿 ``heartbeatInterval`` 即原樣奉還。
  func beatingHeart(at now: Date) -> Self {
    guard now.timeIntervalSince(heartbeatAt) >= Self.heartbeatInterval else { return self }
    var result = self
    result.heartbeatAt = now
    return result
  }

  /// 記一次乾淨結束——計數一併歸零。
  func recordingCleanExit(at now: Date) -> Self {
    var result = self
    result.cleanExitAt = now
    result.abnormalDeathStreak = 0
    return result
  }

  // MARK: Private

  private static func date(fromStamp stamp: Double) -> Date {
    stamp > 0 ? Date(timeIntervalSince1970: stamp) : .distantPast
  }

  private static func stamp(from date: Date) -> Double {
    date > .distantPast ? date.timeIntervalSince1970 : 0
  }
}
