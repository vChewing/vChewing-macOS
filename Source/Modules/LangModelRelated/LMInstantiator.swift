// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension vChewing {
  /// 語言模組副本化模組（LMInstantiator，下稱「LMI」）自身為符合天權星組字引擎內
  /// 的 LangModelProtocol 協定的模組、統籌且整理來自其它子模組的資料（包括使
  /// 用者語彙、繪文字模組、語彙濾除表、原廠語言模組等）。
  ///
  /// LMI 型別為與輸入法按鍵調度模組直接溝通之唯一語言模組。當組字器開始根據給定的
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
    public var isPhraseReplacementEnabled = false
    public var isCNSEnabled = false
    public var isSymbolEnabled = false

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
    static var lmCNS = vChewing.LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -11.0, forceDefaultScore: false
    )
    static var lmSymbols = vChewing.LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -13.0, forceDefaultScore: false
    )

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
    var lmReplacements = LMReplacments()
    var lmAssociates = LMAssociates()
    var lmPlainBopomofo = LMPlainBopomofo()

    // MARK: - 工具函式

    public var isLanguageModelLoaded: Bool { lmCore.isLoaded() }
    public func loadLanguageModel(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCore.open(path)
        IME.prtDebugIntel("lmCore: \(lmCore.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmCore: File access failure: \(path)")
      }
    }

    public var isCNSDataLoaded: Bool { vChewing.LMInstantiator.lmCNS.isLoaded() }
    public func loadCNSData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        vChewing.LMInstantiator.lmCNS.open(path)
        IME.prtDebugIntel("lmCNS: \(vChewing.LMInstantiator.lmCNS.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmCNS: File access failure: \(path)")
      }
    }

    public var isMiscDataLoaded: Bool { lmMisc.isLoaded() }
    public func loadMiscData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmMisc.open(path)
        IME.prtDebugIntel("lmMisc: \(lmMisc.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmMisc: File access failure: \(path)")
      }
    }

    public var isSymbolDataLoaded: Bool { vChewing.LMInstantiator.lmSymbols.isLoaded() }
    public func loadSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        vChewing.LMInstantiator.lmSymbols.open(path)
        IME.prtDebugIntel("lmSymbol: \(vChewing.LMInstantiator.lmSymbols.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmSymbols: File access failure: \(path)")
      }
    }

    public func loadUserPhrasesData(path: String, filterPath: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmUserPhrases.close()
        lmUserPhrases.open(path)
        IME.prtDebugIntel("lmUserPhrases: \(lmUserPhrases.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmUserPhrases: File access failure: \(path)")
      }
      if FileManager.default.isReadableFile(atPath: filterPath) {
        lmFiltered.close()
        lmFiltered.open(filterPath)
        IME.prtDebugIntel("lmFiltered: \(lmFiltered.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmFiltered: File access failure: \(path)")
      }
    }

    public func loadUserSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmUserSymbols.close()
        lmUserSymbols.open(path)
        IME.prtDebugIntel("lmUserSymbol: \(lmUserSymbols.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmUserSymbol: File access failure: \(path)")
      }
    }

    public func loadUserAssociatesData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmAssociates.close()
        lmAssociates.open(path)
        IME.prtDebugIntel("lmAssociates: \(lmAssociates.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmAssociates: File access failure: \(path)")
      }
    }

    public func loadReplacementsData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmReplacements.close()
        lmReplacements.open(path)
        IME.prtDebugIntel("lmReplacements: \(lmReplacements.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmReplacements: File access failure: \(path)")
      }
    }

    public func loadUserSCPCSequencesData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmPlainBopomofo.close()
        lmPlainBopomofo.open(path)
        IME.prtDebugIntel("lmPlainBopomofo: \(lmPlainBopomofo.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmPlainBopomofo: File access failure: \(path)")
      }
    }

    // MARK: - 核心函式（對外）

    /// 威注音輸入法目前尚未具備對雙元圖的處理能力，故停用該函式。
    // public func bigramsFor(preceedingKey: String, key: String) -> [Megrez.Bigram] { }

    /// 給定讀音字串，讓 LMI 給出對應的經過處理的單元圖陣列。
    /// - Parameter key: 給定的讀音字串。
    /// - Returns: 對應的經過處理的單元圖陣列。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      /// 給空格鍵指定輸出值。
      if key == " " { return [.init(value: " ")] }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Megrez.Unigram] = []

      // 如果有檢測到使用者自訂逐字選字語料庫內的相關資料的話，在這裡先插入。
      if mgrPrefs.useSCPCTypingMode {
        rawAllUnigrams += lmPlainBopomofo.valuesFor(key: key).map { Megrez.Unigram(value: $0, score: 0) }
      }

      // 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
      // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
      // 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
      rawAllUnigrams += lmUserPhrases.unigramsFor(key: key).reversed()

      // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
      rawAllUnigrams += lmMisc.unigramsFor(key: key)
      rawAllUnigrams += lmCore.unigramsFor(key: key)

      if isCNSEnabled {
        rawAllUnigrams += vChewing.LMInstantiator.lmCNS.unigramsFor(key: key)
      }

      if isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: key)
        rawAllUnigrams += vChewing.LMInstantiator.lmSymbols.unigramsFor(key: key)
      }

      // 新增與日期、時間、星期有關的單元圖資料
      rawAllUnigrams.append(contentsOf: queryDateTimeUnigrams(with: key))

      // 準備過濾清單。因為我們在 Swift 使用 NSOrderedSet，所以就不需要統計清單了。
      var filteredPairs: Set<String> = []

      // 載入要過濾的 KeyValuePair 清單。
      for unigram in lmFiltered.unigramsFor(key: key) {
        filteredPairs.insert(unigram.value)
      }

      return filterAndTransform(
        unigrams: rawAllUnigrams,
        filter: filteredPairs
      )
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(key: String) -> Bool {
      if key == " " { return true }

      if !lmFiltered.hasUnigramsFor(key: key) {
        return lmUserPhrases.hasUnigramsFor(key: key) || lmCore.hasUnigramsFor(key: key)
      }

      return !unigramsFor(key: key).isEmpty
    }

    public func associatedPhrasesFor(pair: Megrez.KeyValuePaired) -> [String] {
      lmAssociates.valuesFor(pair: pair)
    }

    public func hasAssociatedPhrasesFor(pair: Megrez.KeyValuePaired) -> Bool {
      lmAssociates.hasValuesFor(pair: pair)
    }

    // MARK: - 核心函式（對內）

    /// 給定單元圖原始結果陣列，經過語彙過濾處理＋置換處理＋去重複處理之後，給出單元圖結果陣列。
    /// - Parameters:
    ///   - unigrams: 傳入的單元圖原始結果陣列。
    ///   - filteredPairs: 傳入的要過濾掉的鍵值配對陣列。
    /// - Returns: 經過語彙過濾處理＋置換處理＋去重複處理的單元圖結果陣列。
    func filterAndTransform(
      unigrams: [Megrez.Unigram],
      filter filteredPairs: Set<String>
    ) -> [Megrez.Unigram] {
      var results: [Megrez.Unigram] = []
      var insertedPairs: Set<String> = []
      for unigram in unigrams {
        var theValue: String = unigram.value
        if filteredPairs.contains(theValue) { continue }
        if isPhraseReplacementEnabled {
          let replacement = lmReplacements.valuesFor(key: theValue)
          if !replacement.isEmpty { theValue = replacement }
        }
        if insertedPairs.contains(theValue) { continue }
        results.append(Megrez.Unigram(value: theValue, score: unigram.score))
        insertedPairs.insert(theValue)
      }
      return results
    }
  }
}
