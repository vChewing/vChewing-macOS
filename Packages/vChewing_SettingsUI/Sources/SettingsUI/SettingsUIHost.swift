// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - SettingsUIHost

/// vChewing_SettingsUI 對宿主（MainAssembly4Darwin）的動作依賴注入點。
///
/// 本套件不得依賴 MainAssembly4Darwin；所有需要宿主服務的動作
/// （LXMgr、SessionUI、AppDelegate、InputSession 等）皆由宿主於啟動時
/// 以 lambda-expression property assignment 的方式注入到 `SettingsUIHost.shared`。
/// 未注入的屬性會保持無操作預設值，讓本套件可獨立於宿主被執行檔 bundle 除錯。
///
/// 註：不在此標註 `@MainActor`（legacy 倉的同名檔案亦然）。6.2 以上側由 21 份 manifest 的
/// `defaultIsolation(MainActor.self)` 提供同一隔離，語義不變；5.10 側無該設定，顯式標註只會讓
/// 非隔離呼叫端（例如 `MainSputnik4IME.init()`）被 5.10 判為錯誤——那正是 legacy 不標的理由。
public final class SettingsUIHost {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public static var shared = SettingsUIHost()

  // MARK: - LXMgr 動作依賴

  public var dataFolderPath: (_ isDefaultFolder: Bool) -> String = { _ in "" }
  public var cassettePath: () -> String = { "" }
  public var cassetteAccessFailureDescription: (_ path: String) -> String = { _ in "" }
  public var checkCassettePathValidity: (_ path: String) -> Bool = { _ in false }
  public var checkIfSpecifiedUserDataFolderValid: (_ path: String) -> Bool = { _ in false }
  public var resolveUserSpecifiedURL: (_ url: URL) -> URL = { $0 }
  public var chkUserLMFilesExist: (_ mode: Shared.InputMode) -> Bool = { _ in false }
  public var initUserLexicons: () -> () = {}
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
  public var retrieveData: (_ mode: Shared.InputMode, _ type: LXAssembly.ReplacableUserDataType) -> String
    = { _, _ in "" }
  public var saveData: (
    _ mode: Shared.InputMode, _ type: LXAssembly.ReplacableUserDataType, _ data: String
  )
    -> String = { _, _, data in data }
  public var tagOverrides: (_ text: inout String, _ mode: Shared.InputMode) -> () = { _, _ in }
  public var openPhraseFile: (
    _ mode: Shared.InputMode, _ type: LXAssembly.ReplacableUserDataType, _ app: FileOpenMethod
  )
    -> () = { _, _, _ in }

  /// 語彙編輯器委派之延遲供應器（宿主注入 `{ LXMgr.shared }`）。
  /// 刻意不以值直接注入：`phraseEditorDelegate` 只在詞彙編輯頁（GUI）被使用，
  /// 沒有必要在程序啟動階段就實體化 `LXMgr.shared`（連帶提早武裝其 KVO 路徑失效觀察器）。
  public var phraseEditorDelegateProvider: (() -> (any PhraseEditorDelegate)?)?

  // MARK: - SessionUI / AppDelegate / InputSession 動作依賴

  public var resyncShiftKeyUpCheckerSettings: () -> () = {}
  public var updateDirectoryMonitorPath: () -> () = {}
  public var recentClientBundleIdentifiers: () -> [String: Int] = { [:] }

  // MARK: - Notifier 動作依賴

  public var notify: (String) -> () = { _ in }

  /// 語彙編輯器委派。首次被讀取（詞彙編輯頁開啟）時才經由供應器解析。
  public var phraseEditorDelegate: (any PhraseEditorDelegate)? { phraseEditorDelegateProvider?() }
}
