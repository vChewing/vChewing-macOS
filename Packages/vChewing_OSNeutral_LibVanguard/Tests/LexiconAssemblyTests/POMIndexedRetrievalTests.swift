// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

private let indexedNow: Double = 114_514 * 10_000
private let indexedNullURL = URL(fileURLWithPath: "/dev/null")

private func makeIndexedStagingDirectory() throws -> URL {
  let dir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pom-indexed-\(UUID().uuidString)", isDirectory: true)
  return dir
}

/// 產生一個無上下文（unigram）的生產格式記憶鍵。
private func makeUnigramKey(reading: String, value: String) -> String {
  "()&()&(\(reading),\(value))"
}

/// 產生第 N 個互異的單一漢字（POM 對注音讀音下的候選有「字數 = 段數」之資料守衛，
/// 故單段讀音的測資必須搭配單一漢字候選）。
private func makeDistinctHanzi(_ serial: Int) -> String {
  let scalarValue = 0x4E00 + serial
  guard let scalar = Unicode.Scalar(scalarValue) else { return "字" }
  return String(Character(scalar))
}

// MARK: - POMTestSuite.POMIndexedRetrievalTests

extension POMTestSuite {
  /// 針對漸退記憶（POM）之**檢索索引**與**容量收斂**的迴歸測試。
  ///
  /// 這批測試鎖定兩類曾被實測到的退化：
  /// 1. 日誌重播只把鍵寫進映射、卻沒寫進 LRU 序列，導致容量上限形同虛設，
  ///    記憶量隨每次啟動單調膨脹（使用者連續打字一兩週後愈來愈慢）。
  /// 2. 檢索逐一解析全體記憶鍵（`O(總記憶量)`），使每次敲鍵的成本與累積記憶量成正比。
  @Suite(.serialized)
  final class POMIndexedRetrievalTests {
    // MARK: Lifecycle

    init() {
      // 使用者資料一律留在記憶體內：不落地，故不與任何其他測試用例共用硬碟區域。
      LXAssembly.userDataLocator = InMemoryUserDataLocator()
    }

    deinit {
      LXAssembly.userDataLocator = DiskUserDataLocator()
    }

    // MARK: Internal

    // MARK: - 容量收斂

    /// 逐 session 反覆載入／存檔時，映射與 LRU 序列必須恆保持同構、且不得超出容量。
    @Test
    func testPOM_IndexedRetrieval_01_CapacityConvergesAcrossSessions() throws {
      let stagingDirectory = try makeIndexedStagingDirectory()
      defer { try? LXAssembly.userDataLocator.remove(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let capacity = 50
      let sessions = 8
      let memoriesPerSession = 20
      var loadedCounts: [Int] = []

      for session in 0 ..< sessions {
        let pom = LXAssembly.LXPerceptor(capacity: capacity, dataURL: dataURL)
        pom.loadData(fromURL: dataURL)
        // 載入後即必須落在容量內，且映射與序列同構。
        #expect(pom.mutLRUMap.count <= capacity)
        #expect(pom.mutLRUMap.count == pom.mutLRUKeySeqList.count)
        loadedCounts.append(pom.mutLRUMap.count)

        for offset in 0 ..< memoriesPerSession {
          let serial = session * memoriesPerSession + offset
          let key = makeUnigramKey(reading: "ㄅㄚ", value: "\(serial)")
          pom.memorizePerception((key, "值\(serial)"), timestamp: indexedNow + Double(serial))
        }

        #expect(pom.mutLRUMap.count <= capacity)
        #expect(pom.mutLRUKeySeqList.count == pom.mutLRUMap.count)
        pom.saveData(toURL: dataURL)
      }

      // 記憶量不得隨 session 單調膨脹：第 3 輪起就該停在上限。
      #expect(loadedCounts.allSatisfy { $0 <= capacity })
      #expect(loadedCounts.last == capacity)
    }

    /// 當快照內的記憶量多於現行容量上限時，載入後必須收斂並保持同構。
    @Test
    func testPOM_IndexedRetrieval_02_LoadConvergesWhenCapacityShrinks() throws {
      let stagingDirectory = try makeIndexedStagingDirectory()
      defer { try? LXAssembly.userDataLocator.remove(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      let widePOM = LXAssembly.LXPerceptor(capacity: 40, dataURL: dataURL)
      for serial in 0 ..< 40 {
        let key = makeUnigramKey(reading: "ㄅㄚ", value: "\(serial)")
        widePOM.memorizePerception((key, "值\(serial)"), timestamp: indexedNow + Double(serial))
      }
      #expect(widePOM.mutLRUMap.count == 40)
      widePOM.saveData(toURL: dataURL)

      let narrowPOM = LXAssembly.LXPerceptor(capacity: 7, dataURL: dataURL)
      narrowPOM.loadData(fromURL: dataURL)
      #expect(narrowPOM.mutLRUMap.count == 7)
      #expect(narrowPOM.mutLRUKeySeqList.count == 7)
      // 留下來者必須是最新的那批。
      #expect(narrowPOM.mutLRUMap.keys.contains(makeUnigramKey(reading: "ㄅㄚ", value: "39")))
      #expect(!narrowPOM.mutLRUMap.keys.contains(makeUnigramKey(reading: "ㄅㄚ", value: "0")))
    }

    /// 日誌重播（快照之後的新增鍵）同樣必須進入 LRU 序列並受容量節制。
    @Test
    func testPOM_IndexedRetrieval_03_JournalReplayRespectsCapacity() throws {
      let stagingDirectory = try makeIndexedStagingDirectory()
      defer { try? LXAssembly.userDataLocator.remove(at: stagingDirectory) }
      let dataURL = stagingDirectory.appendingPathComponent("pom.json")

      // 第一個 session：寫入完整快照，再追加日誌。
      let firstPOM = LXAssembly.LXPerceptor(capacity: 12, dataURL: dataURL)
      for serial in 0 ..< 12 {
        let key = makeUnigramKey(reading: "ㄕ", value: "\(serial)")
        firstPOM.memorizePerception((key, "值\(serial)"), timestamp: indexedNow + Double(serial))
      }
      firstPOM.saveData(toURL: dataURL)
      for serial in 12 ..< 24 {
        let key = makeUnigramKey(reading: "ㄨ", value: "\(serial)")
        firstPOM.memorizePerception((key, "值\(serial)"), timestamp: indexedNow + Double(serial))
      }
      firstPOM.saveData(toURL: dataURL)
      #expect(firstPOM.mutLRUMap.count == 12)

      // 第二個 session：載入快照並重播日誌後，仍必須收斂在容量內且同構。
      let secondPOM = LXAssembly.LXPerceptor(capacity: 12, dataURL: dataURL)
      secondPOM.loadData(fromURL: dataURL)
      #expect(secondPOM.mutLRUMap.count == 12)
      #expect(secondPOM.mutLRUKeySeqList.count == secondPOM.mutLRUMap.count)
    }

    // MARK: - 索引檢索之完整性

    /// `.exact` 檢索必須涵蓋映射內所有 head 全等之記憶，不得因索引而漏項。
    @Test
    func testPOM_IndexedRetrieval_04_ExactLookupIsComplete() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 400, dataURL: indexedNullURL)

      // 10 個互異的單段讀音，各配一個專屬候選字。
      let readings = ["ㄕ", "ㄨ", "ㄅㄚ", "ㄇㄚ", "ㄋㄧ", "ㄏㄠ", "ㄊㄧㄢ", "ㄖㄣ", "ㄉㄚ", "ㄒㄧㄠ"]
      let candidates = readings.enumerated().map { makeDistinctHanzi($0.offset) }
      for (index, reading) in readings.enumerated() {
        let value = candidates[index]
        pom.memorizePerception((makeUnigramKey(reading: reading, value: value), value), timestamp: indexedNow)
      }
      // 另外塞入大量 head 不相關的記憶，確保索引不會誤收。
      let noise = (0 ..< 300).map { makeDistinctHanzi(1_000 + $0) }
      for value in noise {
        pom.memorizePerception(
          (makeUnigramKey(reading: "ㄌㄨㄢ", value: value), value),
          timestamp: indexedNow,
          saveCallback: {}
        )
      }
      for (index, reading) in readings.enumerated() {
        let results = pom.perceptionsFor(headReading: reading, timestamp: indexedNow)
        let found = Set(results.map(\.candidate))
        #expect(found == [candidates[index]], "讀音 \(reading) 的檢索結果應恰為其專屬候選")
        #expect(!found.contains(where: { noise.contains($0) }), "索引不得納入 head 不相關的記憶")
      }
    }

    /// `.toneInsensitivePrefix` 檢索必須涵蓋去聲調後 head 全等之記憶。
    @Test
    func testPOM_IndexedRetrieval_05_ToneInsensitiveLookupIsComplete() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 100, dataURL: indexedNullURL)
      // 「ㄕˊ（時）」「ㄕˇ（史）」與「ㄕ（無調）」互為去聲調等價。
      pom.memorizePerception((makeUnigramKey(reading: "ㄕˊ", value: "時"), "時"), timestamp: indexedNow)
      pom.memorizePerception((makeUnigramKey(reading: "ㄕˇ", value: "史"), "史"), timestamp: indexedNow)
      pom.memorizePerception((makeUnigramKey(reading: "ㄨ", value: "我"), "我"), timestamp: indexedNow)

      // 去聲調檢索：應取回「時」「史」，不應取回「我」。
      let tolerant = pom.perceptionsFor(
        headReading: "ㄕ",
        timestamp: indexedNow,
        matchMode: .toneInsensitivePrefix
      )
      #expect(Set(tolerant.map(\.candidate)) == ["時", "史"])

      // 精確檢索：無調的「ㄕ」不應命中帶調的記憶。
      let exact = pom.perceptionsFor(headReading: "ㄕ", timestamp: indexedNow, matchMode: .exact)
      #expect(exact.isEmpty)
    }

    /// 多段 head 於兩種檢索模式下皆不得漏項，且段數不同者不得互相污染。
    @Test
    func testPOM_IndexedRetrieval_06_MultiSegmentHeadsAreIndexedPerSegment() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 100, dataURL: indexedNullURL)
      let key = "()&()&(ㄕˊ-ㄨㄛ,是我)"
      pom.memorizePerception((key, "是我"), timestamp: indexedNow)
      pom.memorizePerception((makeUnigramKey(reading: "ㄕˊ", value: "時"), "時"), timestamp: indexedNow)

      let multi = pom.perceptionsFor(headReading: "ㄕˊ-ㄨㄛ", timestamp: indexedNow, matchMode: .exact)
      #expect(Set(multi.map(\.candidate)) == ["是我"])
      // 單段查詢不得把兩段記憶拉進來（段數守衛）。
      let single = pom.perceptionsFor(headReading: "ㄕˊ", timestamp: indexedNow, matchMode: .exact)
      #expect(Set(single.map(\.candidate)) == ["時"])
    }

    // MARK: - 替代鍵之次序

    /// `alternateKeys` 的輸出次序必須與 LRU 序列一致（維持逐鍵走訪時代的先後語義）。
    @Test
    func testPOM_IndexedRetrieval_07_AlternateKeysFollowLRUOrder() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 100, dataURL: indexedNullURL)
      // 全部以兩段 head 開頭，使其成為「ㄕˊ-ㄨㄛ」的替代鍵候選。
      for serial in 0 ..< 8 {
        let key = "()&()&(ㄕˊ-ㄨㄛ,值\(serial))"
        pom.memorizePerception((key, "值\(serial)"), timestamp: indexedNow + Double(serial))
      }
      let query = "()&()&(ㄕˊ,值\(0))"
      let alternates = pom.alternateKeysForTesting(query)
      let matchedSet = Set(alternates)
      // 結果必須是 LRU 序列在「合格鍵集合」上的子序列。
      let expectedOrder = pom.mutLRUKeySeqList.filter { matchedSet.contains($0) }
      #expect(alternates == expectedOrder)
      #expect(!alternates.isEmpty)
    }

    /// 逐出記憶時必須同時自索引除名，否則會撈到已不存在的鍵。
    @Test
    func testPOM_IndexedRetrieval_08_EvictedMemoriesLeaveTheIndex() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 3, dataURL: indexedNullURL)
      let readings = ["ㄕ", "ㄨ", "ㄅㄚ", "ㄇㄚ", "ㄋㄧ"]
      let values = readings.indices.map { makeDistinctHanzi($0) }
      for (index, reading) in readings.prefix(3).enumerated() {
        pom.memorizePerception(
          (makeUnigramKey(reading: reading, value: values[index]), values[index]),
          timestamp: indexedNow
        )
      }
      // 再塞兩筆，逐出最舊的「ㄕ」「ㄨ」。
      for index in 3 ..< 5 {
        pom.memorizePerception(
          (makeUnigramKey(reading: readings[index], value: values[index]), values[index]),
          timestamp: indexedNow
        )
      }
      #expect(pom.mutLRUMap.count == 3)
      #expect(pom.perceptionsFor(headReading: "ㄕ", timestamp: indexedNow).isEmpty)
      #expect(pom.perceptionsFor(headReading: "ㄨ", timestamp: indexedNow).isEmpty)
      #expect(
        Set(pom.perceptionsFor(headReading: "ㄇㄚ", timestamp: indexedNow).map(\.candidate)) == [values[3]]
      )
    }

    // MARK: - 檢索成本不得隨記憶量線性膨脹

    /// 檢索成本必須與記憶總量脫鉤：海量不相關記憶之下的單次檢索仍須為常數級。
    ///
    /// 本測試為**變異測試之判準**：把索引改回「逐鍵解析全表掃描」時，這裡的量測
    /// 會由微秒級退化為毫秒級（`O(總記憶量)`），因而超時而轉紅。
    @Test
    func testPOM_IndexedRetrieval_09_LookupCostDoesNotScaleWithMemorySize() throws {
      let pom = LXAssembly.LXPerceptor(capacity: 6_000, dataURL: indexedNullURL)
      for serial in 0 ..< 5_000 {
        let key = makeUnigramKey(reading: "ㄌㄨㄢ", value: "雜\(serial)")
        pom.memorizePerception(
          (key, "雜\(serial)"),
          timestamp: indexedNow,
          saveCallback: {}
        )
      }
      #expect(pom.mutLRUMap.count == 5_000)
      // 查詢用的記憶置於最後，確保它一定在映射內。
      let target = makeUnigramKey(reading: "ㄒㄧㄠ", value: "笑")
      pom.memorizePerception((target, "笑"), timestamp: indexedNow, saveCallback: {})

      let iterations = 100
      let clock = ContinuousClock()
      let elapsed = clock.measure {
        for _ in 0 ..< iterations {
          _ = pom.perceptionsFor(headReading: "ㄒㄧㄠ", timestamp: indexedNow)
        }
      }
      // 5,000 筆記憶下、100 次檢索的寬鬆上限（現行實作約為數百微秒；
      // 全表掃描則需數百毫秒）。
      #expect(elapsed < .milliseconds(120), "單次檢索成本疑似隨記憶總量線性膨脹：\(elapsed)")
    }
  }
}
