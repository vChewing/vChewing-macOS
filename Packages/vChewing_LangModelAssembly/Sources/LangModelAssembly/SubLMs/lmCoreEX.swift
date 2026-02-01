// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Megrez

// MARK: - LMAssembly.LMCoreEX

extension LMAssembly {
  /// 與之前的 LMCore 不同，LMCoreEX 不在辭典內記錄實體，而是記錄 range 範圍。
  /// 需要資料的時候，直接拿 range 去 strData 取資料。
  /// 資料記錄原理與上游 C++ 的 ParselessLM 差不多，但用的是 Swift 原生手段。
  /// 主要時間消耗仍在 For 迴圈，但這個算法可以顯著減少記憶體佔用。
  struct LMCoreEX {
    // MARK: Lifecycle

    /// 初期化該語言模型。
    ///
    /// - parameters:
    ///   - reverse: 聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    ///   - consolidate: 請且僅請對使用者語言模組啟用該參數：是否自動整理格式。
    ///   - defaultScore: 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    ///   - forceDefaultScore: 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    init(
      reverse: Bool = false,
      consolidate: Bool = false,
      defaultScore scoreDefault: ScoreAssigner? = nil,
      forceDefaultScore: Bool = false
    ) {
      self.rangeMap = [:]
      self.allowConsolidation = consolidate
      self.shouldReverse = reverse
      self.defaultScore = scoreDefault ?? defaultScore
      self.shouldForceDefaultScore = forceDefaultScore
    }

    // MARK: Internal

    private(set) var filePath: String?

    /// 資料庫辭典。索引內容為注音字串，資料內容則為字串首尾範圍、方便自 strData 取資料。
    var rangeMap: [String: [Range<String.Index>]] = [:]
    /// 資料庫追加辭典。
    var temporaryMap: [String: [Megrez.Unigram]] = [:]
    /// 資料庫字串陣列。
    var strData: String = ""
    /// 聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    var shouldReverse = false
    var allowConsolidation = false
    /// 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    var defaultScore: ScoreAssigner = { _ in 0 }
    /// 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    var shouldForceDefaultScore = false

    /// 資料陣列內承載的資料筆數。
    var count: Int { rangeMap.count }

    /// 偵測資料庫辭典內是否已經有載入的資料。
    var isLoaded: Bool { !rangeMap.isEmpty }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    @discardableResult
    mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }

      let oldPath = filePath
      filePath = nil

      let consolidated = allowConsolidation
      do {
        let rawStrData: String = try LMAssembly.withFileHandleQueueSync {
          if allowConsolidation {
            LMConsolidator.fixEOF(path: path)
            LMConsolidator.consolidate(path: path, pragma: true)
          }
          return try String(contentsOfFile: path, encoding: .utf8)
        }
        var processed = rawStrData
        if !consolidated {
          processed = processed.replacingOccurrences(of: "\t", with: " ")
          processed = processed.replacingOccurrences(of: "\r", with: "\n")
        }
        replaceData(textData: processed)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    mutating func replaceData(textData rawStrData: String) {
      if strData == rawStrData { return }

      // 清理之前的資料以釋放記憶體
      rangeMap.removeAll(keepingCapacity: false)
      temporaryMap.removeAll(keepingCapacity: false)

      strData = rawStrData
      var newMap: [String: [Range<String.Index>]] = [:]
      let shouldReverse = shouldReverse // 必需，否則下文的 closure 會出錯。
      strData.parse(splitee: "\n") { theRange in
        let theCells = rawStrData[theRange].split(separator: " ")
        if theCells.count >= 2, theCells[0].description.first != "#" {
          var theKey = shouldReverse ? String(theCells[1]) : String(theCells[0])
          theKey.convertToPhonabets()
          newMap[theKey, default: []].append(theRange)
        }
      }
      rangeMap = newMap
      // 明確釋放 newMap 記憶體
      newMap.removeAll(keepingCapacity: false)
    }

    /// 將當前語言模組的資料庫辭典自記憶體內卸除。
    mutating func clear() {
      filePath = nil
      strData.removeAll(keepingCapacity: false)
      rangeMap.removeAll(keepingCapacity: false)
      temporaryMap.removeAll(keepingCapacity: false)
    }

    // MARK: - Advanced features

    func saveData() {
      guard let filePath = filePath else { return }
      LMAssembly.withFileHandleQueueSync {
        var dataToWrite = strData
        do {
          if !temporaryMap.isEmpty {
            temporaryMap.forEach { neta in
              neta.value.forEach { unigram in
                dataToWrite.append("\(unigram.value) \(neta.key) \(unigram.score.description)\n")
              }
            }
          }
          try dataToWrite.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
          vCLMLog("Failed to save current database to: \(filePath)")
        }
      }
    }

    /// 將當前資料庫辭典的內容以文本的形式輸出至 macOS 內建的 Console.app。
    ///
    /// 該功能僅作偵錯之用途。
    func dump() {
      var strDump = ""
      for entry in rangeMap {
        let netaRanges: [Range<String.Index>] = entry.value
        for netaRange in netaRanges {
          let neta = strData[netaRange]
          let addline = neta + "\n"
          strDump += addline
        }
      }
      vCLMLog(strDump)
    }

    /// 根據給定的讀音索引鍵，來獲取資料庫辭典內的對應資料陣列的字串首尾範圍資料、據此自 strData 取得字串形式的資料、生成單元圖陣列。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    func unigramsFor(
      key: String,
      keyArray: [String]? = nil,
      omitNonTemporarySingleCharNonSymbolUnigrams: Bool = false,
      factorySingleReadingValueHashes: Set<Int> = []
    )
      -> [Megrez.Unigram] {
      let keyArray = keyArray ?? key.split(separator: "-").map(\.description)
      let singleSegLength: Bool = keyArray.count == 1
      let noPunctuations = keyArray.allSatisfy { !$0.hasPrefix("_") }
      var grams: [Megrez.Unigram] = []
      let omitUserPhrases: Bool = [
        omitNonTemporarySingleCharNonSymbolUnigrams,
        singleSegLength,
        noPunctuations,
      ].reduce(true) { $0 && $1 }
      if let arrRangeRecords: [Range<String.Index>] = rangeMap[key] {
        for netaRange in arrRangeRecords {
          let neta = strData[netaRange].split(separator: " ")
          let theValue: String = shouldReverse ? String(neta[0]) : String(neta[1])
          let valueHash = theValue.hashValue
          // 完全排除使用者詞庫中的單漢字結果（除非原廠辭典並未包含這個配對），避免其影響組字結果。
          checkOmission: if omitUserPhrases {
            let isFactoryValue = factorySingleReadingValueHashes.contains(valueHash)
            guard isFactoryValue else { break checkOmission }
            continue
          }
          var theScore: Double
          if neta.count >= 3, !shouldForceDefaultScore, !neta[2].contains("#") {
            theScore = .init(String(neta[2])) ?? defaultScore((keyArray, theValue))
          } else {
            theScore = defaultScore(nil)
          }
          if theScore > 0 {
            theScore *= -1 // 應對可能忘記寫負號的情形
          }
          grams.append(Megrez.Unigram(keyArray: keyArray, value: theValue, score: theScore))
        }
      }
      if let arrOtherRecords: [Megrez.Unigram] = temporaryMap[key] {
        // 完全排除使用者詞庫中的單漢字結果（除非原廠辭典並未包含這個配對），避免其影響組字結果。
        let arrOtherRecordsFiltered = arrOtherRecords.filter {
          guard omitUserPhrases else { return true }
          return !factorySingleReadingValueHashes.contains($0.value.hashValue)
        }
        grams.append(contentsOf: arrOtherRecordsFiltered)
      }
      return grams
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    func hasUnigramsFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

extension LMAssembly.LMCoreEX {
  var dictRepresented: [String: [String]] {
    var result = [String: [String]]()
    rangeMap.forEach { key, arrValueRanges in
      result[key, default: []] = arrValueRanges.map { currentRange in
        strData[currentRange].description
      }
    }
    return result
  }
}
