// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

// MARK: - POM 記憶分數隨時間下探（P327／事主裁定）

/// 事主裁定之新行為：「剛生成的 POM 永遠壓過語料，但隨著時間推移的話則不一定」。
/// 對應之實作：分數自 `-kWeightMultiplier`（≈ −0.1145，剛生成）單調下探至淘汰閾值
/// （`kDecayThreshold`，≈ −13），中段落在常見語料分數（−2 … −10）之區間內。
@Suite(.serialized)
struct POMTimeDecayTests {
  // MARK: Internal

  /// 剛生成者永遠壓過語料：分數近 0，高於任何常見語料單元圖。
  @Test
  func testFreshMemoryDominatesCorpus() {
    let fresh = weight(daysAgo: 0)
    #expect(fresh < 0)
    #expect(fresh > -1.0) // 高於 10⁻¹ 量級之語料分數
    #expect(fresh > -2.0) // 高於「常用詞」等級之語料分數
    // 起點即野獸常數：POM 之曲線刻意用 `kWeightMultiplier`（Tadokoro 式）、
    // 非自然對數；t = 0 ⇒ 分數恰為 −kWeightMultiplier。
    #expect(abs(fresh - (-LXAssembly.LXPerceptor.kWeightMultiplier)) < 1e-12)
  }

  /// 分數須隨時間單調下探（舊制之 `ageFactor` 反向：越老越強，已廢）。
  @Test
  func testScoreDecaysMonotonically() {
    let scores = [0.0, 1.0, 2.0, 4.0, 6.0, 7.5].map { weight(daysAgo: $0) }
    for idx in 1 ..< scores.count {
      #expect(scores[idx] < scores[idx - 1], "分數於第 \(idx) 段未下探")
    }
    #expect(scores.allSatisfy { $0 > LXAssembly.LXPerceptor.kDecayThreshold })
  }

  /// 老記憶「不一定」壓過語料：五日齡已低於常見語料分數，但仍高於淘汰閾值。
  @Test
  func testAgedMemoryMayLoseToCorpus() {
    let aged = weight(daysAgo: 5) // wT＝8 天
    #expect(aged < -2.0)
    #expect(aged > LXAssembly.LXPerceptor.kDecayThreshold)
  }

  /// 到達視窗末端即淘汰（分數低於閾值），與既有 `daysDiff >= wT` 之硬截止一致。
  @Test
  func testExpiredMemoryReturnsBelowThreshold() {
    let expected = LXAssembly.LXPerceptor.kDecayThreshold - 0.001
    #expect(weight(daysAgo: 8.0) == expected)
    #expect(weight(daysAgo: 9.0) == expected)
  }

  /// 用得越多、下探越慢（同一年齡下，高頻記憶之分數較高）。
  @Test
  func testRepeatedUsageDecaysSlower() {
    let rare = weight(daysAgo: 3, eventCount: 1, totalCount: 10)
    let frequent = weight(daysAgo: 3, eventCount: 10, totalCount: 10)
    #expect(frequent > rare)
  }

  /// 記憶不得改寫語料側的 unigram 分數本身。
  @Test
  func testInjectionDoesNotRewriteCorpusGrams() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lxFacade = LXAssembly.LXFacade()
    let before = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    lxFacade.memorizePerception(
      (ngramKey: "(ㄕˋ,是)&(ㄇㄚ,媽)", candidate: "媽"),
      timestamp: Date().timeIntervalSince1970
    )
    let after = lxFacade.unigramsFor(keyArray: ["ㄇㄚ"])
    let beforeScore = before.first {
      $0.current == "媽" && $0.previous == nil && $0.anterior == nil
    }?.probability
    let afterScore = after.first {
      $0.current == "媽" && $0.previous == nil && $0.anterior == nil
    }?.probability
    #expect(beforeScore == afterScore)
  }

  // MARK: Private

  private let dayInSeconds: Double = 24 * 3_600
  private let nowTimeStamp: Double = 114_514 * 10_000

  private func weight(
    daysAgo: Double,
    eventCount: Int = 1,
    totalCount: Int = 1,
    isUnigram: Bool = false
  )
    -> Double {
    let pom = LXAssembly.LXPerceptor(capacity: 5, dataURL: URL(fileURLWithPath: "/dev/null"))
    return pom.calculateWeight(
      eventCount: eventCount,
      totalCount: totalCount,
      eventTimestamp: nowTimeStamp - daysAgo * dayInSeconds,
      timestamp: nowTimeStamp,
      isUnigram: isUnigram
    )
  }
}
