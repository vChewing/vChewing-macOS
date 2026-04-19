// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import HomaSharedTestComponents

import Testing

@testable import LangModelAssembly

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMTestSuite.POMJoinedTests

extension POMTestSuite {
  // MARK: - POMJoinedTests

  @Suite(.serialized)
  struct POMJoinedTests {
    @Test
    func testPOM_AC01A_SaisoukiNoGaika() throws {
      let lm = TestLM(rawData: HomaTests.strLMSampleData_SaisoukiNoGaika)
      let pom = LMAssembly.LXPerceptor(
        dataURL: URL(fileURLWithPath: "/dev/null")
      )
      let compositor = Homa.Assembler(
        gramQuerier: lm.asGramQuerier(),
        gramAvailabilityChecker: lm.asGramAvailabilityChecker()
      )
      // 測試用句「再創世的凱歌」。
      let readingKeys = ["zai4", "chuang4", "shi4", "de5", "kai3", "ge1"]
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()
      let assembledPriorToOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect("再 創 是的 凱歌" == assembledPriorToOverride)
      // 測試此時生成的 keyForQueryingData 是否正確
      let cursorShi = 2
      let cursorShiDe = 3
      let keyForQueryingDataAt2 = compositor.assembledSentence
        .generateKeyForPerception(cursor: cursorShi)
      #expect(keyForQueryingDataAt2?.ngramKey == "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
      #expect(keyForQueryingDataAt2?.headReading == "shi4")
      let keyForQueryingDataAt3 = compositor.assembledSentence
        .generateKeyForPerception(cursor: cursorShiDe)
      #expect(keyForQueryingDataAt3?.ngramKey == "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
      #expect(keyForQueryingDataAt3?.headReading == "de5")
      // 應能提供『是的』『似的』『凱歌』等候選
      let pairsAtShiDeEnd = compositor.fetchCandidates(at: 4, filter: .endAt)
      #expect(pairsAtShiDeEnd.map(\.pair.value).contains("是的"))
      #expect(pairsAtShiDeEnd.map(\.pair.value).contains("似的"))
      // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
      var obsCaptured: Homa.PerceptionIntel?
      try compositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["shi4"], value: "世"),
        at: cursorShi,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }
      #expect(obsCaptured?.contextualizedGramKey == "(zai4,再)&(chuang4,創)&(shi4,世)")
      guard let obsCaptured else {
        preconditionFailure("Should have a capture.")
      }
      // compositor.assemble() <- 已經組句了。
      let assembledFollowingOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect("再 創 世 的 凱歌" == assembledFollowingOverride)
      pom.memorizePerception(
        (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
        timestamp: Date().timeIntervalSince1970
      )
      // 記憶完畢。先看看是否有記憶。
      let currentmemory = pom.getSavableData()
      let firstObservationKey = currentmemory.first?.key
      guard let firstObservationKey else {
        preconditionFailure("POM memorized nothing, or something wrong happen.")
      }
      #expect(firstObservationKey == obsCaptured.contextualizedGramKey)
      // 然後是記憶效力測試：
      let validationLM = TestLM(rawData: HomaTests.strLMSampleData_SaisoukiNoGaika)
      let validationCompositor = Homa.Assembler(
        gramQuerier: validationLM.asGramQuerier(),
        gramAvailabilityChecker: validationLM.asGramAvailabilityChecker()
      )
      for key in readingKeys.prefix(4) { try validationCompositor.insertKey(key) }
      validationCompositor.assemble()
      let cursorToTest = validationCompositor.cursor
      let assembledNow = validationCompositor.assembledSentence.values
        .joined(separator: " ")
      #expect(
        ["再 創 是的", "再 創 世 的"].contains(assembledNow)
      )
      let suggestion = pom.fetchSuggestion(
        assembledResult: validationCompositor.assembledSentence,
        cursor: cursorToTest,
        timestamp: Date().timeIntervalSince1970
      )
      #expect(!suggestion.isEmpty)
      guard let firstSuggestionRAW = suggestion.candidates.first else {
        preconditionFailure("POM suggested nothing, or something wrong happen.")
      }
      let candidateSuggested = Homa.CandidatePair(
        keyArray: firstSuggestionRAW.keyArray,
        value: firstSuggestionRAW.value
      ).weighted(firstSuggestionRAW.probability)
      let cursorForOverride = suggestion.overrideCursor ?? cursorShi
      do {
        try validationCompositor.overrideCandidate(
          candidateSuggested,
          at: cursorForOverride,
          type: suggestion.suggestedOverrideType,
          enforceRetokenization: true
        )
      } catch {
        try validationCompositor.overrideCandidateLiteral(
          candidateSuggested.pair.value,
          at: cursorForOverride,
          overrideType: suggestion.suggestedOverrideType
        )
      }
      validationCompositor.assemble()
      let assembledByPOM = validationCompositor.assembledSentence.values
        .joined(separator: " ")
      #expect(assembledByPOM == "再 創 世 的")
    }

    @Test
    func testPOM_AC01B_SaisoukiOnly() throws {
      let lm = TestLM(rawData: HomaTests.strLMSampleData_SaisoukiNoGaika)
      let pom = LMAssembly.LXPerceptor(
        dataURL: URL(fileURLWithPath: "/dev/null")
      )
      let compositor = Homa.Assembler(
        gramQuerier: lm.asGramQuerier(),
        gramAvailabilityChecker: lm.asGramAvailabilityChecker()
      )
      let readingKeys = ["zai4", "chuang4", "shi4"]
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()
      let assembledPriorToOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledPriorToOverride == "再 創 是")

      let cursorShi = 2
      var obsCaptured: Homa.PerceptionIntel?
      try compositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["shi4"], value: "世"),
        at: cursorShi,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }
      #expect(obsCaptured?.contextualizedGramKey == "(zai4,再)&(chuang4,創)&(shi4,世)")
      guard let obsCaptured else {
        preconditionFailure("Should have a capture.")
      }

      let assembledFollowingOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledFollowingOverride == "再 創 世")
      pom.memorizePerception(
        (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
        timestamp: Date().timeIntervalSince1970
      )

      let currentmemory = pom.getSavableData()
      let firstObservationKey = currentmemory.first?.key
      guard let firstObservationKey else {
        preconditionFailure("POM memorized nothing, or something wrong happen.")
      }
      #expect(firstObservationKey == obsCaptured.contextualizedGramKey)

      compositor.clear()
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()

      let assembledNow = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledNow == "再 創 是")

      let cursorToTest = compositor.cursor
      let suggestion = pom.fetchSuggestion(
        assembledResult: compositor.assembledSentence,
        cursor: cursorToTest,
        timestamp: Date().timeIntervalSince1970
      )
      #expect(!suggestion.isEmpty)
      guard let firstSuggestionRAW = suggestion.candidates.first else {
        preconditionFailure("POM suggested nothing, or something wrong happen.")
      }

      let candidateSuggested = Homa.CandidatePair(
        keyArray: firstSuggestionRAW.keyArray,
        value: firstSuggestionRAW.value
      ).weighted(firstSuggestionRAW.probability)
      let cursorForOverride = suggestion.overrideCursor ?? cursorShi
      do {
        try compositor.overrideCandidate(
          candidateSuggested,
          at: cursorForOverride,
          type: suggestion.suggestedOverrideType,
          enforceRetokenization: true
        )
      } catch {
        try compositor.overrideCandidateLiteral(
          candidateSuggested.pair.value,
          at: cursorForOverride,
          overrideType: suggestion.suggestedOverrideType
        )
      }
      compositor.assemble()
      let assembledByPOM = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledByPOM == "再 創 世")
    }

    @Test
    func testPOM_AC02_BusinessEnglishSession() throws {
      let lm = TestLM(rawData: HomaTests.strLMSampleData_BusinessEnglishSession)
      let pom = LMAssembly.LXPerceptor(
        dataURL: URL(fileURLWithPath: "/dev/null")
      )
      let compositor = Homa.Assembler(
        gramQuerier: lm.asGramQuerier(),
        gramAvailabilityChecker: lm.asGramAvailabilityChecker()
      )
      // 測試用句「再創世的凱歌」。
      let readingKeys = ["shang1", "wu4", "ying1", "yu3", "hui4", "hua4"]
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()
      let assembledPriorToOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect("商務 英語 繪畫" == assembledPriorToOverride)
      // 測試此時生成的 keyForQueryingData 是否正確
      let cursorHua = 5
      let keyForQueryingDataAt5 = compositor.assembledSentence
        .generateKeyForPerception(cursor: cursorHua)
      #expect(keyForQueryingDataAt5?.ngramKey == "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,繪畫)")
      #expect(keyForQueryingDataAt5?.headReading == "hua4")
      // 應能提供『是的』『似的』『凱歌』等候選
      let pairsAtHuiHuaEnd = compositor.fetchCandidates(at: 6, filter: .endAt)
      #expect(pairsAtHuiHuaEnd.map(\.pair.value).contains("繪畫"))
      #expect(pairsAtHuiHuaEnd.map(\.pair.value).contains("會話"))
      // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
      var obsCaptured: Homa.PerceptionIntel?
      try compositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["hui4", "hua4"], value: "會話"),
        at: cursorHua,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }
      #expect(obsCaptured?.contextualizedGramKey == "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,會話)")
      guard let obsCaptured else {
        preconditionFailure("Should have a capture.")
      }
      // compositor.assemble() <- 已經組句了。
      let assembledFollowingOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect("商務 英語 會話" == assembledFollowingOverride)
      pom.memorizePerception(
        (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
        timestamp: Date().timeIntervalSince1970
      )
      // 記憶完畢。先看看是否有記憶。
      let currentmemory = pom.getSavableData()
      let firstObservationKey = currentmemory.first?.key
      guard let firstObservationKey else {
        preconditionFailure("POM memorized nothing, or something wrong happen.")
      }
      #expect(firstObservationKey == obsCaptured.contextualizedGramKey) // 然後是記憶效力測試：
      let validationLM = TestLM(rawData: HomaTests.strLMSampleData_BusinessEnglishSession)
      let validationCompositor = Homa.Assembler(
        gramQuerier: validationLM.asGramQuerier(),
        gramAvailabilityChecker: validationLM.asGramAvailabilityChecker()
      )
      for key in readingKeys { try validationCompositor.insertKey(key) }
      validationCompositor.assemble()
      let cursorToTest = validationCompositor.cursor
      let assembledNow = validationCompositor.assembledSentence.values
        .joined(separator: " ")
      #expect(
        ["商務 英語 繪畫", "商務 英語 會話"].contains(assembledNow)
      )
      let suggestion = pom.fetchSuggestion(
        assembledResult: validationCompositor.assembledSentence,
        cursor: cursorToTest,
        timestamp: Date().timeIntervalSince1970
      )
      #expect(!suggestion.isEmpty)
      guard let firstSuggestionRAW = suggestion.candidates.first else {
        preconditionFailure("POM suggested nothing, or something wrong happen.")
      }
      let candidateSuggested = Homa.CandidatePair(
        keyArray: firstSuggestionRAW.keyArray,
        value: firstSuggestionRAW.value
      ).weighted(firstSuggestionRAW.probability)
      let cursorForOverride = suggestion.overrideCursor ?? cursorHua
      do {
        try validationCompositor.overrideCandidate(
          candidateSuggested,
          at: cursorForOverride,
          type: suggestion.suggestedOverrideType,
          enforceRetokenization: true
        )
      } catch {
        try validationCompositor.overrideCandidateLiteral(
          candidateSuggested.pair.value,
          at: cursorForOverride,
          overrideType: suggestion.suggestedOverrideType
        )
      }
      validationCompositor.assemble()
      let assembledByPOM = validationCompositor.assembledSentence.values
        .joined(separator: " ")
      #expect(assembledByPOM == "商務 英語 會話")
    }

    @Test
    func testPOM_AC03_DiJiaoSubmission() throws {
      let lm = TestLM(rawData: HomaTests.strLMSampleData_DiJiaoSubmission)
      let pom = LMAssembly.LXPerceptor(dataURL: URL(fileURLWithPath: "/dev/null"))
      let compositor = Homa.Assembler(
        gramQuerier: lm.asGramQuerier(),
        gramAvailabilityChecker: lm.asGramAvailabilityChecker()
      )
      let readingKeys = ["di4", "jiao1"]
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()

      try compositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["di4"], value: "第"),
        at: 0,
        enforceRetokenization: true
      )
      compositor.assemble()

      let assembledFollowingFirstOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect(
        ["第 交", "第 教"].contains(assembledFollowingFirstOverride)
      )

      let candidatesAtEnd = compositor.fetchCandidates(at: readingKeys.count, filter: .endAt)
      guard let diJiaoCandidate = candidatesAtEnd.first(where: { $0.pair.value == "遞交" })?.pair else {
        Issue.record("Failed to find '遞交' candidate.")
        return
      }

      var obsCaptured: Homa.PerceptionIntel?
      try compositor.overrideCandidate(
        diJiaoCandidate,
        at: readingKeys.count,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }
      guard let obsCaptured else {
        preconditionFailure("Should have a capture.")
      }
      #expect(obsCaptured.candidate == "遞交")
      #expect(obsCaptured.contextualizedGramKey == "()&(di4,第)&(di4-jiao1,遞交)")

      let assembledFollowingSecondOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledFollowingSecondOverride == "遞交")

      pom.memorizePerception(
        (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
        timestamp: Date().timeIntervalSince1970
      )

      let savedKeys = pom.getSavableData().map(\.key)
      #expect(savedKeys.contains(obsCaptured.contextualizedGramKey))

      let directSuggestion = pom.getSuggestion(
        key: obsCaptured.contextualizedGramKey,
        timestamp: Date().timeIntervalSince1970
      )
      #expect(directSuggestion?.first?.value == "遞交")

      let validationLM = TestLM(rawData: HomaTests.strLMSampleData_DiJiaoSubmission)
      let validationCompositor = Homa.Assembler(
        gramQuerier: validationLM.asGramQuerier(),
        gramAvailabilityChecker: validationLM.asGramAvailabilityChecker()
      )
      for key in readingKeys { try validationCompositor.insertKey(key) }
      validationCompositor.assemble()
      try validationCompositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["di4"], value: "第"),
        at: 0,
        enforceRetokenization: true
      )
      validationCompositor.assemble()

      let baselineKey = validationCompositor.assembledSentence
        .generateKeyForPerception(cursor: max(validationCompositor.cursor - 1, 0))
      #expect(baselineKey?.ngramKey == "()&(di4,第)&(jiao1,交)")

      let suggestion = pom.fetchSuggestion(
        assembledResult: validationCompositor.assembledSentence,
        cursor: validationCompositor.cursor,
        timestamp: Date().timeIntervalSince1970
      )
      #expect(!suggestion.isEmpty)
      guard let firstSuggestionRAW = suggestion.candidates.first else {
        preconditionFailure("POM suggested nothing, or something wrong happen.")
      }
      #expect(firstSuggestionRAW.value == "遞交")
      #expect(firstSuggestionRAW.keyArray == ["di4", "jiao1"])

      let candidateSuggested = Homa.CandidatePair(
        keyArray: firstSuggestionRAW.keyArray,
        value: firstSuggestionRAW.value
      ).weighted(firstSuggestionRAW.probability)
      let cursorForOverride = suggestion.overrideCursor ?? 0
      do {
        try validationCompositor.overrideCandidate(
          candidateSuggested,
          at: cursorForOverride,
          type: suggestion.suggestedOverrideType,
          enforceRetokenization: true
        )
      } catch {
        try validationCompositor.overrideCandidateLiteral(
          candidateSuggested.pair.value,
          at: cursorForOverride,
          overrideType: suggestion.suggestedOverrideType,
          enforceRetokenization: true,
        )
      }
      validationCompositor.assemble()

      let assembledByPOM = validationCompositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledByPOM == "遞交")
    }
  }
}
