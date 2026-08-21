// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import LangModelAssembly

private let sampleData: String = #"""
# 語彙置換表測試資料。
芙寧娜 芙黎娜
希諾寧 希洛寧
艾絲妲 阿絲妲

"""#

// MARK: - LMReplacementsTests

@Suite(.serialized)
struct LMReplacementsTests {
  @Test
  func testBasicQueryAndMetadata() throws {
    var lmTest = LMAssembly.LMReplacements()
    #expect(!lmTest.isLoaded)
    lmTest.replaceData(textData: sampleData)
    #expect(lmTest.isLoaded)
    #expect(lmTest.count == 3)
    #expect(lmTest.valuesFor(key: "芙寧娜") == "芙黎娜")
    #expect(lmTest.valuesFor(key: "艾絲妲") == "阿絲妲")
    #expect(lmTest.valuesFor(key: "芭芭拉").isEmpty)
    #expect(lmTest.hasValuesFor(key: "希諾寧"))
    #expect(!lmTest.hasValuesFor(key: "芭芭拉"))
    // strData computed 屬性與載入原文一致（保護外部唯讀消費端）。
    #expect(lmTest.strData == sampleData)
  }

  @Test
  func testDuplicateKeyLastLineWins() throws {
    var lmTest = LMAssembly.LMReplacements()
    lmTest.replaceData(textData: "台 臺\n台 檯\n")
    #expect(lmTest.count == 1)
    #expect(lmTest.valuesFor(key: "台") == "檯")
    // dictRepresented 記錄的是整行內容。
    #expect(lmTest.dictRepresented["台"] == "台 檯")
  }

  @Test
  func testCommentAndMalformedLinesSkipped() throws {
    var lmTest = LMAssembly.LMReplacements()
    lmTest.replaceData(textData: "# 註解行 內容\n獨行無值\n甲 乙\n")
    #expect(lmTest.count == 1)
    #expect(!lmTest.hasValuesFor(key: "#"))
    #expect(!lmTest.hasValuesFor(key: "獨行無值"))
    #expect(lmTest.valuesFor(key: "甲") == "乙")
  }

  @Test
  func testConsecutiveSeparatorsAndMissingTrailingNewline() throws {
    var lmTest = LMAssembly.LMReplacements()
    // 連續分隔符不產生空 cell（dense 索引）；最後一行無換行仍會載入。
    lmTest.replaceData(textData: "甲  乙\n丙 丁")
    #expect(lmTest.count == 2)
    #expect(lmTest.valuesFor(key: "甲") == "乙")
    #expect(lmTest.valuesFor(key: "丙") == "丁")
  }

  @Test
  func testClearAndRepeatedReplaceData() throws {
    var lmTest = LMAssembly.LMReplacements()
    lmTest.replaceData(textData: sampleData)
    // 相同內容重複餵入不應重建（提前返回），也不應出錯。
    lmTest.replaceData(textData: sampleData)
    #expect(lmTest.count == 3)
    lmTest.clear()
    #expect(!lmTest.isLoaded)
    #expect(lmTest.count < 1)
    #expect(lmTest.strData.isEmpty)
    #expect(lmTest.valuesFor(key: "芙寧娜").isEmpty)
  }

  @Test
  func testSaveDataRoundTrip() throws {
    var lmTest = LMAssembly.LMReplacements()
    lmTest.replaceData(textData: sampleData)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_replacements_\(UUID().uuidString).txt")
    lmTest.filePath = tempURL.path
    lmTest.saveData()
    let saved = try String(contentsOf: tempURL, encoding: .utf8)
    #expect(saved == sampleData)
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testOpenSaveRoundTripPreservesInvalidUTF8() throws {
    // open → saveData 全程以位元組進行：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
    let header = LMAssembly.LMConsolidator.kPragmaHeader
    let bytes: [UInt8] = Array("\(header)\nfoo 測試\n".utf8) + [0xFF, 0xFE] + Array("\nbar\n".utf8)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_replacements_invalid_\(UUID().uuidString).txt")
    try Data(bytes).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var lmTest = LMAssembly.LMReplacements()
    let opened = lmTest.open(tempURL.path)
    #expect(opened)
    lmTest.saveData()
    let saved = try Data(contentsOf: tempURL)
    #expect(Array(saved) == bytes)
  }
}
