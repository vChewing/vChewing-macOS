// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKUtils
import InputMethodKit
import SwiftExtension

extension MainView {
  public func removeThenInstallInputMethod() {
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
      pendingSheetPresenting = true
    } else {
      installInputMethod(
        previousExists: false, previousVersionNotFullyDeactivatedWarning: false
      )
    }
  }

  public func installInputMethod(
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
      isShowingAlertForFailedInstallation = true
      NSApp.terminateWithDelay()
    }

    _ = try? NSApp.shell("/usr/bin/xattr -drs com.apple.quarantine \(kTargetPartialPath)")

    guard let theBundle = Bundle(url: imeURLInstalled),
          let imeIdentifier = theBundle.bundleIdentifier
    else {
      NSApp.terminateWithDelay()
      return
    }

    let imeBundleURL = theBundle.bundleURL

    if allRegisteredInstancesOfThisInputMethod.isEmpty {
      Process.consoleLog(
        "Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString)."
      )
      let status = (TISRegisterInputSource(imeBundleURL as CFURL) == noErr)
      if !status {
        isShowingAlertForMissingPostInstall = true
        NSApp.terminateWithDelay()
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
      // WARNING: macOS 12 may return false positives, hence forced activation.
      if neta.activate() {
        Process.consoleLog("Input method enabled: \(imeIdentifier)")
      } else {
        Process.consoleLog("Failed to enable input method: \(imeIdentifier)")
      }
    }

    // Alert Panel
    if warning {
      currentAlertContent = .postInstallAttention
    } else if !mainInputSourceEnabled {
      currentAlertContent = .postInstallWarning
    } else {
      currentAlertContent = .postInstallOK
    }
    isShowingPostInstallNotification = true
    NSApp.terminateWithDelay()
  }
}
