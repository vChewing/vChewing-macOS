// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Carbon

// MARK: - SecurityAgentHelper

public final class SecurityAgentHelper {
  // MARK: Lifecycle

  private init() {
    let carried = SecurityAgentSessionLedger(prefs: PrefMgr.shared)
    let started = carried.startingNewSession(at: Date())
    self.ledger = started.ledger
    self.isInSafeMode = started.isSafeMode
    ledger.persist(to: PrefMgr.shared)
    SecurityAgentSignalTombstone.install()
    reportPreviousTermination(carried: carried, isInSafeMode: started.isSafeMode)
  }

  deinit {
    removeTimer()
  }

  // MARK: Public

  public static let shared = SecurityAgentHelper()

  /// 掃描週期。
  public static let scanInterval: TimeInterval = 60

  public func deployTimer() {
    guard timer == nil else { return }
    let newTimer = Timer.scheduledTimer(
      timeInterval: Self.scanInterval, target: self, selector: #selector(checkAndHandle(_:)),
      userInfo: nil, repeats: true
    )
    newTimer.tolerance = Self.scanInterval / 3
    timer = newTimer
    vCLog(
      "SecurityAgentHelper is online, scanning SecureEventInput abusers every \(Int(Self.scanInterval)) seconds."
    )
    checkAndHandle(newTimer)
  }

  nonisolated public func removeTimer() {
    mainSync {
      timer?.invalidate()
      timer = nil
    }
  }

  /// 於正常終結路徑記一次「乾淨結束」，並把連續非正常結束之計數歸零。
  ///
  /// 唯有如此，`imklaunchagent` 之「died too many times recently」計數才有機會回落；未及呼叫本
  /// 函式者（崩潰、被 `SIGKILL`）即留下墓碑，由下一輪起動反推。
  public func recordCleanExit() {
    ledger = ledger.recordingCleanExit(at: Date())
    ledger.persist(to: PrefMgr.shared)
    vCLog(forced: true, "SecurityAgentHelper recorded a clean exit; the abnormal-death streak is cleared.")
  }

  @objc
  public func checkAndHandle(_: Timer) {
    beatHeart()
    guard !isScanning else { return }
    isScanning = true
    defer { isScanning = false }

    guard !isInSafeMode else { return }
    guard PrefMgr.shared.checkAbusersOfSecureEventInputAPI else { return }

    let results = SecureEventInputSputnik.getRunningSecureInputApps(abusersOnly: true)
    vCLog("SecurityAgentHelper scanned SecureEventInput abusers. \(results.count) targets found.")
    guard !results.isEmpty else { return }
    _ = DisableSecureEventInput()
    // WARNING: It is not necessary, but extremely troublesome,
    // to call EnableSecureEventInput manually here
    // (whether deferred or not).
    //
    // EnableSecureEventInput is automatically invoked by the system
    // whenever a password field regains focus. The SecureEventInput
    // API is only designed for protecting password fields. When
    // vChewing issues a warning about abuse of the SecureEventInput
    // API, all password fields in other applications lose focus.
    //
    // Modern AI-powered security vulnerability scanners apparently
    // are never aware that leaving SecureEventInput enabled
    // (i.e., failing to restore the previous state) completely
    // prevents users from switching to any 3rd-party input method
    // — regardless of whether the current app has text input focus.
    //
    // This long-standing issue has severely degraded the UX for all
    // 3rd-party input method users ever since SecureEventInput (or
    // InputMethodKit, whichever came later) was introduced.
    //
    // The built-in Zhuyin input method on macOS is quite poor,
    // yet Apple's Chinese Input Method Team (as of May 2026)
    // refuses to improve it. They are even unwilling to provide
    // a Zhuyin IME for typing Simplified Chinese. Apple's bug report
    // and feedback channels have remained largely unresponsive for
    // decades unless the issue is a critical security vulnerability.
    // This is why users "vote with their feet" and choose
    // third-party solutions.
    var pending = results
    Self.reportedPIDs.forEach { pending[$0] = nil }
    guard !pending.isEmpty else { return }
    pending.keys.forEach { Self.reportedPIDs.append($0) }
    // 上一則警示仍在畫面上時不再疊加。`DisableSecureEventInput()` 已於上方每輪照常執行，
    // 故此處只略過呈現、不略過緩解。
    guard warningWindow == nil else { return }
    presentWarning(for: pending)
  }

  // MARK: Internal

  var timer: Timer?

  private(set) var ledger: SecurityAgentSessionLedger
  private(set) var isInSafeMode: Bool

  // MARK: Private

  private static var reportedPIDs: [Int32] = []

  private var isScanning = false
  private var warningWindow: NSWindow?

  /// 把「上一輪是怎麼結束的」寫進系統記錄。
  ///
  /// 這幾行**不受 `_DebugMode` 管制**：若連「上一輪怎麼死的」都要使用者先開偵錯模式才會記，
  /// 則每一次客訴都只能從零開始——而客訴的間隔是「每隔數日」。一行日誌換一次客訴的資訊量，
  /// 這個交易划算。
  private func reportPreviousTermination(
    carried: SecurityAgentSessionLedger,
    isInSafeMode: Bool
  ) {
    vCLog(
      forced: true,
      "SecurityAgentHelper booted. previousSessionAbnormal=\(carried.previousSessionEndedAbnormally) previousSessionLifespan=\(Int(carried.previousSessionLifespan))s streak=\(carried.abnormalDeathStreak) safeMode=\(isInSafeMode)"
    )
    let records = SecurityAgentSignalTombstone.drainPreviousRecords()
    guard !records.isEmpty else { return }
    records.forEach { record in
      let senderPath = SecurityAgentSignalTombstone.executablePath(ofSenderPID: record.senderPID)
      vCLog(
        forced: true,
        "Previous session was terminated by signal \(record.signal) from pid \(record.senderPID) at \(senderPath ?? "an unresolvable path")"
      )
    }
  }

  private func beatHeart() {
    let next = ledger.beatingHeart(at: Date())
    guard next != ledger else { return }
    ledger = next
    ledger.persist(to: PrefMgr.shared)
  }

  /// 以**非阻塞**之方式呈現警告。
  ///
  /// 舊制以 `NSAlert.runModal()` 呈現、並在其**返回之後**才呼叫 `NSApp.popup()`：對一枚
  /// 遊戲 `LSUIElement` 之 accessory app 而言，警示視窗於整個巢狀執行迴圈期間都拿不到啟用，
  /// 而主執行緒則被扣住——對輸入法而言，這等同於停止回應。故本制改為先取得啟用、再以
  /// `orderFrontRegardless()` 逼出視窗，且整個呈現過程不進入任何巢狀執行迴圈。
  private func presentWarning(for targets: [Int32: NSRunningApplication]) {
    var entries: [String] = ["i18n:securityAgentHelper.warningMessage.header".i18n]
    for (matchedPID, matchedApp) in targets.sorted(by: { $0.key < $1.key }) {
      var builder = ContiguousArray<String>(["[PID: \(matchedPID)]"])
      let bundleURL = matchedApp.bundleURL ?? matchedApp.executableURL
      if let bundleURL {
        builder.append(" \(bundleURL.lastPathComponent)")
        if let bundleIdentifier = matchedApp.bundleIdentifier {
          builder.append(" (\(bundleIdentifier))")
        }
        builder.append("\n→ \(bundleURL.path)")
      } else if let bundleIdentifier = matchedApp.bundleIdentifier {
        builder.append(" \(bundleIdentifier)")
      }
      entries.append(builder.joined())
    }
    entries.append("i18n:securityAgentHelper.warningMessage.footer".i18n)

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "i18n:securityAgentHelper.warningMessage.title".i18n
    alert.informativeText = entries.joined(separator: "\n\n")
    alert.addButton(withTitle: "i18n:Common.OK".i18n)

    let window = alert.window
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hidesOnDeactivate = false
    window.center()
    alert.buttons.forEach { button in
      button.target = self
      button.action = #selector(dismissWarning(_:))
    }
    warningWindow = window
    NSApp.popup()
    window.orderFrontRegardless()
  }

  @objc
  private func dismissWarning(_: Any?) {
    warningWindow?.orderOut(nil)
    warningWindow = nil
  }
}

// MARK: - SecurityAgentSessionLedger + PrefMgr

extension SecurityAgentSessionLedger {
  init(prefs: PrefMgr) {
    self.init(
      bootedAtStamp: prefs.securityAgentSessionBootedAt,
      heartbeatAtStamp: prefs.securityAgentSessionHeartbeatAt,
      cleanExitAtStamp: prefs.securityAgentSessionCleanExitAt,
      abnormalDeathStreak: prefs.securityAgentAbnormalDeathStreak
    )
  }

  func persist(to prefs: PrefMgr) {
    prefs.securityAgentSessionBootedAt = bootedAtStamp
    prefs.securityAgentSessionHeartbeatAt = heartbeatAtStamp
    prefs.securityAgentSessionCleanExitAt = cleanExitAtStamp
    prefs.securityAgentAbnormalDeathStreak = abnormalDeathStreak
  }
}
