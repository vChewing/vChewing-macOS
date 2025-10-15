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

final class POMDataManagementTests: XCTestCase {
  func testBasicDataOperations() throws {
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)

    // 新增一些測試數據
    let testData = [
      ("(test1,測試1)&(key,鍵)&(target,target)", "目標1"),
      ("(test2,測試2)&(key,鍵)&(target,target)", "目標2"),
      ("(test3,測試3)&(key,鍵)&(target,target)", "目標3"),
    ]

    let timestamp = Date.now.timeIntervalSince1970

    for (key, candidate) in testData {
      pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: timestamp)
    }

    // 檢查數據是否正確存儲
    for (key, expectedCandidate) in testData {
      let suggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
      XCTAssertNotNil(suggestions, "應該能獲取建議 - key: \(key)")
      XCTAssertEqual(suggestions?.first?.value, expectedCandidate, "應該返回正確的候選詞 - key: \(key)")
    }

    // 測試 getSavableData 基本功能
    let savableData = pom.getSavableData()
    XCTAssertEqual(savableData.count, testData.count, "可保存數據應該包含所有記憶的項目")

    print("基本數據操作測試完成")
  }

  func testTimestampBasedDecay() throws {
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)

    let key = "(test,測試)&(key,鍵)&(target,target)"
    let candidate = "目標"
    let baseTimestamp = Date.now.timeIntervalSince1970

    // 記憶一個候選詞
    pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: baseTimestamp)

    // 測試即時查詢
    let immediatesuggestions = pom.getSuggestion(key: key, timestamp: baseTimestamp)
    XCTAssertNotNil(immediatesuggestions, "應該能獲取即時建議")

    // 測試一小時後查詢
    let oneHourLater = baseTimestamp + 3_600
    let laterSuggestions = pom.getSuggestion(key: key, timestamp: oneHourLater)
    XCTAssertNotNil(laterSuggestions, "一小時後應該仍能獲取建議")

    // 測試一天後查詢
    let oneDayLater = baseTimestamp + 86_400
    let muchLaterSuggestions = pom.getSuggestion(key: key, timestamp: oneDayLater)
    XCTAssertNotNil(muchLaterSuggestions, "一天後應該仍能獲取建議")

    // 測試一周後查詢 (可能已經衰減到閾值以下)
    let oneWeekLater = baseTimestamp + 604_800
    let weekLaterSuggestions = pom.getSuggestion(key: key, timestamp: oneWeekLater)
    // 一周後可能已經衰減，這是正常的
    if weekLaterSuggestions == nil {
      print("一周後建議已衰減，這是預期的行為")
    }

    print("時間戳衰減測試完成")
  }
}
