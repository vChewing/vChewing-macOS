// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
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

import CSQLite3
import Foundation

#if canImport(Musl)
  import Musl
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#elseif canImport(ucrt)
  import ucrt
#endif

#if canImport(OSLog)
  import OSLog
#endif

// MARK: - DictType

public enum DictType: Int, CaseIterable {
  case zhHantTW = 0
  case zhHantHK = 1
  case zhHansSG = 2
  case zhHansJP = 3
  case zhHantKX = 4
  case zhHansCN = 5

  // MARK: Public

  public var rawKeyString: String {
    switch self {
    case .zhHantTW:
      return "zh2TW"
    case .zhHantHK:
      return "zh2HK"
    case .zhHansSG:
      return "zh2SG"
    case .zhHansJP:
      return "zh2JP"
    case .zhHantKX:
      return "zh2KX"
    case .zhHansCN:
      return "zh2CN"
    }
  }

  public static func match(rawKeyString: String) -> Self? {
    Self.allCases.filter { $0.rawKeyString == rawKeyString }.first
  }
}

// MARK: - Hotenka

public enum Hotenka {
  static func consoleLog<S: StringProtocol>(_ msg: S) {
    let msgStr = msg.description
    if #available(macOS 26.0, *) {
      #if canImport(OSLog)
        let logger = Logger(subsystem: "vChewing", category: "Hotenka")
        logger.log(level: .default, "\(msgStr, privacy: .public)")
        return
      #endif
    }

    // 兼容旧系统
    NSLog(msgStr)
  }
}

// MARK: - HotenkaChineseConverter

public final class HotenkaChineseConverter {
  // MARK: Lifecycle

  deinit {
    sqlite3_close_v2(ptrSQL)
    ptrSQL = nil
  }

  public init(sqliteDir dbPath: String) {
    self.dict = .init()
    self.dictFiles = .init()
    guard sqlite3_open(dbPath, &ptrSQL) == SQLITE_OK else {
      Hotenka.consoleLog("// Exception happened when connecting to SQLite database at: \(dbPath).")
      self.ptrSQL = nil
      return
    }
    sqlite3_exec(ptrSQL, "PRAGMA journal_mode = OFF;", nil, nil, nil)

    // Sanity check: verify a sample key exists (helps detect CRLF/trimming/sql bind issues on platforms)
    do {
      var ptrStatement: OpaquePointer?
      let checkQuery = "SELECT theValue FROM DATA_HOTENKA WHERE dict=0 AND theKey = ? LIMIT 1;"
      if sqlite3_prepare_v2(ptrSQL, checkQuery, -1, &ptrStatement, nil) == SQLITE_OK {
        "为".withCString { ckey in
          _ = sqlite3_bind_text(ptrStatement, 1, ckey, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        if sqlite3_step(ptrStatement) == SQLITE_ROW, let raw = sqlite3_column_text(ptrStatement, 0) {
          Hotenka.consoleLog("// SQLite sanity: found sample mapping -> \(String(cString: raw))")
        } else {
          Hotenka.consoleLog("// SQLite sanity: sample mapping not found for dict=0 key='为'")
        }
        sqlite3_finalize(ptrStatement)
        ptrStatement = nil
      }

      // Count rows per dict to verify population
      for id in 0 ... 5 {
        var cntStmt: OpaquePointer?
        let cntQuery = "SELECT COUNT(*) FROM DATA_HOTENKA WHERE dict=\(id);"
        if sqlite3_prepare_v2(ptrSQL, cntQuery, -1, &cntStmt, nil) == SQLITE_OK {
          if sqlite3_step(cntStmt) == SQLITE_ROW {
            let cnt = sqlite3_column_int(cntStmt, 0)
            Hotenka.consoleLog("// SQLite rows for dict=\(id): \(cnt)")
          }
          sqlite3_finalize(cntStmt)
          cntStmt = nil
        }
      }
    }
  }

  public init(plistDir: String) {
    self.dictFiles = .init()
    do {
      let rawData = try Data(contentsOf: URL(fileURLWithPath: plistDir))
      let rawPlist: [String: [String: String]] =
        try PropertyListSerialization
          .propertyList(from: rawData, format: nil) as? [String: [String: String]] ?? .init()
      self.dict = rawPlist
    } catch {
      Hotenka.consoleLog("// Exception happened when reading dict plist at: \(plistDir).")
      self.dict = .init()
    }
  }

  public init(jsonDir: String) {
    self.dictFiles = .init()
    do {
      let rawData = try Data(contentsOf: URL(fileURLWithPath: jsonDir))
      let rawJSON = try JSONDecoder().decode([String: [String: String]].self, from: rawData)
      self.dict = rawJSON
    } catch {
      Hotenka.consoleLog("// Exception happened when reading dict json at: \(jsonDir).")
      self.dict = .init()
    }
  }

  public init(dictDir: String) {
    self.dictFiles = [
      "zh2TW": [String](),
      "zh2HK": [String](),
      "zh2SG": [String](),
      "zh2JP": [String](),
      "zh2KX": [String](),
      "zh2CN": [String](),
    ]
    self.dict = [
      "zh2TW": [String: String](),
      "zh2HK": [String: String](),
      "zh2SG": [String: String](),
      "zh2JP": [String: String](),
      "zh2KX": [String: String](),
      "zh2CN": [String: String](),
    ]

    // 建立基底檔案目錄 URL，確保為本機檔案路徑
    let baseURL = URL(fileURLWithPath: dictDir)
    let enumerator = FileManager.default.enumerator(atPath: dictDir)
    guard let filePaths = enumerator?.allObjects as? [String] else { return }
    // 以 fileURLWithPath + appendingPathComponent 的方式建立檔案 URL，避免 URL(string:) 解析為網路 URL
    let arrFiles = filePaths.filter { $0.contains(".txt") }.map { baseURL.appendingPathComponent($0) }
    for theURL in arrFiles {
      let fullFilename = theURL.lastPathComponent
      let mainFilename = fullFilename.substring(to: fullFilename.range(of: ".").lowerBound)

      if var neta = dictFiles[mainFilename] {
        neta.append(theURL.path)
        dictFiles[mainFilename] = neta
      } else {
        dictFiles[mainFilename] = [theURL.path]
      }
    }

    for dictType in dictFiles.keys {
      guard let arrFiles = dictFiles[dictType] else { continue }
      if arrFiles.isEmpty {
        continue
      }

      for filePath in arrFiles {
        if !FileManager.default.fileExists(atPath: filePath) {
          continue
        }
        do {
          let arrLines = try String(contentsOfFile: filePath, encoding: .utf8)
            .split(whereSeparator: { $0.isNewline })
          for line in arrLines {
            let arrWords = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            if arrWords.count == 2 {
              let key = String(arrWords[0]).trimmingCharacters(in: .whitespacesAndNewlines)
              let val = String(arrWords[1]).trimmingCharacters(in: .whitespacesAndNewlines)
              if var theSubDict = dict[dictType] {
                theSubDict[key] = val
                dict[dictType] = theSubDict
              } else {
                dict[dictType] = [key: val]
              }
            }
          }
        } catch {
          continue
        }
      }
    }
    Thread.sleep(forTimeInterval: 1)
  }

  // MARK: Public

  // MARK: - Public Methods

  public func query(dict dictType: DictType, key searchKey: String) -> String? {
    guard ptrSQL != nil else { return dict[dictType.rawKeyString]?[searchKey] }
    var ptrStatement: OpaquePointer?
    let sqlQuery = "SELECT theValue FROM DATA_HOTENKA WHERE dict=? AND theKey=?;"
    // 使用 prepared statement 與 bind 參數以避免 SQL 注入
    let preparation = sqlite3_prepare_v2(ptrSQL, sqlQuery, -1, &ptrStatement, nil)
    guard preparation == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(ptrStatement); ptrStatement = nil }
    // 綁定 dict 與 key
    _ = sqlite3_bind_int(ptrStatement, 1, Int32(dictType.rawValue))
    searchKey.withCString { cKey in
      _ = sqlite3_bind_text(ptrStatement, 2, cKey, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
    // 此處只需要用到第一筆結果。
    while sqlite3_step(ptrStatement) == SQLITE_ROW {
      // 因為 SELECT theValue 回傳的是第 0 欄位
      guard let rawValue = sqlite3_column_text(ptrStatement, 0) else { continue }
      return String(cString: rawValue)
    }
    return nil
  }

  public func convert(_ target: String, to dictType: DictType) -> String {
    var result = ""
    if ptrSQL == nil {
      guard dict[dictType.rawKeyString] != nil else { return target }
    }

    var i = 0
    while i < (target.count) {
      let max = (target.count) - i
      var j: Int
      j = max

      innerloop: while j > 0 {
        let start = target.index(target.startIndex, offsetBy: i)
        let end = target.index(target.startIndex, offsetBy: i + j)
        guard let useDictSubStr = query(dict: dictType, key: String(target[start ..< end])) else {
          j -= 1
          continue
        }
        result = result + useDictSubStr
        break innerloop
      }

      if j == 0 {
        let start = target.index(target.startIndex, offsetBy: i)
        let end = target.index(target.startIndex, offsetBy: i + 1)
        result = result + String(target[start ..< end])
        i += 1
      } else {
        i += j
      }
    }

    return result
  }

  // MARK: Internal

  private(set) var dict: [String: [String: String]]
  var ptrSQL: OpaquePointer?

  // MARK: Private

  private var dictFiles: [String: [String]]
}

// MARK: - String extensions

extension String {
  fileprivate func range(of str: String) -> Range<Int> {
    var start = -1
    withCString { bytes in
      str.withCString { sbytes in
        start = strstr(bytes, sbytes) - UnsafeMutablePointer<Int8>(mutating: bytes)
      }
    }
    return start < 0 ? 0 ..< 0 : start ..< start + str.utf8.count
  }

  fileprivate func substring(to index: Int) -> String {
    var out = self
    withCString { bytes in
      let bytes = UnsafeMutablePointer<Int8>(mutating: bytes)
      bytes[index] = 0
      out = String(cString: bytes)
    }
    return out
  }

  fileprivate func substring(from index: Int) -> String {
    var out = self
    withCString { bytes in
      out = String(cString: bytes + index)
    }
    return out
  }
}
