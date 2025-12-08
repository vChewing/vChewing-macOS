// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import InputMethodKit
import MainAssembly

let cmdParameters = CommandLine.arguments.dropFirst(1)

switch cmdParameters.count {
case 0: break
case 1:
  switch cmdParameters.first?.lowercased() {
  case "--dump-prefs":
    if let strDumpedPrefs = PrefMgr.shared.dumpShellScriptBackup() {
      print(strDumpedPrefs)
    }
    exit(0)
  case "--dump-user-dict":
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    LMMgr.initUserLangModels()
    LMMgr.loadUserPhraseReplacement()
    LMMgr.dumpUserDictDataToJSON(print: true, all: false)
    exit(0)
  case "--dump-user-dict-all":
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    LMMgr.initUserLangModels()
    LMMgr.loadUserPhraseReplacement()
    LMMgr.loadUserAssociatesData()
    LMMgr.dumpUserDictDataToJSON(print: true, all: true)
    exit(0)
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
  exit(0)
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
      exit(1)
    }
    let url = URL(fileURLWithPath: path)
    let maybeCount: (totalFound: Int, importedCount: Int)?
    do {
      maybeCount = try LMMgr.importYahooKeyKeyUserDictionary(url: url)
    } catch {
      print(error.localizedDescription)
      exit(1)
    }
    let countResult: (totalFound: Int, importedCount: Int) = maybeCount ?? (0, 0)
    let msg = String(
      format: "i18n:settings.importFromKimoTxt.finishedCount:%@%@".i18n,
      countResult.totalFound.description,
      countResult.importedCount.description
    )
    print("[Kimo Import] \(msg)")
    exit(0)
  default: break
  }
  exit(0)
default: exit(0)
}

guard let mainNibName = Bundle.main.infoDictionary?["NSMainNibFile"] as? String else {
  Process.consoleLog("vChewingDebug: Fatal error: NSMainNibFile key not defined in Info.plist.")
  exit(-1)
}

let loaded = Bundle.main.loadNibNamed(mainNibName, owner: NSApp, topLevelObjects: nil)
if !loaded {
  Process.consoleLog("vChewingDebug: Fatal error: Cannot load \(mainNibName).")
  exit(-1)
}

let kConnectionName = Bundle.main
  .infoDictionary?["InputMethodConnectionName"] as? String ??
  "org.atelierInmu.inputmethod.vChewing_Connection"

guard let bundleID = Bundle.main.bundleIdentifier,
      let server = IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
else {
  Process.consoleLog(
    "vChewingDebug: Fatal error: Cannot initialize input method server with connection name retrieved from the plist, nor there's no connection name in the plist."
  )
  exit(-1)
}

public let theServer = server

NSApplication.shared.delegate = AppDelegate.shared
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
