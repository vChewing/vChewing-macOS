// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import InputMethodKit

@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
  private func reloadOnFolderChangeHappens() {
    // 拖 100ms 再重載，畢竟有些有特殊需求的使用者可能會想使用巨型自訂語彙檔案。
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
      if mgrPrefs.shouldAutoReloadUserDataFiles {
        IME.initLangModels(userOnly: true)
      }
    }
  }

  // let vChewingKeyLayoutBundle = Bundle.init(path: URL(fileURLWithPath: Bundle.main.resourcePath ?? "").appendingPathComponent("vChewingKeyLayout.bundle").path)

  @IBOutlet var window: NSWindow?
  private var ctlPrefWindowInstance: ctlPrefWindow?
  private var ctlAboutWindowInstance: ctlAboutWindow?  // New About Window
  private var checkTask: URLSessionTask?
  public lazy var folderMonitor = FolderMonitor(
    url: URL(fileURLWithPath: mgrLangModel.dataFolderPath(isDefaultFolder: false))
  )
  private var currentAlertType: String = ""

  func userNotificationCenter(_: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool {
    true
  }

  func applicationDidFinishLaunching(_: Notification) {
    NSUserNotificationCenter.default.delegate = self
    // 一旦發現與使用者半衰模組的觀察行為有關的崩潰標記被開啟，就清空既有的半衰記憶資料檔案。
    if mgrPrefs.failureFlagForUOMObservation {
      mgrLangModel.clearUserOverrideModelData(.imeModeCHS)
      mgrLangModel.clearUserOverrideModelData(.imeModeCHT)
      mgrPrefs.failureFlagForUOMObservation = false
      let userNotification = NSUserNotification()
      userNotification.title = NSLocalizedString("vChewing", comment: "")
      userNotification.informativeText =
        "\(NSLocalizedString("vChewing crashed while handling previously loaded UOM observation data. These data files are cleaned now to ensure the usability.", comment: ""))"
      userNotification.soundName = NSUserNotificationDefaultSoundName
      NSUserNotificationCenter.default.deliver(userNotification)
    }

    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
      IME.initLangModels(userOnly: false)
    }

    folderMonitor.folderDidChange = { [weak self] in
      self?.reloadOnFolderChangeHappens()
    }
    folderMonitor.startMonitoring()

    mgrPrefs.fixOddPreferences()
    mgrPrefs.setMissingDefaults()

    // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
    if mgrPrefs.checkUpdateAutomatically {
      checkForUpdate()
    }
  }

  func updateDirectoryMonitorPath() {
    folderMonitor.stopMonitoring()
    folderMonitor = FolderMonitor(
      url: URL(fileURLWithPath: mgrLangModel.dataFolderPath(isDefaultFolder: false))
    )
    folderMonitor.folderDidChange = { [weak self] in
      self?.reloadOnFolderChangeHappens()
    }
    folderMonitor.startMonitoring()
  }

  func showPreferences() {
    if ctlPrefWindowInstance == nil {
      ctlPrefWindowInstance = ctlPrefWindow.init(windowNibName: "frmPrefWindow")
    }
    ctlPrefWindowInstance?.window?.center()
    ctlPrefWindowInstance?.window?.orderFrontRegardless()  // 逼著屬性視窗往最前方顯示
    ctlPrefWindowInstance?.window?.level = .statusBar
    ctlPrefWindowInstance?.window?.titlebarAppearsTransparent = true
    NSApp.setActivationPolicy(.accessory)
  }

  // New About Window
  func showAbout() {
    if ctlAboutWindowInstance == nil {
      ctlAboutWindowInstance = ctlAboutWindow.init(windowNibName: "frmAboutWindow")
    }
    ctlAboutWindowInstance?.window?.center()
    ctlAboutWindowInstance?.window?.orderFrontRegardless()  // 逼著關於視窗往最前方顯示
    ctlAboutWindowInstance?.window?.level = .statusBar
    NSApp.setActivationPolicy(.accessory)
  }

  func checkForUpdate(forced: Bool = false) {
    if checkTask != nil {
      // busy
      return
    }

    // time for update?
    if !forced {
      if !mgrPrefs.checkUpdateAutomatically {
        return
      }
      let now = Date()
      let date = UserDefaults.standard.object(forKey: VersionUpdateApi.kNextUpdateCheckDateKey) as? Date ?? now
      if now.compare(date) == .orderedAscending {
        return
      }
    }

    let nextUpdateDate = Date(timeInterval: VersionUpdateApi.kNextCheckInterval, since: Date())
    UserDefaults.standard.set(nextUpdateDate, forKey: VersionUpdateApi.kNextUpdateCheckDateKey)

    checkTask = VersionUpdateApi.check(forced: forced) { [self] result in
      defer {
        checkTask = nil
      }
      switch result {
        case .success(let apiResult):
          switch apiResult {
            case .shouldUpdate(let report):
              let content = String(
                format: NSLocalizedString(
                  "You're currently using vChewing %@ (%@), a new version %@ (%@) is now available. Do you want to visit vChewing's website to download the version?%@",
                  comment: ""
                ),
                report.currentShortVersion,
                report.currentVersion,
                report.remoteShortVersion,
                report.remoteVersion,
                report.versionDescription
              )
              IME.prtDebugIntel("vChewingDebug: \(content)")
              let alert = NSAlert()
              alert.messageText = NSLocalizedString("New Version Available", comment: "")
              alert.informativeText = content
              alert.addButton(withTitle: NSLocalizedString("Visit Website", comment: ""))
              alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))
              let result = alert.runModal()
              if result == NSApplication.ModalResponse.alertFirstButtonReturn {
                if let siteURL = report.siteUrl {
                  NSWorkspace.shared.open(siteURL)
                }
              }
              NSApp.setActivationPolicy(.accessory)
            case .noNeedToUpdate, .ignored:
              break
          }
        case .failure(let error):
          switch error {
            case VersionUpdateApiError.connectionError(let message):
              let title = NSLocalizedString("Update Check Failed", comment: "")
              let content = String(
                format: NSLocalizedString(
                  "There may be no internet connection or the server failed to respond.\n\nError message: %@",
                  comment: ""
                ), message
              )
              let buttonTitle = NSLocalizedString("Dismiss", comment: "")
              IME.prtDebugIntel("vChewingDebug: \(content)")

              let alert = NSAlert()
              alert.messageText = title
              alert.informativeText = content
              alert.addButton(withTitle: buttonTitle)
              alert.runModal()
              NSApp.setActivationPolicy(.accessory)
            default:
              break
          }
      }
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
        mgrLangModel.dataFolderPath(isDefaultFolder: true), withApplication: "Finder"
      )
      IME.uninstall(isSudo: false, selfKill: true)
    }
    NSApp.setActivationPolicy(.accessory)
  }

  // New About Window
  @IBAction func about(_: Any) {
    (NSApp.delegate as? AppDelegate)?.showAbout()
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
