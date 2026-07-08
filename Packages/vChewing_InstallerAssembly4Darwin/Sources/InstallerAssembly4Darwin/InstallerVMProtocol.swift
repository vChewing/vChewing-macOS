// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import InputMethodKit

// MARK: - InstallerVMProtocol

// 將協定抽象化，讓針對舊版 macOS（10.9+）的前端實作可以在不引入 SwiftUI 或 Combine 細節的情況下遵從。
protocol InstallerVMProtocol: AnyObject {
  // 狀態需求
  var config: InstallerUIConfig { get set }

  // 實作所需的計時器儲存欄位
  var translocationTimer: DispatchSourceTimer? { get set }

  // DispatchQueue
  var taskQueue: DispatchQueue { get }
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
    let shouldWaitForTranslocationRemoval = Reloc
      .isAppBundleTranslocated(atPath: kTargetPartialPath)

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

    if shouldWaitForTranslocationRemoval {
      DispatchQueue.main.async {
        self.config.pendingSheetPresenting = true
        self.startTranslocationTimer()
      }
    } else {
      installInputMethod(previousExists: false, previousVersionNotFullyDeactivatedWarning: false)
    }
  }

  func startTranslocationTimer() {
    stopTranslocationTimer()

    config.timeRemaining = Int(kTranslocationRemovalDeadline)

    let timer = DispatchSource.makeTimerSource(queue: taskQueue)
    timer.schedule(deadline: .now(), repeating: 1.0)
    timer.setEventHandler { [weak self] in
      guard let self = self else { return }

      // 在背景執行檢查，但在主執行緒更新公開狀態
      if self.config.timeRemaining > 0 {
        if Reloc.isAppBundleTranslocated(atPath: kTargetPartialPath) == false {
          self.stopTranslocationTimer()
          DispatchQueue.main.async {
            self.config.pendingSheetPresenting = false
            self.config.isTranslocationFinished = true
            self.installInputMethod(
              previousExists: true, previousVersionNotFullyDeactivatedWarning: false
            )
          }
        } else {
          DispatchQueue.main.async {
            self.config.timeRemaining -= 1
          }
        }
      } else {
        self.stopTranslocationTimer()
        DispatchQueue.main.async {
          self.config.pendingSheetPresenting = false
          self.config.isTranslocationFinished = false
          self.installInputMethod(
            previousExists: true, previousVersionNotFullyDeactivatedWarning: true
          )
        }
      }
    }
    translocationTimer = timer
    timer.resume()
  }

  func stopTranslocationTimer() {
    if let timer = translocationTimer {
      timer.setEventHandler(handler: nil)
      timer.cancel()
      translocationTimer = nil
    }
  }

  private func installInputMethod(
    previousExists _: Bool, previousVersionNotFullyDeactivatedWarning warning: Bool
  ) {
    guard let targetBundle = Bundle.main.path(forResource: kTargetBin, ofType: kTargetType)
    else {
      return
    }
    let cpTask = Process()
    cpTask.launchPath = "/bin/cp"
    print(kDestinationPartial)
    cpTask.arguments = [
      "-R", targetBundle, kDestinationPartial,
    ]
    cpTask.launch()
    cpTask.waitUntilExit()

    if cpTask.terminationStatus != 0 {
      DispatchQueue.main.async {
        // 讓使用者自己藉由 UI 結束安裝程式。
        self.config.alertItem = InstallerUIConfig.AlertType.installationFailed.makeAlertItem()
      }
      return
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
      DispatchQueue.main.async {
        // Bundled IME 缺失時，給出失敗告示。讓使用者自己藉由 UI 結束安裝程式。
        self.config.alertItem = InstallerUIConfig.AlertType.missingAfterRegistration.makeAlertItem()
      }
      return
    }

    let imeBundleURL = theBundle.bundleURL

    if allRegisteredInstancesOfThisInputMethod.isEmpty {
      Process.consoleLog(
        "Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString)."
      )
      let status = (TISRegisterInputSource(imeBundleURL as CFURL) == noErr)
      if !status {
        DispatchQueue.main.async {
          // 讓使用者自己藉由 UI 結束安裝程式。
          self.config.alertItem = InstallerUIConfig.AlertType.missingAfterRegistration.makeAlertItem()
        }
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

    // 提示面板
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let type: InstallerUIConfig.AlertType
      if !self.config.adminRenameFailureAlertPaths.isEmpty {
        type = .adminRenameFailure
      } else if warning {
        type = .postInstallAttention
      } else if !mainInputSourceEnabled {
        type = .postInstallWarning
      } else {
        type = .postInstallOK
      }
      self.config.currentAlertContent = type
    }
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
