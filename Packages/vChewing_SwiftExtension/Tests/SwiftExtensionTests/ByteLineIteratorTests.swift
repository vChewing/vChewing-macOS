// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
@testable import SwiftExtension
import Testing

// MARK: - ByteLineIteratorTests

@MainActor
@Suite(.serialized)
struct ByteLineIteratorTests {
  // MARK: Internal

  @Test("[SwiftExtension] ByteLineIterator_LFSeparation")
  func testLFSeparation() async throws {
    let lines = Self.harvestLines(from: Array("alpha\nbeta\ngamma\n".utf8))
    // LF 結尾的檔案不產生尾端空行。
    #expect(lines == ["alpha", "beta", "gamma"])
  }

  @Test("[SwiftExtension] ByteLineIterator_CRLFStripping")
  func testCRLFStripping() async throws {
    let lines = Self.harvestLines(from: Array("alpha\r\nbeta\r\n".utf8))
    #expect(lines == ["alpha", "beta"])
  }

  @Test("[SwiftExtension] ByteLineIterator_MixedEndingsAndUnterminatedLastLine")
  func testMixedEndingsAndUnterminatedLastLine() async throws {
    let lines = Self.harvestLines(from: Array("alpha\r\nbeta\ngamma".utf8))
    #expect(lines == ["alpha", "beta", "gamma"])
  }

  @Test("[SwiftExtension] ByteLineIterator_EmptyFile")
  func testEmptyFile() async throws {
    #expect(Self.harvestLines(from: []).isEmpty)
  }

  @Test("[SwiftExtension] ByteLineIterator_EmptyLinesPreserved")
  func testEmptyLinesPreserved() async throws {
    let lines = Self.harvestLines(from: Array("a\n\nb\n".utf8))
    #expect(lines == ["a", "", "b"])
  }

  @Test("[SwiftExtension] ByteLineIterator_ChunkBoundaries")
  func testChunkBoundaries() async throws {
    // 刻意讓 CR 與 LF 分處相鄰 chunk 邊界兩側，且行橫跨複數 chunk。
    let source = "ab\r\ncdefgh\ni\r\njk"
    let expected = ["ab", "cdefgh", "i", "jk"]
    for chunkSize in 1 ... 5 {
      let lines = Self.harvestLines(from: Array(source.utf8), chunkSize: chunkSize)
      #expect(lines == expected)
    }
    // 多位元組斷行字元（LS、NEL）橫跨 chunk 邊界的情形。
    let multibyteSource = "a\u{2028}bb\u{0085}ccc\r\nd"
    let multibyteExpected = ["a", "bb", "ccc", "d"]
    for chunkSize in 1 ... 6 {
      let lines = Self.harvestLines(from: Array(multibyteSource.utf8), chunkSize: chunkSize)
      #expect(lines == multibyteExpected)
    }
  }

  @Test("[SwiftExtension] ByteLineIterator_ExtendedNewlineDelimiters")
  func testExtendedNewlineDelimiters() async throws {
    // VT / FF / NEL / LS / PS 皆為斷行依據。
    let lines = Self.harvestLines(from: Array("a\u{000B}b\u{000C}c\u{0085}d\u{2028}e\u{2029}f".utf8))
    #expect(lines == ["a", "b", "c", "d", "e", "f"])
  }

  @Test("[SwiftExtension] ByteLineIterator_CRDelimitability")
  func testCRDelimitability() async throws {
    // 古典 Mac 的 CR-only 斷行也會被識別。
    #expect(Self.harvestLines(from: Array("a\rb".utf8)) == ["a", "b"])
    #expect(Self.harvestLines(from: Array("a\r".utf8)) == ["a"])
  }

  @Test("[SwiftExtension] ByteLineIterator_ConsecutiveDelimiters")
  func testConsecutiveDelimiters() async throws {
    // 連續斷行產生空行；CRLF 視為單一斷行、不產生多餘空行。
    let lines = Self.harvestLines(from: Array("x\r\r\ny\n\nz".utf8))
    #expect(lines == ["x", "", "y", "", "z"])
  }

  @Test("[SwiftExtension] ByteLineIterator_IteratorProtocol")
  func testIteratorProtocol() async throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try Data("x\ny".utf8).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }
    let fileHandle = try #require(FileHandle(forReadingAtPath: tempURL.path))
    defer { try? fileHandle.close() }
    let iterator = ByteLineIterator(file: fileHandle, chunkSize: 2)
    #expect(iterator.nextLine().map { String(decoding: $0, as: UTF8.self) } == "x")
    #expect(iterator.nextLine().map { String(decoding: $0, as: UTF8.self) } == "y")
    #expect(iterator.nextLine() == nil)
    // EOF 之後持續回傳 nil。
    #expect(iterator.nextLine() == nil)
  }

  // MARK: Private

  /// 將給定位元組寫入暫存檔、以指定 chunk 大小建立迭代器並收集全部行。
  private static func harvestLines(
    from bytes: [UInt8],
    chunkSize: Int = 4_096
  )
    -> [String] {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    do {
      try Data(bytes).write(to: tempURL)
      defer { try? FileManager.default.removeItem(at: tempURL) }
      guard let fileHandle = FileHandle(forReadingAtPath: tempURL.path) else {
        Issue.record("Failed to open temp file for reading.")
        return []
      }
      defer { try? fileHandle.close() }
      let iterator = ByteLineIterator(file: fileHandle, chunkSize: chunkSize)
      return iterator.map { String(decoding: $0, as: UTF8.self) }
    } catch {
      Issue.record("Failed to prepare temp file: \(error)")
      return []
    }
  }
}
