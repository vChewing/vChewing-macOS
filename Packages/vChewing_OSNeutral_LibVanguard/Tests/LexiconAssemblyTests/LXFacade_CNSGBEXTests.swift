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

  // MARK: Private

  private static let fengKey: [String] = ["ㄈㄥ"]
  private static let feng2Key: [String] = ["ㄈㄥˊ"]
  private static let fengCoreChar = "風"
  private static let fengCNSValues = ["㐽", "㑳", "㑶"]
  private static let fengGBEXValues = ["𫲸", "𫲹"]
  private static let feng2CNSValues = ["㑄", "㑅"]
  private static let cnsOnlyChar = "㐽"
  private static let gbexOnlyChar = "𫲸"

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
