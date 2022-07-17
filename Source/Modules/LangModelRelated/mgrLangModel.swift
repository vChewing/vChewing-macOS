// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
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

import Cocoa

/// 我們不能讓 mgrLangModel 這個靜態管理器來承載下面這些副本變數。
/// 所以，這些副本變數只能放在 mgrLangModel 的外部。
/// 同時，這些變數不對外開放任意存取權限。
/// 我們只在 mgrLangModel 內部寫幾個回傳函式、供其餘控制模組來讀取。

private var gLangModelCHS = vChewing.LMInstantiator()
private var gLangModelCHT = vChewing.LMInstantiator()
private var gUserOverrideModelCHS = vChewing.LMUserOverride()
private var gUserOverrideModelCHT = vChewing.LMUserOverride()

/// 使用者辭典資料預設範例檔案名稱。
private let kTemplateNameUserPhrases = "template-userphrases"
private let kTemplateNameUserReplacements = "template-replacements"
private let kTemplateNameUserExclusions = "template-exclusions"
private let kTemplateNameUserSymbolPhrases = "template-usersymbolphrases"
private let kTemplateNameUserAssociatesCHS = "template-associatedPhrases-chs"
private let kTemplateNameUserAssociatesCHT = "template-associatedPhrases-cht"

enum mgrLangModel {
  /// 寫幾個回傳函式、供其餘控制模組來讀取那些被設為 fileprivate 的器外變數。
  public static var lmCHS: vChewing.LMInstantiator { gLangModelCHS }
  public static var lmCHT: vChewing.LMInstantiator { gLangModelCHT }
  public static var uomCHS: vChewing.LMUserOverride { gUserOverrideModelCHS }
  public static var uomCHT: vChewing.LMUserOverride { gUserOverrideModelCHT }

  // MARK: - Functions reacting directly with language models.

  static func loadCoreLanguageModelFile(filenameSansExtension: String, langModel lm: inout vChewing.LMInstantiator) {
    let dataPath: String = mgrLangModel.getBundleDataPath(filenameSansExtension)
    lm.loadLanguageModel(path: dataPath)
  }

  public static func loadDataModels() {
    if !gLangModelCHT.isCNSDataLoaded {
      gLangModelCHT.loadCNSData(path: getBundleDataPath("data-cns"))
    }
    if !gLangModelCHT.isMiscDataLoaded {
      gLangModelCHT.loadMiscData(path: getBundleDataPath("data-zhuyinwen"))
    }
    if !gLangModelCHT.isSymbolDataLoaded {
      gLangModelCHT.loadSymbolData(path: getBundleDataPath("data-symbols"))
    }
    if !gLangModelCHS.isCNSDataLoaded {
      gLangModelCHS.loadCNSData(path: getBundleDataPath("data-cns"))
    }
    if !gLangModelCHS.isMiscDataLoaded {
      gLangModelCHS.loadMiscData(path: getBundleDataPath("data-zhuyinwen"))
    }
    if !gLangModelCHS.isSymbolDataLoaded {
      gLangModelCHS.loadSymbolData(path: getBundleDataPath("data-symbols"))
    }
    if !gLangModelCHT.isLanguageModelLoaded {
      NotifierController.notify(
        message: String(
          format: "%@", NSLocalizedString("Loading CHT Core Dict...", comment: "")
        )
      )
      loadCoreLanguageModelFile(filenameSansExtension: "data-cht", langModel: &gLangModelCHT)
      NotifierController.notify(
        message: String(
          format: "%@", NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      )
    }
    if !gLangModelCHS.isLanguageModelLoaded {
      NotifierController.notify(
        message: String(
          format: "%@", NSLocalizedString("Loading CHS Core Dict...", comment: "")
        )
      )
      loadCoreLanguageModelFile(filenameSansExtension: "data-chs", langModel: &gLangModelCHS)
      NotifierController.notify(
        message: String(
          format: "%@", NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      )
    }
  }

  public static func loadDataModel(_ mode: InputMode) {
    if mode == InputMode.imeModeCHS {
      if !gLangModelCHS.isMiscDataLoaded {
        gLangModelCHS.loadMiscData(path: getBundleDataPath("data-zhuyinwen"))
      }
      if !gLangModelCHS.isSymbolDataLoaded {
        gLangModelCHS.loadSymbolData(path: getBundleDataPath("data-symbols"))
      }
      if !gLangModelCHS.isCNSDataLoaded {
        gLangModelCHS.loadCNSData(path: getBundleDataPath("data-cns"))
      }
      if !gLangModelCHS.isLanguageModelLoaded {
        NotifierController.notify(
          message: String(
            format: "%@", NSLocalizedString("Loading CHS Core Dict...", comment: "")
          )
        )
        loadCoreLanguageModelFile(filenameSansExtension: "data-chs", langModel: &gLangModelCHS)
        NotifierController.notify(
          message: String(
            format: "%@", NSLocalizedString("Core Dict loading complete.", comment: "")
          )
        )
      }
    } else if mode == InputMode.imeModeCHT {
      if !gLangModelCHT.isMiscDataLoaded {
        gLangModelCHT.loadMiscData(path: getBundleDataPath("data-zhuyinwen"))
      }
      if !gLangModelCHT.isSymbolDataLoaded {
        gLangModelCHT.loadSymbolData(path: getBundleDataPath("data-symbols"))
      }
      if !gLangModelCHT.isCNSDataLoaded {
        gLangModelCHT.loadCNSData(path: getBundleDataPath("data-cns"))
      }
      if !gLangModelCHT.isLanguageModelLoaded {
        NotifierController.notify(
          message: String(
            format: "%@", NSLocalizedString("Loading CHT Core Dict...", comment: "")
          )
        )
        loadCoreLanguageModelFile(filenameSansExtension: "data-cht", langModel: &gLangModelCHT)
        NotifierController.notify(
          message: String(
            format: "%@", NSLocalizedString("Core Dict loading complete.", comment: "")
          )
        )
      }
    }
  }

  public static func loadUserPhrasesData() {
    gLangModelCHT.loadUserPhrasesData(
      path: userPhrasesDataURL(InputMode.imeModeCHT).path,
      filterPath: userFilteredDataURL(InputMode.imeModeCHT).path
    )
    gLangModelCHS.loadUserPhrasesData(
      path: userPhrasesDataURL(InputMode.imeModeCHS).path,
      filterPath: userFilteredDataURL(InputMode.imeModeCHS).path
    )
    gLangModelCHT.loadUserSymbolData(path: userSymbolDataURL(InputMode.imeModeCHT).path)
    gLangModelCHS.loadUserSymbolData(path: userSymbolDataURL(InputMode.imeModeCHS).path)

    gUserOverrideModelCHT.loadData(fromURL: userOverrideModelDataURL(InputMode.imeModeCHT))
    gUserOverrideModelCHS.loadData(fromURL: userOverrideModelDataURL(InputMode.imeModeCHS))

    SymbolNode.parseUserSymbolNodeData()
  }

  public static func loadUserAssociatesData() {
    gLangModelCHT.loadUserAssociatesData(
      path: mgrLangModel.userAssociatesDataURL(InputMode.imeModeCHT).path
    )
    gLangModelCHS.loadUserAssociatesData(
      path: mgrLangModel.userAssociatesDataURL(InputMode.imeModeCHS).path
    )
  }

  public static func loadUserPhraseReplacement() {
    gLangModelCHT.loadReplacementsData(
      path: mgrLangModel.userReplacementsDataURL(InputMode.imeModeCHT).path
    )
    gLangModelCHS.loadReplacementsData(
      path: mgrLangModel.userReplacementsDataURL(InputMode.imeModeCHS).path
    )
  }

  public static func checkIfUserPhraseExist(
    userPhrase: String,
    mode: InputMode,
    key unigramKey: String
  ) -> Bool {
    let unigrams: [Megrez.Unigram] =
      (mode == InputMode.imeModeCHT)
      ? gLangModelCHT.unigramsFor(key: unigramKey) : gLangModelCHS.unigramsFor(key: unigramKey)
    for unigram in unigrams {
      if unigram.keyValue.value == userPhrase {
        return true
      }
    }
    return false
  }

  public static func setPhraseReplacementEnabled(_ state: Bool) {
    gLangModelCHT.isPhraseReplacementEnabled = state
    gLangModelCHS.isPhraseReplacementEnabled = state
  }

  public static func setCNSEnabled(_ state: Bool) {
    gLangModelCHT.isCNSEnabled = state
    gLangModelCHS.isCNSEnabled = state
  }

  public static func setSymbolEnabled(_ state: Bool) {
    gLangModelCHT.isSymbolEnabled = state
    gLangModelCHS.isSymbolEnabled = state
  }

  // MARK: - 獲取當前輸入法封包內的原廠核心語彙檔案所在路徑

  static func getBundleDataPath(_ filenameSansExt: String) -> String {
    Bundle.main.path(forResource: filenameSansExt, ofType: "plist")!
  }

  // MARK: - 使用者語彙檔案的具體檔案名稱路徑定義

  // Swift 的 appendingPathComponent 需要藉由 URL 完成，最後再用 .path 轉為路徑。

  /// 使用者語彙辭典資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userPhrasesDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "userdata-cht.txt" : "userdata-chs.txt"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者繪文字符號辭典資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userSymbolDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "usersymbolphrases-cht.txt" : "usersymbolphrases-chs.txt"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者聯想詞資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userAssociatesDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "associatedPhrases-cht.txt" : "associatedPhrases-chs.txt"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者語彙濾除表資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userFilteredDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "exclude-phrases-cht.txt" : "exclude-phrases-chs.txt"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者語彙置換表資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userReplacementsDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "phrases-replacement-cht.txt" : "phrases-replacement-chs.txt"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者波浪符號選單資料路徑。
  /// - Returns: 資料路徑（URL）。
  static func userSymbolNodeDataURL() -> URL {
    let fileName = "symbols.dat"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者半衰記憶模組資料的存取頻次特別高，且資料新陳代謝速度快，所以只適合放在預設的使用者資料目錄下。
  /// 也就是「~/Library/Application Support/vChewing/」目錄下，且不會隨著使用者辭典目錄的改變而改變。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  static func userOverrideModelDataURL(_ mode: InputMode) -> URL {
    let fileName = (mode == InputMode.imeModeCHT) ? "override-model-data-cht.dat" : "override-model-data-chs.dat"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: true)).appendingPathComponent(fileName)
  }

  // MARK: - 檢查具體的使用者語彙檔案是否存在

  static func ensureFileExists(
    _ fileURL: URL, populateWithTemplate templateBasename: String = "1145141919810",
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
          IME.prtDebugIntel("Failed to write template data to: \(filePath)")
          return false
        }
      }
    }
    return true
  }

  @discardableResult static func chkUserLMFilesExist(_ mode: InputMode) -> Bool {
    if !userDataFolderExists {
      return false
    }
    /// SymbolNode 資料與 UserOverrideModel 半衰模組資料檔案不需要強行確保存在。
    /// 前者的話，需要該檔案存在的人自己會建立。
    /// 後者的話，你在敲字時自己就會建立。
    if !ensureFileExists(userPhrasesDataURL(mode), populateWithTemplate: kTemplateNameUserPhrases)
      || !ensureFileExists(
        userAssociatesDataURL(mode),
        populateWithTemplate: mode == .imeModeCHS ? kTemplateNameUserAssociatesCHS : kTemplateNameUserAssociatesCHT)
      || !ensureFileExists(userFilteredDataURL(mode), populateWithTemplate: kTemplateNameUserExclusions)
      || !ensureFileExists(userReplacementsDataURL(mode), populateWithTemplate: kTemplateNameUserReplacements)
      || !ensureFileExists(userSymbolDataURL(mode), populateWithTemplate: kTemplateNameUserSymbolPhrases)
    {
      return false
    }

    return true
  }

  // MARK: - 使用者語彙檔案專用目錄的合規性檢查

  // 一次性檢查給定的目錄是否存在寫入合規性（僅用於偏好設定檢查等初步檢查場合，不做任何糾偏行為）
  static func checkIfSpecifiedUserDataFolderValid(_ folderPath: String?) -> Bool {
    var isFolder = ObjCBool(false)
    let folderExist = FileManager.default.fileExists(atPath: folderPath ?? "", isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "folderExist".

    // 路徑沒有結尾斜槓的話，會導致目錄合規性判定失準。
    // 出於每個型別每個函式的自我責任原則，這裡多檢查一遍也不壞。
    var folderPath = folderPath  // Convert the incoming constant to a variable.
    if isFolder.boolValue {
      folderPath?.ensureTrailingSlash()
    }
    let isFolderWritable = FileManager.default.isWritableFile(atPath: folderPath ?? "")

    if ((folderExist && !isFolder.boolValue) || !folderExist) || !isFolderWritable {
      return false
    }

    return true
  }

  // 檢查給定的目錄是否存在寫入合規性、且糾偏，不接受任何傳入變數。
  static var userDataFolderExists: Bool {
    let folderPath = mgrLangModel.dataFolderPath(isDefaultFolder: false)
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

  // MARK: - 用以讀取使用者語彙檔案目錄的函式，會自動對 mgrPrefs 當中的參數糾偏。

  // 當且僅當 mgrPrefs 當中的參數不合規（比如非實在路徑、或者無權限寫入）時，才會糾偏。

  static func dataFolderPath(isDefaultFolder: Bool) -> String {
    let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].path
    var userDictPathSpecified = mgrPrefs.userDataFolderSpecified.expandingTildeInPath
    var userDictPathDefault =
      URL(fileURLWithPath: appSupportPath).appendingPathComponent("vChewing").path.expandingTildeInPath

    userDictPathDefault.ensureTrailingSlash()
    userDictPathSpecified.ensureTrailingSlash()

    if (userDictPathSpecified == userDictPathDefault)
      || isDefaultFolder
    {
      return userDictPathDefault
    }
    if mgrPrefs.ifSpecifiedUserDataPathExistsInPlist() {
      if mgrLangModel.checkIfSpecifiedUserDataFolderValid(userDictPathSpecified) {
        return userDictPathSpecified
      } else {
        UserDefaults.standard.removeObject(forKey: "UserDataFolderSpecified")
      }
    }
    return userDictPathDefault
  }

  // MARK: - 寫入使用者檔案

  static func writeUserPhrase(
    _ userPhrase: String?, inputMode mode: InputMode, areWeDuplicating: Bool, areWeDeleting: Bool
  ) -> Bool {
    if var currentMarkedPhrase: String = userPhrase {
      if !chkUserLMFilesExist(InputMode.imeModeCHS)
        || !chkUserLMFilesExist(InputMode.imeModeCHT)
      {
        return false
      }

      let theURL = areWeDeleting ? userFilteredDataURL(mode) : userPhrasesDataURL(mode)

      if areWeDuplicating, !areWeDeleting {
        // Do not use ASCII characters to comment here.
        // Otherwise, it will be scrambled by cnvHYPYtoBPMF
        // module shipped in the vChewing Phrase Editor.
        currentMarkedPhrase += "\t#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎"
      }

      if let writeFile = FileHandle(forUpdatingAtPath: theURL.path),
        let data = currentMarkedPhrase.data(using: .utf8),
        let endl = "\n".data(using: .utf8)
      {
        writeFile.seekToEndOfFile()
        writeFile.write(endl)
        writeFile.write(data)
        writeFile.write(endl)
        writeFile.closeFile()
      } else {
        return false
      }

      // We enforce the format consolidation here, since the pragma header
      // will let the UserPhraseLM bypasses the consolidating process on load.
      if !vChewing.LMConsolidator.consolidate(path: theURL.path, pragma: false) {
        return false
      }

      // We use FSEventStream to monitor possible changes of the user phrase folder, hence the
      // lack of the needs of manually load data here unless FSEventStream is disabled by user.
      if !mgrPrefs.shouldAutoReloadUserDataFiles {
        loadUserPhrasesData()
      }
      return true
    }
    return false
  }

  static func saveUserOverrideModelData() {
    gUserOverrideModelCHT.saveData(toURL: userOverrideModelDataURL(InputMode.imeModeCHT))
    gUserOverrideModelCHS.saveData(toURL: userOverrideModelDataURL(InputMode.imeModeCHS))
  }

  static func removeUnigramsFromUserOverrideModel(_ mode: InputMode) {
    switch mode {
      case .imeModeCHS:
        gUserOverrideModelCHT.bleachUnigrams()
      case .imeModeCHT:
        gUserOverrideModelCHS.bleachUnigrams()
      case .imeModeNULL:
        break
    }
  }

  static func clearUserOverrideModelData(_ mode: InputMode = .imeModeNULL) {
    switch mode {
      case .imeModeCHS:
        gUserOverrideModelCHS.clearData(withURL: userOverrideModelDataURL(InputMode.imeModeCHS))
      case .imeModeCHT:
        gUserOverrideModelCHT.clearData(withURL: userOverrideModelDataURL(InputMode.imeModeCHT))
      case .imeModeNULL:
        break
    }
  }
}
