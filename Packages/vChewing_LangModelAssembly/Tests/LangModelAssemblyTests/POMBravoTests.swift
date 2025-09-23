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

// MARK: - POMBravoTests

final class POMBravoTests: XCTestCase {
  func testBasicAPI() throws {
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)

    // 測試基本功能 - 使用簡單的 key 格式
    let key = "((test,測試),(key,鍵),target)"
    let candidate = "目標"
    let timestamp = Date.now.timeIntervalSince1970

    // 記憶一個候選詞
    pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: timestamp)
    print("記憶候選詞: \(key) -> \(candidate)")

    // 檢索建議
    let suggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
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
    let emptySuggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
    XCTAssertNil(emptySuggestions, "清理後應該沒有建議")

    print("基本 API 測試完成")
  }

  func testActualUseCase() throws {
    let savedPOMData = """
    [{"p":{"ovr":{"凱歌":{"ts":1758988289.311234,"cnt":2}}},"k":"((ㄕˋ,世),(ㄉㄜ˙,的),ㄎㄞˇ-ㄍㄜ)"},{"p":{"ovr":{"世":{"ts":1758988286.926742,"cnt":2}}},"k":"((ㄗㄞˋ,再),(ㄔㄨㄤˋ,創),ㄕˋ)"},{"p":{"ovr":{"創":{"ts":1758988285.2418919,"cnt":1}}},"k":"((),(ㄗㄞˋ,再),ㄔㄨㄤˋ)"},{"p":{"ovr":{"再":{"ts":1758988283.880796,"cnt":1}}},"k":"((),(),ㄗㄞˋ)"},{"p":{"ovr":{"的":{"ts":1758988270.961279,"cnt":1}}},"k":"((ㄔㄨㄤˋ,創),(ㄕˋ,世),ㄉㄜ˙)"}]
    """

    let decoder = JSONDecoder()
    let rawData = try XCTUnwrap(savedPOMData.data(using: .utf8))
    let pairs = try decoder.decode([LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self, from: rawData)

    let instantiator = LMAssembly.LMInstantiator()
    instantiator.lmPerceptionOverride.loadData(from: pairs)

    let sentence: [Megrez.GramInPath] = [
      .init(readingChain: "ㄗㄞˋ", value: "再"),
      .init(readingChain: "ㄔㄨㄤˋ", value: "創"),
      .init(readingChain: "ㄕˋ", value: "世"),
      .init(readingChain: "ㄉㄜ˙", value: "的"),
      .init(readingChain: "ㄎㄞˇ-ㄍㄜ", value: "凱歌", score: -4.5),
    ]

    let queryTimestamp = (pairs.compactMap { pair in
      pair.perception.overrides.values.map(\.timestamp).max()
    }.compactMap { $0 }.max() ?? 0) + 10

    let totalKeyCount = sentence.reduce(0) { $0 + $1.segLength }
    var checkedValues = Set<String>()
    var cursorExpectations: [(cursor: Int, value: String)] = []

    for cursor in 0 ..< totalKeyCount {
      guard let result = sentence.findGramWithRange(at: cursor) else { continue }
      let value = result.node.gram.value
      guard checkedValues.insert(value).inserted else { continue }
      cursorExpectations.append((cursor, value))
    }

    XCTAssertEqual(cursorExpectations.count, 5, "應該為每個節點準備測試資料")

    for expectation in cursorExpectations {
      let suggestions = instantiator.fetchPOMSuggestion(
        currentWalk: sentence,
        cursor: expectation.cursor,
        timestamp: queryTimestamp
      )

      XCTAssertFalse(suggestions.candidates.isEmpty, "游標 \(expectation.cursor) 應該產生建議")
      XCTAssertEqual(
        suggestions.candidates.first?.value,
        expectation.value,
        "游標 \(expectation.cursor) 應該建議 \(expectation.value)"
      )
    }
  }
}

extension Megrez.GramInPath {
  fileprivate init(readingChain: String, value: String, score: Double = -5.0) {
    let keyCells = readingChain.split(separator: "-").map(String.init)
    self.init(
      keyArray: keyCells,
      gram: .init(value: value, score: score),
      isOverridden: false
    )
  }
}
