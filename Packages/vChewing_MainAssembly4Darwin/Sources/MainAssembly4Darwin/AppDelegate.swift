// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
#if canImport(UserNotifications)
  import UserNotifications
#endif

// MARK: - AppDelegate + UNUserNotificationCenterDelegate

@available(macOS 10.14, *)
extension AppDelegate: UNUserNotificationCenterDelegate {}

// MARK: - AppDelegate + NSUserNotificationCenterDelegate

@available(macOS, deprecated: 10.14)
extension AppDelegate: NSUserNotificationCenterDelegate {
  public func userNotificationCenter(
    _: NSUserNotificationCenter,
    shouldPresent _: NSUserNotification
  )
    -> Bool {
    true
  }
}

// MARK: - AppDelegate

@objc(AppDelegate)
public final class AppDelegate: NSObject, NSApplicationDelegate {
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
      vCLog("[FolderMonitor] User Dictionary data changes detected.")
      if PrefMgr.shared.shouldAutoReloadUserDataFiles || forced { LMMgr.initUserLangModels() }
      asyncOnMain(after: 0.1) {
        if PrefMgr.shared.phraseEditorAutoReloadExternalModifications {
          Broadcaster.shared.postEventForReloadingPhraseEditor()
        }
      }
    }
  }

  /// 在指定時間內暫時忽略使用者資料夾的檔案事件。
  func suppressUserDataMonitor(for interval: TimeInterval) {
    folderMonitor.suppressEvents(for: interval)
  }
}

// MARK: - Public Functions

extension AppDelegate {
  public func applicationWillFinishLaunching(_: Notification) {
    if #available(macOS 10.14, *) {
      UNUserNotificationCenter.current().delegate = self
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .badge],
        completionHandler: { _, _ in }
      )
    } else {
      NSUserNotificationCenter.default.delegate = self
    }

    PrefMgr.shared.fixOddPreferences()

    CandidateTextService.enableFinalSanityCheck()

    // 將不需要阻塞啟動流程的初期化工作延後至下一個 RunLoop 迭代。
    asyncOnMain {
      // 安全代理檢查（行程掃描）與語音引擎預熱無需在啟動瞬間完成。
      SecurityAgentHelper.shared.timer?.fire()
      SpeechSputnik.shared.refreshStatus() // 根據現狀條件決定是否初期化語音引擎。
    }

    // 一旦發現與使用者漸退模組的觀察行為有關的崩潰標記被開啟：
    // 如果有開啟 Debug 模式的話，就將既有的漸退記憶資料檔案更名＋打上當時的時間戳。
    // 如果沒有開啟 Debug 模式的話，則將漸退記憶資料直接清空。
    if PrefMgr.shared.failureFlagForPOMObservation {
      PrefMgr.shared.failureFlagForPOMObservation = false
      asyncOnMain {
        LMMgr.relocateWreckedPOMData()
        if #available(macOS 10.14, *) {
          let msgPackage = UNMutableNotificationContent()
          msgPackage.title = "vChewing".i18n
          msgPackage
            .body =
            "vChewing crashed while handling previously loaded POM observation data. These data files are cleaned now to ensure the usability."
              .i18n
          msgPackage.sound = .defaultCritical
          UNUserNotificationCenter.current().add(
            .init(identifier: "vChewing.notification.pomCrash", content: msgPackage, trigger: nil),
            withCompletionHandler: nil
          )
        } else {
          let userNotification = NSUserNotification()
          userNotification.title = "vChewing".i18n
          userNotification
            .informativeText =
            "vChewing crashed while handling previously loaded POM observation data. These data files are cleaned now to ensure the usability."
              .i18n
          userNotification.soundName = NSUserNotificationDefaultSoundName
          NSUserNotificationCenter.default.deliver(userNotification)
        }
      }
    }

    // 核心辭典連線、磁帶載入、使用者語模初始化：
    // 延後至下一個 RunLoop 迭代以避免阻塞 applicationWillFinishLaunching。
    asyncOnMain { [weak self] in
      LMMgr.connectCoreDB()
      LMMgr.loadCassetteData()
      LMMgr.initUserLangModels()
      guard let this = self else { return }
      this.folderMonitor.folderDidChange = { [weak this] in
        guard let this = this else { return }
        this.reloadOnFolderChangeHappens()
      }
      if LMMgr.userDataFolderExists { this.folderMonitor.startMonitoring() }
    }

    PrefMgr.shared.fixOddPreferences()
  }

  public func applicationWillTerminate(_: Notification) {
    // 確保應用終止時停止所有已啟動的 security-scoped 資源
    BookmarkManager.shared.stopAllSecurityScopedAccesses()
  }

  public func updateDirectoryMonitorPath() {
    folderMonitor.stopMonitoring()
    folderMonitor = FolderMonitor(
      url: URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    )
    folderMonitor.folderDidChange = { [weak self] in
      guard let this = self else { return }
      this.reloadOnFolderChangeHappens()
    }
    if LMMgr.userDataFolderExists { // 沒有資料夾的話，FolderMonitor 會崩潰。
      folderMonitor.startMonitoring()
      reloadOnFolderChangeHappens(forced: true)
    }
  }

  public func selfUninstall() {
    let content = String(
      format: "This will remove vChewing Input Method from this user account, requiring your confirmation.".i18n
    )
    let alert = NSAlert()
    alert.messageText = "Uninstallation".i18n
    alert.informativeText = content
    alert.addButton(withTitle: "OK".i18n)
    if #available(macOS 11, *) {
      alert.buttons.forEach { button in
        button.hasDestructiveAction = true
      }
    }
    alert.addButton(withTitle: "Not Now".i18n)
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
      let title = "vChewing".i18n
      let body =
        "vChewing is rebooted due to a memory-excessive-usage problem. If convenient, please inform the developer that you are having this issue, stating whether you are using an Intel Mac or Apple Silicon Mac. An NSLog is generated with the current memory footprint size."
          .i18n
      if #available(macOS 10.14, *) {
        let msgPackage = UNMutableNotificationContent()
        msgPackage.title = title
        msgPackage.body = body
        UNUserNotificationCenter.current().add(
          .init(
            identifier: "vChewing.notification.memoryExcessiveUsage",
            content: msgPackage, trigger: nil
          ),
          withCompletionHandler: nil
        )
      } else {
        let userNotification = NSUserNotification()
        userNotification.title = title
        userNotification.informativeText = body
        NSUserNotificationCenter.default.deliver(userNotification)
      }
      asyncOnMain(after: 0.3) {
        NSApp.terminate(self)
      }
    default: break
    }
    return currentMemorySize
  }

  /// 以此取代 `MainMenu.xib`。
  public func buildNSAppMainMenu() -> NSMenu {
    NSMenu(title: "MainMenu").appendItems {
      NSMenu.buildSubMenu(verbatim: "vChewing") {
        NSMenu.Item("About vChewing")?
          .act(#selector(about(_:)))
          .withTarget(self)
        NSMenu.Item.separator()
        NSMenu.Item("Close")?
          .act(#selector(NSWindow.performClose(_:)))
          .hotkey("w", mask: [.command])
      }

      NSMenu.buildSubMenu(verbatim: "Edit") {
        NSMenu.Item("Undo")?
          .act(#selector(UndoManager.undo))
          .hotkey("z", mask: [.command])
        NSMenu.Item("Redo")?
          .act(#selector(UndoManager.redo))
          .hotkey("Z", mask: [.command, .shift])
        NSMenu.Item.separator()
        NSMenu.Item("Cut")?
          .act(#selector(NSText.cut(_:)))
          .hotkey("x", mask: [.command])
        NSMenu.Item("Copy")?
          .act(#selector(NSText.copy(_:)))
          .hotkey("c", mask: [.command])
        NSMenu.Item("Paste")?
          .act(#selector(NSText.paste(_:)))
          .hotkey("v", mask: [.command])
        NSMenu.Item("Select All")?
          .act(#selector(NSText.selectAll(_:)))
          .hotkey("a", mask: [.command])
        NSMenu.Item.separator()
      }
    }
  }

  // New About Window
  @IBAction
  public func about(_: Any) {
    CtlAboutUI.show()
    NSApp.popup()
  }
}
