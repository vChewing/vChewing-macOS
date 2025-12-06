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

final class POMFileHandleTests: XCTestCase {
  func testClearDataFormat() throws {
    // 測試修復後的 clearData 會寫入正確格式
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_fix.json")

    let pom = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)

    // 先添加一些數據
    pom.memorizePerception(
      (ngramKey: "(test,測試)&(key,鍵)&(target,target)", candidate: "目標"),
      timestamp: Date.now.timeIntervalSince1970
    )

    // 驗證數據存在
    let dataBeforeClear = pom.getSavableData()
    XCTAssertEqual(dataBeforeClear.count, 1, "應該有一個項目")

    // 清除數據
    pom.clearData(withURL: tempURL)

    // 檢查文件內容
    do {
      let fileContent = try String(contentsOf: tempURL, encoding: .utf8)
      print("清除後文件內容: '\(fileContent)'")

      XCTAssertEqual(fileContent, "[]", "清除後文件內容應該是空陣列 '[]' 而不是 '{}'")
    } catch {
      XCTFail("無法讀取清除後的文件: \(error)")
    }

    // 驗證內存中的數據也被清除
    let dataAfterClear = pom.getSavableData()
    XCTAssertEqual(dataAfterClear.count, 0, "清除後應該沒有項目")

    // 清理
    try? FileManager.default.removeItem(at: tempURL)
  }

  func testLoadOldFormatFile() throws {
    // 測試加載舊格式 "{}" 文件的處理
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_old_format.json")
    let journalURL = tempURL.appendingPathExtension("journal")

    // 創建舊格式文件
    try "{}".write(to: tempURL, atomically: false, encoding: .utf8)

    let pom = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)

    // 加載舊格式文件（應該被正確處理為空內容）
    pom.loadData(fromURL: tempURL)

    // 驗證內存中沒有數據（因為舊格式被跳過了）
    let dataAfterLoad = pom.getSavableData()
    XCTAssertEqual(dataAfterLoad.count, 0, "加載舊格式文件後應該沒有數據")

    // 現在添加一些新數據並保存，應該會覆蓋舊格式
    pom.memorizePerception(
      (ngramKey: "(new,新)&(data,數據)&(test,test)", candidate: "測試"),
      timestamp: Date.now.timeIntervalSince1970
    )
    pom.saveData(toURL: tempURL)

    // 檢查文件現在是正確的格式
    do {
      let fileContent = try String(contentsOf: tempURL, encoding: .utf8)
      print("保存新數據後文件內容: '\(fileContent.prefix(50))...'")

      XCTAssertFalse(
        fileContent.trimmingCharacters(in: .whitespacesAndNewlines) == "{}",
        "不應該再是舊的 '{}' 格式"
      )

      let data = fileContent.data(using: .utf8) ?? .init()
      let decoded = try JSONDecoder().decode(
        [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self,
        from: data
      )
      XCTAssertLessThanOrEqual(decoded.count, 1)
    } catch {
      print("讀取保存後文件失敗: \(error)")
    }

    // 若快照仍為空，則日誌必須存在並包含變更
    if let snapshot = try? Data(contentsOf: tempURL),
       let decoded = try? JSONDecoder().decode(
         [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self,
         from: snapshot
       ), decoded.isEmpty {
      XCTAssertTrue(FileManager.default.fileExists(atPath: journalURL.path))
      let journalContent = try String(contentsOf: journalURL, encoding: .utf8)
      XCTAssertFalse(journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    let reloaded = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)
    reloaded.loadData(fromURL: tempURL)
    XCTAssertEqual(reloaded.getSavableData().count, 1)

    // 清理
    try? FileManager.default.removeItem(at: tempURL)
    try? FileManager.default.removeItem(at: journalURL)
  }

  func testSaveWithLogging() throws {
    // 測試新的保存日誌功能
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_logging.json")

    let pom = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)

    // 添加測試數據
    let testData = [
      ("(test1,測試1)&(key,鍵)&(target,target)", "目標1"),
      ("(test2,測試2)&(key,鍵)&(target,target)", "目標2"),
    ]

    let timestamp = Date.now.timeIntervalSince1970
    for (key, candidate) in testData {
      pom.memorizePerception((ngramKey: key, candidate: candidate), timestamp: timestamp)
    }

    // 保存數據（會有日誌輸出）
    pom.saveData(toURL: tempURL)

    // 驗證保存成功
    let fileContent = try String(contentsOf: tempURL, encoding: .utf8)
    XCTAssertFalse(fileContent.isEmpty, "保存的文件不應該為空")

    let data = fileContent.data(using: .utf8) ?? .init()
    let decoder = JSONDecoder()
    let decoded = try decoder.decode([LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self, from: data)
    let journalURL = tempURL.appendingPathExtension("journal")
    if decoded.count < testData.count {
      XCTAssertTrue(FileManager.default.fileExists(atPath: journalURL.path))
      let journalContent = try String(contentsOf: journalURL, encoding: .utf8)
      XCTAssertFalse(journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    let pomReloaded = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)
    pomReloaded.loadData(fromURL: tempURL)
    let reloaded = pomReloaded.getSavableData()
    XCTAssertEqual(reloaded.count, testData.count, "重新載入後的項目數應該與原始資料一致")

    // 清理
    try? FileManager.default.removeItem(at: tempURL)
    try? FileManager.default.removeItem(at: journalURL)
  }

  func testJournalReplayKeepsDataConsistency() throws {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_journal.json")
    let journalURL = tempURL.appendingPathExtension("journal")
    defer {
      try? FileManager.default.removeItem(at: tempURL)
      try? FileManager.default.removeItem(at: journalURL)
    }

    let timestamp = Date.now.timeIntervalSince1970

    // 初次保存會產生完整快照
    let pom = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)
    pom.memorizePerception(
      (ngramKey: "(k1,k1)&(k2,k2)&(k3,k3)", candidate: "c1"),
      timestamp: timestamp
    )
    pom.saveData(toURL: tempURL)

    let baseSnapshotAfterFirstSave = try Data(contentsOf: tempURL)
    let decodedAfterFirstSave = try JSONDecoder().decode(
      [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self,
      from: baseSnapshotAfterFirstSave
    )
    XCTAssertEqual(decodedAfterFirstSave.count, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: journalURL.path))

    // 第二次保存會寫入追加式日誌
    pom.memorizePerception(
      (ngramKey: "(k4,k4)&(k5,k5)&(k6,k6)", candidate: "c2"),
      timestamp: timestamp
    )
    pom.saveData(toURL: tempURL)

    // 基礎快照仍保有舊資料，變更被寫入日誌
    let baseSnapshotAfterSecondSave = try Data(contentsOf: tempURL)
    let decodedAfterSecondSave = try JSONDecoder().decode(
      [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self,
      from: baseSnapshotAfterSecondSave
    )
    XCTAssertEqual(decodedAfterSecondSave.count, 1)

    XCTAssertTrue(FileManager.default.fileExists(atPath: journalURL.path))
    let journalContent = try String(contentsOf: journalURL)
    XCTAssertFalse(journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    // 重新載入應能重放日誌並還原到最新狀態
    let pomReloaded = LMAssembly.LMPerceptionOverride(capacity: 10, dataURL: tempURL)
    pomReloaded.loadData(fromURL: tempURL)
    let savableAfterReload = pomReloaded.getSavableData()
    XCTAssertEqual(savableAfterReload.count, 2)
    XCTAssertTrue(savableAfterReload.contains { $0.key.contains("k6") })
  }
}
