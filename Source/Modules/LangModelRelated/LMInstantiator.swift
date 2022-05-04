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
private var lmCNS = vChewing.LMLite(consolidate: false)
private var lmSymbols = vChewing.LMCore(reverse: true, consolidate: false, defaultScore: -13.0, forceDefaultScore: true)

extension vChewing {
  /// LMInstantiator is a facade for managing a set of models including
  /// the input method language model, user phrases and excluded phrases.
  ///
  /// It is the primary model class that the input controller and grammar builder
  /// of vChewing talks to. When the grammar builder starts to build a sentence
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
    // 在函數內部用以記錄狀態的開關。
    public var isPhraseReplacementEnabled = false
    public var isCNSEnabled = false
    public var isSymbolEnabled = false

    /// 介紹一下三個通用的語言模組型別：
    /// LMCore 是全功能通用型的模組，每一筆辭典記錄以 key 為注音、以 [Unigram] 陣列作為記錄內容。
    /// 比較適合那種每筆記錄都有不同的權重數值的語言模組，雖然也可以強制施加權重數值就是了。
    /// 然而缺點是：哪怕你強制施加權重數值，也不會減輕記憶體佔用。
    /// 至於像全字庫這樣所有記錄都使用同一權重數值的模組，可以用 LMLite 以節省記憶體佔用。
    /// LMLite 的辭典內不會存儲權重資料，只會在每次讀取記錄時施加您給定的權重數值。
    /// LMLite 與 LMCore 都會用到多執行緒、以加速載入（不然的話，全部資料載入會耗費八秒左右）。
    /// LMReplacements 與 LMAssociates 均為特種模組，分別擔當語彙置換表資料與使用者聯想詞的資料承載工作。

    // 聲明原廠語言模組
    /// Reverse 的話，第一欄是注音，第二欄是對應的漢字，第三欄是可能的權重。
    /// 不 Reverse 的話，第一欄是漢字，第二欄是對應的注音，第三欄是可能的權重。
    var lmCore = LMCore(reverse: false, consolidate: false, defaultScore: -9.5, forceDefaultScore: false)
    var lmMisc = LMCore(reverse: true, consolidate: false, defaultScore: -1, forceDefaultScore: false)

    // 聲明使用者語言模組。
    // 使用者語言模組使用多執行緒的話，可能會導致一些問題。有時間再仔細排查看看。
    var lmUserPhrases = LMLite(consolidate: true)
    var lmFiltered = LMLite(consolidate: true)
    var lmUserSymbols = LMLite(consolidate: true)
    var lmReplacements = LMReplacments()
    var lmAssociates = LMAssociates()

    // 初期化的函數先保留
    override init() {}

    // 以下這些函數命名暫時保持原樣，等弒神行動徹底結束了再調整。

    public func isDataModelLoaded() -> Bool { lmCore.isLoaded() }
    public func loadLanguageModel(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCore.open(path)
        IME.prtDebugIntel("lmCore: \(lmCore.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmCore.dump()
        }
      } else {
        IME.prtDebugIntel("lmCore: File access failure: \(path)")
      }
    }

    public func isCNSDataLoaded() -> Bool { lmCNS.isLoaded() }
    public func loadCNSData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmCNS.open(path)
        IME.prtDebugIntel("lmCNS: \(lmCNS.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmCNS.dump()
        }
      } else {
        IME.prtDebugIntel("lmCNS: File access failure: \(path)")
      }
    }

    public func isMiscDataLoaded() -> Bool { lmMisc.isLoaded() }
    public func loadMiscData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmMisc.open(path)
        IME.prtDebugIntel("lmMisc: \(lmMisc.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmMisc.dump()
        }
      } else {
        IME.prtDebugIntel("lmMisc: File access failure: \(path)")
      }
    }

    public func isSymbolDataLoaded() -> Bool { lmSymbols.isLoaded() }
    public func loadSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmSymbols.open(path)
        IME.prtDebugIntel("lmSymbol: \(lmSymbols.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmSymbols.dump()
        }
      } else {
        IME.prtDebugIntel("lmSymbols: File access failure: \(path)")
      }
    }

    public func loadUserPhrases(path: String, filterPath: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmUserPhrases.close()
        lmUserPhrases.open(path)
        IME.prtDebugIntel("lmUserPhrases: \(lmUserPhrases.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmUserPhrases.dump()
        }
      } else {
        IME.prtDebugIntel("lmUserPhrases: File access failure: \(path)")
      }
      if FileManager.default.isReadableFile(atPath: filterPath) {
        lmFiltered.close()
        lmFiltered.open(filterPath)
        IME.prtDebugIntel("lmFiltered: \(lmFiltered.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmFiltered.dump()
        }
      } else {
        IME.prtDebugIntel("lmFiltered: File access failure: \(path)")
      }
    }

    public func loadUserSymbolData(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmUserSymbols.close()
        lmUserSymbols.open(path)
        IME.prtDebugIntel("lmUserSymbol: \(lmUserSymbols.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmUserSymbols.dump()
        }
      } else {
        IME.prtDebugIntel("lmUserSymbol: File access failure: \(path)")
      }
    }

    public func loadUserAssociatedPhrases(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmAssociates.close()
        lmAssociates.open(path)
        IME.prtDebugIntel("lmAssociates: \(lmAssociates.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmAssociates.dump()
        }
      } else {
        IME.prtDebugIntel("lmAssociates: File access failure: \(path)")
      }
    }

    public func loadPhraseReplacementMap(path: String) {
      if FileManager.default.isReadableFile(atPath: path) {
        lmReplacements.close()
        lmReplacements.open(path)
        IME.prtDebugIntel("lmReplacements: \(lmReplacements.count) entries of data loaded from: \(path)")
        if path.contains("vChewing/") {
          lmReplacements.dump()
        }
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
      rawAllUnigrams += lmUserPhrases.unigramsFor(key: key, score: 0.0).reversed()
      if lmUserPhrases.unigramsFor(key: key).isEmpty {
        IME.prtDebugIntel("Not found in UserPhrasesUnigram(\(lmUserPhrases.count)): \(key)")
      }

      // LMMisc 與 LMCore 的 score 在 (-10.0, 0.0) 這個區間內。
      rawAllUnigrams += lmMisc.unigramsFor(key: key)
      rawAllUnigrams += lmCore.unigramsFor(key: key)

      if isCNSEnabled {
        rawAllUnigrams += lmCNS.unigramsFor(key: key, score: -11)
      }

      if isSymbolEnabled {
        rawAllUnigrams += lmUserSymbols.unigramsFor(key: key, score: -12.0)
        if lmUserSymbols.unigramsFor(key: key).isEmpty {
          IME.prtDebugIntel("Not found in UserSymbolUnigram(\(lmUserSymbols.count)): \(key)")
        }

        rawAllUnigrams += lmSymbols.unigramsFor(key: key)
      }

      // 準備過濾清單與統計清單
      var insertedPairs: Set<Megrez.KeyValuePair> = []  // 統計清單
      var filteredPairs: Set<Megrez.KeyValuePair> = []  // 過濾清單

      // 載入要過濾的 KeyValuePair 清單。
      for unigram in lmFiltered.unigramsFor(key: key) {
        filteredPairs.insert(unigram.keyValue)
      }

      var debugOutput = "\n"
      for neta in rawAllUnigrams {
        debugOutput += "RAW: \(neta.keyValue.key) \(neta.keyValue.value) \(neta.score)\n"
      }
      if debugOutput == "\n" {
        debugOutput = "RAW: No match found in all unigrams."
      }
      IME.prtDebugIntel(debugOutput)

      return filterAndTransform(
        unigrams: rawAllUnigrams,
        filter: filteredPairs, inserted: &insertedPairs
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
      filter filteredPairs: Set<Megrez.KeyValuePair>,
      inserted insertedPairs: inout Set<Megrez.KeyValuePair>
    ) -> [Megrez.Unigram] {
      var results: [Megrez.Unigram] = []

      for unigram in unigrams {
        var pair: Megrez.KeyValuePair = unigram.keyValue
        if filteredPairs.contains(pair) {
          continue
        }

        if isPhraseReplacementEnabled {
          let replacement = lmReplacements.valuesFor(key: pair.value)
          if !replacement.isEmpty, pair.value.count == replacement.count {
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
