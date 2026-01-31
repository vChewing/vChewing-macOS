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
import XCTest

@testable import Hotenka

private let packageRootPath = URL(fileURLWithPath: #file).pathComponents
  .prefix(while: { $0 != "Tests" }).joined(
    separator: "/"
  ).dropFirst()

private let testDataPath: String = packageRootPath + "/Tests/TestDictData/"

extension HotenkaTests {
  func testGeneratingSQLiteDB() throws {
    Hotenka.consoleLog("// Start loading from: \(packageRootPath)")
    let testInstance: HotenkaChineseConverter = .init(dictDir: testDataPath)
    Hotenka.consoleLog("// Loading complete. Generating SQLite database.")
    var ptrSQL: OpaquePointer?
    let dbPath = testDataPath + "convdict.sqlite"

    XCTAssertTrue(
      sqlite3_open(dbPath, &ptrSQL) == SQLITE_OK,
      "HOTENKA: SQLite Database Initialization Error."
    )
    XCTAssertTrue(
      sqlite3_exec(ptrSQL, "PRAGMA synchronous = OFF;", nil, nil, nil) == SQLITE_OK,
      "HOTENKA: SQLite synchronous OFF failed."
    )
    XCTAssertTrue(
      sqlite3_exec(ptrSQL, "PRAGMA journal_mode = OFF;", nil, nil, nil) == SQLITE_OK,
      "HOTENKA: SQLite journal_mode OFF failed."
    )

    let sqlMakeTableHotenka = """
    DROP TABLE IF EXISTS DATA_HOTENKA;
    CREATE TABLE IF NOT EXISTS DATA_HOTENKA (
      dict INTEGER,
      theKey TEXT,
      theValue TEXT,
      PRIMARY KEY (dict, theKey)
    ) WITHOUT ROWID;
    """

    XCTAssertTrue(
      sqlite3_exec(ptrSQL, sqlMakeTableHotenka, nil, nil, nil) == SQLITE_OK,
      "HOTENKA: SQLite Table Creation Failed."
    )

    XCTAssertTrue(sqlite3_exec(ptrSQL, "begin;", nil, nil, nil) == SQLITE_OK)

    testInstance.dict.forEach { dictName, subDict in
      Hotenka.consoleLog("// Debug: inserting dictName=\(dictName) subCount=\(subDict.count)")
      guard let dictID = DictType.match(rawKeyString: dictName)?.rawValue
      else { Hotenka.consoleLog("// Debug: dictName \(dictName) not matched to DictType"); return }
      subDict.forEach { key, value in
        var ptrStatement: OpaquePointer?
        let sqlInsertion = "INSERT INTO DATA_HOTENKA (dict, theKey, theValue) VALUES (?, ?, ?)"
        XCTAssertTrue(
          sqlite3_prepare_v2(ptrSQL, sqlInsertion, -1, &ptrStatement, nil) == SQLITE_OK,
          "HOTENKA: Failed from preparing: \(sqlInsertion)"
        )
        // bind values
        _ = sqlite3_bind_int(ptrStatement, 1, Int32(dictID))
        key.withCString { kptr in
          _ = sqlite3_bind_text(ptrStatement, 2, kptr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        value.withCString { vptr in
          _ = sqlite3_bind_text(ptrStatement, 3, vptr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        XCTAssertTrue(sqlite3_step(ptrStatement) == SQLITE_DONE, "HOTENKA: Failed from stepping: bound insert")
        sqlite3_finalize(ptrStatement)
        ptrStatement = nil
      }
    }
    XCTAssertTrue(sqlite3_exec(ptrSQL, "commit;", nil, nil, nil) == SQLITE_OK)
    sqlite3_close_v2(ptrSQL)
  }

  func testSampleWithSQLiteDB() throws {
    Hotenka.consoleLog("// Start loading plist from: \(packageRootPath)")
    let testInstance2: HotenkaChineseConverter = .init(sqliteDir: testDataPath + "convdict.sqlite")
    Hotenka.consoleLog("// Successfully loading sql dictionary.")

    let oriString = "为中华崛起而读书"
    let result1 = testInstance2.convert(oriString, to: .zhHantTW)
    let result2 = testInstance2.convert(result1, to: .zhHantKX)
    let result3 = testInstance2.convert(result2, to: .zhHansJP)
    Hotenka.consoleLog("// Results: \(result1) \(result2) \(result3)")
    XCTAssertEqual(result1, "為中華崛起而讀書")
    XCTAssertEqual(result2, "爲中華崛起而讀書")
    XCTAssertEqual(result3, "為中華崛起而読書")
  }

  func testSQLInjectionVulnerableQuery() throws {
    // 測試：使用惡意查詢字串，應不會造成 SQL 注入或回傳非特定條件下的結果
    let testInstance2: HotenkaChineseConverter = .init(sqliteDir: testDataPath + "convdict.sqlite")
    // 插入 2 組測試資料
    // 使用 LMInstantiator 讀取 DB 時，請確認 Hotenka 已經使用 prepared query
    let normalKey = "k1"
    let normalVal = "v1"
    let normalKey2 = "k2"
    let normalVal2 = "v2"
    // 直接呼叫 SQLite 工具，插入資料
    var ptrSQL: OpaquePointer?
    XCTAssertTrue(sqlite3_open(testDataPath + "convdict.sqlite", &ptrSQL) == SQLITE_OK)
    var ptrStatement: OpaquePointer?
    let sqlIns = "INSERT OR REPLACE INTO DATA_HOTENKA (dict, theKey, theValue) VALUES (0, ?, ?)"
    XCTAssertTrue(sqlite3_prepare_v2(ptrSQL, sqlIns, -1, &ptrStatement, nil) == SQLITE_OK)
    normalKey.withCString { c in
      _ = sqlite3_bind_text(
        ptrStatement,
        1,
        c,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
    normalVal.withCString { c in
      _ = sqlite3_bind_text(
        ptrStatement,
        2,
        c,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
    XCTAssertTrue(sqlite3_step(ptrStatement) == SQLITE_DONE)
    sqlite3_finalize(ptrStatement)
    // 插入第二個 Key
    XCTAssertTrue(sqlite3_prepare_v2(ptrSQL, sqlIns, -1, &ptrStatement, nil) == SQLITE_OK)
    normalKey2.withCString { c in
      _ = sqlite3_bind_text(
        ptrStatement,
        1,
        c,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
    normalVal2.withCString { c in
      _ = sqlite3_bind_text(
        ptrStatement,
        2,
        c,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
    XCTAssertTrue(sqlite3_step(ptrStatement) == SQLITE_DONE)
    sqlite3_finalize(ptrStatement)
    sqlite3_close_v2(ptrSQL)

    // 驗證：一般 key 查詢正確
    let res = testInstance2.query(dict: .zhHantTW, key: normalKey)
    XCTAssertEqual(res, normalVal)

    // 嘗試注入查詢字串
    let malicious = "k2' OR 1=1 --"
    let res2 = testInstance2.query(dict: .zhHantTW, key: malicious)
    // 如果 query 使用 bind statements，res2 應為 nil（無精確 match）
    XCTAssertNil(res2)
  }
}
