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

#if os(Linux)
  import Glibc
#else
  import Darwin
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
      #else
        break
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

    let enumerator = FileManager.default.enumerator(atPath: dictDir)
    guard let filePaths = enumerator?.allObjects as? [String] else { return }
    let arrFiles = filePaths.filter { $0.contains(".txt") }.compactMap { URL(string: dictDir + $0) }
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
            .split(separator: "\n")
          for line in arrLines {
            let arrWords = line.split(separator: "\t")
            if arrWords.count == 2 {
              if var theSubDict = dict[dictType] {
                theSubDict[String(arrWords[0])] = String(arrWords[1])
                dict[dictType] = theSubDict
              } else {
                dict[dictType] = .init()
              }
            }
          }
        } catch {
          continue
        }
      }
    }
    sleep(1)
  }

  // MARK: Public

  // MARK: - Public Methods

  public func query(dict dictType: DictType, key searchKey: String) -> String? {
    guard ptrSQL != nil else { return dict[dictType.rawKeyString]?[searchKey] }
    var ptrStatement: OpaquePointer?
    let sqlQuery =
      "SELECT * FROM DATA_HOTENKA WHERE dict=\(dictType.rawValue) AND theKey='\(searchKey)';"
    sqlite3_prepare_v2(ptrSQL, sqlQuery, -1, &ptrStatement, nil)
    defer {
      sqlite3_finalize(ptrStatement)
      ptrStatement = nil
    }
    // 此處只需要用到第一筆結果。
    while sqlite3_step(ptrStatement) == SQLITE_ROW {
      guard let rawValue = sqlite3_column_text(ptrStatement, 2) else { continue }
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
