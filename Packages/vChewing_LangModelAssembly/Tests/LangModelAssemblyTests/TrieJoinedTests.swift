// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import HomaSharedTestComponents
@testable import LangModelAssembly
import LMAssemblyMaterials4Tests
import Tekkon
import Testing
import TrieKit

// MARK: - TrieJoinedTestSuite

@Suite(.serialized)
struct TrieJoinedTestSuite {}

extension TrieJoinedTestSuite {
  @Test(
    "[LMA] TrieJoined_AssemblyingUsingFullMatch",
  )
  func testTrieJoinedAssemblyingUsingFullMatch() async throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    #expect(
      LMAssembly.LMInstantiator.connectToTestFactoryDictionary(
        textMapData: LMATestsData.textMapTestCoreLMData
      )
    )
    let trie = try #require(LMAssembly.LMInstantiator.factoryTrie)
    let readings: [Substring] = "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ".split(separator: " ")
    let assembler = Homa.Assembler(
      gramQuerier: Self.makeFactoryGramQuerier(trie: trie, partiallyMatch: false),
      gramAvailabilityChecker: Self.makeFactoryGramAvailabilityChecker(trie: trie, partiallyMatch: false)
    )
    try Self.measureTime("Key insertion time cost total", tag: "(FullMatch)") {
      try readings.forEach { try assembler.insertKey($0.description) }
    }
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["優", "跌", "能", "留意", "旅", "方"])
    try assembler.overrideCandidate(.init((["ㄧㄡ"], "幽")), at: 0)
    try assembler.overrideCandidate(.init((["ㄉㄧㄝˊ"], "蝶")), at: 1)
    try assembler.overrideCandidate(.init((["ㄌㄧㄡˊ"], "留")), at: 3)
    try assembler.overrideCandidate(.init((["ㄧˋ", "ㄌㄩˇ"], "一縷")), at: 4)
    try assembler.overrideCandidate(.init((["ㄈㄤ"], "芳")), at: 6)
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽", "蝶", "能", "留", "一縷", "芳"])
    let actualkeysJoined = assembler.actualKeys.joined(separator: " ")
    #expect(actualkeysJoined == "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ")
  }

  @Test(
    "[LMA] TrieJoined_AssemblyingUsingPartialMatchAndChops",
  )
  func testTrieJoinedAssemblyingUsingPartialMatchAndChops() async throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    #expect(
      LMAssembly.LMInstantiator.connectToTestFactoryDictionary(
        textMapData: LMATestsData.textMapTestCoreLMData
      )
    )
    let pinyinTrie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
    let rawPinyin = "yodienliylvf"
    let rawPinyinChopped = pinyinTrie.chop(rawPinyin)
    #expect(rawPinyinChopped == ["yo", "die", "n", "li", "y", "lv", "f"])
    let keys2Add = pinyinTrie.deductChoppedPinyinToZhuyin(rawPinyinChopped)
    #expect(keys2Add == ["ㄧㄛ&ㄧㄡ&ㄩㄥ", "ㄉㄧㄝ", "ㄋ", "ㄌㄧ", "ㄧ&ㄩ", "ㄌㄩ&ㄌㄩㄝ&ㄌㄩㄢ", "ㄈ"])
    let trie = try #require(LMAssembly.LMInstantiator.factoryTrie)
    let assembler = Homa.Assembler(
      gramQuerier: Self.makeFactoryGramQuerier(trie: trie, partiallyMatch: true),
      gramAvailabilityChecker: Self.makeFactoryGramAvailabilityChecker(trie: trie, partiallyMatch: true)
    )
    try Self.measureTime("Key insertion time cost total", tag: "(Partial Match)") {
      try keys2Add.forEach { try assembler.insertKey($0.description) }
    }
    var assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["優", "跌", "年", "留意", "旅", "方"])
    try assembler.overrideCandidate(.init((["ㄧㄡ"], "幽")), at: 0)
    try assembler.overrideCandidate(.init((["ㄉㄧㄝˊ"], "蝶")), at: 1)
    try assembler.overrideCandidate(.init((["ㄋㄥˊ"], "能")), at: 2)
    try assembler.overrideCandidate(.init((["ㄌㄧㄡˊ"], "留")), at: 3)
    try assembler.overrideCandidate(.init((["ㄧˋ", "ㄌㄩˇ"], "一縷")), at: 4)
    try assembler.overrideCandidate(.init((["ㄈㄤ"], "芳")), at: 6)
    assembledSentence = assembler.assemble().compactMap(\.value)
    #expect(assembledSentence == ["幽", "蝶", "能", "留", "一縷", "芳"])
    let actualkeysJoined = assembler.actualKeys.joined(separator: " ")
    #expect(actualkeysJoined == "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ")
  }

  private static func measureTime(
    _ memo: String,
    tag: String,
    enabled: Bool = true,
    _ task: @escaping () throws -> ()
  ) rethrows {
    guard enabled else {
      try task()
      return
    }
    let timestamp1a = Date().timeIntervalSince1970
    try task()
    let timestamp1b = Date().timeIntervalSince1970
    let timeCost = ((timestamp1b - timestamp1a) * 100_000).rounded() / 100
    print("[Sitrep \(tag)] \(memo): \(timeCost)ms.")
  }

  private static func makeFactoryGramQuerier(
    trie: VanguardTrie.TextMapTrie,
    partiallyMatch: Bool
  )
    -> Homa.GramQuerier {
    { keyArray in
      let encodedKeys = keyArray.map(PhonabetCipher.convertPhonabetToASCII)
      return trie.queryGrams(
        encodedKeys,
        filterType: .cht,
        partiallyMatch: partiallyMatch
      ).map {
        (
          keyArray: $0.keyArray.map(PhonabetCipher.restorePhonabetFromASCII),
          value: $0.value,
          probability: $0.probability,
          previous: $0.previous
        )
      }
    }
  }

  private static func makeFactoryGramAvailabilityChecker(
    trie: VanguardTrie.TextMapTrie,
    partiallyMatch: Bool
  )
    -> Homa.GramAvailabilityChecker {
    { keyArray in
      let encodedKeys = keyArray.map(PhonabetCipher.convertPhonabetToASCII)
      return trie.hasGrams(
        encodedKeys,
        filterType: .cht,
        partiallyMatch: partiallyMatch
      )
    }
  }
}
