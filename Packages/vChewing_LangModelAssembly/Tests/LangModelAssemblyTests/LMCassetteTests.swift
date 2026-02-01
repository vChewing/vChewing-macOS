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
    #expect(lmCassette.keyNameMap.count == 26)
    #expect(lmCassette.charDefMap.count == 23_494)
    #expect(lmCassette.charDefWildcardMap.count == 8_390)
    #expect(lmCassette.octagramMap.count == 14_616)
    #expect(lmCassette.octagramDividedMap.isEmpty)
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
    #expect(lmCassette.keyNameMap.count == 31)
    #expect(lmCassette.charDefMap.count == 29_491)
    #expect(lmCassette.charDefWildcardMap.count == 11_946)
    #expect(lmCassette.octagramMap.isEmpty)
    #expect(lmCassette.octagramDividedMap.isEmpty)
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
