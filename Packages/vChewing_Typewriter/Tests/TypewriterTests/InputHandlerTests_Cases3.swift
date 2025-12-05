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
import XCTest

@testable import LangModelAssembly
@testable import Typewriter

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// MARK: - 測試案例 Vol 3 (POM Dedicated)

extension InputHandlerTests {
  func test_IH301_POMBleacherIntegrationTest() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
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
    XCTAssert(Set(fetchedExtraUnigrams1).count == 4)
    XCTAssertEqual(Set(additionalUnigrams.prefix(4)), Set(fetchedExtraUnigrams1))
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = [.sortedKeys]
    let readingKeyChainStr = "xu.6u4"
    typeSentence(readingKeyChainStr)
    // 此時「留意」原始權重最高，會被自動選中。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "留意")
    XCTAssertEqual(testSession.state.displayedText, "留意")
    // let candidateCursor = testHandler.actualNodeCursorPosition
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(4)
    XCTAssertEqual(candidates1, ["留意", "流溢", "流易", "流議"])
    // 觸發選字窗選擇「流易」，該字詞在 Megrez 內的的頻分權重由常規區間（ -9.5 <= x <= 0）升至 114_514。
    testSession.candidatePairSelectionConfirmed(at: 2) // 「流易」
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流易")
    XCTAssertEqual(testSession.state.displayedText, "流易")
    // 此時應該有生成一些 POM 記憶。
    let pomData1 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON1 = try jsonEncoder.encode(pomData1)
    let encodedJSONStr1 = String(data: encodedJSON1, encoding: .utf8) ?? "N/A"
    // 每次跑測試時，ts 時間戳都不同。所以不將 ts 的資料值納入 Assertion 對象。
    XCTAssertTrue(encodedJSONStr1.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
    // 直接呼叫 EmptyState。這個過程會清空 InputHandler。
    testSession.switchState(.ofEmpty())
    XCTAssertTrue(testHandler.assembler.isEmpty)
    // 重新打字。
    typeSentence(readingKeyChainStr)
    // 此時「流易」權重最高，因為是 POM 推薦資料。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流易")
    XCTAssertEqual(testSession.state.displayedText, "流易")
    // 檢查 assembler 內部的 nodes 確保「流易」的 OverridingScore 必須不能是「114_514」。
    // 不然的話，會出現 POM 記憶劫持使用者片語的情況。
    // 判斷方法是：任何雙字詞節點都不該有「score == 114_514」。
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    let allNodes: [Megrez.Node] = testHandler.assembler.segments.compactMap { $0[2] }
    XCTAssertTrue(allNodes.allSatisfy { $0.score != 114_514 })
    // 嘗試觸發就地加詞的 method。這在目前的這個單元測試內不會實際加詞，但會嘗試清空相關的 POM 記憶。
    // 咱們先用 revolveCandidate 的功能將該節點換成別的雙字候選詞。
    let candidateStateTemporary1 = testHandler.generateStateOfCandidates()
    let candidatesAssumed = candidateStateTemporary1.candidates.prefix(4).map(\.value)
    XCTAssertEqual(candidatesAssumed, ["流易", "留意", "流溢", "流議"])
    // 第三個候選字詞是「流溢」，咱們用這個做實驗。於是讓 revolver API 往正極方向輪兩下。
    XCTAssertTrue(testHandler.revolveCandidate(reverseOrder: false))
    XCTAssertTrue(testHandler.revolveCandidate(reverseOrder: false))
    // Revolver 輪轉完畢。這個過程不會影響 POM。開始確認當前候選字詞是「流溢」。
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "流溢")
    XCTAssertEqual(testSession.state.displayedText, "流溢")
    XCTAssertEqual(testSession.state.type, .ofInputting)
    // 然後呼叫 .ofMarking 狀態、以便接下來的對就地加詞 API 的觸發。
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .front))
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    XCTAssertTrue(testHandler.triageInput(event: arrLeftEvent.asEvent))
    XCTAssertTrue(testHandler.triageInput(event: arrLeftEvent.asEvent))
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .rear, isMarker: true))
    XCTAssertEqual(testSession.state.type, .ofMarking)
    XCTAssertEqual(testSession.state.markedRange, 0 ..< 2)
    // 這一行會觸發 handleMarkingState(input: Enter) 所排定觸發的 `performUserPhraseOperation`。
    // 此過程在 MockSession 會觸發 `inputHandler.currentLM.bleachSpecifiedPOMSuggestions`。
    // 註：真實 Session 會通過 `LMMgr.bleachSpecifiedSuggestions` 間接觸發該 API。
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let fetchablesNow = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    let assumedNewUnigram = Megrez.Unigram(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"], value: "流溢", score: 0)
    XCTAssert(fetchablesNow.contains(assumedNewUnigram))
    // 現在應該假設 POM 當中任何妨礙 assumedNewUnigram 被選中的內容都被清掉了。
    // 看一下 POM 記憶。
    let pomData2 = testHandler.currentLM.lmPerceptionOverride.getSavableData()
    let encodedJSON2 = try jsonEncoder.encode(pomData2)
    let encodedJSONStr2 = String(data: encodedJSON2, encoding: .utf8) ?? "N/A"
    // 到這一步如果 Asserts 都通過的話就證明手動加詞時的 Bleacher 是成功的。
    XCTAssertTrue(!encodedJSONStr2.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
  }

  func test_IH302_POMStopShortKeyArrFromHijackingLongKeyArr() throws {
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    // 備註：該測試用例沒必要鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：年中")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("su065j/ ")
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["年中"])
    XCTAssertTrue(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertTrue(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertFalse(testHandler.assembler.moveCursorStepwise(to: .rear))
    XCTAssertTrue(testHandler.assembler.isCursorAtEdge(direction: .rear))
    testSession.switchState(testHandler.generateStateOfCandidates())
    let candidates1 = testSession.state.candidates.map(\.value).prefix(3)
    XCTAssertEqual(candidates1, ["年", "黏", "粘"])
    testSession.candidatePairSelectionConfirmed(at: 2) // 黏
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["粘", "中"])
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
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value), ["年終"])
  }

  func test_IH303_POMIgnoresLowerWeightSuggestedUnigramMatchingRawQueriedUnigram() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
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
    XCTAssertEqual(testHandler.assembler.assembledSentence.map(\.value).joined(), "水果汁")

    guard let keyGen = testHandler.assembler.assembledSentence.generateKeyForPerception(
      cursor: testHandler.actualNodeCursorPosition
    ) else {
      XCTFail("Failed to generate perception key from assembled sentence.")
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
      XCTFail("Failed to locate current GramInPath")
      return
    }
    let keyArray = gramPair.gram.keyArray
    let candidateFetchFilter: Megrez.Compositor.CandidateFetchFilter =
      testHandler.prefs.useRearCursorMode ? .beginAt : .endAt
    let rawCandidates = testHandler.assembler.fetchCandidates(filter: candidateFetchFilter)
    guard let rawCandidate = rawCandidates.first(where: {
      $0.keyArray == keyArray && $0.value == candidateValue
    }) else {
      XCTFail("Unable to locate raw candidate for keyArray \(keyArray) and value \(candidateValue).")
      return
    }

    // 情境 A：插入近期（高權重）的 POM 記錄；預期建議清單會包含該候選字詞
    testHandler.currentLM.memorizePerception(
      (ngramKey, candidateValue),
      timestamp: Date().timeIntervalSince1970
    )
    var suggestionPairs = testHandler.retrievePOMSuggestions(apply: false)
    var suggestions = suggestionPairs.map { $0.1.value }
    XCTAssertTrue(suggestions.contains(candidateValue))
    if let candidateUnigram = suggestionPairs.first(where: { $0.1.value == candidateValue }) {
      XCTAssertGreaterThanOrEqual(candidateUnigram.1.score, rawCandidate.score)
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
    XCTAssertTrue(suggestions.isEmpty)
    XCTAssertFalse(suggestions.contains(candidateValue))
  }

  func test_IH303_FilterPOMAppendablesRejectsLowerScoreMatches() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
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
    XCTAssertFalse(filtered.contains(where: { $0.1.value == "波" }))
    XCTAssertEqual(filtered.map { $0.1.value }, ["玻", "坡"])
  }

  func test_IH304_SaisoukiNoGaika() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
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
    XCTAssert(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄗㄞˋ"]))
    XCTAssert(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄎㄞˇ", "ㄍㄜ"]))
    // 測試用句「再創世的凱歌」。
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())
    let assembledBefore = assembler.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 是的 凱歌", assembledBefore)
    // ====================
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorShi = 2
    let cursorShiDe = 3
    let keyForQueryingDataAt2 = assembler.assembledSentence
      .generateKeyForPerception(cursor: cursorShi)
    XCTAssertEqual(keyForQueryingDataAt2?.ngramKey, "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ-ㄉㄜ˙,是的)")
    XCTAssertEqual(keyForQueryingDataAt2?.headReading, "ㄕˋ")
    let keyForQueryingDataAt3 = assembler.assembledSentence
      .generateKeyForPerception(cursor: cursorShiDe)
    XCTAssertEqual(keyForQueryingDataAt3?.ngramKey, "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ-ㄉㄜ˙,是的)")
    XCTAssertEqual(keyForQueryingDataAt3?.headReading, "ㄉㄜ˙")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtShiDeEnd = assembler.fetchCandidates(at: 4, filter: .endAt)
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("是的"))
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("似的"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    _ = assembler.overrideCandidate(
      .init(keyArray: ["ㄕˋ"], value: "世"),
      at: cursorShi,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // assembler.assemble() <- 已經組句了。
    let assembledAfter = assembler.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("再 創 世 的 凱歌" == assembledAfter)
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
    XCTAssertEqual(firstObservationKey, obsCaptured.contextualizedGramKey)
    // 然後是記憶效力測試：
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    typeSentence(readingKeys4Sentence.prefix(4).joined())
    let cursorToTest = assembler.cursor
    let assembledNow = assembler.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertTrue(
      ["再 創 是的", "再 創 世 的"].contains(assembledNow),
      "Unexpected baseline assembly: \(assembledNow)"
    )
    // 再試試整句。
    do {
      typeSentence(readingKeys4Sentence.suffix(2).joined())
      let assembledNow2 = assembler.assembledSentence
        .map(\.value)
        .joined(separator: " ")
      XCTAssertTrue(
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
    XCTAssertTrue(!suggestion.isEmpty)
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      XCTFail("POM suggested nothing, or something wrong happen.")
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
    XCTAssertEqual("再 創 世 的", assembledByPOM)
    // 追加真實場景測試。
    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    typeSentence(readingKeys4Sentence.prefix(3).joined())
    XCTAssertEqual("再創世", assembler.assembledSentence.map(\.value).joined())
    typeSentence(readingKeys4Sentence[3]) // 4th
    XCTAssertEqual("再創世的", assembler.assembledSentence.map(\.value).joined())
    typeSentence(readingKeys4Sentence[4 ... 5].joined()) // 5th ~ 6th
    XCTAssertEqual("再創世的凱歌", assembler.assembledSentence.map(\.value).joined())
  }

  func test_IH305_SaisoukiOnly() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
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
    XCTAssert(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄗㄞˋ"]))
    XCTAssert(testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄎㄞˇ", "ㄍㄜ"]))
    // 測試用句「再創世的凱歌」。
    let readingKeys4Sentence = ["y94", "tj;4", "g4"]
    typeSentence(readingKeys4Sentence.joined())
    let assembledBefore = assembler.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 是", assembledBefore)
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
    XCTAssertTrue(overrideSucceeded)
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }

    let assembledAfter = assembler.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 世", assembledAfter)
    pom.memorizePerception(
      (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
      timestamp: Date().timeIntervalSince1970
    )

    let currentmemory = pom.getSavableData()
    let firstObservationKey = currentmemory.first?.key
    guard let firstObservationKey else {
      preconditionFailure("POM memorized nothing, or something wrong happen.")
    }
    XCTAssertEqual(firstObservationKey, obsCaptured.contextualizedGramKey)

    testHandler.clear()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    typeSentence(readingKeys4Sentence.joined())

    let assembledNow = assembler.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 是", assembledNow)
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true

    let cursorToTest = assembler.cursor
    let suggestion = pom.fetchSuggestion(
      assembledResult: assembler.assembledSentence,
      cursor: cursorToTest,
      timestamp: Date().timeIntervalSince1970
    )
    XCTAssertTrue(!suggestion.isEmpty)
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
    XCTAssertEqual("再 創 世", assembledByPOM)
    // 追加真實場景測試。此時 prefs.fetchSuggestionsFromPerceptionOverrideModel 是 true。
    testHandler.clear()
    typeSentence(readingKeys4Sentence.joined())
    XCTAssertEqual("再 創 世", assembler.assembledSentence.map(\.value).joined(separator: " "))
  }
}
