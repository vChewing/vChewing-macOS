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

// NOTE: We still keep some of the comments left by Zonble,
// regardless that he is not in charge of this Swift module。

import Foundation

// 簡體中文模式與繁體中文模式共用全字庫擴展模組，故單獨處理。
// 塞在 LMInstantiator 內的話，每個模式都會讀入一份全字庫，會多佔用 100MB 記憶體。
private var lmCNS = vChewing.LMCoreNS(
  reverse: true, consolidate: false, defaultScore: -11.0, forceDefaultScore: false
)
private var lmSymbols = vChewing.LMCoreNS(
  reverse: true, consolidate: false, defaultScore: -13.0, forceDefaultScore: false
)

extension vChewing {
  /// LMInstantiator is a facade for managing a set of models including
  /// the input method language model, user phrases and excluded phrases.
  ///
  /// It is the primary model class that the input controller and input compositor
  /// of vChewing talks to. When the input compositor starts to build a sentence
  /// from a series of BPMF readings, it passes the readings to the model to see
  /// if there are valid unigrams, and use returned unigrams to produce the final
  /// results.
  ///
  /// LMInstantiator combine and transform the unigrams from the primary language
  /// model and user phrases. The process is
  ///
  /// 1) Get the original unigrams.
  /// 2) Drop the unigrams whose value is contained in the exclusion map.
  /// 3) Replace the values of the unigrams using the phrase replacement map.
  /// 4) Drop the duplicated phrases from the generated unigram array.
  ///
  /// The controller can ask the model to load the primary input method language
  /// model while launching and to load the user phrases anytime if the custom
  /// files are modified. It does not keep the reference of the data pathes but
  /// you have to pass the paths when you ask it to load.
  public class LMInstantiator: Megrez.LanguageModel {
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

    // 聲明原廠語言模組
    /// Reverse 的話，第一欄是注音，第二欄是對應的漢字，第三欄是可能的權重。
    /// 不 Reverse 的話，第一欄是漢字，第二欄是對應的注音，第三欄是可能的權重。
    var lmCore = LMCoreNS(
      reverse: false, consolidate: false, defaultScore: -9.9, forceDefaultScore: false
    )
    var lmMisc = LMCoreNS(
      reverse: true, consolidate: false, defaultScore: -1.0, forceDefaultScore: false
    )

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lmUserPhrases = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: 0, forceDefaultScore: true
    )
    var lmFiltered = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: 0, forceDefaultScore: true
    )
    var lmUserSymbols = LMCoreEX(
      reverse: true, consolidate: true, defaultScore: -12.0, forceDefaultScore: true
    )
    var lmReplacements = LMReplacments()
    var lmAssociates = LMAssociates()

    // 初期化的函式先保留
    override init() {}

    // 以下這些函式命名暫時保持原樣，等弒神行動徹底結束了再調整。

    public var isLanguageModelLoaded: Bool { lmCore.isLoaded() }
    public func loadLanguageModel(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCore.open(path)
        IME.prtDebugIntel("lmCore: \(lmCore.count) entries of data loaded from: \(path)")
      } else {
        IME.prtDebugIntel("lmCore: File access failure: \(path)")
      }
    }

    public var isCNSDataLoaded: Bool { lmCNS.isLoaded() }
    public func loadCNSData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCNS.open(path)
        IME.prtDebugIntel("lmCNS: \(lmCNS.count) entries of data loaded from: \(path)")
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

    public var isSymbolDataLoaded: Bool { lmSymbols.isLoaded() }
    public func loadSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmSymbols.open(path)
        IME.prtDebugIntel("lmSymbol: \(lmSymbols.count) entries of data loaded from: \(path)")
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

    // MARK: - Core Functions (Public)

    /// Not implemented since we do not have data to provide bigram function.
    // public func bigramsForKeys(preceedingKey: String, key: String) -> [Megrez.Bigram] { }

    /// Returns a list of available unigram for the given key.
    /// @param key:String represents the BPMF reading or a symbol key.
    /// For instance, it you pass "ㄉㄨㄟˇ", it returns "㨃" and other possible candidates.
    override open func unigramsFor(key: String) -> [Megrez.Unigram] {
      if key == " " {
        /// 給空格鍵指定輸出值。
        let spaceUnigram = Megrez.Unigram(
          keyValue: Megrez.KeyValuePair(key: " ", value: " "),
          score: 0
        )
        return [spaceUnigram]
      }

      /// 準備不同的語言模組容器，開始逐漸往容器陣列內塞入資料。
      var rawAllUnigrams: [Megrez.Unigram] = []

      // 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
      // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
      // 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
      rawAllUnigrams += lmUserPhrases.unigramsFor(key: key).reversed()

      // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
      rawAllUnigrams += lmMisc.unigramsFor(key: key)
      rawAllUnigrams += lmCore.unigramsFor(key: key)

      if isCNSEnabled {
        rawAllUnigrams += lmCNS.unigramsFor(key: key)
      }

      if isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: key)
        rawAllUnigrams += lmSymbols.unigramsFor(key: key)
      }

      // 準備過濾清單。因為我們在 Swift 使用 NSOrderedSet，所以就不需要統計清單了。
      var filteredPairs: Set<Megrez.KeyValuePair> = []

      // 載入要過濾的 KeyValuePair 清單。
      for unigram in lmFiltered.unigramsFor(key: key) {
        filteredPairs.insert(unigram.keyValue)
      }

      return filterAndTransform(
        unigrams: rawAllUnigrams,
        filter: filteredPairs
      )
    }

    /// If the model has unigrams for the given key.
    /// @param key The key.
    override open func hasUnigramsFor(key: String) -> Bool {
      if key == " " { return true }

      if !lmFiltered.hasUnigramsFor(key: key) {
        return lmUserPhrases.hasUnigramsFor(key: key) || lmCore.hasUnigramsFor(key: key)
      }

      return !unigramsFor(key: key).isEmpty
    }

    public func associatedPhrasesForKey(_ key: String) -> [String] {
      lmAssociates.valuesFor(key: key) ?? []
    }

    public func hasAssociatedPhrasesForKey(_ key: String) -> Bool {
      lmAssociates.hasValuesFor(key: key)
    }

    // MARK: - Core Functions (Private)

    func filterAndTransform(
      unigrams: [Megrez.Unigram],
      filter filteredPairs: Set<Megrez.KeyValuePair>
    ) -> [Megrez.Unigram] {
      var results: [Megrez.Unigram] = []
      var insertedPairs: Set<Megrez.KeyValuePair> = []

      for unigram in unigrams {
        var pair: Megrez.KeyValuePair = unigram.keyValue
        if filteredPairs.contains(pair) {
          continue
        }

        if isPhraseReplacementEnabled {
          let replacement = lmReplacements.valuesFor(key: pair.value)
          if !replacement.isEmpty {
            IME.prtDebugIntel("\(pair.value) -> \(replacement)")
            pair.value = replacement
          }
        }

        if !insertedPairs.contains(pair) {
          results.append(Megrez.Unigram(keyValue: pair, score: unigram.score))
          insertedPairs.insert(pair)
        }
      }
      return results
    }
  }
}
