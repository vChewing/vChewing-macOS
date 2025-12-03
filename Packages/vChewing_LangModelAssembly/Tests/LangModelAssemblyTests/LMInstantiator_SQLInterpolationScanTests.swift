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
final class LMInstantiatorSQLInterpolationScanTests: XCTestCase {
  func testNoSQLStringInterpolationAcrossRepo() throws {
    // 此測試執行全 repo 檔案系統掃描，與 Xcode 單元測試沙箱不相容。
    // 在 Xcode 中執行時跳過此測試。
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // 掃描所有 .swift 檔案（排除 Source/Data）並回報疑似的 SQL 字串插值。
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

    let primaryKeywords = ["SELECT", "INSERT", "DELETE", "UPDATE", "DROP"]
    let secondaryKeywords = ["WHERE", "FROM"]
    let fm = FileManager.default
    // 限制掃描範圍至 package 原始檔案以減少誤報。
    let packagesRoot = repoRoot.appendingPathComponent("Packages")
    let enumerator = fm.enumerator(at: packagesRoot, includingPropertiesForKeys: nil)!
    var findings: [String] = []
    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      // 排除 submodule、建置／衍生原始碼、腳本與 DevLab
      if path.contains("/Source/Data/") { continue }
      if path.contains("/.build/") { continue }
      if path.contains("/Scripts/") { continue }
      if path.contains("/DevLab/") { continue }
      if path.hasSuffix(".swift") {
        // 跳過測試檔案與建置產物，避免掃描測試用 SQL 字串或衍生程式碼。
        if path.contains("/Tests/") || path.contains("/.build/") { continue }
        guard let content = try? String(contentsOf: node, encoding: .utf8) else { continue }
        // 僅掃描包含 Swift 字串插值（"\( ... )"）的行。
        if content.contains("\\(") {
          let lines = content.split(separator: "\n")
          for (idx, line) in lines.enumerated() {
            let str = String(line)
            // 在行中尋找加引號的子字串（簡易方法：定位成對的雙引號）。
            var searchStart = str.startIndex
            let quote: Character = "\""
            while let openQuote = str[searchStart...].firstIndex(of: quote) {
              let afterOpen = str.index(after: openQuote)
              guard let closeQuote = str[afterOpen...].firstIndex(of: quote) else { break }
              let quoted = String(str[afterOpen ..< closeQuote])
              // 檢查加引號字串內的插值與 SQL 關鍵字。
              if quoted.contains("\\(") {
                let upperQuoted = quoted.uppercased()
                // 僅在存在主要 SQL 起始關鍵字時標記；這可避免誤匹配日誌中的一般 'from' 或 'where'。
                let hasPrimary = primaryKeywords.contains { kw in
                  upperQuoted.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil
                }
                if hasPrimary {
                  findings.append("\(path):\(idx + 1): \(str.trimmingCharacters(in: .whitespaces))")
                } else {
                  // 若未找到主要關鍵字，但存在 WHERE/FROM 等次要關鍵字，僅在加引號字串
                  // 包含典型 SQL 標點符號（如逗號、括號、分號）時視為可疑，以減少誤報。
                  let hasSecondary = secondaryKeywords.contains { kw in
                    upperQuoted.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil
                  }
                  if hasSecondary {
                    let punctuationSet = CharacterSet(charactersIn: ",();")
                    if quoted.rangeOfCharacter(from: punctuationSet) != nil {
                      findings.append("\(path):\(idx + 1): \(str.trimmingCharacters(in: .whitespaces))")
                    }
                  }
                }
              }
              // 排除常見的日誌行或已知安全模式以減少誤報
              if str.contains("consoleLog(\"") || str.contains("vCLMLog(\"") || str.contains("Process.consoleLog(\"") {
                // 移除最近衍生的發現，若它是來自日誌的誤報
                if !findings.isEmpty { findings.removeLast() }
              }
              // 允許 LMInstantiator_SQLExtension 內已知的安全慣用語法（基於模式）
              if path.hasSuffix("LMInstantiator_SQLExtension.swift"),
                 str.contains("SELECT EXISTS") || str.contains("column.name) IS NOT NULL") {
                if !findings.isEmpty { findings.removeLast() }
              }
              searchStart = str.index(after: closeQuote)
            }
          }
        }
      }
    }
    // 若發現明顯實例則測試失敗。可能存在某些誤報；將此作為
    // 輕量級靜態檢查以捕捉意外的 SQL 插值。
    XCTAssertTrue(
      findings.isEmpty,
      "Found potential SQL string interpolation occurrences: \(findings)\nPlease review and use prepared statements instead."
    )
  }
}
