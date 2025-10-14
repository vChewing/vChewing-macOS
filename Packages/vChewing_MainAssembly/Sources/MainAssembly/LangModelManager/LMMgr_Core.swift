// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import LangModelAssembly
import NotifierUI
import Shared
import SwiftExtension

// MARK: - Input Mode Extension for Language Models

extension Shared.InputMode {
  private static let lmCHS = LMAssembly.LMInstantiator(
    isCHS: true, pomDataURL: LMMgr.perceptionOverrideModelDataURL(.imeModeCHS)
  )
  private static let lmCHT = LMAssembly.LMInstantiator(
    isCHS: false, pomDataURL: LMMgr.perceptionOverrideModelDataURL(.imeModeCHT)
  )

  public var langModel: LMAssembly.LMInstantiator {
    switch self {
    case .imeModeCHS: return Self.lmCHS
    case .imeModeCHT: return Self.lmCHT
    case .imeModeNULL: return .init()
    }
  }
}

// MARK: - LMMgr

public class LMMgr {
  public static var shared = LMMgr()

  public static var isCoreDBConnected: Bool { LMAssembly.LMInstantiator.isSQLDBConnected }

  // MARK: - Functions reacting directly with language models.

  public static func initUserLangModels() {
    Shared.InputMode.validCases.forEach { mode in
      Self.chkUserLMFilesExist(mode)
    }
    // LMMgr 的 loadUserPhrases 等函式在自動讀取 dataFolderPath 時，
    // 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
    // 所以這裡不需要特別處理。
    Self.loadUserPhrasesData()
  }

  public static func connectCoreDB(dbPath: String? = nil) {
    guard let path: String = dbPath ?? Self.getCoreDictionaryDBPath() else {
      preconditionFailure("vChewing factory SQLite data not found.")
    }
    let result = LMAssembly.LMInstantiator.connectSQLDB(dbPath: path)
    assert(result, "vChewing factory SQLite connection failed.")
    Notifier.notify(
      message: NSLocalizedString("Core Dict loading complete.", comment: "")
    )
  }

  /// 載入磁帶資料。
  /// - Remark: cassettePath() 會在輸入法停用磁帶時直接返回
  public static func loadCassetteData() {
    func validateCassetteCandidateKey(_ target: String) -> Bool {
      CandidateKey.validate(keys: target) == nil
    }

    LMAssembly.LMInstantiator.setCassetCandidateKeyValidator(validateCassetteCandidateKey)
    LMAssembly.LMInstantiator.loadCassetteData(path: cassettePath())
  }

  public static func loadUserPhrasesData(type: LMAssembly.ReplacableUserDataType? = nil) {
    guard let type = type else {
      Shared.InputMode.validCases.forEach { mode in
        mode.langModel.loadUserPhrasesData(
          path: userDictDataURL(mode: mode, type: .thePhrases).path,
          filterPath: userDictDataURL(mode: mode, type: .theFilter).path
        )
        mode.langModel.loadUserSymbolData(path: userDictDataURL(mode: mode, type: .theSymbols).path)
        mode.langModel.loadPOMData()
      }

      if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
      if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }

      CandidateNode.load(url: Self.userSymbolMenuDataURL())
      return
    }
    Shared.InputMode.validCases.forEach { mode in
      switch type {
      case .thePhrases:
        mode.langModel.loadUserPhrasesData(
          path: userDictDataURL(mode: mode, type: .thePhrases).path,
          filterPath: nil
        )
      case .theFilter:
        asyncOnMain {
          Self.reloadUserFilterDirectly(mode: mode)
        }
      case .theReplacements:
        if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }
      case .theAssociates:
        if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
      case .theSymbols:
        mode.langModel.loadUserSymbolData(
          path: Self.userDictDataURL(mode: mode, type: .theSymbols).path
        )
      }
    }
  }

  public static func loadUserAssociatesData() {
    Shared.InputMode.validCases.forEach { mode in
      mode.langModel.loadUserAssociatesData(
        path: Self.userDictDataURL(mode: mode, type: .theAssociates).path
      )
    }
  }

  public static func loadUserPhraseReplacement() {
    Shared.InputMode.validCases.forEach { mode in
      mode.langModel.loadReplacementsData(
        path: Self.userDictDataURL(mode: mode, type: .theReplacements).path
      )
    }
  }

  public static func reloadUserFilterDirectly(mode: Shared.InputMode) {
    mode.langModel
      .reloadUserFilterDirectly(path: userDictDataURL(mode: mode, type: .theFilter).path)
  }

  public static func checkIfPhrasePairExists(
    userPhrase: String,
    mode: Shared.InputMode,
    keyArray: [String],
    factoryDictionaryOnly: Bool = false
  )
    -> Bool {
    mode.langModel.hasKeyValuePairFor(
      keyArray: keyArray, value: userPhrase, factoryDictionaryOnly: factoryDictionaryOnly
    )
  }

  public static func checkIfPhrasePairIsFiltered(
    userPhrase: String,
    mode: Shared.InputMode,
    keyArray: [String]
  )
    -> Bool {
    mode.langModel.isPairFiltered(pair: .init(keyArray: keyArray, value: userPhrase))
  }

  /// 偵測當前輸入狀態所標記的詞音配對是否可以被加入過濾清單。
  public static func isStateDataFilterableForMarked(_ state: IMEStateData) -> Bool {
    guard state.isMarkedLengthValid else { return false } // 範圍長度必須合規。
    guard state.markedTargetExists else { return false } // 必須得有在庫對象
    guard state.markedReadings.count == 1 else { return true } // 如果幅長大於 1，則直接批准。
    // 處理單個漢字的情形：當且僅當在庫量僅有一筆的時候，才禁止過濾。
    return countPhrasePairs(
      keyArray: state.markedReadings, mode: IMEApp.currentInputMode
    ) > 1
  }

  public static func countPhrasePairs(
    keyArray: [String],
    mode: Shared.InputMode,
    factoryDictionaryOnly: Bool = false
  )
    -> Int {
    mode.langModel.countKeyValuePairs(
      keyArray: keyArray, factoryDictionaryOnly: factoryDictionaryOnly
    )
  }

  public static func syncLMPrefs() {
    Shared.InputMode.validCases.forEach { mode in
      mode.langModel.setOptions { config in
        config.isPhraseReplacementEnabled = PrefMgr.shared.phraseReplacementEnabled
        config.isCNSEnabled = PrefMgr.shared.cns11643Enabled
        config.isSymbolEnabled = PrefMgr.shared.symbolInputEnabled
        config.isSCPCEnabled = PrefMgr.shared.useSCPCTypingMode
        config.isCassetteEnabled = PrefMgr.shared.cassetteEnabled
        config.filterNonCNSReadings = PrefMgr.shared.filterNonCNSReadingsForCHTInput
        config.deltaOfCalendarYears = PrefMgr.shared.deltaOfCalendarYears
      }
    }
  }

  // MARK: POM

  public static func savePerceptionOverrideModelData(_ saveAllModes: Bool = true) {
    let globalQueue = DispatchQueue(
      label: "LMAssembly_POM",
      qos: .unspecified,
      attributes: .concurrent
    )
    let group = DispatchGroup()
    let cases = saveAllModes ? [IMEApp.currentInputMode] : Shared.InputMode.allCases
    cases.forEach { mode in
      group.enter()
      globalQueue.async {
        mode.langModel.savePOMData()
        group.leave()
      }
    }
    _ = group.wait(timeout: .distantFuture)
    group.notify(queue: DispatchQueue.main) {}
  }

  public static func bleachSpecifiedSuggestions(targets: [String], mode: Shared.InputMode) {
    mode.langModel.bleachSpecifiedPOMSuggestions(targets: targets)
  }

  public static func bleachSpecifiedSuggestions(headReadings: [String], mode: Shared.InputMode) {
    mode.langModel.bleachSpecifiedPOMSuggestions(headReadings: headReadings)
  }

  public static func removeUnigramsFromPerceptionOverrideModel(_ mode: Shared.InputMode) {
    mode.langModel.bleachPOMUnigrams()
  }

  public static func relocateWreckedPOMData() {
    func dateStringTag(date givenDate: Date) -> String {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyyMMdd-HHmm"
      dateFormatter.timeZone = .current
      let strDate = dateFormatter.string(from: givenDate)
      return strDate
    }

    let urls: [URL] = [perceptionOverrideModelDataURL(.imeModeCHS), perceptionOverrideModelDataURL(.imeModeCHT)]
    let folderURL = URL(fileURLWithPath: dataFolderPath(isDefaultFolder: true))
      .deletingLastPathComponent()
    urls.forEach { oldURL in
      let newFileName = "[POM-CRASH][\(dateStringTag(date: .init()))]\(oldURL.lastPathComponent)"
      let newURL = folderURL.appendingPathComponent(newFileName)
      try? FileManager.default.moveItem(at: oldURL, to: newURL)
    }
  }

  public static func clearPerceptionOverrideModelData(_ mode: Shared.InputMode = .imeModeNULL) {
    mode.langModel.clearPOMData()
  }

  /// 清理語言模型記憶體，防止記憶體洩漏
  public static func performMemoryCleanup() {
    Shared.InputMode.validCases.forEach { mode in
      mode.langModel.purgeInputTokenHashMap()
    }
  }
}
