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

extension vChewingLM {
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
    // 在函式內部用以記錄狀態的開關。
    public var isCassetteEnabled = false
    public var isPhraseReplacementEnabled = false
    public var isCNSEnabled = false
    public var isSymbolEnabled = false
    public var isSCPCEnabled = false
    public var isCHS = false
    public var deltaOfCalendarYears: Int = -2000

    // 這句需要留著，不然無法被 package 外界存取。
    public init(isCHS: Bool = false) {
      self.isCHS = isCHS
    }

    /// 介紹一下幾個通用的語言模組型別：
    /// ----------------------
    /// LMCoreEX 是全功能通用型的模組，每一筆辭典記錄以 key 為注音、以 [Unigram] 陣列作為記錄內容。
    /// 比較適合那種每筆記錄都有不同的權重數值的語言模組，雖然也可以強制施加權重數值就是了。
    /// LMCoreEX 的辭典陣列不承載 Unigram 本體、而是承載索引範圍，這樣可以節約記憶體。
    /// 一個 LMCoreEX 就可以滿足威注音幾乎所有語言模組副本的需求，當然也有這兩個例外：
    /// LMReplacements 與 LMAssociates 分別擔當語彙置換表資料與使用者聯想詞的資料承載工作。
    /// 但是，LMCoreEX 對 2010-2013 年等舊 mac 機種而言，讀取速度異常緩慢。
    /// 於是 LMCoreNS 就出場了，專門用來讀取原廠的 plist 格式的辭典。

    // 聲明原廠語言模組：
    // Reverse 的話，第一欄是注音，第二欄是對應的漢字，第三欄是可能的權重。
    // 不 Reverse 的話，第一欄是漢字，第二欄是對應的注音，第三欄是可能的權重。
    var lmCore = LMCoreNS(
      reverse: false, consolidate: false, defaultScore: -9.9, forceDefaultScore: false
    )
    var lmMisc = LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -1.0, forceDefaultScore: false
    )

    // 簡體中文模式與繁體中文模式共用全字庫擴展模組，故靜態處理。
    // 不然，每個模式都會讀入一份全字庫，會多佔用 100MB 記憶體。
    static var lmCNS = vChewingLM.LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -11.0, forceDefaultScore: false
    )
    static var lmSymbols = vChewingLM.LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -13.0, forceDefaultScore: false
    )

    // 磁帶資料模組。「currentCassette」對外唯讀，僅用來讀取磁帶本身的中繼資料（Metadata）。
    static var lmCassette = LMCassette()

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
    var lmPlainBopomofo = LMPlainBopomofo()

    // MARK: - 工具函式

    public var isLanguageModelLoaded: Bool { lmCore.isLoaded }
    public func loadLanguageModel(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCore.open(path)
        vCLog("lmCore: \(lmCore.count) entries of data loaded from: \(path)")
      } else {
        vCLog("lmCore: File access failure: \(path)")
      }
    }

    public var isCNSDataLoaded: Bool { Self.lmCNS.isLoaded }
    public func loadCNSData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        Self.lmCNS.open(path)
        vCLog("lmCNS: \(Self.lmCNS.count) entries of data loaded from: \(path)")
      } else {
        vCLog("lmCNS: File access failure: \(path)")
      }
    }

    public var isMiscDataLoaded: Bool { lmMisc.isLoaded }
    public func loadMiscData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmMisc.open(path)
        vCLog("lmMisc: \(lmMisc.count) entries of data loaded from: \(path)")
      } else {
        vCLog("lmMisc: File access failure: \(path)")
      }
    }

    public var isSymbolDataLoaded: Bool { Self.lmSymbols.isLoaded }
    public func loadSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        Self.lmSymbols.open(path)
        vCLog(
          "lmSymbol: \(Self.lmSymbols.count) entries of data loaded from: \(path)")
      } else {
        vCLog("lmSymbols: File access failure: \(path)")
      }
    }

    // 上述幾個函式不要加 Async，因為這些內容都被 LMMgr 負責用別的方法 Async 了、用 GCD 的多任務並行共結來完成。

    public func loadUserPhrasesData(path: String, filterPath: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          self.lmUserPhrases.clear()
          self.lmUserPhrases.open(path)
          vCLog("lmUserPhrases: \(self.lmUserPhrases.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmUserPhrases: File access failure: \(path)")
        }
      }
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: filterPath) {
          self.lmFiltered.clear()
          self.lmFiltered.open(filterPath)
          vCLog("lmFiltered: \(self.lmFiltered.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmFiltered: File access failure: \(path)")
        }
      }
    }

    public func loadUserSymbolData(path: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          self.lmUserSymbols.clear()
          self.lmUserSymbols.open(path)
          vCLog("lmUserSymbol: \(self.lmUserSymbols.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmUserSymbol: File access failure: \(path)")
        }
      }
    }

    public func loadUserAssociatesData(path: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          self.lmAssociates.clear()
          self.lmAssociates.open(path)
          vCLog("lmAssociates: \(self.lmAssociates.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmAssociates: File access failure: \(path)")
        }
      }
    }

    public func loadReplacementsData(path: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          self.lmReplacements.clear()
          self.lmReplacements.open(path)
          vCLog("lmReplacements: \(self.lmReplacements.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmReplacements: File access failure: \(path)")
        }
      }
    }

    public func loadUserSCPCSequencesData(path: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          self.lmPlainBopomofo.clear()
          self.lmPlainBopomofo.open(path)
          vCLog("lmPlainBopomofo: \(self.lmPlainBopomofo.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmPlainBopomofo: File access failure: \(path)")
        }
      }
    }

    public var isCassetteDataLoaded: Bool { Self.lmCassette.isLoaded }
    public static func loadCassetteData(path: String) {
      DispatchQueue.main.async {
        if FileManager.default.isReadableFile(atPath: path) {
          Self.lmCassette.clear()
          Self.lmCassette.open(path)
          vCLog("lmCassette: \(Self.lmCassette.count) entries of data loaded from: \(path)")
        } else {
          vCLog("lmCassette: File access failure: \(path)")
        }
      }
    }

    // MARK: - 核心函式（對外）

    public func hasAssociatedPhrasesFor(pair: Megrez.Compositor.KeyValuePaired) -> Bool {
      lmAssociates.hasValuesFor(pair: pair)
    }

    public func associatedPhrasesFor(pair: Megrez.Compositor.KeyValuePaired) -> [String] {
      lmAssociates.valuesFor(pair: pair)
    }

    /// 插入臨時資料。
    /// - Parameters:
    ///   - key: 索引鍵。
    ///   - unigram: 要插入的單元圖。
    ///   - isFiltering: 是否有在過濾內容。
    public func insertTemporaryData(key: String, unigram: Megrez.Unigram, isFiltering: Bool) {
      _ =
        isFiltering
        ? lmFiltered.temporaryMap[key, default: []].append(unigram)
        : lmUserPhrases.temporaryMap[key, default: []].append(unigram)
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
    public func replaceData(textData rawStrData: String, for targetType: ReplacableUserDataType, save: Bool = true) {
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
    /// - Parameter key: 索引鍵。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(key: String) -> Bool {
      key == " " || (!unigramsFor(key: key).isEmpty && !key.isEmpty)
    }

    /// 根據給定的索引鍵和資料值，確認是否有該具體的資料值在庫。
    /// - Parameters:
    ///   - key: 索引鍵。
    ///   - value: 資料值。
    /// - Returns: 是否在庫。
    public func hasKeyValuePairFor(key: String, value: String) -> Bool {
      unigramsFor(key: key).map(\.value).contains(value)
    }

    /// 給定讀音字串，讓 LMI 給出對應的經過處理的單元圖陣列。
    /// - Parameter key: 給定的讀音字串。
    /// - Returns: 對應的經過處理的單元圖陣列。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      guard !key.isEmpty else { return [] }
      /// 給空格鍵指定輸出值。
      if key == " " { return [.init(value: " ")] }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Megrez.Unigram] = []

      if isCassetteEnabled { rawAllUnigrams += Self.lmCassette.unigramsFor(key: key) }

      // 如果有檢測到使用者自訂逐字選字語料庫內的相關資料的話，在這裡先插入。
      if isSCPCEnabled {
        rawAllUnigrams += lmPlainBopomofo.valuesFor(key: key).map { Megrez.Unigram(value: $0, score: 0) }
      }

      // 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
      // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
      // 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
      rawAllUnigrams += lmUserPhrases.unigramsFor(key: key).reversed()

      if !isCassetteEnabled || isCassetteEnabled && key.charComponents[0] == "_" {
        // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
        rawAllUnigrams += lmMisc.unigramsFor(key: key)
        rawAllUnigrams += lmCore.unigramsFor(key: key)
        if isCNSEnabled { rawAllUnigrams += Self.lmCNS.unigramsFor(key: key) }
      }

      if isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: key)
        if !isCassetteEnabled {
          rawAllUnigrams += Self.lmSymbols.unigramsFor(key: key)
        }
      }

      // 新增與日期、時間、星期有關的單元圖資料
      rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: key))

      // 提前處理語彙置換
      if isPhraseReplacementEnabled {
        for i in 0..<rawAllUnigrams.count {
          let newValue = lmReplacements.valuesFor(key: rawAllUnigrams[i].value)
          guard !newValue.isEmpty else { continue }
          rawAllUnigrams[i].value = newValue
        }
      }

      // 讓單元圖陣列自我過濾。在此基礎之上，對於相同詞值的多個單元圖，僅保留權重最大者。
      rawAllUnigrams.consolidate(filter: .init(lmFiltered.unigramsFor(key: key).map(\.value)))
      return rawAllUnigrams
    }
  }
}
