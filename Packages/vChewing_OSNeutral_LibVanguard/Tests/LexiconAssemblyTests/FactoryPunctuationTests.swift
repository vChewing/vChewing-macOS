// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Shared
import Testing

@testable import LexiconAssembly

@Suite("原廠標點子模組")
struct FactoryPunctuationTests {
  @Test("共享實例承接資料檔")
  func sharedInstance() {
    let punctuation = LXAssembly.FactoryPunctuation.shared
    #expect(!punctuation.isEmpty)
    #expect(punctuation.keyCount == 223)
    #expect(punctuation.hasUnigramsFor(keyArray: ["_punct_["]))
    #expect(punctuation.unigramsFor(keyArray: ["_punct_["]).count == 13)
    #expect(punctuation.unigramsFor(keyArray: ["_punct_["]).contains { $0.current == "[" })
    #expect(punctuation.unigramsFor(keyArray: ["_punct_["]).contains { $0.current == "【" })
    #expect(!punctuation.hasUnigramsFor(keyArray: ["_half_punct_"]))
  }

  @Test("原廠辭典無標點時由子模組補上")
  func facadeFallback() {
    let facade = LXAssembly.LXFacade(isCHS: false, factory: FactoryDictionary())
    #expect(facade.unigramsFor(keyArray: ["_punct_["]).count == 13)
    #expect(facade.lxQuerier.hasGrams(for: ["_punct_["]))
    #expect(facade.unigramsFor(keyArray: ["_punct_["]).contains { $0.current == "【" })
  }

  @Test("可注入自訂資料")
  func injectedRecords() {
    let punctuation = LXAssembly.FactoryPunctuation(records: [
      .init(key: "_punct_", value: "、"),
      .init(key: "_punct_", value: "。"),
    ])
    #expect(punctuation.keyCount == 1)
    #expect(punctuation.unigramsFor(keyArray: ["_punct_"]).count == 2)
    #expect(punctuation.hasUnigramsFor(keyArray: ["_punct_"]))
    #expect(!punctuation.hasUnigramsFor(keyArray: ["_punct_[", "_punct_]"]))
  }
}
