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

@testable import LexiconAssembly

private let sampleData: String = #"""
# 關聯詞語測試資料
芳 苑 鄰 香
芳 芳香 苑
(fang,芳) 苑 鄰
草 華 蹤 # 後續不錄
孤行無值
"""#

// MARK: - LXAssociatesTests

@Suite(.serialized)
struct LXAssociatesTests {
  // MARK: Internal

  @Test
  func testBasicDualKeyQuery() throws {
    let lxTest = makeLoadedLX()
    #expect(lxTest.isLoaded)
    // 唯一 key：芳、(fang,芳)、草；註解行與無值行不建 entry。
    // 註：純英數 pinyin（如 fang）不會被 cnvNGramKeyFromPinyinToPhona 轉換，key 原樣保留。
    #expect(lxTest.count == 3)
    let pair = Homa.CandidatePair(keyArray: ["ㄈㄤ"], value: "芳")
    #expect(lxTest.hasValuesFor(pair: pair))
    // toNGramKey「(ㄈㄤ,芳)」查無、改由「芳」命中：依行序列出後 dedup。
    #expect(lxTest.valuesFor(pair: pair) == ["苑", "鄰", "香", "芳香"])
    // 直接以檔案內的 ngram key 查詢。
    let ngramPair = Homa.CandidatePair(keyArray: ["fang"], value: "芳")
    #expect(lxTest.valuesFor(pair: ngramPair) == ["苑", "鄰", "香", "芳香"])
    #expect(lxTest.hasValuesFor(pair: .init(keyArray: [], value: "(fang,芳)")))
  }

  @Test
  func testHashCellStopsRecordingSubsequentCells() throws {
    let lxTest = makeLoadedLX()
    let pair = Homa.CandidatePair(keyArray: ["ㄘㄠ"], value: "草")
    let values = lxTest.valuesFor(pair: pair)
    #expect(values == ["華", "蹤"])
    #expect(!values.contains("後續不錄"))
    #expect(!values.contains("#"))
  }

  @Test
  func testCommentAndMalformedLinesSkipped() throws {
    let lxTest = makeLoadedLX()
    #expect(!lxTest.hasValuesFor(pair: .init(keyArray: [], value: "#")))
    #expect(!lxTest.hasValuesFor(pair: .init(keyArray: [], value: "關聯詞語測試資料")))
    #expect(!lxTest.hasValuesFor(pair: .init(keyArray: [], value: "孤行無值")))
    #expect(!lxTest.hasValuesFor(pair: .init(keyArray: [], value: "不存在的key")))
  }

  @Test
  func testDictRepresentedKeepsRawOrderWithoutDedup() throws {
    let lxTest = makeLoadedLX()
    let dict = lxTest.dictRepresented
    // dictRepresented 不做 dedup（與舊版行為一致）：兩行「芳」依行序全數列出。
    #expect(dict["芳"] == ["苑", "鄰", "香", "芳香", "苑"])
    #expect(dict["(fang,芳)"] == ["苑", "鄰"])
    #expect(dict["草"] == ["華", "蹤"])
  }

  @Test
  func testCnvNGramKeyGuardPassthrough() throws {
    // 不具備括號與逗號結構的 key 原樣返回；純英數 pinyin 不觸發轉換。
    #expect(LXAssembly.LXAssociates.cnvNGramKeyFromPinyinToPhona(target: "芳") == "芳")
    #expect(LXAssembly.LXAssociates.cnvNGramKeyFromPinyinToPhona(target: "(fang,芳)") == "(fang,芳)")
    #expect(LXAssembly.LXAssociates.cnvNGramKeyFromPinyinToPhona(target: "(a,b,c)") == "(a,b,c)")
  }

  @Test
  func testStrDataAndClear() throws {
    var lxTest = makeLoadedLX()
    // strData computed 屬性與載入原文一致（保護外部唯讀消費端）。
    #expect(lxTest.strData == sampleData)
    lxTest.clear()
    #expect(!lxTest.isLoaded)
    #expect(lxTest.count < 1)
    #expect(lxTest.strData.isEmpty)
    #expect(!lxTest.hasValuesFor(pair: .init(keyArray: ["ㄈㄤ"], value: "芳")))
  }

  @Test
  func testSaveDataRoundTrip() throws {
    var lxTest = makeLoadedLX()
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_associates_\(UUID().uuidString).txt")
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
      .appendingPathComponent("vChewingTest_associates_invalid_\(UUID().uuidString).txt")
    try Data(bytes).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var lxTest = LXAssembly.LXAssociates()
    let opened = lxTest.open(tempURL.path)
    #expect(opened)
    lxTest.saveData()
    let saved = try Data(contentsOf: tempURL)
    #expect(Array(saved) == bytes)
  }

  // MARK: Private

  private func makeLoadedLX() -> LXAssembly.LXAssociates {
    var lxTest = LXAssembly.LXAssociates()
    lxTest.replaceData(textData: sampleData)
    return lxTest
  }
}
