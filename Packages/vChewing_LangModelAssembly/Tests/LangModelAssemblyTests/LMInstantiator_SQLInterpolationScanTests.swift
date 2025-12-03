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
final class LMInstantiatorSQLInterpolationScanTests: XCTestCase {
  func testNoSQLStringInterpolationAcrossRepo() throws {
    // This test performs repo-wide file system scanning which is incompatible with
    // Xcode's Unit Test sandbox. We skip when the test is run under Xcode.
    let env = ProcessInfo.processInfo.environment
    try XCTSkipIf(
      env["XCTestConfigurationFilePath"] != nil || env["XCODE_VERSION_ACTUAL"] != nil || env["XCODE_VERSION_MAJOR"] !=
        nil,
      "Skipping test under Xcode due to Unit Test sandbox restrictions"
    )
    // Scan all .swift files (excluding Source/Data) and report suspected SQL string interpolations.
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
    // Limit the scan to package source files to reduce false positives
    let packagesRoot = repoRoot.appendingPathComponent("Packages")
    let enumerator = fm.enumerator(at: packagesRoot, includingPropertiesForKeys: nil)!
    var findings: [String] = []
    while let node = enumerator.nextObject() as? URL {
      let path = node.path
      // Exclude submodule, build/derived sources, scripts, and DevLab
      if path.contains("/Source/Data/") { continue }
      if path.contains("/.build/") { continue }
      if path.contains("/Scripts/") { continue }
      if path.contains("/DevLab/") { continue }
      if path.hasSuffix(".swift") {
        // Skip test files and build artifacts to avoid scanning test SQL strings or derived code.
        if path.contains("/Tests/") || path.contains("/.build/") { continue }
        guard let content = try? String(contentsOf: node, encoding: .utf8) else { continue }
        // Only scan lines which include Swift string interpolation ("\( ... )").
        if content.contains("\\(") {
          let lines = content.split(separator: "\n")
          for (idx, line) in lines.enumerated() {
            let str = String(line)
            // Find quoted substrings in the line (simple approach: locate pairs of double-quotes).
            var searchStart = str.startIndex
            let quote: Character = "\""
            while let openQuote = str[searchStart...].firstIndex(of: quote) {
              let afterOpen = str.index(after: openQuote)
              guard let closeQuote = str[afterOpen...].firstIndex(of: quote) else { break }
              let quoted = String(str[afterOpen ..< closeQuote])
              // Check for interpolation and SQL keywords within the quoted string.
              if quoted.contains("\\(") {
                let upperQuoted = quoted.uppercased()
                // Only flag if a primary SQL starter keyword exists; this avoids matching general 'from' or 'where' in logs.
                let hasPrimary = primaryKeywords.contains { kw in
                  upperQuoted.range(of: "\\b\(kw)\\b", options: .regularExpression) != nil
                }
                if hasPrimary {
                  findings.append("\(path):\(idx + 1): \(str.trimmingCharacters(in: .whitespaces))")
                } else {
                  // If no primary keyword found, but a secondary keyword like WHERE/FROM exists, only consider it suspicious
                  // if the quoted string contains typical SQL punctuation (e.g., commas, parentheses, semicolons), which reduces false positives.
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
              // Exclude common logging lines or known safe patterns to reduce false positives
              if str.contains("consoleLog(\"") || str.contains("vCLMLog(\"") || str.contains("Process.consoleLog(\"") {
                // remove the most recent derived finding if it was a false positive from logging
                if !findings.isEmpty { findings.removeLast() }
              }
              // Allow the known safe idioms within LMInstantiator_SQLExtension (pattern-based)
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
    // We fail the test if there are obvious instances found. Some false positives are possible; use this
    // as a lightweight static check to catch accidental SQL interpolation.
    XCTAssertTrue(
      findings.isEmpty,
      "Found potential SQL string interpolation occurrences: \(findings)\nPlease review and use prepared statements instead."
    )
  }
}
