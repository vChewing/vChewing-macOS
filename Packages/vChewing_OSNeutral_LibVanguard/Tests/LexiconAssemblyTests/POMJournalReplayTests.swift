// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

private let replayNow: Double = 114_514 * 10_000

private func makeReplayStagingDirectory() throws -> URL {
  let dir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pom-journal-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

/// 產生一個無上下文（unigram）的生產格式記憶鍵。
private func makeReplayUnigramKey(reading: String, value: String) -> String {
  "()&()&(\(reading),\(value))"
}

/// 以 JSON 造出一個 `KeyPerceptionPair`，模擬日誌記錄裡承載的配對內容。
private func makeReplayPair(
  key: String,
  candidate: String,
  timestamp: Double = replayNow
) throws
  -> LXAssembly.LXPerceptor.KeyPerceptionPair {
  let json = #"{"k":"\#(key)","p":{"ovr":{"\#(candidate)":{"cnt":1,"ts":\#(timestamp)}}}}"#
  return try JSONDecoder().decode(
    LXAssembly.LXPerceptor.KeyPerceptionPair.self,
    from: Data(json.utf8)
  )
}

/// 把一組日誌記錄逐行寫成日誌檔（檔名 = 快照檔名再加 `.journal`）。
private func writeReplayJournal(_ records: [[String: Any]], to baseURL: URL) throws {
  let lines: [String] = try records.map { record in
    let data = try JSONSerialization.data(withJSONObject: record)
    return String(decoding: data, as: UTF8.self)
  }
  let journalURL = baseURL.appendingPathExtension("journal")
  try lines.joined(separator: "\n").write(to: journalURL, atomically: true, encoding: .utf8)
}

/// 把一組配對寫成快照檔。
private func writeReplaySnapshot(
  _ pairs: [LXAssembly.LXPerceptor.KeyPerceptionPair],
  to baseURL: URL
) throws {
  try JSONEncoder().encode(pairs).write(to: baseURL, options: .atomic)
}

// MARK: - POMTestSuite.POMJournalReplayTests

extension POMTestSuite {
  /// 針對漸退記憶（POM）之日誌重播語義的迴歸測試。
  ///
  /// 這批測試鎖定一類曾被實測到的退化：`replayJournal` 以「映射中的空值」表達移除，
  /// 而字典無從區分「未提及此鍵」與「此鍵已移除」，故移除與清空記錄全數於重播時丟失，
  /// 被 bleach 或逐出的鍵於是自快照復活。
  @Suite(.serialized)
  final class POMJournalReplayTests {
    // MARK: - 移除與清空

    /// 日誌記載的移除必須生效：快照裡有、日誌裡被移除的鍵，重載後不得復活。
    @Test
    func testPOM_JournalReplay_01_RemovalRecordIsApplied() throws {
      let stagingDirectory = try makeReplayStagingDirectory()
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let keyA = makeReplayUnigramKey(reading: "ㄅㄚ", value: "芭")
      let keyB = makeReplayUnigramKey(reading: "ㄆㄚ", value: "趴")
      try writeReplaySnapshot(
        [
          try makeReplayPair(key: keyA, candidate: "芭"),
          try makeReplayPair(key: keyB, candidate: "趴"),
        ],
        to: dataURL
      )
      try writeReplayJournal([["operation": "removeKey", "key": keyB]], to: dataURL)

      let pom = LXAssembly.LXPerceptor(capacity: 16, dataURL: dataURL)
      pom.loadData(fromURL: dataURL)

      #expect(pom.mutLRUMap.keys.contains(keyA))
      #expect(!pom.mutLRUMap.keys.contains(keyB))
      #expect(pom.mutLRUMap.count == pom.mutLRUKeySeqList.count)
    }

    /// 日誌記載的清空必須生效，且清空之後的記錄仍然有效。
    @Test
    func testPOM_JournalReplay_02_ClearRecordIsApplied() throws {
      let stagingDirectory = try makeReplayStagingDirectory()
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let keyA = makeReplayUnigramKey(reading: "ㄅㄚ", value: "芭")
      let keyB = makeReplayUnigramKey(reading: "ㄆㄚ", value: "趴")
      let keyC = makeReplayUnigramKey(reading: "ㄇㄚ", value: "媽")
      let pairC = try makeReplayPair(key: keyC, candidate: "媽")
      try writeReplaySnapshot(
        [
          try makeReplayPair(key: keyA, candidate: "芭"),
          try makeReplayPair(key: keyB, candidate: "趴"),
        ],
        to: dataURL
      )
      try writeReplayJournal(
        [
          ["operation": "clear"],
          [
            "operation": "upsert",
            "pair": try JSONSerialization.jsonObject(with: JSONEncoder().encode(pairC)),
          ],
        ],
        to: dataURL
      )

      let pom = LXAssembly.LXPerceptor(capacity: 16, dataURL: dataURL)
      pom.loadData(fromURL: dataURL)

      #expect(pom.mutLRUMap.keys.sorted() == [keyC])
      #expect(pom.mutLRUKeySeqList.count == 1)
    }

    /// 同一鍵在日誌中先後出現時，必須以後者為準。
    @Test
    func testPOM_JournalReplay_03_RecordOrderIsHonored() throws {
      let stagingDirectory = try makeReplayStagingDirectory()
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let keyA = makeReplayUnigramKey(reading: "ㄅㄚ", value: "芭")
      let keyB = makeReplayUnigramKey(reading: "ㄆㄚ", value: "趴")
      let pairA = try makeReplayPair(key: keyA, candidate: "芭", timestamp: replayNow + 10)
      let pairB = try makeReplayPair(key: keyB, candidate: "趴", timestamp: replayNow + 11)
      try writeReplaySnapshot([pairA], to: dataURL)
      // A 先被移除，再被重新記起 ⇒ 最終應存在；B 先被記起，再被移除 ⇒ 最終應不存在。
      try writeReplayJournal(
        [
          ["operation": "removeKey", "key": keyA],
          [
            "operation": "upsert",
            "pair": try JSONSerialization.jsonObject(with: JSONEncoder().encode(pairA)),
          ],
          [
            "operation": "upsert",
            "pair": try JSONSerialization.jsonObject(with: JSONEncoder().encode(pairB)),
          ],
          ["operation": "removeKey", "key": keyB],
        ],
        to: dataURL
      )

      let pom = LXAssembly.LXPerceptor(capacity: 16, dataURL: dataURL)
      pom.loadData(fromURL: dataURL)

      #expect(pom.mutLRUMap.keys.sorted() == [keyA])
      #expect(pom.mutLRUMap.count == pom.mutLRUKeySeqList.count)
    }

    // MARK: - 經真實標記路徑的移除

    /// 走真實的 bleach 路徑所產生的移除，也必須存活到重新啟動之後。
    ///
    /// 此案同時鎖定標記層的節流：`markKeyForRemoval` 若因「同一鍵兩秒內剛被標記過」
    /// 而丟棄該移除，則該鍵仍留在快照裡、重啟即復活。
    @Test
    func testPOM_JournalReplay_04_BleachRemovalSurvivesReload() throws {
      let stagingDirectory = try makeReplayStagingDirectory()
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let keyA = makeReplayUnigramKey(reading: "ㄅㄚ", value: "芭")
      let candidateA = "芭"

      let pom = LXAssembly.LXPerceptor(capacity: 16, dataURL: dataURL)
      pom.memorizePerception((keyA, candidateA), timestamp: replayNow)
      #expect(pom.mutLRUMap.count == 1)

      pom.bleachSpecifiedSuggestions(targets: [(ngramKey: keyA, candidate: candidateA)])
      #expect(pom.mutLRUMap.isEmpty)

      let reloaded = LXAssembly.LXPerceptor(capacity: 16, dataURL: dataURL)
      reloaded.loadData(fromURL: dataURL)
      #expect(reloaded.mutLRUMap.isEmpty)
    }

    // MARK: - 交予呼叫端的變化流

    /// 持久化層交出的變化流必須是有序的，且移除與清空皆須在列。
    @Test
    func testPOM_JournalReplay_05_ChangeStreamCarriesRemovalsAndClears() throws {
      let stagingDirectory = try makeReplayStagingDirectory()
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let keyA = makeReplayUnigramKey(reading: "ㄅㄚ", value: "芭")
      let keyB = makeReplayUnigramKey(reading: "ㄆㄚ", value: "趴")
      let keyC = makeReplayUnigramKey(reading: "ㄇㄚ", value: "媽")
      let pairA = try makeReplayPair(key: keyA, candidate: "芭")
      let pairB = try makeReplayPair(key: keyB, candidate: "趴")
      let pairC = try makeReplayPair(key: keyC, candidate: "媽")
      let jsonOf: (LXAssembly.LXPerceptor.KeyPerceptionPair) throws -> Any = {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode($0))
      }
      try writeReplaySnapshot([pairA], to: dataURL)

      var captured: [LXAssembly.PerceptionPersistor.JournalChange] = []
      let persistor = LXAssembly.PerceptionPersistor(baseURL: dataURL)

      // 第一輪：移除 A、記起 B。變化流必須照此序交付。
      try writeReplayJournal(
        [
          ["operation": "removeKey", "key": keyA],
          ["operation": "upsert", "pair": try jsonOf(pairB)],
        ],
        to: dataURL
      )
      persistor.loadData(
        loadCallback: { _ in },
        replayApplicator: { captured = $0 },
        keyValidator: { _ in true },
        fromURL: dataURL
      )
      try #require(captured.count == 2)
      if case let .remove(key) = captured[0] {
        #expect(key == keyA)
      } else {
        Issue.record("變化流首筆應為移除記錄。")
      }
      if case let .upsert(pair) = captured[1] {
        #expect(pair.key == keyB)
      } else {
        Issue.record("變化流次筆應為新增記錄。")
      }

      // 第二輪：記起 C、清空、再記起 B。清空之前的變化全數作廢，但仍須交付清空本身。
      try writeReplayJournal(
        [
          ["operation": "upsert", "pair": try jsonOf(pairC)],
          ["operation": "clear"],
          ["operation": "upsert", "pair": try jsonOf(pairB)],
        ],
        to: dataURL
      )
      captured = []
      persistor.loadData(
        loadCallback: { _ in },
        replayApplicator: { captured = $0 },
        keyValidator: { _ in true },
        fromURL: dataURL
      )
      try #require(captured.count == 2)
      if case .clear = captured[0] {
        #expect(true)
      } else {
        Issue.record("變化流首筆應為清空。")
      }
      if case let .upsert(pair) = captured[1] {
        #expect(pair.key == keyB)
      } else {
        Issue.record("變化流次筆應為新增記錄。")
      }
    }
  }
}
