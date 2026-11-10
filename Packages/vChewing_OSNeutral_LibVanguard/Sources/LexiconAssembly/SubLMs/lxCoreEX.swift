// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa

// MARK: - LXAssembly.LXCoreEX

extension LXAssembly {
  /// 與之前的 LXCore 不同，LXCoreEX 不在辭典內記錄實體，而是記錄位元組範圍。
  /// 需要資料的時候，直接拿範圍去 rawData 取資料。
  struct LXCoreEX {
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

    /// 本資料模組之儲存後端。預設沿用行程級之 `LXAssembly.userDataLocator`；
    /// 注入專屬的後端即可讓該模組之讀寫完全脫離硬碟。
    var locator: any UserDataLocator = LXAssembly.userDataLocator

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

      let consolidated = allowConsolidation && locator.isBackedByFileSystem
      do {
        // 直接以位元組讀入：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
        let backend = locator
        let newBytes: [UInt8] = try LXAssembly.withFileHandleQueueSync {
          if consolidated {
            LXConsolidator.fixEOF(path: path)
            LXConsolidator.consolidate(path: path, pragma: true)
          }
          return [UInt8](try backend.read(at: URL(fileURLWithPath: path)))
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
      // 以位元組層級將 Tab 換成空白字元（對應舊 `replacingOccurrences(of: "\t", with: " ")`）。
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
      // 供載入期診斷：資料列之檔案序行號與範圍（診斷於索引建置完成之後另跑，見下）。
      var diagnosticLines: [(number: Int, range: Range<Int>)] = []
      var lineNumber = 0
      rawData.parseByteLines { lineRange in
        lineNumber += 1
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
        diagnosticLines.append((lineNumber, lineRange))
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
      diagnose(lines: diagnosticLines)
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

    // MARK: - 增量更新

    /// 就地在記憶體索引內追加一列：**只解析該列**，不重讀整檔、亦不重解析既有列。
    ///
    /// 內容語義與檔案內之列相同（`值 讀音 [權重] [#NGRAM:前文鏈]`）：key 取第二格
    /// （`shouldReverse` 為真時；本類型之三份使用者資料皆如此），`#` 起首之註解列一律不收。
    /// 既有內容若未以斷行收尾，先補一個斷行——與 `UserPhraseFileWriter` 之追加語義一致，
    /// 否則記憶體內之 `rawData` 會與磁碟上之內容分歧。
    ///
    /// - Important: 本函式只動**索引**與 `rawData`；`#NGRAM:` 閘門之判定仍在查詢時逐列為之，
    ///   故增量收列與整檔重載之查詢結果一致。
    /// - Parameter row: 該列之內容（可含結尾斷行）。
    /// - Returns: 是否已建入索引；輸入不合格時回傳假、記憶體狀態不變。
    @discardableResult
    mutating func insertRow(_ row: String) -> Bool {
      var rowBytes = Array(row.utf8)
      guard !rowBytes.isEmpty else { return false }
      if rowBytes.last != 0x0A { rowBytes.append(0x0A) }
      // 既有內容缺斷行時先補一個（與落盤端之補行語義一致）。
      let needsLeadingNewline = rawData.last.map { $0 != 0x0A } ?? false
      let rollbackStart = rawData.count
      let lineStart = rawData.count + (needsLeadingNewline ? 1 : 0)
      if needsLeadingNewline { rawData.append(0x0A) }
      rawData.append(contentsOf: rowBytes)
      // 與 `parseByteLines` 之語義一致：entry 之範圍**不含**結尾斷行。
      let lineRange = lineStart ..< (rawData.count - 1)

      // 只解析這一列的前兩格。
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
      guard let firstCellRange, let secondCellRange,
            rawData[firstCellRange.lowerBound] != 0x23
      else {
        // 註解列、或格數不足：回滾這一列之追加。
        rawData.removeSubrange(rollbackStart ..< rawData.count)
        return false
      }
      let keyRange = shouldReverse ? secondCellRange : firstCellRange
      var theKey = String(decoding: rawData[keyRange], as: UTF8.self)
      theKey.convertToPhonabets()
      insertIndexEntry(keyBytes: Array(theKey.utf8), lineRange: lineRange)
      return true
    }

    /// 就地在記憶體索引內移除一列：命中之列於 `rawData` 內以 NUL 覆寫前兩格
    /// （與 `UserPhraseFileWriter` 之落盤語義一致），並自索引內除名。
    ///
    /// - Parameter cells: 該列之前兩格（`[值, 讀音]`）。
    /// - Returns: 是否確有一列被移除。
    @discardableResult
    mutating func removeRow(matching cells: [String]) -> Bool {
      guard cells.count >= 2 else { return false }
      let keyChain = shouldReverse ? cells[1] : cells[0]
      guard let keyRange = entryRange(forKey: keyChain) else { return false }
      let spacePrefixed = Array("\(cells[0]) \(cells[1])".utf8)
      let tabPrefixed = Array("\(cells[0])\t\(cells[1])".utf8)
      let prefixLength = spacePrefixed.count // 兩者等長
      var didRemove = false
      var survivors: [CoreEXEntry] = []
      survivors.reserveCapacity(entries.count)
      for (offset, entry) in entries.enumerated() {
        guard keyRange.contains(offset) else {
          survivors.append(entry)
          continue
        }
        let headStart = Int(entry.lineStart)
        guard headStart + prefixLength <= rawData.count,
              Array(rawData[headStart ..< headStart + prefixLength]) == spacePrefixed
              || Array(rawData[headStart ..< headStart + prefixLength]) == tabPrefixed
        else {
          survivors.append(entry)
          continue
        }
        for offsetInLine in 0 ..< prefixLength {
          rawData[headStart + offsetInLine] = 0
        }
        didRemove = true
        continue
      }
      guard didRemove else { return false }
      let keyBytes = Array(keyChain.utf8)
      let stillHasKey = survivors.contains { entry in
        keyData.compareByteRange(Int(entry.keyStart) ..< Int(entry.keyEnd), with: keyBytes) == 0
      }
      if !stillHasKey { uniqueKeyCount = Swift.max(0, uniqueKeyCount - 1) }
      entries = survivors
      return true
    }

    // MARK: - Advanced features

    func saveData() {
      guard let filePath = filePath else { return }
      LXAssembly.withFileHandleQueueSync {
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
          try locator.write(Data(dataToWrite), to: URL(fileURLWithPath: filePath))
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
          let parsed = parseLine(lineRange)
          guard let firstCellRange = parsed.firstCell,
                let secondCellRange = parsed.secondCell
          else { continue }
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
          if let scoreCell = parsed.scoreCell, !shouldForceDefaultScore,
             !rawData[scoreCell].contains(0x23) {
            theScore = .init(String(decoding: rawData[scoreCell], as: UTF8.self))
              ?? defaultScore((keyArray, theValue))
          } else {
            theScore = defaultScore(nil)
          }
          if theScore > 0 {
            theScore *= -1 // 應對可能忘記寫負號的情形
          }
          if parsed.gateCount > 0 {
            // 該列宣告為 n-gram：前文鏈不合格者**整列不生效**——不得落回單元圖，
            // 否則「宣告了卻寫壞」會靜默地以條件機率充當無條件分數。
            guard parsed.gateCount == 1, parsed.issue == nil,
                  let gateCell = parsed.gateCell,
                  let chain = contextChain(ofGateCell: gateCell)
            else { continue }
            grams.append(Homa.Gram(
              keyArray: keyArray,
              current: theValue,
              previous: chain.previous,
              anterior: chain.anterior,
              probability: theScore
            ))
            continue
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

    /// 對「每位置的前綴候選集合」做多位置前綴交集掃描（排序鍵陣列、位元組層級比對）。
    ///
    /// 以排序鍵陣列本身充當索引的「sorted-array trie walk」：先以位置 0 的首字元範圍
    /// 二分定位連續區間（initial 收斂，對齊整詞簡拼查詢的 `initialZhuyinOnly` 精神），
    /// 再於區間內逐鍵做逐位置 byte 前綴比對、及早退出。訪問鍵數與「笛卡爾乘積」無關，
    /// 避免 `ysxb` 類查詢把詞庫查詢展開成天文數字。語義與「逐 combo 前綴查詢的聯集」
    /// 完全一致（∀i 第 i 段以某個候選前綴開頭）。
    /// - Parameter prefixCells: 每位置的前綴候選（如 `[["ㄧ","ㄩ"],["ㄕ","ㄙ"],["ㄒ"],["ㄅ"]]`）。
    /// - Returns: 匹配的讀音索引鍵（依排序序、去重）。
    func keys(matchingPrefixesByPosition prefixCells: [[String]]) -> [String] {
      guard !prefixCells.isEmpty else { return [] }
      let cellBytes = prefixCells.map { cell in cell.map { Array($0.utf8) }.filter { !$0.isEmpty } }
      guard cellBytes.allSatisfy({ !$0.isEmpty }) else { return [] }
      let firstScalars = cellBytes[0].map { bytes in
        Self.firstScalarBytes(bytes)
      }
      guard let minInitial = firstScalars.min(by: { $0.lexicographicallyPrecedes($1) }),
            let maxInitial = firstScalars.max(by: { $0.lexicographicallyPrecedes($1) })
      else { return [] }
      var result: [String] = []
      var seen: Set<String> = []
      // 二分定位 lower bound：第一個「整鍵 ≥ minInitial」的 entry。
      // 由於鍵以「首字元」排序，整鍵比較即可正確找出首字元 ≥ minInitial 的區間起點。
      var low = 0
      var high = entries.count
      while low < high {
        let mid = (low + high) / 2
        let e = entries[mid]
        let keyRange = Int(e.keyStart) ..< Int(e.keyEnd)
        if keyData.compareByteRange(keyRange, with: minInitial) < 0 {
          low = mid + 1
        } else {
          high = mid
        }
      }
      var i = low
      while i < entries.count {
        let e = entries[i]
        let keyRange = Int(e.keyStart) ..< Int(e.keyEnd)
        // 首字元超出 maxInitial → 停止（排序保證）。
        if Self.compareFirstScalar(keyData, at: keyRange.lowerBound, against: maxInitial) > 0 { break }
        if Self.keyMatchesCells(keyData, keyRange: keyRange, cellBytes: cellBytes) {
          let key = String(decoding: keyData[keyRange], as: UTF8.self)
          if seen.insert(key).inserted { result.append(key) }
        }
        i += 1
      }
      // 線性掃描 temporaryMap（資料量通常很小）。
      for key in temporaryMap.keys.sorted() {
        let keyBytes = Array(key.utf8)
        if Self.keyMatchesCells(keyBytes, keyRange: 0 ..< keyBytes.count, cellBytes: cellBytes),
           seen.insert(key).inserted {
          result.append(key)
        }
      }
      return result
    }

    /// 根據給定的「每位置前綴候選集合」做多位置前綴交集查詢。
    /// 對每個匹配到的 key 自動推導其 `keyArray` 並傳入 exact-match 查詢（同 `unigramsFor(keyPrefix:)`）。
    /// - parameters:
    ///   - prefixCells: 每位置的前綴候選集合。
    ///   - omitNonTemporarySingleCharNonSymbolUnigrams: 是否省略非暫存的單字符非符號單元圖。
    ///   - factorySingleReadingValueHashes: 原廠單讀音值雜湊集合，用於過濾。
    func unigramsFor(
      keyPrefixesByPosition prefixCells: [[String]],
      omitNonTemporarySingleCharNonSymbolUnigrams: Bool = false,
      factorySingleReadingValueHashes: Set<Int> = []
    )
      -> [Homa.Gram] {
      let matchingKeys = keys(matchingPrefixesByPosition: prefixCells)
      var grams: [Homa.Gram] = []
      for key in matchingKeys {
        grams.append(contentsOf: unigramsFor(
          key: key,
          omitNonTemporarySingleCharNonSymbolUnigrams: omitNonTemporarySingleCharNonSymbolUnigrams,
          factorySingleReadingValueHashes: factorySingleReadingValueHashes
        ))
      }
      return grams
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

    // MARK: - n-gram 列（`#NGRAM:前文鏈`）

    /// 一列之標籤區分類結果。
    private struct LineParse {
      var firstCell: Range<Int>?
      var secondCell: Range<Int>?
      /// 第 2 格若非以 `#` 起首之標籤，即為分數格。
      var scoreCell: Range<Int>?
      /// `#NGRAM` 閘門格（重複時取最後一個）。
      var gateCell: Range<Int>?
      var gateCount = 0
      /// 診斷訊息（nil＝本列無問題）。
      var issue: String?
    }

    /// 轉換後注音 keys 的 UTF-8 位元組 blob（key 經 `convertToPhonabets` 轉換，非原文子字串）。
    private var keyData: [UInt8] = []
    /// 按 key bytes 排序的行索引；同 key 的行依檔案行序排列。
    private var entries: [CoreEXEntry] = []
    /// 唯一 key 數量（entries 以行為單位，同 key 可能多行）。
    private var uniqueKeyCount = 0

    /// 取位元組陣列的首個 UTF-8 字元（1–4 bytes）。
    private static func firstScalarBytes(_ bytes: [UInt8]) -> [UInt8] {
      guard let first = bytes.first else { return [] }
      let len = utf8SequenceLength(first)
      return len > 0 && bytes.count >= len ? Array(bytes[0 ..< len]) : [first]
    }

    /// 回傳 UTF-8 首字元位元組數。
    private static func utf8SequenceLength(_ byte: UInt8) -> Int {
      if byte & 0x80 == 0 { return 1 }
      if byte & 0xE0 == 0xC0 { return 2 }
      if byte & 0xF0 == 0xE0 { return 3 }
      if byte & 0xF8 == 0xF0 { return 4 }
      return 0
    }

    /// 比較兩個位元組陣列的字典序（-1 / 0 / 1；共同前綴時短者較小）。
    private static func compareByteArrays(_ lhs: [UInt8], _ rhs: [UInt8]) -> Int {
      let common = Swift.min(lhs.count, rhs.count)
      for index in 0 ..< common {
        if lhs[index] < rhs[index] { return -1 }
        if lhs[index] > rhs[index] { return 1 }
      }
      if lhs.count < rhs.count { return -1 }
      if lhs.count > rhs.count { return 1 }
      return 0
    }

    /// 比較 keyData 於 offset 處的首個 UTF-8 字元與目標位元組陣列（字典序）。
    private static func compareFirstScalar(_ keyData: [UInt8], at offset: Int, against target: [UInt8]) -> Int {
      guard !target.isEmpty, offset < keyData.count else { return 0 }
      let scalarLen = utf8SequenceLength(keyData[offset])
      guard scalarLen > 0, offset + scalarLen <= keyData.count else {
        return compareByteArrays([keyData[offset]], target)
      }
      return compareByteArrays(Array(keyData[offset ..< offset + scalarLen]), target)
    }

    /// 逐位置 byte 前綴比對：key 的第 i 段需以 cellBytes[i] 的任一前綴開頭；
    /// 超出 cell 數的額外段忽略（對齊前綴查詢語義）。任一段不符即回傳 false。
    private static func keyMatchesCells(
      _ keyData: [UInt8],
      keyRange: Range<Int>,
      cellBytes: [[[UInt8]]]
    )
      -> Bool {
      var segStart = keyRange.lowerBound
      var segIndex = 0
      var cursor = keyRange.lowerBound
      while cursor <= keyRange.upperBound, segIndex < cellBytes.count {
        if cursor == keyRange.upperBound || keyData[cursor] == 0x2D { // "-"
          let segEnd = cursor
          let segLen = segEnd - segStart
          var matched = false
          for prefix in cellBytes[segIndex] where segLen >= prefix.count {
            var ok = true
            for j in 0 ..< prefix.count where keyData[segStart + j] != prefix[j] {
              ok = false
              break
            }
            if ok {
              matched = true
              break
            }
          }
          guard matched else { return false }
          segStart = segEnd + 1
          segIndex += 1
          if cursor == keyRange.upperBound { break }
        }
        cursor += 1
      }
      return segIndex == cellBytes.count
    }

    /// 於索引內插入一筆 entry：`keyData` 之新鍵一律附加於尾端（既有 entry 之位移因此不動），
    /// `entries` 則插在「第一筆鍵大於該鍵」之處——與 `entryRange(forKey:)` 之二分搜尋假設一致。
    private mutating func insertIndexEntry(keyBytes: [UInt8], lineRange: Range<Int>) {
      var lo = 0
      var hi = entries.count
      while lo < hi {
        let mid = lo + (hi - lo) / 2
        let entry = entries[mid]
        let comparison = keyData.compareByteRange(
          Int(entry.keyStart) ..< Int(entry.keyEnd), with: keyBytes
        )
        if comparison <= 0 { lo = mid + 1 } else { hi = mid }
      }
      let hasSameKey = lo > 0 && keyData.compareByteRange(
        Int(entries[lo - 1].keyStart) ..< Int(entries[lo - 1].keyEnd), with: keyBytes
      ) == 0
      let keyStart: Int
      if hasSameKey {
        keyStart = Int(entries[lo - 1].keyStart)
      } else {
        keyStart = keyData.count
        keyData.append(contentsOf: keyBytes)
        uniqueKeyCount += 1
      }
      let newEntry = CoreEXEntry(
        keyStart: UInt32(keyStart),
        keyEnd: UInt32(keyStart + keyBytes.count),
        lineStart: UInt32(lineRange.lowerBound),
        lineEnd: UInt32(lineRange.upperBound)
      )
      entries.insert(newEntry, at: lo)
    }

    /// `#` 之後是否以 ASCII `NGRAM`（不分大小寫）起首；是則回傳含 `#` 之前綴長度（6）。
    private func ngramPrefixLength(in cell: Range<Int>) -> Int? {
      guard cell.count >= 6 else { return nil }
      let expected: [UInt8] = Array("ngram".utf8)
      for offset in 0 ..< 5 {
        var byte = rawData[cell.lowerBound + 1 + offset]
        if byte >= 0x41, byte <= 0x5A { byte += 0x20 } // ASCII 大寫 → 小寫
        guard byte == expected[offset] else { return nil }
      }
      return 6
    }

    /// 逐格掃描一列、分類標籤區並辨識 `#NGRAM` 閘門；同時產生載入期診斷。
    private func parseLine(_ lineRange: Range<Int>) -> LineParse {
      var result = LineParse()
      var sawChainLikeCellWithoutGate = false
      var numericCellAfterTag: Int?
      rawData.parseByteCells(in: lineRange) { cell, index in
        switch index {
        case 0:
          result.firstCell = cell
        case 1:
          result.secondCell = cell
        default:
          if rawData[cell.lowerBound] == 0x23 {
            guard let prefixLength = ngramPrefixLength(in: cell) else { return true }
            result.gateCount += 1
            result.gateCell = cell
            let payloadStart = cell.lowerBound + prefixLength
            if payloadStart >= cell.upperBound {
              result.issue = "`#NGRAM` 之後缺 `:前文鏈`"
            } else if rawData[payloadStart] != 0x3A { // ':'
              result.issue = "`#NGRAM` 之後須為 `:`（未知變體）"
            }
          } else if index == 2 {
            result.scoreCell = cell
          } else if rawData[cell].contains(0x7C) { // '|'
            sawChainLikeCellWithoutGate = true
          } else if numericCellAfterTag == nil,
                    Double(String(decoding: rawData[cell], as: UTF8.self)) != nil {
            numericCellAfterTag = cell.lowerBound
          }
        }
        return true
      }
      if result.gateCount > 1 {
        result.issue = "一列出現 \(result.gateCount) 個 `#NGRAM` 閘門（取最後一個）"
      } else if result.gateCount == 0, sawChainLikeCellWithoutGate {
        result.issue = "疑似前文鏈之內容卻無 `#NGRAM` 閘門（將按單元圖讀取）"
      } else if result.issue == nil, let numericCellAfterTag {
        result.issue = "分數只能寫在第 2 格（第 \(numericCellAfterTag + 1) 位元組處另有數字）"
      }
      if result.issue == nil, let second = result.secondCell {
        if rawData[second.lowerBound] == 0x23 {
          result.issue = "讀音格以 `#` 起首（疑似把標籤寫進了讀音格）"
        } else if Double(String(decoding: rawData[second], as: UTF8.self)) != nil {
          result.issue = "讀音格是數字（疑似把分數寫進了讀音格）"
        }
      }
      return result
    }

    /// 取閘門格所載之前文鏈；nil＝不合格。
    ///
    /// 鏈由舊至新、以 `|` 分隔；末詞為 `previous`、倒數第二詞為 `anterior`。
    /// `*` 只准居兩詞鏈之末（缺口列），不得單獨成鏈、亦不得居非末位。
    private func contextChain(ofGateCell cell: Range<Int>) -> (previous: String, anterior: String?)? {
      guard let prefixLength = ngramPrefixLength(in: cell) else { return nil }
      let payloadStart = cell.lowerBound + prefixLength
      guard payloadStart < cell.upperBound, rawData[payloadStart] == 0x3A else { return nil }
      let start = payloadStart + 1
      guard start < cell.upperBound else { return nil }
      let payload = String(decoding: rawData[start ..< cell.upperBound], as: UTF8.self)
      let tokens = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
      guard !tokens.isEmpty, tokens.allSatisfy({ !$0.isEmpty }) else { return nil }
      let wildcard = Homa.Gram.wildcardContextToken
      switch tokens.count {
      case 1:
        guard tokens[0] != wildcard else { return nil }
        return (tokens[0], nil)
      case 2:
        if tokens[1] == wildcard {
          guard tokens[0] != wildcard else { return nil }
          return (wildcard, tokens[0])
        }
        guard !tokens.contains(wildcard) else { return nil }
        return (tokens[1], tokens[0])
      default:
        return nil
      }
    }

    /// 載入期診斷：僅記錄，不阻斷載入（使用者資料之解析一律「絕不整體失敗」）。
    private func diagnose(lines: [(number: Int, range: Range<Int>)]) {
      var seen: [String: Double] = [:]
      for line in lines {
        let parsed = parseLine(line.range)
        if let issue = parsed.issue {
          let raw = String(decoding: rawData[line.range], as: UTF8.self)
          vCLMLog("lxCoreEX: 第 \(line.number) 列：\(issue)。原列：\(raw)")
        }
        guard let first = parsed.firstCell, let second = parsed.secondCell else { continue }
        let valueCell = shouldReverse ? first : second
        let readingCell = shouldReverse ? second : first
        let value = String(decoding: rawData[valueCell], as: UTF8.self)
        var reading = String(decoding: rawData[readingCell], as: UTF8.self)
        reading.convertToPhonabets()
        let chain = parsed.gateCell.flatMap { contextChain(ofGateCell: $0) }
        let chainKey = chain.map { [$0.anterior ?? "", $0.previous].joined(separator: "|") } ?? ""
        let identity = "\(reading)\u{1}\(value)\u{1}\(chainKey)"
        let score = parsed.scoreCell.flatMap { Double(String(decoding: rawData[$0], as: UTF8.self)) } ?? 0
        if let existing = seen[identity], existing != score {
          vCLMLog("lxCoreEX: 第 \(line.number) 列：同一（讀音、詞值、前文鏈）重複且分數不同（先出現者生效）。")
        } else {
          seen[identity] = score
        }
      }
    }

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

extension LXAssembly.LXCoreEX {
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
