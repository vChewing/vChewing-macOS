// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly
@testable import TrieKit

/// 狂拼簡拼整詞查詢（`abbreviatedWordCandidates`）之兩條契約。
///
/// 其一：該查詢**無語境**（只有逐位置前綴、沒有前文），故帶前驗詞鏈之條目一律不得進入——
/// 其分數是條件機率 P(詞｜前文)，在此無從求值。其二：其原廠資料源
/// （`factoryChoppedUnigramsFor`）之輸出須為**確定序**；該函式以 Dictionary 收尾、迭代序
/// 跨行程不保證，而本查詢係「先按詞值去重、後排序」，故次序不確定即令名次不可重現。
@Suite(.serialized)
struct LXFacadeFuriousAbbreviationTests {
  /// 「館」在測試樣本裡只有帶前文之條目（型別 C／D，型別碼 6），故它只會經由
  /// `factoryChoppedUnigramsFor` 以帶 `previous` 的形式出現；過濾之後應為空。
  @Test
  func abbreviatedLookupRejectsContextualGrams() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    #expect(
      LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    let instance = LXAssembly.LXFacade(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.bypassUserPhrasesData = true
    }

    // 前提：樣本必須真的含帶前文之條目，否則本用例測不到東西。
    let probeKey = ["ㄍㄨㄢˇ"]
    let rawFactory = instance.factoryChoppedUnigramsFor(
      keyArray: probeKey,
      entryType: .cht,
      partiallyMatch: false
    )
    #expect(
      rawFactory.contains { !$0.isUnigram },
      "測試樣本之「館」必須含帶前文之條目，否則本用例失去前提。"
    )

    let chopped = instance.abbreviatedWordCandidates(keysChopped: probeKey)
    #expect(chopped.allSatisfy { $0.isUnigram })
    #expect(chopped.isEmpty, "「館」在樣本裡只有帶前文之條目，過濾後應為空。")

    // 正控：確有單元圖之讀音仍照常出列，且同樣不含帶前文者。
    let zaiCandidates = instance.abbreviatedWordCandidates(keysChopped: ["ㄗㄞˋ"])
    #expect(!zaiCandidates.isEmpty)
    #expect(zaiCandidates.contains { $0.current == "在" })
    #expect(zaiCandidates.allSatisfy { $0.isUnigram })
  }

  /// 原廠 chopped 查詢之輸出序：機率降冪，同分按 (詞值, previous, anterior) 升冪。
  @Test
  func choppedFactoryQueryReturnsDeterministicOrder() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    #expect(
      LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    let instance = LXAssembly.LXFacade(isCHS: false)
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.bypassUserPhrasesData = true
    }

    let grams = instance.factoryChoppedUnigramsFor(
      keyArray: ["ㄕㄨˋ"],
      entryType: .cht,
      partiallyMatch: false
    )
    #expect(grams.count >= 5, "樣本之「ㄕㄨˋ」須有足夠條目，否則偶然有序之機率過高。")

    let expected = grams.sorted { lhs, rhs in
      if lhs.probability != rhs.probability { return lhs.probability > rhs.probability }
      if lhs.current != rhs.current { return lhs.current < rhs.current }
      if (lhs.previous ?? "") != (rhs.previous ?? "") {
        return (lhs.previous ?? "") < (rhs.previous ?? "")
      }
      return (lhs.anterior ?? "") < (rhs.anterior ?? "")
    }

    func identity(_ gram: Homa.Gram) -> String {
      "\(gram.current)\u{1}\(gram.previous ?? "")\u{1}\(gram.anterior ?? "")\u{1}\(gram.probability)"
    }

    #expect(grams.map(identity) == expected.map(identity))
  }
}
