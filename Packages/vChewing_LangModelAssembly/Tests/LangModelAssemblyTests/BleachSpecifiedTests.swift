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

final class BleachSpecifiedTests: XCTestCase {
  func testBleachSpecifiedSuggestions() throws {
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
    let timestamp = Date.now.timeIntervalSince1970
    
    // 記憶幾個候選詞
    let key1 = "((test1,測試1),(key,鍵),target)"
    let candidate1 = "目標1"
    pom.memorizePerception((ngramKey: key1, candidate: candidate1), timestamp: timestamp)
    
    let key2 = "((test2,測試2),(key,鍵),target)"
    let candidate2 = "目標2"
    pom.memorizePerception((ngramKey: key2, candidate: candidate2), timestamp: timestamp)
    
    let key3 = "((test3,測試3),(key,鍵),target)"
    let candidate3 = "目標3"
    pom.memorizePerception((ngramKey: key3, candidate: candidate3), timestamp: timestamp)
    
    // 檢查是否能獲取建議
    let suggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
    XCTAssertNotNil(suggestions1, "應該能獲取 key1 的建議")
    XCTAssertEqual(suggestions1?.first?.value, candidate1)
    
    let suggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
    XCTAssertNotNil(suggestions2, "應該能獲取 key2 的建議")
    XCTAssertEqual(suggestions2?.first?.value, candidate2)
    
    let suggestions3 = pom.getSuggestion(key: key3, timestamp: timestamp + 100)
    XCTAssertNotNil(suggestions3, "應該能獲取 key3 的建議")
    XCTAssertEqual(suggestions3?.first?.value, candidate3)
    
    // 現在清除 candidate2
    print("Before bleach - mutLRUMap keys: \(pom.mutLRUMap.keys)")
    print("Before bleach - mutLRUMap count: \(pom.mutLRUMap.count)")
    for (key, pair) in pom.mutLRUMap {
      print("Key: \(key), Perception overrides: \(pair.perception.overrides.keys)")
    }
    
    pom.bleachSpecifiedSuggestions(targets: [candidate2])
    
    print("After bleach - mutLRUMap keys: \(pom.mutLRUMap.keys)")
    print("After bleach - mutLRUMap count: \(pom.mutLRUMap.count)")
    for (key, pair) in pom.mutLRUMap {
      print("Key: \(key), Perception overrides: \(pair.perception.overrides.keys)")
    }
    
    // key1 和 key3 應該還在
    let afterSuggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
    XCTAssertNotNil(afterSuggestions1, "清除後應該還能獲取 key1 的建議")
    XCTAssertEqual(afterSuggestions1?.first?.value, candidate1)
    
    let afterSuggestions3 = pom.getSuggestion(key: key3, timestamp: timestamp + 100)
    XCTAssertNotNil(afterSuggestions3, "清除後應該還能獲取 key3 的建議")
    XCTAssertEqual(afterSuggestions3?.first?.value, candidate3)
    
    // key2 應該被清除了
    let afterSuggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
    XCTAssertNil(afterSuggestions2, "清除後應該無法獲取 key2 的建議")
  }
  
  func testBleachSpecifiedSuggestionsWithMultipleOverrides() throws {
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
    let timestamp = Date.now.timeIntervalSince1970
    
    // 為同一個 key 記憶多個候選詞
    let key = "((test,測試),(key,鍵),target)"
    let candidate1 = "目標A"
    let candidate2 = "目標B"
    let candidate3 = "目標C"
    
    pom.memorizePerception((ngramKey: key, candidate: candidate1), timestamp: timestamp)
    pom.memorizePerception((ngramKey: key, candidate: candidate2), timestamp: timestamp + 10)
    pom.memorizePerception((ngramKey: key, candidate: candidate3), timestamp: timestamp + 20)
    
    // 檢查是否能獲取建議
    let suggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
    XCTAssertNotNil(suggestions, "應該能獲取建議")
    XCTAssertTrue(suggestions!.count >= 1, "應該有至少一個建議")
    
    if let overrideKeys = pom.mutLRUMap[key]?.perception.overrides.keys {
      print("Before bleach - Perception overrides for key '\(key)': \(Array(overrideKeys))")
    }
    
    // 現在只清除 candidate2
    pom.bleachSpecifiedSuggestions(targets: [candidate2])
    
    if let overrideKeys = pom.mutLRUMap[key]?.perception.overrides.keys {
      print("After bleach - Perception overrides for key '\(key)': \(Array(overrideKeys))")
    } else {
      print("After bleach - key '\(key)' no longer exists in mutLRUMap")
    }
    
    // 整個 key 是否被刪除了？
    if pom.mutLRUMap[key] == nil {
      print("整個 key 被刪除了（這可能是問題所在）")
      XCTFail("清除單個候選詞不應該刪除整個 key，如果還有其他候選詞的話")
    } else {
      print("key 還在，檢查 overrides")
      let overrides = pom.mutLRUMap[key]!.perception.overrides
      XCTAssertFalse(overrides.keys.contains(candidate2), "candidate2 應該被刪除")
      // 如果邏輯正確，candidate1 和 candidate3 應該還在
      // 但當前實現可能會刪除整個 key
    }
  }
}
