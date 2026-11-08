// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly

/// 使用者 n-gram 列穿過 `LXFacade` 之三條契約（P335）：
/// ① 單音節加冕只及於單元圖——n-gram 列之分數與前文原樣穿過；
/// ② 同值之單元圖列與 n-gram 列於 `consolidate(filter:)` 之後並存；
/// ③ 簡拼整詞查詢（無語境）不得收錄使用者 n-gram 列。
private func makeFacade(userData: String) -> LXAssembly.LXFacade {
  let store = InMemoryUserDataLocator()
  let url = URL(fileURLWithPath: "/vChewing-UserNGramTest/\(UUID().uuidString)/userdata-cht.txt")
  #expect((try? store.write(Data(userData.utf8), to: url)) != nil)
  let facade = LXAssembly.LXFacade(isCHS: false, locator: store)
  facade.setOptions { config in
    config.isCNSEnabled = false
    config.isSymbolEnabled = false
    config.allowRescoringSingleKanjiCandidates = true
    config.fetchSuggestionsFromPerceptionOverrideModel = false
  }
  facade.loadUserPhrasesData(path: url.path, filterPath: nil, async: false)
  return facade
}

// MARK: - LXFacadeUserNGramTests

@Suite(.serialized)
struct LXFacadeUserNGramTests {
  @Test
  func singleSyllableNGramKeepsAuthoredScoreAndContext() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    #expect(
      LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    let facade = makeFacade(userData: "在 ㄗㄞˋ -0.1 #NGRAM:這樣\n")
    let grams = facade.unigramsFor(keyArray: ["ㄗㄞˋ"])
    let target = grams.first { $0.current == "在" && $0.previous == "這樣" }
    #expect(target != nil, "單音節 n-gram 列須帶前文抵達 façade。")
    #expect(target?.anterior == nil)
    #expect(target?.chainLength == 2)
    // 加冕（`topScore + 0.000114514`）不得改寫 n-gram 列之分數：
    // 原廠「在」為 −5.009，若被改寫會落到約 −5.0089。
    #expect(abs((target?.probability ?? 0) - -0.1) < 1e-9)
  }

  @Test
  func userUnigramAndNGramRowCoexist() throws {
    let facade = makeFacade(userData: """
    測字 ㄘㄜˋ-ㄗˋ -3.0
    測字 ㄘㄜˋ-ㄗˋ -1.0 #NGRAM:某某
    """)
    let grams = facade.unigramsFor(keyArray: ["ㄘㄜˋ", "ㄗˋ"]).filter { $0.current == "測字" }
    #expect(grams.count == 2, "同值之單元圖列與 n-gram 列於 consolidate 之後須並存。")
    #expect(grams.contains { $0.isUnigram })
    #expect(grams.contains { $0.previous == "某某" && $0.anterior == nil })
  }

  /// 純 n-gram 列係「語境偏好」、不是「頻率已釘」：不得令該配對被誤判為控頻
  /// （否則該字之狂拼 α 自動套用會被無故關掉，P266）。
  @Test
  func nGramRowDoesNotCountAsFrequencyControlledPair() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    #expect(
      LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    // 原廠側確有 (ㄗㄞˋ, 在) 此一配對（樣本之「在」為 −5.009）。
    let withNGram = makeFacade(userData: "在 ㄗㄞˋ -0.1 #NGRAM:這樣\n")
    #expect(!withNGram.isFrequencyControlledPair((keyArray: ["ㄗㄞˋ"], value: "在")))

    // 對照組：寫成單元圖列者仍算控頻。
    let withUnigram = makeFacade(userData: "在 ㄗㄞˋ -0.1\n")
    #expect(withUnigram.isFrequencyControlledPair((keyArray: ["ㄗㄞˋ"], value: "在")))
  }

  @Test
  func abbreviatedLookupExcludesUserNGramRow() throws {
    let facade = makeFacade(userData: """
    測字 ㄘㄜˋ-ㄗˋ -3.0
    測字 ㄘㄜˋ-ㄗˋ -0.5 #NGRAM:某某
    """)
    let chopped = facade.abbreviatedWordCandidates(keysChopped: ["ㄘㄜˋ", "ㄗˋ"])
    #expect(chopped.allSatisfy { $0.isUnigram })
    let matched = chopped.filter { $0.current == "測字" }
    #expect(matched.count == 1, "簡拼查詢每值至多一筆（單元圖者）。")
    #expect(abs((matched.first?.probability ?? 0) - -3.0) < 1e-9, "應取單元圖之分數，而非 n-gram 之 −0.5。")
  }
}
