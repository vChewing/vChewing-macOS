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

import Foundation
import SQLite3
import XCTest

@testable import Hotenka

private let packageRootPath = URL(fileURLWithPath: #file).pathComponents
  .prefix(while: { $0 != "Tests" }).joined(
    separator: "/"
  ).dropFirst()

private let testDataPath: String = packageRootPath + "/Tests/TestDictData/"

extension HotenkaTests {
  func testGeneratingSQLiteDB() throws {
    NSLog("// Start loading from: \(packageRootPath)")
    let testInstance: HotenkaChineseConverter = .init(dictDir: testDataPath)
    NSLog("// Loading complete. Generating SQLite database.")
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

    assert(sqlite3_exec(ptrSQL, "begin;", nil, nil, nil) == SQLITE_OK)

    testInstance.dict.forEach { dictName, subDict in
      guard let dictID = DictType.match(rawKeyString: dictName)?.rawValue else { return }
      subDict.forEach { key, value in
        var ptrStatement: OpaquePointer?
        let sqlInsertion =
          "INSERT INTO DATA_HOTENKA (dict, theKey, theValue) VALUES (\(dictID), '\(key)', '\(value)')"
        assert(
          sqlite3_prepare_v2(
            ptrSQL, sqlInsertion, -1, &ptrStatement, nil
          ) == SQLITE_OK,
          "HOTENKA: Failed from preparing: \(sqlInsertion)"
        )
        assert(
          sqlite3_step(ptrStatement) == SQLITE_DONE,
          "HOTENKA: Failed from stepping: \(sqlInsertion)"
        )
        sqlite3_finalize(ptrStatement)
        ptrStatement = nil
      }
    }
    assert(sqlite3_exec(ptrSQL, "commit;", nil, nil, nil) == SQLITE_OK)
    sqlite3_close_v2(ptrSQL)
  }

  func testSampleWithSQLiteDB() throws {
    NSLog("// Start loading plist from: \(packageRootPath)")
    let testInstance2: HotenkaChineseConverter = .init(sqliteDir: testDataPath + "convdict.sqlite")
    NSLog("// Successfully loading sql dictionary.")

    let oriString = "为中华崛起而读书"
    let result1 = testInstance2.convert(oriString, to: .zhHantTW)
    let result2 = testInstance2.convert(result1, to: .zhHantKX)
    let result3 = testInstance2.convert(result2, to: .zhHansJP)
    NSLog("// Results: \(result1) \(result2) \(result3)")
    XCTAssertEqual(result1, "為中華崛起而讀書")
    XCTAssertEqual(result2, "爲中華崛起而讀書")
    XCTAssertEqual(result3, "為中華崛起而読書")
  }
}
