// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Carbon
import Cocoa

// The namespace of this input method.
public enum vChewing {}

// The type of input modes.
public enum InputMode: String {
  case imeModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
  case imeModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
  case imeModeNULL = ""
}

public enum IME {
  static let arrSupportedLocales = ["en", "zh-Hant", "zh-Hans", "ja"]
  static let dlgOpenPath = NSOpenPanel()

  // MARK: - 輸入法的當前的簡繁體中文模式是？

  static var currentInputMode: InputMode = .init(rawValue: mgrPrefs.mostRecentInputMode) ?? .imeModeNULL

  static func kanjiConversionIfRequired(_ text: String) -> String {
    if currentInputMode == InputMode.imeModeCHT {
      switch (mgrPrefs.chineseConversionEnabled, mgrPrefs.shiftJISShinjitaiOutputEnabled) {
        case (false, true): return ChineseConverter.cnvTradToJIS(text)
        case (true, false): return ChineseConverter.cnvTradToKangXi(text)
        // 本來這兩個開關不該同時開啟的，但萬一被同時開啟了的話就這樣處理：
        case (true, true): return ChineseConverter.cnvTradToJIS(text)
        case (false, false): return text
      }
    }
    return text
  }

  // MARK: - 開關判定當前應用究竟是？

  static var areWeUsingOurOwnPhraseEditor: Bool = false

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
    mgrLangModel.loadUserAssociatesData()
    mgrLangModel.loadUserPhraseReplacement()
    mgrLangModel.loadUserPhrasesData()
    if !userOnly {
      // mgrLangModel.loadDataModels()
    }
  }

  // MARK: - System Dark Mode Status Detector.

  static func isDarkMode() -> Bool {
    if #available(macOS 10.15, *) {
      let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription
        .lowercased()
      if appearanceDescription.contains("dark") {
        return true
      }
    } else if #available(macOS 10.14, *) {
      if let appleInterfaceStyle = UserDefaults.standard.object(forKey: "AppleInterfaceStyle")
        as? String
      {
        if appleInterfaceStyle.lowercased().contains("dark") {
          return true
        }
      }
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
        ctlNonModalAlertWindow.shared.show(
          title: NSLocalizedString("Unable to create the user phrase file.", comment: ""),
          content: content, confirmButtonTitle: NSLocalizedString("OK", comment: ""),
          cancelButtonTitle: nil, cancelAsDefault: false, delegate: nil
        )
        NSApp.setActivationPolicy(.accessory)
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

    let kTargetBin = "vChewing"
    let kTargetBundle = "/vChewing.app"
    let pathLibrary =
      isSudo
      ? "/Library"
      : FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path
    let pathIMELibrary =
      isSudo
      ? "/Library/Input Methods"
      : FileManager.default.urls(for: .inputMethodsDirectory, in: .userDomainMask)[0].path
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
    }
    if !IME.trashTargetIfExists(pathIMELibrary + kTargetBundle) { return -1 }  // 最後移除 App 自身
    // 幹掉殘留在記憶體內的執行緒。
    if selfKill {
      let killTask = Process()
      killTask.launchPath = "/usr/bin/killall"
      killTask.arguments = ["-9", kTargetBin]
      killTask.launch()
      killTask.waitUntilExit()
    }
    return 0
  }

  // MARK: - Registering the input method.

  @discardableResult static func registerInputMethod() -> Int32 {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      return -1
    }
    let bundleUrl = Bundle.main.bundleURL
    var maybeInputSource = InputSourceHelper.inputSource(for: bundleID)

    if maybeInputSource == nil {
      NSLog("Registering input source \(bundleID) at \(bundleUrl.absoluteString)")
      // then register
      let status = InputSourceHelper.registerTnputSource(at: bundleUrl)

      if !status {
        NSLog(
          "Fatal error: Cannot register input source \(bundleID) at \(bundleUrl.absoluteString)."
        )
        return -1
      }

      maybeInputSource = InputSourceHelper.inputSource(for: bundleID)
    }

    guard let inputSource = maybeInputSource else {
      NSLog("Fatal error: Cannot find input source \(bundleID) after registration.")
      return -1
    }

    if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
      NSLog("Enabling input source \(bundleID) at \(bundleUrl.absoluteString).")
      let status = InputSourceHelper.enable(inputSource: inputSource)
      if !status {
        NSLog("Fatal error: Cannot enable input source \(bundleID).")
        return -1
      }
      if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
        NSLog("Fatal error: Cannot enable input source \(bundleID).")
        return -1
      }
    }

    if CommandLine.arguments.count > 2, CommandLine.arguments[2] == "--all" {
      let enabled = InputSourceHelper.enableAllInputMode(for: bundleID)
      NSLog(
        enabled
          ? "All input sources enabled for \(bundleID)"
          : "Cannot enable all input sources for \(bundleID), but this is ignored")
    }
    return 0
  }

  // MARK: - 準備枚舉系統內所有的 ASCII 鍵盤佈局

  struct CarbonKeyboardLayout {
    var strName: String = ""
    var strValue: String = ""
  }

  static let arrWhitelistedKeyLayoutsASCII: [String] = [
    "com.apple.keylayout.ABC",
    "com.apple.keylayout.ABC-AZERTY",
    "com.apple.keylayout.ABC-QWERTZ",
    "com.apple.keylayout.British",
    "com.apple.keylayout.Colemak",
    "com.apple.keylayout.Dvorak",
    "com.apple.keylayout.Dvorak-Left",
    "com.apple.keylayout.DVORAK-QWERTYCMD",
    "com.apple.keylayout.Dvorak-Right",
  ]
  static var arrEnumerateSystemKeyboardLayouts: [IME.CarbonKeyboardLayout] {
    // 提前塞入 macOS 內建的兩款動態鍵盤佈局
    var arrKeyLayouts: [IME.CarbonKeyboardLayout] = []
    arrKeyLayouts += [
      IME.CarbonKeyboardLayout(
        strName: NSLocalizedString("Apple Chewing - Dachen", comment: ""),
        strValue: "com.apple.keylayout.ZhuyinBopomofo"
      ),
      IME.CarbonKeyboardLayout(
        strName: NSLocalizedString("Apple Chewing - Eten Traditional", comment: ""),
        strValue: "com.apple.keylayout.ZhuyinEten"
      ),
    ]

    // 準備枚舉系統內所有的 ASCII 鍵盤佈局
    var arrKeyLayoutsMACV: [IME.CarbonKeyboardLayout] = []
    var arrKeyLayoutsASCII: [IME.CarbonKeyboardLayout] = []
    let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
    for source in list {
      if let ptrCategory = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) {
        let category = Unmanaged<CFString>.fromOpaque(ptrCategory).takeUnretainedValue()
        if category != kTISCategoryKeyboardInputSource {
          continue
        }
      } else {
        continue
      }

      if let ptrASCIICapable = TISGetInputSourceProperty(
        source, kTISPropertyInputSourceIsASCIICapable
      ) {
        let asciiCapable = Unmanaged<CFBoolean>.fromOpaque(ptrASCIICapable)
          .takeUnretainedValue()
        if asciiCapable != kCFBooleanTrue {
          continue
        }
      } else {
        continue
      }

      if let ptrSourceType = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) {
        let sourceType = Unmanaged<CFString>.fromOpaque(ptrSourceType).takeUnretainedValue()
        if sourceType != kTISTypeKeyboardLayout {
          continue
        }
      } else {
        continue
      }

      guard let ptrSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
        let localizedNamePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
      else {
        continue
      }

      let sourceID = String(Unmanaged<CFString>.fromOpaque(ptrSourceID).takeUnretainedValue())
      let localizedName = String(
        Unmanaged<CFString>.fromOpaque(localizedNamePtr).takeUnretainedValue())

      if sourceID.contains("vChewing") {
        arrKeyLayoutsMACV += [
          IME.CarbonKeyboardLayout(strName: localizedName, strValue: sourceID)
        ]
      }

      if IME.arrWhitelistedKeyLayoutsASCII.contains(sourceID) {
        arrKeyLayoutsASCII += [
          IME.CarbonKeyboardLayout(strName: localizedName, strValue: sourceID)
        ]
      }
    }
    arrKeyLayouts += arrKeyLayoutsMACV
    arrKeyLayouts += arrKeyLayoutsASCII
    return arrKeyLayouts
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
