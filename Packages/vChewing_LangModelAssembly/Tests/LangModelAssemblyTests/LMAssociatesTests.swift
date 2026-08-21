// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import Testing

@testable import LangModelAssembly

private let sampleData: String = #"""
# 關聯詞語測試資料
芳 苑 鄰 香
芳 芳香 苑
(fang,芳) 苑 鄰
草 華 蹤 # 後續不錄
孤行無值
"""#

// MARK: - LMAssociatesTests

@Suite(.serialized)
struct LMAssociatesTests {
  // MARK: Internal

  @Test
  func testBasicDualKeyQuery() throws {
    let lmTest = makeLoadedLM()
    #expect(lmTest.isLoaded)
    // 唯一 key：芳、(fang,芳)、草；註解行與無值行不建 entry。
    // 註：純英數 pinyin（如 fang）不會被 cnvNGramKeyFromPinyinToPhona 轉換，key 原樣保留。
    #expect(lmTest.count == 3)
    let pair = Homa.CandidatePair(keyArray: ["ㄈㄤ"], value: "芳")
    #expect(lmTest.hasValuesFor(pair: pair))
    // toNGramKey「(ㄈㄤ,芳)」查無、改由「芳」命中：依行序列出後 dedup。
    #expect(lmTest.valuesFor(pair: pair) == ["苑", "鄰", "香", "芳香"])
    // 直接以檔案內的 ngram key 查詢。
    let ngramPair = Homa.CandidatePair(keyArray: ["fang"], value: "芳")
    #expect(lmTest.valuesFor(pair: ngramPair) == ["苑", "鄰", "香", "芳香"])
    #expect(lmTest.hasValuesFor(pair: .init(keyArray: [], value: "(fang,芳)")))
  }

  @Test
  func testHashCellStopsRecordingSubsequentCells() throws {
    let lmTest = makeLoadedLM()
    let pair = Homa.CandidatePair(keyArray: ["ㄘㄠ"], value: "草")
    let values = lmTest.valuesFor(pair: pair)
    #expect(values == ["華", "蹤"])
    #expect(!values.contains("後續不錄"))
    #expect(!values.contains("#"))
  }

  @Test
  func testCommentAndMalformedLinesSkipped() throws {
    let lmTest = makeLoadedLM()
    #expect(!lmTest.hasValuesFor(pair: .init(keyArray: [], value: "#")))
    #expect(!lmTest.hasValuesFor(pair: .init(keyArray: [], value: "關聯詞語測試資料")))
    #expect(!lmTest.hasValuesFor(pair: .init(keyArray: [], value: "孤行無值")))
    #expect(!lmTest.hasValuesFor(pair: .init(keyArray: [], value: "不存在的key")))
  }

  @Test
  func testDictRepresentedKeepsRawOrderWithoutDedup() throws {
    let lmTest = makeLoadedLM()
    let dict = lmTest.dictRepresented
    // dictRepresented 不做 dedup（與舊版行為一致）：兩行「芳」依行序全數列出。
    #expect(dict["芳"] == ["苑", "鄰", "香", "芳香", "苑"])
    #expect(dict["(fang,芳)"] == ["苑", "鄰"])
    #expect(dict["草"] == ["華", "蹤"])
  }

  @Test
  func testCnvNGramKeyGuardPassthrough() throws {
    // 不具備括號與逗號結構的 key 原樣返回；純英數 pinyin 不觸發轉換。
    #expect(LMAssembly.LMAssociates.cnvNGramKeyFromPinyinToPhona(target: "芳") == "芳")
    #expect(LMAssembly.LMAssociates.cnvNGramKeyFromPinyinToPhona(target: "(fang,芳)") == "(fang,芳)")
    #expect(LMAssembly.LMAssociates.cnvNGramKeyFromPinyinToPhona(target: "(a,b,c)") == "(a,b,c)")
  }

  @Test
  func testStrDataAndClear() throws {
    var lmTest = makeLoadedLM()
    // strData computed 屬性與載入原文一致（保護外部唯讀消費端）。
    #expect(lmTest.strData == sampleData)
    lmTest.clear()
    #expect(!lmTest.isLoaded)
    #expect(lmTest.count < 1)
    #expect(lmTest.strData.isEmpty)
    #expect(!lmTest.hasValuesFor(pair: .init(keyArray: ["ㄈㄤ"], value: "芳")))
  }

  @Test
  func testSaveDataRoundTrip() throws {
    var lmTest = makeLoadedLM()
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_associates_\(UUID().uuidString).txt")
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
      .appendingPathComponent("vChewingTest_associates_invalid_\(UUID().uuidString).txt")
    try Data(bytes).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var lmTest = LMAssembly.LMAssociates()
    let opened = lmTest.open(tempURL.path)
    #expect(opened)
    lmTest.saveData()
    let saved = try Data(contentsOf: tempURL)
    #expect(Array(saved) == bytes)
  }

  // MARK: Private

  private func makeLoadedLM() -> LMAssembly.LMAssociates {
    var lmTest = LMAssembly.LMAssociates()
    lmTest.replaceData(textData: sampleData)
    return lmTest
  }
}
