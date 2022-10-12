// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import FolderMonitor
import Uninstaller
import UpdateSputnik

@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
  private func reloadOnFolderChangeHappens() {
    // 拖 100ms 再重載，畢竟有些有特殊需求的使用者可能會想使用巨型自訂語彙檔案。
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
      if PrefMgr.shared.shouldAutoReloadUserDataFiles {
        LMMgr.initUserLangModels()
      }
    }
  }

  public let updateSputnik = UpdateSputnik()
  public var folderMonitor = FolderMonitor(
    url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
  )
  private var currentAlertType: String = ""

  func userNotificationCenter(_: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool {
    true
  }

  func applicationDidFinishLaunching(_: Notification) {
    NSUserNotificationCenter.default.delegate = self
    // 一旦發現與使用者半衰模組的觀察行為有關的崩潰標記被開啟，就清空既有的半衰記憶資料檔案。
    if PrefMgr.shared.failureFlagForUOMObservation {
      LMMgr.clearUserOverrideModelData(.imeModeCHS)
      LMMgr.clearUserOverrideModelData(.imeModeCHT)
      PrefMgr.shared.failureFlagForUOMObservation = false
      let userNotification = NSUserNotification()
      userNotification.title = NSLocalizedString("vChewing", comment: "")
      userNotification.informativeText =
        "\(NSLocalizedString("vChewing crashed while handling previously loaded UOM observation data. These data files are cleaned now to ensure the usability.", comment: ""))"
      userNotification.soundName = NSUserNotificationDefaultSoundName
      NSUserNotificationCenter.default.deliver(userNotification)
    }

    if !PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
    DispatchQueue.main.async {
      LMMgr.initUserLangModels()
      self.folderMonitor.folderDidChange = { [weak self] in
        self?.reloadOnFolderChangeHappens()
      }
      if LMMgr.userDataFolderExists {
        self.folderMonitor.startMonitoring()
      }
    }

    PrefMgr.shared.fixOddPreferences()

    // 配置更新小助手
    updateSputnik.varkUpdateInfoPageURLKey = "UpdateInfoSite"
    updateSputnik.varkUpdateCheckDateKeyPrevious = "PreviousUpdateCheckDate"
    updateSputnik.varkUpdateCheckDateKeyNext = "NextUpdateCheckDate"
    updateSputnik.varkUpdateCheckInterval = 114_514
    updateSputnik.varCheckUpdateAutomatically = "ChecvarkUpdateAutomatically"

    // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
    if PrefMgr.shared.checkUpdateAutomatically {
      updateSputnik.checkForUpdate(forced: false, url: kUpdateInfoSourceURL)
    }
  }

  func updateDirectoryMonitorPath() {
    folderMonitor.stopMonitoring()
    folderMonitor = FolderMonitor(
      url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    )
    folderMonitor.folderDidChange = { [weak self] in
      self?.reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists {
      folderMonitor.startMonitoring()
    }
  }

  func selfUninstall() {
    currentAlertType = "Uninstall"
    let content = String(
      format: NSLocalizedString(
        "This will remove vChewing Input Method from this user account, requiring your confirmation.",
        comment: ""
      ))
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Uninstallation", comment: "")
    alert.informativeText = content
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))
    let result = alert.runModal()
    if result == NSApplication.ModalResponse.alertFirstButtonReturn {
      NSWorkspace.shared.openFile(
        LMMgr.dataFolderPath(isDefaultFolder: true), withApplication: "Finder"
      )
      Uninstaller.uninstall(
        isSudo: false, selfKill: true, defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true)
      )
    }
    NSApp.setActivationPolicy(.accessory)
  }

  // New About Window
  @IBAction func about(_: Any) {
    CtlAboutWindow.show()
    NSApp.activate(ignoringOtherApps: true)
  }
}
