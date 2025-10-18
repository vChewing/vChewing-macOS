// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import UserNotifications

// MARK: - AppDelegate

@objc(AppDelegate)
public class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  // MARK: Public

  public static let shared = AppDelegate()

  public static var updateInfoSourceURL: URL? {
    guard let urlText = Bundle.main.infoDictionary?["UpdateInfoEndpoint"] as? String else {
      vCLog(
        forced: true,
        "vChewingDebug: Fatal error: Info.plist wrecked. It needs to have correct 'UpdateInfoEndpoint' value."
      )
      return nil
    }
    return .init(string: urlText)
  }

  public func checkUpdate(forced: Bool, shouldBypass: @escaping () -> Bool) {
    guard let url = Self.updateInfoSourceURL else { return }
    UpdateSputnik.shared.checkForUpdate(forced: forced, url: url) { shouldBypass() }
  }

  // MARK: Private

  private var folderMonitor = FolderMonitor(
    url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
  )
}

// MARK: - Private Functions

extension AppDelegate {
  private func reloadOnFolderChangeHappens(forced: Bool = true) {
    // 拖 100ms 再重載，畢竟有些有特殊需求的使用者可能會想使用巨型自訂語彙檔案。
    asyncOnMain(after: 0.1) {
      // forced 用於剛剛切換了辭典檔案目錄的場合。
      // 先執行 initUserLangModels() 可以在目標辭典檔案不存在的情況下先行生成空白範本檔案。
      if PrefMgr.shared.shouldAutoReloadUserDataFiles || forced { LMMgr.initUserLangModels() }
      asyncOnMain(after: 0.1) {
        if PrefMgr.shared.phraseEditorAutoReloadExternalModifications {
          Broadcaster.shared.eventForReloadingPhraseEditor = .init()
        }
      }
    }
  }
}

// MARK: - Public Functions

extension AppDelegate {
  public func applicationWillFinishLaunching(_: Notification) {
    UNUserNotificationCenter.current().delegate = self

    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge],
      completionHandler: { _, _ in }
    )

    PrefMgr.shared.fixOddPreferences()

    SecurityAgentHelper.shared.timer?.fire()

    SpeechSputnik.shared.refreshStatus() // 根據現狀條件決定是否初期化語音引擎。

    CandidateTextService.enableFinalSanityCheck()

    // 一旦發現與使用者漸退模組的觀察行為有關的崩潰標記被開啟：
    // 如果有開啟 Debug 模式的話，就將既有的漸退記憶資料檔案更名＋打上當時的時間戳。
    // 如果沒有開啟 Debug 模式的話，則將漸退記憶資料直接清空。
    if PrefMgr.shared.failureFlagForPOMObservation {
      LMMgr.relocateWreckedPOMData()
      PrefMgr.shared.failureFlagForPOMObservation = false
      let msgPackage = UNMutableNotificationContent()
      msgPackage.title = NSLocalizedString("vChewing", comment: "")
      msgPackage.body = NSLocalizedString(
        "vChewing crashed while handling previously loaded POM observation data. These data files are cleaned now to ensure the usability.",
        comment: ""
      )
      msgPackage.sound = .defaultCritical
      UNUserNotificationCenter.current().add(
        .init(identifier: "vChewing.notification.pomCrash", content: msgPackage, trigger: nil),
        withCompletionHandler: nil
      )
    }

    LMMgr.connectCoreDB()
    LMMgr.loadCassetteData()
    LMMgr.initUserLangModels()
    folderMonitor.folderDidChange = { [weak self] in
      guard let self = self else { return }
      self.reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists { folderMonitor.startMonitoring() }
  }

  public func updateDirectoryMonitorPath() {
    folderMonitor.stopMonitoring()
    folderMonitor = FolderMonitor(
      url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    )
    folderMonitor.folderDidChange = { [weak self] in
      guard let self = self else { return }
      self.reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists { // 沒有資料夾的話，FolderMonitor 會崩潰。
      folderMonitor.startMonitoring()
      reloadOnFolderChangeHappens(forced: true)
    }
  }

  public func selfUninstall() {
    let content = String(
      format: NSLocalizedString(
        "This will remove vChewing Input Method from this user account, requiring your confirmation.",
        comment: ""
      )
    )
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Uninstallation", comment: "")
    alert.informativeText = content
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    if #available(macOS 11, *) {
      alert.buttons.forEach { button in
        button.hasDestructiveAction = true
      }
    }
    alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))
    let result = alert.runModal()
    NSApp.popup()
    guard result == NSApplication.ModalResponse.alertFirstButtonReturn else { return }
    let url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: true))
    FileOpenMethod.finder.open(url: url)
    Uninstaller.uninstall(
      selfKill: true, defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true)
    )
  }

  /// 檢查該程式本身的記憶體佔用量。
  /// - Returns: 記憶體佔用量（MiB）。
  @discardableResult
  public func checkMemoryUsage() -> Double {
    guard let currentMemorySizeInBytes = NSApplication.memoryFootprint else { return 0 }
    let currentMemorySize: Double = (Double(currentMemorySizeInBytes) / 1_024 / 1_024)
      .rounded(toPlaces: 1)
    switch currentMemorySize {
    case 1_024...:
      vCLog("WARNING: EXCESSIVE MEMORY FOOTPRINT (\(currentMemorySize)MB).")
      let msgPackage = UNMutableNotificationContent()
      msgPackage.title = NSLocalizedString("vChewing", comment: "")
      msgPackage.body = NSLocalizedString(
        "vChewing is rebooted due to a memory-excessive-usage problem. If convenient, please inform the developer that you are having this issue, stating whether you are using an Intel Mac or Apple Silicon Mac. An NSLog is generated with the current memory footprint size.",
        comment: ""
      )
      UNUserNotificationCenter.current().add(
        .init(
          identifier: "vChewing.notification.memoryExcessiveUsage",
          content: msgPackage, trigger: nil
        ),
        withCompletionHandler: nil
      )
      asyncOnMain(after: 0.3) {
        NSApp.terminate(self)
      }
    default: break
    }
    return currentMemorySize
  }

  // New About Window
  @IBAction
  public func about(_: Any) {
    CtlAboutUI.show()
    NSApp.popup()
  }
}
