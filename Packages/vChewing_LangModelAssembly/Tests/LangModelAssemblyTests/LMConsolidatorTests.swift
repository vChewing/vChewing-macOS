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

// MARK: - LMConsolidatorConsolidateTests

@Suite(.serialized)
struct LMConsolidatorConsolidateTests {
  // MARK: Internal

  @Test("[LMAssembly] ConsolidateText_PragmaIntactSkips")
  func testConsolidateTextPragmaIntactSkips() {
    // pragma: true 且標頭完好時直接略過整理（pragma 判定修正後的行為）。
    for content in [
      "\(header)\nfoo bar\n",
      "\(header)\r\nfoo\r\n",
      header, // 僅標頭、無尾端斷行（EOF 視為通過）。
    ] {
      var text = content
      LMAssembly.LMConsolidator.consolidate(text: &text, pragma: true)
      #expect(text == content)
    }
  }

  @Test("[LMAssembly] ConsolidateText_NormalizeWhenHeaderMissing")
  func testConsolidateTextNormalizeWhenHeaderMissing() {
    var text = "foo bar\n"
    LMAssembly.LMConsolidator.consolidate(text: &text, pragma: true)
    #expect(text == "\(header)\nfoo bar\n")
  }

  @Test("[LMAssembly] ConsolidateText_WhitespaceCollapse")
  func testConsolidateTextWhitespaceCollapse() {
    // 連續 ASCII 空格／Tab／NBSP／全形空格收斂為單一 ASCII 空格。
    var text = "foo  bar\t baz\u{00A0}\u{00A0}qux\u{3000}\u{3000}zap"
    LMAssembly.LMConsolidator.consolidate(text: &text, pragma: false)
    #expect(text == "\(header)\nfoo bar baz qux zap\n")
  }

  @Test("[LMAssembly] ConsolidateText_LineEdgeSpaces")
  func testConsolidateTextLineEdgeSpaces() {
    // 行首行尾空格（含檔案首尾）剝除；CRLF／CR／FF 收斂為 LF。
    var text = "  foo  \n  bar  "
    LMAssembly.LMConsolidator.consolidate(text: &text, pragma: false)
    #expect(text == "\(header)\nfoo\nbar\n")
  }

  @Test("[LMAssembly] ConsolidateText_NewlineClass")
  func testConsolidateTextNewlineClass() {
    // CRLF／CR／FF 收斂為 LF；VT 是行錨（剝除鄰近空格）但不會被收斂。
    var a = "a\r\nb\rc\u{000C}d\u{000B}e\n"
    LMAssembly.LMConsolidator.consolidate(text: &a, pragma: false)
    #expect(a == "\(header)\na\nb\nc\nd\u{000B}e\n")

    // FF 同時是行錨與可收斂字元。
    var b = "a \u{000C} b"
    LMAssembly.LMConsolidator.consolidate(text: &b, pragma: false)
    #expect(b == "\(header)\na\nb\n")

    // VT 是行錨但留在行內。
    var c = "a \u{000B} b"
    LMAssembly.LMConsolidator.consolidate(text: &c, pragma: false)
    #expect(c == "\(header)\na\u{000B}b\n")

    // LS 是行錨（剝除鄰近空格）但留在行內。
    var d = "a\u{2028} b\n"
    LMAssembly.LMConsolidator.consolidate(text: &d, pragma: false)
    #expect(d == "\(header)\na\u{2028}b\n")

    // 斷行前的空格剝除。
    var e = "x \r\ny\n"
    LMAssembly.LMConsolidator.consolidate(text: &e, pragma: false)
    #expect(e == "\(header)\nx\ny\n")
  }

  @Test("[LMAssembly] ConsolidateText_Deduplication")
  func testConsolidateTextDeduplication() {
    // 去重複以「保留最後一次出現」為準（不破壞最新的 override 資訊）。
    var text = "a\nb\na\n"
    LMAssembly.LMConsolidator.consolidate(text: &text, pragma: false)
    #expect(text == "\(header)\nb\na\n")
  }

  @Test("[LMAssembly] ConsolidateText_HeaderLineRemoval")
  func testConsolidateTextHeaderLineRemoval() {
    // 內容中恰等於 pragma 標頭的列會被移除，並於檔首補回一次。
    var a = "foo\n\(header)\nbar\n"
    LMAssembly.LMConsolidator.consolidate(text: &a, pragma: false)
    #expect(a == "\(header)\nfoo\nbar\n")

    // 標頭列位於檔尾且無尾端斷行。
    var b = "foo\n\(header)"
    LMAssembly.LMConsolidator.consolidate(text: &b, pragma: false)
    #expect(b == "\(header)\nfoo\n")

    // 重複標頭列僅保留檔首一份。
    var c = "\(header)\n\(header)\n"
    LMAssembly.LMConsolidator.consolidate(text: &c, pragma: false)
    #expect(c == "\(header)\n\n")

    // 空內容（沿用既有行為：補回標頭後帶尾端斷行）。
    var d = ""
    LMAssembly.LMConsolidator.consolidate(text: &d, pragma: false)
    #expect(d == "\(header)\n\n")
  }

  @Test("[LMAssembly] ConsolidatePath_Basic")
  func testConsolidatePathBasic() {
    Self.withTempFile(contents: "foo  bar\n") { path in
      #expect(LMAssembly.LMConsolidator.consolidate(path: path, pragma: false))
      let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
      #expect(String(decoding: data, as: UTF8.self) == "\(header)\nfoo bar\n")
    }
  }

  @Test("[LMAssembly] ConsolidatePath_PragmaIntactSkips")
  func testConsolidatePathPragmaIntactSkips() {
    let content = "\(header)\nfoo\n"
    Self.withTempFile(contents: content) { path in
      #expect(LMAssembly.LMConsolidator.consolidate(path: path, pragma: true))
      let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
      #expect(String(decoding: data, as: UTF8.self) == content)
    }
  }

  @Test("[LMAssembly] ConsolidatePath_PreservesInvalidUTF8")
  func testConsolidatePathPreservesInvalidUTF8() {
    // Data 直讀直寫：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD 後永久損毀）。
    let invalid: [UInt8] = Array("foo\n".utf8) + [0xFF, 0xFE] + Array("\nbar\n".utf8)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try? Data(invalid).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }
    #expect(LMAssembly.LMConsolidator.consolidate(path: tempURL.path, pragma: false))
    let result = (try? Data(contentsOf: tempURL)) ?? Data()
    #expect(Array(result) == Array("\(header)\nfoo\n".utf8) + [0xFF, 0xFE] + Array("\nbar\n".utf8))
  }

  // MARK: Private

  private let header = LMAssembly.LMConsolidator.kPragmaHeader

  /// 將給定字串寫入暫存檔，並以該路徑執行給定檢查。
  private static func withTempFile(
    contents: String,
    _ check: (String) -> ()
  ) {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    do {
      try contents.write(to: tempURL, atomically: false, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: tempURL) }
      check(tempURL.path)
    } catch {
      Issue.record("Failed to prepare temp file: \(error)")
    }
  }
}
