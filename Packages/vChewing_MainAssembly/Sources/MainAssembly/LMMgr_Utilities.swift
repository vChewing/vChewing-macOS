// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import BookmarkManager
import LangModelAssembly
import Shared
import SwiftExtension

/// 使用者辭典資料預設範例檔案名稱。
private let kTemplateNameUserPhrases = "template-userphrases"
private let kTemplateNameUserReplacements = "template-replacements"
private let kTemplateNameUserFilterList = "template-exclusions"
private let kTemplateNameUserSymbolPhrases = "template-usersymbolphrases"
private let kTemplateNameUserAssociatesCHS = "template-associatedPhrases-chs"
private let kTemplateNameUserAssociatesCHT = "template-associatedPhrases-cht"

public extension LMMgr {
  // MARK: - 獲取原廠核心語彙檔案資料所在路徑（優先獲取 Containers 下的資料檔案）。

  // 該函式目前僅供步天歌繁簡轉換引擎使用，並不會檢查目標檔案格式的實際可用性。

  static func getBundleDataPath(_ filenameSansExt: String, factory: Bool = false, ext: String) -> String {
    let factory = PrefMgr.shared.useExternalFactoryDict ? factory : true
    let factoryPath = Bundle.main.path(forResource: filenameSansExt, ofType: ext)!
    let containerPath = Self.appSupportURL.appendingPathComponent("vChewingFactoryData/\(filenameSansExt).\(ext)").path
      .expandingTildeInPath
    var isFailed = false
    if !factory {
      var isFolder = ObjCBool(false)
      if !FileManager.default.fileExists(atPath: containerPath, isDirectory: &isFolder) { isFailed = true }
      if !isFailed, !FileManager.default.isReadableFile(atPath: containerPath) { isFailed = true }
    }
    let result = (factory || isFailed) ? factoryPath : containerPath
    return result
  }

  // MARK: - 獲取原廠核心語彙檔案資料本身（優先獲取 Containers 下的資料檔案），可能會出 nil。

  static func getDictionaryData(_ filenameSansExt: String, factory: Bool = false) -> (
    dict: [String: [String]]?, path: String
  ) {
    let factory = PrefMgr.shared.useExternalFactoryDict ? factory : true
    let factoryResultURL = Bundle.main.url(forResource: filenameSansExt, withExtension: "json")
    let containerResultURL = Self.appSupportURL.appendingPathComponent("vChewingFactoryData/\(filenameSansExt).json")
    var lastReadPath = factoryResultURL?.path ?? "Factory file missing: \(filenameSansExt).json"

    func getJSONData(url: URL?) -> [String: [String]]? {
      var isFailed = false
      var isFolder = ObjCBool(false)
      guard let url = url else {
        vCLog("URL Invalid.")
        return nil
      }
      defer { lastReadPath = url.path }
      if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) { isFailed = true }
      if !isFailed, !FileManager.default.isReadableFile(atPath: url.path) { isFailed = true }
      if isFailed {
        vCLog("↑ Exception happened when reading json file at: \(url.path).")
        return nil
      }
      do {
        let rawData = try Data(contentsOf: url)
        return try? JSONSerialization.jsonObject(with: rawData) as? [String: [String]]
      } catch {
        return nil
      }
    }

    let result =
      factory
        ? getJSONData(url: factoryResultURL)
        : getJSONData(url: containerResultURL) ?? getJSONData(url: factoryResultURL)
    if result == nil {
      vCLog("↑ Exception happened when reading json file at: \(lastReadPath).")
    }
    return (dict: result, path: lastReadPath)
  }

  // MARK: - 使用者語彙檔案的具體檔案名稱路徑定義

  // Swift 的 appendingPathComponent 需要藉由 URL 完成。

  /// 指定的使用者辭典資料路徑。
  /// - Parameters:
  ///   - mode: 繁簡模式。
  ///   - type: 辭典資料類型
  /// - Returns: 資料路徑（URL）。
  static func userDictDataURL(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> URL {
    var fileName: String = {
      switch type {
      case .thePhrases: return "userdata"
      case .theFilter: return "exclude-phrases"
      case .theReplacements: return "phrases-replacement"
      case .theAssociates: return "associatedPhrases"
      case .theSymbols: return "usersymbolphrases"
      }
    }()
    fileName.append((mode == .imeModeCHT) ? "-cht.txt" : "-chs.txt")
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者逐字選字模式候選字詞順序資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userSCPCSequencesURL(_ mode: Shared.InputMode) -> URL {
    let fileName = (mode == .imeModeCHT) ? "data-plain-bpmf-cht.plist" : "data-plain-bpmf-chs.plist"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者波浪符號選單資料路徑。
  /// - Returns: 資料路徑（URL）。
  static func userSymbolMenuDataURL() -> URL {
    let fileName = "symbols.dat"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者半衰記憶模組資料的存取頻次特別高，且資料新陳代謝速度快，所以只適合放在預設的使用者資料目錄下。
  /// 也就是「~/Library/Application Support/vChewing/」目錄下，且不會隨著使用者辭典目錄的改變而改變。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userOverrideModelDataURL(_ mode: Shared.InputMode) -> URL {
    let fileName: String = {
      switch mode {
      case .imeModeCHS: return "vChewing_override-model-data-chs.dat"
      case .imeModeCHT: return "vChewing_override-model-data-cht.dat"
      case .imeModeNULL: return "vChewing_override-model-data-dummy.dat"
      }
    }()

    return URL(
      fileURLWithPath: dataFolderPath(isDefaultFolder: true)
    ).deletingLastPathComponent().appendingPathComponent(fileName)
  }

  // MARK: - 使用者語彙檔案專用目錄的合規性檢查

  // 一次性檢查給定的目錄是否存在寫入合規性（僅用於偏好設定檢查等初步檢查場合，不做任何糾偏行為）
  static func checkIfSpecifiedUserDataFolderValid(_ folderPath: String?) -> Bool {
    var isFolder = ObjCBool(false)
    let folderExist = FileManager.default.fileExists(atPath: folderPath ?? "", isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "folderExist".

    // 路徑沒有結尾斜槓的話，會導致目錄合規性判定失準。
    // 出於每個型別每個函式的自我責任原則，這裡多檢查一遍也不壞。
    var folderPath = folderPath // Convert the incoming constant to a variable.
    if isFolder.boolValue {
      folderPath?.ensureTrailingSlash()
    }
    let isFolderWritable = FileManager.default.isWritableFile(atPath: folderPath ?? "")
    // vCLog("mgrLM: Exist: \(folderExist), IsFolder: \(isFolder.boolValue), isWritable: \(isFolderWritable)")
    if ((folderExist && !isFolder.boolValue) || !folderExist) || !isFolderWritable {
      return false
    }
    return true
  }

  // 檢查給定的磁帶目錄是否存在讀入合規性、且是否為指定格式。
  static func checkCassettePathValidity(_ cassettePath: String?) -> Bool {
    var isFolder = ObjCBool(true)
    let isExist = FileManager.default.fileExists(atPath: cassettePath ?? "", isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "isExist".
    let isReadable = FileManager.default.isReadableFile(atPath: cassettePath ?? "")
    return !isFolder.boolValue && isExist && isReadable
  }

  // 檢查給定的目錄是否存在寫入合規性、且糾偏，不接受任何傳入變數。
  static var userDataFolderExists: Bool {
    let folderPath = Self.dataFolderPath(isDefaultFolder: false)
    var isFolder = ObjCBool(false)
    var folderExist = FileManager.default.fileExists(atPath: folderPath, isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "folderExist".
    // 發現目標路徑不是目錄的話：
    // 如果要找的目標路徑是原廠目標路徑的話，先將這個路徑的所指對象更名、再認為目錄不存在。
    // 如果要找的目標路徑不是原廠目標路徑的話，則直接報錯。
    if folderExist, !isFolder.boolValue {
      do {
        if dataFolderPath(isDefaultFolder: false)
          == dataFolderPath(isDefaultFolder: true)
        {
          let formatter = DateFormatter()
          formatter.dateFormat = "YYYYMMDD-HHMM'Hrs'-ss's'"
          let dirAlternative = folderPath + formatter.string(from: Date())
          try FileManager.default.moveItem(atPath: folderPath, toPath: dirAlternative)
        } else {
          throw folderPath
        }
      } catch {
        print("Failed to make path available at: \(error)")
        return false
      }
      folderExist = false
    }
    if !folderExist {
      do {
        try FileManager.default.createDirectory(
          atPath: folderPath,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        print("Failed to create folder: \(error)")
        return false
      }
    }
    return true
  }

  // MARK: - 用以讀取使用者語彙檔案目錄的函式，會自動對 PrefMgr 當中的參數糾偏。

  // 當且僅當 PrefMgr 當中的參數不合規（比如非實在路徑、或者無權限寫入）時，才會糾偏。

  static let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

  static func dataFolderPath(isDefaultFolder: Bool) -> String {
    var userDictPathSpecified = PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath
    var userDictPathDefault =
      Self.appSupportURL.appendingPathComponent("vChewing").path.expandingTildeInPath

    userDictPathDefault.ensureTrailingSlash()
    userDictPathSpecified.ensureTrailingSlash()

    if (userDictPathSpecified == userDictPathDefault)
      || isDefaultFolder
    {
      return userDictPathDefault
    }
    if UserDefaults.standard.object(forKey: UserDef.kUserDataFolderSpecified.rawValue) != nil {
      BookmarkManager.shared.loadBookmarks()
      if Self.checkIfSpecifiedUserDataFolderValid(userDictPathSpecified) {
        return userDictPathSpecified
      }
      UserDefaults.standard.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    }
    return userDictPathDefault
  }

  static func cassettePath() -> String {
    let rawCassettePath = PrefMgr.shared.cassettePath
    if UserDefaults.standard.object(forKey: UserDef.kCassettePath.rawValue) != nil {
      BookmarkManager.shared.loadBookmarks()
      if Self.checkCassettePathValidity(rawCassettePath) { return rawCassettePath }
      UserDefaults.standard.removeObject(forKey: UserDef.kCassettePath.rawValue)
    }
    return ""
  }

  // MARK: - 重設使用者語彙檔案目錄

  static func resetSpecifiedUserDataFolder() {
    UserDefaults.standard.set(dataFolderPath(isDefaultFolder: true), forKey: UserDef.kUserDataFolderSpecified.rawValue)
    Self.initUserLangModels()
  }

  static func resetCassettePath() {
    UserDefaults.standard.set("", forKey: UserDef.kCassettePath.rawValue)
    Self.loadCassetteData()
  }

  // MARK: - 寫入使用者檔案

  static func writeUserPhrasesAtOnce(
    _ userPhrase: UserPhrase, areWeFiltering: Bool,
    errorHandler: (() -> Void)? = nil
  ) {
    let resultA = userPhrase.write(toFilter: areWeFiltering)
    let resultB = userPhrase.crossConverted.write(toFilter: areWeFiltering)
    guard resultA, resultB else {
      if let errorHandler = errorHandler {
        errorHandler()
      }
      return
    }
    // The new FolderMonitor module does NOT monitor cases that files are modified
    // by the current application itself, requiring additional manual loading process here.
    if #available(macOS 10.15, *) { FileObserveProject.shared.touch() }
    if PrefMgr.shared.phraseEditorAutoReloadExternalModifications {
      Broadcaster.shared.eventForReloadingPhraseEditor = .init()
    }
    loadUserPhrasesData(type: .thePhrases)
  }

  // MARK: - 藉由語彙編輯器開啟使用者檔案

  private static func checkIfUserFilesExistBeforeOpening() -> Bool {
    if !Self.chkUserLMFilesExist(.imeModeCHS)
      || !Self.chkUserLMFilesExist(.imeModeCHT)
    {
      let content = String(
        format: NSLocalizedString(
          "Please check the permission at \"%@\".", comment: ""
        ),
        Self.dataFolderPath(isDefaultFolder: false)
      )
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Unable to create the user phrase file.", comment: "")
        alert.informativeText = content
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
        NSApp.popup()
      }
      return false
    }
    return true
  }

  static func openUserDictFile(type: vChewingLM.ReplacableUserDataType, dual: Bool = false, alt: Bool) {
    let app: String = alt ? "" : "Finder"
    openPhraseFile(fromURL: userDictDataURL(mode: IMEApp.currentInputMode, type: type), app: app)
    guard dual else { return }
    openPhraseFile(fromURL: userDictDataURL(mode: IMEApp.currentInputMode.reversed, type: type), app: app)
  }

  /// 用指定應用開啟指定檔案。
  /// - Remark: 如果你的 App 有 Sandbox 處理過的話，請勿給 app 傳入 "vim" 參數，因為 Sandbox 會阻止之。
  /// - Parameters:
  ///   - url: 檔案 URL。
  ///   - app: 指定 App 應用的 binary 檔案名稱。
  static func openPhraseFile(fromURL url: URL, app: String = "") {
    if !Self.checkIfUserFilesExistBeforeOpening() { return }
    DispatchQueue.main.async {
      switch app {
      case "vim":
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh/")
        process.arguments = ["-c", "open '/usr/bin/vim'", "'\(url.path)'"]
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { process in
          vCLog("\ndidFinish: \(!process.isRunning)")
        }
        let fileHandle = pipe.fileHandleForReading
        do {
          try process.run()
        } catch {
          NSWorkspace.shared.openFile(url.path, withApplication: "TextEdit")
        }
        do {
          if let theData = try fileHandle.readToEnd(),
             let outStr = String(data: theData, encoding: .utf8)
          {
            vCLog(outStr)
          }
        } catch {}
      case "Finder":
        NSWorkspace.shared.activateFileViewerSelecting([url])
      default:
        if !NSWorkspace.shared.openFile(url.path, withApplication: app) {
          NSWorkspace.shared.openFile(url.path, withApplication: "TextEdit")
        }
      }
    }
  }

  // MARK: - 檢查具體的使用者語彙檔案是否存在

  private static func ensureFileExists(
    _ fileURL: URL, deployTemplate templateBasename: String = "1145141919810",
    extension ext: String = "txt"
  ) -> Bool {
    let filePath = fileURL.path
    if !FileManager.default.fileExists(atPath: filePath) {
      let templateURL = Bundle.main.url(forResource: templateBasename, withExtension: ext)
      var templateData = Data("".utf8)
      if templateBasename != "" {
        do {
          try templateData = Data(contentsOf: templateURL ?? URL(fileURLWithPath: ""))
        } catch {
          templateData = Data("".utf8)
        }
        do {
          try templateData.write(to: URL(fileURLWithPath: filePath))
        } catch {
          vCLog("Failed to write template data to: \(filePath)")
          return false
        }
      }
    }
    return true
  }

  @discardableResult static func chkUserLMFilesExist(_ mode: Shared.InputMode) -> Bool {
    if !userDataFolderExists {
      return false
    }
    /// CandidateNode 資料與 UserOverrideModel 半衰模組資料檔案不需要強行確保存在。
    /// 前者的話，需要該檔案存在的人自己會建立。
    /// 後者的話，你在敲字時自己就會建立。
    var failed = false
    caseCheck: for type in vChewingLM.ReplacableUserDataType.allCases {
      let templateName = Self.templateName(for: type, mode: mode)
      if !ensureFileExists(userDictDataURL(mode: mode, type: type), deployTemplate: templateName) {
        failed = true
        break caseCheck
      }
    }
    failed = failed || !ensureFileExists(userSCPCSequencesURL(mode))
    return !failed
  }

  internal static func templateName(for type: vChewingLM.ReplacableUserDataType, mode: Shared.InputMode) -> String {
    switch type {
    case .thePhrases: return kTemplateNameUserPhrases
    case .theFilter: return kTemplateNameUserFilterList
    case .theReplacements: return kTemplateNameUserReplacements
    case .theSymbols: return kTemplateNameUserSymbolPhrases
    case .theAssociates:
      return mode == .imeModeCHS ? kTemplateNameUserAssociatesCHS : kTemplateNameUserAssociatesCHT
    }
  }
}
