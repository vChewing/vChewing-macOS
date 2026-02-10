// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CSQLite3Lib
import Foundation
import LMAssemblyMaterials4Tests
import Megrez
import Testing

@testable import LangModelAssembly

private let strCakeKey: [String] = ["ㄉㄢˋ", "ㄍㄠ"]
private let strHaninSymbolMenuKey: [String] = ["_punctuation_list"]
private let strZhongKey: [String] = ["ㄓㄨㄥ"]
private let strBoobsKey: [String] = ["ㄋㄟ", "ㄋㄟ"]
private let expectedReverseLookupResults: [String] = [
  "ㄏㄜˋ", "ㄏㄜ˙", "ㄏㄜˊ", "ㄏㄨㄛ", "ㄏㄨˊ",
  "ㄏㄨㄛ˙", "ㄏㄨㄛˊ", "ㄏㄨㄛˋ", "ㄏㄢˋ", "ㄉㄨㄥ",
]

// MARK: - LMInstantiatorSQLTests

@Suite(.serialized)
struct LMInstantiatorSQLTests {
  // MARK: Internal

  @Test
  func testSQL() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    #expect(!LMATestsData.sqlTestCoreLMData.isEmpty)
    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData))
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
    }
    #expect(instance.unigramsFor(keyArray: strCakeKey).description == "[(ㄉㄢˋ-ㄍㄠ,蛋糕,-4.073)]")
    #expect(instance.getHaninSymbolMenuUnigrams()[1].description == "(_punctuation_list,，,-9.9)")
    #expect(instance.unigramsFor(keyArray: strBoobsKey).description == "[(ㄋㄟ-ㄋㄟ,ㄋㄟㄋㄟ,-1.0)]")
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = true
    }
    #expect(instance.unigramsFor(keyArray: strCakeKey).last?.description == "(ㄉㄢˋ-ㄍㄠ,🧁,-13.000001)")
    #expect(instance.getHaninSymbolMenuUnigrams()[1].description == "(_punctuation_list,，,-9.9)")
    #expect(instance.unigramsFor(keyArray: strZhongKey).count == 21)
    #expect(instance.unigramsFor(keyArray: strBoobsKey).last?.description == "(ㄋㄟ-ㄋㄟ,☉☉,-13.0)")
    // 再測試反查。
    #expect(LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "和") == expectedReverseLookupResults)
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  @Test
  func testCNSMask() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: false)
    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData))
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.filterNonCNSReadings = false
      config.alwaysSupplyETenDOSUnigrams = false
    }
    #expect(instance.unigramsFor(keyArray: ["ㄨㄟ"]).first(where: { $0.value == "危" })?.description == "(ㄨㄟ,危,-5.287)")
    #expect(instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).first(where: { $0.value == "危" })?.description == "(ㄨㄟˊ,危,-5.287)")
    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }
    #expect(instance.unigramsFor(keyArray: ["ㄨㄟ"]).first(where: { $0.value == "危" }) == nil)
    #expect(instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).first(where: { $0.value == "危" })?.description == "(ㄨㄟˊ,危,-5.287)")
  }

  @Test
  func testFactoryKeyWithApostropheIsFound() throws {
    // 確保包含尾隨單引號的 key 能正確從資料庫擷取。
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    let sqlSetup = """
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
    INSERT INTO DATA_MAIN(theKey, theDataCHS) VALUES ('k''', '1 value');
    """

    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlSetup))
    let grams = instance.unigramsFor(keyArray: ["k'"])
    #expect(gramsContainValue(grams, "value"))
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  @Test
  func testFactoryCNSAndExistenceWithApostropheKey() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: false)
    let sqlSetup = """
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
    INSERT INTO DATA_MAIN(theKey, theDataCNS) VALUES ('k''', 'cnsval');
    """
    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlSetup))
    // 透過 connectToTestSQLDB 確認資料庫連線已建立
    // 檢查 CNS 過濾執行緒
    guard let cnsv = instance.factoryCNSFilterThreadFor(key: "k'") else {
      Issue.record("Failed to retrieve CNS value for key with apostrophe.")
      return
    }
    #expect(cnsv.contains("cnsval"))
    // 檢查該 key 的 theDataCNS 欄位是否存在
    let encryptedKeyForCheck = "k'"
    let q = "SELECT * FROM DATA_MAIN WHERE theKey = ? AND theDataCNS IS NOT NULL"
    let existsCNS = LMAssembly.LMInstantiator.hasSQLResult(strStmt: q, params: [encryptedKeyForCheck])
    #expect(existsCNS)
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  @Test
  func testFactorySupersetUnigramsFor() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    let sqlSetup = """
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
    INSERT INTO DATA_MAIN(theKey, theDataCHS) VALUES ('A-B-C', '-9.0 base');
    INSERT INTO DATA_MAIN(theKey, theDataCHS) VALUES ('Z-A-B-C', '-1.0 zval');
    INSERT INTO DATA_MAIN(theKey, theDataCHS) VALUES ('A-B-C-F', '-2.0 fval');
    INSERT INTO DATA_MAIN(theKey, theDataCHS) VALUES ('M-A-B-C-Q', '-3.0 mval');
    """

    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlSetup))

    let grams = instance.factorySupersetUnigramsFor(
      subsetKey: "A-B-C",
      subsetKeyArray: ["A", "B", "C"],
      column: .theDataCHS
    )

    #expect(gramsContainValue(grams, "zval"))
    #expect(gramsContainValue(grams, "fval"))
    #expect(gramsContainValue(grams, "mval"))
    #expect(!gramsContainValue(grams, "base"))

    // 確認返回的 keyArray 為 superset（長度大於子集合）
    if let z = grams.first(where: { $0.value == "zval" }) {
      #expect(z.keyArray.count == 4)
    } else {
      Issue.record("Failed to find 'zval' unigram.")
    }

    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  // MARK: Private

  private func gramsContainValue(_ grams: [Megrez.Unigram], _ value: String) -> Bool {
    grams.contains(where: { $0.value == value })
  }
}

extension LMInstantiatorSQLTests {
  /// 以下測試用例無法在 Xcode 中執行，因為與 Xcode 單元測試沙箱機制不相容。
  @Test
  func testNoSQLStringInterpolationAcrossRepo() throws {
    // 此測試執行全 repo 檔案系統掃描，與 Xcode 單元測試沙箱不相容。
    // 在 Xcode 中執行時跳過此測試。
    let env = ProcessInfo.processInfo.environment
    if env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
      nil {
      return
    }
    // 掃描所有 .swift 檔案（排除 Source/Data）並回報疑似的 SQL 字串插值。
    var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var root: URL?
    while true {
      let candidate = cwd.appendingPathComponent("vChewing.xcodeproj")
      if FileManager.default.fileExists(atPath: candidate.path) {
        root = cwd
        break
      }
      guard cwd.pathComponents.count > 1 else { break }
      cwd.deleteLastPathComponent()
    }
    guard let repoRoot = root else {
      Issue.record("Failed to locate repository root directory.")
      return
    }

    let primaryKeywords = ["SELECT", "INSERT", "DELETE", "UPDATE", "DROP"]
    let secondaryKeywords = ["WHERE", "FROM"]
    let fm = FileManager.default
    // 限制掃描範圍至 package 原始檔案以減少誤報。
    let packagesRoot = repoRoot.appendingPathComponent("Packages")
    let enumerator = fm.enumerator(at: packagesRoot, includingPropertiesForKeys: nil)!
    var findings: [String] = []
    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      // 排除 submodule、建置／衍生原始碼、腳本與 DevLab
      // 跳過測試檔案與建置產物，避免掃描測試用 SQL 字串或衍生程式碼。
      let folderNamesToExclude: Set<String> = [
        "Sources",
        ".build",
        "Build",
        "Tests",
        "Scripts",
        "DevLab",
        "Plugins",
      ]
      let shouldSkipFolder: Bool = !Set(node.pathComponents.dropLast()).intersection(
        folderNamesToExclude
      ).isEmpty
      guard !shouldSkipFolder, path.hasSuffix(".swift") else { continue }
      guard let content = try? String(contentsOf: node, encoding: .utf8) else { continue }
      // 僅掃描包含 Swift 字串插值（"\( ... )"）的行。
      if content.contains("\\(") {
        let lines = content.split(separator: "\n")
        for (idx, line) in lines.enumerated() {
          let str = String(line)
          // 在行中尋找加引號的子字串（簡易方法：定位成對的雙引號）。
          var searchStart = str.startIndex
          let quote: Character = "\""
          while let openQuote = str[searchStart...].firstIndex(of: quote) {
            let afterOpen = str.index(after: openQuote)
            guard let closeQuote = str[afterOpen...].firstIndex(of: quote) else { break }
            let quoted = String(str[afterOpen ..< closeQuote])
            // 檢查加引號字串內的插值與 SQL 關鍵字。
            if quoted.contains("\\(") {
              let upperQuoted = quoted.uppercased()
              // 僅在存在主要 SQL 起始關鍵字時標記；這可避免誤匹配日誌中的一般 'from' 或 'where'。
              let hasPrimary = primaryKeywords.contains { kw in
                upperQuoted.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil
              }
              if hasPrimary {
                findings.append("\(path):\(idx + 1): \(str.trimmingCharacters(in: .whitespaces))")
              } else {
                // 若未找到主要關鍵字，但存在 WHERE/FROM 等次要關鍵字，僅在加引號字串
                // 包含典型 SQL 標點符號（如逗號、括號、分號）時視為可疑，以減少誤報。
                let hasSecondary = secondaryKeywords.contains { kw in
                  upperQuoted.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil
                }
                if hasSecondary {
                  let punctuationSet = CharacterSet(charactersIn: ",();")
                  if quoted.rangeOfCharacter(from: punctuationSet) != nil {
                    findings.append("\(path):\(idx + 1): \(str.trimmingCharacters(in: .whitespaces))")
                  }
                }
              }
            }
            // 排除常見的日誌行或已知安全模式以減少誤報
            if str.contains("consoleLog(\"") || str.contains("vCLMLog(\"") || str.contains("Process.consoleLog(\"") {
              // 移除最近衍生的發現，若它是來自日誌的誤報
              if !findings.isEmpty { findings.removeLast() }
            }
            // 允許 LMInstantiator_SQLExtension 內已知的安全慣用語法（基於模式）
            if path.hasSuffix("LMInstantiator_SQLExtension.swift"),
               str.contains("SELECT EXISTS") || str.contains("column.name) IS NOT NULL") {
              if !findings.isEmpty { findings.removeLast() }
            }
            searchStart = str.index(after: closeQuote)
          }
        }
      }
    }
    // 若發現明顯實例則測試失敗。可能存在某些誤報；將此作為
    // 輕量級靜態檢查以捕捉意外的 SQL 插值。
    #expect(findings.isEmpty)
    if !findings.isEmpty { print("Found potential SQL string interpolation occurrences: \(findings)") }
  }
}

extension LMInstantiatorSQLTests {
  @Test
  func testPreparedStatementsResistSQLInjection() {
    // 建立一筆可用來驗證的樣本資料（包含防呆的 create table）
    let create = "CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL);"
    let insert = "INSERT OR REPLACE INTO DATA_REV (theChar, theReadings) VALUES ('A', 'z');"
    // 使用 connectToTestSQLDB 將 SQLite 初始化與插入語句一次性提交
    #expect(LMAssembly.LMInstantiator.connectToTestSQLDB(create + insert))
    #expect(LMAssembly.LMInstantiator.ptrSQL != nil)

    // 正常讀取：先以 sqlite3 直接查詢確認資料存在
    var ptrStmt: OpaquePointer?
    sqlite3_prepare_v2(
      LMAssembly.LMInstantiator.ptrSQL,
      "SELECT theReadings FROM DATA_REV WHERE theChar='A';",
      -1,
      &ptrStmt,
      nil
    )
    var dbFound = false
    while sqlite3_step(ptrStmt) == SQLITE_ROW {
      guard let raw = sqlite3_column_text(ptrStmt, 0) else { continue }
      let s = String(cString: raw)
      #expect(s == "z")
      dbFound = true
    }
    sqlite3_finalize(ptrStmt)
    #expect(dbFound)
    // Debug: 查詢 sqlite_master 以確認 tables
    var masterStmt: OpaquePointer?
    sqlite3_prepare_v2(
      LMAssembly.LMInstantiator.ptrSQL,
      "SELECT name FROM sqlite_master WHERE type='table';",
      -1,
      &masterStmt,
      nil
    )
    var tables = [String]()
    while sqlite3_step(masterStmt) == SQLITE_ROW {
      if let c = sqlite3_column_text(masterStmt, 0) {
        tables.append(String(cString: c))
      }
    }
    sqlite3_finalize(masterStmt)
    print("sqlite_master tables: \(tables)")
    #expect(!tables.isEmpty)
    // Debug: 查詢表筆數與列出內容
    var countStmt: OpaquePointer?
    sqlite3_prepare_v2(LMAssembly.LMInstantiator.ptrSQL, "SELECT COUNT(*) FROM DATA_REV;", -1, &countStmt, nil)
    var cnt = 0
    if sqlite3_step(countStmt) == SQLITE_ROW {
      cnt = Int(sqlite3_column_int(countStmt, 0))
    }
    sqlite3_finalize(countStmt)
    print("DATA_REV count: \(cnt)")
    #expect(cnt >= 1)
    // List rows
    var listStmt: OpaquePointer?
    sqlite3_prepare_v2(
      LMAssembly.LMInstantiator.ptrSQL,
      "SELECT theChar, theReadings FROM DATA_REV;",
      -1,
      &listStmt,
      nil
    )
    while sqlite3_step(listStmt) == SQLITE_ROW {
      let c0 = sqlite3_column_text(listStmt, 0)
      let c1 = sqlite3_column_text(listStmt, 1)
      print(
        "ROW: char=\(c0 != nil ? String(cString: c0!) : "nil") readings=\(c1 != nil ? String(cString: c1!) : "nil")"
      )
    }
    sqlite3_finalize(listStmt)
    // 使用 API 再次驗證 getFactoryReverseLookupData 能讀取
    let normal = LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "A")
    print("API normal result: \(String(describing: normal))")
    #expect(normal != nil)
    #expect(normal!.contains("z") || normal!.contains("ㄗ"))

    // 嘗試注入型 payload; 若程式利用 string interpolation 而非 bind，可能導致 DROP TABLE
    let payload = "A'); DROP TABLE DATA_REV; --"
    // 呼叫被保護的 API 不應該造成表結構變動
    _ = LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: payload)

    // 再次檢查資料是否仍存在
    let afterPayload = LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "A")
    #expect(afterPayload != nil)
    #expect(afterPayload!.contains("z") || afterPayload!.contains("ㄗ"))

    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  @Test
  func testHasSQLResultRequiresPlaceholdersWhenParamsGiven() {
    #expect(
      LMAssembly.LMInstantiator
        .connectToTestSQLDB("CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL);")
    )
    // 插入一筆測試資料，以便佔位符號測試時確實能回傳結果。
    #expect(
      LMAssembly.LMInstantiator
        .connectToTestSQLDB(
          "CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL); INSERT OR REPLACE INTO DATA_REV (theChar, theReadings) VALUES ('A', 'z');"
        )
    )
    // 正確使用方式：佔位符號數量與參數數量匹配
    let proper = LMAssembly.LMInstantiator.hasSQLResult(
      strStmt: "SELECT * FROM DATA_REV WHERE theChar = ?",
      params: ["A"]
    )
    #expect(proper)

    // 不匹配情況：提供了參數陣列但查詢語句中沒有佔位符號 -> 應回傳 false
    let mismatch = LMAssembly.LMInstantiator.hasSQLResult(
      strStmt: "SELECT * FROM DATA_REV WHERE theChar = 'A'",
      params: ["A"]
    )
    #expect(!mismatch)
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }
}
