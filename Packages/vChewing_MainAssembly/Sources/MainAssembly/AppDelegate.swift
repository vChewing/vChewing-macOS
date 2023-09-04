// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import FolderMonitor
import Shared
import Uninstaller
import UpdateSputnik

@objc(AppDelegate)
public class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
  public static let shared = AppDelegate()
  private var folderMonitor = FolderMonitor(
    url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
  )

  public static var updateInfoSourceURL: URL? {
    guard let urlText = Bundle.main.infoDictionary?["UpdateInfoEndpoint"] as? String else {
      NSLog("vChewingDebug: Fatal error: Info.plist wrecked. It needs to have correct 'UpdateInfoEndpoint' value.")
      return nil
    }
    return .init(string: urlText)
  }

  public func checkUpdate(forced: Bool) {
    guard let url = Self.updateInfoSourceURL else { return }
    UpdateSputnik.shared.checkForUpdate(forced: forced, url: url)
  }
}

// MARK: - Private Functions

extension AppDelegate {
  private func reloadOnFolderChangeHappens(forced: Bool = true) {
    // 拖 100ms 再重載，畢竟有些有特殊需求的使用者可能會想使用巨型自訂語彙檔案。
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
      // forced 用於剛剛切換了辭典檔案目錄的場合。
      // 先執行 initUserLangModels() 可以在目標辭典檔案不存在的情況下先行生成空白範本檔案。
      if PrefMgr.shared.shouldAutoReloadUserDataFiles || forced { LMMgr.initUserLangModels() }
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if #available(macOS 10.15, *) { FileObserveProject.shared.touch() }
        if PrefMgr.shared.phraseEditorAutoReloadExternalModifications {
          Broadcaster.shared.eventForReloadingPhraseEditor = .init()
        }
      }
    }
  }
}

// MARK: - Public Functions

public extension AppDelegate {
  func userNotificationCenter(_: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool {
    true
  }

  func applicationWillFinishLaunching(_: Notification) {
    NSUserNotificationCenter.default.delegate = self
    PrefMgr.shared.fixOddPreferences()

    // 一旦發現與使用者半衰模組的觀察行為有關的崩潰標記被開啟：
    // 如果有開啟 Debug 模式的話，就將既有的半衰記憶資料檔案更名＋打上當時的時間戳。
    // 如果沒有開啟 Debug 模式的話，則將半衰記憶資料直接清空。
    if PrefMgr.shared.failureFlagForUOMObservation {
      LMMgr.relocateWreckedUOMData()
      PrefMgr.shared.failureFlagForUOMObservation = false
      let userNotification = NSUserNotification()
      userNotification.title = NSLocalizedString("vChewing", comment: "")
      userNotification.informativeText = NSLocalizedString(
        "vChewing crashed while handling previously loaded UOM observation data. These data files are cleaned now to ensure the usability.",
        comment: ""
      )
      userNotification.soundName = NSUserNotificationDefaultSoundName
      NSUserNotificationCenter.default.deliver(userNotification)
    }

    if !PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
    LMMgr.loadCassetteData()
    LMMgr.initUserLangModels()
    folderMonitor.folderDidChange = { [weak self] in
      guard let self = self else { return }
      reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists { folderMonitor.startMonitoring() }

    // 只要使用者沒有勾選檢查更新、沒有主動做出要檢查更新的操作，就不要檢查更新。
    if PrefMgr.shared.checkUpdateAutomatically {
      checkUpdate(forced: false)
    }
  }

  func updateDirectoryMonitorPath() {
    folderMonitor.stopMonitoring()
    folderMonitor = FolderMonitor(
      url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    )
    folderMonitor.folderDidChange = { [weak self] in
      guard let self = self else { return }
      reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists { // 沒有資料夾的話，FolderMonitor 會崩潰。
      folderMonitor.startMonitoring()
      reloadOnFolderChangeHappens(forced: true)
    }
  }

  func selfUninstall() {
    let content = String(
      format: NSLocalizedString(
        "This will remove vChewing Input Method from this user account, requiring your confirmation.",
        comment: ""
      ))
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
    if result == NSApplication.ModalResponse.alertFirstButtonReturn {
      NSWorkspace.shared.openFile(
        LMMgr.dataFolderPath(isDefaultFolder: true), withApplication: "Finder"
      )
      Uninstaller.uninstall(
        isSudo: false, selfKill: true, defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true)
      )
    }
  }

  /// 檢查該程式本身的記憶體佔用量。
  /// - Returns: 記憶體佔用量（MiB）。
  @discardableResult func checkMemoryUsage() -> Double {
    guard let currentMemorySizeInBytes = NSApplication.memoryFootprint else { return 0 }
    let currentMemorySize: Double = (Double(currentMemorySizeInBytes) / 1024 / 1024).rounded(toPlaces: 1)
    switch currentMemorySize {
    case 512...:
      vCLog("WARNING: EXCESSIVE MEMORY FOOTPRINT (\(currentMemorySize)MB).")
      let userNotification = NSUserNotification()
      userNotification.title = NSLocalizedString("vChewing", comment: "")
      userNotification.informativeText = NSLocalizedString(
        "vChewing is rebooted due to a memory-excessive-usage problem. If convenient, please inform the developer that you are having this issue, stating whether you are using an Intel Mac or Apple Silicon Mac. An NSLog is generated with the current memory footprint size.",
        comment: ""
      )
      NSUserNotificationCenter.default.deliver(userNotification)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        NSApp.terminate(self)
      }
    default: break
    }
    return currentMemorySize
  }
}
