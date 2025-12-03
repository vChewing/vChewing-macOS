// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

/// 以下測試套件無法在 Xcode 中執行，因為與 Xcode 單元測試沙箱機制不相容。
final class PerformSelectorScanTests: XCTestCase {
  func testPerformSelectorNotUsedOutsideSubmodules() throws {
    // 此測試執行全 repo 檔案系統掃描，與 Xcode 單元測試沙箱不相容。
    // 在 Xcode 中執行時跳過此測試。
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // 遍歷 repo 根目錄，確保在 non-submodule 程式碼中沒有使用 'performSelector(' 語句。
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
      // 忽略 Tests 目錄下的測試檔案與測試輔助工具；
      // 它們可能包含字面字串 "performSelector(" 用於測試目的。
      if path.contains("/Tests/") { continue }
      if path.contains("/Source/Data/") { continue } // submodule 允許使用
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
