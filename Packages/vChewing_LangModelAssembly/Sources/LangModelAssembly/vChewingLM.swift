// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import SQLite3

public enum vChewingLM {
  enum FileErrors: Error {
    case fileHandleError(String)
  }

  public enum ReplacableUserDataType: String, CaseIterable, Identifiable {
    public var id: ObjectIdentifier { .init(rawValue as AnyObject) }
    public var localizedDescription: String { NSLocalizedString(rawValue, comment: "") }

    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols
  }
}

// MARK: - String as SQL Command

extension String {
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

extension Array where Element == String {
  @discardableResult func runAsSQLPreparedSteps(dbPointer ptrDB: inout OpaquePointer?) -> Bool {
    guard ptrDB != nil else { return false }
    guard "begin;".runAsSQLExec(dbPointer: &ptrDB) else { return false }
    defer {
      let looseEnds = sqlite3_exec(ptrDB, "commit;", nil, nil, nil) == SQLITE_OK
      assert(looseEnds)
    }

    for strStmt in self {
      let thisResult = performStatement { ptrStmt in
        sqlite3_prepare_v2(ptrDB, strStmt, -1, &ptrStmt, nil) == SQLITE_OK && sqlite3_step(ptrStmt) == SQLITE_DONE
      }
      guard thisResult else {
        vCLog("SQL Query Error. Statement: \(strStmt)")
        return false
      }
    }
    return true
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
