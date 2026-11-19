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
  func testTextMapContextualGramsReachHomaGrams() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: false)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    // 本用例只驗「原廠 TextMap 的帶前文條目能否穿過 LXFacade」。POM 同樣會供應帶前驗詞的
    // gram，故必須顯式關掉：否則測到的可能是使用者習慣記憶而非詞庫，且會隨執行順序漂移。
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.fetchSuggestionsFromPerceptionOverrideModel = false
      config.bypassUserPhrasesData = true
    }

    let grams = instance.unigramsFor(keyArray: ["ㄍㄞˇ", "ㄉㄠˋ"])
    let contextual = grams.filter { $0.current == "改到" && $0.previous != nil }
    #expect(contextual.count == 2, "測試樣本之「改到」應有兩筆帶前文的條目。")
    #expect(
      Set(contextual.compactMap(\.previous)) == ["會議", "活動"],
      "帶前文條目之前文應為「會議」與「活動」。"
    )
    #expect(contextual.allSatisfy { $0.anterior == nil })
  }

  /// 繁簡兩軌不得串軌：同一個「繁簡共用詞」在兩軌各有一筆帶前文條目時，
  /// 各軌只能取到自己那一筆，且分數必須是自己那一筆的分數。
  @Test
  func testSharedHanziStaysInItsOwnLane() {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let normalizedSample = LXATestsData.textMapTestCoreLXData
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    var lines = normalizedSample.components(separatedBy: "\n")

    func patchRow(typeID: Int, score: Double) -> Bool {
      guard let index = lines.firstIndex(where: { $0.hasPrefix("!改到\t\(typeID)\t") })
      else { return false }
      var fields = lines[index].split(separator: "\t", omittingEmptySubsequences: false)
        .map(String.init)
      guard fields.count >= 5 else { return false }
      for i in stride(from: 2, to: fields.count, by: 2) {
        fields[i] = String(score)
      }
      lines[index] = fields.joined(separator: "\t")
      return true
    }

    guard patchRow(typeID: 6, score: -1.25) else {
      Issue.record("測試樣本裡必須有繁體軌的「改到」帶前文條目（型別 6）。")
      return
    }
    guard patchRow(typeID: 5, score: -0.36) else {
      Issue.record("測試樣本裡必須有簡體軌的「改到」帶前文條目（型別 5）。")
      return
    }
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

    let traditional = traditionalInstance.unigramsFor(keyArray: ["ㄍㄞˇ", "ㄉㄠˋ"])
      .filter { $0.current == "改到" && ["會議", "活動"].contains($0.previous ?? "") }
    let simplified = simplifiedInstance.unigramsFor(keyArray: ["ㄍㄞˇ", "ㄉㄠˋ"])
      .filter { $0.current == "改到" && ["会议", "活动"].contains($0.previous ?? "") }

    #expect(traditional.count == 2, "繁體模式應只看到兩筆繁體前文條目。")
    #expect(simplified.count == 2, "簡體模式應只看到兩筆簡體前文條目。")
    #expect(traditional.allSatisfy { abs($0.probability - -1.25) < 0.001 })
    #expect(simplified.allSatisfy { abs($0.probability - -0.36) < 0.001 })
    #expect(traditional.allSatisfy { $0.anterior == nil })
    #expect(simplified.allSatisfy { $0.anterior == nil })
  }
}
