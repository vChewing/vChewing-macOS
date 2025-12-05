// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import XCTest

@testable import LangModelAssembly

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMRapidForgetTests

final class POMRapidForgetTests: XCTestCase {
  /// 測試急速遺忘模式：當啟用後，記憶在 12 小時（0.5 天）後應該被遺忘
  func testPOM_RapidForget_01_EnabledMode() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    
    // 啟用急速遺忘模式
    pom.prefs.reducePOMLifetimeToNoMoreThan12Hours = true
    
    let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    let expectedSuggestion = "狗"
    pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "應該立即找到記憶")

    // 測試 6 小時內應該保留（0.25 天）
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 0.25)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "6 小時內記憶應該保留")

    // 測試 12 小時（0.5 天）後應該消失
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 0.5)
    )
    XCTAssertNil(suggested, "12 小時後記憶應該已經衰減到閾值以下")
  }

  /// 測試正常模式：當未啟用急速遺忘模式時，記憶在約一週後才會被遺忘
  func testPOM_RapidForget_02_DisabledMode() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    
    // 不啟用急速遺忘模式（預設值為 false）
    pom.prefs.reducePOMLifetimeToNoMoreThan12Hours = false
    
    let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    let expectedSuggestion = "狗"
    pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "應該立即找到記憶")

    // 測試 12 小時內應該保留（0.5 天）
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 0.5)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "正常模式下 12 小時內記憶應該保留")

    // 測試 2 天內應該保留
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 2)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "正常模式下 2 天內記憶應該保留")

    // 測試 8 天後應該消失
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 8)
    )
    XCTAssertNil(suggested, "正常模式下 8 天後記憶應該已經衰減到閾值以下")
  }

  /// 測試急速遺忘模式與正常模式的對比：同一個記憶在兩種模式下的衰減速度不同
  func testPOM_RapidForget_03_ModeComparison() throws {
    let pomRapid = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let pomNormal = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    
    pomRapid.prefs.reducePOMLifetimeToNoMoreThan12Hours = true
    pomNormal.prefs.reducePOMLifetimeToNoMoreThan12Hours = false
    
    let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    let expectedSuggestion = "狗"
    
    pomRapid.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)
    pomNormal.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

    // 測試 12 小時（0.5 天）後的差異
    let testTime = nowTimeStamp + (dayInSeconds * 0.5)
    
    let rapidSuggested = pomRapid.getSuggestion(key: key1, timestamp: testTime)
    let normalSuggested = pomNormal.getSuggestion(key: key1, timestamp: testTime)
    
    XCTAssertNil(rapidSuggested, "急速遺忘模式下 12 小時後記憶應該消失")
    XCTAssertEqual(normalSuggested?.first?.value ?? "", expectedSuggestion, "正常模式下 12 小時後記憶應該保留")
  }

  /// 測試急速遺忘模式對單字的影響：單字的遺忘速度應該更快
  func testPOM_RapidForget_04_UnigramEffect() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    
    pom.prefs.reducePOMLifetimeToNoMoreThan12Hours = true
    
    // 使用單字鍵（unigram）
    let unigramKey = "(ㄍㄡˇ,狗)"
    let expectedSuggestion = "狗"
    pom.memorizePerception((unigramKey, expectedSuggestion), timestamp: nowTimeStamp)

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: unigramKey, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "應該立即找到記憶")

    // 單字在急速遺忘模式下，遺忘時間會更短（0.5 * 0.85 = 0.425 天）
    // 測試 0.3 天（約 7.2 小時）應該保留
    suggested = pom.getSuggestion(
      key: unigramKey,
      timestamp: nowTimeStamp + (dayInSeconds * 0.3)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion, "單字在 7.2 小時內應該保留")

    // 測試 0.425 天（約 10.2 小時）後應該消失
    suggested = pom.getSuggestion(
      key: unigramKey,
      timestamp: nowTimeStamp + (dayInSeconds * 0.425)
    )
    XCTAssertNil(suggested, "單字在急速遺忘模式下約 10.2 小時後應該消失")
  }
}
