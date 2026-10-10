// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Foundation
import SwiftExtension

// MARK: - TerminationTiming

/// 終止作業之節奏參數。
struct TerminationTiming {
  static let `default` = Self()

  /// 換檔前之盡力而為：不等候、不升級。
  static let bestEffort = Self(
    pollInterval: 0.1, gracefulTimeout: 0.5, forcefulTimeout: 0.5
  )

  /// 逐拍輪詢之間隔（秒）。
  var pollInterval: TimeInterval = 0.1
  /// 送出溫和終止訊號後、升級為強制終止之前的等待上限（秒）。
  var gracefulTimeout: TimeInterval = 3.0
  /// 送出強制終止訊號之後的等待上限（秒）。
  var forcefulTimeout: TimeInterval = 3.0
}

// MARK: - TerminationOutcome

/// 一次終止作業之結果。
struct TerminationOutcome: Equatable {
  /// 本次捕捉到的行程編號。
  var captured: [pid_t] = []
  /// 是否動用過強制終止（SIGKILL）。
  var escalated = false
  /// 等待結束後仍存活的行程編號。
  var surviving: [pid_t] = []

  /// 是否已無捕捉到的行程存活。
  var isVacant: Bool { surviving.isEmpty }

  /// 供系統記錄使用之單行描述。
  /// - Parameter reason: 本次終止作業之緣由標記（`preSwap`／`postSwap`／…）。
  func logLine(reason: String) -> String {
    let capturedText = captured.map(\.description).joined(separator: ",")
    let survivingText = surviving.map(\.description).joined(separator: ",")
    let escalatedText = escalated ? "true" : "false"
    let result = isVacant ? "vacated" : "stuck"
    return "Terminate: reason=\(reason) captured=[\(capturedText)] "
      + "escalated=\(escalatedText) result=\(result) surviving=[\(survivingText)]"
  }
}

/// 逐拍輪詢，直到 `condition` 成立或逾時。
/// - Parameters:
///   - timeout: 等待上限（秒）。
///   - pollInterval: 逐拍之間隔（秒）；最後一拍會縮短至剩餘時間以內。
///   - condition: 受測條件。
/// - Returns: `condition` 是否在時限內成立。
func waitUntil(
  timeout: TimeInterval,
  pollInterval: TimeInterval = 0.1,
  condition: () -> Bool
)
  -> Bool {
  if condition() { return true }
  let deadline = Date().addingTimeInterval(timeout)
  while true {
    let remaining = deadline.timeIntervalSinceNow
    guard remaining > 0 else { break }
    Thread.sleep(forTimeInterval: min(pollInterval, remaining))
    if condition() { return true }
  }
  return condition()
}

/// 行程是否仍存在。
///
/// `kill(pid, 0)` 只做存在性與權限檢查、不送訊號：`EPERM` 代表行程存在但不屬於本行程，
/// 於此仍算存活。
/// - Parameter pid: 受測行程編號。
func isProcessAlive(_ pid: pid_t) -> Bool {
  if kill(pid, 0) == 0 { return true }
  return errno == EPERM
}

/// 終止指定行程，並驗證它們確實退場。
///
/// 之所以直接送訊號、而不倚賴 `NSRunningApplication.terminate()`：後者是「請求結束」、
/// 客體有權拒絕（且對無回應的客體無效），而安裝流程要的是「保證」。
/// - Parameters:
///   - pids: 目標行程編號。
///   - reason: 本次終止作業之緣由標記。
///   - timing: 節奏參數。
///   - escalates: 溫和終止逾時後是否升級為 SIGKILL。
/// - Returns: 本次終止作業之結果（含日誌所需之欄位）。
@discardableResult
func terminateProcesses(
  _ pids: [pid_t],
  reason: String,
  timing: TerminationTiming = .default,
  escalates: Bool = true
)
  -> TerminationOutcome {
  // 剔除本行程與已消失者：前者絕不可自殺，後者無需處理。
  let targets = pids.filter { $0 > 1 && $0 != getpid() && isProcessAlive($0) }
  var outcome = TerminationOutcome(captured: pids)
  guard !targets.isEmpty else {
    OSUtils.consoleLog(outcome.logLine(reason: reason))
    return outcome
  }

  targets.forEach { kill($0, SIGTERM) }
  let vacated = waitUntil(timeout: timing.gracefulTimeout, pollInterval: timing.pollInterval) {
    targets.allSatisfy { !isProcessAlive($0) }
  }

  if !vacated, escalates {
    outcome.escalated = true
    targets.forEach { kill($0, SIGKILL) }
    _ = waitUntil(timeout: timing.forcefulTimeout, pollInterval: timing.pollInterval) {
      targets.allSatisfy { !isProcessAlive($0) }
    }
  }

  outcome.surviving = targets.filter { isProcessAlive($0) }
  OSUtils.consoleLog(outcome.logLine(reason: reason))
  return outcome
}

/// 蒐集正在執行的輸入法實例（就執行檔名與 bundle 識別字兩路捕捉、去重）。
///
/// 兩路並用之理由：bundle 識別字涵蓋「已安裝 bundle 之實例」，執行檔名另可涵蓋
/// 「自別處（含 `*.appTrashed` 舊 bundle）啟動的同名實例」——後者恰是舊行程最常見的殘留形態。
/// 執行檔名那一路再分兩式：AppKit 之執行中應用程式清單（認的是 `Contents/MacOS/` 之下那個
/// 檔名、不受 `MAXCOMLEN` 截斷影響），以及 `pgrep -x`（作業系統層之程序表，不依賴 AppKit
/// 之應用程式註冊）。兩式互為備援：前者可認超長檔名，後者不倚賴 AppKit。
/// - Parameters:
///   - executableNames: 執行檔名（`Contents/MacOS/` 之下那一層）。
///   - bundleIdentifier: 已安裝 bundle 之識別字；`nil` 表示只以執行檔名捕捉。
/// - Returns: 捕捉到的行程編號。
func captureRunningInstances(
  executableNames: Set<String>,
  bundleIdentifier: String?
)
  -> [pid_t] {
  var pids: [pid_t] = []
  var seen = Set<pid_t>()
  func collect(_ pid: pid_t) {
    guard pid > 1, seen.insert(pid).inserted else { return }
    pids.append(pid)
  }
  NSWorkspace.shared.runningApplications.forEach { app in
    guard let name = app.executableURL?.lastPathComponent, executableNames.contains(name)
    else { return }
    collect(app.processIdentifier)
  }
  if let bundleIdentifier {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
      .forEach { collect($0.processIdentifier) }
  }
  executableNames.sorted().forEach { name in
    let outcome = runProcessCapturingStatus("/usr/bin/pgrep", args: ["-x", name])
    outcome.output.split(separator: "\n").forEach { line in
      guard let pid = pid_t(line.trimmingCharacters(in: .whitespaces)) else { return }
      collect(pid)
    }
  }
  return pids
}

/// 終止執行中的輸入法實例，並驗證它們確實退場。
///
/// ★ 為何「換檔後的這一刀」才是保證：IMK 對輸入法係隨選啟動（客體一需要文字輸入即拉起），
/// 而系統永遠自「當下磁碟上、已註冊的那份 bundle」拉起。故換檔**之前**送出的終止只會讓系統
/// 立刻把舊碼重新拉起（新 PID、舊碼）——那枚新行程恰好躲過其後的一切檢查。唯有在 bundle
/// 就位**之後**再終止一次，才能保證此後被拉起的行程都是剛就位的新碼。
/// - Parameters:
///   - reason: 本次終止作業之緣由標記。
///   - executableNames: 執行檔名集合。
///   - bundleIdentifier: 已安裝 bundle 之識別字。
///   - timing: 節奏參數。
///   - escalates: 逾時後是否升級為 SIGKILL。
/// - Returns: 本次終止作業之結果。
@discardableResult
func terminateRunningInputMethodInstances(
  reason: String,
  executableNames: Set<String>,
  bundleIdentifier: String? = nil,
  timing: TerminationTiming = .default,
  escalates: Bool = true
)
  -> TerminationOutcome {
  let pids = captureRunningInstances(
    executableNames: executableNames, bundleIdentifier: bundleIdentifier
  )
  return terminateProcesses(pids, reason: reason, timing: timing, escalates: escalates)
}

/// 以 `/usr/bin/killall` 請指定具名程序離場，並將結束碼寫進系統記錄。
///
/// 保留此路徑係為了與既有行為一致（換檔前先請舊行程離場，可縮短舊行程寫入自身狀態的時間），
/// 但**不承擔保證**：`killall` 只認名字、且其退出碼從前從未被檢查過。
/// - Parameters:
///   - processName: 程序名。
///   - reason: 本次終止作業之緣由標記。
/// - Returns: `killall` 之結束碼；`nil` 表示該程式根本沒能啟動。
@discardableResult
func terminateByProcessName(_ processName: String, reason: String) -> Int32? {
  let outcome = runProcessCapturingStatus("/usr/bin/killall", args: [processName])
  let statusText = outcome.status.map(\.description) ?? "launchFailed"
  let outputText = outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
  OSUtils.consoleLog(
    "Terminate: reason=\(reason) target=\(processName) killall=\(statusText) output=\(outputText)"
  )
  return outcome.status
}

/// 執行外部程式並取其結束碼與輸出。
///
/// `NSApplication.exec` 只回傳輸出、不檢查結束碼（其 doc 所述之拋錯僅涵蓋「程式沒能啟動」），
/// 故終止流程另用本助手，才能把「`killall` 到底有沒有跑、結果如何」記進日誌。
/// - Parameters:
///   - executable: 可執行檔完整路徑。
///   - args: 參數列。
/// - Returns: 結束碼（`nil` 表示沒能啟動）與標準輸出／標準錯誤之合併內容。
func runProcessCapturingStatus(
  _ executable: String,
  args: [String]
)
  -> (status: Int32?, output: String) {
  let task = Process()
  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = pipe
  task.standardInput = nil
  task.arguments = args
  if #available(macOS 10.13, *) {
    task.executableURL = URL(fileURLWithPath: executable)
  } else {
    task.launchPath = executable
  }
  do {
    if #available(macOS 10.13, *) {
      try task.run()
    } else {
      task.launch()
    }
  } catch {
    return (nil, "")
  }
  // 先讀到 EOF 再 waitUntilExit：反之，輸出量一旦填滿管線緩衝，兩邊會互等而死鎖。
  // 註：安裝器之 legacy 臂的部署目標為 10.9，而 `FileHandle.readToEnd()` 需 10.15.4；
  // 故改用 `availableData` 迴圈逐塊讀到 EOF（該 API 自 10.0 起即有）。
  var data = Data()
  let handle = pipe.fileHandleForReading
  while true {
    let chunk = handle.availableData
    if chunk.isEmpty { break }
    data.append(chunk)
  }
  let output = String(data: data, encoding: .utf8) ?? ""
  task.waitUntilExit()
  return (task.terminationStatus, output)
}
