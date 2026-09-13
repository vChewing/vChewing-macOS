// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

@testable import Shared
@testable import Shared_DarwinImpl
import Testing

/// PrefMgr().dumpShellScriptBackup()
@Test
func testDumpedPrefs() async throws {
  let prefs = PrefMgr.sharedSansDidSetOps
  let fetched = prefs.dumpShellScriptBackup() ?? ""
  #expect(!fetched.isEmpty)
}
