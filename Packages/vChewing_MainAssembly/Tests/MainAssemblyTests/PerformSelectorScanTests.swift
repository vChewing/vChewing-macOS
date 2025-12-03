// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

/// The following test suite is not executable in Xcode since it is incompatible
/// with Xcode Unit Test Sandbox.
final class PerformSelectorScanTests: XCTestCase {
  func testPerformSelectorNotUsedOutsideSubmodules() throws {
    // This test performs repo-wide file system scanning which is incompatible with
    // Xcode's Unit Test sandbox. We skip when the test is run under Xcode.
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // Walk repo root to ensure there are no 'performSelector(' usages in non-submodule code.
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
    guard let repoRoot = root else { XCTFail("Repository root not found."); return }

    let fm = FileManager.default
    let enumerator = fm.enumerator(at: repoRoot, includingPropertiesForKeys: nil)!
    var matches: [String] = []
    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      // Ignore test files and test helpers under any Tests directories;
      // they may include the literal string "performSelector(" for test purposes.
      if path.contains("/Tests/") { continue }
      if path.contains("/Source/Data/") { continue } // submodule allowed
      if path.hasSuffix(".swift") {
        guard let content = try? String(contentsOf: node, encoding: .utf8) else { continue }
        if content.contains("performSelector(onMainThread:") || content.contains("performSelector(") {
          matches.append(path)
        }
      }
    }
    XCTAssertTrue(matches.isEmpty, "performSelector usage should be removed in non-submodule code; found: \(matches)")
  }
}
