// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

extension POMTestSuite {
  @Suite(.serialized)
  final class POMFileHandleTests {
    // MARK: Lifecycle

    init() {
      // 使用者資料一律留在記憶體內：不落地，故不與任何其他測試用例共用硬碟區域。
      LXAssembly.userDataLocator = InMemoryUserDataLocator()
    }

    deinit {
      LXAssembly.userDataLocator = DiskUserDataLocator()
    }

    // MARK: Internal

    @Test
    func testClearDataFormat() throws {
      // 測試修復後的 clearData 會寫入正確格式
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_fix.json")

      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)

      // 先添加一些數據
      pom.memorizePerception(
        (ngramKey: "(test,測試)&(key,鍵)&(target,target)", candidate: "目標"),
        timestamp: Date.now.timeIntervalSince1970
      )

      // 驗證數據存在
      let dataBeforeClear = pom.getSavableData()
      #expect(dataBeforeClear.count == 1)

      // 清除數據
      pom.clearData(withURL: tempURL)

      // 檢查文件內容
      do {
        let fileContent = try LXAssembly.userDataLocator.readText(at: tempURL)
        #expect(fileContent == "[]")
      } catch {
        Issue.record("讀取清除後文件失敗: \(error)")
      }

      // 驗證內存中的數據也被清除
      let dataAfterClear = pom.getSavableData()
      #expect(dataAfterClear.isEmpty)

      // 清理
      try? LXAssembly.userDataLocator.remove(at: tempURL)
    }

    @Test
    func testLoadOldFormatFile() throws {
      // 測試加載舊格式 "{}" 文件的處理
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_old_format.json")
      let journalURL = tempURL.appendingPathExtension("journal")

      // 創建舊格式文件
      try LXAssembly.userDataLocator.write(Data("{}".utf8), to: tempURL)

      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)

      // 加載舊格式文件（應該被正確處理為空內容）
      pom.loadData(fromURL: tempURL)

      // 驗證內存中沒有數據（因為舊格式被跳過了）
      let dataAfterLoad = pom.getSavableData()
      #expect(dataAfterLoad.isEmpty)

      // 現在添加一些新數據並保存，應該會覆蓋舊格式
      pom.memorizePerception(
        (ngramKey: "(new,新)&(data,數據)&(test,test)", candidate: "測試"),
        timestamp: Date.now.timeIntervalSince1970
      )
      pom.saveData(toURL: tempURL)

      // 檢查文件現在是正確的格式
      do {
        let fileContent = try LXAssembly.userDataLocator.readText(at: tempURL)
        #expect(!(fileContent.trimmingCharacters(in: .whitespacesAndNewlines) == "{}"))

        let data = fileContent.data(using: .utf8) ?? .init()
        let decoded = try JSONDecoder().decode(
          [LXAssembly.LXPerceptor.KeyPerceptionPair].self,
          from: data
        )
        #expect(decoded.count <= 1)
      } catch {
        Issue.record("讀取保存後文件失敗: \(error)")
      }

      // 若快照仍為空，則日誌必須存在並包含變更
      if let snapshot = try? LXAssembly.userDataLocator.read(at: tempURL),
         let decoded = try? JSONDecoder().decode(
           [LXAssembly.LXPerceptor.KeyPerceptionPair].self,
           from: snapshot
         ), decoded.isEmpty {
        #expect(LXAssembly.userDataLocator.exists(at: journalURL))
        let journalContent = try LXAssembly.userDataLocator.readText(at: journalURL)
        #expect(!journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      let reloaded = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      reloaded.loadData(fromURL: tempURL)
      #expect(reloaded.getSavableData().count == 1)

      // 清理
      try? LXAssembly.userDataLocator.remove(at: tempURL)
      try? LXAssembly.userDataLocator.remove(at: journalURL)
    }

    @Test
    func testSaveWithLogging() throws {
      // 測試新的保存日誌功能
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_logging.json")

      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)

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
      let fileContent = try LXAssembly.userDataLocator.readText(at: tempURL)
      #expect(!fileContent.isEmpty)

      let data = fileContent.data(using: .utf8) ?? .init()
      let decoder = JSONDecoder()
      let decoded = try decoder.decode([LXAssembly.LXPerceptor.KeyPerceptionPair].self, from: data)
      let journalURL = tempURL.appendingPathExtension("journal")
      if decoded.count < testData.count {
        #expect(LXAssembly.userDataLocator.exists(at: journalURL))
        let journalContent = try LXAssembly.userDataLocator.readText(at: journalURL)
        #expect(!journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      let pomReloaded = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      pomReloaded.loadData(fromURL: tempURL)
      let reloaded = pomReloaded.getSavableData()
      #expect(reloaded.count == testData.count)

      // 清理
      try? LXAssembly.userDataLocator.remove(at: tempURL)
      try? LXAssembly.userDataLocator.remove(at: journalURL)
    }

    @Test
    func testJournalReplayKeepsDataConsistency() throws {
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_journal.json")
      let journalURL = tempURL.appendingPathExtension("journal")
      defer {
        try? LXAssembly.userDataLocator.remove(at: tempURL)
        try? LXAssembly.userDataLocator.remove(at: journalURL)
      }

      let timestamp = Date.now.timeIntervalSince1970

      // 初次保存會產生完整快照
      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      pom.memorizePerception(
        (ngramKey: "(k1,k1)&(k2,k2)&(k3,k3)", candidate: "c1"),
        timestamp: timestamp
      )
      pom.saveData(toURL: tempURL)

      let baseSnapshotAfterFirstSave = try LXAssembly.userDataLocator.read(at: tempURL)
      let decodedAfterFirstSave = try JSONDecoder().decode(
        [LXAssembly.LXPerceptor.KeyPerceptionPair].self,
        from: baseSnapshotAfterFirstSave
      )
      #expect(decodedAfterFirstSave.count == 1)
      #expect(!LXAssembly.userDataLocator.exists(at: journalURL))

      // 第二次保存會寫入追加式日誌
      pom.memorizePerception(
        (ngramKey: "(k4,k4)&(k5,k5)&(k6,k6)", candidate: "c2"),
        timestamp: timestamp
      )
      pom.saveData(toURL: tempURL)

      // 基礎快照仍保有舊資料，變更被寫入日誌
      let baseSnapshotAfterSecondSave = try LXAssembly.userDataLocator.read(at: tempURL)
      let decodedAfterSecondSave = try JSONDecoder().decode(
        [LXAssembly.LXPerceptor.KeyPerceptionPair].self,
        from: baseSnapshotAfterSecondSave
      )
      #expect(decodedAfterSecondSave.count == 1)

      #expect(LXAssembly.userDataLocator.exists(at: journalURL))
      let journalContent = try LXAssembly.userDataLocator.readText(at: journalURL)
      #expect(!journalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

      // 重新載入應能重放日誌並還原到最新狀態
      let pomReloaded = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      pomReloaded.loadData(fromURL: tempURL)
      let savableAfterReload = pomReloaded.getSavableData()
      #expect(savableAfterReload.count == 2)
      #expect(savableAfterReload.contains { $0.key.contains("k6") })
    }

    @Test
    func testJournalReplayIgnoresInvalidEntries() throws {
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_journal_invalid.json")
      let journalURL = tempURL.appendingPathExtension("journal")
      defer {
        try? LXAssembly.userDataLocator.remove(at: tempURL)
        try? LXAssembly.userDataLocator.remove(at: journalURL)
      }

      let now = Date.now.timeIntervalSince1970
      let future = now + 86_400

      // 建立日誌檔案：包含一條合法 upsert，以及多條不合法項目（使用 JSONSerialization 構造以避開轉義問題）
      let validUpsertDict: [String: Any] = [
        "operation": "upsert",
        "pair": [
          "k": "(a,啊)&(b,吧)&(c,此)",
          "p": ["ovr": ["目標": ["cnt": 1, "ts": now]]],
        ],
      ]
      let emptyKeyUpsertDict: [String: Any] = [
        "operation": "upsert",
        "pair": [
          "k": "",
          "p": ["ovr": ["壞": ["cnt": 1, "ts": now]]],
        ],
      ]
      let futureTsUpsertDict: [String: Any] = [
        "operation": "upsert",
        "pair": [
          "k": "(x,欸)&(y,乙)&(z,子)",
          "p": ["ovr": ["未來": ["cnt": 1, "ts": future]]],
        ],
      ]
      let zeroCountUpsertDict: [String: Any] = [
        "operation": "upsert",
        "pair": [
          "k": "(m,目)&(n,哪)&(o,哦)",
          "p": ["ovr": ["零": ["cnt": 0, "ts": now]]],
        ],
      ]
      let validRemoveDict: [String: Any] = ["operation": "removeKey", "key": "(a,啊)&(b,吧)&(c,此)"]

      var lines: [String] = []
      for obj in [validUpsertDict, emptyKeyUpsertDict, futureTsUpsertDict, zeroCountUpsertDict, validRemoveDict] {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        if let s = String(data: data, encoding: .utf8) { lines.append(s) }
      }
      let journalContent = lines.joined(separator: "\n")
      try LXAssembly.userDataLocator.write(Data(journalContent.utf8), to: journalURL)

      // 載入並重播日誌
      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      pom.loadData(fromURL: tempURL)

      // 當日誌中含有不合法記錄時，整個日誌應視為受損並被自動刪除
      #expect(!LXAssembly.userDataLocator.exists(at: journalURL))

      // 最終記憶體應該沒有項目（因為移除了日誌、未應用任何 upsert）
      let savable = pom.getSavableData()
      #expect(savable.isEmpty)
    }

    @Test
    func testCorruptedJournalIsRemoved() throws {
      let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_pom_journal_corrupt.json")
      let journalURL = tempURL.appendingPathExtension("journal")
      defer {
        try? LXAssembly.userDataLocator.remove(at: tempURL)
        try? LXAssembly.userDataLocator.remove(at: journalURL)
      }

      let now = Date.now.timeIntervalSince1970

      // 建立日誌檔案：先一條合法 upsert，再一行明顯的非 JSON 文本
      let validUpsertDict: [String: Any] = [
        "operation": "upsert",
        "pair": [
          "k": "(a,啊)&(b,吧)&(c,此)",
          "p": ["ovr": ["目標": ["cnt": 1, "ts": now]]],
        ],
      ]

      var lines: [String] = []
      let data = try JSONSerialization.data(withJSONObject: validUpsertDict, options: [])
      if let s = String(data: data, encoding: .utf8) { lines.append(s) }
      lines.append("THIS IS NOT JSON")
      let journalContent = lines.joined(separator: "\n")
      try LXAssembly.userDataLocator.write(Data(journalContent.utf8), to: journalURL)

      // 載入並重播日誌
      let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: tempURL)
      pom.loadData(fromURL: tempURL)

      // 應該偵測到損毀並刪除日誌
      #expect(!LXAssembly.userDataLocator.exists(at: journalURL))

      // 並且記憶體應保持空
      let savable = pom.getSavableData()
      #expect(savable.isEmpty)
    }
  }
}
