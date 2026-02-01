// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CSQLite3Lib
import Foundation
import HotenkaTestDictData
import Testing

@testable import Hotenka

extension HotenkaTests {
  @Test
  func testGeneratingSQLiteDB() throws {
    let testInstance: HotenkaChineseConverter = .init(dictDir: testDataPath)
    Hotenka.consoleLog("// Loading complete. Generating SQLite database.")
    var ptrSQL: OpaquePointer?
    let dbPath = testDataPath + "convdict.sqlite"

    #expect(
      sqlite3_open(dbPath, &ptrSQL) == SQLITE_OK,
      "HOTENKA: SQLite Database Initialization Error."
    )
    #expect(
      sqlite3_exec(ptrSQL, "PRAGMA synchronous = OFF;", nil, nil, nil) == SQLITE_OK,
      "HOTENKA: SQLite synchronous OFF failed."
    )
    #expect(
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

    #expect(
      sqlite3_exec(ptrSQL, sqlMakeTableHotenka, nil, nil, nil) == SQLITE_OK,
      "HOTENKA: SQLite Table Creation Failed."
    )

    #expect(sqlite3_exec(ptrSQL, "begin;", nil, nil, nil) == SQLITE_OK)

    testInstance.dict.forEach { dictName, subDict in
      Hotenka.consoleLog("// Debug: inserting dictName=\(dictName) subCount=\(subDict.count)")
      guard let dictID = DictType.match(rawKeyString: dictName)?.rawValue
      else { Hotenka.consoleLog("// Debug: dictName \(dictName) not matched to DictType"); return }
      subDict.forEach { key, value in
        var ptrStatement: OpaquePointer?
        let sqlInsertion = "INSERT INTO DATA_HOTENKA (dict, theKey, theValue) VALUES (?, ?, ?)"
        #expect(
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
        #expect(sqlite3_step(ptrStatement) == SQLITE_DONE, "HOTENKA: Failed from stepping: bound insert")
        sqlite3_finalize(ptrStatement)
        ptrStatement = nil
      }
    }
    #expect(sqlite3_exec(ptrSQL, "commit;", nil, nil, nil) == SQLITE_OK)
    sqlite3_close_v2(ptrSQL)
  }

  @Test
  func testSampleWithSQLiteDB() throws {
    let testInstance2: HotenkaChineseConverter = .init(sqliteDir: testDataPath + "convdict.sqlite")
    Hotenka.consoleLog("// Successfully loading sql dictionary.")

    let oriString = "为中华崛起而读书"
    let result1 = testInstance2.convert(oriString, to: .zhHantTW)
    let result2 = testInstance2.convert(result1, to: .zhHantKX)
    let result3 = testInstance2.convert(result2, to: .zhHansJP)
    Hotenka.consoleLog("// Results: \(result1) \(result2) \(result3)")
    #expect(result1 == "為中華崛起而讀書")
    #expect(result2 == "爲中華崛起而讀書")
    #expect(result3 == "為中華崛起而読書")
  }

  @Test
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
    #expect(sqlite3_open(testDataPath + "convdict.sqlite", &ptrSQL) == SQLITE_OK)
    var ptrStatement: OpaquePointer?
    let sqlIns = "INSERT OR REPLACE INTO DATA_HOTENKA (dict, theKey, theValue) VALUES (0, ?, ?)"
    #expect(sqlite3_prepare_v2(ptrSQL, sqlIns, -1, &ptrStatement, nil) == SQLITE_OK)
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
    #expect(sqlite3_step(ptrStatement) == SQLITE_DONE)
    sqlite3_finalize(ptrStatement)
    // 插入第二個 Key
    #expect(sqlite3_prepare_v2(ptrSQL, sqlIns, -1, &ptrStatement, nil) == SQLITE_OK)
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
    #expect(sqlite3_step(ptrStatement) == SQLITE_DONE)
    sqlite3_finalize(ptrStatement)
    sqlite3_close_v2(ptrSQL)

    // 驗證：一般 key 查詢正確
    let res = testInstance2.query(dict: .zhHantTW, key: normalKey)
    #expect(res == normalVal)

    // 嘗試注入查詢字串
    let malicious = "k2' OR 1=1 --"
    let res2 = testInstance2.query(dict: .zhHantTW, key: malicious)
    // 如果 query 使用 bind statements，res2 應為 nil（無精確 match）
    #expect(res2 == nil)
  }
}
