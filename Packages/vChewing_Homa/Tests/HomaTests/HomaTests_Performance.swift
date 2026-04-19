// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import HomaSharedTestComponents
import Testing

@testable import Homa

// MARK: - HomaPerformanceTests

@Suite(.serialized)
public struct HomaPerformanceTests: HomaTestSuite {
  // MARK: Internal

  @Test("[Homa] Bench_LargeScaleSentenceAssembly")
  func testLargeScaleSentenceAssembly() async throws {
    print("// Starting large scale sentence assembly performance test")

    // 構築一份更複雜的測試資料。這次使用繁體中文。

    let testSentences = [
      "suo3-wei4-kai1-tuo4", // 所謂開拓
      "jiu4-shi4-yan2-zhe5-qian2-ren2-wei4-jin4-de5-dao4-lu4", // 就是沿著前人未盡的道路
      "zou3-chu1-geng1-yao2-yuan3-de5-ju4-li2", // 走出更遙遠的距離
      "yin1-wei2-kai1-tuo4-de5-dao4-lu4", // 因為開拓的道路
      "cong2-lai2-bu4-you2-ta1-ren2-pu1-jiu4", // 從來不由他人鋪就
    ]

    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataTrailblazing)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) },
      gramAvailabilityChecker: { mockLM.hasGrams($0) }
    )

    var totalTime: Double = 0
    let iterations = 100

    for iteration in 0 ..< iterations {
      let sentence = testSentences[iteration % testSentences.count]
      let keys = sentence.split(separator: "-").map(String.init)

      // 每次迭代都清空一次組字器。
      assembler.clear()

      let iterationTime = Self.measureTime {
        do {
          for key in keys {
            try assembler.insertKey(key)
          }
          _ = assembler.assemble()
        } catch {
          // Handle error
        }
      }

      totalTime += iterationTime

      if iteration % 20 == 0 {
        print("// Completed iteration \(iteration), time: \(iterationTime)s")
      }
    }

    let averageTime = totalTime / Double(iterations)
    print("// Average time per sentence: \(averageTime)s")
    print("// Total time for \(iterations) iterations: \(totalTime)s")

    // 效能斷言 - 平均每句話的組字不該超過 5ms。
    #expect(
      averageTime < 0.005,
      "Sentence assembly should be under 5ms on average, was \(averageTime)s"
    )
  }

  @Test("[Homa] Bench_TrieOpsStressTest")
  func testTrieOperationsStress() async throws {
    print("// Starting Trie operations stress test")

    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataTrailblazing)

    // 測試查詢效能。
    let keys = ["suo3", "wei4", "kai1", "tuo4", "jiu4", "shi4"]
    let iterations = 1_000

    let queryTime = Self.measureTime {
      for _ in 0 ..< iterations {
        for key in keys {
          _ = mockLM.queryGrams([key])
          _ = mockLM.hasGrams([key])
        }
      }
    }

    let avgQueryTime = queryTime / Double(iterations * keys.count)
    print("// Average query time: \(avgQueryTime)s")
    print("// Total query time for \(iterations * keys.count) operations: \(queryTime)s")

    // 效能斷言 - 平均每句話的組字不該超過 0.1ms。
    #expect(
      avgQueryTime < 0.0001,
      "Trie queries should be under 0.1ms on average, was \(avgQueryTime)s"
    )
  }

  @Test("[Homa] Bench_MemoryUsageAndARCPressure")
  func testMemoryUsage() async throws {
    print("// Starting memory usage test")

    let mockLM = TestLM(rawData: HomaTests.strLMSampleDataTrailblazing)
    let assembler = Homa.Assembler(
      gramQuerier: { mockLM.queryGrams($0) },
      gramAvailabilityChecker: { mockLM.hasGrams($0) }
    )

    // 模擬重度使用情形模式
    let testTime = Self.measureTime {
      for batch in 0 ..< 50 {
        // 創建暨摧毀組字器副本，測試 ARC 效能
        for _ in 0 ..< 20 {
          let tempAssembler = Homa.Assembler(
            gramQuerier: { mockLM.queryGrams($0) },
            gramAvailabilityChecker: { mockLM.hasGrams($0) }
          )

          try? tempAssembler.insertKey("test\(batch)")
          _ = tempAssembler.assemble()
        }

        // 以累積資料測試主要組字器
        try? assembler.insertKey("batch\(batch)")
        _ = assembler.assemble()

        if batch % 10 == 0 {
          assembler.clear()
        }
      }
    }

    print("// Memory usage test completed in: \(testTime)s")
    #expect(
      testTime < 1.0,
      "Memory usage test should complete in under 1 second, took \(testTime)s"
    )
  }

  @Test("[Homa] Bench_AdvancedOptimizations")
  func testAdvancedOptimizations() async throws {
    print("// Starting advanced optimizations benchmark")

    // 用更大的真實資料集來做測試
    let testData = generateRealisticChineseInput()
    let mockLM = TestLM(rawData: testData.mockData)

    var totalTime: Double = 0
    let iterations = 200 // 增加迭代次數以追求測試可信度

    // 預熱快取
    for _ in 0 ..< 10 {
      let assembler = Homa.Assembler(
        gramQuerier: { mockLM.queryGrams($0) },
        gramAvailabilityChecker: { mockLM.hasGrams($0) }
      )

      for key in testData.keys.prefix(5) {
        try? assembler.insertKey(key)
      }
      _ = assembler.assemble()
    }

    // 執行實際基準測試
    for iteration in 0 ..< iterations {
      let keys = testData.keys

      let iterationTime = try Self.measureTime {
        let assembler = Homa.Assembler(
          gramQuerier: { mockLM.queryGrams($0) },
          gramAvailabilityChecker: { mockLM.hasGrams($0) }
        )

        for key in keys {
          try assembler.insertKey(key)
        }
        _ = assembler.assemble()
      }

      totalTime += iterationTime

      if iteration % 50 == 0 {
        print("// Iteration \(iteration), time: \(iterationTime)s")
      }
    }

    let averageTime = totalTime / Double(iterations)
    print("// Advanced benchmark - Average time: \(averageTime)s")
    print("// Advanced benchmark - Total time: \(totalTime)s for \(iterations) iterations")

    // 效能斷言 - 這裡使用更寬鬆的閾值要求
    #expect(
      averageTime < 0.02,
      "Advanced benchmark should be under 20ms on average, was \(averageTime)s"
    )
  }

  // MARK: Private

  private func generateRealisticChineseInput() -> (keys: [String], mockData: String) {
    // 生成複雜的擬真語言模型資料。
    var mockData = HomaTests.strLMSampleDataTrailblazing

    // 建立真實的中文拼音輸入模式 - 使用與 Mock 資料對應的拼音讀音
    let knownPinyin = [
      "suo3", "wei4", "kai1", "tuo4", "jiu4", "shi4",
      "yan2", "zhe5", "qian2", "ren2", "wei4", "jin4",
      "de5", "dao4", "lu4", "zou3", "chu1", "geng1",
      "yao2", "yuan3", "ju4", "li2", "yin1", "wei2",
      "cong2", "lai2", "bu4", "you2", "ta1", "pu1",
    ]

    // 建立一些雙元圖組合
    for i in 0 ..< min(knownPinyin.count, 10) {
      for j in 0 ..< min(knownPinyin.count, 10) {
        let bigram = "\(knownPinyin[i])-\(knownPinyin[j])"
        let weight = -7.0 - Double.random(in: 0 ... 2)
        mockData += "\n\(bigram) 測試\(i)\(j) \(weight)"
      }
    }

    // 生成測試用讀音鍵值，以模擬長句輸入。只使用已知存在的讀音。
    var keys: [String] = []
    for _ in 0 ..< 15 { // Longer input sequence
      keys.append(knownPinyin.randomElement()!)
    }

    return (keys: keys, mockData: mockData)
  }
}
