// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

// MARK: - LXCandidateSequenceTests

/// 使用者自訂候選字詞排序表之解析、讀取與清除。
@Suite(.serialized)
struct LXCandidateSequenceTests {
  @Test
  func testParseSkipsCommentsBlankLinesAndMalformedRows() {
    let text = """
    # 𝙵𝙾𝚁𝙼𝙰𝚃
    # 讀音 候選（依序）
    ㄅㄚ\t八 巴 吧

    ㄗㄞˋ 在 再
    ㄅㄛ
    """
    let parsed = LXAssembly.LXCandidateSequence.parse(text)
    #expect(parsed["ㄅㄚ"] == ["八", "巴", "吧"])
    #expect(parsed["ㄗㄞˋ"] == ["在", "再"])
    #expect(parsed["ㄅㄛ"] == nil)
    #expect(parsed.count == 2)
  }

  @Test
  func testParseDeduplicatesValuesAndKeepsLastLinePerReading() {
    let text = """
    ㄅㄚ 八 巴 八
    ㄅㄚ 巴 八
    """
    let parsed = LXAssembly.LXCandidateSequence.parse(text)
    #expect(parsed["ㄅㄚ"] == ["巴", "八"])
  }

  @Test
  func testValuesForUnknownReadingIsEmpty() {
    var sequence = LXAssembly.LXCandidateSequence()
    sequence.replaceData(textData: "ㄅㄚ 八 巴\n")
    #expect(sequence.values(for: "ㄅㄚ") == ["八", "巴"])
    #expect(sequence.values(for: "ㄅㄛ").isEmpty)
    #expect(sequence.count == 1)
    #expect(sequence.isLoaded)
    sequence.clear()
    #expect(sequence.values(for: "ㄅㄚ").isEmpty)
    #expect(!sequence.isLoaded)
  }

  @Test
  func testLoadFromUserDataLocatorAndPurge() throws {
    let locator = InMemoryUserDataLocator()
    let url = URL(fileURLWithPath: "/virtual/userdata/candidate-sequence-cht.txt")
    try locator.write(Data("ㄅㄚ 八 巴\n".utf8), to: url)
    let lx = LXAssembly.LXFacade(isCHS: false, locator: locator)
    lx.loadCandidateSequenceData(path: url.path)
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ") == ["八", "巴"])
    #expect(lx.lxQuerier.candidateSequenceValues(for: "ㄅㄚ") == ["八", "巴"])

    lx.purgeUserData()
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ").isEmpty)

    // 檔案不存在 ⇒ 空表，不得殘留前一次載入的資料。
    lx.replaceCandidateSequenceData(textData: "ㄅㄚ 八 巴\n")
    lx.loadCandidateSequenceData(path: "/virtual/userdata/absent.txt")
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ").isEmpty)
  }

  @Test
  func testFacadeRetrieveReplaceAndSaveRoundTrip() throws {
    let locator = InMemoryUserDataLocator()
    let url = URL(fileURLWithPath: "/virtual/userdata/candidate-sequence-cht.txt")
    try locator.write(Data("# 註解\nㄅㄚ 八 巴\n".utf8), to: url)
    let lx = LXAssembly.LXFacade(isCHS: false, locator: locator)
    lx.loadCandidateSequenceData(path: url.path)
    #expect(lx.retrieveData(from: .theCandidateSequence).contains("八 巴"))

    lx.replaceData(textData: "ㄅㄚ 巴 八\n", for: .theCandidateSequence, save: true)
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ") == ["巴", "八"])
    let saved = try locator.readText(at: url)
    #expect(saved.contains("巴 八"))
    #expect(saved.contains(LXAssembly.LXConsolidator.kPragmaHeader))

    lx.loadCandidateSequenceData(path: url.path)
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ") == ["巴", "八"])
  }

  @Test
  func testInvalidUTF8FileLoadsAsEmpty() throws {
    let locator = InMemoryUserDataLocator()
    let url = URL(fileURLWithPath: "/virtual/userdata/candidate-sequence-cht.txt")
    try locator.write(Data([0xFF, 0xFE, 0x0A]), to: url)
    let lx = LXAssembly.LXFacade(isCHS: false, locator: locator)
    lx.loadCandidateSequenceData(path: url.path)
    #expect(lx.candidateSequenceValues(for: "ㄅㄚ").isEmpty)
  }
}
