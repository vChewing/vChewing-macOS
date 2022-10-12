// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import CocoaExtension

public enum Uninstaller {
  // MARK: - Uninstall the input method.

  @discardableResult public static func uninstall(
    isSudo: Bool = false, selfKill: Bool = true, defaultDataFolderPath: String
  ) -> Int32 {
    let realHomeDir = URL(
      fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
    )
    // 輸入法自毀處理。這裡不用「Bundle.main.bundleURL」是為了方便使用者以 sudo 身分來移除被錯誤安裝到系統目錄內的輸入法。
    guard let bundleID = Bundle.main.bundleIdentifier else {
      NSLog("Failed to ensure the bundle identifier.")
      return -1
    }

    // 自威注音 v2.3.0 開始，沙箱限制了威注音的某些行為，所以該函式不再受理 sudo 模式下的操作。
    if isSudo {
      print(
        "vChewing binary does not support sudo-uninstall since v2.3.0. Please use the bundled uninstall.sh instead.\n\nIf you want to fix the installation (i.e. removing all incorrectly installed files outside of the current user folder), please use the bundled fixinstall.sh instead.\n\nIf you don't know how to proceed, please bring either the uninstall.sh / install.sh or the instruction article https://vchewing.github.io/UNINSTALL.html to Apple Support (support.apple.com) for help. Their senior advisors can understand these uninstall instructions."
      )
      return -1
    }

    let kTargetBundle = "/vChewing.app"
    let pathLibrary =
      isSudo
      ? "/Library"
      : realHomeDir.appendingPathComponent("Library/").path
    let pathIMELibrary =
      isSudo
      ? "/Library/Input Methods"
      : realHomeDir.appendingPathComponent("Library/Input Methods/").path
    let pathUnitKeyboardLayouts = "/Keyboard Layouts"
    let arrKeyLayoutFiles = [
      "/vChewing ETen.keylayout", "/vChewingKeyLayout.bundle", "/vChewing MiTAC.keylayout",
      "/vChewing IBM.keylayout", "/vChewing FakeSeigyou.keylayout",
      "/vChewing Dachen.keylayout",
    ]

    // 先移除各種鍵盤佈局。
    for objPath in arrKeyLayoutFiles {
      let objFullPath = pathLibrary + pathUnitKeyboardLayouts + objPath
      if !FileManager.trashTargetIfExists(objFullPath) { return -1 }
    }
    if CommandLine.arguments.count > 2, CommandLine.arguments[2] == "--all",
      CommandLine.arguments[1] == "uninstall"
    {
      // 再處理是否需要移除放在預設使用者資料夾內的檔案的情況。
      // 如果使用者有在輸入法偏好設定內將該目錄改到別的地方（而不是用 symbol link）的話，則不處理。
      // 目前暫時無法應對 symbol link 的情況。
      FileManager.trashTargetIfExists(defaultDataFolderPath)
      FileManager.trashTargetIfExists(pathLibrary + "/Preferences/" + bundleID + ".plist")  // 之後移除 App 偏好設定
      FileManager.trashTargetIfExists(pathLibrary + "/Receipts/org.atelierInmu.vChewing.bom")  // pkg 垃圾
      FileManager.trashTargetIfExists(pathLibrary + "/Receipts/org.atelierInmu.vChewing.plist")  // pkg 垃圾
    }
    if !FileManager.trashTargetIfExists(pathIMELibrary + kTargetBundle) { return -1 }  // 最後移除 App 自身
    // 幹掉殘留在記憶體內的執行緒。
    if selfKill {
      NSApp.terminate(nil)
    }
    return 0
  }
}
