// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import SwiftExtension

// MARK: - LMAssembly.PerceptionPersistor

extension LMAssembly {
  /// 負責 POM（Perception Override Model）資料的磁碟持久化：
  /// JSON 快照、追加式 WAL 日誌、CRC32 去重與日誌壓縮。
  ///
  /// `LMPerceptionOverride` 專注觀測邏輯；本類別專注 I/O。
  nonisolated public final class PerceptionPersistor {
    // MARK: Lifecycle

    public init(baseURL: URL? = nil) {
      self.fileSaveLocationURL = baseURL
      self.previouslySavedHash = ""
    }

    // MARK: Public

    /// 設定或覆蓋儲存路徑。
    public var fileSaveLocationURL: URL?

    // MARK: Internal

    /// 記錄最近一次快照的雜湊值（hex string），以避免重複寫入。
    var previouslySavedHash: String

    // MARK: Private

    /// 純以筆數判斷是否需要壓縮日誌的門檻。
    private static let journalCompactionEntryThreshold = 120
    /// 當日誌檔案大小超過此值便會重新輸出快照。
    private static let journalCompactionSizeThreshold: UInt64 = 64 * 1_024
    /// 每鍵限制的時間窗（秒）。在此時間內相同 key 的日誌不會被重複加入。
    private static let perKeyThrottleInterval: TimeInterval = 2.0

    /// 下一次刷新時必須寫入日誌的鍵值集合。
    private var pendingUpsertKeys: Set<String> = []
    /// 下一次刷新時需要從日誌移除的鍵值集合。
    private var pendingRemovedKeys: Set<String> = []
    /// 用來判斷是否需要執行日誌壓縮的計數器。
    private var journalEntriesSinceLastCompaction: Int = 0
    /// 指示下一次儲存需要輸出完整快照而非增量日誌。
    private var needsFullSnapshot = false
    /// 記錄每個鍵上次被標記（queued）或寫入的時間戳（Unix time interval）。僅存在於記憶體中。
    private var lastLogTimestampByKey: [String: TimeInterval] = [:]
    /// 用於保護持久化可變狀態的鎖，確保執行緒安全。
    private let lock = NSLock()
  }
}

// MARK: - Journal Record Types

extension LMAssembly.PerceptionPersistor {
  nonisolated private enum JournalOperation: String, Codable {
    case upsert
    case removeKey
    case clear
  }

  nonisolated private struct JournalRecord: Codable {
    // MARK: Lifecycle

    init(
      operation: JournalOperation,
      key: String? = nil,
      pair: LMAssembly.LMPerceptionOverride.KeyPerceptionPair? = nil
    ) {
      self.operation = operation
      self.key = key
      self.pair = pair
    }

    // MARK: Internal

    var operation: JournalOperation
    var key: String?
    var pair: LMAssembly.LMPerceptionOverride.KeyPerceptionPair?
  }
}

// MARK: - Pending Key Tracking (called by LMPerceptionOverride under its lock)

extension LMAssembly.PerceptionPersistor {
  /// 標記某鍵值需在下一次刷新時寫入日誌。
  nonisolated func markKeyForUpsert(_ key: String) {
    lock.withLock {
      pendingRemovedKeys.remove(key)
      let now = Date().timeIntervalSince1970
      if let last = lastLogTimestampByKey[key], now - last < Self.perKeyThrottleInterval {
        return
      }
      pendingUpsertKeys.insert(key)
      lastLogTimestampByKey[key] = now
    }
  }

  /// 標記某鍵值已刪除，讓變更能寫入磁碟。
  nonisolated func markKeyForRemoval(_ key: String) {
    lock.withLock {
      pendingUpsertKeys.remove(key)
      let now = Date().timeIntervalSince1970
      if let last = lastLogTimestampByKey[key], now - last < Self.perKeyThrottleInterval {
        return
      }
      pendingRemovedKeys.insert(key)
      lastLogTimestampByKey[key] = now
    }
  }

  /// 重置日誌追蹤狀態（記憶體清空時呼叫）。
  nonisolated func resetPendingState() {
    lock.withLock {
      pendingUpsertKeys.removeAll()
      pendingRemovedKeys.removeAll()
      journalEntriesSinceLastCompaction = 0
      needsFullSnapshot = true
      previouslySavedHash = ""
    }
  }
}

// MARK: - Save / Load / Clear

extension LMAssembly.PerceptionPersistor {
  /// 透過追加式日誌或完整快照將變更後的覆寫資料寫回磁碟。
  /// - Parameters:
  ///   - dataProvider: 回呼取得目前待存檔的資料。
  ///   - mapProvider: 回呼取得目前的 LRU map（用於組裝 journal records）。
  ///   - keyValidator: 回呼判斷某 key 是否應被忽略。
  ///   - fileURL: 可選的儲存路徑，覆寫預設位置。
  nonisolated func saveData(
    dataProvider: () -> [LMAssembly.LMPerceptionOverride.KeyPerceptionPair],
    mapProvider: () -> [String: LMAssembly.LMPerceptionOverride.KeyPerceptionPair],
    keyValidator: (String) -> Bool,
    toURL fileURL: URL? = nil
  ) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM saveData() failed. At least the file Save URL is not set for the current POM.")
      return
    }

    let fileManager = FileManager.default
    lock.withLock {
      if !fileManager.fileExists(atPath: fileURL.path) {
        needsFullSnapshot = true
      }
    }

    let shouldDoFullSnapshot = lock.withLock { needsFullSnapshot }
    if shouldDoFullSnapshot {
      do {
        try writeFullSnapshot(dataProvider: dataProvider, to: fileURL, force: true)
      } catch {
        vCLMLog("POM Error: Unable to write full snapshot. Details: \(error)")
      }
      return
    }

    let records: [JournalRecord] = lock.withLock {
      preparePendingJournalRecords(mapProvider: mapProvider, keyValidator: keyValidator)
    }
    guard !records.isEmpty else {
      vCLMLog("POM Skip: No pending journal entries to flush.")
      return
    }

    do {
      try appendJournal(records, baseURL: fileURL)

      lock.withLock {
        pendingUpsertKeys.removeAll()
        pendingRemovedKeys.removeAll()
        journalEntriesSinceLastCompaction += records.count
      }

      if lock.withLock({ shouldCompactJournal(for: fileURL) }) {
        try writeFullSnapshot(dataProvider: dataProvider, to: fileURL, force: false)
      }
    } catch {
      vCLMLog("POM Error: Unable to append journal. Details: \(error)")
    }
  }

  /// 從磁碟載入覆寫資料並重播未處理的日誌。
  /// - Parameters:
  ///   - loadCallback: 回呼，將解碼後的資料載入 POM 記憶體。
  ///   - keyValidator: 回呼判斷某 key 是否應被忽略。
  ///   - fileURL: 可選的載入路徑。
  nonisolated func loadData(
    loadCallback: ([LMAssembly.LMPerceptionOverride.KeyPerceptionPair]) -> (),
    replayApplicator: (inout [String: LMAssembly.LMPerceptionOverride.KeyPerceptionPair], inout Bool) -> () = { _, _ in
    },
    keyValidator: @escaping (String) -> Bool,
    fromURL fileURL: URL? = nil
  ) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM loadData() failed. At least the file Load URL is not set for the current POM.")
      return
    }
    let fileManager = FileManager.default
    let decoder = JSONDecoder()

    if fileManager.fileExists(atPath: fileURL.path) {
      do {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let dataString = String(data: data, encoding: .utf8) ?? ""
        vCLMLog("POM: Loading data from snapshot, content: '\(dataString.prefix(100))...'")

        let trimmed = dataString.trimmingCharacters(in: .whitespacesAndNewlines)
        let emptyContents = ["", "{}", "[]"]
        if !emptyContents.contains(trimmed) {
          let jsonResult = try decoder.decode(
            [LMAssembly.LMPerceptionOverride.KeyPerceptionPair].self, from: data
          )
          vCLMLog("POM: Successfully decoded \(jsonResult.count) items from snapshot")
          loadCallback(jsonResult)
        } else {
          if trimmed == "{}" {
            vCLMLog("POM: Detected legacy '{}' snapshot, clearing storage")
            clearDataOnDisk(fileURL: fileURL, dataProvider: { [] })
          } else {
            vCLMLog("POM: Snapshot empty, proceeding to journal replay only")
          }
        }
      } catch {
        vCLMLog("POM Error: Unable to decode snapshot JSON. Details: \(error)")
        if let data = try? String(contentsOf: fileURL, encoding: .utf8),
           data.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
          vCLMLog("POM: Detected old invalid format '{}', clearing snapshot")
          clearDataOnDisk(fileURL: fileURL, dataProvider: { [] })
        }
      }
    }

    replayJournal(from: fileURL, keyValidator: keyValidator, replayApplicator: replayApplicator)

    if let snapshotData = try? Data(contentsOf: fileURL) {
      previouslySavedHash = computeHexCRC32(snapshotData)
    } else {
      previouslySavedHash = ""
    }
  }

  /// 清除磁碟上的快照與日誌。
  nonisolated func clearDataOnDisk(
    fileURL: URL? = nil,
    dataProvider: () -> [LMAssembly.LMPerceptionOverride.KeyPerceptionPair]
  ) {
    guard let fileURL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM Error: Unable to clear data because file URL is nil.")
      return
    }
    do {
      try writeFullSnapshot(dataProvider: dataProvider, to: fileURL, force: true)
    } catch {
      vCLMLog("POM Error: Unable to clear the data in the POM file. Details: \(error)")
    }
  }
}

// MARK: - Journal Internals

extension LMAssembly.PerceptionPersistor {
  /// 建立待寫入日誌的記錄列表。
  nonisolated private func preparePendingJournalRecords(
    mapProvider: () -> [String: LMAssembly.LMPerceptionOverride.KeyPerceptionPair],
    keyValidator: (String) -> Bool
  )
    -> [JournalRecord] {
    if needsFullSnapshot { return [] }
    var results: [JournalRecord] = []
    let removalKeys = pendingRemovedKeys.sorted()
    let upsertKeys = pendingUpsertKeys.sorted()
    let map = mapProvider()

    for key in removalKeys {
      results.append(.init(operation: .removeKey, key: key, pair: nil))
    }

    for key in upsertKeys {
      guard let pair = map[key] else { continue }
      guard keyValidator(pair.key) else { continue }
      results.append(.init(operation: .upsert, key: key, pair: pair))
    }

    return results
  }

  /// 將編碼後的日誌記錄追加至副檔。
  nonisolated private func appendJournal(_ records: [JournalRecord], baseURL: URL) throws {
    guard !records.isEmpty else { return }
    let journalURL = journalFileURL(for: baseURL)
    let encoder = JSONEncoder()
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: journalURL.path) {
      _ = fileManager.createFile(atPath: journalURL.path, contents: nil, attributes: nil)
    }

    let handle = try FileHandle(forWritingTo: journalURL)
    defer { handle.closeFile() }
    handle.seekToEndOfFile()

    for record in records {
      let data = try encoder.encode(record)
      handle.write(data)
      if let newline = "\n".data(using: .utf8) {
        handle.write(newline)
      }
    }

    vCLMLog("POM Journal: Appended \(records.count) entries to \(journalURL.path)")
    let now = Date().timeIntervalSince1970
    lock.withLock {
      for rec in records {
        if let k = rec.key {
          lastLogTimestampByKey[k] = now
        } else if let p = rec.pair {
          lastLogTimestampByKey[p.key] = now
        }
      }
    }
  }

  /// 計算資料的 CRC32 雜湊並回傳十六進位字串表示。
  nonisolated private func computeHexCRC32(_ data: Data) -> String {
    let checksum = CRC32.checksum(data: data)
    return String(format: "%08x", checksum)
  }

  /// 判斷是否需要以新快照壓縮日誌。
  nonisolated private func shouldCompactJournal(for baseURL: URL) -> Bool {
    let journalURL = journalFileURL(for: baseURL)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: journalURL.path) else { return false }

    if journalEntriesSinceLastCompaction >= Self.journalCompactionEntryThreshold {
      return true
    }

    do {
      let attributes = try fileManager.attributesOfItem(atPath: journalURL.path)
      if let fileSize = attributes[.size] as? NSNumber {
        return fileSize.uint64Value >= Self.journalCompactionSizeThreshold
      }
    } catch {
      vCLMLog("POM Journal: Unable to read attributes, forcing compaction. Details: \(error)")
      return true
    }

    return false
  }

  /// 將現有覆寫資料完整輸出為快照，並重置日誌狀態。
  nonisolated private func writeFullSnapshot(
    dataProvider: () -> [LMAssembly.LMPerceptionOverride.KeyPerceptionPair],
    to baseURL: URL,
    force: Bool
  ) throws {
    let encoder = JSONEncoder()
    let toSave = dataProvider()
    let jsonData = try encoder.encode(toSave)
    let crc = computeHexCRC32(jsonData)

    let shouldWrite = lock.withLock {
      if !force, previouslySavedHash == crc {
        return false
      }
      return true
    }

    if shouldWrite {
      try jsonData.write(to: baseURL, options: .atomic)
      lock.withLock {
        previouslySavedHash = crc
      }
      vCLMLog("POM Snapshot: Wrote \(toSave.count) items to \(baseURL.path)")
    } else {
      vCLMLog("POM Snapshot: Hash unchanged, skipping rewrite.")
    }

    lock.withLock {
      pendingUpsertKeys.removeAll()
      pendingRemovedKeys.removeAll()
      journalEntriesSinceLastCompaction = 0
      needsFullSnapshot = false
      cleanupOldTimestamps()
    }
    removeJournalFile(for: baseURL)
  }

  /// 重播日誌操作以同步記憶體狀態。
  nonisolated private func replayJournal(
    from baseURL: URL,
    keyValidator: @escaping (String) -> Bool,
    replayApplicator: (inout [String: LMAssembly.LMPerceptionOverride.KeyPerceptionPair], inout Bool) -> ()
  ) {
    let journalURL = journalFileURL(for: baseURL)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: journalURL.path) else { return }

    do {
      let data = try Data(contentsOf: journalURL)
      guard !data.isEmpty else { return }
      guard let content = String(data: data, encoding: .utf8) else { return }
      let decoder = JSONDecoder()
      let lines = content.split(whereSeparator: { $0.isNewline })
      guard !lines.isEmpty else { return }

      var recordsToApply: [JournalRecord] = []
      for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        guard let recordData = trimmed.data(using: .utf8) else { continue }

        do {
          let record = try decoder.decode(JournalRecord.self, from: recordData)
          guard isValidJournalRecord(record, keyValidator: keyValidator) else {
            vCLMLog(
              "POM Journal: Detected corrupted journal record during validation, deleting journal: \(trimmed.prefix(200))"
            )
            removeJournalFile(for: baseURL)
            return
          }
          recordsToApply.append(record)
        } catch {
          vCLMLog(
            "POM Journal: Failed to decode record during validation. Details: \(error). Removing journal file to avoid replay of corrupted data."
          )
          removeJournalFile(for: baseURL)
          return
        }
      }

      // Apply validated records through the callback.
      var tempMap = [String: LMAssembly.LMPerceptionOverride.KeyPerceptionPair]()
      var mutated = false
      for record in recordsToApply {
        switch record.operation {
        case .clear:
          tempMap.removeAll()
          mutated = true
        case .removeKey:
          if let key = record.key {
            tempMap[key] = nil // Mark for removal
            mutated = true
          }
        case .upsert:
          if let pair = record.pair, keyValidator(pair.key) {
            tempMap[pair.key] = pair
            mutated = true
          }
        }
      }

      replayApplicator(&tempMap, &mutated)

      lock.withLock {
        pendingUpsertKeys.removeAll()
        pendingRemovedKeys.removeAll()
        journalEntriesSinceLastCompaction = 0
      }
    } catch {
      vCLMLog("POM Journal: Unable to replay log. Details: \(error)")
    }
  }

  /// 檢查 journal record 的合理性以避免受損或惡意資料回放。
  nonisolated private func isValidJournalRecord(
    _ record: JournalRecord,
    keyValidator: (String) -> Bool
  )
    -> Bool {
    switch record.operation {
    case .clear:
      return true
    case .removeKey:
      guard let key = record.key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
      if !keyValidator(key) { return false }
      return true
    case .upsert:
      guard let pair = record.pair else { return false }
      let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !key.isEmpty else { return false }
      if !keyValidator(key) { return false }
      if pair.perception.overrides.isEmpty { return false }
      let now = Date().timeIntervalSince1970
      for (candidate, override) in pair.perception.overrides {
        let cand = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if cand.isEmpty || cand.count > 128 { return false }
        if override.count <= 0 || override.count > 10_000 { return false }
        if override.timestamp <= 0 || override.timestamp > now + 3_600 { return false }
      }
      return true
    }
  }

  /// 在成功壓縮後刪除日誌副檔。
  nonisolated private func removeJournalFile(for baseURL: URL) {
    let journalURL = journalFileURL(for: baseURL)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: journalURL.path) else { return }
    do {
      try fileManager.removeItem(at: journalURL)
      vCLMLog("POM Journal: Cleared journal at \(journalURL.path)")
    } catch {
      vCLMLog("POM Journal: Unable to delete journal. Details: \(error)")
    }
  }

  /// 依據快照檔案 URL 推導日誌副檔的路徑。
  nonisolated private func journalFileURL(for baseURL: URL) -> URL {
    baseURL.appendingPathExtension("journal")
  }

  /// 清理 lastLogTimestampByKey 中過期的條目以防止記憶體洩漏。
  nonisolated private func cleanupOldTimestamps() {
    let now = Date().timeIntervalSince1970
    let threshold = now - (Self.perKeyThrottleInterval * 10)
    lastLogTimestampByKey = lastLogTimestampByKey.filter { $0.value > threshold }
  }
}
