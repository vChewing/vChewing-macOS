// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly

// MARK: - LXCassetteTests

@Suite(.serialized)
struct LXCassetteTests {
  @Test
  func testCassetteLoadWubi86() throws {
    let pathCINFile = LXATestsData.getCINPath4Tests("wubi", ext: "cin")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }
    var lxCassette = LXAssembly.LXCassette()
    vCLMLog("LXCassette: Start loading CIN.")
    lxCassette.open(pathCINFile)
    vCLMLog("LXCassette: Finished loading CIN. Entries: \(lxCassette.count)")
    print(lxCassette.unigramsFor(key: "aaaz"))
    // keyname 25 鍵 + wildcardKey "z" + anySingleCharKey "Z"。
    #expect(lxCassette.keyNameMap.count == 27)
    #expect(lxCassette.wildcardKey == "z")
    #expect(lxCassette.anySingleCharKey == "Z")
    #expect(lxCassette.charDefMap.count == 23_494)
    #expect(lxCassette.octagramMap.count == 14_616)
    #expect(lxCassette.octagramDividedMap.isEmpty)
    #expect(!lxCassette.unigramsFor(key: "aaa" + lxCassette.wildcard).isEmpty)
    #expect(lxCassette.nameShort == "WUBI")
    #expect(lxCassette.nameENG == "Wubi")
    #expect(lxCassette.nameCJK == "五笔")
    #expect(lxCassette.nameIntl == "Haifeng Wubi:en;海峰五笔:zh-Hans;海峰五筆:zh-Hant")
    #expect(lxCassette.maxKeyLength == 4)
    #expect(lxCassette.endKeys.isEmpty)
    #expect(lxCassette.selectionKeys.count == 10)
  }

  @Test
  func testCassetteLoadArray30() throws {
    // "array30.cin2" 測試 quickphrase 時，用 `zzzj 歷歷在目` 這個測試例子即可。
    let pathCINFile = LXATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lxCassette = LXAssembly.LXCassette()
    vCLMLog("LXCassette: Start loading CIN.")
    lxCassette.open(pathCINFile)
    vCLMLog("LXCassette: Finished loading CIN. Entries: \(lxCassette.count)")
    #expect(!lxCassette.quickDefMap.isEmpty)
    print(lxCassette.quickSetsFor(key: ",.") ?? "")
    // keyname 30 鍵 + wildcardKey "*" + anySingleCharKey "?"。
    #expect(lxCassette.keyNameMap.count == 32)
    #expect(lxCassette.wildcardKey == "*")
    #expect(lxCassette.anySingleCharKey == "?")
    #expect(lxCassette.charDefMap.count == 29_491)
    #expect(lxCassette.octagramMap.isEmpty)
    #expect(lxCassette.octagramDividedMap.isEmpty)
    #expect(!lxCassette.unigramsFor(key: "aaa" + lxCassette.wildcard).isEmpty)
    #expect(lxCassette.nameShort == "AR30")
    #expect(lxCassette.nameENG == "array30")
    #expect(lxCassette.nameCJK == "行列30")
    #expect(lxCassette.nameIntl == "Array 30:en;行列30:zh-Hans;行列30:zh-Hant")
    #expect(lxCassette.maxKeyLength == 5)
    #expect(lxCassette.endKeys.count == 10)
    #expect(lxCassette.selectionKeys.count == 10)
    #expect(lxCassette.quickPhraseMap.count == 4)
    #expect(lxCassette.quickPhraseCommissionKey == "'")
    #expect(lxCassette.quickPhrasesFor(key: ",,,") ?? [] == ["米糕"])
    #expect(lxCassette.quickPhrasesFor(key: "zzza") ?? [] == ["需不需要"])
  }

  /// 直接載入行列30磁帶，重現 CIN v2.7 規格書中 `%anysinglecharkey` 與 `%wildcardkey` 的範例。
  @Test
  func testCassetteCIN27WildcardAndAnySingleCharExamples() throws {
    let pathCINFile = LXATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lxCassette = LXAssembly.LXCassette()
    let opened = lxCassette.open(pathCINFile)
    #expect(opened)
    #expect(lxCassette.wildcardKey == "*")
    #expect(lxCassette.anySingleCharKey == "?")
    #expect(lxCassette.allowedKeys.contains("*"))
    #expect(lxCassette.allowedKeys.contains("?"))
    // 組筆區顯示字根：花牌鍵預設為 ♧、任意單字元鍵預設為 ⍰（皆為使用者無法直接敲出的符號）。
    #expect(lxCassette.convertKeyToDisplay(char: "*") == "♧")
    #expect(lxCassette.convertKeyToDisplay(char: "?") == "⍰")

    // 規格範例：「培」的字根為 `ry;`（4↑ 6↑ 0-）。
    #expect(lxCassette.unigramsFor(key: "ry;").map(\.current).contains("培"))
    // 任何字根都可以用 `?` 代替：`r?;`、`ry?`、`?y;`、甚至 `r??` 均可查到「培」。
    #expect(lxCassette.unigramsFor(key: "r?;").map(\.current).contains("培"))
    #expect(lxCassette.unigramsFor(key: "ry?").map(\.current).contains("培"))
    #expect(lxCassette.unigramsFor(key: "?y;").map(\.current).contains("培"))
    #expect(lxCassette.unigramsFor(key: "r??").map(\.current).contains("培"))

    // 規格範例：`*` 放在中間或後面時，同時代表一個或多個 `?`。
    // `y*e` = `y?e`（如 yae 証）與 `y??e`（如 yaee 讘）的聯集。
    let valuesYStarE = lxCassette.unigramsFor(key: "y*e").map(\.current)
    #expect(valuesYStarE.contains("証"))
    #expect(valuesYStarE.contains("讘"))
    // `yk*` = `yk?`（如 ykj 初）與 `yk??`（如 ykac 褾）的聯集。
    let valuesYKStar = lxCassette.unigramsFor(key: "yk*").map(\.current)
    #expect(valuesYKStar.contains("初"))
    #expect(valuesYKStar.contains("褾"))

    // 規格範例：`*` 放在一個字的前面時為任意字根序查詢；
    // 即使字根倒過來輸入（如 `yr;` 詰）也可以找出該字。
    let valuesStarRY = lxCassette.unigramsFor(key: "*ry;").map(\.current)
    #expect(valuesStarRY.contains("培"))
    #expect(valuesStarRY.contains("詰"))

    // 反向斷言：非匹配結果不應混入。
    #expect(!lxCassette.unigramsFor(key: "r?;").map(\.current).contains("詰"))
    #expect(!valuesYStarE.contains("培"))

    // hasUnigramsFor：pattern 查詢的正反案例。
    #expect(lxCassette.hasUnigramsFor(key: "r?;"))
    #expect(lxCassette.hasUnigramsFor(key: "*ry;"))
    // 超過最大碼長（5）的 pattern 不可能有匹配。
    #expect(!lxCassette.hasUnigramsFor(key: "??????"))
  }

  /// 磁帶反查（字→碼）：chardef 與 symboldef 合併 namespace、零複製索引查詢。
  @Test
  func testCassetteReverseLookup() throws {
    let pathCINFile = LXATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lxCassette = LXAssembly.LXCassette()
    let opened = lxCassette.open(pathCINFile)
    #expect(opened)
    // chardef：「培」的字根為 `ry;`；「埻」的字根為 `ry;f`。
    #expect(lxCassette.reverseCodes(for: "培")?.contains("ry;") == true)
    #expect(lxCassette.reverseCodes(for: "埻") == ["ry;f"])
    // symboldef 合併語義：「ㄅ」來自 %symboldef 章節（w0）。
    #expect(lxCassette.reverseCodes(for: "ㄅ")?.contains("w0") == true)
    // 無結果回傳 nil。
    #expect(lxCassette.reverseCodes(for: "不存在的字詞") == nil)
    #expect(lxCassette.reverseCodes(for: "") == nil)
  }

  @Test
  func testCassetteQuickPhraseParsingVariants() throws {
    let pathCINFile = LXATestsData.getCINPath4Tests("quickphrases_multi", ext: "cin")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：quickphrases_multi.cin")
      return
    }
    var lxCassette = LXAssembly.LXCassette()
    let opened = lxCassette.open(pathCINFile)
    #expect(opened)
    #expect(lxCassette.quickPhraseCommissionKey.isEmpty)
    #expect(lxCassette.quickPhraseMap.count == 2)
    #expect(lxCassette.quickPhrasesFor(key: "ab") ?? [] == ["Foo", "Bar"])
    #expect(lxCassette.quickPhrasesFor(key: "ac") ?? [] == ["Bar"])
  }
}
