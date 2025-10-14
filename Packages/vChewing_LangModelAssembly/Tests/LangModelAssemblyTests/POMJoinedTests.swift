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

// MARK: - POMJoinedTests

final class POMJoinedTests: XCTestCase {
  func testPOM_AC01A_SaisoukiNoGaika() throws {
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
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(zai4,再)&(chuang4,創)&(shi4,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
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

  func testPOM_AC01B_SaisoukiOnly() throws {
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
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(zai4,再)&(chuang4,創)&(shi4,世)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }

    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
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

  func testPOM_AC02_BusinessEnglishSession() throws {
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
    XCTAssertEqual(obsCaptured?.contextualizedGramKey, "(shang1-wu4,商務)&(ying1-yu3,英語)&(hui4-hua4,會話)")
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    // compositor.assemble() <- 已經組句了。
    let assembledAfter = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue("商務 英語 會話" == assembledAfter)
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

  func testPOM_AC03_DiJiaoSubmission() throws {
    let lm = SimpleLM(input: MegrezTestComponents.strLMSampleData_DiJiaoSubmission)
    let pom = LMAssembly.LMPerceptionOverride(dataURL: URL(fileURLWithPath: "/dev/null"))
    let compositor = Megrez.Compositor(with: lm)
    let readingKeys = ["di4", "jiao1"]
    readingKeys.forEach { compositor.insertKey($0) }
    compositor.assemble()

    let overrideFirst = compositor.overrideCandidate(
      .init(keyArray: ["di4"], value: "第"),
      at: 0,
      enforceRetokenization: true
    )
    XCTAssertTrue(overrideFirst)
    compositor.assemble()

    let assembledAfterFirst = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertTrue(
      ["第 交", "第 教"].contains(assembledAfterFirst),
      "Unexpected assembly after forcing 第: \(assembledAfterFirst)"
    )

    let candidatesAtEnd = compositor.fetchCandidates(at: readingKeys.count, filter: .endAt)
    guard let diJiaoCandidate = candidatesAtEnd.first(where: { $0.value == "遞交" }) else {
      XCTFail("遞交 should be available as a candidate ending at the current cursor.")
      return
    }

    var obsCaptured: Megrez.PerceptionIntel?
    let overrideSucceeded = compositor.overrideCandidate(
      diJiaoCandidate,
      at: readingKeys.count,
      enforceRetokenization: true
    ) {
      obsCaptured = $0
    }
    XCTAssertTrue(overrideSucceeded)
    guard let obsCaptured else {
      preconditionFailure("Should have a capture.")
    }
    XCTAssertEqual(obsCaptured.candidate, "遞交")
    XCTAssertEqual(obsCaptured.contextualizedGramKey, "()&(di4,第)&(di4-jiao1,遞交)")

    let assembledAfterSecond = compositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("遞交", assembledAfterSecond)

    pom.memorizePerception(
      (obsCaptured.contextualizedGramKey, obsCaptured.candidate),
      timestamp: Date().timeIntervalSince1970
    )

    let savedKeys = pom.getSavableData().map(\.key)
    XCTAssertTrue(savedKeys.contains(obsCaptured.contextualizedGramKey))

    let directSuggestion = pom.getSuggestion(
      key: obsCaptured.contextualizedGramKey,
      timestamp: Date().timeIntervalSince1970
    )
    XCTAssertEqual(directSuggestion?.first?.value, "遞交")

    let validationLM = SimpleLM(input: MegrezTestComponents.strLMSampleData_DiJiaoSubmission)
    let validationCompositor = Megrez.Compositor(with: validationLM)
    readingKeys.forEach { validationCompositor.insertKey($0) }
    validationCompositor.assemble()
    _ = validationCompositor.overrideCandidate(
      .init(keyArray: ["di4"], value: "第"),
      at: 0,
      enforceRetokenization: true
    )
    validationCompositor.assemble()

    let baselineKey = validationCompositor.assembledSentence
      .generateKeyForPerception(cursor: max(validationCompositor.cursor - 1, 0))
    XCTAssertEqual(baselineKey?.ngramKey, "()&(di4,第)&(jiao1,交)")

    let suggestion = pom.fetchSuggestion(
      assembledResult: validationCompositor.assembledSentence,
      cursor: validationCompositor.cursor,
      timestamp: Date().timeIntervalSince1970
    )
    let savedDataDump = pom.getSavableData()
      .map { "\($0.key): \($0.perception.overrides.keys.sorted())" }
      .joined(separator: "; ")
    XCTAssertFalse(
      suggestion.isEmpty,
      "Suggestion should not be empty. Saved data: [\(savedDataDump)]"
    )
    guard let firstSuggestionRAW = suggestion.candidates.first else {
      preconditionFailure("POM suggested nothing, or something wrong happen.")
    }
    XCTAssertEqual(firstSuggestionRAW.value, "遞交")
    XCTAssertEqual(firstSuggestionRAW.keyArray, ["di4", "jiao1"])

    let candidateSuggested = Megrez.KeyValuePaired(
      keyArray: firstSuggestionRAW.keyArray,
      value: firstSuggestionRAW.value,
      score: firstSuggestionRAW.probability
    )
    let cursorForOverride = suggestion.overrideCursor ?? 0
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
        overrideType: suggestion.forceHighScoreOverride ? .withSpecified : .withTopGramScore,
        enforceRetokenization: true
      )
    }
    validationCompositor.assemble()
    let assembledByPOM = validationCompositor.assembledSentence.map(\.value).joined(separator: " ")
    XCTAssertEqual("遞交", assembledByPOM)
  }
}
