// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import XCTest

@testable import LangModelAssembly
import LMAssemblyMaterials4Tests

final class LMInstantiatorTests: XCTestCase {
  override func tearDown() {
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  func testReplaceDataSavesToCorrectStore() {
    let lmi = LMAssembly.LMInstantiator()
    let sample = "foo bar\n"

    lmi.replaceData(textData: sample, for: .thePhrases, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .thePhrases).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theFilter, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theFilter).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theReplacements, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theReplacements).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theAssociates, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theAssociates).contains("foo bar"))

    lmi.replaceData(textData: sample, for: .theSymbols, save: true)
    XCTAssertTrue(lmi.retrieveData(from: .theSymbols).contains("foo bar"))
  }

  func testCleanupInputTokenHashMapRemovesToTargetSize() {
    let instance = LMAssembly.LMInstantiator()
    // Create 3500 dummy hashes
    instance.inputTokenHashesArray = ContiguousArray((0 ..< 3_500).map { $0 })
    // Trigger cleanup via a simple unigram query
    _ = instance.unigramsFor(keyArray: ["ㄎㄜ"])
    XCTAssertEqual(instance.inputTokenHashesArray.count, 1_000)
  }

  func testQueryUserAddedKanjiByAPI() throws {
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
      XCTAssert(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.value)
      XCTAssert(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.value)
      XCTAssert(queriedValues.contains(testSingleCharUnigramSymbol))
    }
  }

  func testQueryUserAddedKanjiByRawString() throws {
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
      XCTAssert(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.value)
      XCTAssert(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.value)
      XCTAssert(queriedValues.contains(testSingleCharUnigramSymbol))
    }
  }
}
