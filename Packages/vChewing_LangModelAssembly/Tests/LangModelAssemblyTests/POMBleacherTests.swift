// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import LangModelAssembly

extension POMTestSuite {
  @Suite(.serialized)
  struct POMBleacherTests {
    @Test
    func testBleachSpecifiedSuggestions() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let timestamp = Date.now.timeIntervalSince1970

      // 記憶幾個候選詞
      let key1 = "(test1,測試1)&(key,鍵)&(target,目標1)"
      let candidate1 = "目標1"
      pom.memorizePerception((ngramKey: key1, candidate: candidate1), timestamp: timestamp)

      let key2 = "(test2,測試2)&(key,鍵)&(target,目標2)"
      let candidate2 = "目標2"
      pom.memorizePerception((ngramKey: key2, candidate: candidate2), timestamp: timestamp)

      let key3 = "(test3,測試3)&(key,鍵)&(target,目標3)"
      let candidate3 = "目標3"
      pom.memorizePerception((ngramKey: key3, candidate: candidate3), timestamp: timestamp)

      // 檢查是否能獲取建議
      let suggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
      #expect(suggestions1 != nil)
      #expect(suggestions1?.first?.value == candidate1)

      let suggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      #expect(suggestions2 != nil)
      #expect(suggestions2?.first?.value == candidate2)

      let suggestions3 = pom.getSuggestion(key: key3, timestamp: timestamp + 100)
      #expect(suggestions3 != nil)
      #expect(suggestions3?.first?.value == candidate3)

      // 現在清除 candidate2（使用 candidateTargets 移除所有上下文中的該候選詞）
      pom.bleachSpecifiedSuggestions(candidateTargets: [candidate2])

      // key1 和 key3 應該還在
      let afterSuggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
      #expect(afterSuggestions1 != nil)
      #expect(afterSuggestions1?.first?.value == candidate1)

      let afterSuggestions3 = pom.getSuggestion(key: key3, timestamp: timestamp + 100)
      #expect(afterSuggestions3 != nil)
      #expect(afterSuggestions3?.first?.value == candidate3)

      // key2 應該被清除了
      let afterSuggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      #expect(afterSuggestions2 == nil)
    }

    @Test
    func testBleachSpecifiedSuggestionsWithMultipleOverrides() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let timestamp = Date.now.timeIntervalSince1970

      // 為同一個 key 記憶多個候選詞
      let key = "(test,測試)&(key,鍵)&(target,基底)"
      let candidate1 = "目標A"
      let candidate2 = "目標B"
      let candidate3 = "目標C"

      pom.memorizePerception((ngramKey: key, candidate: candidate1), timestamp: timestamp)
      pom.memorizePerception((ngramKey: key, candidate: candidate2), timestamp: timestamp + 10)
      pom.memorizePerception((ngramKey: key, candidate: candidate3), timestamp: timestamp + 20)

      // 檢查是否能獲取建議
      let suggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
      #expect(suggestions != nil)
      #expect(suggestions!.count >= 1)

      // 現在只清除 candidate2（使用 candidateTargets 移除所有上下文中的該候選詞）
      pom.bleachSpecifiedSuggestions(candidateTargets: [candidate2])

      // 驗證修復結果：key 應該還在，但只有 candidate2 被移除
      guard let overrides = pom.mutLRUMap[key]?.perception.overrides else {
        Issue.record("Failed to retrieve overrides for key after bleaching.")
        return
      }
      #expect(!overrides.keys.contains(candidate2))
      #expect(overrides.keys.contains(candidate1))
      #expect(overrides.keys.contains(candidate3))
      #expect(overrides.count == 2)
    }

    @Test
    func testBleachSpecifiedSuggestionsRemovesKeyWhenAllOverridesRemoved() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let timestamp = Date.now.timeIntervalSince1970

      // 為同一個 key 記憶一個候選詞
      let key = "(test,測試)&(key,鍵)&(target,基底)"
      let candidate = "唯一目標"

      pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: timestamp)

      // 檢查是否能獲取建議
      let suggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
      #expect(suggestions != nil)

      // 清除唯一的候選詞（使用 candidateTargets 移除所有上下文中的該候選詞）
      pom.bleachSpecifiedSuggestions(candidateTargets: [candidate])

      // 整個 key 應該被移除了
      #expect(pom.mutLRUMap[key] == nil)

      // 確認無法再獲取建議
      let afterSuggestions = pom.getSuggestion(key: key, timestamp: timestamp + 100)
      #expect(afterSuggestions == nil)
    }

    @Test
    func testBleachSpecifiedSuggestionsWithContextPairs() throws {
      let pom = LMAssembly.LMPerceptionOverride(capacity: 10)
      let timestamp = Date.now.timeIntervalSince1970

      // 記憶同一個候選詞在不同上下文中
      let key1 = "(context1,上下文1)&(test,測試)&(target,共用目標)"
      let key2 = "(context2,上下文2)&(test,測試)&(target,共用目標)"
      let candidate = "共用目標"

      pom.memorizePerception((ngramKey: key1, candidate: candidate), timestamp: timestamp)
      pom.memorizePerception((ngramKey: key2, candidate: candidate), timestamp: timestamp)

      // 檢查兩個上下文都能獲取建議
      let suggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
      #expect(suggestions1 != nil)
      #expect(suggestions1?.first?.value == candidate)

      let suggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      #expect(suggestions2 != nil)
      #expect(suggestions2?.first?.value == candidate)

      // 只清除 key1 的候選詞（使用 context-specific API）
      pom.bleachSpecifiedSuggestions(targets: [(ngramKey: key1, candidate: candidate)])

      // key1 應該被清除了
      let afterSuggestions1 = pom.getSuggestion(key: key1, timestamp: timestamp + 100)
      #expect(afterSuggestions1 == nil)

      // key2 應該還在（因為只清除了特定上下文）
      let afterSuggestions2 = pom.getSuggestion(key: key2, timestamp: timestamp + 100)
      #expect(afterSuggestions2 != nil)
      #expect(afterSuggestions2?.first?.value == candidate)
    }
  }
}
