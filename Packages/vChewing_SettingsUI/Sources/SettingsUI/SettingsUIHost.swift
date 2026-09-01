// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - SettingsUIHost

/// vChewing_SettingsUI 對宿主（MainAssembly4Darwin）的動作依賴注入點。
///
/// 本套件不得依賴 MainAssembly4Darwin；所有需要宿主服務的動作
/// （LMMgr、SessionUI、AppDelegate、InputSession 等）皆由宿主於啟動時
/// 以 lambda-expression property assignment 的方式注入到 `SettingsUIHost.shared`。
/// 未注入的屬性會保持無操作預設值，讓本套件可獨立於宿主被執行檔 bundle 除錯。
@MainActor
public final class SettingsUIHost {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public static var shared = SettingsUIHost()

  // MARK: - LMMgr 動作依賴

  public var dataFolderPath: (_ isDefaultFolder: Bool) -> String = { _ in "" }
  public var cassettePath: () -> String = { "" }
  public var cassetteAccessFailureDescription: (_ path: String) -> String = { _ in "" }
  public var checkCassettePathValidity: (_ path: String) -> Bool = { _ in false }
  public var checkIfSpecifiedUserDataFolderValid: (_ path: String) -> Bool = { _ in false }
  public var resolveUserSpecifiedURL: (_ url: URL) -> URL = { $0 }
  public var chkUserLMFilesExist: (_ mode: Shared.InputMode) -> Bool = { _ in false }
  public var initUserLangModels: () -> () = {}
  public var connectCoreDB: () -> () = {}
  public var syncLMPrefs: () -> () = {}
  public var loadUserPhraseReplacement: () -> () = {}
  public var loadCassetteData: () -> () = {}
  public var resetCassettePath: () -> () = {}
  public var resetSpecifiedUserDataFolder: () -> () = {}
  public var importCassetteFileToCache: (_ url: URL) -> () = { _ in }
  public var migrateUserDataFrom: (_ oldPath: String, _ newPath: String) -> Int = { _, _ in 0 }
  public var importYahooKeyKeyUserDictionary: (_ url: URL?) throws -> (totalFound: Int, importedCount: Int)
    = { _ in (0, 0) }
  public var retrieveData: (_ mode: Shared.InputMode, _ type: LMAssembly.ReplacableUserDataType) -> String
    = { _, _ in "" }
  public var saveData: (
    _ mode: Shared.InputMode, _ type: LMAssembly.ReplacableUserDataType, _ data: String
  )
    -> String = { _, _, data in data }
  public var tagOverrides: (_ text: inout String, _ mode: Shared.InputMode) -> () = { _, _ in }
  public var openPhraseFile: (
    _ mode: Shared.InputMode, _ type: LMAssembly.ReplacableUserDataType, _ app: FileOpenMethod
  )
    -> () = { _, _, _ in }

  /// 語彙編輯器委派（宿主以 `LMMgr.shared` 注入）。
  public var phraseEditorDelegate: (any PhraseEditorDelegate)?

  // MARK: - SessionUI / AppDelegate / InputSession 動作依賴

  public var resyncShiftKeyUpCheckerSettings: () -> () = {}
  public var updateDirectoryMonitorPath: () -> () = {}
  public var recentClientBundleIdentifiers: () -> [String: Int] = { [:] }

  // MARK: - Notifier 動作依賴

  public var notify: (String) -> () = { _ in }
}
