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
      LMAssembly.LMInstantiator.disconnectSQLDB()
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
      LMAssembly.LMInstantiator.disconnectSQLDB()
    }
    let instance = LMAssembly.LMInstantiator()
    // Create 3500 dummy hashes
    instance.inputTokenHashesArray = ContiguousArray((0 ..< 3_500).map { $0 })
    // Trigger cleanup via a simple unigram query
    _ = instance.unigramsFor(keyArray: ["ㄎㄜ"])
    #expect(instance.inputTokenHashesArray.count == 1_000)
  }

  @Test
  func testQueryUserAddedKanjiByAPI() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectSQLDB()
    }
    let instance = LMAssembly.LMInstantiator()
    LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData)
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
      LMAssembly.LMInstantiator.disconnectSQLDB()
    }
    let instance = LMAssembly.LMInstantiator()
    LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData)
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
      LMAssembly.LMInstantiator.disconnectSQLDB()
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
}
