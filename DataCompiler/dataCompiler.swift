#!/usr/bin/env swift

// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SQLite3

// MARK: - 前導工作

fileprivate extension String {
  mutating func regReplace(pattern: String, replaceWith: String = "") {
    // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
    do {
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }
}

// MARK: - Safe APIs for using SQLite Statements.

func performStatement(_ handler: (inout OpaquePointer?) -> Bool) -> Bool {
  var ptrStmt: OpaquePointer?
  defer {
    sqlite3_finalize(ptrStmt)
    ptrStmt = nil
  }
  return handler(&ptrStmt)
}

func performStatementSansResult(_ handler: (inout OpaquePointer?) -> Void) {
  var ptrStmt: OpaquePointer?
  defer {
    sqlite3_finalize(ptrStmt)
    ptrStmt = nil
  }
  handler(&ptrStmt)
}

// MARK: - String as SQL Command

fileprivate extension String {
  @discardableResult func runAsSQLExec(dbPointer ptrDB: inout OpaquePointer?) -> Bool {
    ptrDB != nil && sqlite3_exec(ptrDB, self, nil, nil, nil) == SQLITE_OK
  }

  @discardableResult func runAsSQLPreparedStep(dbPointer ptrDB: inout OpaquePointer?) -> Bool {
    guard ptrDB != nil else { return false }
    return performStatement { ptrStmt in
      sqlite3_prepare_v2(ptrDB, self, -1, &ptrStmt, nil) == SQLITE_OK && sqlite3_step(ptrStmt) == SQLITE_DONE
    }
  }
}

// MARK: - StringView Ranges Extension (by Isaac Xen)

fileprivate extension String {
  func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex ..< endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}

// MARK: - 引入小數點位數控制函式

// Ref: https://stackoverflow.com/a/32581409/4162914
fileprivate extension Double {
  func rounded(toPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return (self * divisor).rounded() / divisor
  }
}

// MARK: - 引入冪乘函式

// Ref: https://stackoverflow.com/a/41581695/4162914
precedencegroup ExponentiationPrecedence {
  associativity: right
  higherThan: MultiplicationPrecedence
}

infix operator **: ExponentiationPrecedence

func ** (_ base: Double, _ exp: Double) -> Double {
  pow(base, exp)
}

// MARK: - 定義檔案結構

struct Unigram: CustomStringConvertible {
  enum UnigramCategory: String {
    case macv = "MACV"
    case tabe = "TABE"
    case moe = "MOED"
    case custom = "CUST"
    case misc = "MISC"
    var description: String { rawValue }
  }

  init(key: String, value: String, score: Double, count: Int, category: Unigram.UnigramCategory) {
    self.key = key
    self.value = value
    self.score = score
    self.count = count
    self.category = category
  }

  var key: String = ""
  var value: String = ""
  var score: Double = -1.0
  var count: Int = 0
  var category: UnigramCategory
  var description: String {
    "(\(key), \(value), \(score), \(category)"
  }
}

// MARK: - 注音加密，減少 JSON 體積

func cnvPhonabetToASCII(_ incoming: String) -> String {
  let dicPhonabet2ASCII = [
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c", "ㄙ": "s", "ㄧ": "i",
    "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M", "ㄡ": "F", "ㄢ": "D",
    "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
  ]
  var strOutput = incoming
  if !strOutput.contains("_") {
    for Unigram in dicPhonabet2ASCII {
      strOutput = strOutput.replacingOccurrences(of: Unigram.key, with: Unigram.value)
    }
  }
  return strOutput
}

// MARK: - 登記全局根常數變數

private let urlCurrentFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private let urlCHSRoot: String = "\(urlCurrentFolder.path)/components/chs/"
private let urlCHTRoot: String = "\(urlCurrentFolder.path)/components/cht/"

private let urlKanjiCore: String = "\(urlCurrentFolder.path)/components/common/char-kanji-core.txt"
private let urlMiscBPMF: String = "\(urlCurrentFolder.path)/components/common/char-misc-bpmf.txt"
private let urlMiscNonKanji: String = "\(urlCurrentFolder.path)/components/common/char-misc-nonkanji.txt"

private let urlPunctuation: String = "\(urlCurrentFolder.path)/components/common/data-punctuations.txt"
private let urlSymbols: String = "\(urlCurrentFolder.path)/components/common/data-symbols.txt"
private let urlZhuyinwen: String = "\(urlCurrentFolder.path)/components/common/data-zhuyinwen.txt"
private let urlCNS: String = "\(urlCurrentFolder.path)/components/common/char-kanji-cns.txt"

private let urlOutputCHS: String = "\(urlCurrentFolder.path)/data-chs.txt"
private let urlOutputCHT: String = "\(urlCurrentFolder.path)/data-cht.txt"

private let urlJSONSymbols: String = "\(urlCurrentFolder.path)/data-symbols.json"
private let urlJSONZhuyinwen: String = "\(urlCurrentFolder.path)/data-zhuyinwen.json"
private let urlJSONCNS: String = "\(urlCurrentFolder.path)/data-cns.json"

private let urlJSONCHS: String = "\(urlCurrentFolder.path)/data-chs.json"
private let urlJSONCHT: String = "\(urlCurrentFolder.path)/data-cht.json"
private let urlJSONBPMFReverseLookup: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup.json"
private let urlJSONBPMFReverseLookupCNS1: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS1.json"
private let urlJSONBPMFReverseLookupCNS2: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS2.json"
private let urlJSONBPMFReverseLookupCNS3: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS3.json"
private let urlJSONBPMFReverseLookupCNS4: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS4.json"
private let urlJSONBPMFReverseLookupCNS5: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS5.json"
private let urlJSONBPMFReverseLookupCNS6: String = "\(urlCurrentFolder.path)/data-bpmf-reverse-lookup-CNS6.json"

private var isReverseLookupDictionaryProcessed: Bool = false

private let urlSQLite: String = "\(urlCurrentFolder.path)/Build/Release/vChewingFactoryDatabase.sqlite"

private var mapReverseLookupForCheck: [String: [String]] = [:]
private var exceptedChars: Set<String> = .init()

private var ptrSQL: OpaquePointer?

var rangeMapJSONCHS: [String: [String]] = [:]
var rangeMapJSONCHT: [String: [String]] = [:]
var rangeMapSymbols: [String: [String]] = [:]
var rangeMapZhuyinwen: [String: [String]] = [:]
var rangeMapCNS: [String: [String]] = [:]
var rangeMapReverseLookup: [String: [String]] = [:]
/// Also use mapReverseLookupForCheck.

// MARK: - 準備資料庫

func prepareDatabase() -> Bool {
  let sqlMakeTableMACV = """
  DROP TABLE IF EXISTS DATA_REV;
  DROP TABLE IF EXISTS DATA_MAIN;
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
  """
  guard sqlite3_open(urlSQLite, &ptrSQL) == SQLITE_OK else { return false }
  guard sqlite3_exec(ptrSQL, "PRAGMA synchronous = OFF;", nil, nil, nil) == SQLITE_OK else { return false }
  guard sqlite3_exec(ptrSQL, "PRAGMA journal_mode = MEMORY;", nil, nil, nil) == SQLITE_OK else { return false }
  guard sqlMakeTableMACV.runAsSQLExec(dbPointer: &ptrSQL) else { return false }
  guard "begin;".runAsSQLExec(dbPointer: &ptrSQL) else { return false }

  return true
}

@discardableResult func writeMainMapToSQL(_ theMap: [String: [String]], column columnName: String) -> Bool {
  for (encryptedKey, arrValues) in theMap {
    // SQL 語言需要對西文 ASCII 半形單引號做回退處理、變成「''」。
    let safeKey = encryptedKey.replacingOccurrences(of: "'", with: "''")
    let valueText = arrValues.joined(separator: "\t").replacingOccurrences(of: "'", with: "''")
    let sqlStmt = "INSERT INTO DATA_MAIN (theKey, \(columnName)) VALUES ('\(safeKey)', '\(valueText)') ON CONFLICT(theKey) DO UPDATE SET \(columnName)='\(valueText)';"
    guard sqlStmt.runAsSQLPreparedStep(dbPointer: &ptrSQL) else {
      print("Failed: " + sqlStmt)
      return false
    }
  }
  return true
}

@discardableResult func writeRevLookupMapToSQL(_ theMap: [String: [String]]) -> Bool {
  for (encryptedKey, arrValues) in theMap {
    // SQL 語言需要對西文 ASCII 半形單引號做回退處理、變成「''」。
    let safeKey = encryptedKey.replacingOccurrences(of: "'", with: "''")
    let valueText = arrValues.joined(separator: "\t").replacingOccurrences(of: "'", with: "''")
    let sqlStmt = "INSERT INTO DATA_REV (theChar, theReadings) VALUES ('\(safeKey)', '\(valueText)') ON CONFLICT(theChar) DO UPDATE SET theReadings='\(valueText)';"
    guard sqlStmt.runAsSQLPreparedStep(dbPointer: &ptrSQL) else {
      print("Failed: " + sqlStmt)
      return false
    }
  }
  return true
}

// MARK: - 載入詞組檔案且輸出陣列

func rawDictForPhrases(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAWOrigDict: [String: String] = [:]
  let urlFolderRoot: String = isCHS ? urlCHSRoot : urlCHTRoot
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    try FileManager.default.contentsOfDirectory(atPath: urlFolderRoot).forEach { thePath in
      guard thePath.contains("phrases-") else { return }
      let str = try String(contentsOfFile: urlFolderRoot + thePath, encoding: .utf8)
      strRAWOrigDict[thePath] = str
    }
  } catch {
    NSLog(" - Exception happened when reading raw phrases data.")
    return []
  }
  for key in strRAWOrigDict.keys {
    guard var strRAW = strRAWOrigDict[key] else { continue }
    // 預處理格式
    strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
    // CJKWhiteSpace (\x{3000}) to ASCII Space
    // NonBreakWhiteSpace (\x{A0}) to ASCII Space
    // Tab to ASCII Space
    // 統整連續空格為一個 ASCII 空格
    strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
    strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "") // 去除行尾行首空格
    strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n") // CR & Form Feed to LF, 且去除重複行
    strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "") // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
    strRAWOrigDict[key] = strRAW

    let currentCategory: Unigram.UnigramCategory = {
      if key.contains("-custom-") { return .custom }
      if key.contains("-tabe-") { return .tabe }
      if key.contains("-moe-") { return .moe }
      if key.contains("-vchewing-") { return .macv }
      return .custom
    }()
    var lineData = ""
    for lineNeta in strRAW.split(separator: "\n") {
      lineData = lineNeta.description
      // 第三欄開始是注音
      let arrLineData = lineData.components(separatedBy: " ")
      var varLineDataProcessed = ""
      var count = 0
      for currentCell in arrLineData {
        count += 1
        if count < 3 {
          varLineDataProcessed += currentCell + "\t"
        } else if count < arrLineData.count {
          varLineDataProcessed += currentCell + "-"
        } else {
          varLineDataProcessed += currentCell
        }
      }
      // 然後直接乾脆就轉成 Unigram 吧。
      let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
      count = 0 // 不需要再定義，因為之前已經有定義過了。
      var phone = ""
      var phrase = ""
      var occurrence = 0
      for cell in arrCells {
        count += 1
        switch count {
        case 1: phrase = cell
        case 3: phone = cell
        case 2: occurrence = Int(cell) ?? 0
        default: break
        }
      }
      if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
        arrUnigramRAW += [
          Unigram(
            key: phone, value: phrase, score: 0.0,
            count: occurrence, category: currentCategory
          ),
        ]
      }
    }
  }

  NSLog(" - \(i18n): 成功生成詞語語料辭典（權重待計算）。")
  return arrUnigramRAW
}

// MARK: - 載入單字檔案且輸出陣列

func rawDictForKanjis(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAW = ""
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    strRAW += try String(contentsOfFile: urlKanjiCore, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw core kanji data.")
    return []
  }
  // 預處理格式
  strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
  // CJKWhiteSpace (\x{3000}) to ASCII Space
  // NonBreakWhiteSpace (\x{A0}) to ASCII Space
  // Tab to ASCII Space
  // 統整連續空格為一個 ASCII 空格
  strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
  strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "") // 去除行尾行首空格
  strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n") // CR & Form Feed to LF, 且去除重複行
  strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "") // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
  // 正式整理格式，現在就開始去重複：
  let arrData = Array(
    NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
  var varLineData = ""
  var mapReverseLookupJSON: [String: [String]] = [:]
  var mapReverseLookupUnencrypted: [String: [String]] = [:]
  for lineData in arrData {
    // 簡體中文的話，提取 1,2,4；繁體中文的話，提取 1,3,4。
    let varLineDataPre = lineData.components(separatedBy: " ").prefix(isCHS ? 2 : 1)
      .joined(
        separator: "\t")
    let varLineDataPost = lineData.components(separatedBy: " ").suffix(isCHS ? 1 : 2)
      .joined(
        separator: "\t")
    varLineData = varLineDataPre + "\t" + varLineDataPost
    let arrLineData = varLineData.components(separatedBy: " ")
    var varLineDataProcessed = ""
    var count = 0
    for currentCell in arrLineData {
      count += 1
      if count < 3 {
        varLineDataProcessed += currentCell + "\t"
      } else if count < arrLineData.count {
        varLineDataProcessed += currentCell + "-"
      } else {
        varLineDataProcessed += currentCell
      }
    }
    // 然後直接乾脆就轉成 Unigram 吧。
    let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
    count = 0 // 不需要再定義，因為之前已經有定義過了。
    var phone = ""
    var phrase = ""
    var occurrence = 0
    for cell in arrCells {
      count += 1
      switch count {
      case 1: phrase = cell
      case 3: phone = cell
      case 2: occurrence = Int(cell) ?? 0
      default: break
      }
    }
    if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
      if !isReverseLookupDictionaryProcessed {
        mapReverseLookupUnencrypted[phrase, default: []].append(phone)
        mapReverseLookupJSON[phrase, default: []].append(cnvPhonabetToASCII(phone))
      }
      arrUnigramRAW += [
        Unigram(
          key: phone, value: phrase, score: 0.0,
          count: occurrence, category: .misc
        ),
      ]
    }
  }
  if !isReverseLookupDictionaryProcessed {
    do {
      isReverseLookupDictionaryProcessed = true
      if compileJSON {
        try JSONSerialization.data(withJSONObject: mapReverseLookupJSON, options: .sortedKeys).write(
          to: URL(fileURLWithPath: urlJSONBPMFReverseLookup))
      }
      mapReverseLookupForCheck = mapReverseLookupUnencrypted
    } catch {
      NSLog(" - Core Reverse Lookup Data Generation Failed.")
    }
  }
  NSLog(" - \(i18n): 成功生成單字語料辭典（權重待計算）。")
  return arrUnigramRAW
}

// MARK: - 載入非漢字檔案且輸出陣列

func rawDictForNonKanjis(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAW = ""
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    strRAW += try String(contentsOfFile: urlMiscBPMF, encoding: .utf8)
    strRAW += "\n"
    strRAW += try String(contentsOfFile: urlMiscNonKanji, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw core kanji data.")
    return []
  }
  // 預處理格式
  strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
  // CJKWhiteSpace (\x{3000}) to ASCII Space
  // NonBreakWhiteSpace (\x{A0}) to ASCII Space
  // Tab to ASCII Space
  // 統整連續空格為一個 ASCII 空格
  strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
  strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "") // 去除行尾行首空格
  strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n") // CR & Form Feed to LF, 且去除重複行
  strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "") // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
  // 正式整理格式，現在就開始去重複：
  let arrData = Array(
    NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
  var varLineData = ""
  for lineData in arrData {
    varLineData = lineData
    // 先完成某兩步需要分行處理才能完成的格式整理。
    varLineData = varLineData.components(separatedBy: " ").prefix(3).joined(
      separator: "\t") // 提取前三欄的內容。
    let arrLineData = varLineData.components(separatedBy: " ")
    var varLineDataProcessed = ""
    var count = 0
    for currentCell in arrLineData {
      count += 1
      if count < 3 {
        varLineDataProcessed += currentCell + "\t"
      } else if count < arrLineData.count {
        varLineDataProcessed += currentCell + "-"
      } else {
        varLineDataProcessed += currentCell
      }
    }
    // 然後直接乾脆就轉成 Unigram 吧。
    let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
    count = 0 // 不需要再定義，因為之前已經有定義過了。
    var phone = ""
    var phrase = ""
    var occurrence = 0
    for cell in arrCells {
      count += 1
      switch count {
      case 1: phrase = cell
      case 3: phone = cell
      case 2: occurrence = Int(cell) ?? 0
      default: break
      }
    }
    if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
      exceptedChars.insert(phrase)
      arrUnigramRAW += [
        Unigram(
          key: phone, value: phrase, score: 0.0,
          count: occurrence, category: .misc
        ),
      ]
    }
  }
  NSLog(" - \(i18n): 成功生成非漢字語料辭典（權重待計算）。")
  return arrUnigramRAW
}

func weightAndSort(_ arrStructUncalculated: [Unigram], isCHS: Bool) -> [Unigram] {
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  var arrStructCalculated: [Unigram] = []
  let fscale = 2.7
  var norm = 0.0
  for unigram in arrStructUncalculated {
    if (1 ... 6).contains(unigram.value.count), unigram.category != .custom {
      norm += fscale ** (Double(unigram.value.count) / 3.0 - 1.0)
        * Double(unigram.count)
    }
  }
  NSLog(" - \(i18n): NORM 計算值為 \(norm)。")
  // norm 計算完畢，開始將 norm 作為新的固定常數來為每個詞條記錄計算權重。
  // 將新酷音的詞語出現次數數據轉換成小麥引擎可讀的數據形式。
  // 對出現次數小於 1 的詞條，將 0 當成 0.5 來處理、以防止除零。
  for unigram in arrStructUncalculated {
    var weight: Double = 0
    switch unigram.count {
    case -2: // 拗音假名
      weight = -13
    case -1: // 單個假名
      weight = -13
    case 0: // 墊底低頻漢字與詞語
      weight = log10(
        fscale ** (Double(unigram.value.count) / 3.0 - 1.0) * 0.25 / norm)
    default:
      weight = log10(
        fscale ** (Double(unigram.value.count) / 3.0 - 1.0)
          * Double(unigram.count) / norm) // Credit: MJHsieh.
    }
    let weightRounded: Double = weight.rounded(toPlaces: 3) // 為了節省生成的檔案體積，僅保留小數點後三位。
    arrStructCalculated += [
      Unigram(
        key: unigram.key, value: unigram.value, score: weightRounded,
        count: unigram.count, category: unigram.category
      ),
    ]
  }
  NSLog(" - \(i18n): 成功計算權重。")
  // ==========================================
  // 接下來是排序，先按照注音遞減排序一遍、再按照權重遞減排序一遍。
  var arrStructSorted: [Unigram] = arrStructCalculated.sorted(by: { lhs, rhs -> Bool in
    (lhs.key, rhs.count) < (rhs.key, lhs.count)
  })
  NSLog(" - \(i18n): 排序整理完畢，準備編譯要寫入的檔案內容。")
  arrStructSorted.append(Unigram(key: "__NORM__", value: norm.description, score: 0, count: 0, category: .misc))
  return arrStructSorted
}

func fileOutput(isCHS: Bool) {
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  var strPunctuation = ""
  var rangeMapJSON: [String: [String]] = [:]
  let pathOutput = URL(fileURLWithPath: isCHS ? urlOutputCHS : urlOutputCHT)
  let jsonURL = URL(fileURLWithPath: isCHS ? urlJSONCHS : urlJSONCHT)
  var strPrintLine = ""
  // 讀取標點內容
  do {
    strPunctuation = try String(contentsOfFile: urlPunctuation, encoding: .utf8).replacingOccurrences(
      of: "\t", with: " "
    )
    if let charLast = strPunctuation.last, !"\n".contains(charLast) {
      strPunctuation += "\n"
    }
    strPrintLine += try String(contentsOfFile: urlPunctuation, encoding: .utf8).replacingOccurrences(
      of: "\t", with: " "
    )
    if let charLast = strPunctuation.last, !"\n".contains(charLast) {
      strPunctuation += "\n"
    }
  } catch {
    NSLog(" - \(i18n): Exception happened when reading raw punctuation data.")
  }
  NSLog(" - \(i18n): 成功插入標點符號與西文字母數據（txt）。")
  // 統合辭典內容
  strPunctuation.ranges(splitBy: "\n").forEach {
    let neta = strPunctuation[$0].split(separator: " ")
    let line = String(strPunctuation[$0])
    if neta.count >= 2 {
      let theKey = String(neta[0])
      let theValue = String(neta[1])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        rangeMapJSON[cnvPhonabetToASCII(theKey), default: []].append(theValue)
      }
    }
  }

  var arrStructUnified: [Unigram] = []
  arrStructUnified += rawDictForKanjis(isCHS: isCHS)
  arrStructUnified += rawDictForNonKanjis(isCHS: isCHS)
  arrStructUnified += rawDictForPhrases(isCHS: isCHS)
  // 計算權重且排序
  arrStructUnified = weightAndSort(arrStructUnified, isCHS: isCHS)

  // 資料重複性檢查
  NSLog(" - \(i18n): 執行資料重複性檢查，會在之後再給出對應的檢查結果。")
  var setAlreadyInserted = Set<String>()
  var arrFoundedDuplications = [String]()

  // 健康狀況檢查
  NSLog(" - \(i18n): 執行資料健康狀況檢查。")
  print(healthCheck(arrStructUnified))
  for unigram in arrStructUnified {
    if setAlreadyInserted.contains(unigram.value + "\t" + unigram.key) {
      arrFoundedDuplications.append(unigram.value + "\t" + unigram.key)
    } else {
      setAlreadyInserted.insert(unigram.value + "\t" + unigram.key)
    }

    let theKey = unigram.key
    let theValue = (String(unigram.score) + " " + unigram.value)
    if !theKey.contains("_punctuation_list") {
      rangeMapJSON[cnvPhonabetToASCII(theKey), default: []].append(theValue)
    }
    strPrintLine += unigram.key + " " + unigram.value
    strPrintLine += " " + String(unigram.score)
    if unigram.count != 0 {
      strPrintLine += " " + String(unigram.count)
    }
    strPrintLine += "\n"
  }
  NSLog(" - \(i18n): 要寫入檔案的 txt 內容編譯完畢。")
  do {
    try strPrintLine.write(to: pathOutput, atomically: true, encoding: .utf8)
    if compileJSON {
      try JSONSerialization.data(withJSONObject: rangeMapJSON, options: .sortedKeys).write(to: jsonURL)
    }
    if isCHS {
      rangeMapJSONCHS = rangeMapJSON
    } else {
      rangeMapJSONCHT = rangeMapJSON
    }
  } catch {
    NSLog(" - \(i18n): Error on writing strings to file: \(error)")
  }
  NSLog(" - \(i18n): JSON & TXT 寫入完成。")
  if !arrFoundedDuplications.isEmpty {
    NSLog(" - \(i18n): 尋得下述重複項目，請務必手動排查：")
    print("-------------------")
    print(arrFoundedDuplications.joined(separator: "\n"))
  }
  print("===================")
}

func commonFileOutput() {
  let i18n = "語言中性"
  var strSymbols = ""
  var strZhuyinwen = ""
  var strCNS = ""
  var mapSymbols: [String: [String]] = [:]
  var mapZhuyinwen: [String: [String]] = [:]
  var mapCNS: [String: [String]] = [:]
  var mapReverseLookupCNS1: [String: [String]] = [:]
  var mapReverseLookupCNS2: [String: [String]] = [:]
  var mapReverseLookupCNS3: [String: [String]] = [:]
  var mapReverseLookupCNS4: [String: [String]] = [:]
  var mapReverseLookupCNS5: [String: [String]] = [:]
  var mapReverseLookupCNS6: [String: [String]] = [:]
  // 讀取標點內容
  do {
    strSymbols = try String(contentsOfFile: urlSymbols, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
    strZhuyinwen = try String(contentsOfFile: urlZhuyinwen, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
    strCNS = try String(contentsOfFile: urlCNS, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
  } catch {
    NSLog(" - \(i18n): Exception happened when reading raw punctuation data.")
  }
  NSLog(" - \(i18n): 成功取得標點符號與西文字母原始資料（JSON）。")
  // 統合辭典內容
  strSymbols.ranges(splitBy: "\n").forEach {
    let neta = strSymbols[$0].split(separator: " ")
    let line = String(strSymbols[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        let encryptedKey = cnvPhonabetToASCII(theKey)
        mapSymbols[encryptedKey, default: []].append(theValue)
        rangeMapSymbols[encryptedKey, default: []].append(theValue)
      }
    }
  }
  strZhuyinwen.ranges(splitBy: "\n").forEach {
    let neta = strZhuyinwen[$0].split(separator: " ")
    let line = String(strZhuyinwen[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        let encryptedKey = cnvPhonabetToASCII(theKey)
        mapZhuyinwen[encryptedKey, default: []].append(theValue)
        rangeMapZhuyinwen[encryptedKey, default: []].append(theValue)
      }
    }
  }
  strCNS.ranges(splitBy: "\n").forEach {
    let neta = strCNS[$0].split(separator: " ")
    let line = String(strCNS[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        let encryptedKey = cnvPhonabetToASCII(theKey)
        mapCNS[encryptedKey, default: []].append(theValue)
        rangeMapCNS[encryptedKey, default: []].append(theValue)
        json: if !theKey.contains("_"), !theKey.contains("-") {
          rangeMapReverseLookup[theValue, default: []].append(encryptedKey)
          if mapReverseLookupCNS1.keys.count <= 16500 {
            mapReverseLookupCNS1[theValue, default: []].append(encryptedKey)
            break json
          }
          if mapReverseLookupCNS2.keys.count <= 16500 {
            mapReverseLookupCNS2[theValue, default: []].append(encryptedKey)
            break json
          }
          if mapReverseLookupCNS3.keys.count <= 16500 {
            mapReverseLookupCNS3[theValue, default: []].append(encryptedKey)
            break json
          }
          if mapReverseLookupCNS4.keys.count <= 16500 {
            mapReverseLookupCNS4[theValue, default: []].append(encryptedKey)
            break json
          }
          if mapReverseLookupCNS5.keys.count <= 16500 {
            mapReverseLookupCNS5[theValue, default: []].append(encryptedKey)
            break json
          }
          if mapReverseLookupCNS6.keys.count <= 16500 {
            mapReverseLookupCNS6[theValue, default: []].append(encryptedKey)
            break json
          }
        }
      }
    }
  }
  NSLog(" - \(i18n): 要寫入檔案的內容編譯完畢。")
  do {
    if compileJSON {
      try JSONSerialization.data(withJSONObject: mapSymbols, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONSymbols))
      try JSONSerialization.data(withJSONObject: mapZhuyinwen, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONZhuyinwen))
      try JSONSerialization.data(withJSONObject: mapCNS, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONCNS))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS1, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS1))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS2, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS2))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS3, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS3))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS4, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS4))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS5, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS5))
      try JSONSerialization.data(withJSONObject: mapReverseLookupCNS6, options: .sortedKeys).write(
        to: URL(fileURLWithPath: urlJSONBPMFReverseLookupCNS6))
    }
  } catch {
    NSLog(" - \(i18n): Error on writing strings to file: \(error)")
  }
  NSLog(" - \(i18n): 寫入完成。")
}

// MARK: - 辭庫健康狀況檢查專用函式

func healthCheck(_ data: [Unigram]) -> String {
  while mapReverseLookupForCheck.isEmpty { sleep(1) }
  var result = ""
  var unigramMonoChar = [String: Unigram]()
  var valueToScore = [String: Double]()
  let unigramMonoCharCounter = data.filter { $0.score > -14 && $0.key.split(separator: "-").count == 1 }.count
  let unigramPolyCharCounter = data.filter { $0.score > -14 && $0.key.split(separator: "-").count > 1 }.count

  // 核心字詞庫的內容頻率一般大於 -10，但也得考慮某些包含假名的合成詞。
  for neta in data.filter({ $0.score > -14 }) {
    valueToScore[neta.value] = max(neta.score, valueToScore[neta.value] ?? -14)
    let theKeySliceArr = neta.key.split(separator: "-")
    guard let theKey = theKeySliceArr.first, theKeySliceArr.count == 1 else { continue }
    if unigramMonoChar.keys.contains(String(theKey)), let theRecord = unigramMonoChar[String(theKey)] {
      if neta.score > theRecord.score { unigramMonoChar[String(theKey)] = neta }
    } else {
      unigramMonoChar[String(theKey)] = neta
    }
  }

  var faulty = [[String]: [Unigram]]()
  var indifferents: [(String, String, Double, [Unigram], Double)] = []
  var insufficients: [(String, String, Double, [Unigram], Double)] = []
  var competingUnigrams = [(String, Double, String, Double)]()

  for neta in data.filter({ $0.key.split(separator: "-").count >= 2 && $0.score > -14 }) {
    var competants = [Unigram]()
    var tscore: Double = 0
    var bad = false
    let checkPerCharMachingStatus: Bool = neta.key.split(separator: "-").count == neta.value.count

    var mispronouncedKanji: [String] = []

    let arrNetaKeys = neta.key.split(separator: "-")
    outerMatchCheck: for (i, x) in arrNetaKeys.enumerated() {
      if !unigramMonoChar.keys.contains(String(x)) {
        if neta.value.count == 1 {
          mispronouncedKanji.append("\(neta.category)@\(neta.value)@\(neta.key)")
        } else if neta.value.count == arrNetaKeys.count {
          mispronouncedKanji.append("\(neta.category)@\(neta.value.map(\.description)[i])@\(arrNetaKeys[i])")
        } else {
          mispronouncedKanji.append("\(neta.category)@OTHER@\(String(x))")
        }
        bad = true
        break outerMatchCheck
      }
      innerMatchCheck: if checkPerCharMachingStatus {
        let char = neta.value.map(\.description)[i]
        if exceptedChars.contains(char) { break innerMatchCheck }
        guard let queriedPhones = mapReverseLookupForCheck[char] else {
          mispronouncedKanji.append("\(neta.category)@\(char)@\(String(x))")
          bad = true
          break outerMatchCheck
        }
        for queriedPhone in queriedPhones {
          if queriedPhone == x.description { break innerMatchCheck }
        }
        mispronouncedKanji.append("\(neta.category)@\(char)@\(String(x))")
        bad = true
        break outerMatchCheck
      }
      guard let u = unigramMonoChar[String(x)] else { continue }
      tscore += u.score
      competants.append(u)
    }

    if bad {
      faulty[mispronouncedKanji, default: []].append(neta)
      continue
    }
    if tscore >= neta.score {
      let instance = (neta.key, neta.value, neta.score, competants, neta.score - tscore)
      let valueJoined = String(competants.map(\.value).joined(separator: ""))
      if neta.value == valueJoined {
        indifferents.append(instance)
      } else {
        if valueToScore.keys.contains(valueJoined), neta.value != valueJoined {
          if let valueJoinedScore = valueToScore[valueJoined], neta.score < valueJoinedScore {
            competingUnigrams.append((neta.value, neta.score, valueJoined, valueJoinedScore))
          }
        }
        insufficients.append(instance)
      }
    }
  }

  insufficients = insufficients.sorted(by: { lhs, rhs -> Bool in
    (lhs.2) > (rhs.2)
  })
  competingUnigrams = competingUnigrams.sorted(by: { lhs, rhs -> Bool in
    (lhs.1 - lhs.3) > (rhs.1 - rhs.3)
  })

  let separator: String = {
    var result = ""
    for _ in 0 ..< 72 { result += "-" }
    return result
  }()

  func printl(_ input: String) {
    result += input + "\n"
  }

  printl(separator)
  printl("持單個字符的有效單元圖數量：\(unigramMonoCharCounter)")
  printl("持多個字符的有效單元圖數量：\(unigramPolyCharCounter)")

  printl(separator)
  printl("總結一下那些容易被單個漢字的字頻干擾輸入的詞組單元圖：")
  printl("因干擾組件和字詞本身完全重疊、而不需要處理的單元圖的數量：\(indifferents.count)")
  printl(
    "有 \(insufficients.count) 個複字單元圖被自身成分讀音對應的其它單字單元圖奪權，約佔全部有效單元圖的 \(insufficients.count / unigramPolyCharCounter * 100)%，"
  )
  printl("\n其中有：")

  var insufficientsMap = [Int: [(String, String, Double, [Unigram], Double)]]()
  for x in 2 ... 10 {
    insufficientsMap[x] = insufficients.filter { $0.0.split(separator: "-").count == x }
  }

  printl("  \(insufficientsMap[2]?.count ?? 0) 個有效雙字單元圖")
  printl("  \(insufficientsMap[3]?.count ?? 0) 個有效三字單元圖")
  printl("  \(insufficientsMap[4]?.count ?? 0) 個有效四字單元圖")
  printl("  \(insufficientsMap[5]?.count ?? 0) 個有效五字單元圖")
  printl("  \(insufficientsMap[6]?.count ?? 0) 個有效六字單元圖")
  printl("  \(insufficientsMap[7]?.count ?? 0) 個有效七字單元圖")
  printl("  \(insufficientsMap[8]?.count ?? 0) 個有效八字單元圖")
  printl("  \(insufficientsMap[9]?.count ?? 0) 個有效九字單元圖")
  printl("  \(insufficientsMap[10]?.count ?? 0) 個有效十字單元圖")

  if let insufficientsMap2 = insufficientsMap[2], !insufficientsMap2.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效雙字單元圖")
    for (i, content) in insufficientsMap2.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap3 = insufficientsMap[3], !insufficientsMap3.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效三字單元圖")
    for (i, content) in insufficientsMap3.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap4 = insufficientsMap[4], !insufficientsMap4.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效四字單元圖")
    for (i, content) in insufficientsMap4.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap5 = insufficientsMap[5], !insufficientsMap5.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效五字單元圖")
    for (i, content) in insufficientsMap5.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap6 = insufficientsMap[6], !insufficientsMap6.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效六字單元圖")
    for (i, content) in insufficientsMap6.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap7 = insufficientsMap[7], !insufficientsMap7.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效七字單元圖")
    for (i, content) in insufficientsMap7.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap8 = insufficientsMap[8], !insufficientsMap8.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效八字單元圖")
    for (i, content) in insufficientsMap8.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap9 = insufficientsMap[9], !insufficientsMap9.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效九字單元圖")
    for (i, content) in insufficientsMap9.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap10 = insufficientsMap[10], !insufficientsMap10.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效十字單元圖")
    for (i, content) in insufficientsMap10.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if !competingUnigrams.isEmpty {
    printl(separator)
    printl("也發現有 \(competingUnigrams.count) 個複字單元圖被某些由高頻單字組成的複字單元圖奪權的情況，")
    printl("例如（前二十五例）：")
    for (i, content) in competingUnigrams.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += String(content.1) + ","
      contentToPrint += content.2 + ","
      contentToPrint += String(content.3) + "}"
      printl(contentToPrint)
    }
  }

  if !faulty.isEmpty {
    printl(separator)
    printl("下述單元圖用到了漢字核心表當中尚未收錄的讀音，可能無法正常輸入：")
    for content in faulty {
      printl("\(content.key): \(content.value)")
    }
  }

  result += "\n"
  return result
}

// MARK: - 主執行緒

var compileJSON = false
var compileSQLite = true

func main() {
  let arguments = CommandLine.arguments.compactMap { $0.lowercased() }
  let conditionMet = arguments.contains(where: { $0 == "--json" || $0 == "json" })
  if conditionMet {
    NSLog("// 接下來準備建置 JSON 格式的原廠辭典，同時生成用來偵錯的 TXT 副產物。")
    compileJSON = true
    compileSQLite = false
  } else {
    NSLog("// 接下來準備建置 SQLite 格式的原廠辭典，同時生成用來偵錯的 TXT 副產物。")
    compileJSON = false
    compileSQLite = true
  }

  if compileSQLite {
    guard prepareDatabase() else {
      NSLog("// SQLite 資料庫初期化失敗。")
      exit(-1)
    }
  }
  let globalQueue = DispatchQueue.global(qos: .default)
  let group = DispatchGroup()
  group.enter()
  globalQueue.async {
    NSLog("// 準備編譯符號表情ㄅ文語料檔案。")
    commonFileOutput()
    group.leave()
  }
  group.enter()
  globalQueue.async {
    NSLog("// 準備編譯繁體中文核心語料檔案。")
    fileOutput(isCHS: false)
    group.leave()
  }
  group.enter()
  globalQueue.async {
    NSLog("// 準備編譯簡體中文核心語料檔案。")
    fileOutput(isCHS: true)
    group.leave()
  }
  // 一直等待完成
  _ = group.wait(timeout: .distantFuture)
  NSLog("// 全部 TXT 辭典檔案建置完畢。")
  if compileJSON {
    NSLog("// 全部 JSON 辭典檔案建置完畢。")
  }
  if compileSQLite {
    NSLog("// 開始整合反查資料。")
    mapReverseLookupForCheck.forEach { key, values in
      values.reversed().forEach { valueLiteral in
        let value = cnvPhonabetToASCII(valueLiteral)
        if !rangeMapReverseLookup[key, default: []].contains(value) {
          rangeMapReverseLookup[key, default: []].insert(value, at: 0)
        }
      }
    }
    NSLog("// 反查資料整合完畢。")
    NSLog("// 準備建置 SQL 資料庫。")
    writeMainMapToSQL(rangeMapJSONCHS, column: "theDataCHS")
    writeMainMapToSQL(rangeMapJSONCHT, column: "theDataCHT")
    writeMainMapToSQL(rangeMapSymbols, column: "theDataSYMB")
    writeMainMapToSQL(rangeMapZhuyinwen, column: "theDataCHEW")
    writeMainMapToSQL(rangeMapCNS, column: "theDataCNS")
    writeRevLookupMapToSQL(rangeMapReverseLookup)
    let committed = "commit;".runAsSQLExec(dbPointer: &ptrSQL)
    assert(committed)
    let compressed = "VACUUM;".runAsSQLExec(dbPointer: &ptrSQL)
    assert(compressed)
    sqlite3_close_v2(ptrSQL)
    NSLog("// 全部 SQLite 辭典檔案建置完畢。")
  }
}

main()
