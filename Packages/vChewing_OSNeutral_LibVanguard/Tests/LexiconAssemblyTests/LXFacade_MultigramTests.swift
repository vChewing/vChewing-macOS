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

  /// 繁簡兩軌不得串軌：同一個「繁簡共用漢字」在兩軌各有一筆 n-gram 條目時，
  /// 各軌只能取到自己那一筆，且分數必須是自己那一筆的分數。
  ///
  /// 出貨語料裡的 `碳` 剛好兩軌同值、同前文、同分母、同分數（只差型別欄的 5／6），
  /// 故任何一軌被換掉都看不出來。本用例於記憶體中改寫樣本，讓兩軌分數不同
  /// （繁體軌 −1.25、簡體軌 −0.36），再分別以 `isCHS = false`／`true` 查同一個讀音。
  /// 只要載入端或取用端拿錯型別，這裡必然失敗。
  @Test
  func testSharedHanziStaysInItsOwnLane() {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    // Windows 的 checkout 會把資源檔換成 CRLF（該倉無 `.gitattributes` 時尤然）。
    // 這裡先正規化成 LF，否則下面的「整行相等」比對會因為行尾多一個 `\r` 而落空。
    let normalizedSample = LXATestsData.textMapTestCoreLXData
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    var lines = normalizedSample.components(separatedBy: "\n")

    let traditionalRow = "碳\t-0.36\t6\t氧|化"
    let simplifiedRow = "碳\t-0.36\t5\t氧|化"
    guard let traditionalIndex = lines.firstIndex(of: traditionalRow) else {
      Issue.record("測試樣本裡必須有繁體軌的「碳」trigram 條目（型別 6）。")
      return
    }
    guard let simplifiedIndex = lines.firstIndex(of: simplifiedRow) else {
      Issue.record("測試樣本裡必須有簡體軌的「碳」trigram 條目（型別 5）。")
      return
    }

    // 只改分數、不動型別與前文，故「哪一軌」完全由第三欄的 5／6 決定。
    lines[traditionalIndex] = "碳\t-1.25\t6\t氧|化"
    lines[simplifiedIndex] = "碳\t-0.36\t5\t氧|化"
    let patchedTextMap = lines.joined(separator: "\n")

    let traditionalInstance = LXAssembly.LXFacade(isCHS: false)
    let simplifiedInstance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: patchedTextMap),
      "改寫後的 TextMap 必須仍能通過嚴格載入驗證。"
    )

    for instance in [traditionalInstance, simplifiedInstance] {
      instance.setOptions { config in
        config.isCNSEnabled = false
        config.isSymbolEnabled = false
        config.fetchSuggestionsFromPerceptionOverrideModel = false
        config.bypassUserPhrasesData = true
      }
    }

    func contextCarryingCarbonProbabilities(_ instance: LXAssembly.LXFacade) -> [Double] {
      instance.unigramsFor(keyArray: ["ㄊㄢˋ"])
        .filter { $0.current == "碳" && $0.previous == "化" && $0.anterior == "氧" }
        .map(\.probability)
    }

    let traditionalProbabilities = contextCarryingCarbonProbabilities(traditionalInstance)
    let simplifiedProbabilities = contextCarryingCarbonProbabilities(simplifiedInstance)

    #expect(
      traditionalProbabilities.count == 1,
      "繁體模式在「氧 化」前文鏈下只該看到一筆「碳」，實得 \(traditionalProbabilities.count) 筆。"
    )
    #expect(
      simplifiedProbabilities.count == 1,
      "簡體模式在「氧 化」前文鏈下只該看到一筆「碳」，實得 \(simplifiedProbabilities.count) 筆。"
    )
    #expect(
      abs((traditionalProbabilities.first ?? 0) - -1.25) < 0.001,
      "繁體模式必須取用型別 6 的那一筆（−1.25），實得 \(traditionalProbabilities.first ?? 0)。"
    )
    #expect(
      abs((simplifiedProbabilities.first ?? 0) - -0.36) < 0.001,
      "簡體模式必須取用型別 5 的那一筆（−0.36），實得 \(simplifiedProbabilities.first ?? 0)。"
    )
  }
}
