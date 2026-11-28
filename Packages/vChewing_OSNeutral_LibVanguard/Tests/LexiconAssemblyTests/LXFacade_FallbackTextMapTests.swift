// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing
import TrieKit

@testable import LexiconAssembly

/// 主辭典缺某個 table 時，該 table 之查詢才回退到第二實例。
@Suite(.serialized)
struct LXFacadeFallbackTextMapTests {
  // MARK: Internal

  @Test("[LexiconAssembly] Primary table wins; no per-key fallback when the table exists")
  func testPrimaryTableWinsWithoutPerKeyFallback() throws {
    let instance = try makeInstance(isCHS: true)
    let presentKey = instance.factoryCoreUnigramsFor(
      key: "ㄐㄧㄚˇ",
      keyArray: ["ㄐㄧㄚˇ"]
    )
    #expect(presentKey.map(\.current) == ["假"])

    // 副本 B 有 CHS table（只是「ㄨˇ」沒有 CHS 條目）⇒ 不回退、結果為空。
    let missingKey = instance.factoryCoreUnigramsFor(
      key: "ㄨˇ",
      keyArray: ["ㄨˇ"]
    )
    #expect(missingKey.isEmpty)
  }

  @Test("[LexiconAssembly] Missing table falls back to the bundled instance")
  func testMissingTableFallsBack() throws {
    let instance = try makeInstance(isCHS: false)
    let jia = instance.factoryCoreUnigramsFor(
      key: "ㄐㄧㄚˇ",
      keyArray: ["ㄐㄧㄚˇ"]
    )
    // 副本 B 沒有 CHT table ⇒ 整張表回退到副本 A。
    #expect(jia.map(\.current) == ["甲"])
    let yi = instance.factoryCoreUnigramsFor(
      key: "ㄧˇ",
      keyArray: ["ㄧˇ"]
    )
    #expect(yi.map(\.current) == ["乙"])
  }

  @Test("[LexiconAssembly] CNS table falls back independently")
  func testSupplementalTableFallsBack() throws {
    let instance = try makeInstance(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = true
    }
    let cnsGrams = instance.supplementalCNSAndGBEXUnigramsFor(
      key: "ㄐㄧㄚˇ",
      keyArray: ["ㄐㄧㄚˇ"]
    )
    #expect(cnsGrams.map(\.current).sorted() == ["甲"])
    #expect(instance.factory.trie(for: .cns) === instance.factory.fallbackTrie)
    #expect(instance.factory.trie(for: .chs) === instance.factory.trie)
  }

  @Test("[LexiconAssembly] Reverse lookup merges the primary and fallback readings")
  func testReverseLookupMerges() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    FactoryDictionary.shared.trie = try VanguardTrie.TextMapTrie(data: Data(externalMap.utf8))
    FactoryDictionary.shared.fallbackTrie = try VanguardTrie.TextMapTrie(data: Data(bundledMap.utf8))

    #expect(LXAssembly.LXFacade.getFactoryReverseLookupData(with: "甲") == ["ㄐㄧㄚˇ"])
    #expect(LXAssembly.LXFacade.getFactoryReverseLookupData(with: "假") == ["ㄐㄧㄚˇ"])
    #expect(LXAssembly.LXFacade.getFactoryReverseLookupData(with: "無") == nil)
  }

  // MARK: Private

  /// 副本 A（bundled）：CHT 與 CNS 俱全，CHS 有兩個鍵。
  private let bundledMap = """
  #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
  VERSION\t2.0
  TYPE\tTYPING
  READING_SEPARATOR\t-
  ENTRY_COUNT\t5
  KEY_COUNT\t3
  DEFAULT_PROB_5\t-5
  DEFAULT_PROB_6\t-5
  DEFAULT_PROB_7\t-11
  #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
  >5\t甲
  >6\t甲
  >7\t甲
  >6\t乙
  >5\t戊
  #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
  ㄐㄧㄚˇ\t0\t3
  ㄧˇ\t3\t1
  ㄨˇ\t4\t1
  """

  /// 副本 B（external）：只有 CHS table。
  private let externalMap = """
  #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
  VERSION\t2.0
  TYPE\tTYPING
  READING_SEPARATOR\t-
  ENTRY_COUNT\t2
  KEY_COUNT\t2
  DEFAULT_PROB_5\t-5
  #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
  @-5\t假\t\u{7}
  >5\t丙
  #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
  ㄐㄧㄚˇ\t0\t1
  ㄧˇ\t1\t1
  """

  private func makeInstance(isCHS: Bool) throws -> LXAssembly.LXFacade {
    let factory = FactoryDictionary()
    factory.trie = try VanguardTrie.TextMapTrie(data: Data(externalMap.utf8))
    factory.fallbackTrie = try VanguardTrie.TextMapTrie(data: Data(bundledMap.utf8))
    let instance = LXAssembly.LXFacade(isCHS: isCHS, factory: factory)
    instance.setOptions { config in
      config.alwaysSupplyETenDOSUnigrams = false
      config.isSymbolEnabled = false
    }
    return instance
  }
}
