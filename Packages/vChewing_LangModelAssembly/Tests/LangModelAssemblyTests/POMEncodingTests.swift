// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// POM 已徹底重寫，使用與 Lukhnos Liu 和 MJHsieh 完全不同的方法。

// Test file to investigate POM JSON encoding issues

import Foundation
import Megrez
import XCTest

@testable import LangModelAssembly

final class POMEncodingTests: XCTestCase {
  func testJSONEncoding() throws {
    // 創建一個暫存檔案路徑用於測試
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_data.json")
    vCLMLog("測試文件路徑: \(tempURL.path)")

    let pom = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)

    // 測試空數據情況
    vCLMLog("=== 測試空數據情況 ===")
    let emptySavableData = pom.getSavableData()
    vCLMLog("空數據時 getSavableData 返回了 \(emptySavableData.count) 個項目")

    // 嘗試編碼空陣列
    let encoder = JSONEncoder()
    do {
      let emptyJsonData = try encoder.encode(emptySavableData)
      let emptyJsonString = String(data: emptyJsonData, encoding: .utf8) ?? "無法轉換為字串"
      vCLMLog("空數據編碼後的 JSON: '\(emptyJsonString)'")

      // 空陣列應該編碼為 "[]"，不是 "{}"
      XCTAssertEqual(emptyJsonString, "[]", "空陣列應該編碼為 []")
    } catch {
      vCLMLog("編碼空數據失敗: \(error)")
    }

    // 測試保存空數據
    pom.saveData(toURL: tempURL)
    do {
      let emptyFileContent = try String(contentsOf: tempURL, encoding: .utf8)
      vCLMLog("空數據保存後的檔案內容: '\(emptyFileContent)'")

      // 如果檔案內容是 "{}"，那說明有問題
      if emptyFileContent == "{}" {
        vCLMLog("⚠️ 發現問題：空數據保存後檔案內容是 '{}' 而不是期望的 '[]'")
      }
    } catch {
      vCLMLog("讀取空數據檔案失敗: \(error)")
    }

    vCLMLog("\n=== 測試有數據情況 ===")
    // 新增測試數據
    let testData = [
      ("(test1,測試1)&(key,鍵)&(target,target)", "目標1"),
      ("(test2,測試2)&(key,鍵)&(target,target)", "目標2"),
      ("(test3,測試3)&(key,鍵)&(target,target)", "目標3"),
    ]

    let timestamp = Date.now.timeIntervalSince1970

    for (key, candidate) in testData {
      pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: timestamp)
    }

    vCLMLog("已記憶 \(testData.count) 個項目")

    // 檢查 getSavableData 返回什麼
    let savableData = pom.getSavableData()
    vCLMLog("getSavableData 返回了 \(savableData.count) 個項目")

    // 嘗試手動編碼並檢查結果
    encoder.outputFormatting = .prettyPrinted

    do {
      let jsonData = try encoder.encode(savableData)
      let jsonString = String(data: jsonData, encoding: .utf8) ?? "無法轉換為字串"
      // vCLMLog("編碼後的 JSON:")
      // vCLMLog(jsonString)
      // 檢查是否只是 "{}" 或空的
      XCTAssertFalse(jsonString.isEmpty, "JSON 不應該為空")
      XCTAssertNotEqual(jsonString.trimmingCharacters(in: .whitespacesAndNewlines), "{}", "JSON 不應該只是空對象")
      XCTAssertTrue(jsonString.contains("test1"), "JSON 應該包含測試數據")
      let data2 = jsonString.data(using: .utf8) ?? .init([])
      let decoded = try JSONDecoder().decode(
        [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self, from: data2
      )
      XCTAssertEqual(decoded, savableData)
    } catch {
      XCTFail("編碼失敗: \(error)")
    }

    // 測試保存操作
    pom.saveData(toURL: tempURL)

    // 檢查文件內容
    do {
      let fileContent = try String(contentsOf: tempURL, encoding: .utf8)
      vCLMLog("檔案內容:")
      vCLMLog(fileContent)

      XCTAssertFalse(fileContent.isEmpty, "檔案內容不應該為空")
      XCTAssertNotEqual(fileContent.trimmingCharacters(in: .whitespacesAndNewlines), "{}", "檔案內容不應該只是空對象")

    } catch {
      vCLMLog("讀取檔案失敗: \(error)")
    }

    // 清理暫存檔案
    try? FileManager.default.removeItem(at: tempURL)
  }

  func testDataIntegrity() throws {
    // 測試數據完整性 - 確認數據是否真的被正確記憶和檢索
    vCLMLog("=== 測試數據完整性 ===")

    let pom = LMAssembly.LMPerceptionOverride(capacity: 10)

    let testKey = "(test,測試)&(key,鍵)&(target,target)"
    let testCandidate = "目標"
    let timestamp = Date.now.timeIntervalSince1970

    // 記憶數據
    pom.memorizePerception((ngramKey: testKey, candidate: testCandidate), timestamp: timestamp)
    vCLMLog("已記憶: key=\(testKey), candidate=\(testCandidate)")

    // 檢查內部數據結構
    let savableData = pom.getSavableData()
    vCLMLog("getSavableData 返回的項目數: \(savableData.count)")

    for (index, item) in savableData.enumerated() {
      vCLMLog("項目 \(index): key=\(item.key), overrides count=\(item.perception.overrides.count)")
      for (candidate, override) in item.perception.overrides {
        vCLMLog("  候選: \(candidate), count=\(override.count), timestamp=\(override.timestamp)")
      }
    }

    XCTAssertEqual(savableData.count, 1, "應該有一個保存項目")
    XCTAssertEqual(savableData.first?.key, testKey, "保存的 key 應該正確")
    XCTAssertEqual(savableData.first?.perception.overrides.count, 1, "應該有一個 override")
    XCTAssertTrue(savableData.first?.perception.overrides.keys.contains(testCandidate) ?? false, "應該包含測試候選詞")
  }
}
