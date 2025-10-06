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
import XCTest

@testable import LangModelAssembly

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - LMPerceptionTests

final class LMPerceptionTests: XCTestCase {
  func testPOM_1_BasicPerceptionOps() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    let expectedSuggestion = "狗"
    pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion)
    XCTAssertEqual(suggested?.first?.previous ?? "", "的")

    // 測試 2 天和 8 天的記憶衰退
    // 2 天內應該保留，8 天應該消失
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 2)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion)

    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 8)
    )
    XCTAssertNil(suggested, "8天後記憶應該已經衰減到閾值以下")
    // -----------

    // 測試基本功能 - 使用簡單的 key 格式
    let key2 = "(test,測試)&(key,鍵)&(target,目標)"
    let candidate = "目標"
    let timestamp = Date.now.timeIntervalSince1970

    // 記憶一個候選詞
    pom.memorizePerception((ngramKey: key2, candidate: candidate), timestamp: timestamp)
    print("記憶候選詞: \(key2) -> \(candidate)")

    // 檢索建議
    let suggestions = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
    if let suggestions = suggestions {
      print("找到 \(suggestions.count) 個建議")
      for suggestion in suggestions {
        print("建議: \(suggestion.value), 權重: \(suggestion.probability)")
      }
      XCTAssertFalse(suggestions.isEmpty, "建議不應該為空")
      XCTAssertEqual(suggestions.first?.value, candidate, "應該返回正確的候選詞")
      XCTAssertTrue(suggestions.first?.probability ?? 0 < 0, "權重應該是負數")
    } else {
      print("沒有找到建議")
      XCTFail("應該能獲取建議")
    }

    // 測試清理功能
    pom.clearData()
    let emptySuggestions = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
    XCTAssertNil(emptySuggestions, "清理後應該沒有建議")

    print("基本 API 測試完成")
  }

  func testPOM_2_NewestAgainstRepeatedlyUsed() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let key = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    let valRepeatedlyUsed = "狗" // 更常用
    let valNewest = "苟" // 最近偶爾用了一次

    // 使用天數作為單位
    let stamps: [Double] = [0, 0.1, 0.2].map { nowTimeStamp + dayInSeconds * $0 }
    stamps.forEach { stamp in
      pom.memorizePerception((key, valRepeatedlyUsed), timestamp: stamp)
    }

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", valRepeatedlyUsed)

    // 在 1 天後選擇了另一個候選字
    pom.memorizePerception((key, valNewest), timestamp: nowTimeStamp + dayInSeconds * 1)

    // 在 1.1 天檢查最新使用的候選字是否被建議
    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + dayInSeconds * 1.1
    )
    XCTAssertEqual(suggested?.first?.value ?? "", valNewest)

    // 在 10 天時，記憶應該已經衰減到閾值以下
    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + dayInSeconds * 10
    )
    XCTAssertNil(suggested, "經過10天後記憶仍未完全衰減")
  }

  func testPOM_3_LRUTable() throws {
    let a = (key: "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)", value: "狗", head: "ㄍㄡˇ")
    let b = (key: "(ㄆㄞˋ-ㄇㄥˊ,派蒙)&(ㄉㄜ˙,的)&(ㄐㄧㄤˇ-ㄐㄧㄣ,獎金)", value: "伙食費", head: "ㄏㄨㄛˇ-ㄕˊ-ㄈㄟˋ")
    let c = (key: "(ㄍㄨㄛˊ-ㄅㄥ,國崩)&(ㄉㄜ˙,的)&(ㄇㄠˋ-ㄗ˙,帽子)", value: "帽子", head: "ㄇㄠˋ-ㄗ˙")
    let d = (key: "(ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍)&(ㄉㄜ˙,的)&(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)", value: "腳臭", head: "ㄐㄧㄠˇ-ㄔㄡˋ")

    // 容量為2的LRU測試
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: 2,
      dataURL: nullURL
    )

    // 緊接著記錄三個項目，只保留最後兩個
    pom.memorizePerception((a.key, a.value), timestamp: nowTimeStamp)
    pom.memorizePerception((b.key, b.value), timestamp: nowTimeStamp + 1)
    pom.memorizePerception((c.key, c.value), timestamp: nowTimeStamp + 2)

    // C是最新的，應該在清單中
    var suggested = pom.getSuggestion(
      key: c.key,
      timestamp: nowTimeStamp + 3
    )
    XCTAssertEqual(suggested?.first?.value ?? "", c.value)

    // B是第二新的，應該在清單中
    suggested = pom.getSuggestion(
      key: b.key,
      timestamp: nowTimeStamp + 4
    )
    XCTAssertEqual(suggested?.first?.value ?? "", b.value)

    // A最舊，應該被移除
    suggested = pom.getSuggestion(
      key: a.key,
      timestamp: nowTimeStamp + 5
    )
    XCTAssertNil(suggested)

    // 添加D, B應該被移除
    pom.memorizePerception((d.key, d.value), timestamp: nowTimeStamp + 6)

    suggested = pom.getSuggestion(
      key: d.key,
      timestamp: nowTimeStamp + 7
    )
    XCTAssertEqual(suggested?.first?.value ?? "", d.value)

    suggested = pom.getSuggestion(
      key: c.key,
      timestamp: nowTimeStamp + 8
    )
    XCTAssertEqual(suggested?.first?.value ?? "", c.value)

    suggested = pom.getSuggestion(
      key: b.key,
      timestamp: nowTimeStamp + 9
    )
    XCTAssertNil(suggested)
  }

  // 添加一個專門測試長期記憶衰減的測試
  func testPOM_4_LongTermMemoryDecay() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let unigramKey = "(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)"
    let unigramCandidate = "腳臭"

    pom.memorizePerception((unigramKey, unigramCandidate), timestamp: nowTimeStamp)

    let shortWindowTimestamp = nowTimeStamp + (dayInSeconds * 5.0)
    let shortWindowSuggestions = pom.getSuggestion(key: unigramKey, timestamp: shortWindowTimestamp)
    XCTAssertNotNil(shortWindowSuggestions, "約 5 天內的單字記憶應該仍可取得")
    XCTAssertEqual(shortWindowSuggestions?.first?.value, unigramCandidate)
    if let score = shortWindowSuggestions?.first?.probability {
      XCTAssertGreaterThan(
        score,
        LMAssembly.LMPerceptionOverride.kDecayThreshold,
        "記憶尚存時的分數應高於閾值"
      )
    }

    let pastShortWindowTimestamp = nowTimeStamp + (dayInSeconds * 6.0)
    XCTAssertNil(
      pom.getSuggestion(key: unigramKey, timestamp: pastShortWindowTimestamp),
      "單字記憶在約 5.4 天的可用期後應該被衰減"
    )

    // 給腳臭來點上下文。
    let contextualKey = "(ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍)&(ㄉㄜ˙,的)&(ㄐㄧㄠˇ-ㄔㄡˋ,腳臭)"
    let contextualCandidate = "腳臭"

    pom.memorizePerception((contextualKey, contextualCandidate), timestamp: nowTimeStamp)

    let longWindowTimestamp = nowTimeStamp + (dayInSeconds * 7.5)
    let longWindowSuggestions = pom.getSuggestion(key: contextualKey, timestamp: longWindowTimestamp)
    XCTAssertNotNil(longWindowSuggestions, "含上下文的記憶在 8 天視窗內應該仍可取得")
    XCTAssertEqual(longWindowSuggestions?.first?.value, contextualCandidate)

    let pastLongWindowTimestamp = nowTimeStamp + (dayInSeconds * 8.0)
    XCTAssertNil(
      pom.getSuggestion(key: contextualKey, timestamp: pastLongWindowTimestamp),
      "含上下文的記憶在 8 天視窗後應該被衰減"
    )
  }

  func testPOM_5_PerceptionKeyGeneration() throws {
    let nonInterruptionSuffix: [Megrez.GramInPath] = [
      ("neng2", "能", -5.36),
      ("liu2", "留", -5.245),
      ("yi4-lv3", "一縷", -8.496),
    ].map(Megrez.GramInPath.fromTuplet)

    guard let nonInterruptionResult = nonInterruptionSuffix.generateKeyForPerception() else {
      XCTFail("Perception key should be generated for valid suffix (non interruption scenario).")
      return
    }

    XCTAssertEqual(nonInterruptionResult.ngramKey, "(neng2,能)&(liu2,留)&(yi4-lv3,一縷)")
    XCTAssertEqual(nonInterruptionResult.candidate, "一縷")
    XCTAssertEqual(nonInterruptionResult.headReading, "lv3")

    let interruptionSuffix: [Megrez.GramInPath] = [
      ("you1-die2", "幽蝶", -8.496),
      ("neng2", "能", -5.36),
      ("liu2", "留", -5.245),
    ].map(Megrez.GramInPath.fromTuplet)

    guard let interruptionResult = interruptionSuffix.generateKeyForPerception() else {
      XCTFail("Perception key should be generated for valid suffix (interruption scenario).")
      return
    }

    XCTAssertEqual(interruptionResult.ngramKey, "(you1-die2,幽蝶)&(neng2,能)&(liu2,留)")
    XCTAssertEqual(interruptionResult.candidate, "留")
    XCTAssertEqual(interruptionResult.headReading, "liu2")
  }

  func testPOM_6_ActualCaseScenario_SaisoukiNoGaika() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    let pom = LMAssembly.LMPerceptionOverride(
      dataURL: URL(fileURLWithPath: "/dev/null")
    )
    let compositor = Megrez.Compositor(with: lm)
    // 測試用句「再創世的凱歌」。
    let readingKeys = ["zai4", "chuang4", "shi4", "de5", "kai3", "ge1"]
    readingKeys.forEach { compositor.insertKey($0) }
    compositor.assemble()
    let assembledBefore = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("再 創 是的 凱歌" == assembledBefore)
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorShi = 2
    let cursorShiDe = 3
    let keyForQueryingDataAt2 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorShi)
    XCTAssertEqual(keyForQueryingDataAt2?.ngramKey, "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    XCTAssertEqual(keyForQueryingDataAt2?.headReading, "shi4")
    let keyForQueryingDataAt3 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorShiDe)
    XCTAssertEqual(keyForQueryingDataAt3?.ngramKey, "(zai4,再)&(chuang4,創)&(shi4-de5,是的)")
    XCTAssertEqual(keyForQueryingDataAt3?.headReading, "de5")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtShiDeEnd = compositor.fetchCandidates(at: 4, filter: .endAt)
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("是的"))
    XCTAssertTrue(pairsAtShiDeEnd.map(\.value).contains("似的"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    _ = compositor.overrideCandidate(
      .init(keyArray: ["shi4"], value: "世"),
      at: cursorShi,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertEqual(obsCaptured?.ngramKey, "(zai4,再)&(chuang4,創)&(shi4,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("再 創 世 的 凱歌" == assembledAfter)
    pom.memorizePerception(
      (obsCaptured.ngramKey, obsCaptured.candidate),
      timestamp: Date().timeIntervalSince1970
    )
    // 記憶完畢。先看看是否有記憶。
    let currentmemory = pom.getSavableData()
    let firstObservationKey = currentmemory.first?.key
    guard let firstObservationKey else {
      preconditionFailure("POM memorized nothing, or something wrong happen.")
    }
    XCTAssertEqual(firstObservationKey, obsCaptured.ngramKey)
    // 然後是記憶效力測試：
    let validationLM = SimpleLM(input: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    let validationCompositor = Megrez.Compositor(with: validationLM)
    readingKeys.prefix(4).forEach { validationCompositor.insertKey($0) }
    validationCompositor.assemble()
    let cursorToTest = validationCompositor.cursor
    let assembledNow = validationCompositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertTrue(
      ["再 創 是的", "再 創 世 的"].contains(assembledNow),
      "Unexpected baseline assembly: \(assembledNow)"
    )
    let suggestion = pom.fetchSuggestion(
      assembledResult: validationCompositor.assembledSentence,
      cursor: cursorToTest,
      timestamp: Date().timeIntervalSince1970
    )
    XCTAssertTrue(!suggestion.isEmpty)
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      preconditionFailure("POM suggested nothing, or something wrong happen.")
    }
    print(firstSuggestionRAW)
    let candidateSuggested = Megrez.KeyValuePaired(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value,
      score: firstSuggestionRAW.probability
    )
    let cursorForOverride = suggestion.overrideCursor ?? cursorShi
    let overrideResult = validationCompositor.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )
    if !overrideResult {
      validationCompositor.overrideCandidateLiteral(
        candidateSuggested.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    validationCompositor.assemble()
    let assembledByPOM = validationCompositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertEqual("再 創 世 的", assembledByPOM)
  }

  func testPOM_7_ActualCaseScenario_SaisoukiOnly() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_SaisoukiNoGaika)
    let pom = LMAssembly.LMPerceptionOverride(
      dataURL: URL(fileURLWithPath: "/dev/null")
    )
    let compositor = Megrez.Compositor(with: lm)
    let readingKeys = ["zai4", "chuang4", "shi4"]
    readingKeys.forEach { compositor.insertKey($0) }
    compositor.assemble()
    let assembledBefore = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 是", assembledBefore)

    let cursorShi = 2
    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceeded = compositor.overrideCandidate(
      .init(keyArray: ["shi4"], value: "世"),
      at: cursorShi,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertTrue(overrideSucceeded)
    XCTAssertEqual(obsCaptured?.ngramKey, "(zai4,再)&(chuang4,創)&(shi4,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }

    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 世", assembledAfter)
    pom.memorizePerception(
      (obsCaptured.ngramKey, obsCaptured.candidate),
      timestamp: Date().timeIntervalSince1970
    )

    let currentmemory = pom.getSavableData()
    let firstObservationKey = currentmemory.first?.key
    guard let firstObservationKey else {
      preconditionFailure("POM memorized nothing, or something wrong happen.")
    }
    XCTAssertEqual(firstObservationKey, obsCaptured.ngramKey)

    compositor.clear()
    readingKeys.forEach { compositor.insertKey($0) }
    compositor.assemble()

    let assembledNow = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 是", assembledNow)

    let cursorToTest = compositor.cursor
    let suggestion = pom.fetchSuggestion(
      assembledResult: compositor.assembledSentence,
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
    let overrideResult = compositor.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )
    if !overrideResult {
      compositor.overrideCandidateLiteral(
        candidateSuggested.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    compositor.assemble()
    let assembledByPOM = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("再 創 世", assembledByPOM)
  }

  func testPOM_8_ActualCaseScenario_BusinessEnglishSession() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_BusinessEnglishSession)
    let pom = LMAssembly.LMPerceptionOverride(
      dataURL: URL(fileURLWithPath: "/dev/null")
    )
    let compositor = Megrez.Compositor(with: lm)
    // 測試用句「再創世的凱歌」。
    let readingKeys = ["shang1", "wu4", "ying1", "yu3", "hui4", "hua4"]
    readingKeys.forEach { compositor.insertKey($0) }
    compositor.assemble()
    let assembledBefore = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("商務 英語 繪畫" == assembledBefore)
    // 測試此時生成的 keyForQueryingData 是否正確
    let cursorHua = 5
    let keyForQueryingDataAt5 = compositor.assembledSentence
      .generateKeyForPerception(cursor: cursorHua)
    XCTAssertEqual(keyForQueryingDataAt5?.ngramKey, "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,繪畫)")
    XCTAssertEqual(keyForQueryingDataAt5?.headReading, "hua4")
    // 應能提供『是的』『似的』『凱歌』等候選
    let pairsAtHuiHuaEnd = compositor.fetchCandidates(at: 6, filter: .endAt)
    XCTAssertTrue(pairsAtHuiHuaEnd.map(\.value).contains("繪畫"))
    XCTAssertTrue(pairsAtHuiHuaEnd.map(\.value).contains("會話"))
    // 模擬使用者把『是』改為『世』，再合成：觀測應為 shortToLong
    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceeded = compositor.overrideCandidate(
      .init(keyArray: ["hui4", "hua4"], value: "會話"),
      at: cursorHua,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertTrue(overrideSucceeded)
    XCTAssertEqual(obsCaptured?.ngramKey, "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,會話)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("商務 英語 會話" == assembledAfter)
    pom.memorizePerception(
      (obsCaptured.ngramKey, obsCaptured.candidate),
      timestamp: Date().timeIntervalSince1970
    )
    // 記憶完畢。先看看是否有記憶。
    let currentmemory = pom.getSavableData()
    let firstObservationKey = currentmemory.first?.key
    guard let firstObservationKey else {
      preconditionFailure("POM memorized nothing, or something wrong happen.")
    }
    XCTAssertEqual(firstObservationKey, obsCaptured.ngramKey)
    // 然後是記憶效力測試：
    let validationLM = SimpleLM(input: MegrezTestComponents.strLMSampleData_BusinessEnglishSession)
    let validationCompositor = Megrez.Compositor(with: validationLM)
    readingKeys.forEach { validationCompositor.insertKey($0) }
    validationCompositor.assemble()
    let cursorToTest = validationCompositor.cursor
    let assembledNow = validationCompositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertTrue(
      ["商務 英語 繪畫", "商務 英語 會話"].contains(assembledNow),
      "Unexpected baseline assembly: \(assembledNow)"
    )
    let suggestion = pom.fetchSuggestion(
      assembledResult: validationCompositor.assembledSentence,
      cursor: cursorToTest,
      timestamp: Date().timeIntervalSince1970
    )
    XCTAssertTrue(!suggestion.isEmpty)
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      preconditionFailure("POM suggested nothing, or something wrong happen.")
    }
    print(firstSuggestionRAW)
    let candidateSuggested = Megrez.KeyValuePaired(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value,
      score: firstSuggestionRAW.probability
    )
    let cursorForOverride = suggestion.overrideCursor ?? cursorHua
    let overrideResult = validationCompositor.overrideCandidate(
      candidateSuggested,
      at: cursorForOverride,
      overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
      enforceRetokenization: true
    )
    if !overrideResult {
      validationCompositor.overrideCandidateLiteral(
        candidateSuggested.value,
        at: cursorForOverride,
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore
      )
    }
    validationCompositor.assemble()
    let assembledByPOM = validationCompositor.assembledSentence
      .map(\.value)
      .joined(separator: " ")
    XCTAssertEqual("商務 英語 會話", assembledByPOM)
  }
}

extension Megrez.Node {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.Node {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.Node(
      keyArray: keyCells,
      segLength: keyCells.count,
      unigrams: [
        .init(value: tuplet4Test.value, score: tuplet4Test.score),
      ]
    )
  }
}

extension Megrez.GramInPath {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.GramInPath {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.GramInPath(
      gram: .init(keyArray: keyCells, value: tuplet4Test.value, score: tuplet4Test.score),
      isOverridden: false
    )
  }
}
