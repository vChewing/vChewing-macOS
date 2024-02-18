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
import SQLite3

/* ==============
 因應 Apple 對 8GB 運行記憶體的病態偏執，威注音的原廠辭典格式更換為 SQLite、以圖減少對記憶體的佔用。
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
  fileprivate static func querySQL(strStmt sqlQuery: String, coreColumn column: CoreColumn, handler: (String) -> Void) {
    guard Self.ptrSQL != nil else { return }
    performStatementSansResult { ptrStatement in
      sqlite3_prepare_v2(Self.ptrSQL, sqlQuery, -1, &ptrStatement, nil)
      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        guard let rawValue = sqlite3_column_text(ptrStatement, column.id) else { continue }
        handler(String(cString: rawValue))
      }
    }
  }

  fileprivate static func hasSQLResult(strStmt sqlQuery: String) -> Bool {
    guard Self.ptrSQL != nil else { return false }
    var sqlQuery = sqlQuery
    if sqlQuery.last == ";" { sqlQuery = sqlQuery.dropLast(1).description } // 防呆設計。
    guard !sqlQuery.isEmpty else { return false }
    return performStatement { ptrStatement in
      let wrappedQuery = "SELECT EXISTS(\(sqlQuery));"
      sqlite3_prepare_v2(Self.ptrSQL, wrappedQuery, -1, &ptrStatement, nil)
      while sqlite3_step(ptrStatement) == SQLITE_ROW {
        return sqlite3_column_int(ptrStatement, 0) == 1
      }
      return false
    }
  }

  /// 获取字根反查资料。
  public static func getFactoryReverseLookupData(with kanji: String) -> [String]? {
    var results: [String] = []
    let sqlQuery = "SELECT * FROM DATA_REV WHERE theChar='\(kanji)';"
    guard Self.ptrSQL != nil else { return nil }
    performStatementSansResult { ptrStatement in
      sqlite3_prepare_v2(Self.ptrSQL, sqlQuery, -1, &ptrStatement, nil)
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
        let neta = Array(strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ").reversed())
        let theValue: String = .init(neta[0])
        var theScore = column.defaultScore
        if neta.count >= 2, let thisScore = Double(String(neta[1])) {
          theScore = thisScore
        }
        if theScore > 0 {
          theScore *= -1 // 應對可能忘記寫負號的情形
        }
        grams.append(Megrez.Unigram(value: theValue, score: theScore))
      }
    }
    return grams
  }

  /// 根據給定的讀音索引鍵，來獲取原廠標準資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  func factoryCoreUnigramsFor(key: String) -> [Megrez.Unigram] {
    // 此處需要把 ASCII 單引號換成連續兩個單引號，否則會有 SQLite 語句查詢故障。
    factoryUnigramsFor(key: key, column: isCHS ? .theDataCHS : .theDataCHT)
  }

  /// 根據給定的讀音索引鍵，來獲取原廠標準資料庫辭典內的對應資料陣列的 UTF8 資料、就地分析、生成單元圖陣列。
  /// - parameters:
  ///   - key: 讀音索引鍵。
  ///   - column: 資料欄位。
  func factoryUnigramsFor(
    key: String, column: LMAssembly.LMInstantiator.CoreColumn
  ) -> [Megrez.Unigram] {
    if key == "_punctuation_list" { return [] }
    var grams: [Megrez.Unigram] = []
    var gramsHW: [Megrez.Unigram] = []
    // 此處需要把 ASCII 單引號換成連續兩個單引號，否則會有 SQLite 語句查詢故障。
    let encryptedKey = Self.cnvPhonabetToASCII(key.replacingOccurrences(of: "'", with: "''"))
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey='\(encryptedKey)';"
    Self.querySQL(strStmt: sqlQuery, coreColumn: column) { currentResult in
      let arrRangeRecords = currentResult.split(separator: "\t")
      for strNetaSet in arrRangeRecords {
        let neta = Array(strNetaSet.trimmingCharacters(in: .newlines).split(separator: " ").reversed())
        let theValue: String = .init(neta[0])
        var theScore = column.defaultScore
        if neta.count >= 2, let thisScore = Double(String(neta[1])) {
          theScore = thisScore
        }
        if theScore > 0 {
          theScore *= -1 // 應對可能忘記寫負號的情形
        }
        grams.append(Megrez.Unigram(value: theValue, score: theScore))
        if !key.contains("_punctuation") { continue }
        let halfValue = theValue.applyingTransformFW2HW(reverse: false)
        if halfValue != theValue {
          gramsHW.append(Megrez.Unigram(value: halfValue, score: theScore))
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
  private func factoryCNSFilterThreadFor(key: String) -> String? {
    let column = CoreColumn.theDataCNS
    if key == "_punctuation_list" { return nil }
    var results: [String] = []
    // 此處需要把 ASCII 單引號換成連續兩個單引號，否則會有 SQLite 語句查詢故障。
    let encryptedKey = Self.cnvPhonabetToASCII(key.replacingOccurrences(of: "'", with: "''"))
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey='\(encryptedKey)';"
    Self.querySQL(strStmt: sqlQuery, coreColumn: column) { currentResult in
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
    let encryptedKey = Self.cnvPhonabetToASCII(keyArray.joined(separator: "-").replacingOccurrences(of: "'", with: "''"))
    // 此處為特例，無須以分號結尾。回頭整句塞到「SELECT EXISTS();」當中執行。
    let sqlQuery = "SELECT * FROM DATA_MAIN WHERE theKey='\(encryptedKey)' AND \(column.name) IS NOT NULL"
    return Self.hasSQLResult(strStmt: sqlQuery)
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

private extension LMAssembly.LMInstantiator {
  /// 內部函式，用以將注音讀音索引鍵進行加密。
  ///
  /// 使用這種加密字串作為索引鍵，可以增加對 json 資料庫的存取速度。
  ///
  /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
  /// - parameters:
  ///   - incoming: 傳入的未加密注音讀音字串。
  static func cnvPhonabetToASCII(_ incoming: String) -> String {
    var strOutput = incoming
    if !strOutput.contains("_") {
      for entry in Self.dicPhonabet2ASCII {
        strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
      }
    }
    return strOutput
  }

  static let dicPhonabet2ASCII: [String: String] = [
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c", "ㄙ": "s", "ㄧ": "i",
    "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M", "ㄡ": "F", "ㄢ": "D",
    "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
  ]

  /// 內部函式，用以將被加密的注音讀音索引鍵進行解密。
  ///
  /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
  /// - parameters:
  ///   - incoming: 傳入的已加密注音讀音字串。
  static func restorePhonabetFromASCII(_ incoming: String) -> String {
    var strOutput = incoming
    if !strOutput.contains("_") {
      for entry in Self.dicPhonabet4ASCII {
        strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
      }
    }
    return strOutput
  }

  static let dicPhonabet4ASCII: [String: String] = [
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
    "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ", "i": "ㄧ",
    "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ", "F": "ㄡ", "D": "ㄢ",
    "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
  ]
}

public extension LMAssembly.LMInstantiator {
  @discardableResult static func connectToTestSQLDB() -> Bool {
    Self.connectSQLDB(dbPath: #":memory:"#) && sqlTestCoreLMData.runAsSQLExec(dbPointer: &ptrSQL)
  }
}
