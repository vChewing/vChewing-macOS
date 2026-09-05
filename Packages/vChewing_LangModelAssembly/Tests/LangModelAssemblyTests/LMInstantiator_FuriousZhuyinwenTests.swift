// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LMAssemblyMaterials4Tests
import Testing

@testable import LangModelAssembly

/// 狂拼（Furious Typing）啟用時抑制原廠注音文（zhuyinwen）資料的行為測試。
/// 測試樣本（vanguardTextMap_test.txtMap）中，讀音「ㄋㄟ-ㄋㄟ」的唯一注音文
/// 條目為「ㄋㄟㄋㄟ」（type 10）。
@Suite(.serialized)
struct LMInstantiatorFuriousZhuyinwenTests {
  // MARK: Internal

  @Test
  func testFactoryZhuyinwenPresentByDefault() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }

    let instance = LMAssembly.LMInstantiator(isCHS: true)
    #expect(
      LMAssembly.LMInstantiator
        .connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData)
    )
    // 未啟用狂拼時，原廠注音文（ㄋㄟㄋㄟ）應照常供應。
    #expect(instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })
  }

  @Test
  func testFuriousTypingSuppressesFactoryZhuyinwen() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }

    let instance = LMAssembly.LMInstantiator(isCHS: true)
    #expect(
      LMAssembly.LMInstantiator
        .connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData)
    )
    instance.setOptions { config in
      config.shouldSuppressFactoryZhuyinwenData = true
    }
    // 狂拼啟用時，來自原廠辭典（TextMapTrie）的注音文資料應被抑制。
    #expect(!instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })
  }

  // MARK: Private

  private static let boobsKey: [String] = ["ㄋㄟ", "ㄋㄟ"]
}
