// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa

// MARK: - LMAssembly.LMCoreEX

extension LMAssembly {
  /// 與之前的 LMCore 不同，LMCoreEX 不在辭典內記錄實體，而是記錄位元組範圍。
  /// 需要資料的時候，直接拿範圍去 rawData 取資料。
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
      self.allowConsolidation = consolidate
      self.shouldReverse = reverse
      self.defaultScore = scoreDefault ?? defaultScore
      self.shouldForceDefaultScore = forceDefaultScore
    }

    // MARK: Internal

    /// 單筆行 entry：轉換後的 key（於 keyData）與整行（於 rawData）的位元組範圍。
    struct CoreEXEntry: Sendable {
      let keyStart: UInt32
      let keyEnd: UInt32
      let lineStart: UInt32
      let lineEnd: UInt32
    }

    var filePath: String?

    /// 原始資料的 UTF-8 位元組（取代舊版 `strData: String` 的實體儲存）。
    private(set) var rawData: [UInt8] = []
    /// 資料庫追加辭典。
    var temporaryMap: [String: [Homa.Gram]] = [:]
    /// 聲明原始檔案內第一、二縱列的內容是否彼此顛倒。
    var shouldReverse = false
    var allowConsolidation = false
    /// 當某一筆資料內的權重資料毀損時，要施加的預設權重。
    var defaultScore: ScoreAssigner = { _ in 0 }
    /// 啟用該選項的話，會強制施加預設權重、而無視原始權重資料。
    var shouldForceDefaultScore = false

    /// 資料庫字串陣列（自 `rawData` 即時物化，供外部唯讀消費）。
    var strData: String { String(decoding: rawData, as: UTF8.self) }

    /// 資料陣列內承載的資料筆數（唯一 key 數量）。
    var count: Int { uniqueKeyCount }

    /// 偵測資料庫辭典內是否已經有載入的資料。
    var isLoaded: Bool { !entries.isEmpty }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    @discardableResult
    mutating func open(_ path: String) -> Bool {
      // 若先前已載入資料，先清除再載入新資料，避免呼叫方忘記 clear() 造成舊資料殘留。
      if isLoaded { clear() }

      let oldPath = filePath
      filePath = nil

      let consolidated = allowConsolidation
      do {
        // 直接以位元組讀入：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
        let newBytes: [UInt8] = try LMAssembly.withFileHandleQueueSync {
          if consolidated {
            LMConsolidator.fixEOF(path: path)
            LMConsolidator.consolidate(path: path, pragma: true)
          }
          return [UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
        }
        var processed = newBytes
        if !consolidated {
          // 未啟用 consolidation 時，以位元組層級將 CR 換成 LF（對應舊 `replacingOccurrences(of: "\r", with: "\n")`）。
          processed = newBytes.map { $0 == 0x0D ? 0x0A : $0 }
        }
        replaceData(bytes: processed)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將資料從字串讀入至資料庫辭典內。
    /// - parameters:
    ///   - textData: 給定資料字串。
    mutating func replaceData(textData rawStrData: String) {
      replaceData(bytes: Array(rawStrData.utf8))
    }

    /// 將資料從位元組緩衝讀入至資料庫辭典內（非法 UTF-8 位元組原樣保留）。
    /// - parameters:
    ///   - bytes: 給定資料位元組。
    mutating func replaceData(bytes newBytes: [UInt8]) {
      // 以位元組層級將 Tab 換成空格（對應舊 `replacingOccurrences(of: "\t", with: " ")`）。
      let processed = newBytes.map { $0 == 0x09 ? 0x20 : $0 }
      if rawData == processed { return }

      // 清理之前的資料以釋放記憶體
      rawData = processed
      keyData.removeAll(keepingCapacity: false)
      entries.removeAll(keepingCapacity: false)
      uniqueKeyCount = 0
      temporaryMap.removeAll(keepingCapacity: false)

      // 載入期暫存：轉換後 key → 行範圍（依檔案行序）。
      let shouldReverse = shouldReverse // 必需，否則下文的 closure 會出錯。
      var protoLineMap: [String: [Range<Int>]] = [:]
      rawData.parseByteLines { lineRange in
        var firstCellRange: Range<Int>?
        var secondCellRange: Range<Int>?
        rawData.parseByteCells(in: lineRange) { currentRange, currentIndex in
          switch currentIndex {
          case 0:
            firstCellRange = currentRange
            return true
          case 1:
            secondCellRange = currentRange
            return false
          default:
            return false
          }
        }
        guard let firstCellRange, let secondCellRange else { return }
        guard rawData[firstCellRange.lowerBound] != 0x23 else { return } // "#" 開頭的行跳過。
        let keyRange = shouldReverse ? secondCellRange : firstCellRange
        var theKey = String(decoding: rawData[keyRange], as: UTF8.self)
        theKey.convertToPhonabets()
        protoLineMap[theKey, default: []].append(lineRange)
      }
      // 依 key bytes 排序建置最終索引；同 key 的行已在暫存階段依檔案行序排列。
      let sortedKeys = protoLineMap.keys.sorted {
        $0.utf8.lexicographicallyPrecedes($1.utf8)
      }
      uniqueKeyCount = sortedKeys.count
      var newKeyData = [UInt8]()
      var newEntries: [CoreEXEntry] = []
      for key in sortedKeys {
        let keyStart = UInt32(newKeyData.count)
        newKeyData.append(contentsOf: key.utf8)
        let keyEnd = UInt32(newKeyData.count)
        for lineRange in protoLineMap[key] ?? [] {
          newEntries.append(.init(
            keyStart: keyStart,
            keyEnd: keyEnd,
            lineStart: UInt32(lineRange.lowerBound),
            lineEnd: UInt32(lineRange.upperBound)
          ))
        }
      }
      keyData = newKeyData
      entries = newEntries
      // 明確釋放暫存辭典記憶體
      protoLineMap.removeAll(keepingCapacity: false)
    }

    /// 將當前語言模組的資料庫辭典自記憶體內卸除。
    mutating func clear() {
      filePath = nil
      rawData.removeAll(keepingCapacity: false)
      keyData.removeAll(keepingCapacity: false)
      entries.removeAll(keepingCapacity: false)
      uniqueKeyCount = 0
      temporaryMap.removeAll(keepingCapacity: false)
    }

    // MARK: - Advanced features

    func saveData() {
      guard let filePath = filePath else { return }
      LMAssembly.withFileHandleQueueSync {
        var dataToWrite = rawData
        if !temporaryMap.isEmpty {
          temporaryMap.forEach { neta in
            neta.value.forEach { unigram in
              dataToWrite.append(contentsOf: "\(unigram.current) \(neta.key) \(unigram.probability.description)\n".utf8)
            }
          }
        }
        do {
          // 以原始位元組寫回：非法 UTF-8 位元組原樣保留。
          try Data(dataToWrite).write(to: URL(fileURLWithPath: filePath), options: .atomic)
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
      for entry in entries {
        let neta = String(
          decoding: rawData[Int(entry.lineStart) ..< Int(entry.lineEnd)],
          as: UTF8.self
        )
        let addline = neta + "\n"
        strDump += addline
      }
      vCLMLog(strDump)
    }

    /// 根據給定的讀音索引鍵，來獲取資料庫辭典內的對應資料陣列的字串首尾範圍資料、據此自 rawData 取得字串形式的資料、生成單元圖陣列。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    func unigramsFor(
      key: String,
      keyArray: [String]? = nil,
      omitNonTemporarySingleCharNonSymbolUnigrams: Bool = false,
      factorySingleReadingValueHashes: Set<Int> = []
    )
      -> [Homa.Gram] {
      let keyArray = keyArray ?? key.split(separator: "-").map(\.description)
      let singleSegLength: Bool = keyArray.count == 1
      let noPunctuations = keyArray.allSatisfy { !$0.hasPrefix("_") }
      var grams: [Homa.Gram] = []
      let omitUserPhrases: Bool = [
        omitNonTemporarySingleCharNonSymbolUnigrams,
        singleSegLength,
        noPunctuations,
      ].reduce(true) { $0 && $1 }
      if let matchedRange = entryRange(forKey: key) {
        for entryIndex in matchedRange {
          let entry = entries[entryIndex]
          let lineRange = Int(entry.lineStart) ..< Int(entry.lineEnd)
          var firstCellRange: Range<Int>?
          var secondCellRange: Range<Int>?
          var thirdCellRange: Range<Int>?
          rawData.parseByteCells(in: lineRange) { currentRange, currentIndex in
            switch currentIndex {
            case 0:
              firstCellRange = currentRange
              return true
            case 1:
              secondCellRange = currentRange
              return true
            case 2:
              thirdCellRange = currentRange
              return false
            default:
              return false
            }
          }
          guard let firstCellRange, let secondCellRange else { continue }
          let valueRange = shouldReverse ? firstCellRange : secondCellRange
          let theValue = String(decoding: rawData[valueRange], as: UTF8.self)
          let valueHash = theValue.hashValue
          // 完全排除使用者詞庫中的單漢字結果（除非原廠辭典並未包含這個配對），避免其影響組字結果。
          checkOmission: if omitUserPhrases {
            let isFactoryValue = factorySingleReadingValueHashes.contains(valueHash)
            guard isFactoryValue else { break checkOmission }
            continue
          }
          var theScore: Double
          if let thirdCellRange, !shouldForceDefaultScore, !rawData[thirdCellRange].contains(0x23) {
            theScore = .init(String(decoding: rawData[thirdCellRange], as: UTF8.self))
              ?? defaultScore((keyArray, theValue))
          } else {
            theScore = defaultScore(nil)
          }
          if theScore > 0 {
            theScore *= -1 // 應對可能忘記寫負號的情形
          }
          grams.append(Homa.Gram(keyArray: keyArray, value: theValue, score: theScore))
        }
      }
      if let arrOtherRecords: [Homa.Gram] = temporaryMap[key] {
        // 完全排除使用者詞庫中的單漢字結果（除非原廠辭典並未包含這個配對），避免其影響組字結果。
        let arrOtherRecordsFiltered = arrOtherRecords.filter {
          guard omitUserPhrases else { return true }
          return !factorySingleReadingValueHashes.contains($0.current.hashValue)
        }
        grams.append(contentsOf: arrOtherRecordsFiltered)
      }
      return grams
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    func hasUnigramsFor(key: String) -> Bool {
      entryRange(forKey: key) != nil || temporaryMap[key] != nil
    }

    /// 根據給定的前綴，返回所有以該前綴開頭的索引鍵。
    /// 同時搜尋主表（二分搜尋 lower-bound + 前綴掃描）與 `temporaryMap.keys`（線性掃描）。
    /// - Parameter prefix: 前綴字串。
    /// - Returns: 匹配的索引鍵陣列。
    func keys(matchingPrefix prefix: String) -> [String] {
      guard !prefix.isEmpty else { return [] }
      let prefixUTF8 = Array(prefix.utf8)
      var result: [String] = []
      var seen: Set<String> = []
      // 二分搜尋 entries：找到第一個不小於 prefix 的位置
      var low = 0
      var high = entries.count
      while low < high {
        let mid = (low + high) / 2
        let e = entries[mid]
        let keyRange = Int(e.keyStart) ..< Int(e.keyEnd)
        // 與 prefix 比較：entry key 以 prefix 開頭（且更長）時視為不小於 prefix，
        // 因此一般的字典序比較即可充當前綴搜尋的 lower-bound。
        if keyData.compareByteRange(keyRange, with: prefixUTF8) < 0 {
          low = mid + 1
        } else {
          high = mid
        }
      }
      var i = low
      while i < entries.count {
        let e = entries[i]
        let keyRange = Int(e.keyStart) ..< Int(e.keyEnd)
        guard keyRange.count >= prefixUTF8.count else { break }
        var isPrefix = true
        for j in 0 ..< prefixUTF8.count {
          if keyData[keyRange.lowerBound + j] != prefixUTF8[j] { isPrefix = false; break }
        }
        guard isPrefix else { break }
        let key = String(decoding: keyData[keyRange], as: UTF8.self)
        if seen.insert(key).inserted {
          result.append(key)
        }
        i += 1
      }
      // 線性掃描 temporaryMap（資料量通常很小）
      for key in temporaryMap.keys.sorted() where key.hasPrefix(prefix) {
        if seen.insert(key).inserted {
          result.append(key)
        }
      }
      return result
    }

    /// 根據給定的讀音索引鍵前綴，來獲取資料庫辭典內所有匹配的資料陣列。
    /// 對每個匹配到的 key，會自動推導其正確的 `keyArray` 並傳入 exact-match 查詢。
    /// - parameters:
    ///   - prefix: 讀音索引鍵前綴。
    ///   - keyArray: 可選，若提供則用於所有匹配結果（通常應留 nil 讓方法自行推導）。
    ///   - omitNonTemporarySingleCharNonSymbolUnigrams: 是否省略非暫存的單字符非符號單元圖。
    ///   - factorySingleReadingValueHashes: 原廠單讀音值雜湊集合，用於過濾。
    func unigramsFor(
      keyPrefix prefix: String,
      keyArray: [String]? = nil,
      omitNonTemporarySingleCharNonSymbolUnigrams: Bool = false,
      factorySingleReadingValueHashes: Set<Int> = []
    )
      -> [Homa.Gram] {
      let matchingKeys = keys(matchingPrefix: prefix)
      var grams: [Homa.Gram] = []
      for key in matchingKeys {
        let inferredKeyArray = keyArray ?? key.split(separator: "-").map(\.description)
        grams.append(contentsOf: unigramsFor(
          key: key,
          keyArray: inferredKeyArray,
          omitNonTemporarySingleCharNonSymbolUnigrams: omitNonTemporarySingleCharNonSymbolUnigrams,
          factorySingleReadingValueHashes: factorySingleReadingValueHashes
        ))
      }
      return grams
    }

    // MARK: Private

    /// 轉換後注音 keys 的 UTF-8 位元組 blob（key 經 `convertToPhonabets` 轉換，非原文子字串）。
    private var keyData: [UInt8] = []
    /// 按 key bytes 排序的行索引；同 key 的行依檔案行序排列。
    private var entries: [CoreEXEntry] = []
    /// 唯一 key 數量（entries 以行為單位，同 key 可能多行）。
    private var uniqueKeyCount = 0

    /// 二分搜尋 key，回傳對應 entries 的範圍（同 key 的行連續排列）。
    private func entryRange(forKey key: String) -> Range<Int>? {
      let keyUTF8 = Array(key.utf8)
      // Lower bound.
      var lo = 0, hi = entries.count
      while lo < hi {
        let mid = lo + (hi - lo) / 2
        let e = entries[mid]
        let cmp = keyData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
        if cmp < 0 { lo = mid + 1 } else { hi = mid }
      }
      guard lo < entries.count else { return nil }
      let first = entries[lo]
      guard keyData.compareByteRange(Int(first.keyStart) ..< Int(first.keyEnd), with: keyUTF8) == 0
      else { return nil }
      var upper = lo
      while upper < entries.count {
        let e = entries[upper]
        guard keyData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8) == 0
        else { break }
        upper += 1
      }
      return lo ..< upper
    }
  }
}

extension LMAssembly.LMCoreEX {
  var dictRepresented: [String: [String]] {
    var result = [String: [String]]()
    entries.forEach { entry in
      let key = String(decoding: keyData[Int(entry.keyStart) ..< Int(entry.keyEnd)], as: UTF8.self)
      let line = String(decoding: rawData[Int(entry.lineStart) ..< Int(entry.lineEnd)], as: UTF8.self)
      result[key, default: []].append(line)
    }
    return result
  }
}
