// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CSQLite3
import Foundation
import Megrez

// MARK: - LMAssembly.LMInstantiator.CoreColumn

/* ==============
 因應 Apple 對 8GB 運行記憶體的病態偏執，唯音的原廠辭典格式更換為 SQLite、以圖減少對記憶體的佔用。
 資料結構如下：
   CREATE TABLE IF NOT EXISTS DATA_MAIN (
     theKey TEXT NOT NULL,
     theDataCHS TEXT,
     theDataCHT TEXT,
     theDataCNS TEXT,
     theDataMISC TEXT,
     theDataSYMB TEXT,
     theDataCHEW TEXT,
     PRIMARY KEY (theKey)
   ) WITHOUT ROWID;
   CREATE TABLE IF NOT EXISTS DATA_REV (
     theChar TEXT NOT NULL,
     theReadings TEXT NOT NULL,
     PRIMARY KEY (theChar)
   ) WITHOUT ROWID;
 */

extension LMAssembly.LMInstantiator {
  enum CoreColumn: Int32 {
    case theDataCHS = 1 // 簡體中文
    case theDataCHT = 2 // 繁體中文
    case theDataCNS = 3 // 全字庫
    case theDataMISC = 4 // 待辦
    case theDataSYMB = 5 // 符號圖
    case theDataCHEW = 6 // 注音文

    // MARK: Internal

    var name: String { String(describing: self) }

    var id: Int32 { rawValue }

    var defaultScore: Double {
      switch self {
      case .theDataCHEW: return -1
      case .theDataCNS: return -11
      case .theDataSYMB: return -13
      case .theDataMISC: return -10
      default: return -9.9
      }
    }
  }
}

extension LMAssembly.LMInstantiator {
  @discardableResult
  public static func connectSQLDB(
    dbPath: String,
    dropPreviousConnection: Bool = true
  )
    -> Bool {
    if dropPreviousConnection { disconnectSQLDB() }
    vCLMLog("Establishing SQLite connection to: \(dbPath)")
    guard sqlite3_open(dbPath, &Self.ptrSQL) == SQLITE_OK else { return false }
    guard "PRAGMA journal_mode = OFF;".runAsSQLExec(dbPointer: &ptrSQL) else { return false }
    isSQLDBConnected = true
    return true
  }

  public static func disconnectSQLDB() {
    if Self.ptrSQL != nil {
      sqlite3_close_v2(Self.ptrSQL)
      Self.ptrSQL = nil
    }
    isSQLDBConnected = false
  }

  fileprivate static func querySQL(
    strStmt sqlQuery: String,
    params: [String] = [],
    coreColumn column: CoreColumn,
    handler: (String) -> ()
  ) {
    guard Self.ptrSQL != nil else { return }
    performStatementSansResult { ptrStatement in
      let preparation = sqlite3_prepare_v2(Self.ptrSQL, sqlQuery, -1, &ptrStatement, nil)
      guard preparation == SQLITE_OK else {
        vCLMLog("SQL prepare failed for query: \(sqlQuery)")
        return
      }
      // 綁定參數（如果有的話）
      for (i, param) in params.enumerated() {
        let idx = Int32(i + 1)
        let utf8 = (param as NSString).utf8String
        _ = sqlite3_bind_text(ptrStatement, idx, utf8, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      }
      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        guard let rawValue = sqlite3_column_text(ptrStatement, column.id) else { continue }
        handler(String(cString: rawValue))
      }
    }
  }

  internal static func hasSQLResult(strStmt sqlQuery: String, params: [String] = []) -> Bool {
    guard Self.ptrSQL != nil else { return false }
    var sqlQuery = sqlQuery
    if sqlQuery.last == ";" { sqlQuery = sqlQuery.dropLast(1).description } // 防呆設計。
    guard !sqlQuery.isEmpty else { return false }
    // 若提供了參數，確保 sqlQuery 使用匹配的佔位符號（?）對應每個參數。
    if !params.isEmpty {
      let placeholderCount = sqlQuery.filter { $0 == "?" }.count
      if placeholderCount != params.count {
        vCLMLog(
          "SQL param placeholder count mismatch: query=\(sqlQuery) expected=\(params.count) found=\(placeholderCount)"
        )
        return false
      }
    }

    return performStatement { ptrStatement in
      let wrappedQuery = "SELECT EXISTS(\(sqlQuery));"
      let prep = sqlite3_prepare_v2(Self.ptrSQL, wrappedQuery, -1, &ptrStatement, nil)
      if prep != SQLITE_OK {
        if let err = sqlite3_errmsg(Self.ptrSQL) { vCLMLog("sqlite3_prepare_v2 failed: \(String(cString: err))") }
        return false
      }
      for (i, param) in params.enumerated() {
        let idx = Int32(i + 1)
        let cParam = (param as NSString).utf8String
        _ = sqlite3_bind_text(ptrStatement, idx, cParam, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      }
      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        return sqlite3_column_int(ptrStatement, 0) == 1
      }
      return false
    }
  }

  /// 获取字根反查资料。
  public static func getFactoryReverseLookupData(with kanji: String) -> [String]? {
    var results: [String] = []
    // 使用 prepared statement 並綁定參數以避免 SQL injection
    let sqlQuery = "SELECT * FROM DATA_REV WHERE theChar = ?;"
    guard Self.ptrSQL != nil else { return nil }
    performStatementSansResult { ptrStatement in
      if sqlite3_prepare_v2(Self.ptrSQL, sqlQuery, -1, &ptrStatement, nil) == SQLITE_OK {
        // 綁定 kanji 參數
        let cKanji = (kanji as NSString).utf8String
        _ = sqlite3_bind_text(ptrStatement, 1, cKanji, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      } else {
        vCLMLog("SQL prepare failed for query: \(sqlQuery)")
      }
      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        guard let rawValue = sqlite3_column_text(ptrStatement, 1) else { continue }
        results.append(
          contentsOf: String(cString: rawValue).split(separator: "\t").map { reading in
            Self.restorePhonabetFromASCII(reading.description)
          }
        )
      }
    }
    return results.isEmpty ? nil : results
  }

  func getHaninSymbolMenuUnigrams() -> [Megrez.Unigram] {
    let column: CoreColumn = isCHS ? .theDataCHS : .theDataCHT
    var grams: [Megrez.Unigram] = []
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey='_punctuation_list';"
    Self.querySQL(strStmt: sqlQuery, coreColumn: column) { currentResult in
      let arrRangeRecords = currentResult.split(separator: "\t")
      for strNetaSet in arrRangeRecords {
        let neta = Array(
          strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ")
            .reversed()
        )
        let theValue: String = .init(neta[0])
        var theScore = column.defaultScore
        if neta.count >= 2, let thisScore = Double(String(neta[1])) {
          theScore = thisScore
        }
        if theScore > 0 {
          theScore *= -1 // 應對可能忘記寫負號的情形
        }
        grams.append(Megrez.Unigram(keyArray: ["_punctuation_list"], value: theValue, score: theScore))
      }
    }
    return grams
  }

  /// 根據給定的讀音索引鍵，來獲取原廠標準資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
  /// - Remark: 該函式會無損地返回原廠辭典的結果，不受使用者控頻與資料過濾條件的影響，不包含全字庫的資料。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  ///   - keyArray: 讀音索引陣列。
  ///   - onlyFindSupersets: 僅找出超集。預設為 false 表示不找出超集。
  public func factoryCoreUnigramsFor(
    key: String,
    keyArray: [String],
    onlyFindSupersets: Bool = false
  )
    -> [Megrez.Unigram] {
    // 此處無須逸出 ASCII 單引號，因為我們使用了 prepared statement 參數綁定。
    if onlyFindSupersets {
      return factorySupersetUnigramsFor(
        subsetKey: key,
        subsetKeyArray: keyArray,
        column: isCHS ? .theDataCHS : .theDataCHT
      )
    } else {
      return factoryUnigramsFor(
        key: key,
        keyArray: keyArray,
        column: isCHS ? .theDataCHS : .theDataCHT
      )
    }
  }

  /// 根據給定的讀音索引鍵，來獲取原廠標準資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  ///   - column: 資料欄位。
  func factoryUnigramsFor(
    key: String,
    keyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Megrez.Unigram] {
    if key == "_punctuation_list" { return [] }
    var grams: [Megrez.Unigram] = []
    var gramsHW: [Megrez.Unigram] = []
    // 此處無須逸出 ASCII 單引號，因為我們使用了 prepared statement 參數綁定。
    let encryptedKey = Self.cnvPhonabetToASCII(key)
    // 使用 prepared statement 並綁定參數以避免 SQL injection
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey = ?;"
    Self.querySQL(strStmt: sqlQuery, params: [encryptedKey], coreColumn: column) { currentResult in
      var i: Double = 0
      var previousScore: Double?
      currentResult.split(separator: "\t").forEach { strNetaSet in
        // 這裡假定原廠資料已經經過對權重的 stable sort 排序。
        let neta = Array(
          strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ")
            .reversed()
        )
        let theValue: String = .init(neta[0])
        var theScore = column.defaultScore
        if neta.count >= 2, let thisScore = Double(String(neta[1])) {
          theScore = thisScore
        }
        if theScore > 0 {
          theScore *= -1 // 應對可能忘記寫負號的情形
        }
        if previousScore == theScore {
          theScore -= i * 0.000001
          i += 1
        } else {
          previousScore = theScore
          i = 0
        }
        grams.append(Megrez.Unigram(keyArray: keyArray, value: theValue, score: theScore))
        if !key.contains("_punctuation") { return }
        let halfValue = theValue.applyingTransformFW2HW(reverse: false)
        if halfValue != theValue {
          gramsHW.append(Megrez.Unigram(keyArray: keyArray, value: halfValue, score: theScore))
        }
      }
    }
    grams.append(contentsOf: gramsHW)
    return grams
  }

  /// 根據給定的讀音索引鍵（子集合），回傳所有包含該子集合作為連續段落的 Superset 單元圖陣列。
  /// - parameters:
  ///   - subsetKey: 子集合索引鍵（例如 "A-B-C"）。
  ///   - subsetKeyArray: 子集合索引鍵的陣列形式（例如 ["A","B","C"]）。
  ///   - column: 資料欄位。
  func factorySupersetUnigramsFor(
    subsetKey: String,
    subsetKeyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Megrez.Unigram] {
    if subsetKey == "_punctuation_list" { return [] }
    var grams: [Megrez.Unigram] = []
    var gramsHW: [Megrez.Unigram] = []

    let encryptedKey = Self.cnvPhonabetToASCII(subsetKey)
    // 使用 LIKE 搜尋包含該子集合的 superset key，並排除完全相等的 key
    let sqlQuery =
      "SELECT theKey, \(column.name) FROM DATA_MAIN WHERE (theKey LIKE ? OR theKey LIKE ? OR theKey LIKE ?) AND theKey != ?;"
    performStatementSansResult { ptrStatement in
      if sqlite3_prepare_v2(Self.ptrSQL, sqlQuery, -1, &ptrStatement, nil) == SQLITE_OK {
        let p1 = encryptedKey + "-%"
        let p2 = "%-" + encryptedKey
        let p3 = "%-" + encryptedKey + "-%"
        let params = [p1, p2, p3, encryptedKey]
        for (i, param) in params.enumerated() {
          let idx = Int32(i + 1)
          let cParam = (param as NSString).utf8String
          _ = sqlite3_bind_text(ptrStatement, idx, cParam, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
      } else {
        vCLMLog("SQL prepare failed for query: \(sqlQuery)")
      }

      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        guard let rawKey = sqlite3_column_text(ptrStatement, 0) else { continue }
        guard let rawValue = sqlite3_column_text(ptrStatement, 1) else { continue }
        let supEncrypted = String(cString: rawKey)
        let currentResult = String(cString: rawValue)
        let supKeyPhonabet = Self.restorePhonabetFromASCII(supEncrypted)
        let supKeyArray = supKeyPhonabet.split(separator: "-").map { String($0) }

        var i: Double = 0
        var previousScore: Double?
        currentResult.split(separator: "\t").forEach { strNetaSet in
          let neta = Array(
            strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ")
              .reversed()
          )
          let theValue: String = .init(neta[0])
          var theScore = column.defaultScore
          if neta.count >= 2, let thisScore = Double(String(neta[1])) {
            theScore = thisScore
          }
          if theScore > 0 {
            theScore *= -1
          }
          if previousScore == theScore {
            theScore -= i * 0.000001
            i += 1
          } else {
            previousScore = theScore
            i = 0
          }
          grams.append(Megrez.Unigram(keyArray: supKeyArray, value: theValue, score: theScore))
          if !supEncrypted.contains("_punctuation") { return }
          let halfValue = theValue.applyingTransformFW2HW(reverse: false)
          if halfValue != theValue {
            gramsHW.append(Megrez.Unigram(keyArray: supKeyArray, value: halfValue, score: theScore))
          }
        }
      }
    }
    grams.append(contentsOf: gramsHW)
    return grams
  }

  /// 根據給定的讀音索引鍵，來獲取原廠 CNS 資料庫辭典內的對應資料陣列的 UTF8 資料。
  /// 該函式僅用來快速篩查 CNS 檢索結果
  /// - parameters:
  ///   - key: 讀音索引鍵。
  ///   - column: 資料欄位。
  internal func factoryCNSFilterThreadFor(key: String) -> String? {
    let column = CoreColumn.theDataCNS
    if key == "_punctuation_list" { return nil }
    var results: [String] = []
    // 此處無須逸出 ASCII 單引號，因為我們使用了 prepared statement 參數綁定。
    let encryptedKey = Self.cnvPhonabetToASCII(key)
    // 使用 prepared statement 並綁定參數以避免 SQL injection
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey = ?;"
    Self.querySQL(strStmt: sqlQuery, params: [encryptedKey], coreColumn: column) { currentResult in
      results.append(currentResult)
    }
    return results.joined(separator: "\t")
  }

  /// 根據給定的讀音索引鍵，來獲取原廠資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
  /// - remark: 該函式暫時用不到，但先不用刪除。沒準今後會有用場。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func hasFactoryCoreUnigramsFor(keyArray: [String]) -> Bool {
    let column: CoreColumn = isCHS ? .theDataCHS : .theDataCHT
    // 此處需要把 ASCII 單引號換成連續兩個單引號，否則會有 SQLite 語句查詢故障。
    let encryptedKey = Self
      .cnvPhonabetToASCII(keyArray.joined(separator: "-"))
    // 此處為特例，無須以分號結尾。回頭整句塞到「SELECT EXISTS();」當中執行。
    // column.name 來自 enum，為安全的欄位識別符。encryptedKey 攜帶使用者輸入，需綁定。
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey = ? AND \(column.name) IS NOT NULL"
    return Self.hasSQLResult(strStmt: sqlQuery, params: [encryptedKey])
  }

  /// 檢查該當 Unigram 結果是否完全符合台澎金馬 CNS11643 的規定讀音。
  /// 該函式不適合拿給簡體中文模式使用。
  func checkCNSConformation(for unigram: Megrez.Unigram, keyArray: [String]) -> Bool {
    guard unigram.value.count == keyArray.count else { return true }
    let chars = unigram.value.map(\.description)
    for (i, key) in keyArray.enumerated() {
      guard !key.hasPrefix("_") else { continue }
      guard let matchedCNSResult = factoryCNSFilterThreadFor(key: key) else { continue }
      guard matchedCNSResult.contains(chars[i]) else { return false }
    }
    return true
  }
}

extension LMAssembly.LMInstantiator {
  /// 內部函式，用以將注音讀音索引鍵進行加密。
  ///
  /// 使用這種加密字串作為索引鍵，可以增加對 json 資料庫的存取速度。
  ///
  /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
  /// - parameters:
  ///   - incoming: 傳入的未加密注音讀音字串。
  fileprivate static func cnvPhonabetToASCII(_ incoming: String) -> String {
    var strOutput = incoming
    if !strOutput.contains("_") {
      for entry in Self.dicPhonabet2ASCII {
        strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
      }
    }
    return strOutput
  }

  fileprivate static let dicPhonabet2ASCII: [String: String] = [
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g",
    "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c",
    "ㄙ": "s", "ㄧ": "i",
    "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M",
    "ㄡ": "F", "ㄢ": "D",
    "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
  ]

  /// 內部函式，用以將被加密的注音讀音索引鍵進行解密。
  ///
  /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
  /// - parameters:
  ///   - incoming: 傳入的已加密注音讀音字串。
  fileprivate static func restorePhonabetFromASCII(_ incoming: String) -> String {
    var strOutput = incoming
    if !strOutput.contains("_") {
      for entry in Self.dicPhonabet4ASCII {
        strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
      }
    }
    return strOutput
  }

  fileprivate static let dicPhonabet4ASCII: [String: String] = [
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ",
    "k": "ㄎ", "h": "ㄏ",
    "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ",
    "s": "ㄙ", "i": "ㄧ",
    "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ",
    "F": "ㄡ", "D": "ㄢ",
    "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
  ]
}

extension LMAssembly.LMInstantiator {
  @discardableResult
  public static func connectToTestSQLDB(_ str: String) -> Bool {
    guard !str.isEmpty else { return false }
    return Self.connectSQLDB(dbPath: #":memory:"#) && str.runAsSQLExec(dbPointer: &ptrSQL)
  }
}
