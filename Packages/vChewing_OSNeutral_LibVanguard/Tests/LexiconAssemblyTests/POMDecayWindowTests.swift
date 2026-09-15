// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Testing

@testable import LexiconAssembly

// 更新時間常數，使用天為單位，與 Perceptor 保持一致
private let nowTimeStamp: Double = 114_514 * 10_000
private let capacity = 5
private let dayInSeconds: Double = 24 * 3_600 // 一天的秒數
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - POMTestSuite.POMDecayWindowTests

extension POMTestSuite {
  /// 記憶衰退視窗的邊界值覆蓋。
  ///
  /// 既有的 `POMBasicTests` 只探測「視窗內」（5 天內／7.5 天）與「明顯逾窗」（8 天／10 天）；
  /// 本組測項補上視窗邊界前後的細粒度探針，以及「視窗自最近一次使用起算」這一語意。
  @Suite(.serialized)
  struct POMDecayWindowTests {
    /// 有效視窗自「最近一次使用」起算，而非自「首次記錄」起算。
    @Test
    func testPOM_DW01_ObservationWindowAnchoredToLatestUse() throws {
      let pom = LXAssembly.LXPerceptor(
        capacity: capacity,
        dataURL: nullURL
      )
      let key = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
      let valRepeatedlyUsed = "狗" // 更常用
      let valNewest = "苟" // 最近偶爾用了一次

      for offset in [0.0, 0.1, 0.2] {
        pom.memorizePerception(
          (key, valRepeatedlyUsed),
          timestamp: nowTimeStamp + dayInSeconds * offset
        )
      }
      #expect(pom.getSuggestion(key: key, timestamp: nowTimeStamp)?.first?.value == valRepeatedlyUsed)

      // 第 1 天改用另一個候選字。
      pom.memorizePerception((key, valNewest), timestamp: nowTimeStamp + dayInSeconds)
      #expect(
        pom.getSuggestion(key: key, timestamp: nowTimeStamp + dayInSeconds * 1.1)?.first?.value == valNewest
      )

      // 7.5 天仍在有效視窗內。
      #expect(pom.getSuggestion(key: key, timestamp: nowTimeStamp + dayInSeconds * 7.5) != nil)
      // 8.01 天仍可取得：視窗是從第 1 天的最後一次選擇起算的。
      #expect(pom.getSuggestion(key: key, timestamp: nowTimeStamp + dayInSeconds * 8.01) != nil)
      // 9.1 天已逾「最後一次選擇 + 8 天」。
      #expect(pom.getSuggestion(key: key, timestamp: nowTimeStamp + dayInSeconds * 9.1) == nil)
    }

    /// 逐日掃描長期記憶的衰退情形，含 8 天之後不得復活的長時程探針。
    @Test
    func testPOM_DW02_LongTermMemoryDecaySweep() throws {
      let pom = LXAssembly.LXPerceptor(
        capacity: capacity,
        dataURL: nullURL
      )
      let key = "(ㄔㄥˊ-ㄒㄧㄣˋ,誠信)&(ㄓㄜˋ,這)&(ㄉㄧㄢˇ,點)"
      let expectedSuggestion = "點"

      pom.memorizePerception((key, expectedSuggestion), timestamp: nowTimeStamp)

      let testCases: [(day: Double, expectAvailable: Bool)] = [
        (0, true),
        (1, true),
        (3, true),
        (5, true),
        (7.5, true),
        (8.1, false),
        (9.0, false),
        (20, false),
        (80, false),
      ]

      for testCase in testCases {
        let suggested = pom.getSuggestion(
          key: key,
          timestamp: nowTimeStamp + dayInSeconds * testCase.day
        )
        if testCase.expectAvailable {
          #expect(suggested != nil)
          if let score = suggested?.first?.probability {
            #expect(score > pom.threshold)
          }
        } else {
          #expect(suggested == nil)
        }
      }
    }

    /// 連續覆寫所產生的洞察，其可保存資料的排序須為「最近使用者在先」。
    @Test
    func testPOM_DW03_SavableDataOrderingAfterOverrides() throws {
      defer {
        LXAssembly.LXFacade.disconnectFactoryDictionary()
      }
      #expect(
        LXAssembly.LXFacade.connectToTestFactoryDictionary(
          textMapData: LXATestsData.textMapTestCoreLXData
        )
      )
      let pom = LXAssembly.LXPerceptor(
        capacity: capacity,
        dataURL: nullURL
      )
      let instance = LXAssembly.LXFacade(isCHS: false)
      instance.setOptions { config in
        config.partialMatchEnabled = false
        config.alwaysSupplyETenDOSUnigrams = false
      }
      let readings: [Substring] = "ㄧㄡ ㄉㄧㄝˊ ㄋㄥˊ ㄌㄧㄡˊ ㄧˋ ㄌㄩˇ ㄈㄤ".split(separator: " ")
      let assembler = Homa.Assembler(
        gramQuerier: instance.lxQuerier.grams(for:)
      )
      try readings.forEach { try assembler.insertKey($0.description) }
      #expect(assembler.assemble().compactMap(\.value) == ["優", "跌", "能", "留意", "旅", "方"])

      var observations: [Homa.PerceptionIntel] = []
      try assembler.overrideCandidate(.init((["ㄧㄡ"], "幽")), at: 0) { observations.append($0) }
      try assembler.overrideCandidate(.init((["ㄉㄧㄝˊ"], "蝶")), at: 1) { observations.append($0) }
      try assembler.overrideCandidate(.init((["ㄌㄧㄡˊ"], "留")), at: 3) { observations.append($0) }
      try assembler.overrideCandidate(.init((["ㄧˋ", "ㄌㄩˇ"], "一縷")), at: 4) { observations.append($0) }
      try assembler.overrideCandidate(.init((["ㄈㄤ"], "芳")), at: 6) { observations.append($0) }
      #expect(assembler.assemble().compactMap(\.value) == ["幽", "蝶", "能", "留", "一縷", "芳"])

      for (index, intel) in observations.enumerated() {
        pom.memorizePerception(
          (intel.contextualizedGramKey, intel.candidate),
          timestamp: nowTimeStamp + Double(index)
        )
      }

      let expectedPerceptionKeys: [String] = [
        "(ㄌㄧㄡˊ,留)&(ㄧˋ-ㄌㄩˇ,一縷)&(ㄈㄤ,芳)",
        "(ㄋㄥˊ,能)&(ㄌㄧㄡˊ,留)&(ㄧˋ-ㄌㄩˇ,一縷)",
        "(ㄉㄧㄝˊ,蝶)&(ㄋㄥˊ,能)&(ㄌㄧㄡˊ,留)",
        "()&(ㄧㄡ,幽)&(ㄉㄧㄝˊ,蝶)",
        "()&()&(ㄧㄡ,幽)",
      ]
      #expect(pom.getSavableData().map(\.key) == expectedPerceptionKeys)
    }
  }
}
