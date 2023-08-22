// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKUtils
import InputMethodKit
import MainAssembly
import Uninstaller

switch max(CommandLine.arguments.count - 1, 0) {
case 0: break
case 1, 2:
  switch CommandLine.arguments[1] {
  case "install":
    if CommandLine.arguments[1] == "install" {
      let exitCode = IMKHelper.registerInputMethod()
      exit(exitCode)
    }
  case "uninstall":
    if CommandLine.arguments[1] == "uninstall" {
      let exitCode = Uninstaller.uninstall(
        isSudo: NSApplication.isSudoMode, defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true)
      )
      exit(exitCode)
    }
  default: break
  }
  exit(0)
default: exit(0)
}

guard let mainNibName = Bundle.main.infoDictionary?["NSMainNibFile"] as? String else {
  NSLog("vChewingDebug: Fatal error: NSMainNibFile key not defined in Info.plist.")
  exit(-1)
}

let loaded = Bundle.main.loadNibNamed(mainNibName, owner: NSApp, topLevelObjects: nil)
if !loaded {
  NSLog("vChewingDebug: Fatal error: Cannot load \(mainNibName).")
  exit(-1)
}

let kConnectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "org.atelierInmu.inputmethod.vChewing_Connection"

guard let bundleID = Bundle.main.bundleIdentifier,
      let server = IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
else {
  NSLog(
    "vChewingDebug: Fatal error: Cannot initialize input method server with connection name retrieved from the plist, nor there's no connection name in the plist."
  )
  exit(-1)
}

public let theServer = server

NSApplication.shared.delegate = AppDelegate.shared
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
