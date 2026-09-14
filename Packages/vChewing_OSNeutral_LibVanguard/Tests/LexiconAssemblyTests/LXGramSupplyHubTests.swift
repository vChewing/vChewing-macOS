// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import LXAssemblyMaterials4Tests
import Testing
import TrieKit

@testable import LexiconAssembly

// MARK: - StubGramSupplier

/// 語言模組來源的測試替身：以「-」連讀的索引鍵字串查表供應元圖。
nonisolated final class StubGramSupplier: LXAssembly.LexiconGramSupplierProtocol {
  // MARK: Lifecycle

  init(gramsByKeyChain: [String: [Homa.Gram]] = [:], associatedPhrases: [Homa.Gram]? = nil) {
    self.gramsByKeyChain = gramsByKeyChain
    self.associatedPhrases = associatedPhrases
  }

  // MARK: Internal

  var gramsByKeyChain: [String: [Homa.Gram]]
  var associatedPhrases: [Homa.Gram]?

  private(set) var hasGramsCallCount = 0
  private(set) var queryGramsCallCount = 0
  private(set) var lastFilterType: VanguardTrie.Trie.EntryType?
  private(set) var lastPartiallyMatch: Bool?

  func hasGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool,
    partiallyMatchedKeysHandler: ((Set<[String]>) -> ())?
  )
    -> Bool {
    hasGramsCallCount += 1
    lastFilterType = filterType
    lastPartiallyMatch = partiallyMatch
    guard !served(keyChain: keys).isEmpty else { return false }
    partiallyMatchedKeysHandler?([keys])
    return true
  }

  func queryGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())?
  )
    -> [Homa.Gram] {
    queryGramsCallCount += 1
    lastFilterType = filterType
    lastPartiallyMatch = partiallyMatch
    let served = served(keyChain: keys)
    guard !served.isEmpty else { return [] }
    partiallyMatchedKeysPostHandler?([keys])
    return served
  }

  func queryAssociatedPhrasesAsGrams(
    _ previous: (keyArray: [String], value: String),
    anterior anteriorValue: String?,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [Homa.Gram]? {
    associatedPhrases
  }

  // MARK: Private

  private func served(keyChain: [String]) -> [Homa.Gram] {
    gramsByKeyChain[keyChain.joined(separator: "-")] ?? []
  }
}

// MARK: - LXGramSupplyHubTests

@Suite(.serialized)
struct LXGramSupplyHubTests {
  @Test
  func testEmptyHubServesNothing() {
    let hub = LXAssembly.LXGramSupplyHub()
    #expect(hub.mountedSuppliers.isEmpty)
    #expect(!hub.hasGrams(["ㄅ"], filterType: []))
    #expect(hub.queryGrams(["ㄅ"], filterType: []).isEmpty)
    #expect(hub.queryAssociatedPhrasesAsGrams((keyArray: ["ㄅ"], value: "甲"), anterior: nil, filterType: []) == nil)
  }

  @Test
  func testConcatenationFollowsMountOrder() {
    let hub = LXAssembly.LXGramSupplyHub()
    let first = StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)],
    ])
    let second = StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [Homa.Gram(keyArray: ["ㄅ"], current: "乙", probability: -1)],
    ])
    hub.mount(first)
    hub.mount(second)
    #expect(hub.queryGrams(["ㄅ"], filterType: []).map(\.current) == ["甲", "乙"])
    hub.concatFlags = .sort
    #expect(hub.queryGrams(["ㄅ"], filterType: []).map(\.current) == ["乙", "甲"])
  }

  @Test
  func testDeduplicationAcrossSuppliers() {
    let hub = LXAssembly.LXGramSupplyHub(concatFlags: .deduplicate)
    let first = StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)],
    ])
    let second = StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [
        Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -9),
        Homa.Gram(keyArray: ["ㄅ"], current: "乙", probability: -1),
      ],
    ])
    hub.mount(first)
    hub.mount(second)
    let served = hub.queryGrams(["ㄅ"], filterType: [])
    #expect(served.map(\.current) == ["甲", "乙"])
    #expect(served.first?.probability == -3)
  }

  @Test
  func testAvailabilityIsLogicalOrAcrossSuppliers() {
    let hub = LXAssembly.LXGramSupplyHub()
    let knowing = StubGramSupplier(gramsByKeyChain: [
      "ㄅ-ㄆ": [Homa.Gram(keyArray: ["ㄅ", "ㄆ"], current: "丙", probability: -1)],
    ])
    hub.mount(knowing)
    #expect(hub.hasGrams(["ㄅ", "ㄆ"], filterType: []))
    #expect(!hub.hasGrams(["ㄅ", "ㄇ"], filterType: []))
    #expect(knowing.hasGramsCallCount == 2)
  }

  @Test
  func testPartiallyMatchedKeysAreAggregated() {
    let hub = LXAssembly.LXGramSupplyHub()
    hub.mount(StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -1)],
    ]))
    hub.mount(StubGramSupplier(gramsByKeyChain: [
      "ㄆ": [Homa.Gram(keyArray: ["ㄆ"], current: "乙", probability: -1)],
    ]))
    var collected: Set<[String]> = []
    _ = hub.queryGrams(["ㄅ"], filterType: [], partiallyMatch: true) { collected.formUnion($0) }
    #expect(collected == [["ㄅ"]])
    var collectedViaCheck: Set<[String]> = []
    _ = hub.hasGrams(["ㄆ"], filterType: [], partiallyMatch: true) { collectedViaCheck.formUnion($0) }
    #expect(collectedViaCheck == [["ㄆ"]])
  }

  @Test
  func testFilterTypeAndPartialMatchAreForwarded() {
    let hub = LXAssembly.LXGramSupplyHub()
    let stub = StubGramSupplier(gramsByKeyChain: [
      "ㄅ": [Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -1)],
    ])
    hub.mount(stub)
    _ = hub.queryGrams(["ㄅ"], filterType: .cns, partiallyMatch: true)
    #expect(stub.lastFilterType == .cns)
    #expect(stub.lastPartiallyMatch == true)
    _ = hub.queryGrams(["ㄅ"], filterType: .symbolPhrases)
    #expect(stub.lastFilterType == .symbolPhrases)
    #expect(stub.lastPartiallyMatch == false)
  }

  @Test
  func testAssociatedPhrasesAreConcatenated() {
    let hub = LXAssembly.LXGramSupplyHub()
    hub.mount(StubGramSupplier(associatedPhrases: [
      Homa.Gram(keyArray: ["ㄅ", "ㄆ"], current: "甲乙", probability: -1),
    ]))
    hub.mount(StubGramSupplier(associatedPhrases: nil))
    let previous = (keyArray: ["ㄅ"], value: "甲")
    let served = hub.queryAssociatedPhrasesAsGrams(previous, anterior: nil, filterType: [])
    #expect(served?.map(\.current) == ["甲乙"])
    #expect(hub.queryAssociatedPhrasesPlain(previous, anterior: nil, filterType: [])?.map(\.value) == ["乙"])
  }

  @Test
  func testUnmountAllBumpsGeneration() {
    let hub = LXAssembly.LXGramSupplyHub()
    let start = hub.generation
    hub.mount(StubGramSupplier())
    #expect(hub.generation == start + 1)
    hub.unmountAll()
    #expect(hub.mountedSuppliers.isEmpty)
    #expect(hub.generation == start + 2)
    hub.unmountAll()
    #expect(hub.generation == start + 2)
  }

  @Test
  func testFactorySupplierServesRawTrieGrams() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData))
    let supplier = LXAssembly.LXFactoryGramSupplier()
    let key: [String] = ["ㄉㄢˋ", "ㄍㄠ"]
    #expect(supplier.hasGrams(key, filterType: .chs))
    let served = supplier.queryGrams(key, filterType: .chs)
    #expect(served.contains { $0.current == "蛋糕" && $0.probability == -4.072 })
    #expect(served.allSatisfy { $0.keyArray == key })
    LXAssembly.LXFacade.disconnectFactoryDictionary()
    #expect(!supplier.hasGrams(key, filterType: .chs))
    #expect(supplier.queryGrams(key, filterType: .chs).isEmpty)
  }
}
