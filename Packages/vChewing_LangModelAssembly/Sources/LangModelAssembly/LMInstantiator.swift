// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import Shared
import SwiftExtension

extension LMAssembly {
  /// 語言模組副本化模組（LMInstantiator，下稱「LMI」）自身為符合天權星組字引擎內
  /// 的 LangModelProtocol 協定的模組、統籌且整理來自其它子模組的資料（包括使
  /// 用者語彙、繪文字模組、語彙濾除表、原廠語言模組等）。
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
  public final class LMInstantiator: LangModelProtocol {
    // MARK: Lifecycle

    // 這句需要留著，不然無法被 package 外界存取。
    public init(
      isCHS: Bool = false,
      pomDataURL: URL? = nil
    ) {
      self.isCHS = isCHS
      self.lmPerceptionOverride = .init(dataURL: pomDataURL)
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
      public var filterNonCNSReadings = false
      public var deltaOfCalendarYears: Int = -2_000
      public var allowRescoringSingleKanjiCandidates = false
    }

    public static var asyncLoadingUserData: Bool = true
    // 與關聯詞語有關的惰性載入器，可由外部登記。
    public static var associatesLazyLoader: (() -> ())?
    // SQLite 連線是否已經建立。
    public internal(set) static var isSQLDBConnected: Bool = false

    // 簡體中文模型？
    public let isCHS: Bool

    // 在函式內部用以記錄狀態的開關。
    public private(set) var config = Config()

    public internal(set) var inputTokenHashesArray: ContiguousArray<Int> = [] {
      didSet {
        let currentSet = Set(inputTokenHashesArray)
        let previousSet = Set(oldValue)
        guard currentSet.hashValue != previousSet.hashValue else { return }
        inputTokenHashesArray = inputTokenHashesArray.deduplicated
      }
    }

    public var isCassetteDataLoaded: Bool { Self.lmCassette.isLoaded }

    public static func setCassetCandidateKeyValidator(_ validator: @escaping (String) -> Bool) {
      Self.lmCassette.candidateKeysValidator = validator
    }

    public static func loadCassetteData(path: String) {
      @Sendable
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
        asyncOnMain {
          load()
        }
      }
    }

    // MARK: Shared Resource Lifecycle

    public static func resetSharedResources(restoreAsyncLoadingStrategy: Bool = true) {
      disconnectSQLDB()
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
    }

    public func resetFactoryJSONModels() {}

    /// 清除 InputToken HashMap。
    /// 注意：此 HashMap 僅記錄由 InputToken（以 "MACRO@" 開頭的特殊標記）生成的 Unigram。
    public func purgeInputTokenHashMap() {
      inputTokenHashesArray.removeAll()
    }

    public func loadUserPhrasesData(path: String, filterPath: String?) {
      @Sendable
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
        asyncOnMain {
          loadMain()
        }
      }
      guard let filterPath = filterPath else { return }
      @Sendable
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
        asyncOnMain {
          loadFilter()
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
      @Sendable
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
        asyncOnMain {
          load()
        }
      }
    }

    public func loadUserAssociatesData(path: String) {
      @Sendable
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
        asyncOnMain {
          load()
        }
      }
    }

    public func loadReplacementsData(path: String) {
      @Sendable
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
        asyncOnMain {
          load()
        }
      }
    }

    // MARK: - 核心函式（對外）

    public func hasAssociatedPhrasesFor(pair: Megrez.KeyValuePaired) -> Bool {
      lmAssociates.hasValuesFor(pair: pair)
    }

    public func associatedPhrasesFor(pair: Megrez.KeyValuePaired) -> [String] {
      lmAssociates.valuesFor(pair: pair)
    }

    public func queryReplacementValue(key: String) -> String? {
      let result = lmReplacements.valuesFor(key: key)
      return result.isEmpty ? nil : result
    }

    public func isPairFiltered(pair: Megrez.KeyValuePaired) -> Bool {
      lmFiltered
        .unigramsFor(key: pair.joinedKey(), keyArray: pair.keyArray)
        .map(\.value)
        .contains(pair.value)
    }

    /// 插入臨時資料。
    /// - Parameters:
    ///   - key: 索引鍵陣列。
    ///   - unigram: 要插入的單元圖。
    ///   - isFiltering: 是否有在過濾內容。
    public func insertTemporaryData(
      unigram: Megrez.Unigram,
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
        if save { lmAssociates.saveData() }
      case .theReplacements:
        lmReplacements.replaceData(textData: rawText)
        if save { lmAssociates.saveData() }
      case .thePhrases:
        lmUserPhrases.replaceData(textData: rawText)
        if save { lmAssociates.saveData() }
      case .theSymbols:
        lmUserSymbols.replaceData(textData: rawText)
        if save { lmAssociates.saveData() }
      }
    }

    public func queryETenDOSSequence(reading: String) -> [String] {
      Self.lmPlainBopomofo.valuesFor(key: reading, isCHS: isCHS)
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵陣列。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      let keyChain = keyArray.joined(separator: "-")
      // 因為涉及到對濾除清單的檢查，所以這裡必須走一遍 .unigramsFor()。
      // 從 SQL 查詢的角度來看，這樣恐怕不是很經濟，因為 SQLite 要專門準備一次查詢結果。
      // 但以 2010 年的電腦效能作為基準參考來看的話，這方面的效能壓力可以忽略不計。
      return keyChain == " " || (!unigramsFor(keyArray: keyArray).isEmpty && !keyChain.isEmpty)
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
        .map(\.value)
        .contains(value)
        : unigramsFor(keyArray: keyArray).map(\.value).contains(value)
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

    /// 給定讀音字串，讓 LMI 給出對應的經過處理的單元圖陣列。
    /// - Parameter key: 給定的讀音字串。
    /// - Returns: 對應的經過處理的單元圖陣列。
    public func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
      let keyChain = keyArray.joined(separator: "-")
      guard !keyChain.isEmpty else { return [] }
      /// 給空格鍵指定輸出值。
      if keyChain == " " { return [.init(keyArray: keyArray, value: " ")] }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Megrez.Unigram] = []

      if !config.isCassetteEnabled
        || config.isCassetteEnabled && keyChain.map(\.description)[0] == "_" {
        // 先給出 NumPad 的結果。
        rawAllUnigrams += supplyNumPadUnigrams(key: keyChain, keyArray: keyArray)
        // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
        rawAllUnigrams += factoryUnigramsFor(
          key: keyChain,
          keyArray: keyArray,
          column: .theDataCHEW
        )
        // 原廠核心辭典內容。
        var coreUnigramsResult: [Megrez.Unigram] = factoryCoreUnigramsFor(
          key: keyChain,
          keyArray: keyArray
        )
        // 如果是繁體中文、且有開啟 CNS11643 全字庫讀音過濾開關的話，對原廠核心辭典內容追加過濾處理：
        if config.filterNonCNSReadings, !isCHS {
          coreUnigramsResult.removeAll { thisUnigram in
            !checkCNSConformation(for: thisUnigram, keyArray: keyArray)
          }
        }
        // 正式追加原廠核心辭典檢索結果。
        rawAllUnigrams += coreUnigramsResult

        if config.isCNSEnabled {
          rawAllUnigrams += factoryUnigramsFor(
            key: keyChain,
            keyArray: keyArray,
            column: .theDataCNS
          )
        }
      }

      if config.isSymbolEnabled {
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
      let allowBoostingSingleKanji = config.allowRescoringSingleKanjiCandidates
      var userPhraseUnigrams = Array(
        lmUserPhrases.unigramsFor(
          key: keyChain,
          keyArray: keyArray,
          omitNonTemporarySingleCharNonSymbolUnigrams: !allowBoostingSingleKanji
        ).reversed()
      )
      if keyArray.count == 1, let topScore = rawAllUnigrams.map(\.score).max() {
        // 不再讓使用者自己加入的單漢字讀音權重進入組句體系。
        userPhraseUnigrams = userPhraseUnigrams.map { currentUnigram in
          Megrez.Unigram(
            keyArray: keyArray,
            value: currentUnigram.value,
            score: Swift.min(topScore + 0.000114514, currentUnigram.score)
          )
        }
      }
      rawAllUnigrams = userPhraseUnigrams + rawAllUnigrams

      // 定期清理 InputToken HashMap 以防止記憶體洩漏
      cleanupInputTokenHashMapIfNeeded()

      // 分析且處理可能存在的 InputToken。
      let rawAllUnigramsToFlat: [[Megrez.Unigram]] = rawAllUnigrams.map { unigram in
        let convertedValues = unigram.value.parseAsInputToken(isCHS: isCHS)
        // 不是 InputToken 的話，直接返回原 Unigram
        guard !convertedValues.isEmpty else { return [unigram] }
        // 只有確認是 InputToken 時才處理並寫入 HashMap
        var result = [Megrez.Unigram]()
        convertedValues.enumerated().forEach { absDelta, value in
          let newScore: Double = -80 - Double(absDelta) * 0.01
          result.append(.init(keyArray: keyArray, value: value, score: newScore))
          // 僅為 InputToken 生成的 Unigram 寫入 HashMap
          let hashKey = "\(keyChain)\t\(value)".hashValue
          inputTokenHashesArray.append(hashKey)
        }
        return result
      }

      rawAllUnigrams = rawAllUnigramsToFlat.flatMap { $0 }

      if config.isCassetteEnabled {
        rawAllUnigrams.insert(
          contentsOf: Self.lmCassette.unigramsFor(key: keyChain, keyArray: keyArray),
          at: 0
        )
      } else if config.isSCPCEnabled || config.alwaysSupplyETenDOSUnigrams {
        // 追加倚天中文 DOS 候選字排序。
        rawAllUnigrams += Self.lmPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
          Megrez.Unigram(
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
      if config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let oldUnigram = rawAllUnigrams[i]
          let newValue = lmReplacements.valuesFor(key: oldUnigram.value)
          guard !newValue.isEmpty else { continue }
          let newUnigram = Megrez.Unigram(
            keyArray: oldUnigram.keyArray,
            value: newValue,
            score: oldUnigram.score
          )
          rawAllUnigrams[i] = newUnigram
        }
      }

      // 讓單元圖陣列自我過濾。在此基礎之上，對於相同詞值的多個單元圖，僅保留權重最大者。
      rawAllUnigrams
        .consolidate(
          filter: .init(
            lmFiltered.unigramsFor(key: keyChain, keyArray: keyArray).map(\.value)
          )
        )
      return rawAllUnigrams
    }

    // MARK: Internal

    // SQLite 連線所在的記憶體位置。
    static var ptrSQL: OpaquePointer?

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

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lmUserPhrases = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: 0,
      forceDefaultScore: false
    )
    var lmFiltered = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: 0,
      forceDefaultScore: true
    )
    var lmUserSymbols = LMCoreEX(
      reverse: true,
      consolidate: true,
      defaultScore: -12.0,
      forceDefaultScore: true
    )
    var lmReplacements = LMReplacements()
    var lmAssociates = LMAssociates()

    // 漸退記憶模組
    var lmPerceptionOverride: LMPerceptionOverride

    // 確保關聯詞語資料在首次剛需時得以即時載入。
    internal func ensureAssociatesLoaded() {
      if !lmAssociates.isLoaded {
        let wasAsync = Self.asyncLoadingUserData
        Self.asyncLoadingUserData = false
        Self.associatesLazyLoader?()
        Self.asyncLoadingUserData = wasAsync
      }
    }

    #if DEBUG
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
      ///   - perceptionOverride: Mutator for the perception-override memory.
      func injectTestData(
        userPhrases: ((inout LMCoreEX) -> ())? = nil,
        userFilter: ((inout LMCoreEX) -> ())? = nil,
        userSymbols: ((inout LMCoreEX) -> ())? = nil,
        replacements: ((inout LMReplacements) -> ())? = nil,
        associates: ((inout LMAssociates) -> ())? = nil,
        perceptionOverride: ((inout LMPerceptionOverride) -> ())? = nil
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
        if let mutator = perceptionOverride {
          mutator(&lmPerceptionOverride)
        }
      }
    #endif

    // MARK: Private

    // MARK: - 工具函式

    private let prefs = PrefMgr()

    /// 當 HashMap 過大時自動清理
    private func cleanupInputTokenHashMapIfNeeded() {
      // 更積極的清理策略：超過 3000 條目就清理至 1000 條目
      if inputTokenHashesArray.count > 3_000 {
        // 保留最近 1000 個條目，清理其餘的
        inputTokenHashesArray.removeFirst(1_000)
      }
    }
  }
}
