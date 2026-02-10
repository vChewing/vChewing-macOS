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
    // 判斷是否為升級安裝（檢查已安裝的套件版本）
    if FileManager.default.fileExists(atPath: kTargetPartialPath) {
      let currentBundle = Bundle(path: kTargetPartialPath)
      let shortVersion = currentBundle?.infoDictionary?["CFBundleShortVersionString"] as? String
      let currentVersion = currentBundle?.infoDictionary?[kCFBundleVersionKey as String] as? String
      if shortVersion != nil, let currentVersion = currentVersion,
         currentVersion.compare(installingVersion, options: .numeric) == .orderedAscending {
        config.isUpgrading = true
      }
    }
  }

  func removeThenInstallInputMethod() {
    let shouldWaitForTranslocationRemoval = Reloc
      .isAppBundleTranslocated(atPath: kTargetPartialPath)

    // 將既存輸入法扔到垃圾桶內
    do {
      let sourceDir = kDestinationPartial
      let fileManager = FileManager.default
      let fileURLString = sourceDir + "/" + kTargetBundle
      let fileURL = URL(fileURLWithPath: fileURLString)

      // 檢查檔案是否存在
      if fileManager.fileExists(atPath: fileURLString) {
        // 塞入垃圾桶
        try fileManager.trashItem(at: fileURL, resultingItemURL: nil)
      } else {
        Process.consoleLog("File does not exist")
      }

    } catch let error as NSError {
      Process.consoleLog("An error took place: \(error)")
    }

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
        self.config.isShowingAlertForFailedInstallation = true
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
        self.config.isShowingAlertForMissingPostInstall = true
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
          self.config.isShowingAlertForMissingPostInstall = true
        }
      }

      if allRegisteredInstancesOfThisInputMethod.isEmpty {
        let message = String(
          format: NSLocalizedString(
            "Cannot find input source %@ after registration.", comment: ""
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
      if warning {
        self.config.currentAlertContent = .postInstallAttention
      } else if !mainInputSourceEnabled {
        self.config.currentAlertContent = .postInstallWarning
      } else {
        self.config.currentAlertContent = .postInstallOK
      }
      // 讓使用者自己藉由 UI 結束安裝程式。
      self.config.isShowingPostInstallNotification = true
    }
  }
}
