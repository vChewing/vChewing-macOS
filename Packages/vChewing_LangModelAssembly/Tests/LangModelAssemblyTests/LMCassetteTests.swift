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

// MARK: - LMCassetteTests

@Suite(.serialized)
struct LMCassetteTests {
  @Test
  func testCassetteLoadWubi86() throws {
    let pathCINFile = LMATestsData.getCINPath4Tests("wubi", ext: "cin")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }
    var lmCassette = LMAssembly.LMCassette()
    vCLMLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    vCLMLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    print(lmCassette.unigramsFor(key: "aaaz"))
    // keyname 25 鍵 + wildcardKey "z" + anySingleCharKey "Z"。
    #expect(lmCassette.keyNameMap.count == 27)
    #expect(lmCassette.wildcardKey == "z")
    #expect(lmCassette.anySingleCharKey == "Z")
    #expect(lmCassette.charDefMap.count == 23_494)
    #expect(lmCassette.octagramMap.count == 14_616)
    #expect(lmCassette.octagramDividedMap.isEmpty)
    #expect(!lmCassette.unigramsFor(key: "aaa" + lmCassette.wildcard).isEmpty)
    #expect(lmCassette.nameShort == "WUBI")
    #expect(lmCassette.nameENG == "Wubi")
    #expect(lmCassette.nameCJK == "五笔")
    #expect(lmCassette.nameIntl == "Haifeng Wubi:en;海峰五笔:zh-Hans;海峰五筆:zh-Hant")
    #expect(lmCassette.maxKeyLength == 4)
    #expect(lmCassette.endKeys.isEmpty)
    #expect(lmCassette.selectionKeys.count == 10)
  }

  @Test
  func testCassetteLoadArray30() throws {
    // "array30.cin2" 測試 quickphrase 時，用 `zzzj 歷歷在目` 這個測試例子即可。
    let pathCINFile = LMATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lmCassette = LMAssembly.LMCassette()
    vCLMLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    vCLMLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    #expect(!lmCassette.quickDefMap.isEmpty)
    print(lmCassette.quickSetsFor(key: ",.") ?? "")
    // keyname 30 鍵 + wildcardKey "*" + anySingleCharKey "?"。
    #expect(lmCassette.keyNameMap.count == 32)
    #expect(lmCassette.wildcardKey == "*")
    #expect(lmCassette.anySingleCharKey == "?")
    #expect(lmCassette.charDefMap.count == 29_491)
    #expect(lmCassette.octagramMap.isEmpty)
    #expect(lmCassette.octagramDividedMap.isEmpty)
    #expect(!lmCassette.unigramsFor(key: "aaa" + lmCassette.wildcard).isEmpty)
    #expect(lmCassette.nameShort == "AR30")
    #expect(lmCassette.nameENG == "array30")
    #expect(lmCassette.nameCJK == "行列30")
    #expect(lmCassette.nameIntl == "Array 30:en;行列30:zh-Hans;行列30:zh-Hant")
    #expect(lmCassette.maxKeyLength == 5)
    #expect(lmCassette.endKeys.count == 10)
    #expect(lmCassette.selectionKeys.count == 10)
    #expect(lmCassette.quickPhraseMap.count == 4)
    #expect(lmCassette.quickPhraseCommissionKey == "'")
    #expect(lmCassette.quickPhrasesFor(key: ",,,") ?? [] == ["米糕"])
    #expect(lmCassette.quickPhrasesFor(key: "zzza") ?? [] == ["需不需要"])
  }

  /// 直接載入行列30磁帶，重現 CIN v2.7 規格書中 `%anysinglecharkey` 與 `%wildcardkey` 的範例。
  @Test
  func testCassetteCIN27WildcardAndAnySingleCharExamples() throws {
    let pathCINFile = LMATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lmCassette = LMAssembly.LMCassette()
    let opened = lmCassette.open(pathCINFile)
    #expect(opened)
    #expect(lmCassette.wildcardKey == "*")
    #expect(lmCassette.anySingleCharKey == "?")
    #expect(lmCassette.allowedKeys.contains("*"))
    #expect(lmCassette.allowedKeys.contains("?"))
    // 組筆區顯示字根：花牌鍵預設為 ♧、任意單字元鍵預設為 ⍰（皆為使用者無法直接敲出的符號）。
    #expect(lmCassette.convertKeyToDisplay(char: "*") == "♧")
    #expect(lmCassette.convertKeyToDisplay(char: "?") == "⍰")

    // 規格範例：「培」的字根為 `ry;`（4↑ 6↑ 0-）。
    #expect(lmCassette.unigramsFor(key: "ry;").map(\.current).contains("培"))
    // 任何字根都可以用 `?` 代替：`r?;`、`ry?`、`?y;`、甚至 `r??` 均可查到「培」。
    #expect(lmCassette.unigramsFor(key: "r?;").map(\.current).contains("培"))
    #expect(lmCassette.unigramsFor(key: "ry?").map(\.current).contains("培"))
    #expect(lmCassette.unigramsFor(key: "?y;").map(\.current).contains("培"))
    #expect(lmCassette.unigramsFor(key: "r??").map(\.current).contains("培"))

    // 規格範例：`*` 放在中間或後面時，同時代表一個或多個 `?`。
    // `y*e` = `y?e`（如 yae 証）與 `y??e`（如 yaee 讘）的聯集。
    let valuesYStarE = lmCassette.unigramsFor(key: "y*e").map(\.current)
    #expect(valuesYStarE.contains("証"))
    #expect(valuesYStarE.contains("讘"))
    // `yk*` = `yk?`（如 ykj 初）與 `yk??`（如 ykac 褾）的聯集。
    let valuesYKStar = lmCassette.unigramsFor(key: "yk*").map(\.current)
    #expect(valuesYKStar.contains("初"))
    #expect(valuesYKStar.contains("褾"))

    // 規格範例：`*` 放在一個字的前面時為任意字根序查詢；
    // 即使字根倒過來輸入（如 `yr;` 詰）也可以找出該字。
    let valuesStarRY = lmCassette.unigramsFor(key: "*ry;").map(\.current)
    #expect(valuesStarRY.contains("培"))
    #expect(valuesStarRY.contains("詰"))

    // 反向斷言：非匹配結果不應混入。
    #expect(!lmCassette.unigramsFor(key: "r?;").map(\.current).contains("詰"))
    #expect(!valuesYStarE.contains("培"))

    // hasUnigramsFor：pattern 查詢的正反案例。
    #expect(lmCassette.hasUnigramsFor(key: "r?;"))
    #expect(lmCassette.hasUnigramsFor(key: "*ry;"))
    // 超過最大碼長（5）的 pattern 不可能有匹配。
    #expect(!lmCassette.hasUnigramsFor(key: "??????"))
  }

  /// 磁帶反查（字→碼）：chardef 與 symboldef 合併 namespace、零複製索引查詢。
  @Test
  func testCassetteReverseLookup() throws {
    let pathCINFile = LMATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }
    var lmCassette = LMAssembly.LMCassette()
    let opened = lmCassette.open(pathCINFile)
    #expect(opened)
    // chardef：「培」的字根為 `ry;`；「埻」的字根為 `ry;f`。
    #expect(lmCassette.reverseCodes(for: "培")?.contains("ry;") == true)
    #expect(lmCassette.reverseCodes(for: "埻") == ["ry;f"])
    // symboldef 合併語義：「ㄅ」來自 %symboldef 章節（w0）。
    #expect(lmCassette.reverseCodes(for: "ㄅ")?.contains("w0") == true)
    // 無結果回傳 nil。
    #expect(lmCassette.reverseCodes(for: "不存在的字詞") == nil)
    #expect(lmCassette.reverseCodes(for: "") == nil)
  }

  @Test
  func testCassetteQuickPhraseParsingVariants() throws {
    let pathCINFile = LMATestsData.getCINPath4Tests("quickphrases_multi", ext: "cin")
    guard let pathCINFile else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：quickphrases_multi.cin")
      return
    }
    var lmCassette = LMAssembly.LMCassette()
    let opened = lmCassette.open(pathCINFile)
    #expect(opened)
    #expect(lmCassette.quickPhraseCommissionKey.isEmpty)
    #expect(lmCassette.quickPhraseMap.count == 2)
    #expect(lmCassette.quickPhrasesFor(key: "ab") ?? [] == ["Foo", "Bar"])
    #expect(lmCassette.quickPhrasesFor(key: "ac") ?? [] == ["Bar"])
  }
}
