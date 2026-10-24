// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly
@testable import TrieKit

/// Phase 324：TextMap 的 multigram（bigram／trigram）條目必須能穿過 LXFacade，
/// 以「帶前驗詞鏈的 Homa.Gram」形式抵達組句引擎。
///
/// 測試樣本（`vanguardTextMap_test.txtMap`）自 Phase 324 起為 `VERSION 2.0`，
/// 且整份由 `vChewing-VanguardLexicon` 的 `create_tiny_sample_txtMap.sh` 產出後原樣拷入
/// （勿手改）。它含有 `phrases-ngram-cht.txt` 烘進來的下列條目：
///   - `再\t-3.405\t6\t要`（bigram：前文「要」）
///   - `再\t-3.502\t6\t不|要`（trigram：前文「要」、前前文「不」）
///
/// 這兩個分數是條件機率 `p(再｜要)` 的 log10 值：分母是「要」的詞頻（樣本內約 6528），
/// 不是 `_NORM`（374388831.9686408）。Phase 324 之前存的是無條件機率，那種寫法下
/// `count(要,再) ≤ count(再)` 恆成立，bigram 永遠贏不過自己的 unigram，故改為條件機率。
///
/// 示範詞特意選「在／再」這組同音歧義：`ㄗㄞˋ` 下「在」是 unigram（-5.009），
/// 「再」只有帶前文的條目；於是 `ㄅㄨˋ-ㄧㄠˋ-ㄗㄞˋ` 的末字選誰，完全由這條 bigram 決定。
@Suite(.serialized)
struct LXFacadeMultigramTests {
  @Test
  func testTextMapMultigramReachesHomaGrams() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: false)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    // 本用例只驗「原廠 TextMap 的 multigram 能否穿過 LXFacade」。POM 同樣會供應帶前驗詞的
    // gram，故必須顯式關掉：否則測到的可能是使用者習慣記憶而非詞庫，且會隨執行順序漂移。
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.fetchSuggestionsFromPerceptionOverrideModel = false
      config.bypassUserPhrasesData = true
    }

    let bigramGrams = instance.unigramsFor(keyArray: ["ㄗㄞˋ"])
    let bigram = bigramGrams.first { $0.current == "再" && $0.previous == "要" }
    #expect(bigram != nil, "TextMap 的 bigram 條目必須以帶 previous 的 Gram 形式抵達 LXFacade。")
    #expect(bigram?.anterior == nil)

    let trigramGrams = instance.unigramsFor(keyArray: ["ㄗㄞˋ"])
    let trigram = trigramGrams.first { $0.current == "再" && $0.previous == "要" && $0.anterior == "不" }
    #expect(trigram != nil, "TextMap 的 trigram 條目必須保留 previous 與 anterior。")
    #expect(trigram?.anterior == "不")
  }
}
