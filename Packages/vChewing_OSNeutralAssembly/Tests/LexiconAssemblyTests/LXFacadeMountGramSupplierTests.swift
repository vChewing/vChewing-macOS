// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import Testing

@testable import LexiconAssembly

// MARK: - LXFacadeMountGramSupplierTests

@Suite(.serialized)
struct LXFacadeMountGramSupplierTests {
  @Test
  func testMountedSupplierFeedsQueryAndAvailability() {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
      LXAssembly.resetSharedState()
    }
    let instance = LXAssembly.LXFacade(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.alwaysSupplyETenDOSUnigrams = false
    }
    let key: [String] = ["ㄅㄅ", "ㄆㄆ"]
    // 無掛載來源時，非原廠辭典來源一無所獲。
    #expect(instance.mountedGramSuppliers.isEmpty)
    #expect(!instance.lxQuerier.hasGrams(for: key))
    #expect(instance.unigramsFor(keyArray: key).isEmpty)

    let stub = StubGramSupplier(gramsByKeyChain: [
      key.joined(separator: "-"): [
        Homa.Gram(keyArray: key, current: "測試詞", probability: -2.5),
      ],
    ])
    instance.mountGramSupplier(stub)
    #expect(instance.mountedGramSuppliers.count == 1)
    // 掛載之後，存在性與查詢結果皆涵蓋該來源（掛載異動亦已使快取失效）。
    #expect(instance.lxQuerier.hasGrams(for: key))
    #expect(instance.unigramsFor(keyArray: key).map(\.current) == ["測試詞"])
    #expect(stub.queryGramsCallCount > 0)
    #expect(stub.lastFilterType == [])
    #expect(stub.lastPartiallyMatch == false)

    instance.unmountAllGramSuppliers()
    #expect(instance.mountedGramSuppliers.isEmpty)
    #expect(!instance.lxQuerier.hasGrams(for: key))
    #expect(instance.unigramsFor(keyArray: key).isEmpty)
  }

  @Test
  func testMountedSuppliersAccumulateInMountOrder() {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
      LXAssembly.resetSharedState()
    }
    let instance = LXAssembly.LXFacade(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.alwaysSupplyETenDOSUnigrams = false
    }
    let key: [String] = ["ㄅㄅ", "ㄆㄆ"]
    instance.mountGramSupplier(StubGramSupplier(gramsByKeyChain: [
      key.joined(separator: "-"): [
        Homa.Gram(keyArray: key, current: "第一", probability: -3),
      ],
    ]))
    instance.mountGramSupplier(StubGramSupplier(gramsByKeyChain: [
      key.joined(separator: "-"): [
        Homa.Gram(keyArray: key, current: "第二", probability: -1),
      ],
    ]))
    #expect(instance.mountedGramSuppliers.count == 2)
    let served = instance.unigramsFor(keyArray: key).map(\.current)
    #expect(Set(served) == ["第一", "第二"])
  }

  @Test
  func testMountedSupplierReceivesPartialMatchFlag() {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
      LXAssembly.resetSharedState()
    }
    let instance = LXAssembly.LXFacade(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.alwaysSupplyETenDOSUnigrams = false
    }
    let key: [String] = ["ㄅㄅ", "ㄆㄆ"]
    let stub = StubGramSupplier()
    instance.mountGramSupplier(stub)
    _ = instance.unigramsFor(keyArray: key, partiallyMatch: true)
    #expect(stub.lastPartiallyMatch == true)
    _ = instance.unigramsFor(keyArray: key)
    #expect(stub.lastPartiallyMatch == false)
  }
}
