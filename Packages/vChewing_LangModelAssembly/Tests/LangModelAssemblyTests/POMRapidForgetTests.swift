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
import Testing

@testable import LangModelAssembly

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMTestSuite.POMRapidForgetTests

extension POMTestSuite {
  // MARK: - POMRapidForgetTests

  @Suite(.serialized)
  final class POMRapidForgetTests {
    /// 測試急速遺忘模式：當啟用後，記憶在 12 小時（0.5 天）後應該被遺忘
    @Test
    func testPOM_RapidForget_01_EnabledMode() throws {
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: capacity,
        dataURL: nullURL
      )
      pom.reducedLifetime = true

      let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
      let expectedSuggestion = "狗"
      pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

      // 即時查詢應該能找到結果
      var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      // 測試 6 小時內應該保留（0.25 天）
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 0.25)
      )
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      // 測試 12 小時（0.5 天）剛過後應該消失
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 0.5) + 10
      )
      #expect(suggested == nil)
    }

    /// 測試正常模式：當未啟用急速遺忘模式時，記憶在約一週後才會被遺忘
    @Test
    func testPOM_RapidForget_02_DisabledMode() throws {
      let pom = LMAssembly.LMPerceptionOverride(
        capacity: capacity,
        dataURL: nullURL
      )
      pom.reducedLifetime = false

      let key1 = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
      let expectedSuggestion = "狗"
      pom.memorizePerception((key1, expectedSuggestion), timestamp: nowTimeStamp)

      // 即時查詢應該能找到結果
      var suggested = pom.getSuggestion(key: key1, timestamp: nowTimeStamp)
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      // 測試 12 小時內應該保留（0.5 天）
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 0.5)
      )
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      // 測試 2 天內應該保留
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 2)
      )
      #expect((suggested?.first?.value ?? "") == expectedSuggestion)

      // 測試 8 天後應該消失
      suggested = pom.getSuggestion(
        key: key1,
        timestamp: nowTimeStamp + (dayInSeconds * 8) + 10
      )
      #expect(suggested == nil)
    }

    /// 測試 LMInstantiator 對 POM 的 rapid-forget 注入轉發。
    @Test
    func testPOM_RapidForget_03_LMInstantiatorForwardsReducedLifetimeFlag() throws {
      let instance = LMAssembly.LMInstantiator(pomDataURL: nullURL)

      #expect(instance.lmPerceptionOverride.reducedLifetime == false)

      instance.pomReducedLifetime = true
      #expect(instance.lmPerceptionOverride.reducedLifetime == true)

      instance.pomReducedLifetime = false
      #expect(instance.lmPerceptionOverride.reducedLifetime == false)
    }
  }
}
