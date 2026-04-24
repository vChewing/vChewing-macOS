// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import Shared
import SwiftExtension
import TrieKit

extension LMAssembly {
  typealias ScoreAssigner = (CandidateInState?) -> Double

  /// 語言模組副本化模組（LMInstantiator，下稱「LMI」）自身統籌且整理來自
  /// 其它子模組的資料（包括使用者語彙、繪文字模組、語彙濾除表、原廠語言模組等）。
  ///
  /// LMI 型別為與輸入法輸入調度模組直接溝通之唯一語言模組。當組字器開始根據給定的
  /// 讀音鏈構築語句時，LMI 會接收來自組字器的讀音、輪流檢查自身是否有可以匹配到的
  /// 單元圖結果，然後將結果整理為陣列、再回饋給組字器。
  ///
  /// LMI 還會在將單元圖結果整理成陣列時做出下述處理轉換步驟：
  ///
  /// 1. 獲取原始結果陣列。
  /// 2. 如果有原始結果也出現在濾除表當中的話，則自結果陣列丟棄這類結果。
  /// 3. 如果啟用了語彙置換的話，則對目前經過處理的結果陣列套用語彙置換。
  /// 4. 擁有相同讀音與詞語資料值的單元圖只會留下權重最大的那一筆，其餘重複值會被丟棄。
  ///
  /// LMI 會根據需要分別載入原廠語言模組和其他個別的子語言模組。LMI 本身不會記錄這些
  /// 語言模組的相關資料的存放位置，僅藉由參數來讀取相關訊息。
  public final class LMInstantiator {
    // MARK: Lifecycle

    // 這句需要留著，不然無法被 package 外界存取。
    public init(
      isCHS: Bool = false,
      pomDataURL: URL? = nil
    ) {
      self.isCHS = isCHS
      self.mtxLXPerceptor = .init(.init(dataURL: pomDataURL))
    }

    // MARK: Public

    public struct Config {
      /// 如果設定為 nil 的話，則不產生任何詞頻資料。
      /// true = 全形，false = 半形。
      public var numPadFWHWStatus: Bool?
      public var isCassetteEnabled = false
      public var isPhraseReplacementEnabled = false
      public var isCNSEnabled = false
      public var isSymbolEnabled = false
      public var isSCPCEnabled = false
      public var alwaysSupplyETenDOSUnigrams = true
      public var partialMatchEnabled = false
      public var filterNonCNSReadings = false
      public var deltaOfCalendarYears: Int = -2_000
      public var allowRescoringSingleKanjiCandidates = false
      public var bypassUserPhrasesData = false
    }

    public enum SupplementalLookupStrategy {
      /// Route through the backend's current default lookup path.
      case configuredLookup
      /// Force exact-key lookup only.
      case exactMatch
      /// Force prefix-based partial lookup.
      case partialMatch
    }

    /// 將收斂後的 lookup facade 集中到單一掛點。
    /// 這讓下游呼叫端可比照 TrieHub 風格使用同一個 hub，而不是直接散落在 LMI 根型別上。
    public struct LookupHub {
      // MARK: Lifecycle

      init(lmi: LMInstantiator) {
        self.lmi = lmi
      }

      // MARK: Public

      public func associatedCandidates(forPairs pairs: [Homa.CandidatePair]) -> [Homa.CandidatePairRAW] {
        var inserted = Set<String>()
        var result: [Homa.CandidatePairRAW] = []
        pairs.forEach { pair in
          lmi.associatedPhrasesFor(pair: pair).forEach { current in
            guard inserted.insert(current).inserted else { return }
            result.append((keyArray: [""], value: current))
          }
        }
        return result
      }

      public func associatedCandidates(forPair pair: Homa.CandidatePair) -> [Homa.CandidatePairRAW] {
        var pairs = [Homa.CandidatePair]()
        var keyArray = pair.keyArray
        var value = pair.value
        while !keyArray.isEmpty {
          if keyArray.count == value.count { pairs.append(.init(keyArray: keyArray, value: value)) }
          pairs.append(.init(keyArray: [], value: value))
          keyArray = Array(keyArray.dropFirst())
          value = value.dropFirst().description
        }
        return associatedCandidates(forPairs: pairs)
      }

      public func supplementalValues(
        for reading: String,
        strategy: SupplementalLookupStrategy
      )
        -> [String] {
        switch strategy {
        case .configuredLookup:
          if lmi.config.partialMatchEnabled {
            return LMInstantiator.lmPlainBopomofo.partiallyMatchedValuesFor(prefix: reading, isCHS: lmi.isCHS)
          }
          return LMInstantiator.lmPlainBopomofo.valuesFor(key: reading, isCHS: lmi.isCHS)
        case .exactMatch:
          return LMInstantiator.lmPlainBopomofo.valuesFor(key: reading, isCHS: lmi.isCHS)
        case .partialMatch:
          return LMInstantiator.lmPlainBopomofo.partiallyMatchedValuesFor(prefix: reading, isCHS: lmi.isCHS)
        }
      }

      public func grams(for keyArray: [String]) -> [Homa.GramRAW] {
        lmi.unigramsFor(keyArray: keyArray).map {
          (keyArray: $0.keyArray, value: $0.current, probability: $0.probability, previous: nil)
        }
      }

      public func hasGrams(for keyArray: [String]) -> Bool {
        lmi.hasUnigramsForFast(keyArray: keyArray)
      }

      // MARK: Fileprivate

      fileprivate let lmi: LMInstantiator
    }

    public static var asyncLoadingUserData: Bool = true
    // 與關聯詞語有關的惰性載入器，可由外部登記。
    public static var associatesLazyLoader: (() -> ())?

    public static var isFactoryDictionaryLoaded: Bool { factoryTrie != nil }

    // 簡體中文模型？
    public let isCHS: Bool

    // 在函式內部用以記錄狀態的開關。
    public private(set) var config = Config()

    public internal(set) var inputTokenHashesArray: Set<Int> = []

    public var lookupHub: LookupHub { .init(lmi: self) }

    public var isCassetteDataLoaded: Bool { Self.lmCassette.isLoaded }

    public static func setCassetCandidateKeyValidator(_ validator: @Sendable @escaping (String) -> Bool) {
      Self.lmCassette.candidateKeysValidator = validator
    }

    public static func loadCassetteData(path: String) {
      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          Self.lmCassette.clear()
          Self.lmCassette.open(path)
          vCLMLog("lmCassette: \(Self.lmCassette.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmCassette: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        // CIN 解析在背景佇列完成，僅在成功後把結果交回 MainActor。
        let validator = Self.lmCassette.candidateKeysValidator
        LMAssembly.fileHandleQueue.async {
          guard FileManager.default.isReadableFile(atPath: path) else {
            vCLMLog("lmCassette: File access failure: \(path)")
            return
          }
          var newCassette = LMCassette()
          newCassette.candidateKeysValidator = validator
          newCassette.open(path)
          let count = newCassette.count
          asyncOnMain {
            Self.lmCassette = newCassette
            vCLMLog("lmCassette: \(count) entries of data loaded from: \(path)")
          }
        }
      }
    }

    // MARK: Shared Resource Lifecycle

    public static func resetSharedResources(restoreAsyncLoadingStrategy: Bool = true) {
      disconnectFactoryDictionary()
      lmCassette = LMCassette()
      lmPlainBopomofo = LMPlainBopomofo()
      guard restoreAsyncLoadingStrategy else { return }
      asyncLoadingUserData = !UserDefaults.pendingUnitTests
    }

    @discardableResult
    public func setOptions(handler: (inout Config) -> ()) -> LMInstantiator {
      handler(&config)
      return self
    }

    public func syncPrefs() {
      config.isPhraseReplacementEnabled = prefs.phraseReplacementEnabled
      config.isCNSEnabled = prefs.cns11643Enabled
      config.isSymbolEnabled = prefs.symbolInputEnabled
      config.isSCPCEnabled = prefs.useSCPCTypingMode
      config.isCassetteEnabled = prefs.cassetteEnabled
      config.filterNonCNSReadings = prefs.filterNonCNSReadingsForCHTInput
      config.deltaOfCalendarYears = prefs.deltaOfCalendarYears
      config.allowRescoringSingleKanjiCandidates = prefs.allowRescoringSingleKanjiCandidates
      config.alwaysSupplyETenDOSUnigrams = prefs.enforceETenDOSCandidateSequence
      config.bypassUserPhrasesData = prefs.userPhrasesDatabaseBypassed
    }

    public func resetFactoryJSONModels() {}

    /// 清除 InputToken HashMap。
    /// 注意：此 HashMap 僅記錄由 InputToken（以 "MACRO@" 開頭的特殊標記）生成的 Unigram。
    public func purgeInputTokenHashMap() {
      inputTokenHashesArray.removeAll()
    }

    public func loadUserPhrasesData(path: String, filterPath: String?) {
      func loadMain() {
        if FileManager.default.isReadableFile(atPath: path) {
          lmUserPhrases.clear()
          lmUserPhrases.open(path)
          vCLMLog("lmUserPhrases: \(lmUserPhrases.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmUserPhrases: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        loadMain()
      } else {
        LMAssembly.readFileContentAsync(
          path: path, shouldConsolidate: lmUserPhrases.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          self.lmUserPhrases.clear()
          self.lmUserPhrases.replaceData(textData: content)
          self.lmUserPhrases.filePath = path
          vCLMLog("lmUserPhrases: \(self.lmUserPhrases.count) entries of data loaded from: \(path)")
        }
      }
      guard let filterPath = filterPath else { return }
      func loadFilter() {
        if FileManager.default.isReadableFile(atPath: filterPath) {
          lmFiltered.clear()
          lmFiltered.open(filterPath)
          vCLMLog("lmFiltered: \(lmFiltered.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmFiltered: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        loadFilter()
      } else {
        LMAssembly.readFileContentAsync(
          path: filterPath, shouldConsolidate: lmFiltered.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          self.lmFiltered.clear()
          self.lmFiltered.replaceData(textData: content)
          self.lmFiltered.filePath = filterPath
          vCLMLog("lmFiltered: \(self.lmFiltered.count) entries of data loaded from: \(filterPath)")
        }
      }
    }

    /// 這個函式不用 GCD。
    public func reloadUserFilterDirectly(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmFiltered.clear()
        lmFiltered.open(path)
        vCLMLog("lmFiltered: \(lmFiltered.count) entries of data loaded from: \(path)")
      } else {
        vCLMLog("lmFiltered: File access failure: \(path)")
      }
    }

    public func loadUserSymbolData(path: String) {
      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lmUserSymbols.clear()
          lmUserSymbols.open(path)
          vCLMLog("lmUserSymbol: \(lmUserSymbols.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmUserSymbol: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        LMAssembly.readFileContentAsync(
          path: path, shouldConsolidate: lmUserSymbols.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          self.lmUserSymbols.clear()
          self.lmUserSymbols.replaceData(textData: content)
          self.lmUserSymbols.filePath = path
          vCLMLog("lmUserSymbol: \(self.lmUserSymbols.count) entries of data loaded from: \(path)")
        }
      }
    }

    public func loadUserAssociatesData(path: String) {
      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lmAssociates.clear()
          lmAssociates.open(path)
          vCLMLog("lmAssociates: \(lmAssociates.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmAssociates: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        loadUserAssociatesDataAsync(path: path)
      }
    }

    /// 非同步讀取關聯詞語資料（懶載入路徑）。
    public func loadUserAssociatesDataAsync(path: String) {
      // LMAssociates.open() 一律 consolidate。
      LMAssembly.readFileContentAsync(
        path: path, shouldConsolidate: true
      ) { [weak self] content in
        guard let self else { return }
        self.lmAssociates.clear()
        self.lmAssociates.replaceData(textData: content)
        self.lmAssociates.filePath = path
        vCLMLog("lmAssociates: \(self.lmAssociates.count) entries of data loaded from: \(path)")
      }
    }

    public func loadReplacementsData(path: String) {
      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lmReplacements.clear()
          lmReplacements.open(path)
          vCLMLog("lmReplacements: \(lmReplacements.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lmReplacements: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        // LMReplacements.open() 一律 consolidate，故 shouldConsolidate: true。
        LMAssembly.readFileContentAsync(
          path: path, shouldConsolidate: true
        ) { [weak self] content in
          guard let self else { return }
          self.lmReplacements.clear()
          self.lmReplacements.replaceData(textData: content)
          self.lmReplacements.filePath = path
          vCLMLog("lmReplacements: \(self.lmReplacements.count) entries of data loaded from: \(path)")
        }
      }
    }

    // MARK: - 核心函式（對外）

    public func hasAssociatedPhrasesFor(pair: Homa.CandidatePair) -> Bool {
      lmAssociates.hasValuesFor(pair: pair)
    }

    public func associatedPhrasesFor(pair: Homa.CandidatePair) -> [String] {
      lmAssociates.valuesFor(pair: pair)
    }

    public func queryReplacementValue(key: String) -> String? {
      let result = lmReplacements.valuesFor(key: key)
      return result.isEmpty ? nil : result
    }

    public func isPairFiltered(pair: Homa.CandidatePair) -> Bool {
      lmFiltered
        .unigramsFor(key: pair.joinedKey(), keyArray: pair.keyArray)
        .map(\.current)
        .contains(pair.value)
    }

    /// 插入臨時資料。
    /// - Parameters:
    ///   - key: 索引鍵陣列。
    ///   - unigram: 要插入的單元圖。
    ///   - isFiltering: 是否有在過濾內容。
    public func insertTemporaryData(
      unigram: Homa.Gram,
      isFiltering: Bool
    ) {
      let keyChain = unigram.keyArray.joined(separator: "-")
      _ =
        isFiltering
          ? lmFiltered.temporaryMap[keyChain, default: []].append(unigram)
          : lmUserPhrases.temporaryMap[keyChain, default: []].append(unigram)
    }

    /// 該函式主要供單元測試所用。
    public func clearTemporaryData(isFiltering: Bool) {
      _ = isFiltering ? lmFiltered.clear() : lmUserPhrases.clear()
    }

    /// 自當前記憶體取得指定使用者子語言模組內的原始資料體。
    /// - Parameters:
    ///   - targetType: 操作對象。
    public func retrieveData(from targetType: ReplacableUserDataType) -> String {
      switch targetType {
      case .thePhrases: return lmUserPhrases.strData
      case .theFilter: return lmFiltered.strData
      case .theReplacements: return lmReplacements.strData
      case .theAssociates: return lmAssociates.strData
      case .theSymbols: return lmUserSymbols.strData
      }
    }

    /// 熱置換指定使用者子語言模組內的資料，且會在熱置換之後存檔。
    /// - Parameters:
    ///   - rawStrData: 新的資料。
    ///   - targetType: 操作對象。
    public func replaceData(
      textData rawStrData: String,
      for targetType: ReplacableUserDataType,
      save: Bool = true
    ) {
      var rawText = rawStrData
      LMConsolidator.consolidate(text: &rawText, pragma: true)
      switch targetType {
      case .theAssociates:
        lmAssociates.replaceData(textData: rawText)
        if save { lmAssociates.saveData() }
      case .theFilter:
        lmFiltered.replaceData(textData: rawText)
        if save { lmFiltered.saveData() }
      case .theReplacements:
        lmReplacements.replaceData(textData: rawText)
        if save { lmReplacements.saveData() }
      case .thePhrases:
        lmUserPhrases.replaceData(textData: rawText)
        if save { lmUserPhrases.saveData() }
      case .theSymbols:
        lmUserSymbols.replaceData(textData: rawText)
        if save { lmUserSymbols.saveData() }
      }
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵陣列。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      let keyChain = keyArray.joined(separator: "-")
      // 因為涉及到對濾除清單的檢查，所以這裡必須走一遍 .unigramsFor()。
      // 以 2010 年的電腦效能作為基準參考來看的話，這方面的效能壓力可以忽略不計。
      return keyChain == " " || (!unigramsFor(keyArray: keyArray).isEmpty && !keyChain.isEmpty)
    }

    /// 輕量版 `hasUnigramsFor`，專供 Homa.Assembler 與 Typewriter 層快速判定讀音是否存在。
    ///
    /// 與完整版 `hasUnigramsFor` 的差異：
    /// - 跳過濾除表、語彙置換、InputToken 展開、DateTime、倚天排序等「後處理」步驟。
    /// - 對含 `&` 的 tone bucket 原廠查詢改走 `factoryChoppedCoreUnigramsFor`（O(1) per keyArray）。
    /// - user phrases / symbols / cassette 僅做 `hasUnigramsFor(key:)` hash lookup。
    ///
    /// 語義保證：若 `hasUnigramsForFast` 回傳 `false`，則 `hasUnigramsFor` / `unigramsFor` 必定也回傳空陣列；
    /// 若回傳 `true`，則 `unigramsFor` 至少會有一筆結果（可能在後處理階段被濾除，但 availability 意義上「存在」）。
    public func hasUnigramsForFast(keyArray: [String]) -> Bool {
      let keyChain = keyArray.joined(separator: "-")
      guard keyChain != " ", !keyChain.isEmpty else { return keyChain == " " }
      let noEmptyKey = !keyArray.isEmpty && keyArray.allSatisfy { !$0.isEmpty }
      guard noEmptyKey else { return false }

      let containsAlternatives = keyArray.joined().contains("&")

      // MARK: 原廠辭典快速檢查

      if !config.isCassetteEnabled
        || (config.isCassetteEnabled && (keyArray.first?.hasPrefix("_") ?? false)) {
        if containsAlternatives {
          if !factoryChoppedCoreUnigramsFor(keyArray: keyArray, strategy: .configuredLookup).isEmpty {
            return true
          }
        } else {
          if hasFactoryCoreUnigramsFor(keyArray: keyArray) { return true }
        }

        if keyChain.hasPrefix("_"), keyChain.count > 1,
           !factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataMISC).isEmpty {
          return true
        }

        if config.isCNSEnabled,
           !factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataCNS).isEmpty {
          return true
        }

        if !config.bypassUserPhrasesData, config.isSymbolEnabled,
           !config.isCassetteEnabled,
           !factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataSYMB).isEmpty {
          return true
        }
      }

      // MARK: User data / cassette 檢查（tone bucket 需展開 alternatives）

      if containsAlternatives {
        for expandedKeyArray in expandAlternativeKeyArrays(from: keyArray) {
          let expandedKeyChain = expandedKeyArray.joined(separator: "-")
          if !config.bypassUserPhrasesData {
            if lmUserPhrases.hasUnigramsFor(key: expandedKeyChain) { return true }
            if config.isSymbolEnabled, lmUserSymbols.hasUnigramsFor(key: expandedKeyChain) { return true }
          }
          if config.isCassetteEnabled, Self.lmCassette.hasUnigramsFor(key: expandedKeyChain) { return true }
        }
      } else {
        let keyChain = keyArray.joined(separator: "-")
        if !config.bypassUserPhrasesData {
          if lmUserPhrases.hasUnigramsFor(key: keyChain) { return true }
          if config.isSymbolEnabled, lmUserSymbols.hasUnigramsFor(key: keyChain) { return true }
        }
        if config.isCassetteEnabled, Self.lmCassette.hasUnigramsFor(key: keyChain) { return true }
      }

      return false
    }

    /// 根據給定的索引鍵和資料值，確認是否有該具體的資料值在庫。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。
    ///   - value: 資料值。
    ///   - factoryDictionaryOnly: 是否僅自原廠辭典確認在庫。
    /// - Returns: 是否在庫。
    public func hasKeyValuePairFor(
      keyArray: [String],
      value: String,
      factoryDictionaryOnly: Bool = false
    )
      -> Bool {
      factoryDictionaryOnly
        ? factoryCoreUnigramsFor(
          key: keyArray.joined(separator: "-"),
          keyArray: keyArray
        )
        .map(\.current)
        .contains(value)
        : unigramsFor(keyArray: keyArray).map(\.current).contains(value)
    }

    /// 根據給定的索引鍵，確認有多少筆資料值在庫。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。
    ///   - factoryDictionaryOnly: 是否僅統計原廠辭典。
    /// - Returns: 是否在庫。
    public func countKeyValuePairs(keyArray: [String], factoryDictionaryOnly: Bool = false) -> Int {
      factoryDictionaryOnly
        ? factoryCoreUnigramsFor(key: keyArray.joined(separator: "-"), keyArray: keyArray).count
        : unigramsFor(keyArray: keyArray).count
    }

    /// 給定讀音索引鍵陣列，讓 LMI 給出對應的經過處理的單元圖陣列。
    /// - Parameter keyArray: 給定的讀音索引鍵陣列。
    /// - Returns: 對應的經過處理的單元圖陣列。
    public func unigramsFor(keyArray: [String]) -> [Homa.Gram] {
      // `config.bypassUserPhrasesData` 啟用時，除了 Associated Phrases 以外的資料全部忽略。
      let keyChain = keyArray.joined(separator: "-")
      let noEmptyKey = !keyArray.isEmpty && keyArray.allSatisfy { !$0.isEmpty }
      guard noEmptyKey else { return [] }
      /// 給空格鍵指定輸出值。
      let asciiSpace = " "
      if keyArray == [asciiSpace] { return [.init(keyArray: keyArray, value: asciiSpace)] }
      if keyArray.joined().contains("&") {
        return mergedAlternativeBucketUnigrams(for: keyArray)
      }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Homa.Gram] = []
      var factoryCoreUnigramsResult: [Homa.Gram] = []

      if !config.isCassetteEnabled
        || config.isCassetteEnabled && (keyArray.first?.hasPrefix("_") ?? false) {
        // 先給出 NumPad 的結果。
        rawAllUnigrams += supplyNumPadUnigrams(key: keyChain, keyArray: keyArray)
        // 注音文資料等雜項資料。LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
        rawAllUnigrams += factoryUnigramsFor(
          key: keyChain,
          keyArray: keyArray,
          column: .theDataCHEW
        )
        // `_` 開頭的特殊 key（標點、半形標點、特殊符號）存放在 MISC 欄位。
        if keyChain.hasPrefix("_"), keyChain.count > 1 {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: keyArray,
            column: .theDataMISC
          )
        }
        // 原廠核心辭典內容。
        factoryCoreUnigramsResult = factoryCoreUnigramsFor(
          key: keyChain,
          keyArray: keyArray
        )
        // 如果是繁體中文、且有開啟 CNS11643 全字庫讀音過濾開關的話，對原廠核心辭典內容追加過濾處理：
        if config.filterNonCNSReadings, !isCHS {
          // 對單個漢字（keyArray.count == 1）的不合規 Unigram 僅 demote score 至 -9.5，而非濾除。
          if keyArray.count == 1 {
            factoryCoreUnigramsResult = factoryCoreUnigramsResult.map { thisUnigram in
              guard !checkCNSConformation(for: thisUnigram, keyArray: keyArray) else { return thisUnigram }
              return .init(keyArray: thisUnigram.keyArray, value: thisUnigram.current, score: -9.5)
            }
          } else {
            factoryCoreUnigramsResult.removeAll { thisUnigram in
              !checkCNSConformation(for: thisUnigram, keyArray: keyArray)
            }
          }
        }
        // 正式追加原廠核心辭典檢索結果。
        rawAllUnigrams += factoryCoreUnigramsResult

        if config.isCNSEnabled {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: keyArray,
            column: .theDataCNS
          )
        }
      }

      if !config.bypassUserPhrasesData, config.isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: keyChain, keyArray: keyArray)
        if !config.isCassetteEnabled {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: keyArray,
            column: .theDataSYMB
          )
        }
      }

      // 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
      // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
      // 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
      if !config.bypassUserPhrasesData {
        let allowBoostingSingleKanji = config.allowRescoringSingleKanjiCandidates
        let factorySingleReadingValueHashes: Set<Int> = factoryCoreUnigramsResult.reduce(into: []) {
          if $1.keyArray.count == 1 { $0.insert($1.hashValue) }
        }
        var userPhraseUnigrams = Array(
          lmUserPhrases.unigramsFor(
            key: keyChain,
            keyArray: keyArray,
            omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
            factorySingleReadingValueHashes: factorySingleReadingValueHashes
          ).reversed()
        )
        if keyArray.count == 1, let topScore = rawAllUnigrams.lazy.map(\.probability).max() {
          // 不再讓使用者自己加入的單漢字讀音權重進入組句體系。
          userPhraseUnigrams = userPhraseUnigrams.map { currentUnigram in
            Homa.Gram(
              keyArray: keyArray,
              value: currentUnigram.current,
              score: Swift.min(topScore + 0.000114514, currentUnigram.probability)
            )
          }
        }
        rawAllUnigrams = userPhraseUnigrams + rawAllUnigrams
      }

      // 定期清理 InputToken HashMap 以防止記憶體洩漏
      cleanupInputTokenHashMapIfNeeded()

      // 分析且處理可能存在的 InputToken（in-place 展開，避免双重陣列）。
      var expandedUnigrams: [Homa.Gram] = []
      expandedUnigrams.reserveCapacity(rawAllUnigrams.count)
      for unigram in rawAllUnigrams {
        let convertedValues = unigram.current.parseAsInputToken(isCHS: isCHS)
        if convertedValues.isEmpty {
          expandedUnigrams.append(unigram)
        } else {
          for (absDelta, value) in convertedValues.enumerated() {
            let newScore: Double = -80 - Double(absDelta) * 0.01
            expandedUnigrams.append(.init(keyArray: keyArray, value: value, score: newScore))
            let hashKey = "\(keyChain)\t\(value)".hashValue
            inputTokenHashesArray.insert(hashKey)
          }
        }
      }
      rawAllUnigrams = expandedUnigrams

      if config.isCassetteEnabled {
        rawAllUnigrams.insert(
          contentsOf: Self.lmCassette.unigramsFor(key: keyChain, keyArray: keyArray),
          at: 0
        )
      } else if config.isSCPCEnabled || config.alwaysSupplyETenDOSUnigrams {
        // 追加倚天中文 DOS 候選字排序。
        rawAllUnigrams += Self.lmPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
          Homa.Gram(
            keyArray: keyArray,
            value: $0,
            score: config.isSCPCEnabled ? 0 : -9.5
          )
        }
      }

      // 新增與日期、時間、星期有關的單元圖資料。
      rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: keyChain, keyArray: keyArray))

      if keyChain == "_punctuation_list" {
        rawAllUnigrams.append(contentsOf: getHaninSymbolMenuUnigrams())
      }

      // 提前處理語彙置換。
      if !config.bypassUserPhrasesData, config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let oldUnigram = rawAllUnigrams[i]
          let newValue = lmReplacements.valuesFor(key: oldUnigram.current)
          guard !newValue.isEmpty else { continue }
          let newUnigram = Homa.Gram(
            keyArray: oldUnigram.keyArray,
            value: newValue,
            score: oldUnigram.probability
          )
          rawAllUnigrams[i] = newUnigram
        }
      }

      // 讓單元圖陣列自我過濾。在此基礎之上，對於相同詞值的多個單元圖，僅保留權重最大者。
      let dataAsFilter: Set<String> = config.bypassUserPhrasesData
        ? []
        : .init(
          lmFiltered.unigramsFor(key: keyChain, keyArray: keyArray).map(\.current)
        )
      rawAllUnigrams.consolidate(filter: dataAsFilter)
      return rawAllUnigrams
    }

    // MARK: Internal

    /// 介紹一下幾個通用的語言模組型別：
    /// ----------------------
    /// LMCoreEX 是全功能通用型的模組，每一筆辭典記錄以 key 為注音、以 [Unigram] 陣列作為記錄內容。
    /// 比較適合那種每筆記錄都有不同的權重數值的語言模組，雖然也可以強制施加權重數值就是了。
    /// LMCoreEX 的辭典陣列不承載 Unigram 本體、而是承載索引範圍，這樣可以節約記憶體。
    /// 一個 LMCoreEX 就可以滿足唯音幾乎所有語言模組副本的需求，當然也有這兩個例外：
    /// LMReplacements 與 LMAssociates 分別擔當語彙置換表資料與使用者關聯詞語的資料承載工作。
    /// 但是，LMCoreEX 對 2010-2013 年等舊 mac 機種而言，讀取速度異常緩慢。
    /// 於是 LMCoreJSON 就出場了，專門用來讀取原廠的 JSON 格式的辭典。

    // 磁帶資料模組。「currentCassette」對外唯讀，僅用來讀取磁帶本身的中繼資料（Metadata）。
    static var lmCassette = LMCassette()
    static var lmPlainBopomofo = LMPlainBopomofo()

    nonisolated static var factoryTrie: VanguardTrie.TextMapTrie? {
      get {
        mtxFactoryTrie.value
      }
      set {
        mtxFactoryTrie.value = newValue
      }
    }

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lmUserPhrases = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in
        0
      },
      forceDefaultScore: false
    )
    var lmFiltered = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in 0 },
      forceDefaultScore: true
    )
    var lmUserSymbols = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in -12.0 },
      forceDefaultScore: true
    )
    var lmReplacements = LMReplacements()
    var lmAssociates = LMAssociates()

    // LXPerceptor（NSMutex 保證執行緒安全，故標記 nonisolated）
    nonisolated var lxPerceptor: LXPerceptor {
      get { mtxLXPerceptor.value }
      set { mtxLXPerceptor.value = newValue }
    }

    // 確保關聯詞語資料在首次剛需時得以即時載入。
    internal func ensureAssociatesLoaded() {
      if !lmAssociates.isLoaded {
        let wasAsync = Self.asyncLoadingUserData
        Self.asyncLoadingUserData = false
        Self.associatesLazyLoader?()
        Self.asyncLoadingUserData = wasAsync
      }
    }

    /// Allows unit tests to mutate individual sub-language models without exposing them publicly.
    /// The provided closures receive mutable references to the backing instances; pass `nil` to leave a store untouched.
    ///
    /// Dev notes: Switching that guard to `#if canImport(Testing) || canImport(XCTest)`
    /// would actually compile the block out in this target: the LangModelAssembly
    /// product doesn’t link either framework, so canImport evaluates to false and
    /// the helper disappears—tests wouldn’t see injectTestData at all.
    /// Keeping `#if DEBUG` (or introducing a dedicated -D flag you enable for tests)
    /// is safer: it remains available when you build in the debug/test configuration,
    /// but it still drops out of release binaries.
    /// - Parameters:
    ///   - userPhrases: Mutator for the user phrases store.
    ///   - userFilter: Mutator for the exclusion list store.
    ///   - userSymbols: Mutator for the symbol menu store.
    ///   - replacements: Mutator for the user replacements store.
    ///   - associates: Mutator for the associates store.
    ///   - lxPerceptor: Mutator for the LXPerceptor memory.
    func injectTestData(
      userPhrases: ((inout LMCoreEX) -> ())? = nil,
      userFilter: ((inout LMCoreEX) -> ())? = nil,
      userSymbols: ((inout LMCoreEX) -> ())? = nil,
      replacements: ((inout LMReplacements) -> ())? = nil,
      associates: ((inout LMAssociates) -> ())? = nil,
      lxPerceptor: ((inout LXPerceptor) -> ())? = nil
    ) {
      if let mutator = userPhrases {
        mutator(&lmUserPhrases)
      }
      if let mutator = userFilter {
        mutator(&lmFiltered)
      }
      if let mutator = userSymbols {
        mutator(&lmUserSymbols)
      }
      if let mutator = replacements {
        mutator(&lmReplacements)
      }
      if let mutator = associates {
        mutator(&lmAssociates)
      }
      if let mutator = lxPerceptor {
        mutator(&self.lxPerceptor)
      }
    }

    // MARK: Private

    private struct AlternativeKeyArrayIterator: IteratorProtocol {
      // MARK: Lifecycle

      init(alternativeColumns: [[String]]) {
        self.alternativeColumns = alternativeColumns
        self.indices = Array(repeating: 0, count: alternativeColumns.count)
        self.isDone = alternativeColumns.isEmpty || alternativeColumns.contains(where: \.isEmpty)
        self.seen = Set()
      }

      // MARK: Internal

      mutating func next() -> [String]? {
        while !isDone {
          let result = alternativeColumns.indices.map { alternativeColumns[$0][indices[$0]] }
          let joined = result.joined(separator: "-")

          // 推進到下一個組合
          var carry = true
          for i in (0 ..< indices.count).reversed() {
            if carry {
              indices[i] += 1
              if indices[i] >= alternativeColumns[i].count {
                indices[i] = 0
              } else {
                carry = false
              }
            }
          }
          if carry { isDone = true }

          if seen.insert(joined).inserted {
            return result
          }
        }
        return nil
      }

      // MARK: Private

      private let alternativeColumns: [[String]]
      private var indices: [Int]
      private var isDone: Bool
      private var seen: Set<String>
    }

    nonisolated private static let mtxFactoryTrie: NSMutex<VanguardTrie.TextMapTrie?> = .init(nil)

    nonisolated private let mtxLXPerceptor: NSMutex<LXPerceptor>

    // MARK: - 工具函式

    private let prefs = PrefMgr.sharedSansDidSetOps

    /// 合併單一位置含有多個讀音候選時的 full-match 檢索結果。
    ///
    /// 與舊版不同：原廠辭典 trie 查詢走 `keysChopped` 路徑，只做一次 trie 查詢（內部展開去重），
    /// 而非對每個笛卡爾積組合分別做完整原廠辭典查詢。非原廠辭典來源（使用者語彙、符號等）
    /// 仍需按展開後的 keyArray 逐一查詢，但這些是輕量級 hash table lookup。
    /// - Parameter keyArray: 可能包含 `&` alternatives 的讀音索引鍵陣列。
    /// - Returns: 合併並去重後的單元圖陣列。
    private func mergedAlternativeBucketUnigrams(for keyArray: [String]) -> [Homa.Gram] {
      var rawAllUnigrams: [Homa.Gram] = []
      var factoryCoreUnigramsResult: [Homa.Gram] = []

      if !config.isCassetteEnabled
        || config.isCassetteEnabled && (keyArray.first?.hasPrefix("_") ?? false) {
        rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataCHEW)
        let keyChain = keyArray.joined(separator: "-")
        if keyChain.hasPrefix("_"), keyChain.count > 1 {
          rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataMISC)
        }
        factoryCoreUnigramsResult = factoryChoppedCoreUnigramsFor(
          keyArray: keyArray,
          strategy: .configuredLookup
        )
        if config.filterNonCNSReadings, !isCHS {
          factoryCoreUnigramsResult = factoryCoreUnigramsResult.compactMap { thisUnigram in
            guard !checkCNSConformation(for: thisUnigram, keyArray: thisUnigram.keyArray) else {
              return thisUnigram
            }
            guard thisUnigram.keyArray.count == 1 else { return nil }
            return .init(
              keyArray: thisUnigram.keyArray,
              value: thisUnigram.current,
              score: -9.5
            )
          }
        }
        rawAllUnigrams += factoryCoreUnigramsResult

        if config.isCNSEnabled {
          rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: keyArray, column: .theDataCNS)
        }
      }

      let factoryCoreUnigramsByKeyArray: [String: [Homa.Gram]] = Dictionary(
        grouping: factoryCoreUnigramsResult,
        by: { $0.keyArray.joined(separator: "-") }
      )
      let topScoreByKeyArray: [String: Double] = rawAllUnigrams.reduce(into: [:]) { partialResult, current in
        let keyChain = current.keyArray.joined(separator: "-")
        let existingTopScore = partialResult[keyChain] ?? -.infinity
        if current.probability > existingTopScore {
          partialResult[keyChain] = current.probability
        }
      }

      var factoryLookupMemo: [String: [Homa.Gram]] = [:]

      func memoizedFactoryUnigrams(
        keyArray: [String],
        keyChain: String,
        column: LMAssembly.LMInstantiator.CoreColumn
      )
        -> [Homa.Gram] {
        let memoKey = "\(keyChain)|\(column.rawValue)"
        if let cached = factoryLookupMemo[memoKey] {
          return cached
        }
        let resolved = factoryUnigramsFor(key: keyChain, keyArray: keyArray, column: column)
        factoryLookupMemo[memoKey] = resolved
        return resolved
      }

      var deferredFilterByKeyArray: [String: Set<String>] = [:]
      for expandedKeyArray in expandAlternativeKeyArrays(from: keyArray) {
        let keyChain = expandedKeyArray.joined(separator: "-")
        let factoryCoreUnigramsForExpandedKey = factoryCoreUnigramsByKeyArray[keyChain] ?? []

        if !config.bypassUserPhrasesData, config.isSymbolEnabled,
           lmUserSymbols.hasUnigramsFor(key: keyChain) {
          rawAllUnigrams += lmUserSymbols.unigramsFor(key: keyChain, keyArray: expandedKeyArray)
        }
        if !config.bypassUserPhrasesData, config.isSymbolEnabled, !config.isCassetteEnabled {
          rawAllUnigrams += memoizedFactoryUnigrams(
            keyArray: expandedKeyArray,
            keyChain: keyChain,
            column: .theDataSYMB
          )
        }

        if !config.bypassUserPhrasesData, lmUserPhrases.hasUnigramsFor(key: keyChain) {
          let allowBoostingSingleKanji = config.allowRescoringSingleKanjiCandidates
          let factorySingleReadingValueHashes: Set<Int> = factoryCoreUnigramsForExpandedKey.reduce(into: []) {
            if $1.keyArray.count == 1 { $0.insert($1.hashValue) }
          }
          var userPhraseUnigrams = Array(
            lmUserPhrases.unigramsFor(
              key: keyChain,
              keyArray: expandedKeyArray,
              omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
              factorySingleReadingValueHashes: factorySingleReadingValueHashes
            ).reversed()
          )
          if expandedKeyArray.count == 1, let topScore = topScoreByKeyArray[keyChain] {
            userPhraseUnigrams = userPhraseUnigrams.map { currentUnigram in
              Homa.Gram(
                keyArray: expandedKeyArray,
                value: currentUnigram.current,
                score: Swift.min(topScore + 0.000114514, currentUnigram.probability)
              )
            }
          }
          rawAllUnigrams = userPhraseUnigrams + rawAllUnigrams
        }

        if config.isCassetteEnabled {
          rawAllUnigrams.insert(
            contentsOf: Self.lmCassette.unigramsFor(key: keyChain, keyArray: expandedKeyArray),
            at: 0
          )
        } else if config.isSCPCEnabled || config.alwaysSupplyETenDOSUnigrams {
          rawAllUnigrams += Self.lmPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
            Homa.Gram(keyArray: expandedKeyArray, value: $0, score: config.isSCPCEnabled ? 0 : -9.5)
          }
        }

        if Self.dateTimeKnownTriggers.contains(keyChain) {
          rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: keyChain, keyArray: expandedKeyArray))
        }

        if !config.bypassUserPhrasesData, lmFiltered.hasUnigramsFor(key: keyChain) {
          let dataAsFilter = Set(
            lmFiltered.unigramsFor(key: keyChain, keyArray: expandedKeyArray).map(\.current)
          )
          if !dataAsFilter.isEmpty {
            deferredFilterByKeyArray[keyChain, default: []].formUnion(dataAsFilter)
          }
        }
      }

      if !config.bypassUserPhrasesData, !deferredFilterByKeyArray.isEmpty {
        rawAllUnigrams.removeAll { gram in
          let keyChain = gram.keyArray.joined(separator: "-")
          guard let dataAsFilter = deferredFilterByKeyArray[keyChain] else { return false }
          return dataAsFilter.contains(gram.current)
        }
      }

      cleanupInputTokenHashMapIfNeeded()
      var expandedUnigrams: [Homa.Gram] = []
      expandedUnigrams.reserveCapacity(rawAllUnigrams.count)
      for unigram in rawAllUnigrams {
        let convertedValues = unigram.current.parseAsInputToken(isCHS: isCHS)
        if convertedValues.isEmpty {
          expandedUnigrams.append(unigram)
        } else {
          let keyChain = unigram.keyArray.joined(separator: "-")
          for (absDelta, value) in convertedValues.enumerated() {
            let newScore: Double = -80 - Double(absDelta) * 0.01
            expandedUnigrams.append(.init(keyArray: unigram.keyArray, value: value, score: newScore))
            let hashKey = "\(keyChain)\t\(value)".hashValue
            inputTokenHashesArray.insert(hashKey)
          }
        }
      }
      rawAllUnigrams = expandedUnigrams

      if !config.bypassUserPhrasesData, config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let oldUnigram = rawAllUnigrams[i]
          let newValue = lmReplacements.valuesFor(key: oldUnigram.current)
          guard !newValue.isEmpty else { continue }
          rawAllUnigrams[i] = Homa.Gram(
            keyArray: oldUnigram.keyArray,
            value: newValue,
            score: oldUnigram.probability
          )
        }
      }

      rawAllUnigrams.consolidate()
      return rawAllUnigrams
    }

    /// 將帶有 `&` alternatives 的讀音索引鍵陣列展開為所有可能的 full-match 組合。
    /// - Parameter keyArray: 可能包含 `&` alternatives 的讀音索引鍵陣列。
    /// - Returns: 展開後的所有 keyArray 組合；若原始輸入不含 `&`，則回傳自身作為唯一結果。
    private func expandAlternativeKeyArrays(from keyArray: [String]) -> AnySequence<[String]> {
      guard keyArray.contains(where: { $0.contains("&") }) else {
        return AnySequence([keyArray])
      }
      let alternativeColumns: [[String]] = keyArray.map { current in
        let split = current.split(separator: "&").map(\.description)
        return split.isEmpty ? [current] : split
      }
      return AnySequence {
        AlternativeKeyArrayIterator(alternativeColumns: alternativeColumns)
      }
    }

    /// 當 HashMap 過大時自動清理
    private func cleanupInputTokenHashMapIfNeeded() {
      // 超過 3000 條目就直接清空（Set 無法保留插入順序，故不做部分截斷）。
      if inputTokenHashesArray.count > 3_000 {
        inputTokenHashesArray.removeAll(keepingCapacity: true)
      }
    }
  }
}
