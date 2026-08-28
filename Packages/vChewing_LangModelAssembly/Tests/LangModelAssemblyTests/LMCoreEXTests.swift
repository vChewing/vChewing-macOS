// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
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
#
# 下述詞頻資料取自 libTaBE 資料庫 (http://sourceforge.net/projects/libtabe/)
# (2002 最終版). 該專案於 1999 年由 Pai-Hsiang Hsiao 發起、以 BSD 授權發行。
#
ㄍㄠ 篙 -13.624335
ㄍㄠ 糕 -12.390804
ㄍㄠ 膏 -11.928720
ㄍㄠ 高 -7.171551
ㄎㄜ 刻 -10.450457
ㄎㄜ 柯 -99.000000
ㄎㄜ 棵 -11.504072
ㄎㄜ 科 -7.171052
ㄎㄜ 顆 -10.574273
ㄙ 司 -99.000000
ㄙ 嘶 -13.513987
ㄙ 思 -9.006414
ㄙ 撕 -12.259095
ㄙ 斯 -8.091803
ㄙ 絲 -9.495858
ㄙ 私 -99.000000

"""#

// MARK: - LMCoreEXTests

@Suite(.serialized)
struct LMCoreEXTests {
  // MARK: Internal

  @Test
  func testLMCoreEXAsFactoryCoreDict() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    #expect(lmTest.count == 3)
    let gao1 = lmTest.unigramsFor(key: "ㄍㄠ").map(\.current)
    let ke1 = lmTest.unigramsFor(key: "ㄎㄜ").map(\.current)
    let si1 = lmTest.unigramsFor(key: "ㄙ").map(\.current)
    #expect(gao1 == ["篙", "糕", "膏", "高"])
    #expect(ke1 == ["刻", "柯", "棵", "科", "顆"])
    #expect(si1 == ["司", "嘶", "思", "撕", "斯", "絲", "私"])
  }

  @Test
  func testKeysMatchingPrefix() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    #expect(lmTest.keys(matchingPrefix: "ㄍ").sorted() == ["ㄍㄠ"])
    #expect(lmTest.keys(matchingPrefix: "ㄎ").sorted() == ["ㄎㄜ"])
    #expect(lmTest.keys(matchingPrefix: "ㄙ").sorted() == ["ㄙ"])
    #expect(lmTest.keys(matchingPrefix: "ㄋ").isEmpty)
    #expect(lmTest.keys(matchingPrefix: "").isEmpty)
  }

  @Test
  func testUnigramsForKeyPrefix() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    let gaoPrefix = lmTest.unigramsFor(keyPrefix: "ㄍ").map(\.current)
    #expect(gaoPrefix == ["篙", "糕", "膏", "高"])
    let emptyPrefix = lmTest.unigramsFor(keyPrefix: "ㄋ")
    #expect(emptyPrefix.isEmpty)
  }

  @Test
  func testPartialMatchIncludesTemporaryMap() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    lmTest.temporaryMap["ㄍㄠ-ㄒㄧㄥ"] = [
      .init(keyArray: ["ㄍㄠ", "ㄒㄧㄥ"], value: "高興", score: -5.0),
    ]
    let keys = lmTest.keys(matchingPrefix: "ㄍㄠ").sorted()
    #expect(keys == ["ㄍㄠ", "ㄍㄠ-ㄒㄧㄥ"])
    let grams = lmTest.unigramsFor(keyPrefix: "ㄍㄠ").map(\.current)
    #expect(grams == ["篙", "糕", "膏", "高", "高興"])
  }

  @Test
  func testReplaceDataHandlesTabDelimitedInput() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    let tabbedData = "ㄍㄠ\t高\t-7.171551\nㄎㄜ\t顆\t-10.574273"
    lmTest.replaceData(textData: tabbedData)
    #expect(lmTest.count == 2)
    let gao = lmTest.unigramsFor(key: "ㄍㄠ").map(\.current)
    let ke = lmTest.unigramsFor(key: "ㄎㄜ").map(\.current)
    #expect(gao == ["高"])
    #expect(ke == ["顆"])
  }

  @Test
  func testPrefixMatchingDeduplicatesOverlappingMainAndTemporaryKeys() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    lmTest.temporaryMap["ㄍㄠ"] = [
      .init(keyArray: ["ㄍㄠ"], value: "暫時高", score: -5.0),
    ]

    let keys = lmTest.keys(matchingPrefix: "ㄍㄠ")
    #expect(keys == ["ㄍㄠ"])

    let grams = lmTest.unigramsFor(keyPrefix: "ㄍㄠ").map(\.current)
    #expect(grams.filter { $0 == "高" }.count == 1)
    #expect(grams.filter { $0 == "暫時高" }.count == 1)
  }

  @Test
  func testStrDataReflectsProcessedSource() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    // strData computed 屬性與載入原文一致（保護外部唯讀消費端）。
    #expect(lmTest.strData == sampleData)
    // tab 會在載入時正規化為空格，strData 反映的是正規化後的內容。
    lmTest.replaceData(textData: "ㄍㄠ\t高\t-7.171551")
    #expect(lmTest.strData == "ㄍㄠ 高 -7.171551")
  }

  @Test
  func testSaveDataRoundTripWithTemporaryMap() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    lmTest.temporaryMap["ㄍㄠ-ㄒㄧㄥ"] = [
      .init(keyArray: ["ㄍㄠ", "ㄒㄧㄥ"], value: "高興", score: -5.0),
    ]
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_coreex_\(UUID().uuidString).txt")
    lmTest.filePath = tempURL.path
    lmTest.saveData()
    let saved = try String(contentsOf: tempURL, encoding: .utf8)
    // 先寫原文、再把 temporaryMap 逐筆以「值 鍵 權重」格式附加。
    #expect(saved.hasPrefix(sampleData))
    #expect(saved.contains("高興 ㄍㄠ-ㄒㄧㄥ -5.0\n"))
    try? FileManager.default.removeItem(at: tempURL)
  }

  @Test
  func testOpenSaveRoundTripPreservesInvalidUTF8() throws {
    // consolidate: false 路徑：open 以位元組讀入（CR→LF、Tab→空格為位元組層級取代），
    // saveData 以原始位元組寫回——非法 UTF-8 位元組原樣保留。
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    let bytes: [UInt8] = Array("foo\tbar\r\n".utf8) + [0xFF] + Array("\nbaz\n".utf8)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_coreex_invalid_\(UUID().uuidString).txt")
    try Data(bytes).write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let opened = lmTest.open(tempURL.path)
    #expect(opened)
    lmTest.saveData()
    let saved = try Data(contentsOf: tempURL)
    // CR→LF、Tab→空格後：foo bar\n\n ＋ 0xFF ＋ \nbaz\n
    let expected: [UInt8] = Array("foo bar\n\n".utf8) + [0xFF] + Array("\nbaz\n".utf8)
    #expect(Array(saved) == expected)
  }

  @Test
  func testMultiPrefixIntersectionScanMatchesPerCellPrefixes() throws {
    let lmTest = makeMultiPrefixLM()
    let cells: [[String]] = [["ㄧ", "ㄩ"], ["ㄕ", "ㄙ"], ["ㄒ"], ["ㄅ"]]
    let keys = lmTest.keys(matchingPrefixesByPosition: cells)
    // 位置 0 限 ㄧ/ㄩ、位置 1 限 ㄕ/ㄙ、位置 2 限 ㄒ、位置 3 限 ㄅ。
    // 「ㄨㄢ-…」（ㄨ ∉ {ㄧ,ㄩ}）、3 段鍵、以及 ㄅ 開頭鍵皆不匹配。
    #expect(keys == [
      "ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ",
      "ㄧㄝ-ㄙㄨㄥ-ㄒㄧㄤ-ㄅㄧㄥ",
      "ㄩㄢ-ㄕ-ㄒㄧㄥ-ㄅㄟ",
      "ㄩㄢ-ㄕㄡ-ㄒㄧㄥ-ㄅㄧㄥ",
    ])
  }

  @Test
  func testMultiPrefixScanIsSupersetOfPerComboUnion() throws {
    let lmTest = makeMultiPrefixLM()
    let cells: [[String]] = [["ㄧ", "ㄩ"], ["ㄕ", "ㄙ"], ["ㄒ"], ["ㄅ"]]
    // 新的多位置前綴掃描為「每位置前綴」語義，是既有「逐 combo 前綴查詢」（前段精確、
    // 僅末段前綴）的超集：舊路徑找得到的，新路徑一定找得到（反向不一定）。
    let scannedKeys = Set(lmTest.keys(matchingPrefixesByPosition: cells))
    var comboKeys = Set<String>()
    for first in ["ㄧ", "ㄩ"] {
      for second in ["ㄕ", "ㄙ"] {
        comboKeys.formUnion(lmTest.keys(matchingPrefix: "\(first)-\(second)-ㄒ-ㄅ"))
      }
    }
    #expect(comboKeys.isSubset(of: scannedKeys))
    // 而「每位置前綴」的命中（如「ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ」整詞以 initial 命中）是舊路徑
    // 找不出來的新能力——此即 R2「ysxb → 野獸先輩」的關鍵。
    #expect(scannedKeys.contains("ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ"))
    #expect(scannedKeys.count > comboKeys.count)
  }

  @Test
  func testMultiPrefixScanIncludesTemporaryMap() throws {
    var lmTest = makeMultiPrefixLM()
    lmTest.temporaryMap["ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ"] = [
      .init(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩(臨時)", score: -5.0),
    ]
    let cells: [[String]] = [["ㄧ", "ㄩ"], ["ㄕ", "ㄙ"], ["ㄒ"], ["ㄅ"]]
    let grams = lmTest.unigramsFor(keyPrefixesByPosition: cells).map(\.current)
    #expect(grams.contains("野獸先輩(臨時)"))
  }

  @Test
  func testMultiPrefixScanBoundedVsCartesianProduct() throws {
    // 規模對照：20×20×20×20 的乘積 = 160,000 次逐 combo 查詢；
    // 多前綴掃描的訪問鍵數只與詞庫鍵數有關（此處 7 鍵）。
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: Self.multiPrefixData)
    let syllables = [
      "ㄚ",
      "ㄜ",
      "ㄛ",
      "ㄞ",
      "ㄟ",
      "ㄠ",
      "ㄡ",
      "ㄢ",
      "ㄣ",
      "ㄤ",
      "ㄥ",
      "ㄦ",
      "ㄧ",
      "ㄨ",
      "ㄩ",
      "ㄅ",
      "ㄆ",
      "ㄇ",
      "ㄈ",
      "ㄉ",
    ]
    let cells: [[String]] = [syllables, syllables, syllables, syllables]
    let product = syllables.count * syllables.count * syllables.count * syllables.count
    #expect(product == 160_000)
    let keys = lmTest.keys(matchingPrefixesByPosition: cells)
    #expect(keys.count <= 7) // 訪問鍵數受詞庫鍵數上限，而非乘積。
    _ = lmTest.unigramsFor(keyPrefixesByPosition: cells)
  }

  // MARK: Private

  // MARK: - Phase 157（R2-A）多位置前綴交集掃描

  private static let multiPrefixData = """
  ㄧㄝ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ 野獸先輩 -8.0
  ㄧㄝ-ㄙㄨㄥ-ㄒㄧㄤ-ㄅㄧㄥ 夜送香冰 -9.0
  ㄩㄢ-ㄕㄡ-ㄒㄧㄥ-ㄅㄧㄥ 遠收星冰 -9.0
  ㄩㄢ-ㄕ-ㄒㄧㄥ-ㄅㄟ 遠師星杯 -9.0
  ㄨㄢ-ㄕㄡ-ㄒㄧㄥ-ㄅㄟ 晚收星杯 -9.0
  ㄧㄝ-ㄕㄡ-ㄒㄧㄢ 野獸先 -9.0
  ㄅㄚ-ㄕㄡ-ㄒㄧㄢ-ㄅㄟ 巴收先杯 -9.0
  """

  private func makeMultiPrefixLM() -> LMAssembly.LMCoreEX {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: Self.multiPrefixData)
    return lmTest
  }
}
