// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import LexiconAssembly

private let sampleData: String = #"""
# 語彙置換表測試資料。
芙寧娜 芙黎娜
希諾寧 希洛寧
艾絲妲 阿絲妲

"""#

// MARK: - LXReplacementsTests

@Suite(.serialized)
struct LXReplacementsTests {
  @Test
  func testBasicQueryAndMetadata() throws {
    var lxTest = LXAssembly.LXReplacements()
    #expect(!lxTest.isLoaded)
    lxTest.replaceData(textData: sampleData)
    #expect(lxTest.isLoaded)
    #expect(lxTest.count == 3)
    #expect(lxTest.valuesFor(key: "芙寧娜") == "芙黎娜")
    #expect(lxTest.valuesFor(key: "艾絲妲") == "阿絲妲")
    #expect(lxTest.valuesFor(key: "芭芭拉").isEmpty)
    #expect(lxTest.hasValuesFor(key: "希諾寧"))
    #expect(!lxTest.hasValuesFor(key: "芭芭拉"))
    // strData computed 屬性與載入原文一致（保護外部唯讀消費端）。
    #expect(lxTest.strData == sampleData)
  }

  @Test
  func testDuplicateKeyLastLineWins() throws {
    var lxTest = LXAssembly.LXReplacements()
    lxTest.replaceData(textData: "台 臺\n台 檯\n")
    #expect(lxTest.count == 1)
    #expect(lxTest.valuesFor(key: "台") == "檯")
    // dictRepresented 記錄的是整行內容。
    #expect(lxTest.dictRepresented["台"] == "台 檯")
  }

  @Test
  func testCommentAndMalformedLinesSkipped() throws {
    var lxTest = LXAssembly.LXReplacements()
    lxTest.replaceData(textData: "# 註解行 內容\n獨行無值\n甲 乙\n")
    #expect(lxTest.count == 1)
    #expect(!lxTest.hasValuesFor(key: "#"))
    #expect(!lxTest.hasValuesFor(key: "獨行無值"))
    #expect(lxTest.valuesFor(key: "甲") == "乙")
  }

  @Test
  func testConsecutiveSeparatorsAndMissingTrailingNewline() throws {
    var lxTest = LXAssembly.LXReplacements()
    // 連續分隔符不產生空 cell（dense 索引）；最後一行無換行仍會載入。
    lxTest.replaceData(textData: "甲  乙\n丙 丁")
    #expect(lxTest.count == 2)
    #expect(lxTest.valuesFor(key: "甲") == "乙")
    #expect(lxTest.valuesFor(key: "丙") == "丁")
  }

  @Test
  func testClearAndRepeatedReplaceData() throws {
    var lxTest = LXAssembly.LXReplacements()
    lxTest.replaceData(textData: sampleData)
    // 相同內容重複餵入不應重建（提前返回），也不應出錯。
    lxTest.replaceData(textData: sampleData)
    #expect(lxTest.count == 3)
    lxTest.clear()
    #expect(!lxTest.isLoaded)
    #expect(lxTest.count < 1)
    #expect(lxTest.strData.isEmpty)
    #expect(lxTest.valuesFor(key: "芙寧娜").isEmpty)
  }

  @Test
  func testSaveDataRoundTrip() throws {
    var lxTest = LXAssembly.LXReplacements()
    lxTest.replaceData(textData: sampleData)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_replacements_\(UUID().uuidString).txt")
    lxTest.filePath = tempURL.path
    lxTest.saveData()
    let saved = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(saved == sampleData)
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testOpenSaveRoundTripPreservesInvalidUTF8() throws {
    // open → saveData 全程以位元組進行：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
    let header = LXAssembly.LXConsolidator.kPragmaHeader
    let bytes: [UInt8] = Array("\(header)\nfoo 測試\n".utf8) + [0xFF, 0xFE] + Array("\nbar\n".utf8)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_replacements_invalid_\(UUID().uuidString).txt")
    try Data(bytes).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var lxTest = LXAssembly.LXReplacements()
    let opened = lxTest.open(tempURL.path)
    #expect(opened)
    lxTest.saveData()
    let saved = try Data(contentsOf: tempURL)
    #expect(Array(saved) == bytes)
  }
}
