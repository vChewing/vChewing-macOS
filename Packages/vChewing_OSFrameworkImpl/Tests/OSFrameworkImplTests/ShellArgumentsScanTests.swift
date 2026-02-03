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
final class ShellArgumentsScanTests: XCTestCase {
  func testNoUnsafeShellArgumentUsagesOutsideAllowedFiles() throws {
    // 此測試使用檔案系統存取與掃描功能，在 Xcode 單元測試沙箱下無法運作。
    // 在 Xcode 中執行時跳過此測試。
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // 向上遍歷目錄直到找到 vChewing.xcodeproj，以確定 repository 根目錄位置。
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
    // 允許的路徑：僅限腳本允許使用 -lc/-c 風格的開發／管理腳本。
    let allowedPaths = [
      "Scripts/vchewing-update.swift",
      "Scripts/vchewing-update-lexicon.swift",
    ]

    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      if path.hasSuffix(".swift") || path.hasSuffix(".sh") {
        // 跳過 Source/Data submodule 內容；允許它包含可能刻意使用 '-c' 風格呼叫的
        // 開發工具與腳本。
        if path.contains("/Source/Data/") { continue }
        // 跳過 Source/Data（submodule）中的路徑以及任何明確列入白名單的路徑
        if allowedPaths.contains(where: { path.contains($0) }) { continue }

        // 讀取檔案內容
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
