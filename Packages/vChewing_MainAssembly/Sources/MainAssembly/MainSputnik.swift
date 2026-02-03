// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import InputMethodKit

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
        let exitCode = Uninstaller.uninstall(
          defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true),
          removeAll: false
        )
        exit(exitCode)
      default: break
      }
      return 0
    case 2:
      switch cmdParameters.first?.lowercased() {
      case "uninstall" where cmdParameters.last?.lowercased() == "--all":
        let exitCode = Uninstaller.uninstall(
          defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true),
          removeAll: true
        )
        exit(exitCode)
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
      default: break
      }
      return 0
    default: return 0
    }
    return nil
  }

  private static func handleIMKConnection() -> IMKServer? {
    let kConnectionName = Bundle.main
      .infoDictionary?["InputMethodConnectionName"] as? String ??
      "org.atelierInmu.inputmethod.vChewing_Connection"

    guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
    return IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
  }
}
