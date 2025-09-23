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

// MARK: - POMAlphaTests

final class POMAlphaTests: XCTestCase {
  // MARK: Internal

  func testPOM_1_BasicPerceptionOps() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let key = "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)"
    let expectedSuggestion = "狗"
    observe(who: pom, key: key, candidate: expectedSuggestion, timestamp: nowTimeStamp)

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion)
    XCTAssertEqual(suggested?.first?.previous ?? "", "的")

    // 測試 2 天和 8 天的記憶衰退
    // 2 天內應該保留，8 天應該消失
    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + (dayInSeconds * 2)
    )
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion)

    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + (dayInSeconds * 8)
    )
    XCTAssertNil(suggested, "8天後記憶應該已經衰減到閾值以下")
  }

  func testPOM_2_NewestAgainstRepeatedlyUsed() throws {
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity,
      dataURL: nullURL
    )
    let key = "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)"
    let valRepeatedlyUsed = "狗" // 更常用
    let valNewest = "苟" // 最近偶爾用了一次

    // 使用天數作為單位
    let stamps: [Double] = [0, 0.1, 0.2].map { nowTimeStamp + dayInSeconds * $0 }
    stamps.forEach { stamp in
      observe(who: pom, key: key, candidate: valRepeatedlyUsed, timestamp: stamp)
    }

    // 即時查詢應該能找到結果
    var suggested = pom.getSuggestion(key: key, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", valRepeatedlyUsed)

    // 在 1 天後選擇了另一個候選字
    observe(
      who: pom,
      key: key,
      candidate: valNewest,
      timestamp: nowTimeStamp + dayInSeconds * 1
    )

    // 在 1.1 天檢查最新使用的候選字是否被建議
    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + dayInSeconds * 1.1
    )
    XCTAssertEqual(suggested?.first?.value ?? "", valNewest)

    // 在 8 天時，記憶應該已經衰減到閾值以下
    suggested = pom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + dayInSeconds * 8
    )
    XCTAssertNil(suggested, "經過8天後記憶仍未完全衰減")
  }

  func testPOM_3_LRUTable() throws {
    let a = (key: "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)", value: "狗", head: "ㄍㄡˇ")
    let b = (key: "((ㄆㄞˋ-ㄇㄥˊ,派蒙),(ㄉㄜ˙,的),ㄐㄧㄤˇ-ㄐㄧㄣ)", value: "伙食費", head: "ㄏㄨㄛˇ-ㄕˊ-ㄈㄟˋ")
    let c = (key: "((ㄍㄨㄛˊ-ㄅㄥ,國崩),(ㄉㄜ˙,的),ㄇㄠˋ-ㄗ˙)", value: "帽子", head: "ㄇㄠˋ-ㄗ˙")
    let d = (key: "((ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍),(ㄉㄜ˙,的),ㄐㄧㄠˇ-ㄔㄡˋ)", value: "腳臭", head: "ㄐㄧㄠˇ-ㄔㄡˋ")

    // 容量為2的LRU測試
    let pom = LMAssembly.LMPerceptionOverride(
      capacity: 2,
      dataURL: nullURL
    )

    // 緊接著記錄三個項目，只保留最後兩個
    observe(who: pom, key: a.key, candidate: a.value, timestamp: nowTimeStamp)
    observe(who: pom, key: b.key, candidate: b.value, timestamp: nowTimeStamp + 1)
    observe(who: pom, key: c.key, candidate: c.value, timestamp: nowTimeStamp + 2)

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
    observe(who: pom, key: d.key, candidate: d.value, timestamp: nowTimeStamp + 6)

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
    let key = "((ㄔㄥˊ-ㄒㄧㄣˋ,誠信),(ㄓㄜˋ,這),ㄉㄧㄢˇ)"
    let expectedSuggestion = "點"

    // 記錄一個記憶
    observe(who: pom, key: key, candidate: expectedSuggestion, timestamp: nowTimeStamp)

    // 確認剛剛記錄的能被找到
    var suggested = pom.getSuggestion(key: key, timestamp: nowTimeStamp)
    XCTAssertEqual(suggested?.first?.value ?? "", expectedSuggestion)

    // 測試不同天數的衰減
    let testDays = [0, 1, 3, 5, 6, 6.5, 7, 8, 20]

    for days in testDays {
      let currentTimestamp = nowTimeStamp + (dayInSeconds * Double(days))
      suggested = pom.getSuggestion(key: key, timestamp: currentTimestamp)

      if days <= 5 {
        XCTAssertNotNil(suggested, "第\(days)天就不該衰減到閾值以下")
        if let suggestion = suggested?.first {
          let score = suggestion.probability
          XCTAssertTrue(
            score > LMAssembly.LMPerceptionOverride.kDecayThreshold,
            "第\(days)天的權重\(score)不應低於閾值\(LMAssembly.LMPerceptionOverride.kDecayThreshold)"
          )
        }
      } else {
        XCTAssertNil(suggested, "第\(days)天應該已經衰減到閾值以下")
      }
    }
  }

  func testPOM_5_ObservationKeyGeneration() throws {
    let sentence1: [Megrez.GramInPath] = [
      ("you1-die2", "幽蝶", -8.496),
      ("neng2", "能", -5.36),
      ("liu2-yi4", "留意", -4.407),
      ("lv3-fang1", "呂方", -6.585),
    ].map(Megrez.GramInPath.fromTuplet)

    let sentence2: [Megrez.GramInPath] = [
      ("you1-die2", "幽蝶", -8.496),
      ("neng2", "能", -5.36),
      ("liu2", "留", -5.245),
      ("yi4", "亦", -5.205),
      ("lv3-fang1", "呂方", -6.585),
    ].map(Megrez.GramInPath.fromTuplet)

    let sentence3: [Megrez.GramInPath] = [
      ("you1-die2", "幽蝶", -8.496),
      ("neng2", "能", -5.36),
      ("liu2", "留", -5.245),
      ("yi4-lv3", "一縷", -8.496),
      ("fang1", "芳", -6.237),
    ].map(Megrez.GramInPath.fromTuplet)

    let pom = LMAssembly.LMPerceptionOverride(
      capacity: capacity
    )

    // S2 vs S3，非插斷之情形。此時 Head 取游標正前方的相鄰節點。
    do {
      let key2v3 = pom.performObservation(
        walkedBefore: sentence2,
        walkedAfter: sentence3,
        cursor: 4, // 此時的當前節點的詞音為 yi4-lv3 (一縷)。
        timestamp: Date.now.timeIntervalSince1970
      ) ?? ("NULL", "NULL")
      XCTAssertTrue(key2v3 == ("((neng2,能),(liu2,留),yi4-lv3)", "一縷"))
      // 避免出現這種狗屄倒肏的結果：
      XCTAssertTrue(key2v3 != ("((liu2,留),(yi4-lv3,一縷),fang1)", "一縷"))
    }

    // S1 vs S2，乃插斷之情形。此時 Head 取游標位置起算的單字節點。
    do {
      let key1v2 = pom.performObservation(
        walkedBefore: sentence1,
        walkedAfter: sentence2,
        cursor: 3, // 此時的當前節點的詞音為 liu2-yi4 (留意)。
        timestamp: Date.now.timeIntervalSince1970
      ) ?? ("NULL", "NULL")
      XCTAssertTrue(key1v2 == ("((you1-die2,幽蝶),(neng2,能),liu2)", "留"))
    }
  }

  // MARK: Private

  private func observe(
    who pom: LMAssembly.LMPerceptionOverride,
    key: String,
    candidate: String,
    timestamp stamp: Double
  ) {
    pom.memorizePerception(
      (ngramKey: key, candidate: candidate),
      timestamp: stamp
    )
  }
}

extension Megrez.Node {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.Node {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.Node(keyArray: keyCells, segLength: keyCells.count, unigrams: [
      .init(value: tuplet4Test.value, score: tuplet4Test.score),
    ])
  }
}

extension Megrez.GramInPath {
  fileprivate static func fromTuplet(
    _ tuplet4Test: (keyChain: String, value: String, score: Double)
  )
    -> Megrez.GramInPath {
    let keyCells = tuplet4Test.keyChain.split(separator: "-").map(\.description)
    return Megrez.GramInPath(
      keyArray: keyCells,
      gram: .init(value: tuplet4Test.value, score: tuplet4Test.score),
      isOverridden: false
    )
  }
}
