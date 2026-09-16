// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import UpdateSputnik

/// macOS 10.9 ~ 10.14 不支援 Swift-based MainActor，但這個必須運行在 Main Thread 上。
public final class MainSputnik4IME {
  // MARK: Lifecycle

  public init() {
    // 兩個 `wireUp()` 皆落於 `defaultIsolation(MainActor.self)`（本套件與其上游套件皆然），
    // 而本 init 不可標 `@MainActor`（§5.3 鐵律五：禁為消錯新增 `@MainActor`，會殺死 ≤ macOS 10.14 的相容性）。
    // 本型別依設計「必須運行在 Main Thread 上」（見本檔頂註），故以 `mainSync {}` 表達
    // 「就地於主執行緒執行」——§6.2 允許的調度寫法（Queue 只管觸發時機、任務本體套一圈 `mainSync {}`），
    // 而非 `{ @MainActor in }`。`mainSync` 於 5.10 側之簽名為 `() throws -> T`、
    // 於 6.2 以上為 `@MainActor () throws -> T`（見 `VanguardSwiftExtension/SwiftFoundationImpl.swift`），
    // 故同一則呼叫在兩側皆為合法。
    mainSync {
      SettingsUIHost.wireUp()
      SessionHost.wireUp()
    }
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

  // `async` 所需的 concurrency 執行期起於 macOS 10.15，故標註其可用性下限
  // （與 `InstallerAssembly4Darwin` 的 `MainSputnik4Installer.asyncInit()` 同款處置。
  //   呼叫端為 `Sources/vChewingIME_macOS/Modules/main.swift`，其部署目標為 12+。）
  //
  // 整支再以編譯器世代分流：5.10 側的入口是純同步的 `MainSputnik4IME()`，用不到這一支；留著它只會讓
  // `MainAssembly4Darwin` 的譯文去引用 `swift_task_switch`，把 `@rpath/libswift_Concurrency.dylib`
  // 寫進執行檔的載入記錄——10.9 上並無該執行期。
  #if compiler(>=6.2)
    @available(macOS 10.15, *)
    public static func asyncInit() async -> MainSputnik4IME {
      MainSputnik4IME()
    }
  #endif

  /// `isLegacyDistro` **只認 `@main` 階段（`Sources/vChewingIME_macOS/Modules/main.swift`）在此明示傳入的值**：
  /// 它同時驅動 `UpdateSputnik.isMainStreamRelease` 與 `AppDelegate` 挑選的更新資訊 feed 鍵，
  /// 故不由 bundle ID 之類的線索猜測。
  public func runNSApp(isLegacyDistro: Bool) {
    AppDelegate.shared.isLegacyDistro = isLegacyDistro
    UpdateSputnik.isMainStreamRelease = !isLegacyDistro
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
      case "--dump-prefs-json":
        return Self.dumpPrefsAsJSON()
      case "--import-prefs-json":
        print("vChewing: `--import-prefs-json` needs a file path.")
        return 1
      case "--dump-user-dict":
        LXAssembly.LXFacade.asyncLoadingUserData = false
        LXMgr.initUserLexicons()
        LXMgr.loadUserPhraseReplacement()
        LXMgr.dumpUserDictDataToJSON(print: true, all: false)
        return 0
      case "--dump-user-dict-all":
        LXAssembly.LXFacade.asyncLoadingUserData = false
        LXMgr.initUserLexicons()
        LXMgr.loadUserPhraseReplacement()
        LXMgr.loadUserAssociatesData()
        LXMgr.dumpUserDictDataToJSON(print: true, all: true)
        return 0
      case "--import-kimo":
        let maybeCount: (totalFound: Int, importedCount: Int)?
        do {
          maybeCount = try LXMgr.importYahooKeyKeyUserDictionary()
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
    case 2: return Self.handleTwoArgVarArgs(Array(cmdParameters))
    default: return 0
    }
    return nil
  }

  /// 兩枚引數的 varargs 之處理。自 `handleVarArgs` 析出，以收斂其圈複雜度（SwiftLint 上限 20）。
  private static func handleTwoArgVarArgs(_ cmdParameters: [String]) -> Int32 {
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
        maybeCount = try LXMgr.importYahooKeyKeyUserDictionary(url: url)
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
    case "--import-prefs-json":
      guard let path = cmdParameters.last else { return 1 }
      return Self.importPrefsFromJSON(atPath: path)
    case "--import-standalone-factory-lexicon":
      guard let path = cmdParameters.last else { return 1 }
      return Self.importStandaloneFactoryLexicon(from: path)
    default: break
    }
    return 0
  }

  // MARK: - Preferences JSON Exchange

  /// `--dump-prefs-json`：以**純 JSON** 印出可交換的偏好至標準輸出，故可直接 `> prefs.json`。
  /// 與 `--dump-prefs`（帶註解的 `defaults write` 腳本）互為人／機兩用的對照，且與設定畫面
  /// 「開發者分頁」之 JSON 匯出**同一套**（`UserDef.exportAsJSON()`，共用黑名單與值域驗證）。
  private static func dumpPrefsAsJSON() -> Int32 {
    guard let data = UserDef.exportAsJSON(),
          let jsonString = String(data: data, encoding: .utf8) else {
      print("vChewing: Failed to serialize the preferences into JSON.")
      return 1
    }
    print(jsonString)
    return 0
  }

  /// `--import-prefs-json <path>`：自 JSON 檔案匯入偏好設定。沙盒（本 app 帶
  /// `com.apple.security.app-sandbox`）之下 container 以外的路徑讀不到，故與 `--import-kimo` 同款：
  /// 先試直接讀，讀不到再以 `NSOpenPanel` 請用戶授權（`files.user-selected.read-write`）。
  /// - Returns: 全部獲准寫入則回 0；有任何一筆被拒（未知鍵、黑名單鍵、值域不符）則回 1。
  private static func importPrefsFromJSON(atPath path: String) -> Int32 {
    let sourceURL = URL(fileURLWithPath: path)
    if let data = try? Data(contentsOf: sourceURL) {
      return applyPrefsJSON(data)
    }
    guard let authorizedURL = requestSandboxAccessToJSONFile(suggested: sourceURL) else { return 1 }
    let accessing = authorizedURL.startAccessingSecurityScopedResource()
    defer {
      if accessing { authorizedURL.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: authorizedURL) else {
      print("vChewing: Failed to read the JSON file at: \(authorizedURL.path)")
      return 1
    }
    return applyPrefsJSON(data)
  }

  /// 把已讀入的偏好 JSON 套用進 `UserDefaults`，並印出逐筆結果。
  /// - Returns: 無任何一筆被拒則回 0，否則回 1。
  private static func applyPrefsJSON(_ data: Data) -> Int32 {
    let importResult = UserDef.importFromJSON(data)
    // 與設定畫面之匯入路徑同款收尾（本行程緊接著便 `exit`，故尚需自行把偏好寫回 cfprefsd）。
    PrefMgr.shared.fixOddPreferencesCore()
    UserDefaults.current.synchronize()
    print(
      String(
        format: "i18n:DevZone.JSONPrefsExchange.ImportSummary:%d%d".i18n,
        importResult.successes.count,
        importResult.failures.count
      )
    )
    importResult.failures.forEach { print("⚠ \($0.key): \($0.reason)") }
    return importResult.failures.isEmpty ? 0 : 1
  }

  /// 彈出 `NSOpenPanel` 請用戶授權讀取 JSON 檔（`suggested` 用於預填面板之路徑與檔名）。
  private static func requestSandboxAccessToJSONFile(suggested: URL) -> URL? {
    // `NSOpenPanel` 必須在主執行緒。
    guard Thread.isMainThread else {
      var result: URL?
      DispatchQueue.main.sync { result = requestSandboxAccessToJSONFile(suggested: suggested) }
      return result
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.messageText = "需要檔案存取授權"
    alert.informativeText = """
    vChewing 需要您授權才能讀取指定的偏好設定 JSON 檔案：

    \(suggested.path)

    點選「授權」後，請在接下來的檔案選取視窗中選擇該檔案。
    """
    alert.addButton(withTitle: "授權")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .informational
    guard alert.runModal() == .alertFirstButtonReturn else {
      print("vChewing: User cancelled permission request.")
      return nil
    }

    let panel = NSOpenPanel()
    panel.title = "選擇偏好設定 JSON 檔案以授權存取"
    panel.message = "請選擇先前由 --dump-prefs-json 導出的 .json 檔案。"
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    if #available(macOS 11.0, *) {
      panel.allowedContentTypes = [.json]
    } else {
      panel.allowedFileTypes = ["json"]
    }
    panel.directoryURL = suggested.deletingLastPathComponent()
    panel.nameFieldStringValue = suggested.lastPathComponent
    guard panel.runModal() == .OK, let selectedURL = panel.url else {
      print("vChewing: User cancelled file selection.")
      return nil
    }
    return selectedURL
  }

  // MARK: - Standalone Factory Lexicon Import

  /// 匯入外部獨立工廠辭典檔案。先在沙盒內嘗試直接讀取，若被阻止則彈出 NSOpenPanel 請求用戶授權。
  /// - Parameter sourcePath: 來源 txtMap 檔案路徑
  /// - Returns: exit code (0 = success, 1 = failure)
  private static func importStandaloneFactoryLexicon(from sourcePath: String) -> Int32 {
    let sourceURL = URL(fileURLWithPath: sourcePath)

    // 嘗試直接讀取驗證（若非沙盒環境或檔案已在可存取路徑內）
    if FileManager.default.isReadableFile(atPath: sourcePath) {
      let validation = LXAssembly.LXFacade.validateFactoryTextMapFile(at: sourcePath)
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
    let validation = LXAssembly.LXFacade.validateFactoryTextMapFile(at: selectedURL.path)
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
    let factoryDataDir = LXMgr.appSupportURL.appendingPathComponent("vChewingFactoryData")
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
    SessionControllerSputnik.injectPostConstructionHandler()
    return IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
  }
}
