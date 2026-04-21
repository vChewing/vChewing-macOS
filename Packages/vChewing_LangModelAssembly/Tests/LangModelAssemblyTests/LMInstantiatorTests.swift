// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Homa
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
  func testAssociatedCandidateFacadePreservesExpansionAndDedupOrder() {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let lmi = LMAssembly.LMInstantiator()
    lmi.replaceData(
      textData: """
      (ㄉㄢˋ-ㄍㄠ,蛋糕) 起司蛋糕 泡芙
      蛋糕 泡芙 布丁
      糕 布丁 年糕
      """,
      for: .theAssociates,
      save: false
    )

    let pair = Homa.CandidatePair(keyArray: ["ㄉㄢˋ", "ㄍㄠ"], value: "蛋糕")
    let expectedValues = ["起司蛋糕", "泡芙", "布丁", "年糕"]

    #expect(lmi.lookupHub.associatedCandidates(forPairs: [pair]).map(\.value) == ["起司蛋糕", "泡芙", "布丁"])

    let expanded = lmi.lookupHub.associatedCandidates(forPair: pair)
    #expect(expanded.map(\.value) == expectedValues)
    #expect(expanded.allSatisfy { $0.keyArray == [""] })
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
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData)
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
      ).map(\.current)
      #expect(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.current)
      #expect(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.current)
      #expect(queriedValues.contains(testSingleCharUnigramSymbol))
    }
  }

  @Test
  func testQueryUserAddedKanjiByRawString() throws {
    defer {
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
    }
    let instance = LMAssembly.LMInstantiator()
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData)
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
      ).map(\.current)
      #expect(subQueried1.contains(testSingleCharUnigramSymbol))
    }
    do {
      let subQueried2 = instance.lmUserPhrases.unigramsFor(
        key: testReading,
        keyArray: testReadingArray,
        omitNonTemporarySingleCharNonSymbolUnigrams: true
      ).map(\.current)
      #expect(subQueried2.contains(testSingleCharUnigramSymbol))
    }
    do {
      let queried = instance.unigramsFor(keyArray: testReadingArray)
      let queriedValues = queried.map(\.current)
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
    var liu2 = instance1.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.current).prefix(3)
    var bao3 = instance1.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.current).prefix(3)
    var jie2 = instance1.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.current).prefix(3)
    #expect(liu2 == ["劉", "流", "留"])
    #expect(bao3 == ["保", "寶", "飽"])
    #expect(jie2 == ["節", "潔", "傑"])
    let instance2 = LMAssembly.LMInstantiator(isCHS: true).setOptions { config in
      config.isSCPCEnabled = true
    }
    liu2 = instance2.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.current).prefix(3)
    bao3 = instance2.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.current).prefix(3)
    jie2 = instance2.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.current).prefix(3)
    #expect(liu2 == ["刘", "流", "留"])
    #expect(bao3 == ["保", "宝", "饱"])
    #expect(jie2 == ["节", "洁", "杰"])
  }

  @Test
  func testETenDOSSequenceLookupStrategySeparatesConfiguredExactAndPartial() {
    let instance = LMAssembly.LMInstantiator(isCHS: false)
    let reading = "ㄅ"

    let exact = instance.lookupHub.supplementalValues(for: reading, strategy: .exactMatch)
    let partial = instance.lookupHub.supplementalValues(for: reading, strategy: .partialMatch)

    #expect(instance.lookupHub.supplementalValues(for: reading, strategy: .configuredLookup) == exact)
    #expect(!exact.isEmpty)
    #expect(Set(partial).isSuperset(of: Set(exact)))
    #expect(partial.count > exact.count)

    _ = instance.setOptions { config in
      config.partialMatchEnabled = true
    }

    #expect(instance.lookupHub.supplementalValues(for: reading, strategy: .configuredLookup) == partial)
  }

  @Test
  func testCassetteQuickSetLookupStrategyPreservesConfiguredBackendDefault() {
    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer {
      LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading
      LMAssembly.LMInstantiator.lmCassette.clear()
    }

    func fetchQuickSetValues(
      from instance: LMAssembly.LMInstantiator,
      key: String,
      strategy: LMAssembly.LMInstantiator.SupplementalLookupStrategy
    )
      -> [String] {
      instance.lookupHub.cassetteQuickSets(for: key, strategy: strategy)?
        .split(separator: "\t")
        .map(\.description) ?? []
    }

    guard let exactFixturePath = LMATestsData.getCINPath4Tests("cassette_exact_quick", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：cassette_exact_quick.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: exactFixturePath)
    let instance = LMAssembly.LMInstantiator()
    let exactFixtureExact = fetchQuickSetValues(from: instance, key: "a", strategy: .exactMatch)
    let exactFixtureConfigured = fetchQuickSetValues(from: instance, key: "a", strategy: .configuredLookup)
    let exactFixturePartial = fetchQuickSetValues(from: instance, key: "a", strategy: .partialMatch)

    #expect(exactFixtureConfigured == exactFixtureExact)
    #expect(exactFixtureExact == ["工"])
    #expect(exactFixturePartial.contains("式"))
    #expect(Set(exactFixturePartial).isSuperset(of: Set(exactFixtureExact)))

    guard let partialFixturePath = LMATestsData.getCINPath4Tests("cassette_partial_quick", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：cassette_partial_quick.cin")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: partialFixturePath)
    let partialFixtureExact = fetchQuickSetValues(from: instance, key: "a", strategy: .exactMatch)
    let partialFixtureConfigured = fetchQuickSetValues(from: instance, key: "a", strategy: .configuredLookup)
    let partialFixturePartial = fetchQuickSetValues(from: instance, key: "a", strategy: .partialMatch)

    #expect(partialFixtureExact == ["工"])
    #expect(partialFixtureConfigured == partialFixturePartial)
    #expect(partialFixturePartial == ["工", "式", "芯"])
  }
}
