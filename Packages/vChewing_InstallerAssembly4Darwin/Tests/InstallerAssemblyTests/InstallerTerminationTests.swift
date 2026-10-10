// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
@testable import InstallerAssembly4Darwin
import Testing

@Suite
struct InstallerTerminationTests {
  // MARK: Internal

  @Test
  func testWaitUntilReturnsTrueWhenConditionAlreadyHolds() {
    var calls = 0
    let result = waitUntil(timeout: 1.0, pollInterval: 0.01) {
      calls += 1
      return true
    }
    #expect(result)
    #expect(calls == 1)
  }

  @Test
  func testWaitUntilGivesUpAtTimeout() {
    let start = Date()
    let result = waitUntil(timeout: 0.2, pollInterval: 0.05) { false }
    let elapsed = Date().timeIntervalSince(start)
    #expect(!result)
    // 逾時即返回：允許排程誤差，但不允許等到天荒地老。
    #expect(elapsed < 1.0)
  }

  @Test
  func testWaitUntilObservesLateCondition() {
    var remainingPolls = 3
    let result = waitUntil(timeout: 2.0, pollInterval: 0.01) {
      remainingPolls -= 1
      return remainingPolls <= 0
    }
    #expect(result)
  }

  @Test
  func testTerminationOutcomeLogLineReportsVacated() {
    let outcome = TerminationOutcome(captured: [11, 22], escalated: false, surviving: [])
    #expect(
      outcome.logLine(reason: "postSwap")
        == "Terminate: reason=postSwap captured=[11,22] escalated=false "
        + "result=vacated surviving=[]"
    )
  }

  @Test
  func testTerminationOutcomeLogLineReportsStuckWithEscalation() {
    let outcome = TerminationOutcome(captured: [33], escalated: true, surviving: [33])
    #expect(
      outcome.logLine(reason: "preSwap")
        == "Terminate: reason=preSwap captured=[33] escalated=true result=stuck surviving=[33]"
    )
  }

  @Test
  func testVacantTargetsAreReportedAsVacated() {
    let outcome = terminateRunningInputMethodInstances(
      reason: "unitTest",
      executableNames: ["vChewingUnitTestProbe-\(UUID().uuidString)"],
      escalates: false
    )
    #expect(outcome.captured.isEmpty)
    #expect(outcome.surviving.isEmpty)
    #expect(outcome.isVacant)
  }

  @Test
  func testInvalidPIDsAreNeverSignalled() {
    // pid 0 是「行程群組」、pid 1 是 launchd、其餘是本測試行程：三者皆不得被送訊號。
    let outcome = terminateProcesses(
      [0, 1, getpid()], reason: "unitTest", timing: .bestEffort, escalates: true
    )
    #expect(outcome.captured == [0, 1, getpid()])
    #expect(outcome.surviving.isEmpty)
    #expect(!outcome.escalated)
  }

  @Test
  func testCooperativeProcessIsTerminatedBySIGTERM() throws {
    let task = try spawnProbeProcess(executable: "/bin/sleep", arguments: ["30"])
    let pid = task.processIdentifier
    #expect(pid > 1)
    #expect(waitUntil(timeout: 2.0) { isProcessAlive(pid) })

    let outcome = terminateProcesses(
      [pid],
      reason: "unitTest",
      timing: TerminationTiming(pollInterval: 0.05, gracefulTimeout: 2.0, forcefulTimeout: 2.0)
    )
    task.waitUntilExit() // 收屍，避免留殭屍。
    #expect(outcome.captured == [pid])
    #expect(!outcome.escalated)
    #expect(outcome.isVacant)
    #expect(!isProcessAlive(pid))
  }

  @Test
  func testUncooperativeProcessForcesEscalation() throws {
    // `trap '' TERM` 讓該行程忽略 SIGTERM；`exec` 之後該忽略設定仍被繼承，SIGKILL 仍應收效。
    // 注意：`exec` 的目標一律寫絕對路徑——測試行程之 `PATH` 未必含 `/bin`，寫相對名稱會讓
    // shell 以 127 退出，探針在我們動手之前就已自行消失，測出來的「成功」是假象。
    let task = try spawnProbeProcess(
      executable: "/bin/sh", arguments: ["-c", "trap '' TERM; exec /bin/sleep 30"]
    )
    let pid = task.processIdentifier
    #expect(pid > 1)
    #expect(waitUntil(timeout: 2.0) { isProcessAlive(pid) })
    Thread.sleep(forTimeInterval: 0.3) // 等探針完成 exec；若它其實會自行退出，這裡就會露餡。
    #expect(isProcessAlive(pid))

    let outcome = terminateProcesses(
      [pid],
      reason: "unitTest",
      timing: TerminationTiming(pollInterval: 0.05, gracefulTimeout: 0.3, forcefulTimeout: 2.0)
    )
    task.waitUntilExit() // 收屍，避免留殭屍。
    #expect(outcome.captured == [pid])
    #expect(outcome.escalated)
    #expect(outcome.isVacant)
    #expect(!isProcessAlive(pid))
  }

  @Test
  func testKillAllExitStatusIsReportedForAbsentTarget() {
    // 不存在的程序名：killall 以非零結束碼回報，本助手必須把該碼帶回來（而非靜默吞掉）。
    let name = "vChewingUnitTestProbe-\(UUID().uuidString)"
    let status = terminateByProcessName(name, reason: "unitTest")
    #expect(status != nil)
    #expect(status != 0)
  }

  @Test
  func testRunProcessCapturingStatusReturnsOutputAndStatus() {
    let outcome = runProcessCapturingStatus("/bin/echo", args: ["vChewing"])
    #expect(outcome.status == 0)
    #expect(outcome.output.trimmingCharacters(in: .whitespacesAndNewlines) == "vChewing")
  }

  @Test
  func testProcurementCaptureSeesNonAppInstanceByName() throws {
    // 以 `pgrep -x` 那一路捕捉：探針刻意不是 App（NSWorkspace 之應用程式清單看不到它），
    // 故本測只可能經作業系統之程序表命中。檔名須短於 `MAXCOMLEN`（16 位元組）以免比對失真。
    // 先探測本環境能否列舉程序：某些沙盒（含開發代理所用之沙盒）不容 `pgrep` 查詢程序表，
    // 此時本測無從成立、直接略過（`pgrep` 那一路在正式安裝情境仍為備援）。
    let probe = runProcessCapturingStatus("/usr/bin/pgrep", args: ["-x", "launchd"])
    guard !probe.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    let name = "vcprobe" + String(UUID().uuidString.prefix(6)).lowercased()
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sleep"), to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let task = try spawnProbeProcess(executable: url.path, arguments: ["20"])
    let pid = task.processIdentifier
    #expect(waitUntil(timeout: 2.0) { isProcessAlive(pid) })
    Thread.sleep(forTimeInterval: 0.2)

    let captured = captureRunningInstances(executableNames: [name], bundleIdentifier: nil)
    #expect(captured.contains(pid))

    _ = terminateProcesses([pid], reason: "unitTest", timing: .bestEffort)
    task.waitUntilExit()
  }

  // MARK: Private

  /// 起一個探針行程（本測試行程之直接子行程）。
  /// - 說明：**不可**改用 `/bin/sh -c "sleep 30 & echo $!"` 之類的孤兒手法——在本專案之測試
  ///   環境中，`/bin/sh` 一退出，由其背景啟動的行程也隨即消失，探針當場即非存活，測不出東西。
  /// - Returns: 該子行程之 `Process`（呼叫端須於終止後 `waitUntilExit()` 收屍）。
  private func spawnProbeProcess(executable: String, arguments: [String]) throws -> Process {
    let task = Process()
    task.standardOutput = nil
    task.standardError = nil
    task.standardInput = nil
    task.arguments = arguments
    if #available(macOS 10.13, *) {
      task.executableURL = URL(fileURLWithPath: executable)
    } else {
      task.launchPath = executable
    }
    try task.run()
    return task
  }
}
