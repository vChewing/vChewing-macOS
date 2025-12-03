// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CSQLite3
import Foundation
import LMAssemblyMaterials4Tests
import XCTest

@testable import LangModelAssembly

final class LMInstantiatorSQLInjectionTests: XCTestCase {
  func testPreparedStatementsResistSQLInjection() {
    // 建立一筆可用來驗證的樣本資料（包含防呆的 create table）
    let create = "CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL);"
    let insert = "INSERT OR REPLACE INTO DATA_REV (theChar, theReadings) VALUES ('A', 'z');"
    // 使用 connectToTestSQLDB 將 SQLite 初始化與插入語句一次性提交
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB(create + insert))
    XCTAssertNotNil(LMAssembly.LMInstantiator.ptrSQL, "Database pointer should be non-nil after connectToTestSQLDB")

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
      XCTAssertEqual(s, "z")
      dbFound = true
    }
    sqlite3_finalize(ptrStmt)
    XCTAssertTrue(dbFound, "Inserted row should be found in the DB")
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
    XCTAssertTrue(!tables.isEmpty, "sqlite_master tables should exist: \(tables)")
    // Debug: 查詢表筆數與列出內容
    var countStmt: OpaquePointer?
    sqlite3_prepare_v2(LMAssembly.LMInstantiator.ptrSQL, "SELECT COUNT(*) FROM DATA_REV;", -1, &countStmt, nil)
    var cnt = 0
    if sqlite3_step(countStmt) == SQLITE_ROW {
      cnt = Int(sqlite3_column_int(countStmt, 0))
    }
    sqlite3_finalize(countStmt)
    print("DATA_REV count: \(cnt)")
    XCTAssertTrue(cnt >= 1, "DATA_REV should contain at least 1 row after insert")
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
    XCTAssertNotNil(normal)
    XCTAssertTrue(normal!.contains("z") || normal!.contains("ㄗ"))

    // 嘗試注入型 payload; 若程式利用 string interpolation 而非 bind，可能導致 DROP TABLE
    let payload = "A'); DROP TABLE DATA_REV; --"
    // 呼叫被保護的 API 不應該造成表結構變動
    _ = LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: payload)

    // 再次檢查資料是否仍存在
    let afterPayload = LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "A")
    XCTAssertNotNil(afterPayload)
    XCTAssertTrue(afterPayload!.contains("z") || afterPayload!.contains("ㄗ"))

    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  func testHasSQLResultRequiresPlaceholdersWhenParamsGiven() {
    XCTAssertTrue(
      LMAssembly.LMInstantiator
        .connectToTestSQLDB("CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL);")
    )
    // Insert a test row so that the query actually returns a result during the placeholder test.
    XCTAssertTrue(
      LMAssembly.LMInstantiator
        .connectToTestSQLDB(
          "CREATE TABLE IF NOT EXISTS DATA_REV (theChar TEXT NOT NULL, theReadings TEXT NOT NULL); INSERT OR REPLACE INTO DATA_REV (theChar, theReadings) VALUES ('A', 'z');"
        )
    )
    // Proper use: placeholder matches params
    let proper = LMAssembly.LMInstantiator.hasSQLResult(
      strStmt: "SELECT * FROM DATA_REV WHERE theChar = ?",
      params: ["A"]
    )
    XCTAssertFalse(
      proper == false,
      "hasSQLResult should accept queries with matching placeholders and params but returned false"
    )

    // Mismatched: params provided but no placeholders -> should return false
    let mismatch = LMAssembly.LMInstantiator.hasSQLResult(
      strStmt: "SELECT * FROM DATA_REV WHERE theChar = 'A'",
      params: ["A"]
    )
    XCTAssertFalse(mismatch, "hasSQLResult should reject queries with param array but no ? placeholders")
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }
}
