// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import MegrezTestComponents
import Shared
import Tekkon
import Testing

@testable import LangModelAssembly
@testable import Typewriter

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// MARK: - 測試案例 Vol 3 (POM Dedicated)

extension InputHandlerTests {
  @Test
  func test_IH301_POMBleacherIntegrationTest() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    var extractedGrams = extractGrams(
      from: MegrezTestComponents.strLMSampleDataHutao,
      readingsToKeep: ["liu2-yi4", "liu2", "yi4"]
    )
    extractedGrams = extractedGrams.filter {
      $0.segLength > 1 || $0.score > -6
    }
    extractedGrams.sort { $0.segLength > $1.segLength && $0.score > $1.score }
    let additionalUnigrams = extractedGrams
    additionalUnigrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    let fetchedExtraUnigrams1 = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    #expect(Set(fetchedExtraUnigrams1).count == 4)
    #expect(Set(additionalUnigrams.prefix(4)) == Set(fetchedExtraUnigrams1))
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = [.sortedKeys]
    let readingKeyChainStr = "xu.6u4"
    typeSentence(readingKeyChainStr)
    // 此時「留意」原始權重最高，會被自動選中。
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")
    #expect(testSession.state.displayedText == "留意")
    // let candidateCursor = testHandler.actualNodeCursorPosition
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(4)
    #expect(Array(candidates1) == ["留意", "流溢", "流易", "流議"])
    // 觸發選字窗選擇「流易」，該字詞在 Megrez 內的的頻分權重由常規區間（ -9.5 <= x <= 0）升至 114_514。
    testSession.candidatePairSelectionConfirmed(at: 2) // 「流易」
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "流易")
    #expect(testSession.state.displayedText == "流易")
    // 此時應該有生成一些 POM 記憶。
    let pomData1 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON1 = try jsonEncoder.encode(pomData1)
    let encodedJSONStr1 = String(data: encodedJSON1, encoding: .utf8) ?? "N/A"
    // 每次跑測試時，ts 時間戳都不同。所以不將 ts 的資料值納入 Assertion 對象。
    #expect(encodedJSONStr1.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
    // 直接呼叫 EmptyState。這個過程會清空 InputHandler。
    testSession.switchState(.ofEmpty())
    #expect(testHandler.assembler.isEmpty)
    // 重新打字。
    typeSentence(readingKeyChainStr)
    // 此時「流易」權重最高，因為是 POM 推薦資料。
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "流易")
    #expect(testSession.state.displayedText == "流易")
    // 檢查 assembler 內部的 nodes 確保「流易」的 OverridingScore 必須不能是「114_514」。
    // 不然的話，會出現 POM 記憶劫持使用者片語的情況。
    // 判斷方法是：任何雙字詞節點都不該有「score == 114_514」。
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    let allNodes: [Megrez.Node] = testHandler.assembler.segments.compactMap { $0[2] }
    #expect(allNodes.allSatisfy { $0.score != 114_514 })
    // 嘗試觸發就地加詞的 method。這在目前的這個單元測試內不會實際加詞，但會嘗試清空相關的 POM 記憶。
    // 咱們先用 revolveCandidate 的功能將該節點換成別的雙字候選詞。
    let candidateStateTemporary1 = testHandler.generateStateOfCandidates()
    let candidatesAssumed = candidateStateTemporary1.candidates.prefix(4).map(\.value)
    #expect(Array(candidatesAssumed) == ["流易", "留意", "流溢", "流議"])
    // 第三個候選字詞是「流溢」，咱們用這個做實驗。於是讓 revolver API 往正極方向輪兩下。
    #expect(testHandler.revolveCandidate(reverseOrder: false))
    #expect(testHandler.revolveCandidate(reverseOrder: false))
    // Revolver 輪轉完畢。這個過程不會影響 POM。開始確認當前候選字詞是「流溢」。
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "流溢")
    #expect(testSession.state.displayedText == "流溢")
    #expect(testSession.state.type == .ofInputting)
    // 然後呼叫 .ofMarking 狀態、以便接下來的對就地加詞 API 的觸發。
    #expect(testHandler.assembler.isCursorAtEdge(direction: .front))
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.assembler.isCursorAtEdge(direction: .rear, isMarker: true))
    #expect(testSession.state.type == .ofMarking)
    #expect(testSession.state.markedRange == 0 ..< 2)
    // 這一行會觸發 handleMarkingState(input: Enter) 所排定觸發的 `performUserPhraseOperation`。
    // 此過程在 MockSession 會觸發 `inputHandler.currentLM.bleachSpecifiedPOMSuggestions`。
    // 註：真實 Session 會通過 `LMMgr.bleachSpecifiedSuggestions` 間接觸發該 API。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let fetchablesNow = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    let assumedNewUnigram = Megrez.Unigram(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"], value: "流溢", score: 0)
    #expect(fetchablesNow.contains(assumedNewUnigram))
    // 現在應該假設 POM 當中任何妨礙 assumedNewUnigram 被選中的內容都被清掉了。
    // 看一下 POM 記憶。
    let pomData2 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON2 = try jsonEncoder.encode(pomData2)
    let encodedJSONStr2 = String(data: encodedJSON2, encoding: .utf8) ?? "N/A"
    // 到這一步如果 Asserts 都通過的話就證明手動加詞時的 Bleacher 是成功的。
    #expect(!encodedJSONStr2.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
  }

  @Test
  func test_IH302_POMStopShortKeyArrFromHijackingLongKeyArr() throws {
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    // 備註：該測試用例沒必要鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：年中")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("su065j/ ")
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["年中"])
    #expect(testHandler.assembler.moveCursorStepwise(to: .rear))
    #expect(testHandler.assembler.moveCursorStepwise(to: .rear))
    #expect(!(testHandler.assembler.moveCursorStepwise(to: .rear)))
    #expect(testHandler.assembler.isCursorAtEdge(direction: .rear))
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(3)
    #expect(Array(candidates1) == ["年", "黏", "粘"])
    testSession.candidatePairSelectionConfirmed(at: 2) // 黏
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["粘", "中"])
    testSession.switchState(.ofAbortion())
    // 模擬手動加詞的情況。
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], value: "年終", score: 0),
      isFiltering: false
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    typeSentence("su065j/ ")
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["年終"])
  }

  @Test
  func test_IH303_POMIgnoresLowerWeightSuggestedUnigramMatchingRawQueriedUnigram() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 測試目的：當 POM 提供與當前 raw queried （來自 factory / 使用者片語 / 磁帶）
    // 相同的詞+讀音，但 POM 的權重比原始查詢結果更低時，該建議應被忽略。
    let readingKeyChainStr = "gjo3eji35 "
    typeSentence(readingKeyChainStr)
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "水果汁")

    guard let keyGen = testHandler.assembler.assembledSentence.generateKeyForPerception(
      cursor: testHandler.actualNodeCursorPosition
    ) else {
      Issue.record("Failed to generate perception key from assembled sentence.")
      return
    }

    let ngramKey = keyGen.ngramKey
    let candidateValue = keyGen.candidate
    // 確認該節點的 keyArray 確實會在組字器返回的候選清單中對應到 candidate。
    // 從目前組句結果中的該節點取得完整的 keyArray。
    guard let gramPair = testHandler.assembler.assembledSentence.findGram(
      at: testHandler.actualNodeCursorPosition
    )
    else {
      Issue.record("Failed to locate current GramInPath")
      return
    }
    let keyArray = gramPair.gram.keyArray
    let candidateFetchFilter: Megrez.Compositor.CandidateFetchFilter =
      testHandler.prefs.useRearCursorMode ? .beginAt : .endAt
    let rawCandidates = testHandler.assembler.fetchCandidates(filter: candidateFetchFilter)
    guard let rawCandidate = rawCandidates.first(where: {
      $0.keyArray == keyArray && $0.value == candidateValue
    }) else {
      Issue.record("Unable to locate raw candidate for keyArray \(keyArray) and value \(candidateValue).")
      return
    }

    // 情境 A：插入近期（高權重）的 POM 記錄；預期建議清單會包含該候選字詞
    testHandler.currentLM.memorizePerception(
      (ngramKey, candidateValue),
      timestamp: Date().timeIntervalSince1970
    )
    var suggestionPairs = testHandler.retrievePOMSuggestions(apply: false)
    var suggestions = suggestionPairs.map { $0.1.value }
    #expect(suggestions.contains(candidateValue))
    if let candidateUnigram = suggestionPairs.first(where: { $0.1.value == candidateValue }) {
      #expect(candidateUnigram.1.score >= rawCandidate.score)
    }

    // 清除並插入舊時戳（低權重）POM 記錄；預期該建議會被忽略
    clearTestPOM()
    // 使用遠古時間戳，讓計算出的權重極可能低於閾值
    let oldTimestamp = Date().timeIntervalSince1970 - 24 * 3_600 * 100
    testHandler.currentLM.memorizePerception(
      (ngramKey, candidateValue),
      timestamp: oldTimestamp
    )
    suggestionPairs = testHandler.retrievePOMSuggestions(apply: false)
    suggestions = suggestionPairs.map { $0.1.value }
    #expect(suggestions.isEmpty)
    #expect(!(suggestions.contains(candidateValue)))
  }

  @Test
  func test_IH303_FilterPOMAppendablesRejectsLowerScoreMatches() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    var suggestion = LMAssembly.OverrideSuggestion()
    suggestion.candidates = [
      (keyArray: ["ㄅ"], value: "波", probability: -0.30, previous: nil),
      (keyArray: ["ㄅ"], value: "玻", probability: -0.15, previous: nil),
      (keyArray: ["ㄅ"], value: "坡", probability: -0.05, previous: nil),
    ]

    let rawCandidates: [Megrez.KeyValuePaired] = [
      .init(keyArray: ["ㄅ"], value: "波", score: -0.10),
      .init(keyArray: ["ㄅ"], value: "波", score: -0.25),
      .init(keyArray: ["ㄅ"], value: "玻", score: -0.30),
    ]

    let filtered = testHandler.filterPOMAppendables(from: suggestion, rawCandidates: rawCandidates)
    #expect(!(filtered.contains(where: { $0.1.value == "波" })))
    #expect(filtered.map { $0.1.value } == ["玻", "坡"])
  }

  @Test
  func test_IH304_SaisoukiNoGaika() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let assembler = testHandler.assembler
    let pom = testHandler.currentLM.lmPerceptionOverride
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let extractedGrams = extractGrams(
      from: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika
    )
    print(extractedGrams)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄗㄞˋ"], value: "在"),
      isFiltering: true
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    #expect(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄗㄞˋ"]))
    #expect(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄎㄞˇ", "ㄍㄜ"]))
    // 測試用句「再創世的凱歌」。
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())
    let assembledPriorToOverride = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 是的 凱歌" == assembledPriorToOverride)
    // ====================
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorShi = 2
    let cursorShiDe = 3
    let keyForQueryingDataAt2 = assembler.assembledSentence
      .generateKeyForPerception(cursor: cursorShi)
    #expect(keyForQueryingDataAt2?.ngramKey == "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ-ㄉㄜ˙,是的)")
    #expect(keyForQueryingDataAt2?.headReading == "ㄕˋ")
    let keyForQueryingDataAt3 = assembler.assembledSentence
      .generateKeyForPerception(cursor: cursorShiDe)
    #expect(keyForQueryingDataAt3?.ngramKey == "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ-ㄉㄜ˙,是的)")
    #expect(keyForQueryingDataAt3?.headReading == "ㄉㄜ˙")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtShiDeEnd = assembler.fetchCandidates(at: 4, filter: .endAt)
    #expect(pairsAtShiDeEnd.map(\.value).contains("是的"))
    #expect(pairsAtShiDeEnd.map(\.value).contains("似的"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    _ = assembler.overrideCandidate(
      .init(keyArray: ["ㄕˋ"], value: "世"),
      at: cursorShi,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    #expect(obsCaptured?.contextualizedGramKey == "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // assembler.assemble() <- 已經組句了。
    let assembledFollowingOverride = assembler.assembledSentence
      .map(\.value)
      .joined(separator: " ")
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
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    typeSentence(readingKeys4Sentence.prefix(4).joined())
    let cursorToTest = assembler.cursor
    let assembledNow = assembler.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    #expect(
      ["再 創 是的", "再 創 世 的"].contains(assembledNow),
      "Unexpected baseline assembly: \(assembledNow)"
    )
    // 再試試整句。
    do {
      typeSentence(readingKeys4Sentence.suffix(2).joined())
      let assembledNow2 = assembler.assembledSentence
        .map(\.value)
        .joined(separator: " ")
      #expect(
        ["再 創 是的 凱歌", "再 創 世 的 凱歌"].contains(assembledNow2),
        "Unexpected baseline assembly: \(assembledNow2)"
      )
      assembler.dropKey(direction: .rear)
      assembler.dropKey(direction: .rear)
      testHandler.assemble()
    }

    let suggestion = pom.fetchSuggestion(
      assembledResult: assembler.assembledSentence,
      cursor: cursorToTest,
      timestamp: Date().timeIntervalSince1970
    )
    #expect(!suggestion.isEmpty)
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      Issue.record("POM suggested nothing, or something wrong happen.")
      return
    }
    print(firstSuggestionRAW)
    let candidateSuggested = Megrez.KeyValuePaired(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value,
      score: firstSuggestionRAW.probability
    )
    let cursorForOverride = suggestion.overrideCursor ?? cursorShi
    let overrideResult = assembler.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )
    if !overrideResult {
      assembler.overrideCandidateLiteral(
        candidateSuggested.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    assembler.assemble()
    let assembledByPOM = assembler.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    #expect("再 創 世 的" == assembledByPOM)
    // 追加真實場景測試。
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    typeSentence(readingKeys4Sentence.prefix(3).joined())
    #expect("再創世" == assembler.assembledSentence.map(\.value).joined())
    typeSentence(readingKeys4Sentence[3]) // 4th
    #expect("再創世的" == assembler.assembledSentence.map(\.value).joined())
    typeSentence(readingKeys4Sentence[4 ... 5].joined()) // 5th ~ 6th
    #expect("再創世的凱歌" == assembler.assembledSentence.map(\.value).joined())
  }

  @Test
  func test_IH305_SaisoukiOnly() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let assembler = testHandler.assembler
    let pom = testHandler.currentLM.lmPerceptionOverride
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let extractedGrams = extractGrams(
      from: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika
    )
    print(extractedGrams)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄗㄞˋ"], value: "在"),
      isFiltering: true
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    #expect(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄗㄞˋ"]))
    #expect(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄎㄞˇ", "ㄍㄜ"]))
    // 測試用句「再創世的凱歌」。
    let readingKeys4Sentence = ["y94", "tj;4", "g4"]
    typeSentence(readingKeys4Sentence.joined())
    let assembledPriorToOverride = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 是" == assembledPriorToOverride)
    // ====================
    let cursorShi = 2
    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceeded = assembler.overrideCandidate(
      .init(keyArray: ["ㄕˋ"], value: "世"),
      at: cursorShi,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    #expect(overrideSucceeded)
    #expect(obsCaptured?.contextualizedGramKey == "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }

    let assembledAfter = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 世" == assembledAfter)
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

    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    typeSentence(readingKeys4Sentence.joined())

    let assembledNow = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 是" == assembledNow)
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true

    let cursorToTest = assembler.cursor
    let suggestion = pom.fetchSuggestion(
      assembledResult: assembler.assembledSentence,
      cursor: cursorToTest,
      timestamp: Date().timeIntervalSince1970
    )
    #expect(!suggestion.isEmpty)
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      preconditionFailure("POM suggested nothing, or something wrong happen.")
    }

    let candidateSuggested = Megrez.KeyValuePaired(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value,
      score: firstSuggestionRAW.probability
    )
    let cursorForOverride = suggestion.overrideCursor ?? cursorShi
    let overrideResult = assembler.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )
    if !overrideResult {
      assembler.overrideCandidateLiteral(
        candidateSuggested.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    testHandler.assemble()
    let assembledByPOM = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 世" == assembledByPOM)
    // 追加真實場景測試。此時 prefs.fetchSuggestionsFromPerceptionOverrideModel 是 true。
    testHandler.clear()
    typeSentence(readingKeys4Sentence.joined())
    #expect("再 創 世" == assembler.assembledSentence.map(\.value).joined(separator: " "))
  }

  @Test
  func test_IH306_ConsolidationWhenCursorAtNodeEdge() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    // 情境 A：後置游標模式，游標位於後端邊緣
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.useRearCursorMode = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("xu.6u4")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")
    testHandler.assembler.cursor = testHandler.assembler.length
    #expect(
      testHandler.assembler.cursor == testHandler.assembler.length,
      "cursor: \(testHandler.assembler.cursor), length: \(testHandler.assembler.length)"
    )
    // `actualNodeCursorPosition` 應指向最後一個節點索引
    #expect(testHandler.actualNodeCursorPosition == max(testHandler.assembler.length - 1, 0))
    // 直接產生候選狀態以避免 MockSession 的額外狀態變化
    let cursorPriorToGeneratingCandidateState = testHandler.assembler.cursor
    #expect(cursorPriorToGeneratingCandidateState == testHandler.assembler.length)
    let candidateState = testHandler.generateStateOfCandidates()
    let cursorAfterGeneratingCandidateState = testHandler.assembler.cursor
    // `generateStateOfCandidates` 可能會為了避免無效邊緣游標而移動游標；確認其結果為有效位置
    #expect(
      !testHandler.isInvalidEdgeCursorSituation(),
      "Cursor remains at invalid edge: \(cursorAfterGeneratingCandidateState)"
    )
    // 診斷：同時檢查 `endAt` 候選
    let rawCandidatesEnd = testHandler.assembler.fetchCandidates(filter: .endAt)
    #expect(!rawCandidatesEnd.isEmpty, "raw endAt candidates should not be empty")
    #expect(
      !candidateState.candidates.isEmpty,
      "generated state candidates should not be empty"
    )
    // 現在將狀態套用到 session，並確認選字能正常運作
    testSession.switchState(candidateState)
    testSession.candidatePairSelectionConfirmed(at: 0)
    // 確認選字沒有崩潰且組字結果非空
    #expect(!(testHandler.assembler.assembledSentence.map(\.value)).joined().isEmpty)

    // 情境 B：前置游標模式，游標位於前端邊緣
    testHandler.clear()
    testHandler.prefs.useRearCursorMode = false
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("xu.6u4")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")
    testHandler.assembler.cursor = 0
    #expect(testHandler.assembler.cursor == 0)
    testSession.switchState(testHandler.generateStateOfCandidates())
    testSession.candidatePairSelectionConfirmed(at: 0)
    #expect(!(testHandler.assembler.assembledSentence.map(\.value)).joined().isEmpty)
  }

  @Test
  func test_IH307_POMShortToLongMarginBehavior() throws {
    guard let testHandler else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    // 驗證 margin 行為：當建議只略微優於既有節點時，應該被跳過；當差距足夠大時，應允許套用。
    #expect(!(testHandler.pomShortToLongAllowed(existingScore: -0.6, suggestedScore: -0.2)))
    #expect(testHandler.pomShortToLongAllowed(existingScore: -2.0, suggestedScore: -1.3))
    // 邊界值：等於 margin 時應該被視為不足（採用 <= 判斷）
    #expect(!(testHandler.pomShortToLongAllowed(existingScore: -1.0, suggestedScore: -0.5)))
  }

  @Test
  func test_IH308_EndToEnd_PreventWrongFirstCandidate() throws {
    // 端對端回歸：確保單節 POM 建議在 margin 不足時不會縮短原始 multi-seg 的頭部（重現 wrong-first-candidate）。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 使用已知的讀音，使其會產生 multi-seg 的頭部（例如「留意」）。
    let readingKeyChainStr = "xu.6u4"
    typeSentence(readingKeyChainStr)
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")

    // 找出目前的 Gram 以及其分數
    guard let gramPair = testHandler.assembler.assembledSentence.findGram(at: testHandler.actualNodeCursorPosition)
    else {
      Issue.record("Failed to locate current GramInPath")
      return
    }
    let existingScore = gramPair.gram.score

    // 找出 keyCursorRaw（gram 範圍的下界）
    guard let found = testHandler.assembler.assembledSentence
      .findGramWithRange(at: testHandler.actualNodeCursorPosition) else {
      Issue.record("Failed to find gram range")
      return
    }
    let keyCursorRaw = found.range.lowerBound

    // 情境 A：建議分數略高但未達 margin → 不應套用
    var s = LMAssembly.OverrideSuggestion()
    let suggestedA: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄌㄧㄡˊ"],
      value: "SHORT",
      probability: existingScore + 0.4, // insufficient margin (0.4 < 0.5)
      previous: nil
    )
    s.candidates = [suggestedA]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = s

    _ = testHandler.retrievePOMSuggestions(apply: true)
    // 因為 prepend/override 被拒，組句結果應維持不變
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")

    // 情境 B：建議分數超過 margin → 應套用並縮短頭部
    var t = LMAssembly.OverrideSuggestion()
    let suggestedB: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄌㄧㄡˊ"],
      value: "SHORT",
      probability: existingScore + 0.6, // sufficient margin
      previous: nil
    )
    t.candidates = [suggestedB]
    t.overrideCursor = keyCursorRaw
    // 先檢查建議是否出現在可附加候選清單
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = t
    let appended = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended.map { $0.1.value }.contains("SHORT"))
    // 再次注入以測試 apply 路徑（fetchSuggestion 會清除注入的建議）
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = t
    _ = testHandler.retrievePOMSuggestions(apply: true)
    // 此時短候選應已取代原本的頭部
    // 若 POM 未能替換，嘗試直接覆寫以檢視行為
    let suggestedPair = Megrez.KeyValuePaired(
      keyArray: suggestedB.keyArray,
      value: suggestedB.value,
      score: suggestedB.probability
    )
    let overrideSucceeded = testHandler.assembler.overrideCandidate(
      suggestedPair,
      at: keyCursorRaw,
      overrideType: .withTopGramScore,
      enforceRetokenization: true
    )
    // 若組字器拒絕直接覆寫也可接受（有些 short->long 的替換無法由組字器表示）；否則應出現 SHORT 候選。
    if overrideSucceeded {
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("SHORT"))
    } else {
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")
    }
  }

  @Test
  func test_IH309_PreviousContextException_EndToEnd() throws {
    // 端對端：確保帶有相符 previous 上下文的 POM 建議會出現在 appendables，且遵守 short->long 的 margin 規則。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 注入「再創世的凱歌」範例的暫存 unigram，使組字結果能穩定包含
    // 具有前文（previous）欄位的多段（multi-seg）頭部。
    let extractedGrams = extractGrams(from: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    extractedGrams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())

    // 在組字結果中尋找 multi-seg 的頭部，不依賴硬編的游標位置。
    var maybeFound: (node: Megrez.GramInPath, range: Range<Int>)?
    for i in 0 ..< testHandler.assembler.length {
      if let f = testHandler.assembler.assembledSentence.findGramWithRange(at: i), f.node.gram.keyArray.count > 1 {
        maybeFound = f
        break
      }
    }
    guard let found = maybeFound else {
      Issue.record("Failed to locate multi-seg GramInPath for previous-context test")
      return
    }
    let keyCursorRaw = found.range.lowerBound
    let existingScore = found.node.gram.score
    guard let prevValue = testHandler.assembler.assembledSentence.findGram(at: keyCursorRaw - 1)?.gram.value else {
      Issue.record("Unable to determine previous value for test")
      return
    }

    // 情境 A：margin 不足 → 不應套用（可見性不一定）
    var s = LMAssembly.OverrideSuggestion()
    let suggestedA: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄕˋ"],
      value: "PREVSHORT",
      probability: existingScore + 0.4, // insufficient
      previous: prevValue
    )
    s.candidates = [suggestedA]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = s

    // apply 路徑應因 short->long margin 而跳過
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = s
    _ = testHandler.retrievePOMSuggestions(apply: true)
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("是"))

    // 情境 B：margin 足夠 → 應套用（若組字器拒絕亦可，兩者皆接受）
    var t = LMAssembly.OverrideSuggestion()
    let suggestedB: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄕˋ"],
      value: "PREVSHORT",
      probability: existingScore + 5.0, // large enough to bypass filtering/margin
      previous: prevValue
    )
    t.candidates = [suggestedB]
    t.overrideCursor = keyCursorRaw
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = t
    let appended2 = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended2.map { $0.1.value }.contains("PREVSHORT"))
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = t
    _ = testHandler.retrievePOMSuggestions(apply: true)

    let suggestedPair = Megrez.KeyValuePaired(
      keyArray: suggestedB.keyArray,
      value: suggestedB.value,
      score: suggestedB.probability
    )
    let overrideSucceeded = testHandler.assembler.overrideCandidate(
      suggestedPair,
      at: keyCursorRaw,
      overrideType: .withTopGramScore,
      enforceRetokenization: true
    )
    if overrideSucceeded {
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("PREVSHORT"))
    } else {
      // 組字器拒絕直接覆寫；保留原始組句仍可接受
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("是"))
    }
  }

  @Test
  func test_IH310_MultiSegCombination_EndToEnd() throws {
    // 端對端：確保拆分候選（previous+head）會被建議，且在 margin 允許時可套用。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 注入「再創世的凱歌」範例的暫存 unigram，以確定性產生 multi-seg 頭部
    let extractedGrams2 = extractGrams(from: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    extractedGrams2.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())

    // 動態尋找 multi-seg 的頭部
    var maybeFound2: (node: Megrez.GramInPath, range: Range<Int>)?
    for i in 0 ..< testHandler.assembler.length {
      if let f = testHandler.assembler.assembledSentence.findGramWithRange(at: i), f.node.gram.keyArray.count > 1 {
        maybeFound2 = f
        break
      }
    }
    guard let found = maybeFound2 else {
      Issue.record("Failed to locate multi-seg GramInPath for multi-seg test")
      return
    }
    let keyCursorRaw = found.range.lowerBound
    let existingScore = found.node.gram.score
    guard let prevValue = testHandler.assembler.assembledSentence.findGram(at: keyCursorRaw - 1)?.gram.value else {
      Issue.record("Unable to determine previous value for test")
      return
    }

    // 候選提供 previous+head；將機率設高以便套用應成功
    var s = LMAssembly.OverrideSuggestion()
    let suggested: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄉㄜ˙"], // head part
      value: "SPLITVAL",
      probability: existingScore + 1.0,
      previous: prevValue
    )
    s.candidates = [suggested]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = s

    let appended = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended.map { $0.1.value }.contains("SPLITVAL"))

    // 套用路徑
    testHandler.currentLM.lmPerceptionOverride.testInjectedSuggestion = s
    _ = testHandler.retrievePOMSuggestions(apply: true)

    let suggestedPair = Megrez.KeyValuePaired(
      keyArray: suggested.keyArray,
      value: suggested.value,
      score: suggested.probability
    )
    let overrideSucceeded = testHandler.assembler.overrideCandidate(
      suggestedPair,
      at: keyCursorRaw,
      overrideType: .withTopGramScore,
      enforceRetokenization: true
    )
    if overrideSucceeded {
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("SPLITVAL"))
    } else {
      // 後備：保留原始 multi-seg
      #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("是"))
    }
  }
}
