// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import Shared
import XCTest

@testable import LangModelAssembly

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMRapidForgetTests

final class POMRapidForgetTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Enable unit test mode for UserDefaults
    UserDefaults.pendingUnitTests = true
  }

  override func tearDown() {
    // Clean up test defaults
    UserDefaults.unitTests?.removeObject(forKey: "ReducePOMLifetimeToNoMoreThan12Hours")
    UserDefaults.pendingUnitTests = false
    super.tearDown()
  }

  /// 測試急速遺忘模式：當啟用後，記憶在 12 小時（0.5 天）後應該被遺忘
  func testPOM_RapidForget_01_EnabledMode() throws {
    // 設置 UserDefaults 值
    UserDefaults.unitTests?.set(true, forKey: "ReducePOMLifetimeToNoMoreThan12Hours")

    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )

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

    // 測試 12 小時（0.5 天）剛過後應該消失
    suggested = pom.getSuggestion(
      key: key1,
      timestamp: nowTimeStamp + (dayInSeconds * 0.5) + 10
    )
    XCTAssertNil(suggested, "12 小時後記憶應該已經衰減到閾值以下")
  }

  /// 測試正常模式：當未啟用急速遺忘模式時，記憶在約一週後才會被遺忘
  func testPOM_RapidForget_02_DisabledMode() throws {
    // 確保 UserDefaults 值為 false
    UserDefaults.unitTests?.set(false, forKey: "ReducePOMLifetimeToNoMoreThan12Hours")

    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )

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
      timestamp: nowTimeStamp + (dayInSeconds * 8) + 10
    )
    XCTAssertNil(suggested, "正常模式下 8 天後記憶應該已經衰減到閾值以下")
  }
}
