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
/// （勿手改）。Phase 331 起它含 `phrases-ngram-cht.txt` 烘進來的下列兩條條目，
/// 兩者同源（同一批 zh.wikipedia 分詞語料）、只差在鏈長：
///   - `館\t-1.642\t6\t書`（bigram：前文「書」；分母取 count(書)，legacy）
///   - `館\t-0.362\t6\t圖|書`（trigram：前文「書」、前前文「圖」；分母取 count(圖,書)）
///
/// 兩者皆為 `log10(e^(1/3−1) × count / 分母)` 之值，`scale = e^(1/3−1) = 0.51342`。
/// bigram 沿用 count(前一個詞) 作分母（P331 僅修正 trigram 的分母：改取完整前文
/// count(圖,書)，故 trigram 之分數必然高於同源的 bigram）。
///
/// 示範詞特意選「館」：其讀音 `ㄍㄨㄢˇ` 下另有「管／官」等單元圖候選，故「館」能否
/// 勝出，完全取決於前文是否為「(圖)書」——這正是 multigram 條目存在的理由。
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

    let grams = instance.unigramsFor(keyArray: ["ㄍㄨㄢˇ"])
    let bigram = grams.first { $0.current == "館" && $0.previous == "書" && $0.anterior == nil }
    #expect(bigram != nil, "TextMap 的 bigram 條目必須以帶 previous 的 Gram 形式抵達 LXFacade。")
    #expect(bigram?.anterior == nil)

    let trigram = grams.first { $0.current == "館" && $0.previous == "書" && $0.anterior == "圖" }
    #expect(trigram != nil, "TextMap 的 trigram 條目必須保留 previous 與 anterior。")
    #expect(trigram?.anterior == "圖")
  }
}
