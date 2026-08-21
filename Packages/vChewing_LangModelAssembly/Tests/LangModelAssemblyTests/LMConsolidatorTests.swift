// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import LangModelAssembly

// MARK: - LMConsolidatorTests

@Suite(.serialized)
struct LMConsolidatorTests {
  // MARK: Internal

  @Test("[LMAssembly] CheckPragma_ValidHeaders")
  func testCheckPragmaValidHeaders() async throws {
    let header = LMAssembly.LMConsolidator.kPragmaHeader
    // LF 斷行。
    #expect(Self.withTempFile(contents: "\(header)\ncontent\n") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // CRLF 斷行。
    #expect(Self.withTempFile(contents: "\(header)\r\ncontent\r\n") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 僅有標頭、無尾端斷行（EOF 視為通過）。
    #expect(Self.withTempFile(contents: header) {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
  }

  @Test("[LMAssembly] CheckPragma_InvalidHeaders")
  func testCheckPragmaInvalidHeaders() async throws {
    let header = LMAssembly.LMConsolidator.kPragmaHeader
    // 標頭同行尚有其他內容（其後非斷行）。
    #expect(!Self.withTempFile(contents: "\(header) extra\n") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 標頭前有其他內容。
    #expect(!Self.withTempFile(contents: "x\(header)\n") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 檔案比標頭短。
    #expect(!Self.withTempFile(contents: String(header.prefix(8))) {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 空檔案。
    #expect(!Self.withTempFile(contents: "") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 無標頭的一般檔案。
    #expect(!Self.withTempFile(contents: "測試 ㄘㄜˋㄕˋ\n") {
      LMAssembly.LMConsolidator.checkPragma(path: $0)
    })
    // 檔案不存在。
    #expect(!LMAssembly.LMConsolidator.checkPragma(
      path: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    ))
  }

  // MARK: Private

  /// 將給定字串寫入暫存檔，並以該路徑執行給定檢查。
  private static func withTempFile(
    contents: String,
    _ check: (String) -> Bool
  )
    -> Bool {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    do {
      try contents.write(to: tempURL, atomically: false, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: tempURL) }
      return check(tempURL.path)
    } catch {
      Issue.record("Failed to prepare temp file: \(error)")
      return false
    }
  }
}
