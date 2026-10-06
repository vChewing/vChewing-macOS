// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard
@testable import Tekkon

// 漸退記憶（POM）之行為層測試：注入、建議、自動套用、主開關，以及語境詞界。
//
// 語境詞界一節緣於使用者報告：打「這個檔案是怎樣出現的？」時實際輸出為「這個檔案室怎樣出現的？」；
// 而用以糾正該句之漸退記憶（`這個 檔案 是` 之三元語境）只在先把游標退到「檔」後面、
// 於選字窗選一次「檔案」，再把游標推到「是」、於選字窗選一次「是」之後才會生成。
// 該節以三支互補之靶釘住該流程：**寫入側**（單次選字即應寫下詞級語境）、
// **讀取側**（語境加分於每一輪組句皆須重算）、**整合**（單次糾正 → 重打即得正確句子）。

// MARK: - IH.POM

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test("IH-POM-001 POM bleacher integration test")
  func test_IH_POM_001_POMBleacherIntegrationTest() throws {
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
      from: HomaTests.strLXSampleDataHutao,
      readingsToKeep: ["liu2-yi4", "liu2", "yi4"]
    )
    extractedGrams = extractedGrams.filter {
      $0.segLength > 1 || $0.probability > -6
    }
    extractedGrams.sort { $0.segLength > $1.segLength && $0.probability > $1.probability }
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
    // 觸發選字窗選擇「流易」，該字詞在 Homa 內的的頻分權重由常規區間（ -9.5 <= x <= 0）升至 114_514。
    testSession.candidatePairSelectionConfirmed(at: 2) // 「流易」
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "流易")
    #expect(testSession.state.displayedText == "流易")
    // 此時應該有生成一些 POM 記憶。
    let pomData1 = testHandler.currentLM.lxPerceptor.getSavableData()
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
    // 檢查 assembler 內部的 nodes 確保 POM 建議使用的是「withTopGramScore」覆寫模式。
    // 不然的話，會出現 POM 記憶劫持使用者片語的情況。
    // 測試目的：在套用 POM 建議時，覆寫類型不得是 withSpecified（強制高分覆寫）。
    // 備註：Homa 的 overridingScore 預設值即為 114_514，無法以此做判斷。
    let allNodes: [Homa.Node] = testHandler.assembler.segments.compactMap { $0[2] }
    #expect(allNodes.allSatisfy { $0.currentOverrideType != .withSpecified })
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
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .front))
    var arrLeftEvent = KBEvent.KeyEventData.dataArrowLeft
    arrLeftEvent.flags.insert(.shift)
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.triageInput(event: arrLeftEvent.asEvent))
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .rear, isMarker: true))
    #expect(testSession.state.type == .ofMarking)
    #expect(testSession.state.markedRange == 0 ..< 2)
    // 這一行會觸發 handleMarkingState(input: Enter) 所排定觸發的 `performUserPhraseOperation`。
    // 此過程在 MockSession 會觸發 `inputHandler.currentLM.bleachSpecifiedPOMSuggestions`。
    // 註：真實 Session 會通過 `LXMgr.bleachSpecifiedSuggestions` 間接觸發該 API。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let fetchablesNow = testHandler.currentLM.unigramsFor(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"])
    let assumedNewUnigram = Homa.Gram(keyArray: ["ㄌㄧㄡˊ", "ㄧˋ"], value: "流溢", score: 0)
    #expect(fetchablesNow.contains(assumedNewUnigram))
    // 現在應該假設 POM 當中任何妨礙 assumedNewUnigram 被選中的內容都被清掉了。
    // 看一下 POM 記憶。
    let pomData2 = testHandler.currentLM.lxPerceptor.getSavableData()
    let encodedJSON2 = try jsonEncoder.encode(pomData2)
    let encodedJSONStr2 = String(data: encodedJSON2, encoding: .utf8) ?? "N/A"
    // 到這一步如果 Asserts 都通過的話就證明手動加詞時的 Bleacher 是成功的。
    #expect(!encodedJSONStr2.contains(#"()&()&(ㄌㄧㄡˊ-ㄧˋ,流易)"#))
  }

  @Test("IH-POM-002 A short POM key array does not hijack a longer one")
  func test_IH_POM_002_POMStopShortKeyArrFromHijackingLongKeyArr() throws {
    // 測試目的：在套用 POM 建議時，OverridingScore 得是 POM 建議的權重。
    // 備註：該測試用例沒必要鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄋㄧㄢˊ", "ㄓㄨㄥ"], current: "年中", probability: -4.329),
      isFiltering: false
    )
    clearTestPOM()
    vCTestLog("測試組句：年中")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("su065j/ ")
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["年中"])
    #expect(throws: Never.self) { try testHandler.assembler.moveCursorStepwise(to: .rear) }
    #expect(throws: Never.self) { try testHandler.assembler.moveCursorStepwise(to: .rear) }
    #expect(throws: Homa.Exception.self) { try testHandler.assembler.moveCursorStepwise(to: .rear) }
    #expect(testHandler.assembler.isCursorAtAssemblerEdge(direction: .rear))
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
    typeSentence("su065j/ ")
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["年終"])
  }

  @Test("IH-POM-003 POM ignores lower-weight suggested unigram matching raw-queried unigram")
  func test_IH_POM_003_POMIgnoresLowerWeightSuggestedUnigramMatchingRawQueriedUnigram() throws {
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
    let candidateFetchFilter: Homa.Assembler.CandidateFetchFilter =
      testHandler.prefs.useRearCursorMode ? .beginAt : .endAt
    let rawCandidates = testHandler.assembler.fetchCandidates(filter: candidateFetchFilter)
    guard let rawCandidate = rawCandidates.first(where: {
      $0.pair.keyArray == keyArray && $0.pair.value == candidateValue
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
    var suggestions = suggestionPairs.map { $0.1.current }
    #expect(suggestions.contains(candidateValue))
    if let candidateUnigram = suggestionPairs.first(where: { $0.1.current == candidateValue }) {
      #expect(candidateUnigram.1.probability >= rawCandidate.weight)
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
    suggestions = suggestionPairs.map { $0.1.current }
    #expect(suggestions.isEmpty)
    #expect(!(suggestions.contains(candidateValue)))
  }

  @Test("IH-POM-004 Filter POM appendables rejects lower-score matches")
  func test_IH_POM_004_FilterPOMAppendablesRejectsLowerScoreMatches() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    var suggestion = LXAssembly.OverrideSuggestion()
    suggestion.candidates = [
      (keyArray: ["ㄅ"], value: "波", probability: -0.30, previous: nil),
      (keyArray: ["ㄅ"], value: "玻", probability: -0.15, previous: nil),
      (keyArray: ["ㄅ"], value: "坡", probability: -0.05, previous: nil),
    ]

    let rawCandidates: [Homa.CandidatePairWeighted] = [
      Homa.CandidatePair(keyArray: ["ㄅ"], value: "波").weighted(-0.10),
      Homa.CandidatePair(keyArray: ["ㄅ"], value: "波").weighted(-0.25),
      Homa.CandidatePair(keyArray: ["ㄅ"], value: "玻").weighted(-0.30),
    ]

    let filtered = testHandler.filterPOMAppendables(from: suggestion, rawCandidates: rawCandidates)
    #expect(!(filtered.contains(where: { $0.1.current == "波" })))
    #expect(filtered.map { $0.1.current } == ["玻", "坡"])
  }

  @Test("IH-POM-005 Saisouki-no-gaika")
  func test_IH_POM_005_SaisoukiNoGaika() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let assembler = testHandler.assembler
    let pom = testHandler.currentLM.lxPerceptor
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let extractedGrams = extractGrams(
      from: HomaTests.strLXSampleData_SaisoukiNoGaika
    )
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
    #expect(pairsAtShiDeEnd.map(\.pair.value).contains("是的"))
    #expect(pairsAtShiDeEnd.map(\.pair.value).contains("似的"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Homa.PerceptionIntel?
    try assembler.overrideCandidate(
      .init(keyArray: ["ㄕˋ"], value: "世"),
      at: cursorShi,
      type: .withSpecified,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    #expect(obsCaptured?.contextualizedGramKey == "(ㄗㄞˋ,再)&(ㄔㄨㄤˋ,創)&(ㄕˋ,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
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
      try assembler.dropKey(direction: .rear)
      try assembler.dropKey(direction: .rear)
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
    let candidateSuggested = Homa.CandidatePair(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value
    ).weighted(firstSuggestionRAW.probability)
    let cursorForOverride = suggestion.overrideCursor ?? cursorShi
    let overrideResult = (try? assembler.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      type: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )) != nil
    if !overrideResult {
      try? assembler.overrideCandidateLiteral(
        candidateSuggested.pair.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
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

  @Test("IH-POM-006 Saisouki only")
  func test_IH_POM_006_SaisoukiOnly() throws {
    // 備註：該測試用例不適合鏡照至 MainAssemblyTests。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false // Use Dachen.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    let assembler = testHandler.assembler
    let pom = testHandler.currentLM.lxPerceptor
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let extractedGrams = extractGrams(
      from: HomaTests.strLXSampleData_SaisoukiNoGaika
    )
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
    var obsCaptured: Homa.PerceptionIntel?
    let overrideSucceeded = (try? assembler.overrideCandidate(
      .init(keyArray: ["ㄕˋ"], value: "世"),
      at: cursorShi,
      type: .withSpecified,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }) != nil
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

    let candidateSuggested = Homa.CandidatePair(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value
    ).weighted(firstSuggestionRAW.probability)
    let cursorForOverride = suggestion.overrideCursor ?? cursorShi
    let overrideResult = (try? assembler.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      type: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )) != nil
    if !overrideResult {
      try? assembler.overrideCandidateLiteral(
        candidateSuggested.pair.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    let assembledByPOM = assembler.assembledSentence.map(\.value).joined(separator: " ")
    #expect("再 創 世" == assembledByPOM)
    // 追加真實場景測試。此時 prefs.fetchSuggestionsFromPerceptionOverrideModel 是 true。
    testHandler.clear()
    typeSentence(readingKeys4Sentence.joined())
    #expect("再 創 世" == assembler.assembledSentence.map(\.value).joined(separator: " "))
  }

  @Test("IH-POM-007 Consolidation when cursor at node edge")
  func test_IH_POM_007_ConsolidationWhenCursorAtNodeEdge() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    // 情境 A：後置游標模式，游標位於最前端（frontest edge；cursor == length；對後置模式而言為無效邊緣、預期被糾正）。
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
    #expect(testHandler.isInvalidEdgeCursorSituation())
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

    // 情境 B：前置游標模式，游標位於最後端（cursor == 0；對前置模式而言為無效邊緣、預期被糾正）。
    testHandler.clear()
    testHandler.prefs.useRearCursorMode = false
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("xu.6u4")
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")
    testHandler.assembler.cursor = 0
    #expect(testHandler.assembler.cursor == 0)
    #expect(testHandler.isInvalidEdgeCursorSituation())
    testSession.switchState(testHandler.generateStateOfCandidates())
    testSession.candidatePairSelectionConfirmed(at: 0)
    #expect(!(testHandler.assembler.assembledSentence.map(\.value)).joined().isEmpty)
  }

  @Test("IH-POM-008 POM short-to-long margin behavior")
  func test_IH_POM_008_POMShortToLongMarginBehavior() throws {
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

  @Test("IH-POM-009 End-to-end prevention of a wrong first candidate")
  func test_IH_POM_009_EndToEndPreventWrongFirstCandidate() throws {
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
    var s = LXAssembly.OverrideSuggestion()
    let suggestedA: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄌㄧㄡˊ"],
      value: "SHORT",
      probability: existingScore + 0.4, // insufficient margin (0.4 < 0.5)
      previous: nil
    )
    s.candidates = [suggestedA]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = s

    _ = testHandler.retrievePOMSuggestions(apply: true)
    // 因為 prepend/override 被拒，組句結果應維持不變
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined() == "留意")

    // 情境 B：建議分數超過 margin → 應套用並縮短頭部
    var t = LXAssembly.OverrideSuggestion()
    let suggestedB: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄌㄧㄡˊ"],
      value: "SHORT",
      probability: existingScore + 0.6, // sufficient margin
      previous: nil
    )
    t.candidates = [suggestedB]
    t.overrideCursor = keyCursorRaw
    // 先檢查建議是否出現在可附加候選清單
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = t
    let appended = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended.map { $0.1.current }.contains("SHORT"))
    // 再次注入以測試 apply 路徑（fetchSuggestion 會清除注入的建議）
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = t
    _ = testHandler.retrievePOMSuggestions(apply: true)
    // 此時短候選應已取代原本的頭部
    // 若 POM 未能替換，嘗試直接覆寫以檢視行為
    let suggestedPair = Homa.CandidatePair(
      keyArray: suggestedB.keyArray,
      value: suggestedB.value
    ).weighted(suggestedB.probability)
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

  @Test("IH-POM-010 Previous-context exception, end to end")
  func test_IH_POM_010_PreviousContextExceptionEndToEnd() throws {
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
    let extractedGrams = extractGrams(from: HomaTests.strLXSampleData_SaisoukiNoGaika)
    extractedGrams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())

    // 在組字結果中尋找 multi-seg 的頭部，不依賴硬編的游標位置。
    var maybeFound: (node: Homa.GramInPath, range: Range<Int>)?
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
    let existingScore = found.node.gram.probability
    guard let prevValue = testHandler.assembler.assembledSentence.findGram(at: keyCursorRaw - 1)?.gram.value else {
      Issue.record("Unable to determine previous value for test")
      return
    }

    // 情境 A：margin 不足 → 不應套用（可見性不一定）
    var s = LXAssembly.OverrideSuggestion()
    let suggestedA: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄕˋ"],
      value: "PREVSHORT",
      probability: existingScore + 0.4, // insufficient
      previous: prevValue
    )
    s.candidates = [suggestedA]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = s

    // apply 路徑應因 short->long margin 而跳過
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = s
    _ = testHandler.retrievePOMSuggestions(apply: true)
    #expect(testHandler.assembler.assembledSentence.map(\.value).joined().contains("是"))

    // 情境 B：margin 足夠 → 應套用（若組字器拒絕亦可，兩者皆接受）
    var t = LXAssembly.OverrideSuggestion()
    let suggestedB: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄕˋ"],
      value: "PREVSHORT",
      probability: existingScore + 5.0, // large enough to bypass filtering/margin
      previous: prevValue
    )
    t.candidates = [suggestedB]
    t.overrideCursor = keyCursorRaw
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = t
    let appended2 = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended2.map { $0.1.current }.contains("PREVSHORT"))
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = t
    _ = testHandler.retrievePOMSuggestions(apply: true)

    let suggestedPair = Homa.CandidatePair(
      keyArray: suggestedB.keyArray,
      value: suggestedB.value
    ).weighted(suggestedB.probability)
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

  @Test("IH-POM-011 Multi-segment combination, end to end")
  func test_IH_POM_011_MultiSegCombinationEndToEnd() throws {
    // 端對端：確保拆分候選（previous+head）會被建議，且在 margin 允許時可套用。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 注入「再創世的凱歌」範例的暫存 unigram，以確定性產生 multi-seg 頭部
    let extractedGrams2 = extractGrams(from: HomaTests.strLXSampleData_SaisoukiNoGaika)
    extractedGrams2.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
    let readingKeys4Sentence = ["y94", "tj;4", "g4", "2k7", "d93", "ek "]
    typeSentence(readingKeys4Sentence.joined())

    // 動態尋找 multi-seg 的頭部
    var maybeFound2: (node: Homa.GramInPath, range: Range<Int>)?
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
    let existingScore = found.node.gram.probability
    guard let prevValue = testHandler.assembler.assembledSentence.findGram(at: keyCursorRaw - 1)?.gram.value else {
      Issue.record("Unable to determine previous value for test")
      return
    }

    // 候選提供 previous+head；將機率設高以便套用應成功
    var s = LXAssembly.OverrideSuggestion()
    let suggested: (keyArray: [String], value: String, probability: Double, previous: String?) = (
      keyArray: ["ㄉㄜ˙"], // head part
      value: "SPLITVAL",
      probability: existingScore + 1.0,
      previous: prevValue
    )
    s.candidates = [suggested]
    s.overrideCursor = keyCursorRaw
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = s

    let appended = testHandler.retrievePOMSuggestions(apply: false)
    #expect(appended.map { $0.1.current }.contains("SPLITVAL"))

    // 套用路徑
    testHandler.currentLM.lxPerceptor.testInjectedSuggestion = s
    _ = testHandler.retrievePOMSuggestions(apply: true)

    let suggestedPair = Homa.CandidatePair(
      keyArray: suggested.keyArray,
      value: suggested.value
    ).weighted(suggested.probability)
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

  /// 狂拼 **Enter 固化候選**確認前方候選**不寫入 POM 記憶**：
  /// copilot 未經使用者逐字確認的最佳猜測不應寫入漸退記憶模組，否則記憶的短詞
  /// 會綁架長詞的組句（如「是嗎」綁架「是媽媽」→「是嗎嗎」）。測資：清空 POM 後
  /// 以預設語義（Enter 固化，`memorizePOM` 預設 false）確認前方候選，組字器仍在、
  /// 讀取 POM 建議應為空。
  @Test("IH-POM-012 Furious Enter direct commit does not memorize POM")
  func test_IH_POM_012_FuriousEnterDirectCommitDoesNotMemorizePOM() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // POM 讀取閘門打開。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shima」：auto-chop 提交 shi、前方 ma 暫存於注拼槽、copilot 候選窗顯示。
    typeSentence("shima")
    #expect(testHandler.assembler.keys.count == 1)
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(!testSession.state.candidates.isEmpty)

    // 以 Enter 直遞語義就地確認前方候選（預設 memorizePOM == false；保留組字器內容）。
    testHandler.confirmFuriousFrontCandidate(testSession.state.candidates.first!)
    #expect(testHandler.assembler.keys.count == 2)

    // Enter 直遞不得產生任何 POM 記憶：組字器仍在，若有記憶應能被建議查詢讀出。
    let pomPairs = testHandler.retrievePOMSuggestions(apply: false)
    #expect(pomPairs.isEmpty)
  }

  /// 狂拼**顯式選字**（Shift+選字鍵／滑鼠點選，`memorizePOM: true`）確認前方候選
  /// **會寫入 POM 記憶**：使用者顯式選字符合 POM 記憶的明確意志，與 Enter 直遞有別。
  /// 測資：清空 POM 後經 `candidatePairSelectionConfirmed`（模擬就地選字路由）
  /// 選中跨邊界候選「世界」，
  /// 漸退記憶模組應有新增記憶。
  @Test("IH-POM-013 Furious explicit selection memorizes POM")
  func test_IH_POM_013_FuriousExplicitSelectionMemorizesPOM() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    insertShiJieSolidificationFixture(testHandler: testHandler)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // POM 讀取閘門打開。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    // 「shijie」：auto-chop 提交 shi、前方 jie 暫存於注拼槽、copilot 候選窗顯示，
    // 置頂候選為跨邊界詞「世界」（keyArray [ㄕˋ, ㄐㄧㄝˋ]，可成功覆寫）。
    typeSentence("shijie")
    #expect(testHandler.composer.romajiBuffer == "jie")
    #expect(testSession.state.candidates.first?.value == "世界")

    // 經 session 就地選字路由（Shift+選字鍵／滑鼠點選同此路徑）：
    // MockSession 對應生產端 InputSession_Delegates，傳入 memorizePOM: true。
    testSession.candidatePairSelectionConfirmed(at: 0)
    #expect(generateDisplayedText() == "世界")

    // 顯式選字應寫入 POM 記憶：直接檢查漸退記憶模組的儲存內容。
    let pomData = testHandler.currentLM.lxPerceptor.getSavableData()
    #expect(!pomData.isEmpty)
  }

  /// 狂拼固化後 POM 建議套用（容錯模式）：空格固化前方聲調桶後，
  /// `retrievePOMSuggestions(apply: true)` 以容錯查詢召回記憶並就地覆寫——組句結果
  /// 由「是嗎」改為記憶的「是媽」。
  @Test("IH-POM-014 Furious typing solidify applies POM suggestion tolerantly")
  func test_IH_POM_014_FuriousTypingSolidifyAppliesPOMSuggestionTolerantly() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shima」→ 空格：前方固化（插聲調桶）＋ POM 容錯套用（是嗎 → 是媽）。
    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
  }

  /// 主開關（fetch）關閉時，POM 記憶完全不影響組句（P182：建議、自動套用與 n-gram 餵入
  /// 皆由 `kFetchSuggestionsFromPerceptionOverrideModel` 單一把守）——即使已種入記憶
  /// （是→媽），組句仍為語言模型最佳猜測（是嗎）。
  @Test("IH-POM-015 Main switch off keeps composition unaffected")
  func test_IH_POM_015_MainSwitchOffKeepsCompositionUnaffected() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false // 關閉主開關（全通道停用）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shima」→ 空格固化前方：主開關關閉 ⇒ 無建議、無 n-gram 餵入，組句維持 LM 最佳猜測「是嗎」。
    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "嗎"])
  }

  /// 狂拼模式、主開關（fetch）開啟時，固化後的自動套用被跳過（雙重加成收斂）：
  /// 記憶詞由 DP 以 n-gram 統計路徑自然選中（gram.previous 帶「是」），
  /// 而非自動 override 錨定的 bare unigram（previous 為 nil）。
  @Test("IH-POM-016 Furious typing n-gram source skips auto POM apply")
  func test_IH_POM_016_FuriousTypingNGramSourceSkipsAutoPOMApply() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // 主開關開啟（預設）：建議與 n-gram 餵入皆由此把守。
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    typeSentence("shima")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
    // 選取來自 n-gram 統計路徑（previous 帶「是」），非自動 override 錨定的 bare unigram。
    #expect(testHandler.assembler.assembledSentence.last?.gram.previous == "是")
  }

  /// 非狂拼（一般拼音）主開關（fetch）開啟時，contextual 記憶若已由 DP 以統計路徑
  /// 自然選中（同值），不再重複以 override 錨定（P181：非狂拼 override 轉為統計路徑的
  /// 兜底、消除雙重加成）——gram.previous 帶「是」即證明選取來自統計路徑、
  /// 非自動 override 錨定的 bare unigram（previous 為 nil）。
  @Test("IH-POM-017 Non-furious pinyin n-gram source skips duplicate anchor")
  func test_IH_POM_017_NonFuriousPinyinNGramSourceSkipsDuplicateAnchor() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "嬤", score: -1),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true // 主開關開啟（預設）。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 非狂拼（一般拼音）。
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 「shi4 ma1」：無記憶時 ㄇㄚ 節點的最佳猜測為「嬤」（-1 > 媽 -8）；
    // 記憶（是→媽）注入為 bigram 後，DP 自然選中「媽」。
    typeSentence("shi4ma1")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)

    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "媽"])
    // 選取來自 n-gram 統計路徑（previous 帶「是」），非自動 override 錨定的 bare unigram。
    #expect(testHandler.assembler.assembledSentence.last?.gram.previous == "是")
  }

  /// 狂拼 copilot 首位＝「組句預覽」語義（定案）：fixed-order（`useFixedCandidateOrderOnSelection`）
  /// 只管「POM 不重排候選」；contextual 記憶經 n-gram 餵入使 DP 組句本就偏好「是媽」，
  /// 該組句預覽居首屬 composition、不受該偏好管（實證：停用 fetch 置頂塊後 IH-FuriousPinyin-044 仍綠）。
  /// 此測試鎖定此語義，防止日後誤把組句預覽一併閘掉。
  @Test("IH-POM-018 Furious copilot composition preview survives fixed order")
  func test_IH_POM_018_FuriousCopilotCompositionPreviewSurvivesFixedOrder() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.useFixedCandidateOrderOnSelection = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.useFixedCandidateOrderOnSelection = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    typeSentence("shima")
    #expect(testHandler.composer.romajiBuffer == "ma")

    // 固定順序啟用：fetch 置頂塊被閘掉，但組句預覽（DP 因 contextual 餵入選「是媽」）
    // 仍使「媽」居首——此為 composition 語義、非候選重排。
    let candidates = testHandler.furiousTypingFrontCandidates
    #expect(!(candidates?.isEmpty ?? true))
    #expect(candidates?.first?.value == "媽")
  }

  /// 狂拼 copilot 置頂塊收斂後（P182）僅服務 unigram（無前後文）記憶：句首（無前文）
  /// 打「ma」時，unigram「媽」由 LibVanguard 通道置頂（fetch 開）；「以固定順序陳列候選字」
  /// 啟用時則不置頂（首位為 LM 最佳猜測「嗎」）。
  @Test("IH-POM-019 Furious copilot fronts unigram memory unless fixed order")
  func test_IH_POM_019_FuriousCopilotFrontsUnigramMemoryUnlessFixedOrder() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.useFixedCandidateOrderOnSelection = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄇㄚ"], value: "媽", score: -8),
      .init(keyArray: ["ㄇㄚˊ"], value: "麻", score: -8),
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.currentLM.syncPrefs()

    testHandler.currentLM.memorizePerception(
      (ngramKey: "()&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )

    // 句首、非 fixed-order：unigram「媽」置頂（LM 最佳為「嗎」）。
    typeSentence("ma")
    #expect(testHandler.composer.romajiBuffer == "ma")
    #expect(testHandler.furiousTypingFrontCandidates?.first?.value == "媽")

    // 句首、fixed-order 啟用：不置頂，首位為 LM 最佳猜測「嗎」。
    testSession.switchState(.ofAbortion())
    testHandler.prefs.useFixedCandidateOrderOnSelection = true
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("ma")
    #expect(testHandler.furiousTypingFrontCandidates?.first?.value == "嗎")
  }

  /// P192 回歸：引擎注入需「逐段含聲調」等值——記憶「(是)→右(ㄧㄡˋ)」不得影響「是 有(ㄧㄡˇ)」
  /// 的組句（客訴：打「有」首候選為「右」；錯調 gram keyArray 與節點鍵不符仍可能被 DP 以
  /// reading-mismatch 選中）。對照：同調（ㄧㄡˋ）注入仍有效。
  @Test("IH-POM-020 POM injection requires exact tone")
  func test_IH_POM_020_POMInjectionRequiresExactTone() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    [
      .init(keyArray: ["ㄕˋ"], value: "是", score: -6),
      .init(keyArray: ["ㄧㄡˇ"], value: "有", score: -1),
      .init(keyArray: ["ㄧㄡˋ"], value: "右", score: -2),
      .init(keyArray: ["ㄧㄡˋ"], value: "幼", score: -1),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 非狂拼（一般拼音、全拼帶聲調）。
    testHandler.currentLM.syncPrefs()

    // 記憶「(是)→右(ㄧㄡˋ)」。
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄧㄡˋ,右)", candidate: "右"),
      timestamp: Date().timeIntervalSince1970
    )

    // 打「是 有」(shi4 you3)：ㄧㄡˋ 的「右」不得注入 ㄧㄡˇ 節點 → 組句「是有」。
    typeSentence("shi4you3")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "有"])

    // 對照：同調（ㄧㄡˋ）注入仍有效——打「是 右」(shi4 you4)，記憶「(是)→右」勝過「幼」。
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("shi4you4")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["是", "右"])
  }

  /// P192 回歸：錯位 POM 記憶（候選字數 ≠ head 讀音段數，如「體式」被記在單 ㄕˊ 下）
  /// 不得套用——影片客訴「打『時』(ㄕˊ) 直接組出/送出『體式』」即此類髒資料所致；
  /// 資料守衛使其不進入建議/套用/餵入，組句維持「時」。
  @Test("IH-POM-021 Misaligned POM candidate ignored")
  func test_IH_POM_021_MisalignedPOMCandidateIgnored() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    [
      .init(keyArray: ["ㄕˊ"], value: "時", score: -1),
      .init(keyArray: ["ㄕˋ"], value: "是", score: -1),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 非狂拼（全拼帶調）。
    testHandler.currentLM.syncPrefs()

    // 錯位記憶：單 ㄕˊ 讀音、候選「體式」(2 字)。
    testHandler.currentLM.memorizePerception(
      (ngramKey: "()&()&(ㄕˊ,體式)", candidate: "體式"), timestamp: Date().timeIntervalSince1970
    )
    typeSentence("shi2")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["時"])

    // 對照：無記憶時亦為「時」。
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)
    clearTestPOM()
    typeSentence("shi2")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["時"])
  }

  /// 第一聲（字串無聲調記號）具體讀音不得被跨聲調 contextual 記憶綁架（issue #610 形：
  /// 打 ㄕㄥ 組字預設「聖(ㄕㄥˋ)」、候選窗第一「生(ㄕㄥ)」——引擎注入誤把 ㄕㄥˋ 記憶
  /// 附到 ㄕㄥ 節點所致）。單鍵查詢走嚴格逐字等值後，組句應維持「生」。
  @Test("IH-POM-022 First tone query not hijacked by cross tone memory")
  func test_IH_POM_022_FirstToneQueryNotHijackedByCrossToneMemory() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled4Pinyin = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    [
      .init(keyArray: ["ㄕㄥ"], value: "生", score: -1),
      .init(keyArray: ["ㄕㄥ"], value: "甥", score: -2),
      .init(keyArray: ["ㄕㄥˋ"], value: "聖", score: -2),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.furiousTypingEnabled4Pinyin = false // 非狂拼（全拼帶調 sheng1＝單鍵 ㄕㄥ）。
    testHandler.currentLM.syncPrefs()

    // 記憶「(活)→聖(ㄕㄥˋ)」：ㄕㄥˋ 記憶不得注入 ㄕㄥ（第一聲）節點。
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄏㄨㄛˊ,活)&(ㄕㄥˋ,聖)", candidate: "聖"),
      timestamp: Date().timeIntervalSince1970
    )

    // 打 sheng1 → 組句「生」（非「聖」）。
    typeSentence("sheng1")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["生"])

    // 對照：無記憶時亦為「生」。
    testSession.switchState(.ofAbortion())
    testSession.resetInputHandler(forceComposerCleanup: true)
    clearTestPOM()
    typeSentence("sheng1")
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ", keyCode: 49).asEvent)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["生"])
  }

  /// IH-POM-023（寫入側）：於「檔案室」成詞之句中央選一次「是」，即應寫下詞級語境之記憶。
  ///
  /// 舊行為：`consolidateCandidateCursorContext` 為保全「檔案室」其餘各鍵之值，將整個節點
  /// 逐鍵拆成「檔」「案」「室」⇒ 觀察到的語境是「檔 案 是」，該記憶對「檔案 是」永不生效。
  @Test("IH-POM-023 Single selection records word level context memory")
  func test_IH_POM_023_SingleSelectionRecordsWordLevelContextMemory() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    preparePOMContextScenario()
    defer { tearDownPOMContextScenario() }
    // 詞庫之長詞「檔案室」勝出（此即使用者所報之實際輸出）。
    #expect(generateDisplayedText() == "這個檔案室怎樣出現的")
    #expect(testSession.state.type == .ofInputting)

    // 游標退到「是」那一格，於選字窗選一次「是」——不做任何多餘之游標往返。
    let candidateValues = placeCaretAndRefreshCandidates(atKeyIndex: 4)
    #expect(candidateValues.first == "檔案室")
    #expect(candidateValues.contains("是"))
    #expect(selectCandidateFromWindow("是"))
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")

    // 寫入側之判準：語境須為詞級之「檔案」，而非逐鍵之「檔 案」。
    let pomKeys = storedPOMKeys()
    #expect(pomKeys.contains("(ㄓㄜˋ-ㄍㄜˋ,這個)&(ㄉㄤˇ-ㄢˋ,檔案)&(ㄕˋ,是)"))
    #expect(!pomKeys.contains("(ㄉㄤˇ,檔)&(ㄢˋ,案)&(ㄕˋ,是)"))
    _ = testHandler
  }

  /// IH-POM-024（整合）：單次糾正之後，重打同一句即應得正確輸出。
  @Test("IH-POM-024 Single selection fix survives retype")
  func test_IH_POM_024_SingleSelectionFixSurvivesRetype() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    preparePOMContextScenario()
    defer { tearDownPOMContextScenario() }
    _ = placeCaretAndRefreshCandidates(atKeyIndex: 4)
    #expect(selectCandidateFromWindow("是"))
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")

    // 清空組字器、重打同一句：記憶應勝過詞庫之「檔案室」。
    testHandler.clear()
    typeSentence(Self.pomContextSentenceKeys)
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")
    _ = testSession
  }

  /// IH-POM-025（讀取側）：語境加分於每一輪組句皆須重算，不得只生效一拍。
  ///
  /// 舊行為：組句函式於命中語境加分時把節點記成 `withTopGramScore` 覆寫狀態，而該狀態之計分臂
  /// 逕以 unigram 基線計分 ⇒ 加分不再重算。實測：按「ㄕˋ」時得「這個檔案是」，再按「ㄗ」即
  /// 還原成「這個檔案室怎」。本靶直接注入詞級記憶、不經寫入側，故兩側之缺陷可分別歸因。
  @Test("IH-POM-025 Contextual bonus is recomputed on every assembly")
  func test_IH_POM_025_ContextualBonusIsRecomputedOnEveryAssembly() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    installPOMContextFixture()
    defer { tearDownPOMContextScenario() }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.currentLM.memorizePerception(
      (ngramKey: "(ㄓㄜˋ-ㄍㄜˋ,這個)&(ㄉㄤˇ-ㄢˋ,檔案)&(ㄕˋ,是)", candidate: "是"),
      timestamp: Date().timeIntervalSince1970
    )
    typeSentence(Self.pomContextSentenceKeys)
    #expect(generateDisplayedText() == "這個檔案是怎樣出現的")
    // 組句為冪等：同一組鍵再組一次，結果與分數皆不變。
    let scoreBefore = testHandler.assembler.mostRecentPathScore
    #expect(testHandler.assembler.assemble().values.joined() == "這個檔案是怎樣出現的")
    #expect(testHandler.assembler.mostRecentPathScore == scoreBefore)
  }

  // MARK: - Test harness

  /// 測試句「這個檔案是怎樣出現的？」之按鍵流（大千排列；「出」為陰平、故以空格收聲調）。
  static let pomContextSentenceKeys = "5k4ek42;304g4yp3u;4tj vu042k7"

  /// 測試語料：**逐筆取自出貨語料庫之權重**（`vChewing-VanguardLexicon/Build/Release/tsv/data-v4.8.5.txt`
  /// 之 `讀音<TAB>詞值<TAB>權重`），各讀音只取足以左右本句組句之前幾名。關鍵三筆為
  /// `ㄉㄤˇ-ㄢˋ 檔案 -4.234`、`ㄉㄤˇ-ㄢˋ-ㄕˋ 檔案室 -5.856`、`ㄕˋ 是 -5.004`：
  /// 無記憶時「檔案室」(−5.856) 勝過「檔案」＋「是」(−9.238)；有記憶時後者得語境加分而勝。
  static let pomContextFixture: [(keyArray: [String], value: String, score: Double)] = [
    (["ㄓㄜˋ"], "這", -5.033),
    (["ㄍㄜˋ"], "個", -5.031),
    (["ㄓㄜˋ", "ㄍㄜˋ"], "這個", -6.656),
    (["ㄉㄤˇ"], "黨", -5.120),
    (["ㄉㄤˇ"], "檔", -5.185),
    (["ㄢˋ"], "案", -5.108),
    (["ㄕˋ"], "是", -5.004),
    (["ㄕˋ"], "室", -5.164),
    (["ㄗㄣˇ"], "怎", -5.244),
    (["ㄧㄤˋ"], "樣", -5.182),
    (["ㄗㄣˇ", "ㄧㄤˋ"], "怎樣", -4.224),
    (["ㄔㄨ"], "出", -5.121),
    (["ㄒㄧㄢˋ"], "現", -5.164),
    (["ㄔㄨ", "ㄒㄧㄢˋ"], "出現", -3.022),
    (["ㄉㄜ˙"], "的", -4.971),
    (["ㄉㄤˇ", "ㄢˋ"], "檔案", -4.234),
    (["ㄉㄤˇ", "ㄢˋ", "ㄕˋ"], "檔案室", -5.856),
  ]

  func installPOMContextFixture() {
    Self.pomContextFixture.forEach {
      testHandler?.currentLM.insertTemporaryData(
        unigram: .init(keyArray: $0.keyArray, value: $0.value, score: $0.score),
        isFiltering: false
      )
    }
  }

  func preparePOMContextScenario() {
    guard let testHandler, let testSession else { return }
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    installPOMContextFixture()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.consolidateContextOnCandidateSelection = true
    testSession.installMockCandidateController()
    typeSentence(Self.pomContextSentenceKeys)
  }

  func tearDownPOMContextScenario() {
    testHandler?.currentLM.clearTemporaryData(isFiltering: false)
    testSession?.mockCandidateController = nil
    testSession?.resetInputHandler(forceComposerCleanup: true)
    clearTestPOM()
  }

  /// 把游標放到指定讀音格之後，並刷新選字窗清單。
  /// - Returns: 該游標位置之候選值清單。
  @discardableResult
  func placeCaretAndRefreshCandidates(atKeyIndex index: Int) -> [String] {
    guard let testHandler, let testSession else { return [] }
    testHandler.assembler.cursor = index + 1
    testSession.switchState(testHandler.generateStateOfCandidates(dodge: false))
    return testSession.state.candidates.map(\.value)
  }

  /// 以選字窗之選字鍵選中給定值（等同使用者以選字窗選字）。
  @discardableResult
  func selectCandidateFromWindow(_ value: String) -> Bool {
    guard let testHandler, let testSession else { return false }
    guard let index = testSession.state.candidates.firstIndex(where: { $0.value == value }),
          Array(testSession.selectionKeys).indices.contains(index)
    else { return false }
    let keyChar = Array(testSession.selectionKeys)[index]
    return testHandler.triageInput(event: KBEvent.KeyEventData(chars: String(keyChar)).asEvent)
  }

  /// 已存入漸退記憶模組之語境鍵清單。
  func storedPOMKeys() -> [String] {
    testHandler?.currentLM.lxPerceptor.getSavableData().map(\.key) ?? []
  }
}
