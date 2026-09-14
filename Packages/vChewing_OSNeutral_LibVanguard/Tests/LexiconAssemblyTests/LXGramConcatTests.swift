// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import Testing

@testable import LexiconAssembly

// MARK: - LXGramConcatTests

@Suite(.serialized)
struct LXGramConcatTests {
  @Test
  func testAvailabilityCheckResultsAreLogicalOr() {
    #expect(!LXAssembly.concatGramAvailabilityCheckResults {})
    #expect(!LXAssembly.concatGramAvailabilityCheckResults { false })
    #expect(!LXAssembly.concatGramAvailabilityCheckResults { nil })
    #expect(!LXAssembly.concatGramAvailabilityCheckResults { false; nil })
    #expect(LXAssembly.concatGramAvailabilityCheckResults { true })
    #expect(LXAssembly.concatGramAvailabilityCheckResults { false; nil; true })
    #expect(LXAssembly.concatGramAvailabilityCheckResults { false; true })
  }

  @Test
  func testQueryResultsWithoutFlagsKeepMountOrder() {
    let first = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)
    let second = Homa.Gram(keyArray: ["ㄅ"], current: "乙", probability: -1)
    let third = Homa.Gram(keyArray: ["ㄅ", "ㄆ"], current: "丙", probability: -9)
    let concatenated = LXAssembly.concatGramQueryResults {
      [first]
      nil
      [second, third]
    }
    #expect(concatenated?.map(\.current) == ["甲", "乙", "丙"])
  }

  @Test
  func testQueryResultsReturnNilWhenNothingIsServed() {
    #expect(LXAssembly.concatGramQueryResults {} == nil)
    #expect(LXAssembly.concatGramQueryResults { nil; nil } == nil)
    #expect(LXAssembly.concatGramQueryResults { []; nil } == nil)
  }

  @Test
  func testSortOrdersBySegmentCountThenReadingThenProbability() {
    let shortHigh = Homa.Gram(keyArray: ["ㄅ"], current: "短高", probability: -1)
    let shortLow = Homa.Gram(keyArray: ["ㄅ"], current: "短低", probability: -5)
    let long = Homa.Gram(keyArray: ["ㄅ", "ㄆ"], current: "長", probability: -8)
    let laterReading = Homa.Gram(keyArray: ["ㄆ"], current: "後讀音", probability: -2)
    let sorted = LXAssembly.concatGramQueryResults(flags: .sort) {
      [shortHigh]
      [laterReading]
      [long]
      [shortLow]
    }
    #expect(sorted?.map(\.current) == ["長", "短高", "短低", "後讀音"])
    #expect(LXAssembly.GramConcatFlags.all.contains(.sort))
  }

  @Test
  func testDeduplicateKeepsFirstOccurrenceByIdentity() {
    let original = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)
    let sameIdentityLowerScore = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -8)
    let otherValue = Homa.Gram(keyArray: ["ㄅ"], current: "乙", probability: -1)
    let deduplicated = LXAssembly.concatGramQueryResults(flags: .deduplicate) {
      [original, otherValue]
      [sameIdentityLowerScore]
    }
    #expect(deduplicated?.count == 2)
    #expect(deduplicated?.map(\.current) == ["甲", "乙"])
    #expect(deduplicated?.first?.probability == -3)
  }

  @Test
  func testDeduplicateTreatsPreviousAsPartOfIdentity() {
    let bare = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)
    let contextual = Homa.Gram(keyArray: ["ㄅ"], current: "甲", previous: "乙", probability: -3)
    let deduplicated = LXAssembly.concatGramQueryResults(flags: .deduplicate) {
      [bare]
      [contextual]
    }
    #expect(deduplicated?.count == 2)
  }

  @Test
  func testForbiddenHashesFilterAndSuppressDeduplication() {
    let first = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)
    let duplicated = Homa.Gram(keyArray: ["ㄅ"], current: "甲", probability: -3)
    let kept = Homa.Gram(keyArray: ["ㄅ"], current: "乙", probability: -1)
    let forbidden: Set<Int> = [LXAssembly.makeGramIdentityHash(kept)]
    let filtered = LXAssembly.concatGramQueryResults(
      flags: [.sort, .deduplicate],
      forbiddenKeyValueHashes: forbidden
    ) {
      [first]
      [duplicated, kept]
    }
    // forbidden 非空時，以該集合為唯一過濾依據，不再另行去重。
    #expect(filtered?.map(\.current) == ["甲", "甲"])
  }

  @Test
  func testIdentityHashIgnoresProbability() {
    let low = Homa.Gram(keyArray: ["ㄅ"], current: "甲", previous: "乙", probability: -9)
    let high = Homa.Gram(keyArray: ["ㄅ"], current: "甲", previous: "乙", probability: -1)
    #expect(LXAssembly.makeGramIdentityHash(low) == LXAssembly.makeGramIdentityHash(high))
    #expect(
      LXAssembly.makeGramIdentityHash(keyArray: ["ㄅ"], value: "甲", previous: "乙")
        == LXAssembly.makeGramIdentityHash(low)
    )
  }
}
