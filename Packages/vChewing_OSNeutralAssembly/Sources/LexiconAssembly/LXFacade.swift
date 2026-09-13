// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Shared
import SwiftExtension
import TrieKit

extension LXAssembly {
  typealias ScoreAssigner = (CandidateInState?) -> Double

  /// 語言模組副本化模組（LXFacade）自身統籌且整理來自
  /// 其它子模組的資料（包括使用者片語、繪文字模組、語彙濾除表、原廠語言模組等）。
  ///
  /// LXFacade 型別為與輸入法輸入調度模組直接溝通之唯一語言模組。當組字器開始根據給定的
  /// 讀音鏈構築語句時，LXFacade 會接收來自組字器的讀音、輪流檢查自身是否有可以匹配到的
  /// 單元圖結果，然後將結果整理為陣列、再回饋給組字器。
  ///
  /// LXFacade 還會在將單元圖結果整理成陣列時做出下述處理轉換步驟：
  ///
  /// 1. 獲取原始結果陣列。
  /// 2. 如果有原始結果也出現在濾除表當中的話，則自結果陣列丟棄這類結果。
  /// 3. 如果啟用了語彙置換的話，則對目前經過處理的結果陣列套用語彙置換。
  /// 4. 擁有相同讀音與詞語資料值的單元圖只會留下權重最大的那一筆，其餘重複值會被丟棄。
  ///
  /// LXFacade 會根據需要分別載入原廠語言模組和其他個別的子語言模組。LXFacade 本身不會記錄這些
  /// 語言模組的相關資料的存放位置，僅藉由參數來讀取相關訊息。
  public final class LXFacade {
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

    public struct Config: Hashable {
      /// 如果設定為 nil 的話，則不產生任何詞頻資料。
      /// true = 全形，false = 半形。
      public var numPadFWHWStatus: Bool?

      public var isCassetteEnabled = false
      public var isPhraseReplacementEnabled = false
      public var isCNSEnabled = false
      public var isSymbolEnabled = false
      public var isSCPCEnabled = false

      /// 消歧義：
      /// - 「倚天中文系統 Unigrams」特指倚天中文系統的輸入法所能敲的漢字、以及其特有的候選字排序。
      /// 台澎金馬有固定的一兩代人對這些順序都有終生無法扭轉的肌肉記憶。這也就是為什麼唯音輸入法單獨提供了這種 lexicon 的支援。
      /// - 「倚天傳統注音鍵盤佈局」是電腦鍵盤上的按鍵與注音符號的映射。「倚天26」也是這種映射。這些都是與 Tekkon Composer 有關的內容。
      public var alwaysSupplyETenDOSUnigrams = true

      /// 是否讓漸退記憶（POM）向組字引擎提供 n-gram（bigram／trigram，可能含 unigram）
      /// 統計資料——鏡像 `kFetchSuggestionsFromPerceptionOverrideModel` 主開關（P182 起
      /// POM 對組句的所有影響皆由此把守）。
      public var fetchSuggestionsFromPerceptionOverrideModel = true

      public var partialMatchEnabled = false
      public var filterNonCNSReadings = false
      public var filterFactoryKanjisOfNonCurrentInputMode = false
      public var deltaOfCalendarYears: Int = -2_000
      public var allowRescoringSingleKanjiCandidates = false
      public var bypassUserPhrasesData = false
      public var suppressFactoryUnigramsOfKanaSyllables = false
      /// 隨狂拼主開關（kFuriousTypingEnabled）同步：true 時抑制來自原廠辭典（TextMapTrie）的注音文資料。
      public var shouldSuppressFactoryZhuyinwenData = false
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
    /// 這讓下游呼叫端可比照 TrieHub 風格使用同一個 hub，而不是直接散落在 LXFacade 根型別上。
    public struct LXQuerier {
      // MARK: Lifecycle

      init(lxFacade: LXFacade) {
        self.lxFacade = lxFacade
      }

      // MARK: Public

      /// 目前已掛載的「額外」語言模組來源，依掛載順序。
      /// 原廠辭典與各使用者子模組不在此列——它們由 `LXFacade` 自身直接供給。
      public var mountedGramSuppliers: [any LexiconGramSupplierProtocol] {
        lxFacade.mountedGramSuppliers
      }

      public func associatedCandidates(forPairs pairs: [Homa.CandidatePair]) -> [Homa.CandidatePairRAW] {
        var inserted = Set<String>()
        var result: [Homa.CandidatePairRAW] = []
        pairs.forEach { pair in
          lxFacade.associatedPhrasesFor(pair: pair).forEach { current in
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
          if lxFacade.config.partialMatchEnabled {
            return LXFacade.lxPlainBopomofo.partiallyMatchedValuesFor(prefix: reading, isCHS: lxFacade.isCHS)
          }
          return LXFacade.lxPlainBopomofo.valuesFor(key: reading, isCHS: lxFacade.isCHS)
        case .exactMatch:
          return LXFacade.lxPlainBopomofo.valuesFor(key: reading, isCHS: lxFacade.isCHS)
        case .partialMatch:
          return LXFacade.lxPlainBopomofo.partiallyMatchedValuesFor(prefix: reading, isCHS: lxFacade.isCHS)
        }
      }

      public func grams(for keyArray: [Homa.PossibleKey]) -> [Homa.Gram] {
        lxFacade.unigramsFor(keyArray: keyArray, partiallyMatch: lxFacade.config.partialMatchEnabled)
      }

      /// 給定讀音索引鍵陣列（相容舊版 `[String]` 介面），回傳經處理的單元圖陣列。
      ///
      /// 與 `grams(for: [Homa.PossibleKey])` 的差異：本重載接受顯式的 `partiallyMatch` 參數，
      /// **不會**自動代入 `config.partialMatchEnabled`；預設 `false`（僅精確匹配）。
      public func grams(for keyArray: [String], partiallyMatch: Bool = false) -> [Homa.Gram] {
        lxFacade.unigramsFor(keyArray: keyArray, partiallyMatch: partiallyMatch)
      }

      /// 狂拼整詞簡拼查詢（R2-α）：給定「每位置的 & 連接前綴候選」，回傳整詞候選。
      ///
      /// 原廠辭典走「&」連讀有界路徑（逐位置 byte 前綴比對，恆為 partial 語義、與偏好無關）；
      /// 使用者片語走多位置前綴交集掃描（有界、訪問鍵數與乘積無關）。
      /// 依分數降冪排序、依詞值去重（保留分數最高者）。
      public func abbreviatedWordCandidates(keysChopped: [String]) -> [Homa.Gram] {
        lxFacade.abbreviatedWordCandidates(keysChopped: keysChopped)
      }

      /// 輕量版存在性檢查：跳過濾除表、語彙置換、InputToken 展開、DateTime、倚天排序等後處理。
      ///
      /// 語義關係：`hasGrams(for:) == false` ⇒ `hasUnigrams(for:) == false` 且 `grams(for:)` 必為空；
      /// 反之不必然（完整版可能在後處理階段把結果濾光）。
      public func hasGrams(for keyArray: [String]) -> Bool {
        lxFacade.hasUnigramsForFast(keyArray: keyArray)
      }

      /// 完整版存在性檢查：走完整查詢管線（含濾除表與語彙置換）。
      public func hasUnigrams(for keyArray: [String]) -> Bool {
        lxFacade.hasUnigramsFor(keyArray: keyArray)
      }

      /// 掛載額外的語言模組來源（多來源掛載）；其元圖會併入一般查詢結果。
      public func mountGramSupplier(_ supplier: any LexiconGramSupplierProtocol) {
        lxFacade.mountGramSupplier(supplier)
      }

      /// 卸載所有額外掛載的語言模組來源。
      public func unmountAllGramSuppliers() {
        lxFacade.unmountAllGramSuppliers()
      }

      // MARK: 使用者資料查詢

      /// 查詢語彙置換表對應的值。
      public func replacementValue(for key: String) -> String? {
        lxFacade.queryReplacementValue(key: key)
      }

      /// 該詞對是否落在使用者濾除表內。
      public func isPairFiltered(pair: Homa.CandidatePair) -> Bool {
        lxFacade.isPairFiltered(pair: pair)
      }

      /// 確認某具體詞對是否在庫。
      public func hasKeyValuePairFor(
        keyArray: [String],
        value: String,
        factoryDictionaryOnly: Bool = false
      )
        -> Bool {
        lxFacade.hasKeyValuePairFor(
          keyArray: keyArray,
          value: value,
          factoryDictionaryOnly: factoryDictionaryOnly
        )
      }

      /// 統計某索引鍵在庫的詞對筆數。
      public func countKeyValuePairs(keyArray: [String], factoryDictionaryOnly: Bool = false) -> Int {
        lxFacade.countKeyValuePairs(keyArray: keyArray, factoryDictionaryOnly: factoryDictionaryOnly)
      }

      // MARK: Fileprivate

      fileprivate let lxFacade: LXFacade
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

    public var lxQuerier: LXQuerier { .init(lxFacade: self) }

    public var isCassetteDataLoaded: Bool { Self.lxCassette.isLoaded }

    public static func setCassetCandidateKeyValidator(_ validator: @Sendable @escaping (String) -> Bool) {
      Self.lxCassette.candidateKeysValidator = validator
    }

    public static func loadCassetteData(path: String) {
      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          Self.lxCassette.clear()
          Self.lxCassette.open(path)
          vCLMLog("lxCassette: \(Self.lxCassette.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxCassette: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        // CIN 解析在背景佇列完成，僅在成功後把結果交回 MainActor。
        let validator = Self.lxCassette.candidateKeysValidator
        LXAssembly.fileHandleQueue.async {
          guard FileManager.default.isReadableFile(atPath: path) else {
            vCLMLog("lxCassette: File access failure: \(path)")
            return
          }
          var newCassette = LXCassette()
          newCassette.candidateKeysValidator = validator
          newCassette.open(path)
          let count = newCassette.count
          asyncOnMain {
            Self.lxCassette = newCassette
            vCLMLog("lxCassette: \(count) entries of data loaded from: \(path)")
          }
        }
      }
    }

    // MARK: Shared Resource Lifecycle

    public static func resetSharedResources(restoreAsyncLoadingStrategy: Bool = true) {
      disconnectFactoryDictionary()
      lxCassette = LXCassette()
      lxPlainBopomofo = LXPlainBopomofo()
      guard restoreAsyncLoadingStrategy else { return }
      asyncLoadingUserData = !UserDefaults.pendingUnitTests
    }

    /// 清除原廠辭典的所有 QueryBuffer 快取。
    /// 應在適當的時機呼叫，避免舊查詢結果污染新的查詢。
    public static func flushTrieCaches() {
      factoryTrie?.flushCaches()
    }

    /// 釋放原廠辭典反查索引佔用的記憶體。
    /// 關閉獨立 RevLookup 視窗後可呼叫；下次反查會自動重新建立。
    public static func flushFactoryReverseLookupIndex() {
      factoryTrie?.flushReverseLookupIndex()
    }

    /// 預先建立原廠辭典反查索引。
    /// 在 RevLookup 視窗顯示時呼叫，使首次查詢無需等待 lazy build。
    public static func preloadFactoryReverseLookupIndex() {
      factoryTrie?.ensureReverseLookupIndex()
    }

    @discardableResult
    public func setOptions(handler: (inout Config) -> ()) -> LXFacade {
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
      config.filterFactoryKanjisOfNonCurrentInputMode = prefs.filterFactoryKanjisOfNonCurrentInputMode
      config.deltaOfCalendarYears = prefs.deltaOfCalendarYears
      config.allowRescoringSingleKanjiCandidates = prefs.allowRescoringSingleKanjiCandidates
      config.alwaysSupplyETenDOSUnigrams = prefs.enforceETenDOSCandidateSequence || prefs.useSCPCTypingMode
      config.fetchSuggestionsFromPerceptionOverrideModel = prefs.fetchSuggestionsFromPerceptionOverrideModel
      config.bypassUserPhrasesData = prefs.userPhrasesDatabaseBypassed
      config.suppressFactoryUnigramsOfKanaSyllables = prefs.suppressFactoryUnigramsOfKanaSyllables
      config.shouldSuppressFactoryZhuyinwenData = prefs.furiousTypingEnabled && prefs.pinyinTypingEnabled
    }

    /// 清除 InputToken HashMap。
    /// 注意：此 HashMap 僅記錄由 InputToken（以 "MACRO@" 開頭的特殊標記）生成的 Unigram。
    public func purgeInputTokenHashMap() {
      inputTokenHashesArray.removeAll()
    }

    /// 清除所有使用者來源的資料（片語、濾除表、符號、關聯詞、置換表、LRU 快取、InputToken 雜湊）。
    /// 不影響原廠辭典（factoryTrie）與漸退記憶模組（lxPerceptor）。
    /// 在切換使用者片語辭典目錄時必須呼叫此方法，以確保舊目錄的資料不會殘留。
    public func purgeUserData() {
      lxUserPhrases.clear()
      lxFiltered.clear()
      lxUserSymbols.clear()
      lxAssociates.clear()
      lxReplacements.clear()
      unigramLRUCache.removeAll(keepingCapacity: true)
      inputTokenHashesArray.removeAll(keepingCapacity: true)
    }

    public func loadUserPhrasesData(path: String, filterPath: String?, async: Bool? = nil) {
      // 無論新檔案是否可讀，都必須先清除舊資料，防止舊目錄內容殘留。
      lxUserPhrases.clear()
      lxFiltered.clear()
      unigramLRUCache.removeAll(keepingCapacity: true)

      let shouldAsync = async ?? Self.asyncLoadingUserData

      func loadMain() {
        if FileManager.default.isReadableFile(atPath: path) {
          lxUserPhrases.open(path)
          vCLMLog("lxUserPhrases: \(lxUserPhrases.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxUserPhrases: File access failure: \(path)")
        }
      }
      if !shouldAsync {
        loadMain()
      } else {
        LXAssembly.readFileContentAsync(
          path: path, shouldConsolidate: lxUserPhrases.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          LXAssembly.withFileHandleQueueSync {
            self.lxUserPhrases.replaceData(textData: content)
          }
          self.lxUserPhrases.filePath = path
          vCLMLog("lxUserPhrases: \(self.lxUserPhrases.count) entries of data loaded from: \(path)")
        }
      }
      guard let filterPath = filterPath else { return }
      func loadFilter() {
        if FileManager.default.isReadableFile(atPath: filterPath) {
          lxFiltered.open(filterPath)
          vCLMLog("lxFiltered: \(lxFiltered.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxFiltered: File access failure: \(path)")
        }
      }
      if !shouldAsync {
        loadFilter()
      } else {
        LXAssembly.readFileContentAsync(
          path: filterPath, shouldConsolidate: lxFiltered.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          LXAssembly.withFileHandleQueueSync {
            self.lxFiltered.replaceData(textData: content)
          }
          self.lxFiltered.filePath = filterPath
          vCLMLog("lxFiltered: \(self.lxFiltered.count) entries of data loaded from: \(filterPath)")
        }
      }
    }

    /// 這個函式不用 GCD。
    public func reloadUserFilterDirectly(path: String) {
      // 無論新檔案是否可讀，都必須先清除舊資料。
      lxFiltered.clear()
      unigramLRUCache.removeAll(keepingCapacity: true)

      if FileManager.default.isReadableFile(atPath: path) {
        lxFiltered.open(path)
        vCLMLog("lxFiltered: \(lxFiltered.count) entries of data loaded from: \(path)")
      } else {
        vCLMLog("lxFiltered: File access failure: \(path)")
      }
    }

    public func loadUserSymbolData(path: String) {
      // 無論新檔案是否可讀，都必須先清除舊資料。
      lxUserSymbols.clear()

      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lxUserSymbols.open(path)
          vCLMLog("lxUserSymbol: \(lxUserSymbols.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxUserSymbol: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        LXAssembly.readFileContentAsync(
          path: path, shouldConsolidate: lxUserSymbols.allowConsolidation
        ) { [weak self] content in
          guard let self else { return }
          LXAssembly.withFileHandleQueueSync {
            self.lxUserSymbols.replaceData(textData: content)
          }
          self.lxUserSymbols.filePath = path
          vCLMLog("lxUserSymbol: \(self.lxUserSymbols.count) entries of data loaded from: \(path)")
        }
      }
    }

    public func loadUserAssociatesData(path: String) {
      // 無論新檔案是否可讀，都必須先清除舊資料。
      lxAssociates.clear()

      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lxAssociates.open(path)
          vCLMLog("lxAssociates: \(lxAssociates.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxAssociates: File access failure: \(path)")
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
      // LXAssociates.open() 一律 consolidate。
      LXAssembly.readFileContentAsync(
        path: path, shouldConsolidate: true
      ) { [weak self] content in
        guard let self else { return }
        LXAssembly.withFileHandleQueueSync {
          self.lxAssociates.replaceData(textData: content)
        }
        self.lxAssociates.filePath = path
        vCLMLog("lxAssociates: \(self.lxAssociates.count) entries of data loaded from: \(path)")
      }
    }

    public func loadReplacementsData(path: String) {
      // 無論新檔案是否可讀，都必須先清除舊資料。
      lxReplacements.clear()

      func load() {
        if FileManager.default.isReadableFile(atPath: path) {
          lxReplacements.open(path)
          vCLMLog("lxReplacements: \(lxReplacements.count) entries of data loaded from: \(path)")
        } else {
          vCLMLog("lxReplacements: File access failure: \(path)")
        }
      }
      if !Self.asyncLoadingUserData {
        load()
      } else {
        // LXReplacements.open() 一律 consolidate，故 shouldConsolidate: true。
        LXAssembly.readFileContentAsync(
          path: path, shouldConsolidate: true
        ) { [weak self] content in
          guard let self else { return }
          LXAssembly.withFileHandleQueueSync {
            self.lxReplacements.replaceData(textData: content)
          }
          self.lxReplacements.filePath = path
          vCLMLog("lxReplacements: \(self.lxReplacements.count) entries of data loaded from: \(path)")
        }
      }
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
          ? lxFiltered.temporaryMap[keyChain, default: []].append(unigram)
          : lxUserPhrases.temporaryMap[keyChain, default: []].append(unigram)
      // LRU cache 必須在暫時資料變更時失效，否則後續查詢會返回過時結果。
      // 注意：cache key 已包含 partiallyMatch 標記，需同時清除兩種變體。
      unigramLRUCache.removeValue(forKey: "\(keyChain)\tPM0")
      unigramLRUCache.removeValue(forKey: "\(keyChain)\tPM1")
    }

    /// 該函式主要供單元測試所用。
    public func clearTemporaryData(isFiltering: Bool) {
      _ = isFiltering ? lxFiltered.clear() : lxUserPhrases.clear()
      // LRU cache 必須在暫時資料變更時失效，否則後續查詢會返回過時結果。
      unigramLRUCache.removeAll(keepingCapacity: true)
    }

    /// 自當前記憶體取得指定使用者子語言模組內的原始資料體。
    /// - Parameters:
    ///   - targetType: 操作對象。
    public func retrieveData(from targetType: ReplacableUserDataType) -> String {
      switch targetType {
      case .thePhrases: return lxUserPhrases.strData
      case .theFilter: return lxFiltered.strData
      case .theReplacements: return lxReplacements.strData
      case .theAssociates: return lxAssociates.strData
      case .theSymbols: return lxUserSymbols.strData
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
      LXConsolidator.consolidate(text: &rawText, pragma: true)
      switch targetType {
      case .theAssociates:
        lxAssociates.replaceData(textData: rawText)
        if save { lxAssociates.saveData() }
      case .theFilter:
        lxFiltered.replaceData(textData: rawText)
        if save { lxFiltered.saveData() }
      case .theReplacements:
        lxReplacements.replaceData(textData: rawText)
        if save { lxReplacements.saveData() }
      case .thePhrases:
        lxUserPhrases.replaceData(textData: rawText)
        if save { lxUserPhrases.saveData() }
      case .theSymbols:
        lxUserSymbols.replaceData(textData: rawText)
        if save { lxUserSymbols.saveData() }
      }
    }

    // MARK: Internal

    /// 介紹一下幾個通用的語言模組型別：
    /// ----------------------
    /// LXCoreEX 是全功能通用型的模組，每一筆辭典記錄以 key 為注音、以 [Unigram] 陣列作為記錄內容。
    /// 比較適合那種每筆記錄都有不同的權重數值的語言模組，雖然也可以強制施加權重數值就是了。
    /// LXCoreEX 的辭典陣列不承載 Unigram 本體、而是承載索引範圍，這樣可以節約記憶體。
    /// 一個 LXCoreEX 就可以滿足唯音幾乎所有語言模組副本的需求，當然也有這兩個例外：
    /// LXReplacements 與 LXAssociates 分別擔當語彙置換表資料與使用者關聯詞語的資料承載工作。
    /// 但是，LXCoreEX 對 2010-2013 年等舊 mac 機種而言，讀取速度異常緩慢。
    /// 於是 LXCoreJSON 就出場了，專門用來讀取原廠的 JSON 格式的辭典。

    // 磁帶資料模組。「currentCassette」對外唯讀，僅用來讀取磁帶本身的中繼資料（Metadata）。
    static var lxCassette = LXCassette()
    static var lxPlainBopomofo = LXPlainBopomofo()

    /// 原廠辭典世代計數器：每次原廠辭典被重新載入或解除安裝時遞增。
    /// 供 `unigramsFor` 的 LRU cache fingerprint 使用，確保切換原廠辭典後舊快取自動失效。
    nonisolated static let mtxFactoryGeneration: NSMutex<Int> = .init(0)

    /// 漸退記憶（POM）世代計數器：每次記憶內容變更（記憶／清除／漂白／載入）時遞增。
    /// 供 `unigramsFor` 的 LRU cache fingerprint 使用，確保 POM 更新後查詢即反映新記憶。
    nonisolated static let mtxPOMGeneration: NSMutex<Int> = .init(0)

    nonisolated static var factoryTrie: VanguardTrie.TextMapTrie? {
      get {
        mtxFactoryTrie.value
      }
      set {
        mtxFactoryTrie.value = newValue
        mtxFactoryGeneration.value &+= 1
      }
    }

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lxUserPhrases = LXCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in
        0
      },
      forceDefaultScore: false
    )
    var lxFiltered = LXCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in 0 },
      forceDefaultScore: true
    )
    var lxUserSymbols = LXCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: { _ in -12.0 },
      forceDefaultScore: true
    )
    var lxReplacements = LXReplacements()
    var lxAssociates = LXAssociates()

    /// 額外掛載的語言模組來源中樞（多來源掛載）。
    /// 預設為空，故對既有行為零影響；宿主可經由 `mountGramSupplier(_:)` 追加來源。
    let gramSupplyHub = LXGramSupplyHub()

    // LXPerceptor（NSMutex 保證執行緒安全，故標記 nonisolated）
    nonisolated var lxPerceptor: LXPerceptor {
      get { mtxLXPerceptor.value }
      set { mtxLXPerceptor.value = newValue }
    }

    // MARK: - 核心函式（對外）

    func hasAssociatedPhrasesFor(pair: Homa.CandidatePair) -> Bool {
      lxAssociates.hasValuesFor(pair: pair)
    }

    func associatedPhrasesFor(pair: Homa.CandidatePair) -> [String] {
      lxAssociates.valuesFor(pair: pair)
    }

    func queryReplacementValue(key: String) -> String? {
      let result = lxReplacements.valuesFor(key: key)
      return result.isEmpty ? nil : result
    }

    func isPairFiltered(pair: Homa.CandidatePair) -> Bool {
      lxFiltered
        .unigramsFor(key: pair.joinedKey(), keyArray: pair.keyArray)
        .map(\.current)
        .contains(pair.value)
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵陣列。
    /// - Returns: 是否在庫。
    func hasUnigramsFor(keyArray: [String]) -> Bool {
      let keyChain = keyArray.joined(separator: "-")
      // 因為涉及到對濾除清單的檢查，所以這裡必須走一遍 .unigramsFor()。
      // 以 2010 年的電腦效能作為基準參考來看的話，這方面的效能壓力可以忽略不計。
      return keyChain == " " || (!unigramsFor(keyArray: keyArray).isEmpty && !keyChain.isEmpty)
    }

    /// 輕量版 `hasUnigramsFor`，專供 Homa.Assembler 與 OSNeutralAssembly 層快速判定讀音是否存在。
    ///
    /// 與完整版 `hasUnigramsFor` 的差異：
    /// - 跳過濾除表、語彙置換、InputToken 展開、DateTime、倚天排序等「後處理」步驟。
    /// - user phrases / symbols / cassette 僅做 `hasUnigramsFor(key:)` hash lookup。
    ///
    /// 語義保證：若 `hasUnigramsForFast` 回傳 `false`，則 `hasUnigramsFor` / `unigramsFor` 必定也回傳空陣列；
    /// 若回傳 `true`，則 `unigramsFor` 至少會有一筆結果（可能在後處理階段被濾除，但 availability 意義上「存在」）。
    func hasUnigramsForFast(keyArray: [String]) -> Bool {
      let keyChain = keyArray.joined(separator: "-")
      guard keyChain != " ", !keyChain.isEmpty else { return keyChain == " " }
      let noEmptyKey = !keyArray.isEmpty && keyArray.allSatisfy { !$0.isEmpty }
      guard noEmptyKey else { return false }

      // MARK: 原廠辭典快速檢查

      if !config.isCassetteEnabled
        || (config.isCassetteEnabled && (keyArray.first?.hasPrefix("_") ?? false)) {
        // lxPlainBopomofo 包含所有合法 BPMF 讀音，此檢查與 alwaysSupplyETenDOSUnigrams 無關：
        // 該旗標控制的是候選字排序，而非讀音有效性。
        if keyArray.count == 1,
           let firstKey = keyArray.first,
           Self.lxPlainBopomofo.hasValuesFor(key: firstKey) {
          return true
        }

        if hasFactoryCoreUnigramsFor(keyArray: keyArray) { return true }

        // nonKanji: 若啟用假名抑制，須走完整查詢以正確過濾
        if config.suppressFactoryUnigramsOfKanaSyllables {
          if !factoryUnigramsFor(key: keyChain, keyArray: keyArray, entryType: .nonKanji).isEmpty {
            return true
          }
        } else if hasFactoryUnigramsFor(keyArray: keyArray, entryType: .nonKanji) {
          return true
        }

        if keyChain.hasPrefix("_"), keyChain.count > 1,
           hasFactoryChoppedUnigramsFor(keyArray: keyArray, entryType: .letterPunctuations) {
          return true
        }

        if config.isCNSEnabled,
           hasFactoryChoppedUnigramsFor(keyArray: keyArray, entryType: .cns)
           || hasFactoryChoppedUnigramsFor(keyArray: keyArray, entryType: .gbex) {
          return true
        }

        if !config.bypassUserPhrasesData, config.isSymbolEnabled,
           !config.isCassetteEnabled,
           hasFactoryChoppedUnigramsFor(keyArray: keyArray, entryType: .symbolPhrases) {
          return true
        }

        // 額外掛載的語言模組來源（多來源掛載）：預設為空，故對既有行為零影響。
        if mountedSuppliersHasGrams(keyArray: keyArray, partiallyMatch: config.partialMatchEnabled) {
          return true
        }
      }

      // MARK: User data / cassette 檢查

      if !config.bypassUserPhrasesData {
        if lxUserPhrases.hasUnigramsFor(key: keyChain) { return true }
        if config.isSymbolEnabled, lxUserSymbols.hasUnigramsFor(key: keyChain) { return true }
      }
      if config.isCassetteEnabled, Self.lxCassette.hasUnigramsFor(key: keyChain) { return true }

      // NumPad keys are dynamically generated by supplyNumPadUnigrams.
      if keyChain.hasPrefix("_NumPad_"), config.numPadFWHWStatus != nil { return true }

      return false
    }

    /// 根據給定的索引鍵和資料值，確認是否有該具體的資料值在庫。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。
    ///   - value: 資料值。
    ///   - factoryDictionaryOnly: 是否僅自原廠辭典確認在庫。
    /// - Returns: 是否在庫。
    func hasKeyValuePairFor(
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
    func countKeyValuePairs(keyArray: [String], factoryDictionaryOnly: Bool = false) -> Int {
      factoryDictionaryOnly
        ? factoryCoreUnigramsFor(key: keyArray.joined(separator: "-"), keyArray: keyArray).count
        : unigramsFor(keyArray: keyArray).count
    }

    /// 給定讀音索引鍵陣列，讓 LXFacade 給出對應的經過處理的單元圖陣列。
    /// - Parameter keyArray: 給定的讀音索引鍵陣列（相容舊版 [String] 介面）。
    /// - Returns: 對應的經過處理的單元圖陣列。
    func unigramsFor(keyArray: [String], partiallyMatch: Bool = false) -> [Homa.Gram] {
      unigramsFor(keyArray: keyArray.map { Homa.PossibleKey.singleKey($0) }, partiallyMatch: partiallyMatch)
    }

    /// 給定讀音索引鍵陣列，讓 LXFacade 給出對應的經過處理的單元圖陣列。
    /// - Parameters:
    ///   - keyArray: 給定的讀音索引鍵陣列。
    ///   - partiallyMatch: 是否對使用者片語啟用前綴部分匹配。
    /// - Returns: 對應的經過處理的單元圖陣列。
    func unigramsFor(keyArray: [Homa.PossibleKey], partiallyMatch: Bool) -> [Homa.Gram] {
      let hasAlternatives = keyArray.contains { $0.count > 1 }

      if hasAlternatives {
        return unigramsForWithAlternatives(keyArray: keyArray, partiallyMatch: partiallyMatch)
      }

      // Fast path: single key per position — use existing logic unchanged
      let flatKeyArray = keyArray.map(\.first)
      let keyChain = flatKeyArray.joined(separator: "-")
      let cacheKey = partiallyMatch ? "\(keyChain)\tPM1" : "\(keyChain)\tPM0"
      let noEmptyKey = !flatKeyArray.isEmpty && flatKeyArray.allSatisfy { !$0.isEmpty }
      guard noEmptyKey else { return [] }
      /// 給空格鍵指定輸出值。
      let asciiSpace = " "
      if flatKeyArray == [asciiSpace] { return [.init(keyArray: flatKeyArray, value: asciiSpace)] }
      // 檢查 LRU 快取
      var hasher = Hasher()
      hasher.combine(config)
      hasher.combine(Self.mtxFactoryGeneration.value)
      hasher.combine(Self.mtxPOMGeneration.value)
      hasher.combine(gramSupplyHub.generation)
      let fingerprint = hasher.finalize()
      if fingerprint != unigramCacheFingerprint {
        unigramLRUCache.removeAll(keepingCapacity: true)
        unigramCacheFingerprint = fingerprint
      }
      if let cached = unigramLRUCache[cacheKey] {
        return cached
      }
      // `config.bypassUserPhrasesData` 啟用時，除了 Associated Phrases 以外的資料全部忽略。
      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Homa.Gram] = []
      rawAllUnigrams.reserveCapacity(Swift.max(16, flatKeyArray.count * 8))
      var factoryCoreUnigramsResult: [Homa.Gram] = []

      if !config.isCassetteEnabled
        || config.isCassetteEnabled && (flatKeyArray.first?.hasPrefix("_") ?? false) {
        // 先給出 NumPad 的結果。
        rawAllUnigrams += supplyNumPadUnigrams(key: keyChain, keyArray: flatKeyArray)
        // 注音文資料等雜項資料。LXMisc 與 LXCore 的 score 在 (-10.0, 0.0) 這個區間內。
        rawAllUnigrams += factoryUnigramsFor(
          key: keyChain,
          keyArray: flatKeyArray,
          entryType: .zhuyinwen
        )
        // nonKanji 內容（假名、鴨蛋零等）對應普通讀音。
        rawAllUnigrams += factoryUnigramsFor(
          key: keyChain,
          keyArray: flatKeyArray,
          entryType: .nonKanji
        )
        // `_` 開頭的特殊 key（標點、半形標點、特殊符號）存放在 MISC 欄位。
        if keyChain.hasPrefix("_"), keyChain.count > 1 {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: flatKeyArray,
            entryType: .letterPunctuations
          )
        }
        // 原廠核心辭典內容。
        factoryCoreUnigramsResult = factoryCoreUnigramsFor(
          key: keyChain,
          keyArray: flatKeyArray
        )
        if config.filterNonCNSReadings, !isCHS {
          // 對單個漢字（flatKeyArray.count == 1）的不合規 Unigram 僅 demote score 至 -9.5，而非濾除。
          if flatKeyArray.count == 1 {
            factoryCoreUnigramsResult = factoryCoreUnigramsResult.map { thisUnigram in
              guard !checkCNSConformation(for: thisUnigram, keyArray: flatKeyArray) else { return thisUnigram }
              return .init(keyArray: thisUnigram.keyArray, value: thisUnigram.current, score: -9.5)
            }
          } else {
            factoryCoreUnigramsResult.removeAll { thisUnigram in
              !checkCNSConformation(for: thisUnigram, keyArray: flatKeyArray)
            }
          }
        }
        if config.filterFactoryKanjisOfNonCurrentInputMode, flatKeyArray.count == 1 {
          factoryCoreUnigramsResult.removeAll { thisUnigram in
            guard let firstChar = thisUnigram.current.first else { return false }
            // 查 contradictory mode（與當前模式相反）的特有字：
            //   CHT 模式 (isCHS=false) → 查簡體特有 (isCHS: true)
            //   CHS 模式 (isCHS=true)  → 查繁體特有 (isCHS: false)
            return Self.lxPlainBopomofo.isExclusive(
              isCHS: !isCHS,
              reading: keyChain,
              target: firstChar
            ) == true
          }
        }
        // 正式追加原廠核心辭典檢索結果。
        rawAllUnigrams += factoryCoreUnigramsResult

        if config.isCNSEnabled {
          rawAllUnigrams += supplementalCNSAndGBEXUnigramsFor(
            key: keyChain,
            keyArray: flatKeyArray
          )
        }
        // 額外掛載的語言模組來源（多來源掛載）：預設為空，故對既有行為零影響。
        rawAllUnigrams += mountedSupplierGrams(keyArray: flatKeyArray, partiallyMatch: partiallyMatch)
      }

      if !config.bypassUserPhrasesData, config.isSymbolEnabled {
        rawAllUnigrams += lxUserSymbols.unigramsFor(key: keyChain, keyArray: flatKeyArray)
        if !config.isCassetteEnabled {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: flatKeyArray,
            entryType: .symbolPhrases
          )
        }
      }

      if !config.bypassUserPhrasesData {
        let allowBoostingSingleKanji = config.allowRescoringSingleKanjiCandidates
        let factorySingleReadingValueHashes: Set<Int> = factoryCoreUnigramsResult.reduce(into: []) {
          if $1.keyArray.count == 1 { $0.insert($1.hashValue) }
        }
        var allUserPhraseUnigrams: [Homa.Gram] = []
        var userPhraseUnigrams: [Homa.Gram]
        if partiallyMatch {
          userPhraseUnigrams = Array(
            lxUserPhrases.unigramsFor(
              keyPrefix: keyChain,
              omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
              factorySingleReadingValueHashes: factorySingleReadingValueHashes
            ).reversed()
          )
        } else {
          userPhraseUnigrams = Array(
            lxUserPhrases.unigramsFor(
              key: keyChain,
              keyArray: flatKeyArray,
              omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
              factorySingleReadingValueHashes: factorySingleReadingValueHashes
            ).reversed()
          )
        }
        if flatKeyArray.count == 1, let topScore = rawAllUnigrams.lazy.map(\.probability).max() {
          userPhraseUnigrams = userPhraseUnigrams.map { currentUnigram in
            guard currentUnigram.keyArray.count == 1 else { return currentUnigram }
            return Homa.Gram(
              keyArray: currentUnigram.keyArray,
              value: currentUnigram.current,
              score: Swift.min(topScore + 0.000114514, currentUnigram.probability)
            )
          }
        }
        allUserPhraseUnigrams = userPhraseUnigrams
        rawAllUnigrams = allUserPhraseUnigrams + rawAllUnigrams
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
            expandedUnigrams.append(.init(keyArray: flatKeyArray, value: value, score: newScore))
            let hashKey = "\(keyChain)\t\(value)".hashValue
            inputTokenHashesArray.insert(hashKey)
          }
        }
      }
      rawAllUnigrams = expandedUnigrams

      if config.isCassetteEnabled {
        rawAllUnigrams.insert(
          contentsOf: Self.lxCassette.unigramsFor(key: keyChain, keyArray: flatKeyArray),
          at: 0
        )
      } else if config.isSCPCEnabled || config.alwaysSupplyETenDOSUnigrams {
        rawAllUnigrams += Self.lxPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
          Homa.Gram(
            keyArray: flatKeyArray,
            value: $0,
            score: config.isSCPCEnabled ? 0 : -9.5
          )
        }
      } else if rawAllUnigrams.isEmpty,
                keyArray.count == 1,
                Self.lxPlainBopomofo.hasValuesFor(key: keyChain) {
        // 原廠辭典查無此讀音、但 lxPlainBopomofo 確認為合法 BPMF 讀音時，
        // 附加低權重候選以履行 hasUnigramsForFast 的語義保證。
        rawAllUnigrams += Self.lxPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
          Homa.Gram(keyArray: flatKeyArray, value: $0, score: -9.5)
        }
      }

      rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: keyChain, keyArray: flatKeyArray))

      if keyChain == "_punctuation_list" {
        rawAllUnigrams.append(contentsOf: getHaninSymbolMenuUnigrams())
      }

      // 提前處理語彙置換。
      if !config.bypassUserPhrasesData, config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let oldUnigram = rawAllUnigrams[i]
          let newValue = lxReplacements.valuesFor(key: oldUnigram.current)
          guard !newValue.isEmpty else { continue }
          let newUnigram = Homa.Gram(
            keyArray: oldUnigram.keyArray,
            value: newValue,
            score: oldUnigram.probability
          )
          rawAllUnigrams[i] = newUnigram
        }
      }

      let dataAsFilter: Set<String> = config.bypassUserPhrasesData
        ? []
        : .init(
          lxFiltered.unigramsFor(key: keyChain, keyArray: flatKeyArray).lazy.map(\.current)
        )
      rawAllUnigrams.consolidate(filter: dataAsFilter)
      rawAllUnigrams.sort { $0.probability > $1.probability }
      // POM 記憶作為 n-gram 統計來源（S2）：附加於 unigram 之後、不經 consolidate
      // （避免與同名 unigram 去重互擾）。僅餵「帶前後文」的 contextual 記憶——bare unigram
      // 記憶對 DP 無貢獻（節點 unigramScore 取陣列首筆、不選中尾端注入）且會污染選字窗
      // 原始候選清單（fetchCandidates 僅排除 contextual grams）；unigram 記憶改由
      // OSNeutralAssembly 建議通道浮現（受 fetch／「固定順序」等把守）。
      if config.fetchSuggestionsFromPerceptionOverrideModel {
        let pomGrams = lxPerceptor.perceptionsFor(
          headReading: keyChain, timestamp: Date().timeIntervalSince1970
        ).compactMap { pom -> Homa.Gram? in
          guard pom.previous != nil || pom.anterior != nil else { return nil }
          return Homa.Gram(
            keyArray: pom.headReading.split(separator: "-").map(String.init),
            current: pom.candidate,
            previous: pom.previous, anterior: pom.anterior,
            probability: pom.probability
          )
        }
        rawAllUnigrams.append(contentsOf: pomGrams)
      }
      // Store in LRU cache with size limit
      unigramLRUCache[cacheKey] = rawAllUnigrams
      if unigramLRUCache.count > 1_024 {
        let half = unigramLRUCache.count / 2
        let keysToRemove = Array(unigramLRUCache.keys.prefix(half))
        keysToRemove.forEach { unigramLRUCache.removeValue(forKey: $0) }
      }
      return rawAllUnigrams
    }

    // 確保關聯詞語資料在首次剛需時得以即時載入。
    internal func ensureAssociatesLoaded() {
      if !lxAssociates.isLoaded {
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
    /// would actually compile the block out in this target: the LexiconAssembly
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
      userPhrases: ((inout LXCoreEX) -> ())? = nil,
      userFilter: ((inout LXCoreEX) -> ())? = nil,
      userSymbols: ((inout LXCoreEX) -> ())? = nil,
      replacements: ((inout LXReplacements) -> ())? = nil,
      associates: ((inout LXAssociates) -> ())? = nil,
      lxPerceptor: ((inout LXPerceptor) -> ())? = nil
    ) {
      if let mutator = userPhrases {
        mutator(&lxUserPhrases)
      }
      if let mutator = userFilter {
        mutator(&lxFiltered)
      }
      if let mutator = userSymbols {
        mutator(&lxUserSymbols)
      }
      if let mutator = replacements {
        mutator(&lxReplacements)
      }
      if let mutator = associates {
        mutator(&lxAssociates)
      }
      if let mutator = lxPerceptor {
        mutator(&self.lxPerceptor)
      }
      // injectTestData 直接修改 sub-LM，必須使 LRU cache 失效。
      unigramLRUCache.removeAll(keepingCapacity: true)
    }

    /// 狂拼整詞簡拼查詢（R2-α）。
    ///
    /// 給定「每位置的 & 連接前綴候選」（如 `["ㄧ&ㄩ","ㄕ&ㄙ","ㄒ","ㄅ"]`），
    /// 回傳可能的整詞候選。候選分區：置頂整詞猜測（factory 命中詞之首）→ 其餘
    /// factory「&」命中詞（逐位置 byte 前綴、恆為 partial 語義、與 `partialMatchEnabled`
    /// 偏好無關）→ user-phrase 命中詞（多位置前綴交集掃描、有界）。各分區依分數降冪、
    /// 依詞值去重（保留先出現者＝factory 優先）。
    func abbreviatedWordCandidates(keysChopped: [String]) -> [Homa.Gram] {
      guard !keysChopped.isEmpty, keysChopped.allSatisfy({ !$0.isEmpty }) else { return [] }
      var factoryGrams: [Homa.Gram] = []
      var userGrams: [Homa.Gram] = []
      let entryType: VanguardTrie.Trie.EntryType = isCHS ? .chs : .cht
      // 原廠辭典：「&」連讀、逐位置 byte 前綴（恆為 partial 語義）。
      factoryGrams = factoryChoppedUnigramsFor(
        keyArray: keysChopped, entryType: entryType, partiallyMatch: true
      )
      // 使用者片語：多位置前綴交集掃描（有界、訪問鍵數與乘積無關）。
      if !config.bypassUserPhrasesData {
        let prefixCells = keysChopped.map { cell in cell.split(separator: "&").map(String.init) }
        if prefixCells.allSatisfy({ !$0.isEmpty }) {
          let factorySingleReadingValueHashes: Set<Int> = factoryGrams.reduce(into: []) {
            if $1.keyArray.count == 1 { $0.insert($1.hashValue) }
          }
          userGrams = lxUserPhrases.unigramsFor(
            keyPrefixesByPosition: prefixCells,
            omitNonTemporarySingleCharNonSymbolUnigrams: !config.allowRescoringSingleKanjiCandidates,
            factorySingleReadingValueHashes: factorySingleReadingValueHashes
          )
        }
      }
      // 依詞值去重（保留先出現者＝factory 優先）、各分區依分數降冪排序。
      var seenValues = Set<String>()
      var result: [Homa.Gram] = []
      for gram in factoryGrams.sorted(by: { $0.probability > $1.probability }) + userGrams
        .sorted(by: { $0.probability > $1.probability }) {
        guard !gram.current.isEmpty else { continue }
        guard seenValues.insert(gram.current).inserted else { continue }
        result.append(gram)
      }
      return result
    }

    // MARK: Private

    nonisolated private static let mtxFactoryTrie: NSMutex<VanguardTrie.TextMapTrie?> = .init(nil)

    /// 笛卡爾積爆炸防禦預算上限。
    ///
    /// 當一個查詢的展開組合數量超過此值時，放棄逐組合展開、只保留原廠辭典的
    /// "&" 連讀查詢路徑，以避免在查詢過程中被笛卡爾積卡死（例如狂拼模式下的
    /// 不完全拼寫）。此閾值與 Homa 組字器的防禦閾值一致（625，P167 依末代
    /// Intel 硬體實測再校準：4,000 仍卡、625（=5⁴）順暢——維持免聲調 4 音節查詢）。
    nonisolated private static let kCartesianProductBudgetLimit = 625

    // LRU cache for unigramsFor
    private var unigramCacheFingerprint: Int = 0
    private var unigramLRUCache: [String: [Homa.Gram]] = [:]

    nonisolated private let mtxLXPerceptor: NSMutex<LXPerceptor>

    // MARK: - 工具函式

    private let prefs = PrefMgr.sharedSansDidSetOps

    /// 計算給定 PossibleKey 陣列的笛卡爾積展開總數（飽和計算、超過預算即早停）。
    private static func cartesianProductBudget(_ keyArray: [Homa.PossibleKey]) -> Int {
      var product = 1
      for pk in keyArray {
        let count = pk.count
        guard count > 1 else { continue }
        if product > Self.kCartesianProductBudgetLimit / count {
          return Self.kCartesianProductBudgetLimit + 1
        }
        product *= count
      }
      return product
    }

    /// 展開含有替代讀音的 PossibleKey 陣列為個別鍵陣列組合。
    /// 例如 [.multipleKeys(["ㄕ","ㄙ"]), .singleKey("ㄨ")] → [["ㄕ","ㄨ"], ["ㄙ","ㄨ"]]
    private static func expandPossibleKeyArrays(_ keyArray: [Homa.PossibleKey]) -> [[String]] {
      var result: [[String]] = [[]]
      for pk in keyArray {
        let alts = pk.allValues
        var newResult: [[String]] = []
        newResult.reserveCapacity(result.count * alts.count)
        for prefix in result {
          for alt in alts {
            newResult.append(prefix + [alt])
          }
        }
        result = newResult
      }
      return result
    }

    /// 處理含替代讀音的鍵陣列查詢。
    /// 對原廠辭典 trie 使用 chopped（"&" 連接）路徑，對使用者資料使用展開路徑。
    private func unigramsForWithAlternatives(keyArray: [Homa.PossibleKey], partiallyMatch: Bool) -> [Homa.Gram] {
      let flatKeyArray = keyArray.map(\.first)
      let keyChain = flatKeyArray.joined(separator: "-")
      let cacheKey = "ALT\t\(keyArray.hashValue)"
      let noEmptyKey = !flatKeyArray.isEmpty && flatKeyArray.allSatisfy { !$0.isEmpty }
      guard noEmptyKey else { return [] }
      // 檢查 LRU 快取
      var hasher = Hasher()
      hasher.combine(config)
      hasher.combine(Self.mtxFactoryGeneration.value)
      hasher.combine(Self.mtxPOMGeneration.value)
      hasher.combine(gramSupplyHub.generation)
      let fingerprint = hasher.finalize()
      if fingerprint != unigramCacheFingerprint {
        unigramLRUCache.removeAll(keepingCapacity: true)
        unigramCacheFingerprint = fingerprint
      }
      if let cached = unigramLRUCache[cacheKey] {
        return cached
      }
      // 展開替代讀音陣列（供非原廠辭典查詢使用）。
      // 若笛卡爾積展開總量超過預算，則放棄展開、只保留原廠辭典的 "&" 連讀查詢路徑，
      // 以免在查詢過程中被笛卡爾積卡死（例如狂拼模式下的不完全拼寫）。
      let cartesianBudgetExceeded = Self.cartesianProductBudget(keyArray) > Self.kCartesianProductBudgetLimit
      let expandedKeyArrays = cartesianBudgetExceeded ? [] : Self.expandPossibleKeyArrays(keyArray)
      // 原廠辭典使用 chopped 路徑（"&" 連接，發生在這裡，一次查詢）
      let choppedKeyArray = keyArray.map { $0.allValues.joined(separator: "&") }

      var rawAllUnigrams: [Homa.Gram] = []
      var factoryCoreUnigramsResult: [Homa.Gram] = []

      if !config.isCassetteEnabled
        || config.isCassetteEnabled && (flatKeyArray.first?.hasPrefix("_") ?? false) {
        rawAllUnigrams += supplyNumPadUnigrams(key: keyChain, keyArray: flatKeyArray)
        rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: choppedKeyArray, entryType: .zhuyinwen)
        rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: choppedKeyArray, entryType: .nonKanji)
        if keyChain.hasPrefix("_"), keyChain.count > 1 {
          rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: choppedKeyArray, entryType: .letterPunctuations)
        }
        factoryCoreUnigramsResult = factoryChoppedCoreUnigramsFor(
          keyArray: choppedKeyArray,
          strategy: .configuredLookup
        )
        // 笛卡爾預算超閾時，展開組合不可用，無法做 CNS 讀音比對，跳過此過濾。
        if config.filterNonCNSReadings, !isCHS, !cartesianBudgetExceeded {
          if flatKeyArray.count == 1 {
            factoryCoreUnigramsResult = factoryCoreUnigramsResult.map { unigram in
              guard expandedKeyArrays.contains(where: { checkCNSConformation(for: unigram, keyArray: $0) }) else {
                return .init(keyArray: unigram.keyArray, value: unigram.current, score: -9.5)
              }
              return unigram
            }
          } else {
            factoryCoreUnigramsResult.removeAll { unigram in
              !expandedKeyArrays.contains(where: { checkCNSConformation(for: unigram, keyArray: $0) })
            }
          }
        }
        if config.filterFactoryKanjisOfNonCurrentInputMode, flatKeyArray.count == 1 {
          factoryCoreUnigramsResult.removeAll { thisUnigram in
            guard let firstChar = thisUnigram.current.first else { return false }
            return expandedKeyArrays.allSatisfy { subKeyArray in
              Self.lxPlainBopomofo.isExclusive(
                isCHS: !isCHS,
                reading: subKeyArray.joined(separator: "-"),
                target: firstChar
              ) == true
            }
          }
        }
        rawAllUnigrams += factoryCoreUnigramsResult
        if config.isCNSEnabled {
          rawAllUnigrams += supplementalChoppedCNSAndGBEXUnigramsFor(keyArray: choppedKeyArray)
        }
        // 額外掛載的語言模組來源（多來源掛載）：預設為空，故對既有行為零影響。
        // 替代讀音路徑以 "&" 連讀鍵詢問，與原廠辭典的 chopped 路徑一致。
        rawAllUnigrams += mountedSupplierGrams(keyArray: choppedKeyArray, partiallyMatch: partiallyMatch)
      }

      if !config.bypassUserPhrasesData, config.isSymbolEnabled {
        for subKeyArray in expandedKeyArrays {
          let subKeyChain = subKeyArray.joined(separator: "-")
          rawAllUnigrams += lxUserSymbols.unigramsFor(key: subKeyChain, keyArray: subKeyArray)
        }
        if !config.isCassetteEnabled {
          rawAllUnigrams += factoryChoppedUnigramsFor(keyArray: choppedKeyArray, entryType: .symbolPhrases)
        }
      }

      if !config.bypassUserPhrasesData {
        let allowBoostingSingleKanji = config.allowRescoringSingleKanjiCandidates
        let factorySingleReadingValueHashes: Set<Int> = factoryCoreUnigramsResult.reduce(into: []) {
          if $1.keyArray.count == 1 { $0.insert($1.hashValue) }
        }
        var allUserPhraseUnigrams: [Homa.Gram] = []
        if partiallyMatch {
          // 多位置前綴交集掃描：一次掃描取代「逐 combo 各做一次前綴查詢」。
          // 訪問鍵數與笛卡爾乘積無關，避免 `ysxb` 類查詢把詞庫查詢展開成天文數字。
          allUserPhraseUnigrams = Array(
            lxUserPhrases.unigramsFor(
              keyPrefixesByPosition: keyArray.map(\.allValues),
              omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
              factorySingleReadingValueHashes: factorySingleReadingValueHashes
            ).reversed()
          )
        } else {
          for subKeyArray in expandedKeyArrays {
            let subKeyChain = subKeyArray.joined(separator: "-")
            allUserPhraseUnigrams += Array(
              lxUserPhrases.unigramsFor(
                key: subKeyChain,
                keyArray: subKeyArray,
                omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji,
                factorySingleReadingValueHashes: factorySingleReadingValueHashes
              ).reversed()
            )
          }
        }
        if flatKeyArray.count == 1, let topScore = rawAllUnigrams.lazy.map(\.probability).max() {
          allUserPhraseUnigrams = allUserPhraseUnigrams.map { currentUnigram in
            guard currentUnigram.keyArray.count == 1 else { return currentUnigram }
            return Homa.Gram(
              keyArray: currentUnigram.keyArray,
              value: currentUnigram.current,
              score: Swift.min(topScore + 0.000114514, currentUnigram.probability)
            )
          }
        }
        rawAllUnigrams = allUserPhraseUnigrams + rawAllUnigrams
      }

      cleanupInputTokenHashMapIfNeeded()

      var expandedUnigrams: [Homa.Gram] = []
      expandedUnigrams.reserveCapacity(rawAllUnigrams.count)
      for unigram in rawAllUnigrams {
        let convertedValues = unigram.current.parseAsInputToken(isCHS: isCHS)
        if convertedValues.isEmpty {
          expandedUnigrams.append(unigram)
        } else {
          for (absDelta, value) in convertedValues.enumerated() {
            let newScore: Double = -80 - Double(absDelta) * 0.01
            expandedUnigrams.append(.init(keyArray: flatKeyArray, value: value, score: newScore))
            let hashKey = "\(keyChain)\t\(value)".hashValue
            inputTokenHashesArray.insert(hashKey)
          }
        }
      }
      rawAllUnigrams = expandedUnigrams

      if config.isCassetteEnabled {
        for subKeyArray in expandedKeyArrays {
          let subKeyChain = subKeyArray.joined(separator: "-")
          rawAllUnigrams.insert(
            contentsOf: Self.lxCassette.unigramsFor(key: subKeyChain, keyArray: subKeyArray),
            at: 0
          )
        }
      } else if config.isSCPCEnabled || config.alwaysSupplyETenDOSUnigrams {
        for subKeyArray in expandedKeyArrays {
          let subKeyChain = subKeyArray.joined(separator: "-")
          rawAllUnigrams += Self.lxPlainBopomofo.valuesFor(key: subKeyChain, isCHS: isCHS).map {
            Homa.Gram(
              keyArray: flatKeyArray,
              value: $0,
              score: config.isSCPCEnabled ? 0 : -9.5
            )
          }
        }
      } else if rawAllUnigrams.isEmpty {
        for subKeyArray in expandedKeyArrays {
          let subKeyChain = subKeyArray.joined(separator: "-")
          if Self.lxPlainBopomofo.hasValuesFor(key: subKeyChain) {
            rawAllUnigrams += Self.lxPlainBopomofo.valuesFor(key: subKeyChain, isCHS: isCHS).map {
              Homa.Gram(keyArray: flatKeyArray, value: $0, score: -9.5)
            }
          }
        }
      }

      for subKeyArray in expandedKeyArrays {
        let subKeyChain = subKeyArray.joined(separator: "-")
        rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: subKeyChain, keyArray: subKeyArray))
      }

      if keyChain == "_punctuation_list" {
        rawAllUnigrams.append(contentsOf: getHaninSymbolMenuUnigrams())
      }

      if !config.bypassUserPhrasesData, config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let oldUnigram = rawAllUnigrams[i]
          let newValue = lxReplacements.valuesFor(key: oldUnigram.current)
          guard !newValue.isEmpty else { continue }
          let newUnigram = Homa.Gram(
            keyArray: oldUnigram.keyArray,
            value: newValue,
            score: oldUnigram.probability
          )
          rawAllUnigrams[i] = newUnigram
        }
      }

      let dataAsFilter: Set<String> = config.bypassUserPhrasesData
        ? []
        : Set(
          expandedKeyArrays.flatMap { subKeyArray in
            lxFiltered.unigramsFor(key: subKeyArray.joined(separator: "-"), keyArray: subKeyArray)
          }.map(\.current)
        )
      rawAllUnigrams.consolidate(filter: dataAsFilter)
      rawAllUnigrams.sort { $0.probability > $1.probability }
      // POM 記憶作為 n-gram 統計來源——同 fast path：僅餵「帶前後文」的 contextual 記憶。
      // 此為聲調桶（[PossibleKey] alternatives）路徑，keyChain 為各位置代表鍵（無調字形），
      // 故 POM head 比對**顯式**以 `.toneInsensitivePrefix`（去聲調等值）進行——桶查詢本就不能
      // 釘定聲調；fast path 的單鍵具體讀音（含第一聲）則維持 `.exact` 逐字等值。
      if config.fetchSuggestionsFromPerceptionOverrideModel {
        let pomGrams = lxPerceptor.perceptionsFor(
          headReading: keyChain,
          timestamp: Date().timeIntervalSince1970,
          matchMode: .toneInsensitivePrefix
        ).compactMap { pom -> Homa.Gram? in
          guard pom.previous != nil || pom.anterior != nil else { return nil }
          return Homa.Gram(
            keyArray: pom.headReading.split(separator: "-").map(String.init),
            current: pom.candidate,
            previous: pom.previous, anterior: pom.anterior,
            probability: pom.probability
          )
        }
        rawAllUnigrams.append(contentsOf: pomGrams)
      }
      unigramLRUCache[cacheKey] = rawAllUnigrams
      if unigramLRUCache.count > 1_024 {
        let half = unigramLRUCache.count / 2
        let keysToRemove = Array(unigramLRUCache.keys.prefix(half))
        keysToRemove.forEach { unigramLRUCache.removeValue(forKey: $0) }
      }
      return rawAllUnigrams
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
