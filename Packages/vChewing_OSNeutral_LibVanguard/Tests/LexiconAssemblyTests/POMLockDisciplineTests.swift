// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

extension POMTestSuite {
  /// `PerceptionPersistor` 的鎖恆為**葉鎖**。
  ///
  /// 取鎖期間若呼叫了 `dataProvider`／`mapProvider`／`keyValidator`／`loadCallback`／
  /// `replayApplicator` 這類回呼，而回呼又取 `LXPerceptor` 的鎖，即與 `LXPerceptor` 的持鎖路徑
  /// （`markKeyForUpsert(_:)`／`markKeyForRemoval(_:)`）構成取鎖順序倒置——背景存檔與加詞／濾除
  /// 相撞時永久死鎖。本模組以 `isLockHeld` 探針把該紀律釘成可回歸的斷言。
  @Suite
  final class POMLockDisciplineTests {
    // MARK: Internal

    /// 本套房專屬之儲存後端：資料一律留在記憶體內、不落地，亦不經行程級全域，
    /// 故與其他套房（乃至同一套房之其他測試用例）不共用任何硬碟區域。
    /// 每一測試用例各得一份新的套房實例，故各得一份新的後端。
    let locator = InMemoryUserDataLocator()

    @Test
    func testSaveDataJournalCallbacksRunOutsidePersistorLock() throws {
      let tempURL = makeTempURL("test_pom_lock_discipline_save.json")
      let journalURL = tempURL.appendingPathExtension("journal")
      defer {
        try? locator.remove(at: tempURL)
        try? locator.remove(at: journalURL)
      }
      // 快照檔先存在，`saveData` 才會走「追加日誌」分支而不提前改寫完整快照。
      try locator.write(Data("[]".utf8), to: tempURL)

      let pair = try makePair()
      let persistor = LXAssembly.PerceptionPersistor(baseURL: tempURL, locator: locator)
      persistor.markKeyForUpsert(pair.key)

      var lockHeldDuringMapProvider = false
      var lockHeldDuringKeyValidator = false
      persistor.saveData(
        dataProvider: { [] },
        mapProvider: {
          lockHeldDuringMapProvider = persistor.isLockHeld
          return [pair.key: pair]
        },
        keyValidator: { _ in
          lockHeldDuringKeyValidator = persistor.isLockHeld
          return true
        }
      )

      #expect(!lockHeldDuringMapProvider)
      #expect(!lockHeldDuringKeyValidator)
      // 日誌確實落地，證明上列兩個回呼真的被走過（否則兩個斷言會空轉為真）。
      #expect(locator.exists(at: journalURL))
    }

    @Test
    func testSaveDataSnapshotCallbackRunsOutsidePersistorLock() throws {
      let tempURL = makeTempURL("test_pom_lock_discipline_snapshot.json")
      defer { try? locator.remove(at: tempURL) }

      // 快照檔不存在，故走「改寫完整快照」分支。
      let persistor = LXAssembly.PerceptionPersistor(baseURL: tempURL, locator: locator)

      var lockHeldDuringDataProvider = false
      persistor.saveData(
        dataProvider: {
          lockHeldDuringDataProvider = persistor.isLockHeld
          return []
        },
        mapProvider: { [:] },
        keyValidator: { _ in true }
      )

      #expect(!lockHeldDuringDataProvider)
      #expect(locator.exists(at: tempURL))
    }

    @Test
    func testLoadDataCallbacksRunOutsidePersistorLock() throws {
      let tempURL = makeTempURL("test_pom_lock_discipline_load.json")
      let journalURL = tempURL.appendingPathExtension("journal")
      defer {
        try? locator.remove(at: tempURL)
        try? locator.remove(at: journalURL)
      }

      let pair = try makePair()
      try locator.write(JSONEncoder().encode([pair]), to: tempURL)
      // 日誌記錄的編碼鍵名與 `JournalRecord` 的 Codable 合成結果一致。
      let record: [String: Any] = [
        "operation": "upsert",
        "pair": try JSONSerialization.jsonObject(with: JSONEncoder().encode(pair)),
      ]
      try locator.write(JSONSerialization.data(withJSONObject: record), to: journalURL)

      let persistor = LXAssembly.PerceptionPersistor(baseURL: tempURL, locator: locator)

      var lockHeldDuringLoadCallback = false
      var lockHeldDuringKeyValidator = false
      var lockHeldDuringReplayApplicator = false
      persistor.loadData(
        loadCallback: { _ in lockHeldDuringLoadCallback = persistor.isLockHeld },
        replayApplicator: { _ in lockHeldDuringReplayApplicator = persistor.isLockHeld },
        keyValidator: { _ in
          lockHeldDuringKeyValidator = persistor.isLockHeld
          return true
        },
        fromURL: tempURL
      )

      #expect(!lockHeldDuringLoadCallback)
      #expect(!lockHeldDuringKeyValidator)
      #expect(!lockHeldDuringReplayApplicator)
    }

    // MARK: Private

    private static let key = "(ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華)&(ㄉㄜ˙,的)&(ㄍㄡˇ,狗)"
    /// 合法日誌記錄要求的時間戳下限是「大於零且不超過當下 + 1 小時」，故取一個過去的定值。
    private static let timestamp: Double = 1_145_140_000

    private func makePair() throws -> LXAssembly.LXPerceptor.KeyPerceptionPair {
      let json = #"{"k":"\#(Self.key)","p":{"ovr":{"狗":{"cnt":1,"ts":\#(Self.timestamp)}}}}"#
      return try JSONDecoder().decode(
        LXAssembly.LXPerceptor.KeyPerceptionPair.self,
        from: Data(json.utf8)
      )
    }

    private func makeTempURL(_ name: String) -> URL {
      URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }
  }
}
