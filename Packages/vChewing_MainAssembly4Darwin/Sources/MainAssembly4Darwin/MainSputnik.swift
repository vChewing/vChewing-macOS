// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKSwift

/// macOS 10.9 ~ 10.14 不支援 Swift-based MainActor，但這個必須運行在 Main Thread 上。
public final class MainSputnik4IME {
  // MARK: Lifecycle

  public init() {
    if let varArgsResult = Self.handleVarArgs() {
      exit(varArgsResult)
    }
    guard let theServer = Self.handleIMKConnection() else {
      Process.consoleLog(
        "vChewingDebug: Fatal error: Cannot initialize input method server with connection name retrieved from the plist, or there's no connection name in the plist."
      )
      exit(1)
    }
    self.theServer = theServer
  }

  // MARK: Public

  public let theServer: IMKServer

  public static func asyncInit() async -> MainSputnik4IME {
    MainSputnik4IME()
  }

  public func runNSApp() {
    // 下述内容取代 RunLoop.main.run()
    NSApplication.shared.delegate = AppDelegate.shared
    NSApplication.shared.setValue(nil, forKey: "mainWindow") // 輸入法不需要主視窗。
    NSApp.mainMenu = AppDelegate.shared.buildNSAppMainMenu()
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }

  // MARK: Private

  private static func handleVarArgs() -> Int32? {
    let cmdParameters = CommandLine.arguments.dropFirst(1)
    switch cmdParameters.count {
    case 0: break
    case 1:
      switch cmdParameters.first?.lowercased() {
      case "--dump-prefs":
        if let strDumpedPrefs = PrefMgr.shared.dumpShellScriptBackup() {
          print(strDumpedPrefs)
        }
        return 0
      case "--dump-user-dict":
        LMAssembly.LMInstantiator.asyncLoadingUserData = false
        LMMgr.initUserLangModels()
        LMMgr.loadUserPhraseReplacement()
        LMMgr.dumpUserDictDataToJSON(print: true, all: false)
        return 0
      case "--dump-user-dict-all":
        LMAssembly.LMInstantiator.asyncLoadingUserData = false
        LMMgr.initUserLangModels()
        LMMgr.loadUserPhraseReplacement()
        LMMgr.loadUserAssociatesData()
        LMMgr.dumpUserDictDataToJSON(print: true, all: true)
        return 0
      case "--import-kimo":
        let maybeCount: (totalFound: Int, importedCount: Int)?
        do {
          maybeCount = try LMMgr.importYahooKeyKeyUserDictionary()
        } catch {
          print(error.localizedDescription)
          return 1
        }
        let countResult: (totalFound: Int, importedCount: Int) = maybeCount ?? (0, 0)
        let msg = String(
          format: "i18n:settings.importFromKimoTxt.finishedCount:%@%@".i18n,
          countResult.totalFound.description,
          countResult.importedCount.description
        )
        print("[Kimo Import] \(msg)")
        return 0
      case "install":
        let exitCode = IMKHelper.registerInputMethod()
        exit(exitCode)
      case "uninstall":
        Uninstaller.printUninstallCLIGuidance()
        return 1
      default: break
      }
      return 0
    case 2:
      switch cmdParameters.first?.lowercased() {
      case "uninstall" where cmdParameters.last?.lowercased() == "--all":
        Uninstaller.printUninstallCLIGuidance()
        return 1
      case "--import-kimo":
        guard let path = cmdParameters.last else {
          return 1
        }
        let url = URL(fileURLWithPath: path)
        let maybeCount: (totalFound: Int, importedCount: Int)?
        do {
          maybeCount = try LMMgr.importYahooKeyKeyUserDictionary(url: url)
        } catch {
          print(error.localizedDescription)
          return 1
        }
        let countResult: (totalFound: Int, importedCount: Int) = maybeCount ?? (0, 0)
        let msg = String(
          format: "i18n:settings.importFromKimoTxt.finishedCount:%@%@".i18n,
          countResult.totalFound.description,
          countResult.importedCount.description
        )
        print("[Kimo Import] \(msg)")
        return 0
      case "--import-standalone-factory-lexicon":
        guard let path = cmdParameters.last else { return 1 }
        return Self.importStandaloneFactoryLexicon(from: path)
      default: break
      }
      return 0
    default: return 0
    }
    return nil
  }

  // MARK: - Standalone Factory Lexicon Import

  /// 匯入外部獨立工廠辭典檔案。先在沙盒內嘗試直接讀取，若被阻止則彈出 NSOpenPanel 請求用戶授權。
  /// - Parameter sourcePath: 來源 txtMap 檔案路徑
  /// - Returns: exit code (0 = success, 1 = failure)
  private static func importStandaloneFactoryLexicon(from sourcePath: String) -> Int32 {
    let sourceURL = URL(fileURLWithPath: sourcePath)

    // 嘗試直接讀取驗證（若非沙盒環境或檔案已在可存取路徑內）
    if FileManager.default.isReadableFile(atPath: sourcePath) {
      let validation = LMAssembly.LMInstantiator.validateFactoryTextMapFile(at: sourcePath)
      guard validation.isValid else {
        print("vChewing: Factory lexicon validation failed: \(validation.errorDescription ?? "Unknown error")")
        return 1
      }
      return deployFactoryLexicon(from: sourceURL)
    }

    // 沙盒阻止直接讀取，透過 NSOpenPanel 獲取 security-scoped 授權
    return requestSandboxAccessAndImport(sourceURL: sourceURL)
  }

  /// 彈出 NSOpenPanel 請求用戶授予檔案存取權限，然後驗證並部署。
  /// - Parameter sourceURL: 建議的來源檔案 URL（用於預填面板路徑與檔名）
  /// - Returns: exit code
  private static func requestSandboxAccessAndImport(sourceURL: URL) -> Int32 {
    // 確保在 main thread 執行（NSOpenPanel 必須在主執行緒）
    guard Thread.isMainThread else {
      var exitCode: Int32 = 1
      DispatchQueue.main.sync {
        exitCode = requestSandboxAccessAndImport(sourceURL: sourceURL)
      }
      return exitCode
    }

    // 確保 NSApplication 已初始化並啟動
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)

    // Step 1: 提示用戶需要授權
    let alert = NSAlert()
    alert.messageText = "需要檔案存取授權"
    alert.informativeText = """
    vChewing 需要您授權才能讀取指定的工廠辭典檔案：

    \(sourceURL.path)

    點選「授權」後，請在接下來的檔案選取視窗中選擇該檔案。
    """
    alert.addButton(withTitle: "授權")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .informational

    guard alert.runModal() == .alertFirstButtonReturn else {
      print("vChewing: User cancelled permission request.")
      return 1
    }

    // Step 2: 彈出 NSOpenPanel 讓用戶選取檔案以獲取 security-scoped 授權
    let panel = NSOpenPanel()
    panel.title = "選擇工廠辭典檔案以授權存取"
    panel.message = "請選擇 VanguardFactoryDict4Typing.txtMap 檔案。"
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    if #available(macOS 11.0, *) {
      panel.allowedContentTypes = [.init(filenameExtension: "txtMap") ?? .data]
    } else {
      panel.allowedFileTypes = ["txtMap"]
    }
    panel.directoryURL = sourceURL.deletingLastPathComponent()
    panel.nameFieldStringValue = sourceURL.lastPathComponent

    guard panel.runModal() == .OK, let selectedURL = panel.url else {
      print("vChewing: User cancelled file selection.")
      return 1
    }

    // Step 3: 啟用 security-scoped 資源存取
    let accessing = selectedURL.startAccessingSecurityScopedResource()
    defer {
      if accessing {
        selectedURL.stopAccessingSecurityScopedResource()
      }
    }

    // Step 4: 驗證 schema
    let validation = LMAssembly.LMInstantiator.validateFactoryTextMapFile(at: selectedURL.path)
    guard validation.isValid else {
      print("vChewing: Factory lexicon validation failed: \(validation.errorDescription ?? "Unknown error")")
      return 1
    }

    // Step 5: 部署到 container 內
    return deployFactoryLexicon(from: selectedURL)
  }

  /// 將已驗證的 txtMap 檔案拷貝到 vChewingFactoryData 目錄。
  /// - Parameter sourceURL: 來源檔案 URL
  /// - Returns: exit code
  private static func deployFactoryLexicon(from sourceURL: URL) -> Int32 {
    let factoryDataDir = LMMgr.appSupportURL.appendingPathComponent("vChewingFactoryData")
    let destURL = factoryDataDir.appendingPathComponent("VanguardFactoryDict4Typing.txtMap")
    do {
      try FileManager.default.createDirectory(at: factoryDataDir, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: destURL.path) {
        try FileManager.default.removeItem(at: destURL)
      }
      try FileManager.default.copyItem(at: sourceURL, to: destURL)
      print("vChewing: Factory lexicon imported successfully to \(destURL.path)")
      return 0
    } catch {
      print("vChewing: Failed to import factory lexicon: \(error.localizedDescription)")
      return 1
    }
  }

  private static func handleIMKConnection() -> IMKServer? {
    let kConnectionName = Bundle.main
      .infoDictionary?["InputMethodConnectionName"] as? String ??
      "org.atelierInmu.inputmethod.vChewing_Connection"

    guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
    return IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
  }
}
