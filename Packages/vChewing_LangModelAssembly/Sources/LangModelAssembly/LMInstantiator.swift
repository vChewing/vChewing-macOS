// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
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
  public class LMInstantiator: LangModelProtocol {
    // MARK: Lifecycle

    // 這句需要留著，不然無法被 package 外界存取。
    public init(
      isCHS: Bool = false,
      uomDataURL: URL? = nil
    ) {
      self.isCHS = isCHS
      self.lmUserOverride = .init(dataURL: uomDataURL)
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
      public var filterNonCNSReadings = false
      public var deltaOfCalendarYears: Int = -2_000
    }

    public static var asyncLoadingUserData: Bool = true

    // SQLite 連線是否已經建立。
    public internal(set) static var isSQLDBConnected: Bool = false

    // 簡體中文模型？
    public let isCHS: Bool

    public internal(set) var inputTokenHashMap: [Int: Bool] = [:]

    // 在函式內部用以記錄狀態的開關。
    public private(set) var config = Config()

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

    @discardableResult
    public func setOptions(handler: (inout Config) -> ()) -> LMInstantiator {
      handler(&config)
      return self
    }

    // MARK: - 工具函式

    public func resetFactoryJSONModels() {}

    public func purgeInputTokenHashMap() {
      inputTokenHashMap.removeAll()
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
      lmFiltered.unigramsFor(key: pair.joinedKey()).map(\.value).contains(pair.value)
    }

    /// 插入臨時資料。
    /// - Parameters:
    ///   - key: 索引鍵陣列。
    ///   - unigram: 要插入的單元圖。
    ///   - isFiltering: 是否有在過濾內容。
    public func insertTemporaryData(
      keyArray: [String],
      unigram: Megrez.Unigram,
      isFiltering: Bool
    ) {
      let keyChain = keyArray.joined(separator: "-")
      _ =
        isFiltering
          ? lmFiltered.temporaryMap[keyChain, default: []].append(unigram)
          : lmUserPhrases.temporaryMap[keyChain, default: []].append(unigram)
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
        ? factoryCoreUnigramsFor(key: keyArray.joined(separator: "-")).map(\.value).contains(value)
        : unigramsFor(keyArray: keyArray).map(\.value).contains(value)
    }

    /// 根據給定的索引鍵，確認有多少筆資料值在庫。
    /// - Parameters:
    ///   - keyArray: 索引鍵陣列。
    ///   - factoryDictionaryOnly: 是否僅統計原廠辭典。
    /// - Returns: 是否在庫。
    public func countKeyValuePairs(keyArray: [String], factoryDictionaryOnly: Bool = false) -> Int {
      factoryDictionaryOnly
        ? factoryCoreUnigramsFor(key: keyArray.joined(separator: "-")).count
        : unigramsFor(keyArray: keyArray).count
    }

    /// 給定讀音字串，讓 LMI 給出對應的經過處理的單元圖陣列。
    /// - Parameter key: 給定的讀音字串。
    /// - Returns: 對應的經過處理的單元圖陣列。
    public func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
      let keyChain = keyArray.joined(separator: "-")
      guard !keyChain.isEmpty else { return [] }
      /// 給空格鍵指定輸出值。
      if keyChain == " " { return [.init(value: " ")] }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Megrez.Unigram] = []

      if config.isCassetteEnabled { rawAllUnigrams += Self.lmCassette.unigramsFor(key: keyChain) }

      // 如果有檢測到使用者自訂逐字選字語料庫內的相關資料的話，在這裡先插入。
      if config.isSCPCEnabled {
        rawAllUnigrams += Self.lmPlainBopomofo.valuesFor(key: keyChain, isCHS: isCHS).map {
          Megrez.Unigram(value: $0, score: 0)
        }
      }

      if !config.isCassetteEnabled || config.isCassetteEnabled && keyChain
        .map(\.description)[0] == "_" {
        // 先給出 NumPad 的結果。
        rawAllUnigrams += supplyNumPadUnigrams(key: keyChain)
        // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
        rawAllUnigrams += factoryUnigramsFor(key: keyChain, column: .theDataCHEW)
        // 原廠核心辭典內容。
        var coreUnigramsResult: [Megrez.Unigram] = factoryCoreUnigramsFor(key: keyChain)
        // 如果是繁體中文、且有開啟 CNS11643 全字庫讀音過濾開關的話，對原廠核心辭典內容追加過濾處理：
        if config.filterNonCNSReadings, !isCHS {
          coreUnigramsResult.removeAll { thisUnigram in
            !checkCNSConformation(for: thisUnigram, keyArray: keyArray)
          }
        }
        // 正式追加原廠核心辭典檢索結果。
        rawAllUnigrams += coreUnigramsResult

        if config.isCNSEnabled {
          rawAllUnigrams += factoryUnigramsFor(key: keyChain, column: .theDataCNS)
        }
      }

      if config.isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: keyChain)
        if !config.isCassetteEnabled {
          rawAllUnigrams += factoryUnigramsFor(key: keyChain, column: .theDataSYMB)
        }
      }

      // 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
      // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
      // 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
      var userPhraseUnigrams = Array(lmUserPhrases.unigramsFor(key: keyChain).reversed())
      if keyArray.count == 1, let topScore = rawAllUnigrams.map(\.score).max() {
        // 不再讓使用者自己加入的單漢字讀音權重進入爬軌體系。
        userPhraseUnigrams = userPhraseUnigrams.map { currentUnigram in
          Megrez.Unigram(
            value: currentUnigram.value,
            score: Swift.min(topScore + 0.000114514, currentUnigram.score)
          )
        }
      }
      rawAllUnigrams = userPhraseUnigrams + rawAllUnigrams

      // 分析且處理可能存在的 InputToken。
      rawAllUnigrams = rawAllUnigrams.map { unigram in
        let convertedValues = unigram.value.parseAsInputToken(isCHS: isCHS)
        guard !convertedValues.isEmpty else { return [unigram] }
        var result = [Megrez.Unigram]()
        convertedValues.enumerated().forEach { absDelta, value in
          let newScore: Double = -80 - Double(absDelta) * 0.01
          result.append(.init(value: value, score: newScore))
          let hashKey = "\(keyChain)\t\(value)".hashValue
          vCLMLog("\(keyChain)\t\(value)" + inputTokenHashMap.description)
          inputTokenHashMap[hashKey] = true
        }
        return result
      }.flatMap { $0 }

      // 新增與日期、時間、星期有關的單元圖資料。
      rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: keyChain))

      if keyChain == "_punctuation_list" {
        rawAllUnigrams.append(contentsOf: getHaninSymbolMenuUnigrams())
      }

      // 提前處理語彙置換。
      if config.isPhraseReplacementEnabled {
        for i in 0 ..< rawAllUnigrams.count {
          let newValue = lmReplacements.valuesFor(key: rawAllUnigrams[i].value)
          guard !newValue.isEmpty else { continue }
          rawAllUnigrams[i].value = newValue
        }
      }

      // 讓單元圖陣列自我過濾。在此基礎之上，對於相同詞值的多個單元圖，僅保留權重最大者。
      rawAllUnigrams.consolidate(filter: .init(lmFiltered.unigramsFor(key: keyChain).map(\.value)))
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
    /// 一個 LMCoreEX 就可以滿足威注音幾乎所有語言模組副本的需求，當然也有這兩個例外：
    /// LMReplacements 與 LMAssociates 分別擔當語彙置換表資料與使用者關聯詞語的資料承載工作。
    /// 但是，LMCoreEX 對 2010-2013 年等舊 mac 機種而言，讀取速度異常緩慢。
    /// 於是 LMCoreJSON 就出場了，專門用來讀取原廠的 JSON 格式的辭典。

    // 磁帶資料模組。「currentCassette」對外唯讀，僅用來讀取磁帶本身的中繼資料（Metadata）。
    static var lmCassette = LMCassette()
    static var lmPlainBopomofo = LMPlainBopomofo()

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lmUserPhrases = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: 0, forceDefaultScore: false
    )
    var lmFiltered = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: 0, forceDefaultScore: true
    )
    var lmUserSymbols = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: -12.0, forceDefaultScore: true
    )
    var lmReplacements = LMReplacements()
    var lmAssociates = LMAssociates()

    // 半衰记忆模组
    var lmUserOverride: LMUserOverride
  }
}
