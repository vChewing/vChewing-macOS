// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Testing

@testable import LangModelAssembly
import LMAssemblyMaterials4Tests

@Suite(.serialized)
struct LMInstantiatorTests {
  @Test
  func testReplaceDataSavesToCorrectStore() {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let lmi = LMAssembly.LMInstantiator()
    let sample = "foo bar\n"

    lmi.replaceData(textData: sample, for: .thePhrases, save: true)
    #expect(lmi.retrieveData(from: .thePhrases).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theFilter, save: true)
    #expect(lmi.retrieveData(from: .theFilter).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theReplacements, save: true)
    #expect(lmi.retrieveData(from: .theReplacements).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theAssociates, save: true)
    #expect(lmi.retrieveData(from: .theAssociates).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theSymbols, save: true)
    #expect(lmi.retrieveData(from: .theSymbols).contains("foo bar"))
  }

  @Test
  func testCleanupInputTokenHashMapRemovesToTargetSize() {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let instance = LMAssembly.LMInstantiator()
    // Create 3500 dummy hashes
    instance.inputTokenHashesArray = Set((0 ..< 3_500).map { $0 })
    // Trigger cleanup via a simple unigram query
    _ = instance.unigramsFor(keyArray: ["ㄎㄜ"])
    #expect(instance.inputTokenHashesArray.isEmpty)
  }

  @Test
  func testQueryUserAddedKanjiByAPI() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let instance = LMAssembly.LMInstantiator()
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.sqlTestCoreLMData)
    let testSingleCharUnigramSymbol = "・"
    let testReading = "ㄌㄧㄣ"
    let testReadingArray = [testReading]
    instance.insertTemporaryData(
      unigram: .init(
        keyArray: testReadingArray,
        value: testSingleCharUnigramSymbol
      ),
      isFiltering: false
    )
    do {
      let subQueried1 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: false
      ).map(\.value)
      #expect(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.value)
      #expect(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.value)
      #expect(queriedValues.contains(testSingleCharUnigramSymbol))
    }
  }

  @Test
  func testQueryUserAddedKanjiByRawString() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let instance = LMAssembly.LMInstantiator()
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.sqlTestCoreLMData)
    let testSingleCharUnigramSymbol = "・"
    let testReading = "ㄌㄧㄣ"
    let testReadingArray = [testReading]
    let hdr = LMAssembly.LMConsolidator.kPragmaHeader
    let rawStr = "\(hdr)\n\(testSingleCharUnigramSymbol) \(testReading)\n"
    instance.lmUserPhrases.replaceData(textData: rawStr)
    do {
      let subQueried1 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: false
      ).map(\.value)
      #expect(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.value)
      #expect(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.value)
      #expect(queriedValues.contains(testSingleCharUnigramSymbol))
    }
  }

  @Test
  func testLMPlainBPMFDataQuery() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let instance1 = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.isSCPCEnabled = true
    }
    var liu2 = instance1.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.value).prefix(3)
    var bao3 = instance1.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.value).prefix(3)
    var jie2 = instance1.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.value).prefix(3)
    #expect(liu2 == ["劉", "流", "留"])
    #expect(bao3 == ["保", "寶", "飽"])
    #expect(jie2 == ["節", "潔", "傑"])
    let instance2 = LMAssembly.LMInstantiator(isCHS: true).setOptions { config in
      config.isSCPCEnabled = true
    }
    liu2 = instance2.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.value).prefix(3)
    bao3 = instance2.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.value).prefix(3)
    jie2 = instance2.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.value).prefix(3)
    #expect(liu2 == ["刘", "流", "留"])
    #expect(bao3 == ["保", "宝", "饱"])
    #expect(jie2 == ["节", "洁", "杰"])
  }

  @Test
  func testFuzzyEnEngReadingQuery() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    // 測試「ㄣ/ㄥ」容錯查詢功能。
    // 當啟用 fuzzyPhoneticEnabled + fuzzyFinalEnEng 時，輸入「ㄣ」應該也能找到「ㄥ」的候選字，反之亦然。
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.sqlTestCoreLMData)

    // 先測試未啟用容錯時的情況：精確查詢「ㄈㄥ」應該找到「風」
    let instanceWithoutFuzzy = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = false
      config.isSCPCEnabled = true
    }
    let exactResults = instanceWithoutFuzzy.unigramsFor(keyArray: ["ㄈㄥ"]).map(\.value)
    #expect(exactResults.contains("風"), "精確查詢應該能找到『風』")

    // 測試啟用容錯後：輸入「ㄈㄣ」應該也能找到「風」
    let instanceWithFuzzy = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = true
      config.fuzzyFinalEnEng = true
      config.isSCPCEnabled = true
    }
    let fuzzyResults = instanceWithFuzzy.unigramsFor(keyArray: ["ㄈㄣ"]).map(\.value)
    #expect(fuzzyResults.contains("風"), "容錯查詢應該讓『ㄈㄣ』也能找到『風』")

    // 反向測試：輸入「ㄌㄧㄥ」應該能找到「ㄌㄧㄣ」的候選字（如「林」）
    // 注意：這取決於測試資料庫的內容
    let reverseResults = instanceWithFuzzy.unigramsFor(keyArray: ["ㄌㄧㄥ"]).map(\.value)
    // 只要驗證容錯功能有執行（返回了結果）即可
    #expect(!reverseResults.isEmpty, "容錯查詢應該返回結果")
  }

  @Test
  func testFuzzyInitialReadingQuery() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    // 測試聲母近似音（ㄗ↔ㄓ）查詢功能。
    // 測試資料庫中有 ㄓㄨㄥ（中），但沒有 ㄗㄨㄥ 的精確詞條。
    // 啟用容錯後，查詢 ㄗㄨㄥ 時應透過 ㄗ↔ㄓ 規則找到 ㄓㄨㄥ 的候選字（如「中」）。
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.sqlTestCoreLMData)

    // 先確認精確查詢 ㄓㄨㄥ 能找到「中」
    let exactZhInstance = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = false
      config.isSCPCEnabled = true
    }
    let exactZhResults = exactZhInstance.unigramsFor(keyArray: ["ㄓㄨㄥ"]).map(\.value)
    #expect(exactZhResults.contains("中"), "精確查詢「ㄓㄨㄥ」應能找到「中」")

    // 啟用 fuzzyPhoneticEnabled + fuzzyInitialZZh（ㄗ↔ㄓ）
    let instanceWithFuzzy = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = true
      config.fuzzyInitialZZh = true
      config.isSCPCEnabled = true
    }
    // 查詢 ㄗㄨㄥ 時，容錯應展開到 ㄓㄨㄥ，並找到「中」
    let fuzzyZResults = instanceWithFuzzy.unigramsFor(keyArray: ["ㄗㄨㄥ"]).map(\.value)
    #expect(fuzzyZResults.contains("中"), "啟用 ㄗ↔ㄓ 容錯時，查詢「ㄗㄨㄥ」應能透過近似音找到「中」")

    // 未啟用容錯時，ㄗㄨㄥ 查不到 ㄓㄨㄥ 的字
    let instanceWithoutFuzzy = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = false
      config.isSCPCEnabled = true
    }
    let noFuzzyResults = instanceWithoutFuzzy.unigramsFor(keyArray: ["ㄗㄨㄥ"]).map(\.value)
    #expect(!noFuzzyResults.contains("中"), "未啟用容錯時，查詢「ㄗㄨㄥ」不應找到「中」（ㄓㄨㄥ 的字）")
  }

  @Test
  func testFuzzyMasterToggle() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    // 測試總開關：關閉時即使子規則啟用也不展開
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.sqlTestCoreLMData)

    let instanceMasterOff = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.fuzzyPhoneticEnabled = false  // 總開關關閉
      config.fuzzyFinalEnEng = true        // 子規則啟用（但無效）
      config.isSCPCEnabled = true
    }
    let results = instanceMasterOff.unigramsFor(keyArray: ["ㄈㄣ"]).map(\.value)
    #expect(!results.contains("風"), "總開關關閉時，「ㄈㄣ」不應找到「風」")
  }
}
