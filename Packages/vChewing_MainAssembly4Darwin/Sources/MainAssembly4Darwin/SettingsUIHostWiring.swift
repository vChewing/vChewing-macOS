// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - SettingsUIHost 動作依賴注入

extension SettingsUIHost {
  /// 由宿主（MainAssembly4Darwin）於啟動時呼叫，將 vChewing_SettingsUI 套件
  /// 所需的宿主服務（LXMgr、SessionUI、AppDelegate、InputSession）注入。
  public static func wireUp() {
    let host = SettingsUIHost.shared
    // LXMgr 動作依賴。
    host.dataFolderPath = { LXMgr.dataFolderPath(isDefaultFolder: $0) }
    host.cassettePath = { LXMgr.cassettePath() }
    host.cassetteAccessFailureDescription = { LXMgr.cassetteAccessFailureDescription(path: $0) }
    host.checkCassettePathValidity = { LXMgr.checkCassettePathValidity($0) }
    host.checkIfSpecifiedUserDataFolderValid = { LXMgr.checkIfSpecifiedUserDataFolderValid($0) }
    host.resolveUserSpecifiedURL = { LXMgr.resolveUserSpecifiedURL($0) }
    host.chkUserLMFilesExist = { LXMgr.chkUserLMFilesExist($0) }
    host.initUserLexicons = { LXMgr.initUserLexicons() }
    host.connectCoreDB = { LXMgr.connectCoreDB() }
    host.syncLMPrefs = { LXMgr.syncLMPrefs() }
    host.loadUserPhraseReplacement = { LXMgr.loadUserPhraseReplacement() }
    host.loadCassetteData = { LXMgr.loadCassetteData() }
    host.resetCassettePath = { LXMgr.resetCassettePath() }
    host.resetSpecifiedUserDataFolder = { LXMgr.resetSpecifiedUserDataFolder() }
    host.importCassetteFileToCache = { LXMgr.importCassetteFileToCache(from: $0) }
    host.migrateUserDataFrom = { LXMgr.migrateUserDataFrom(oldPath: $0, to: $1) }
    host.importYahooKeyKeyUserDictionary = { url in
      try LXMgr.importYahooKeyKeyUserDictionary(url: url)
    }
    host.retrieveData = { LXMgr.retrieveData(mode: $0, type: $1) }
    host.saveData = { LXMgr.saveData(mode: $0, type: $1, data: $2) }
    host.tagOverrides = { text, mode in
      LXMgr.shared.tagOverrides(in: &text, mode: mode)
    }
    host.openPhraseFile = { mode, type, app in
      LXMgr.shared.openPhraseFile(mode: mode, type: type, using: app)
    }
    // 以 provider 延遲注入：LXMgr.shared 僅在詞彙編輯頁真正開啟時才實體化，
    // 避免程序啟動階段就武裝其 KVO 路徑失效觀察器。
    host.phraseEditorDelegateProvider = { LXMgr.shared }
    // SessionUI / AppDelegate / InputSession 動作依賴。
    host.resyncShiftKeyUpCheckerSettings = { SessionUI.shared.resyncShiftKeyUpCheckerSettings() }
    host.updateDirectoryMonitorPath = { AppDelegate.shared.updateDirectoryMonitorPath() }
    host.recentClientBundleIdentifiers = { InputSession.recentClientBundleIdentifiers }
    // Notifier 動作依賴。
    host.notify = { Notifier.notify(message: $0) }
    // PrefMgr 單例剩餘的 didSet 回呼（涉及 LXMgr 與 SessionUI 者）。
    PrefMgr.shared.didAskForSyncingLMPrefs = {
      if PrefMgr.shared.phraseReplacementEnabled {
        LXMgr.loadUserPhraseReplacement()
      }
      if PrefMgr.shared.associatedPhrasesEnabled {
        LXMgr.loadUserAssociatesData()
      }
      LXMgr.syncLMPrefs()
    }
    PrefMgr.shared.didAskForSyncingShiftKeyDetectorPrefs = {
      SessionUI.shared.resyncShiftKeyUpCheckerSettings()
    }
  }
}
