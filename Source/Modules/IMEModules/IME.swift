// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import InputMethodKit

// The namespace of this input method.
public enum vChewing {}

// The type of input modes.
public enum InputMode: String, CaseIterable {
  case imeModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
  case imeModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
  case imeModeNULL = ""
}

public enum IME {
  static let arrSupportedLocales = ["en", "zh-Hant", "zh-Hans", "ja"]
  static let dlgOpenPath = NSOpenPanel()
  public static let realHomeDir = URL(
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
  )

  // MARK: - vChewing Emacs CharCode-KeyCode translation tables.

  public enum vChewingEmacsKey {
    static let charKeyMapHorizontal: [UInt16: UInt16] = [6: 124, 2: 123, 1: 115, 5: 119, 4: 117, 22: 121]
    static let charKeyMapVertical: [UInt16: UInt16] = [6: 125, 2: 126, 1: 115, 5: 119, 4: 117, 22: 121]
  }

  // MARK: - 瀏覽器 Bundle Identifier 關鍵詞匹配黑名單

  /// 瀏覽器 Bundle Identifier 關鍵詞匹配黑名單，匹配到的瀏覽器會做出特殊的 Shift 鍵擊劍判定處理。
  static let arrClientShiftHandlingExceptionList = [
    "com.avast.browser", "com.brave.Browser", "com.brave.Browser.beta", "com.coccoc.Coccoc", "com.fenrir-inc.Sleipnir",
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.hiddenreflex.Epic",
    "com.maxthon.Maxthon", "com.microsoft.edgemac", "com.microsoft.edgemac.Canary", "com.microsoft.edgemac.Dev",
    "com.naver.Whale", "com.operasoftware.Opera", "com.valvesoftware.steam", "com.vivaldi.Vivaldi",
    "net.qihoo.360browser", "org.blisk.Blisk", "org.chromium.Chromium", "org.qt-project.Qt.QtWebEngineCore",
    "ru.yandex.desktop.yandex-browser",
  ]

  // MARK: - 輸入法的當前的簡繁體中文模式是？

  static var currentInputMode: InputMode = .init(rawValue: mgrPrefs.mostRecentInputMode) ?? .imeModeNULL

  static func kanjiConversionIfRequired(_ text: String) -> String {
    guard currentInputMode == InputMode.imeModeCHT else { return text }
    switch (mgrPrefs.chineseConversionEnabled, mgrPrefs.shiftJISShinjitaiOutputEnabled) {
      case (false, true): return ChineseConverter.cnvTradToJIS(text)
      case (true, false): return ChineseConverter.cnvTradToKangXi(text)
      // 本來這兩個開關不該同時開啟的，但萬一被同時開啟了的話就這樣處理：
      case (true, true): return ChineseConverter.cnvTradToJIS(text)
      case (false, false): return text
    }
  }

  // MARK: - 自 ctlInputMethod 讀取當前輸入法的簡繁體模式

  static func getInputMode(isReversed: Bool = false) -> InputMode {
    if isReversed {
      return (IME.currentInputMode == InputMode.imeModeCHT)
        ? InputMode.imeModeCHS : InputMode.imeModeCHT
    } else {
      return IME.currentInputMode
    }
  }

  // MARK: - Print debug information to the console.

  static func prtDebugIntel(_ strPrint: String) {
    if mgrPrefs.isDebugModeEnabled {
      NSLog("vChewingDebug: %@", strPrint)
    }
  }

  // MARK: - Tell whether this IME is running with Root privileges.

  static var isSudoMode: Bool {
    NSUserName() == "root"
  }

  // MARK: - Initializing Language Models.

  static func initLangModels(userOnly: Bool) {
    mgrLangModel.chkUserLMFilesExist(.imeModeCHT)
    mgrLangModel.chkUserLMFilesExist(.imeModeCHS)
    // mgrLangModel 的 loadUserPhrases 等函式在自動讀取 dataFolderPath 時，
    // 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
    // 所以這裡不需要特別處理。
    if mgrPrefs.associatedPhrasesEnabled {
      mgrLangModel.loadUserAssociatesData()
    }
    if mgrPrefs.phraseReplacementEnabled {
      mgrLangModel.loadUserPhraseReplacement()
    }
    if mgrPrefs.useSCPCTypingMode {
      mgrLangModel.loadUserSCPCSequencesData()
    }
    mgrLangModel.loadUserPhrasesData()
    if !userOnly {
      // mgrLangModel.loadDataModels()
    }
  }

  // MARK: - System Dark Mode Status Detector.

  static var isDarkMode: Bool {
    if #available(macOS 10.15, *) {
      let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription
        .lowercased()
      return appearanceDescription.contains("dark")
    } else if let appleInterfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
      return appleInterfaceStyle.lowercased().contains("dark")
    }
    return false
  }

  // MARK: - Open a phrase data file.

  static func openPhraseFile(fromURL url: URL) {
    openPhraseFile(userFileAt: url.path)
  }

  static func openPhraseFile(userFileAt path: String) {
    func checkIfUserFilesExist() -> Bool {
      if !mgrLangModel.chkUserLMFilesExist(InputMode.imeModeCHS)
        || !mgrLangModel.chkUserLMFilesExist(InputMode.imeModeCHT)
      {
        let content = String(
          format: NSLocalizedString(
            "Please check the permission at \"%@\".", comment: ""
          ),
          mgrLangModel.dataFolderPath(isDefaultFolder: false)
        )
        DispatchQueue.main.async {
          let alert = NSAlert()
          alert.messageText = NSLocalizedString("Unable to create the user phrase file.", comment: "")
          alert.informativeText = content
          alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
          alert.runModal()
          NSApp.setActivationPolicy(.accessory)
        }
        return false
      }
      return true
    }

    if !checkIfUserFilesExist() {
      return
    }
    NSWorkspace.shared.openFile(path, withApplication: "vChewingPhraseEditor")
  }

  // MARK: - Trash a file if it exists.

  @discardableResult static func trashTargetIfExists(_ path: String) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: path) {
        // 塞入垃圾桶
        try FileManager.default.trashItem(
          at: URL(fileURLWithPath: path), resultingItemURL: nil
        )
      } else {
        NSLog("Item doesn't exist: \(path)")
      }
    } catch let error as NSError {
      NSLog("Failed from removing this object: \(path) || Error: \(error)")
      return false
    }
    return true
  }

  // MARK: - Uninstall the input method.

  @discardableResult static func uninstall(isSudo: Bool = false, selfKill: Bool = true) -> Int32 {
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
      : IME.realHomeDir.appendingPathComponent("Library/").path
    let pathIMELibrary =
      isSudo
      ? "/Library/Input Methods"
      : IME.realHomeDir.appendingPathComponent("Library/Input Methods/").path
    let pathUnitKeyboardLayouts = "/Keyboard Layouts"
    let arrKeyLayoutFiles = [
      "/vChewing ETen.keylayout", "/vChewingKeyLayout.bundle", "/vChewing MiTAC.keylayout",
      "/vChewing IBM.keylayout", "/vChewing FakeSeigyou.keylayout",
      "/vChewing Dachen.keylayout",
    ]

    // 先移除各種鍵盤佈局。
    for objPath in arrKeyLayoutFiles {
      let objFullPath = pathLibrary + pathUnitKeyboardLayouts + objPath
      if !IME.trashTargetIfExists(objFullPath) { return -1 }
    }
    if CommandLine.arguments.count > 2, CommandLine.arguments[2] == "--all",
      CommandLine.arguments[1] == "uninstall"
    {
      // 再處理是否需要移除放在預設使用者資料夾內的檔案的情況。
      // 如果使用者有在輸入法偏好設定內將該目錄改到別的地方（而不是用 symbol link）的話，則不處理。
      // 目前暫時無法應對 symbol link 的情況。
      IME.trashTargetIfExists(mgrLangModel.dataFolderPath(isDefaultFolder: true))
      IME.trashTargetIfExists(pathLibrary + "/Preferences/" + bundleID + ".plist")  // 之後移除 App 偏好設定
      IME.trashTargetIfExists(pathLibrary + "/Receipts/org.atelierInmu.vChewing.bom")  // pkg 垃圾
      IME.trashTargetIfExists(pathLibrary + "/Receipts/org.atelierInmu.vChewing.plist")  // pkg 垃圾
    }
    if !IME.trashTargetIfExists(pathIMELibrary + kTargetBundle) { return -1 }  // 最後移除 App 自身
    // 幹掉殘留在記憶體內的執行緒。
    if selfKill {
      NSApplication.shared.terminate(nil)
    }
    return 0
  }
}

// MARK: - Root Extensions

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
extension RangeReplaceableCollection where Element: Hashable {
  var deduplicate: Self {
    var set = Set<Element>()
    return filter { set.insert($0).inserted }
  }
}

// MARK: - String charComponents Extension

extension String {
  public var charComponents: [String] { map { String($0) } }
}

extension Array where Element == String.Element {
  public var charComponents: [String] { map { String($0) } }
}

// MARK: - String Tildes Expansion Extension

extension String {
  public var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}

// MARK: - String Localized Error Extension

extension String: LocalizedError {
  public var errorDescription: String? {
    self
  }
}

// MARK: - Ensuring trailing slash of a string

extension String {
  mutating func ensureTrailingSlash() {
    if !hasSuffix("/") {
      self += "/"
    }
  }
}

// MARK: - CharCode printability check

// Ref: https://forums.swift.org/t/57085/5
extension UniChar {
  public var isPrintable: Bool {
    guard Unicode.Scalar(UInt32(self)) != nil else {
      struct NotAWholeScalar: Error {}
      return false
    }
    return true
  }

  public var isPrintableASCII: Bool {
    (32...126).contains(self)
  }
}

// MARK: - Stable Sort Extension

// Ref: https://stackoverflow.com/a/50545761/4162914
extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  public func stableSort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}

// MARK: - Shell Extension

extension NSApplication {
  public static func shell(_ command: String) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    if #available(macOS 10.13, *) {
      task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    } else {
      task.launchPath = "/bin/zsh"
    }
    task.standardInput = nil

    if #available(macOS 10.13, *) {
      try task.run()
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
  }
}
