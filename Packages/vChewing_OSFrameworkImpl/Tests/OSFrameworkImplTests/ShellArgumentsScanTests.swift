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
final class ShellArgumentsScanTests: XCTestCase {
  func testNoUnsafeShellArgumentUsagesOutsideAllowedFiles() throws {
    // This test uses file system access and scanning which doesn't work under
    // Xcode Unit Test sandbox. Skip when running inside Xcode.
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // Determine repository root by walking upwards from current dir until vChewing.xcodeproj exists.
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
    // Allowed paths: only scripts are allowed to use -lc/-c style for dev/admin scripts.
    let allowedPaths = [
      "Scripts/vchewing-update.swift",
    ]

    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      if path.hasSuffix(".swift") || path.hasSuffix(".sh") {
        // Skip the Source/Data submodule content; it is allowed to contain dev tools
        // and scripts which may intentionally use '-c' style invocations.
        if path.contains("/Source/Data/") { continue }
        // Skip paths in Source/Data (submodule) and any paths explicitly whitelisted
        if allowedPaths.contains(where: { path.contains($0) }) { continue }

        // Read file content
        guard let content = try? String(contentsOf: node, encoding: .utf8) else { continue }
        if content.contains("task.arguments = [\"-c\"") || content.contains("task.arguments = [\"-lc\"") {
          matches.append(path)
        }
      }
    }
    XCTAssertTrue(
      matches.isEmpty,
      "Found -c/-lc style shell arguments in unexpected files: \(matches)\nAllowed paths: \(allowedPaths)"
    )
  }
}
