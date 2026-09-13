// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Foundation
import InputMethodKit

// MARK: - InstallerVMProtocol

// 將協定抽象化，讓針對舊版 macOS（10.9+）的前端實作可以在不引入 SwiftUI 或 Combine 細節的情況下遵從。
protocol InstallerVMProtocol: AnyObject {
  // 狀態需求
  var config: InstallerUIConfig { get set }

  // 實作所需的計時器儲存欄位
  var installRetryTimer: DispatchSourceTimer? { get set }
}

extension InstallerVMProtocol {
  func installationButtonClicked() {
    config.isCancelButtonEnabled = false
    config.isAgreeButtonEnabled = false
    removeThenInstallInputMethod()
  }

  func updateUpgradeableStatus() {
    guard !config.isUpgrading else { return }
    // 判斷是否為升級安裝：掃描所有持相同 InputMethodConnectionName 的已安裝 bundle，
    // 若任一的 build version 比本次要安裝的版本還低，則視為升級。
    let connectionName = installingIMEConnectionName ?? kTISInputSourceID
    let candidateURLs = findAppBundlesWithSameConnectionName(
      as: connectionName, in: urlDestinationPartial
    ) + findAppBundlesWithSameConnectionName(
      as: connectionName, in: URL(fileURLWithPath: "/Library/Input Methods")
    )
    for bundleURL in candidateURLs {
      guard let currentBundle = Bundle(url: bundleURL) else { continue }
      let shortVersion = currentBundle.infoDictionary?["CFBundleShortVersionString"] as? String
      let currentVersion = currentBundle.infoDictionary?[kCFBundleVersionKey as String] as? String
      if shortVersion != nil, let currentVersion = currentVersion,
         currentVersion.compare(installingVersion, options: .numeric) == .orderedAscending {
        config.isUpgrading = true
        return
      }
    }
  }

  func removeThenInstallInputMethod() {
    // 先終止執行中的輸入法程序，避免 bundle 被系統鎖定
    let killTask = Process()
    killTask.launchPath = "/usr/bin/killall"
    killTask.arguments = [kTargetBin]
    killTask.launch()
    killTask.waitUntilExit()

    let killTask2 = Process()
    killTask2.launchPath = "/usr/bin/killall"
    killTask2.arguments = [kTargetBinPhraseEditor]
    killTask2.launch()
    killTask2.waitUntilExit()

    // 取得本次要安裝的 IME 的 InputMethodConnectionName，用於掃描既有安裝
    let connectionName = installingIMEConnectionName ?? kTISInputSourceID
    let fileManager = FileManager.default

    // 掃描 ~/Library/Input Methods，移除所有持相同 connection name 的舊版 App Bundle
    let userMatches = findAppBundlesWithSameConnectionName(
      as: connectionName, in: urlDestinationPartial
    )
    for bundleURL in userMatches {
      moveAppToTrashWithRename(bundleURL, fileManager: fileManager)
    }

    // 掃描 /Library/Input Methods，若有匹配則向使用者索取管理員權限後移除
    let systemDir = URL(fileURLWithPath: "/Library/Input Methods")
    let systemMatches = findAppBundlesWithSameConnectionName(
      as: connectionName, in: systemDir
    )
    if !systemMatches.isEmpty {
      let failedPaths = adminRenameBundles(systemMatches)
      if !failedPaths.isEmpty {
        config.adminRenameFailureAlertPaths = failedPaths
      }
    }

    installInputMethodWithRetry()
  }

  /// 直接開始安裝，並以退避重試因應「舊版 bundle 尚未被系統釋放」之類的暫時性失敗。
  ///
  /// 不預先判斷舊版是否仍被 Gatekeeper 的轉置映像佔用：轉置映像為唯讀，
  /// 寫入該路徑必然失敗，故「複製失敗」本身就是可靠的等待訊號。
  func installInputMethodWithRetry() {
    stopInstallRetryTimer()
    config.timeRemaining = kInstallRetryTimeout
    config.retryDeadline = nil

    // 計時器必須直接建在主佇列上：本 target 採 `defaultIsolation(MainActor.self)`，事件處理器
    // 閉包因此是 MainActor 隔離的；若計時器跑在私有佇列，Swift 執行期會在閉包入口就以
    // `_swift_task_checkIsolatedSwift` → `dispatch_assert_queue` 失敗而 SIGTRAP（閉包本體
    // 根本不會執行，所以「用 main.sync 包住呼叫」也救不了）。安裝流程另會碰 TIS 系列 API，
    // HIToolbox 同樣對呼叫端斷言主佇列，至此兩者一併滿足。
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: kInstallRetryInterval)
    timer.setEventHandler { [weak self] in
      self?.installInputMethod()
    }
    installRetryTimer = timer
    timer.resume()
  }

  func stopInstallRetryTimer() {
    if let timer = installRetryTimer {
      timer.setEventHandler(handler: nil)
      timer.cancel()
      installRetryTimer = nil
    }
  }

  /// 單次安裝嘗試。失敗不報錯，交由 `scheduleInstallRetry()` 排定下一次。
  private func installInputMethod() {
    guard let targetBundle = Bundle.main.path(forResource: kTargetBin, ofType: kTargetType)
    else {
      finishWithAlert(.installationFailed)
      return
    }

    let fileManager = FileManager.default
    let staging = makeStagingURL(inDirectory: urlDestinationPartial, fileManager: fileManager)
    do {
      // 先複製到同目錄的暫名，再原子搬移就位；任一步失敗都視為本次嘗試失敗。
      try fileManager.copyItem(at: URL(fileURLWithPath: targetBundle), to: staging)
      // 舊版已於稍早改名／進垃圾桶；若仍有殘留（例如被系統佔用而未能丟棄），先清掉再就位。
      if fileManager.fileExists(atPath: imeURLInstalled.path) {
        try fileManager.removeItem(at: imeURLInstalled)
      }
      try fileManager.moveItem(at: staging, to: imeURLInstalled)
    } catch {
      try? fileManager.removeItem(at: staging)
      scheduleInstallRetry()
      return
    }

    stopInstallRetryTimer()
    DispatchQueue.main.async { [weak self] in
      self?.config.pendingSheetPresenting = false
    }

    do {
      // 使用 exec 而不是 shell -c，避免將路徑或變數插入到 shell 字串，降低注入風險。
      _ = try NSApplication.exec(
        "/usr/bin/xattr",
        args: ["-drs", "com.apple.quarantine", kTargetPartialPath]
      )
    } catch {
      // 忽略執行錯誤，維持原有行為
    }

    guard let theBundle = Bundle(url: imeURLInstalled),
          let imeIdentifier = theBundle.bundleIdentifier
    else {
      // Bundled IME 缺失時，給出失敗告示。讓使用者自己藉由 UI 結束安裝程式。
      finishWithAlert(.missingAfterRegistration)
      return
    }

    let imeBundleURL = theBundle.bundleURL

    if allRegisteredInstancesOfThisInputMethod.isEmpty {
      Process.consoleLog(
        "Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString)."
      )
      let status = (TISRegisterInputSource(imeBundleURL as CFURL) == noErr)
      if !status {
        // 讓使用者自己藉由 UI 結束安裝程式。
        finishWithAlert(.missingAfterRegistration)
      }

      if allRegisteredInstancesOfThisInputMethod.isEmpty {
        let message = String(
          format: NSLocalizedString(
            "i18n:Installer.CannotFindInputSourceAfterRegistration:%@", comment: ""
          ) + "(#D41J0U8U)",
          imeIdentifier
        )
        Process.consoleLog(message)
      }
    }

    // 結束文字輸入選單的 agent 程序（TextInputMenuAgent）：須在輸入源啟用（register）之前完成，
    // 且 register 得等它結束（無論成敗）後再延後半秒才執行，讓系統重新載入輸入法清單、新裝的
    // 輸入法才會出現在選單中。此程序在舊版 macOS 上可能不存在或尚未啟動，故不檢查 killall 的
    // 結束狀態。
    terminateTextInputSystemAgents()

    // 提示面板（輸入源啟用也在這個主執行緒區塊內完成）：以 asyncAfter 延後半秒，確保
    // TextInputMenuAgent 已經結束、系統也重新載入輸入法清單之後，才執行 register＋結果提示。
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let self = self else { return }

      var mainInputSourceEnabled = false

      allRegisteredInstancesOfThisInputMethod.forEach { neta in
        let isActivated = neta.isActivated
        defer {
          // 如果使用者在升級安裝或再次安裝之前已經有啟用唯音任一簡繁模式的話，則標記安裝成功。
          // 這樣可以尊重某些使用者「僅使用簡體中文」或「僅使用繁體中文」的習慣。
          mainInputSourceEnabled = mainInputSourceEnabled || isActivated
        }
        if isActivated { return }
        // 警告：macOS 12 可能回傳 false positive，因此採取強制啟用。
        if neta.activate() {
          Process.consoleLog("Input method enabled: \(imeIdentifier)")
        } else {
          Process.consoleLog("Failed to enable input method: \(imeIdentifier)")
        }
      }

      let type: InstallerUIConfig.AlertType
      if !self.config.adminRenameFailureAlertPaths.isEmpty {
        type = .adminRenameFailure
      } else if !mainInputSourceEnabled {
        type = .postInstallWarning
      } else {
        type = .postInstallOK
      }
      self.config.currentAlertContent = type
    }
  }

  /// 排定下一次安裝嘗試。首次失敗時才亮出等待面板並記下截止時刻；逾時則放棄。
  private func scheduleInstallRetry() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.config.retryDeadline == nil {
        self.config.retryDeadline = Date().addingTimeInterval(TimeInterval(kInstallRetryTimeout))
        self.config.pendingSheetPresenting = true
      }
      let remaining = self.config.retrySecondsRemaining
      self.config.timeRemaining = remaining
      guard remaining > 0 else {
        self.finishWithAlert(.oldVersionStillInUse)
        return
      }
    }
  }

  /// 收工並指定要顯示的結果面板；等待面板一併關閉。
  private func finishWithAlert(_ type: InstallerUIConfig.AlertType) {
    stopInstallRetryTimer()
    DispatchQueue.main.async { [weak self] in
      self?.config.pendingSheetPresenting = false
      self?.config.currentAlertContent = type
    }
  }

  /// 強制結束文字輸入選單的 agent 程序（TextInputMenuAgent），使其重新載入輸入法清單。
  /// 只針對 TextInputMenuAgent：結束 imklaunchagent 會讓正在接收文字輸入的客體 App 失去
  /// 與所有輸入法的對接、須重啟該客體 App 才會恢復；TextInputSwitcher 只是純 UI 套件、
  /// 結束它沒有意義。此程序在舊版 macOS 上可能不存在或尚未啟動，故不檢查 killall 的結束
  /// 狀態（無論成敗皆返回）。呼叫端應於本方法返回後再延後半秒才執行輸入源啟用（register）。
  private func terminateTextInputSystemAgents() {
    let killTask = Process()
    killTask.launchPath = "/usr/bin/killall"
    killTask.arguments = ["TextInputMenuAgent"]
    killTask.launch()
    killTask.waitUntilExit()
  }
}

// MARK: - 安裝前舊版清除輔助

/// 掃描指定目錄，找出所有 Info.plist 中持相同 InputMethodConnectionName 的 .app bundles。
/// - Parameters:
///   - connectionName: 要比對的 connection name。
///   - directory: 要掃描的目錄 URL。
/// - Returns: 匹配的 App Bundle URL 陣列。
private func findAppBundlesWithSameConnectionName(
  as connectionName: String,
  in directory: URL
)
  -> [URL] {
  let fileManager = FileManager.default
  guard let contents = try? fileManager.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
  ) else { return [] }

  return contents.filter { url in
    url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
  }.filter { url in
    guard let bundle = Bundle(url: url) else { return false }
    let candidate = bundle.infoDictionary?["InputMethodConnectionName"] as? String
      ?? bundle.bundleIdentifier
    return candidate == connectionName
  }
}

/// 將指定的 App Bundle 就地改名（附加 ISO 8601 日期與 .appTrashed 副檔名），
/// 再嘗試丟入垃圾桶。改名後即使 trash 失敗也不再影響後續安裝。
/// 若目標名稱已存在，會自動附加遞增編號以避免碰撞。
/// - Parameters:
///   - fileURL: 要處理的 App Bundle URL。
///   - fileManager: FileManager 實例。
private func moveAppToTrashWithRename(_ fileURL: URL, fileManager: FileManager) {
  do {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
    dateFormatter.timeZone = TimeZone.current
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    let dateSuffix = dateFormatter.string(from: Date())
    let baseName = fileURL.deletingPathExtension().lastPathComponent
    let parentDir = fileURL.deletingLastPathComponent()

    var trashedURL = parentDir.appendingPathComponent(
      "\(baseName)-\(dateSuffix).appTrashed"
    )
    var counter = 1
    while fileManager.fileExists(atPath: trashedURL.path) {
      trashedURL = parentDir.appendingPathComponent(
        "\(baseName)-\(dateSuffix)-\(counter).appTrashed"
      )
      counter += 1
    }

    try fileManager.moveItem(at: fileURL, to: trashedURL)
    // 再嘗試將改名後的檔案丟到垃圾桶（失敗也無妨，已不影響 cp）
    try? fileManager.trashItem(at: trashedURL, resultingItemURL: nil)
  } catch let error as NSError {
    Process.consoleLog("Failed to trash old bundle at \(fileURL.path): \(error)")
  }
}

/// 使用管理員權限對 `/Library/Input Methods` 下的 bundles 進行 rename 操作。
/// 透過 osascript 彈出系統密碼對話框，改名後不再阻擋安裝。
/// 注意：此處僅執行 rename（不實際丟入 user Trash），因為以 root 身份把檔案丟到當前使用者的
/// Trash 需要額外的權限協調；改名成 `.appTrashed` 已可確保該 bundle 不再被系統載入。
/// - Parameter bundleURLs: 待處理的 App Bundle URL 陣列。
/// - Returns: 無法完成 rename 的原始路徑陣列（供安裝後提示使用者手動處理）。
private func adminRenameBundles(_ bundleURLs: [URL]) -> [String] {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
  dateFormatter.timeZone = TimeZone.current
  dateFormatter.locale = Locale(identifier: "en_US_POSIX")
  let dateSuffix = dateFormatter.string(from: Date())

  var shellCommands: [String] = []
  for url in bundleURLs {
    let baseName = url.deletingPathExtension().lastPathComponent
    let parentDir = url.deletingLastPathComponent()

    var newName = "\(baseName)-\(dateSuffix).appTrashed"
    var counter = 1
    while FileManager.default.fileExists(atPath: parentDir.appendingPathComponent(newName).path) {
      newName = "\(baseName)-\(dateSuffix)-\(counter).appTrashed"
      counter += 1
    }

    let escapedOld = shellEscapePath(url.path)
    let escapedNew = shellEscapePath(parentDir.appendingPathComponent(newName).path)
    shellCommands.append("mv \(escapedOld) \(escapedNew)")
  }
  guard !shellCommands.isEmpty else { return [] }

  let shellScript = shellCommands.joined(separator: " && ")
  // 將 shell script 內容正確 escape 後嵌入 AppleScript 字串（避免路徑中的 " 或 \ 破壞 script）
  let appleScriptBody = shellScript
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")

  let task = Process()
  task.launchPath = "/usr/bin/osascript"
  task.arguments = [
    "-e",
    "do shell script \"\(appleScriptBody)\" with administrator privileges",
  ]
  task.launch()
  task.waitUntilExit()

  if task.terminationStatus != 0 {
    // 整個對話框被取消或任一 mv 失敗：保守起見，將所有目標路徑視為需要手動處理
    Process.consoleLog("Admin rename operation failed with status \(task.terminationStatus)")
    return bundleURLs.map(\.path)
  }

  return []
}

/// 以單引號包裹路徑，並將路徑中 embedded 的單引號轉換為 shell-safe 的寫法。
private func shellEscapePath(_ path: String) -> String {
  "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
