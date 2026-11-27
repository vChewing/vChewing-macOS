// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly

/// CNS+GBEX 模式的行為測試。
/// 測試樣本（vanguardTextMap_test.txtMap）中讀音「ㄈㄥ」同時具備：
///   - CNS（type 7）專屬字「㐽」（不存在於 GBEX 與原廠核心）；
///   - GBEX（type 11）專屬字「𫲸」（不存在於 CNS 與原廠核心）。
/// 藉此驗證 CNS 開關開啟時的補給與排序、以及開關關閉時的隱藏。
@Suite(.serialized)
struct LXFacadeCNSGBEXTests {
  // MARK: Internal

  @Test
  func testCNSEnabledSuppliesGBEXAfterCNSInCHT() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: false)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = false
    }

    let grams = instance.unigramsFor(keyArray: Self.fengKey)
    let indexOfCNS = grams.firstIndex { $0.current == Self.cnsOnlyChar }
    let indexOfGBEX = grams.firstIndex { $0.current == Self.gbexOnlyChar }

    // 兩個補充來源都應出現。
    #expect(indexOfCNS != nil)
    #expect(indexOfGBEX != nil)
    // 繁體中文模式：GBEX 排序在 CNS 之後。
    #expect(indexOfGBEX! > indexOfCNS!)
    // 兩者基礎權重相同（皆 -11）。
    let probCNS = grams.first { $0.current == Self.cnsOnlyChar }?.probability
    let probGBEX = grams.first { $0.current == Self.gbexOnlyChar }?.probability
    #expect(probCNS == -11.0)
    #expect(probGBEX == -11.0)
  }

  @Test
  func testCNSEnabledSuppliesGBEXBeforeCNSInCHS() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = false
    }

    let grams = instance.unigramsFor(keyArray: Self.fengKey)
    let indexOfCNS = grams.firstIndex { $0.current == Self.cnsOnlyChar }
    let indexOfGBEX = grams.firstIndex { $0.current == Self.gbexOnlyChar }
    #expect(indexOfCNS != nil)
    #expect(indexOfGBEX != nil)
    // 簡體中文模式：GBEX 優先於 CNS。
    #expect(indexOfGBEX! < indexOfCNS!)
  }

  @Test
  func testCNSDisabledSuppressesBothCNSAndGBEX() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: false)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
    }

    let grams = instance.unigramsFor(keyArray: Self.fengKey)
    #expect(grams.contains { $0.current == Self.cnsOnlyChar } == false)
    #expect(grams.contains { $0.current == Self.gbexOnlyChar } == false)
  }

  // MARK: - 補充供給上限（P368）

  /// 上限逐來源計（CNS、GBEX 各一份額度），且只截補充資料、不動原廠核心。
  @Test
  func testSupplyLimitCapsCNSAndGBEXPerSource() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeCappedFixtureInstance()
    let unlimited = instance.unigramsFor(keyArray: Self.fengKey)
    #expect(Self.cnsValues(in: unlimited) == Self.fengCNSValues)
    #expect(Self.gbexValues(in: unlimited) == Self.fengGBEXValues)
    #expect(unlimited.contains { $0.current == Self.fengCoreChar })

    let capped = instance.unigramsFor(keyArray: Self.fengKey, partiallyMatch: false, supplyLimit: 2)
    #expect(Self.cnsValues(in: capped) == Array(Self.fengCNSValues.prefix(2)))
    #expect(Self.gbexValues(in: capped) == Array(Self.fengGBEXValues.prefix(2)))
    // 原廠核心不受上限影響。
    #expect(capped.contains { $0.current == Self.fengCoreChar })
  }

  /// 「&」連讀／替代讀音路徑：上限**跨各展開組合累計**，而非每組合各一份。
  @Test
  func testSupplyLimitAccumulatesAcrossChoppedCombinations() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeCappedFixtureInstance()
    let bucket: [Homa.PossibleKey] = [.multipleKeys([Self.fengKey[0], Self.feng2Key[0]])]

    let unlimited = instance.unigramsFor(keyArray: bucket, partiallyMatch: false)
    #expect(Self.cnsValues(in: unlimited).count == Self.fengCNSValues.count + Self.feng2CNSValues.count)

    let capped = instance.unigramsFor(keyArray: bucket, partiallyMatch: false, supplyLimit: 2)
    #expect(Self.cnsValues(in: capped).count == 2)
  }

  /// 上限係查詢語義之一維：同一鍵以不同上限取用時不得互撞快取。
  @Test
  func testSupplyLimitIsPartOfTheQueryCacheKey() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeCappedFixtureInstance()
    let narrow = instance.unigramsFor(keyArray: Self.fengKey, partiallyMatch: false, supplyLimit: 1)
    #expect(Self.cnsValues(in: narrow).count == 1)
    // 不限者緊接其後查詢，不得吃到上面那一份被截短的快取。
    let unlimited = instance.unigramsFor(keyArray: Self.fengKey)
    #expect(Self.cnsValues(in: unlimited) == Self.fengCNSValues)
    // 反向亦然：再一次以較寬之上限查詢，不得吃到「1」那一份。
    let wider = instance.unigramsFor(keyArray: Self.fengKey, partiallyMatch: false, supplyLimit: 3)
    #expect(Self.cnsValues(in: wider).count == 3)
  }

  /// 上限 0＝copilot 窗完全不取 CNS／GBEX（核心照舊）。
  @Test
  func testSupplyLimitZeroDropsSupplementalSupply() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeCappedFixtureInstance()
    let suppressed = instance.unigramsFor(keyArray: Self.fengKey, partiallyMatch: false, supplyLimit: 0)
    #expect(Self.cnsValues(in: suppressed).isEmpty)
    #expect(Self.gbexValues(in: suppressed).isEmpty)
    #expect(suppressed.contains { $0.current == Self.fengCoreChar })
  }

  // MARK: - 讀音過濾（僅傳回符合全字庫讀音者）

  /// 判準須以**每個元圖自身之讀音**為準，不得以「查詢之任一展開變體符合」放行。
  ///
  /// 病灶（P369）：替代讀音路徑原以 `expandedKeyArrays.contains(where:)` 判之 ⇒ 桶查詢
  /// （單一注音前綴之全體補全）只需**任何一個**變體符合即整批放行，故實機上 demote 恆為 0。
  @Test
  func testFilterUsesEachGramsOwnReadingInPlaceOfAnyVariant() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeReadingFilterFixtureInstance()
    // 未啟用過濾時，桶查詢照舊取原廠核心分數。
    let unfilteredBucket = instance.unigramsFor(keyArray: Self.boBucket, partiallyMatch: false)
    #expect(Self.score(of: Self.filteredChar, in: unfilteredBucket) == -4.5)

    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }
    // 「播」自身之讀音 ㄅㄛ 之 CNS 值集（僅「玻」）不含「播」⇒ 應 demote 至 −9.5；
    // 舊制因查詢另含 ㄅㄛˋ（其值集有「播」）而放行、維持 −4.5。
    let filteredBucket = instance.unigramsFor(keyArray: Self.boBucket, partiallyMatch: false)
    #expect(Self.score(of: Self.filteredChar, in: filteredBucket) == -9.5)
    // 單一讀音之查詢語義不變（同一結論）。
    let filteredExact = instance.unigramsFor(keyArray: ["ㄅㄛ"])
    #expect(Self.score(of: Self.filteredChar, in: filteredExact) == -9.5)
  }

  /// 單音節取 demote（不剔除）、多讀音詞組取剔除——段數判準以元圖自身為準。
  @Test
  func testFilterDemotesUnigramsAndDropsPhrasesByOwnSegmentCount() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeReadingFilterFixtureInstance()
    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }

    // 單音節：「播」仍在清單內，只是沉到 −9.5（既有 UX 裁定：否則常用字會整批消失）。
    let exact = instance.unigramsFor(keyArray: ["ㄅㄛ"])
    #expect(Self.score(of: Self.filteredChar, in: exact) == -9.5)
    // 多讀音詞組：「播播」（ㄅㄛ-ㄅㄛ）整列剔除。
    let filteredPhrase = instance.unigramsFor(keyArray: Self.boBoPhraseKey)
    #expect(!filteredPhrase.map(\.current).contains(Self.filteredPhraseValue))
    instance.setOptions { config in
      config.filterNonCNSReadings = false
    }
    let unfilteredPhrase = instance.unigramsFor(keyArray: Self.boBoPhraseKey)
    #expect(unfilteredPhrase.map(\.current).contains(Self.filteredPhraseValue))
  }

  /// 笛卡爾積超預算時亦須過濾——舊制因需先展開組合而整段略過（靜默失效）。
  @Test
  func testFilterAppliesEvenWhenCartesianBudgetIsExceeded() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeReadingFilterFixtureInstance()
    // 5 個位置各 4 個替代讀音 ⇒ 4⁵ = 1,024 > 625（`kCartesianProductBudgetLimit`）。
    let longBucket: [Homa.PossibleKey] = Array(
      repeating: .multipleKeys(["ㄅㄚ", "ㄅㄚˊ", "ㄅㄚˇ", "ㄅㄚˋ"]),
      count: 5
    )
    instance.setOptions { config in
      config.filterNonCNSReadings = false
    }
    let unfilteredLong = instance.unigramsFor(keyArray: longBucket, partiallyMatch: false)
    #expect(unfilteredLong.map(\.current).contains(Self.overBudgetPhraseValue))
    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }
    let filteredLong = instance.unigramsFor(keyArray: longBucket, partiallyMatch: false)
    #expect(!filteredLong.map(\.current).contains(Self.overBudgetPhraseValue))
  }

  /// 同型之第二處（反側特有字之過濾）：原以「全部展開變體皆為反側特有」判之，超預算時
  /// `expandedKeyArrays` 為空 ⇒ `allSatisfy` 對空集合恆真 ⇒ 整批核心元圖被清空。
  @Test
  func testContradictoryModeFilterDoesNotWipeWhenCartesianBudgetIsExceeded() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = Self.makeReadingFilterFixtureInstance()
    instance.setOptions { config in
      config.filterFactoryKanjisOfNonCurrentInputMode = true
      config.filterNonCNSReadings = false
    }
    // 單一位置、650 個替代讀音 ⇒ 笛卡爾積 650 > 625（觸發超預算且仍走「單音節」分支）。
    let wideBucket: [Homa.PossibleKey] = [
      .multipleKeys(["ㄅㄚ", "ㄅㄚˊ", "ㄅㄚˇ", "ㄅㄚˋ"] + (0 ..< 646).map { "ㄅㄧ\($0)" }),
    ]
    let grams = instance.unigramsFor(keyArray: wideBucket, partiallyMatch: false)
    #expect(grams.map(\.current).contains("八"))
  }

  // MARK: Private

  private static let fengKey: [String] = ["ㄈㄥ"]
  private static let feng2Key: [String] = ["ㄈㄥˊ"]
  private static let fengCoreChar = "風"
  private static let fengCNSValues = ["㐽", "㑳", "㑶"]
  private static let fengGBEXValues = ["𫲸", "𫲹"]
  private static let feng2CNSValues = ["㑄", "㑅"]
  private static let cnsOnlyChar = "㐽"
  private static let gbexOnlyChar = "𫲸"

  private static let boBucket: [Homa.PossibleKey] = [.multipleKeys(["ㄅㄛ", "ㄅㄛˋ"])]
  private static let boBoPhraseKey: [String] = ["ㄅㄛ", "ㄅㄛ"]
  private static let filteredChar = "播"
  private static let filteredPhraseValue = "播播"
  private static let overBudgetPhraseValue = "八八八八八"

  /// 含 3 個 CNS、2 個 GBEX、1 個原廠核心字之夾具；另立一讀音供「跨組合累計」之驗證。
  ///
  /// 不掛在共用夾具 `vanguardTextMap_test.txtMap` 上：上限之驗證需要「同一讀音多於 2 個
  /// CNS 字」，而共用夾具之字數為其他測試所倚（且兩倉逐位元組同步）。
  private static func makeCappedFixtureInstance() -> LXAssembly.LXFacade {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t9
    KEY_COUNT\t2
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-9.9\t風\t風
    㐽\t-11\t7
    㑳\t-11\t7
    㑶\t-11\t7
    𫲸\t-11\t11
    𫲹\t-11\t11
    㑄\t-11\t7
    㑅\t-11\t7
    𫲺\t-11\t11
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄈㄥ\t0\t6
    ㄈㄥˊ\t6\t3
    """
    let instance = LXAssembly.LXFacade(isCHS: false)
    _ = LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: textMap)
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = false
      // 倚天候選序會把一大堆無關字灌進清單（且與本測試之計數無涉），關掉以聚焦。
      config.alwaysSupplyETenDOSUnigrams = false
    }
    return instance
  }

  /// 讀音過濾之夾具：兩個同族讀音（ㄅㄛ／ㄅㄛˋ）、一個同讀音重疊詞、一個五音節長詞。
  ///
  /// - ㄅㄛ 之 CNS 值集僅「玻」⇒ 其下的「播」不合規（舊制會被 ㄅㄛˋ 那一格放行）。
  /// - ㄅㄛˋ 之 CNS 值集為「播」⇒ 該讀音下合規。
  /// - ㄅㄚ 之 CNS 值集僅「巴」⇒ 「八八八八八」之五位皆不合規（供超預算之驗證）。
  private static func makeReadingFilterFixtureInstance() -> LXAssembly.LXFacade {
    let textMap = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t2.0
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t8
    KEY_COUNT\t5
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    @-4.5\t播\t播
    玻\t-11\t7
    @-4.2\t簸\t簸
    播\t-11\t7
    @-5.5\t播播\t播播
    @-4.5\t八\t八
    巴\t-11\t7
    @-6\t八八八八八\t八八八八八
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄅㄛ\t0\t2
    ㄅㄛˋ\t2\t2
    ㄅㄛ-ㄅㄛ\t4\t1
    ㄅㄚ\t5\t2
    ㄅㄚ-ㄅㄚ-ㄅㄚ-ㄅㄚ-ㄅㄚ\t7\t1
    """
    let instance = LXAssembly.LXFacade(isCHS: false)
    _ = LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: textMap)
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = false
      config.alwaysSupplyETenDOSUnigrams = false
    }
    return instance
  }

  private static func score(of value: String, in grams: [Homa.Gram]) -> Double? {
    grams.first { $0.current == value }?.probability
  }

  private static func cnsValues(in grams: [Homa.Gram]) -> [String] {
    orderedValues(in: grams, within: Set(fengCNSValues + feng2CNSValues))
  }

  private static func gbexValues(in grams: [Homa.Gram]) -> [String] {
    orderedValues(in: grams, within: Set(fengGBEXValues + ["𫲺"]))
  }

  private static func orderedValues(in grams: [Homa.Gram], within candidates: Set<String>) -> [String] {
    grams.map(\.current).filter { candidates.contains($0) }
  }
}
