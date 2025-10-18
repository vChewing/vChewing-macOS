// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

@testable import Shared
@testable import Shared_DarwinImpl
import XCTest

final class SharedDarwinImplTests: XCTestCase {
  /// PrefMgr().dumpShellScriptBackup()
  func testDumpedPrefs() throws {
    let prefs = PrefMgr()
    let fetched = prefs.dumpShellScriptBackup() ?? ""
    XCTAssertFalse(fetched.isEmpty)
  }
}
