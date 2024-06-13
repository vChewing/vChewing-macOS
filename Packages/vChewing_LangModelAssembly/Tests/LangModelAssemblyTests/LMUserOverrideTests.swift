//// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

@testable import LangModelAssembly

private let nowTimeStamp: Double = 114_514 * 10000
private let capacity = 5
private let halfLife: Double = 5400
private let nullURL = URL(fileURLWithPath: "/dev/null")

// MARK: - LMUserOverrideTests

final class LMUserOverrideTests: XCTestCase {
  // MARK: Internal

  func testUOM_1_BasicOps() throws {
    let uom = LMAssembly.LMUserOverride(
      capacity: capacity,
      decayConstant: Double(halfLife),
      dataURL: nullURL
    )
    let key = "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)"
    let headReading = "ㄍㄡˇ"
    let expectedSuggestion = "狗"
    observe(who: uom, key: key, candidate: expectedSuggestion, timestamp: nowTimeStamp)
    var suggested = uom.getSuggestion(key: key, timestamp: nowTimeStamp, headReading: headReading)
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", expectedSuggestion)
    var i = 0
    while !suggested.candidates.isEmpty {
      suggested = uom.getSuggestion(
        key: key,
        timestamp: nowTimeStamp + (halfLife * Double(i)),
        headReading: headReading
      )
      let suggestedCandidates = suggested.candidates
      if suggestedCandidates.isEmpty { print(i) }
      if i >= 21 {
        XCTAssertNotEqual(
          Set(suggested.candidates.map(\.1.value)).first ?? "",
          expectedSuggestion,
          i.description
        )
        XCTAssert(suggested.candidates.isEmpty)
      } else {
        XCTAssertEqual(
          Set(suggested.candidates.map(\.1.value)).first ?? "",
          expectedSuggestion,
          i.description
        )
      }
      i += 1
    }
  }

  func testUOM_2_NewestAgainstRepeatedlyUsed() throws {
    let uom = LMAssembly.LMUserOverride(
      capacity: capacity,
      decayConstant: Double(halfLife),
      dataURL: nullURL
    )
    let key = "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)"
    let headReading = "ㄍㄡˇ"
    let valRepeatedlyUsed = "狗" // 更常用
    let valNewest = "苟" // 最近偶爾用了一次
    let stamps: [Double] = [0, 0.5, 2, 2.5, 4, 4.5, 5.3].map { nowTimeStamp + halfLife * $0 }
    stamps.forEach { stamp in
      observe(who: uom, key: key, candidate: valRepeatedlyUsed, timestamp: stamp)
    }
    var suggested = uom.getSuggestion(key: key, timestamp: nowTimeStamp, headReading: headReading)
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", valRepeatedlyUsed)
    [6.0, 18.0, 23.0].forEach { i in
      suggested = uom.getSuggestion(
        key: key,
        timestamp: nowTimeStamp + halfLife * Double(i),
        headReading: headReading
      )
      XCTAssertEqual(
        Set(suggested.candidates.map(\.1.value)).first ?? "",
        valRepeatedlyUsed,
        i.description
      )
    }
    // 試試看偶爾選了不常用的詞的話、是否會影響上文所生成的有一定強效的記憶。
    observe(who: uom, key: key, candidate: valNewest, timestamp: nowTimeStamp + halfLife * 23.4)
    suggested = uom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + halfLife * 26,
      headReading: headReading
    )
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", valNewest)
    suggested = uom.getSuggestion(
      key: key,
      timestamp: nowTimeStamp + halfLife * 50,
      headReading: headReading
    )
    XCTAssertNotEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", valNewest)
    XCTAssert(suggested.candidates.isEmpty)
  }

  func testUOM_3_LRUTable() throws {
    let a = (key: "((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)", value: "狗", head: "ㄍㄡˇ")
    let b = (key: "((ㄆㄞˋ-ㄇㄥˊ,派蒙),(ㄉㄜ˙,的),ㄐㄧㄤˇ-ㄐㄧㄣ)", value: "伙食費", head: "ㄏㄨㄛˇ-ㄕˊ-ㄈㄟˋ")
    let c = (key: "((ㄍㄨㄛˊ-ㄅㄥ,國崩),(ㄉㄜ˙,的),ㄇㄠˋ-ㄗ˙)", value: "帽子", head: "ㄇㄠˋ-ㄗ˙")
    let d = (key: "((ㄌㄟˊ-ㄉㄧㄢˋ-ㄐㄧㄤ-ㄐㄩㄣ,雷電將軍),(ㄉㄜ˙,的),ㄐㄧㄠˇ-ㄔㄡˋ)", value: "腳臭", head: "ㄐㄧㄠˇ-ㄔㄡˋ")
    let uom = LMAssembly.LMUserOverride(
      capacity: 2,
      decayConstant: Double(halfLife),
      dataURL: nullURL
    )
    observe(who: uom, key: a.key, candidate: a.value, timestamp: nowTimeStamp)
    observe(who: uom, key: b.key, candidate: b.value, timestamp: nowTimeStamp + halfLife * 1)
    observe(who: uom, key: c.key, candidate: c.value, timestamp: nowTimeStamp + halfLife * 2)
    // C is in the list.
    var suggested = uom.getSuggestion(
      key: c.key,
      timestamp: nowTimeStamp + halfLife * 3,
      headReading: c.head
    )
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", c.value)
    // B is in the list.
    suggested = uom.getSuggestion(
      key: b.key,
      timestamp: nowTimeStamp + halfLife * 3.5,
      headReading: b.head
    )
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", b.value)
    // A is purged.
    suggested = uom.getSuggestion(
      key: a.key,
      timestamp: nowTimeStamp + halfLife * 4,
      headReading: a.head
    )
    XCTAssertNotEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", a.value)
    XCTAssert(suggested.candidates.isEmpty)
    // Observe a new pair (D).
    observe(who: uom, key: d.key, candidate: d.value, timestamp: nowTimeStamp + halfLife * 4.5)
    // D is in the list.
    suggested = uom.getSuggestion(
      key: d.key,
      timestamp: nowTimeStamp + halfLife * 5,
      headReading: d.head
    )
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", d.value)
    // C is in the list.
    suggested = uom.getSuggestion(
      key: c.key,
      timestamp: nowTimeStamp + halfLife * 5.5,
      headReading: c.head
    )
    XCTAssertEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", c.value)
    // B is purged.
    suggested = uom.getSuggestion(
      key: b.key,
      timestamp: nowTimeStamp + halfLife * 6,
      headReading: b.head
    )
    XCTAssertNotEqual(Set(suggested.candidates.map(\.1.value)).first ?? "", b.value)
    XCTAssert(suggested.candidates.isEmpty)
  }

  // MARK: Private

  private func observe(
    who uom: LMAssembly.LMUserOverride,
    key: String,
    candidate: String,
    timestamp stamp: Double
  ) {
    uom.doObservation(
      key: key,
      candidate: candidate,
      timestamp: stamp,
      forceHighScoreOverride: false,
      saveCallback: {}
    )
  }
}
