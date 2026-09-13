// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import BPMFVS
import Foundation
import Testing

@Suite("BPMFVSTests", .serialized)
struct BPMFVSTests {
  @Test
  func testBundledFileAccess() async throws {
    _ = try #require(BPMFVS.getBPMFVSDataURL())
    #expect(BPMFVS.isDataTableLoaded)
  }

  @Test
  func testManualDataURLSpecificationAndFailSafe() throws {
    BPMFVS.specifyDataURL(nil)
    defer { BPMFVS.specifyDataURL(nil) }
    let bundledURL = try #require(BPMFVS.getBPMFVSDataURL())
    BPMFVS.specifyDataURL(bundledURL)
    #expect(BPMFVS.getBPMFVSDataURL() == bundledURL)
    #expect(BPMFVS.isDataTableLoaded)
    // 指定一個不可讀的位置時，查找落空、轉換退回原樣輸出。
    BPMFVS.specifyDataURL(URL(fileURLWithPath: "/nonexistent-vChewing/phonic_table_Z.txt"))
    #expect(BPMFVS.getBPMFVSDataURL() != bundledURL)
    #expect(!BPMFVS.isDataTableLoaded)
    let vs1 = String(try #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄚˊ") == "咱")
    // 清除指定之後，預設查找重新接手。
    BPMFVS.specifyDataURL(nil)
    #expect(BPMFVS.isDataTableLoaded)
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄚˊ") == "咱\(vs1)")
  }

  @Test
  func testKeepsPrimaryReadingUntouched() {
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄢˊ") == "咱")
  }

  @Test
  func testAddsVariationSelectorForNonPrimaryReading() {
    let expected = "咱" + String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄚˊ") == expected)
  }

  @Test
  func testNormalizesTrailingNeutralToneMarker() {
    let expected = "地" + String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "地", reading: "ㄉㄜ˙") == expected)
  }

  @Test
  func testConvertsMultiCharacterDisplaySegment() {
    let vs1 = String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "咱地", readings: ["ㄗㄚˊ", "ㄉㄜ˙"]) == "咱\(vs1)地\(vs1)")
  }

  @Test
  func testLeavesMultiCharacterDisplaySegmentUntouchedWhenCountsMismatch() {
    #expect(BPMFVS.convert(value: "咱地", readings: ["ㄗㄚˊ"]) == "咱地")
  }
}
