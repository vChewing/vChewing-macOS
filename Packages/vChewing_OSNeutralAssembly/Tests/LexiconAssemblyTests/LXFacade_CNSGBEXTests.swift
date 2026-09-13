// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
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

  // MARK: Private

  private static let fengKey: [String] = ["ㄈㄥ"]
  private static let cnsOnlyChar = "㐽"
  private static let gbexOnlyChar = "𫲸"
}
