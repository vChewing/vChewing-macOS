// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Tekkon
import Testing
@testable import TrieKit

// MARK: - TrieKitTestsSQL

@Suite(.serialized)
public struct TrieKitTests: TrieKitTestSuite {
  // MARK: Internal

  @Test("[TrieKit] Trie SQL Query Test", arguments: [false, true])
  func testTrieDirectQuery(useTextMap: Bool) async throws {
    let mockLM = try prepareTrieLM(useTextMap: useTextMap).lm
    do {
      let partialMatchQueried = mockLM.queryGrams(["ㄧ"], partiallyMatch: true)
      #expect(!partialMatchQueried.isEmpty)
      #expect(partialMatchQueried.contains(where: { $0.keyArray.first == "ㄧˋ" }))
    }
    do {
      let fullMatchQueried = mockLM.queryGrams(["ㄧㄡ"], partiallyMatch: true)
      #expect(!fullMatchQueried.isEmpty)
      #expect(!fullMatchQueried.contains(where: { $0.keyArray.first == "ㄧˋ" }))
    }
    do {
      let fullMatchQueried2 = mockLM.queryGrams(["ㄧㄡ", "ㄉㄧㄝˊ"], partiallyMatch: true)
      #expect(!fullMatchQueried2.isEmpty)
    }
    do {
      let partialMultiMatchQueried = mockLM.queryGrams(["ㄧㄛ&ㄧㄡ&ㄩㄥ"], partiallyMatch: true)
      #expect(!partialMultiMatchQueried.isEmpty)
      #expect(!partialMultiMatchQueried.contains(where: { $0.keyArray.first == "ㄧˋ" }))
    }
  }

  /// 這裡重複對護摩引擎的胡桃測試（Full Match）。
  @Test("[TrieKit] Trie SQL Structure Test (Full Match)", arguments: [false, true])
  func testTrieSQLStructureWithFullMatch(useTextMap: Bool) async throws {
    let mockLM = try prepareTrieLM(useTextMap: useTextMap).lm
    let readings: [Substring] = "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ".split(separator: " ")
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) }, // 會回傳包含 Bigram 的結果。
      gramAvailabilityChecker: { mockLM.hasGrams($0) }
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    // 初始組句結果。
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄌㄧㄡˊ"], value: "留"), at: 3, type: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。這也便於最後一個位置的 Bigram 測試。
    // （因為是有了「一縷」這個前提才會去找對應的 Bigram。）
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄧˋ", "ㄌㄩˇ"], value: "一縷"), at: 4, type: .withSpecified
    )
    let dotWithBigram = assembler.dumpDOT(verticalGraph: true)
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    // 剛才測試 Bigram 生效了。現在禁用 Bigram 試試看。先攔截掉 Bigram 結果。
    assembler.gramQuerier = { mockLM.queryGrams($0).filter { $0.previous == nil } }
    try assembler.assignNodes(updateExisting: true) // 置換掉所有節點裡面的資料。
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "方"])
    // 對位置 7 這個最前方的座標位置使用節點覆寫。會在此過程中自動糾正成對位置 6 的覆寫。
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄈㄤ"], value: "芳"), at: 7, type: .withSpecified
    )
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let dotSansBigram = assembler.dumpDOT(verticalGraph: true)
    // 驗證兩次 dumpDOT 結果是否雷同。
    #expect(dotWithBigram == dotSansBigram)
    let expectedDOT = """
    digraph {\ngraph [ rankdir=TB ];\nBOS;\nBOS -> 優;\n優;\n優 -> 跌;\nBOS -> 幽蝶;\n\
    幽蝶;\n幽蝶 -> 能;\n幽蝶 -> 能留;\n跌;\n跌 -> 能;\n跌 -> 能留;\n能;\n能 -> 留;\n\
    能 -> 留意;\n能留;\n能留 -> 亦;\n能留 -> 一縷;\n留;\n留 -> 亦;\n留 -> 一縷;\n留意;\n\
    留意 -> 旅;\n留意 -> 呂方;\n亦;\n亦 -> 旅;\n亦 -> 呂方;\n一縷;\n一縷 -> 芳;\n旅;\n\
    旅 -> 芳;\n呂方;\n呂方 -> EOS;\n芳;\n芳 -> EOS;\nEOS;\n}\n
    """
    #expect(dotWithBigram == expectedDOT)
  }

  /// 這裡重複對護摩引擎的胡桃測試（Partial Match）。
  @Test("[TrieKit] Trie SQL Structure Test (Partial Match)", arguments: [false, true])
  func testTrieSQLStructureWithPartialMatch(useTextMap: Bool) async throws {
    let mockLM = try prepareTrieLM(useTextMap: useTextMap).lm
    #expect(mockLM.hasGrams(["ㄧ"], partiallyMatch: true))
    #expect(!mockLM.queryGrams(["ㄧ"], partiallyMatch: true).isEmpty)
    let readings: [String] = "ㄧㄉㄋㄌㄧㄌㄈ".map(\.description)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0, partiallyMatch: true) }, // 會回傳包含 Bigram 的結果。
      gramAvailabilityChecker: { mockLM.hasGrams($0, partiallyMatch: true) }
    )
    try readings.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄌㄧㄡˊ"], value: "留"), at: 3, type: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。這也便於最後一個位置的 Bigram 測試。
    // （因為是有了「一縷」這個前提才會去找對應的 Bigram。）
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄧˋ", "ㄌㄩˇ"], value: "一縷"), at: 4, type: .withSpecified
    )
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let actualkeysJoined = assembler.actualKeys.joined(separator: " ")
    #expect(actualkeysJoined == "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ")
  }

  /// 利用 PinyinTrie 工具處理不完整的拼音輸入串、再藉由護摩組字引擎交給 VanguardTrie 處理。
  ///
  /// 這會完整模擬一款簡拼輸入法「僅依賴使用者的不完全拼音輸入字串進行組字」的完整流程、
  /// 且組字時使用以注音索引的後端辭典資料。
  @Test("[TrieKit] Test Chopped Pinyin Handling (with PinyinTrie)", arguments: [false, true])
  func testTekkonPinyinTrieTogetherAgainstChoppedPinyin(useTextMap: Bool) async throws {
    let pinyinTrie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
    let rawPinyin = "yodienliylvf"
    let rawPinyinChopped = pinyinTrie.chop(rawPinyin)
    #expect(rawPinyinChopped == ["yo", "die", "n", "li", "y", "lv", "f"])
    let keys2Add = pinyinTrie.deductChoppedPinyinToZhuyin(rawPinyinChopped)
    #expect(keys2Add == ["ㄧㄛ&ㄧㄡ&ㄩㄥ", "ㄉㄧㄝ", "ㄋ", "ㄌㄧ", "ㄧ&ㄩ", "ㄌㄩ&ㄌㄩㄝ&ㄌㄩㄢ", "ㄈ"])
    let mockLM = try prepareTrieLM(useTextMap: useTextMap).lm
    let hasResults = mockLM.hasGrams(["ㄧ&ㄩ"], partiallyMatch: true)
    #expect(hasResults)
    let queried = mockLM.queryGrams(["ㄧ&ㄩ"], partiallyMatch: true)
    #expect(!queried.isEmpty)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0, partiallyMatch: true) }, // 會回傳包含 Bigram 的結果。
      gramAvailabilityChecker: { mockLM.hasGrams($0, partiallyMatch: true) }
    )
    try keys2Add.forEach {
      try assembler.insertKey($0.description)
    }
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留意", "呂方"])
    // 測試覆寫「留」以試圖打斷「留意」。
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄌㄧㄡˊ"], value: "留"), at: 3, type: .withSpecified
    )
    // 測試覆寫「一縷」以打斷「留意」與「呂方」。這也便於最後一個位置的 Bigram 測試。
    // （因為是有了「一縷」這個前提才會去找對應的 Bigram。）
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄧˋ", "ㄌㄩˇ"], value: "一縷"), at: 4, type: .withSpecified
    )
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽蝶", "能", "留", "一縷", "芳"])
    let actualkeysJoined = assembler.actualKeys.joined(separator: " ")
    #expect(actualkeysJoined == "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ")
  }

  /// 檢查對關聯詞語的檢索能力。
  @Test("[TrieKit] Trie Associated Phrases Query Test", arguments: [false, true])
  func testTrieQueryingAssociatedPhrases(useTextMap: Bool) async throws {
    let trie = try prepareTrieLM(useTextMap: useTextMap).trie
    do {
      let fetched = trie.queryAssociatedPhrasesPlain(
        (["ㄌㄧㄡˊ"], "流"),
        filterType: .langNeutral
      )
      #expect(fetched?.map(\.value) == ["溢", "易", "議"])
    }
    do {
      let fetched = trie.queryAssociatedPhrasesAsGrams(
        (["ㄕㄨˋ"], "🌳"),
        filterType: .langNeutral
      )
      #expect(fetched?.filter { $0.previous == nil }.map(\.value) == ["🌳🆕💨", "🌳🆕🐝"])
      #expect(fetched?.map(\.value).prefix(2) == ["🌳🆕🐝", "🌳🆕💨"])
      let fetchedPlain = trie.queryAssociatedPhrasesPlain(
        (["ㄕㄨˋ"], "🌳"),
        filterType: .langNeutral
      )
      #expect(fetchedPlain?.map(\.value) == ["🆕🐝", "🆕💨"])
    }
    do {
      let fetched = trie.queryAssociatedPhrasesAsGrams(
        (["ㄕㄨˋ"], "🌳"),
        anterior: "",
        filterType: .langNeutral
      )
      #expect(fetched?.map(\.value) == ["🌳🆕💨", "🌳🆕🐝"])
      #expect(fetched?.map(\.value).prefix(2) == ["🌳🆕💨", "🌳🆕🐝"])
      let fetchedPlain = trie.queryAssociatedPhrasesPlain(
        (["ㄕㄨˋ"], "🌳"),
        anterior: "",
        filterType: .langNeutral
      )
      #expect(fetchedPlain?.map(\.value) == ["🆕💨", "🆕🐝"])
    }
    do {
      let fetched = trie.queryAssociatedPhrasesAsGrams(
        (["ㄕㄨˋ"], "🌳"),
        anterior: "不要",
        filterType: .langNeutral
      )
      #expect(fetched?.map(\.value) == ["🌳🆕🐝"])
      #expect(fetched?.map(\.value).prefix(2) == ["🌳🆕🐝"])
      let fetchedPlain = trie.queryAssociatedPhrasesPlain(
        (["ㄕㄨˋ"], "🌳"),
        anterior: "不要",
        filterType: .langNeutral
      )
      #expect(fetchedPlain?.map(\.value) == ["🆕🐝"])
    }
  }

  // MARK: Private

  private func prepareTrieLM(useTextMap: Bool) throws -> (
    lm: TestLM4Trie,
    trie: any VanguardTrieProtocol
  ) {
    // 先測試物件創建。
    let trie = VanguardTrie.Trie(separator: "-")
    strLMSampleDataHutaoZhuyin.enumerateLines { line, _ in
      let components = line.split(whereSeparator: \.isWhitespace)
      guard components.count >= 3 else { return }
      let value = String(components[1])
      guard let probability = Double(components[2].description) else { return }
      let previous = components.count > 3 ? String(components[3]) : nil
      let readings: [String] = components[0].split(
        separator: trie.readingSeparator
      ).map(\.description)
      let entry = VanguardTrie.Trie.Entry(
        value: value,
        typeID: .langNeutral,
        probability: probability,
        previous: previous
      )
      trie.insert(entry: entry, readings: readings)
    }
    let trieFinal: VanguardTrieProtocol
    switch useTextMap {
    case false:
      let encoded = try VanguardTrie.TrieIO.serialize(trie)
      trieFinal = try VanguardTrie.TrieIO.deserialize(encoded)
    case true:
      let textMap = VanguardTrie.TrieIO.serializeToTextMap(trie)
      let trie = try VanguardTrie.TextMapTrie(data: Data(textMap.utf8))
      trieFinal = trie
    }
    let mockLM = TestLM4Trie(trie: trieFinal)
    #expect(mockLM.hasGrams(["ㄧˋ", "ㄌㄩˇ"]))
    #expect(!mockLM.queryGrams(["ㄧˋ", "ㄌㄩˇ"]).isEmpty)
    return (mockLM, trieFinal)
  }
}
