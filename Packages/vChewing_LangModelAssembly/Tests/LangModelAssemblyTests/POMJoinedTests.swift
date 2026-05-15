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
import LMAssemblyMaterials4Tests

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
        gramQuerier: lm.asGramQuerier()
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
        gramQuerier: validationLM.asGramQuerier()
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
        gramQuerier: lm.asGramQuerier()
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
        gramQuerier: lm.asGramQuerier()
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
        gramQuerier: validationLM.asGramQuerier()
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
        gramQuerier: lm.asGramQuerier()
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
        gramQuerier: validationLM.asGramQuerier()
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

    @Test
    func testPOM_AC04_DuoQiMemorization() throws {
      // 測試 POM 記憶使用者對「多期」→「多奇」的覆寫行為。
      // ---- Part A: 以不含 bigram 的 LM 驗證 POM 完整 round-trip ----
      let unigramOnlyData = """
      ㄉㄨㄛ 多 -5.053
      ㄉㄨㄛ 哆 -5.248
      ㄉㄨㄛ 朵 -6.212
      ㄑㄧˊ 期 -5.124
      ㄑㄧˊ 其 -5.125
      ㄑㄧˊ 騎 -5.14
      ㄑㄧˊ 奇 -5.184
      ㄑㄧˊ 旗 -5.2
      """
      let unigramLM = TestLM(rawData: unigramOnlyData)
      let pom = LMAssembly.LXPerceptor(dataURL: URL(fileURLWithPath: "/dev/null"))
      let compositor = Homa.Assembler(
        gramQuerier: unigramLM.asGramQuerier()
      )
      let readingKeys = ["ㄉㄨㄛ", "ㄑㄧˊ"]
      for key in readingKeys { try compositor.insertKey(key) }
      compositor.assemble()

      // 確認初始組句結果為兩個獨立 Gram
      let assembledBefore = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledBefore == "多 期")

      // 獲取覆寫前的感知 Key
      let keyBeforeOverride = compositor.assembledSentence
        .generateKeyForPerception(cursor: 1)
      #expect(keyBeforeOverride?.ngramKey == "()&(ㄉㄨㄛ,多)&(ㄑㄧˊ,期)")

      // 模擬使用者將 pos 1 改為「奇」
      var obsCaptured: Homa.PerceptionIntel?
      try compositor.overrideCandidate(
        Homa.CandidatePair(keyArray: ["ㄑㄧˊ"], value: "奇"),
        at: 1,
        enforceRetokenization: true
      ) {
        obsCaptured = $0
      }

      // 驗證覆寫後的組句結果
      let assembledAfterOverride = compositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledAfterOverride == "多 奇")

      guard let obsCaptured else {
        preconditionFailure("Should have captured the perception intel.")
      }
      // sameLenSwap 場景，key 反映覆寫後的結果。
      #expect(obsCaptured.contextualizedGramKey == "()&(ㄉㄨㄛ,多)&(ㄑㄧˊ,奇)")
      #expect(obsCaptured.candidate == "奇")

      // 記憶到 POM
      pom.memorizePerception(
        (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
        timestamp: nowTimeStamp
      )

      // ====== 檢查 POM 記憶內容 ======
      let currentMemory = pom.getSavableData()
      let firstObservationKey = currentMemory.first?.key
      guard let firstObservationKey else {
        preconditionFailure("POM memorized nothing.")
      }
      #expect(firstObservationKey == obsCaptured.contextualizedGramKey)

      // ====== 記憶效力測試 ======
      let validationLM = TestLM(rawData: unigramOnlyData)
      let validationCompositor = Homa.Assembler(
        gramQuerier: validationLM.asGramQuerier()
      )
      for key in readingKeys { try validationCompositor.insertKey(key) }
      validationCompositor.assemble()

      let assembledNow = validationCompositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledNow == "多 期")

      let suggestion = pom.fetchSuggestion(
        assembledResult: validationCompositor.assembledSentence,
        cursor: validationCompositor.cursor,
        timestamp: nowTimeStamp
      )
      #expect(!suggestion.isEmpty, "POM should suggest the memorized override.")
      guard let firstSuggestionRAW = suggestion.candidates.first else {
        preconditionFailure("POM suggested nothing.")
      }

      let candidateSuggested = Homa.CandidatePair(
        keyArray: firstSuggestionRAW.keyArray,
        value: firstSuggestionRAW.value
      ).weighted(firstSuggestionRAW.probability)
      let cursorForOverride = suggestion.overrideCursor ?? 1

      // 套用 POM 建議
      if (try? validationCompositor.overrideCandidate(
        candidateSuggested,
        at: cursorForOverride,
        type: suggestion.suggestedOverrideType,
        enforceRetokenization: true
      )) == nil {
        try validationCompositor.overrideCandidateLiteral(
          candidateSuggested.pair.value,
          at: cursorForOverride,
          overrideType: suggestion.suggestedOverrideType
        )
      }
      validationCompositor.assemble()

      let assembledByPOM = validationCompositor.assembledSentence.values.joined(separator: " ")
      #expect(assembledByPOM == "多 奇", "POM suggestion should correct to 多 奇.")

      // ---- Part B: 驗證 alternateKeys 的 bigram to split 匹配 ----
      let bigramLM = TestLM(rawData: LMATestsData.strDataCase4DuoQi)
      let bigramPOM = LMAssembly.LXPerceptor(dataURL: URL(fileURLWithPath: "/dev/null"))

      // 直接記憶拆分後的 key（模擬 bigram 被拆分覆寫後記錄的 key）
      let splitMemoryKey = "()&(ㄉㄨㄛ,多)&(ㄑㄧˊ,奇)"
      bigramPOM.memorizePerception(
        (splitMemoryKey, "奇"),
        timestamp: nowTimeStamp
      )
      #expect(bigramPOM.getSavableData().first?.key == splitMemoryKey)

      // 用 bigram 格式的查詢鍵查詢
      let bigramQueryKey = "()&()&(ㄉㄨㄛ-ㄑㄧˊ,多期)"
      let alternateKeys = bigramPOM.alternateKeysForTesting(bigramQueryKey)
      #expect(
        alternateKeys.contains(splitMemoryKey),
        "AlternateKeys must find split key from bigram query."
      )

      // 驗證 fetchSuggestion 也能正確找回
      let bigramCompositor = Homa.Assembler(
        gramQuerier: bigramLM.asGramQuerier()
      )
      for key in readingKeys { try bigramCompositor.insertKey(key) }
      bigramCompositor.assemble()

      let bigramSuggestion = bigramPOM.fetchSuggestion(
        assembledResult: bigramCompositor.assembledSentence,
        cursor: bigramCompositor.cursor,
        timestamp: nowTimeStamp
      )
      #expect(!bigramSuggestion.isEmpty, "FetchSuggestion must find memory from bigram query.")
      if let bigramCandidate = bigramSuggestion.candidates.first {
        #expect(bigramCandidate.value == "奇")
      }
    }
  }
}
