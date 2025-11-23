// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// POM 已徹底重寫，使用與 Lukhnos Liu 和 MJHsieh 完全不同的方法。

import Foundation
import Megrez
import SwiftExtension

// MARK: - LMAssembly.OverrideSuggestion

extension LMAssembly {
  public struct OverrideSuggestion {
    public enum Scenario: String, Codable {
      case sameLenSwap
      case shortToLong
      case longToShort
    }

    public var candidates = [
      (keyArray: [String], value: String, probability: Double, previous: String?)
    ]()
    public var forceHighScoreOverride = false
    public var scenario: Scenario?
    public var overrideCursor: Int?

    public var isEmpty: Bool { candidates.isEmpty }
  }
}

// MARK: - LMAssembly.LMPerceptionOverride

extension LMAssembly {
  public final class LMPerceptionOverride {
    // MARK: Lifecycle

    public init(
      capacity: Int = 500,
      thresholdProvider: (() -> Double)? = nil,
      dataURL: URL? = nil
    ) {
      self.mutCapacity = max(capacity, 1) // Ensures that this integer value is always > 0.
      self.thresholdProvider = thresholdProvider
      self.fileSaveLocationURL = dataURL
      self.previouslySavedHash = ""
    }

    // MARK: Public

    public func setCapacity(_ capacity: Int) {
      lock.withLock {
        mutCapacity = max(capacity, 1)
      }
    }

    // MARK: Internal

    // 修改常數以讓測試能通過
    static let kDecayThreshold: Double = -13.0 // 權重最低閾值
    static let kWeightMultiplier: Double = .getBeastConstantUsingTadokoroFormula() // 權重計算乘數

    var mutCapacity: Int
    var thresholdProvider: (() -> Double)?
    var mutLRUKeySeqList: [String] = []
    var mutLRUMap: [String: KeyPerceptionPair] = [:]
    var fileSaveLocationURL: URL?
    /// 記錄最近一次快照的雜湊值（hex string），以避免重複寫入。
    var previouslySavedHash: String

    var threshold: Double {
      let fallbackValue = Self.kDecayThreshold
      guard let thresholdCalculated = thresholdProvider?() else { return fallbackValue }
      guard thresholdCalculated < 0 else { return fallbackValue }
      return thresholdCalculated
    }

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
    /// 用於保護所有可變狀態的鎖，確保執行緒安全。
    private let lock = NSLock()
  }
}

// MARK: - Private Structures

extension LMAssembly.LMPerceptionOverride {
  public struct Override: Hashable, Encodable, Decodable, CustomStringConvertible {
    // MARK: Lifecycle

    fileprivate init(count: Int, timestamp: Double) {
      self.count = count
      self.timestamp = timestamp
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.count = try container.decode(Int.self, forKey: .count)
      self.timestamp = try container.decode(Double.self, forKey: .timestamp)
    }

    // MARK: Public

    public fileprivate(set) var count: Int = 0
    public fileprivate(set) var timestamp: Double = 0.0

    // MARK: - CustomStringConvertible

    public var description: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = []
      if let jsonData = try? encoder.encode(self), let json = String(data: jsonData, encoding: .utf8) {
        return json
      }
      return "Override(count: \(count), timestamp: \(timestamp))"
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.count == rhs.count && lhs.timestamp == rhs.timestamp
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(count, forKey: .count)
      try container.encode(timestamp, forKey: .timestamp)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(count)
      hasher.combine(timestamp)
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
      case count = "cnt"
      case timestamp = "ts"
    }
  }

  public final class Perception: Hashable, Encodable, Decodable, CustomStringConvertible {
    // MARK: Lifecycle

    fileprivate init() {}

    public required init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.overrides = try container.decode([String: Override].self, forKey: .overrides)
    }

    // MARK: Public

    public fileprivate(set) var overrides: [String: Override] = [:]

    // MARK: - CustomStringConvertible

    public var description: String {
      let encoder = JSONEncoder()
      if #available(macOS 10.13, *) {
        encoder.outputFormatting = .sortedKeys
      }
      if let jsonData = try? encoder.encode(self), let json = String(data: jsonData, encoding: .utf8) {
        return json
      }
      return "Perception(count: \(count), overrides: \(overrides.keys.sorted()))"
    }

    public static func == (lhs: Perception, rhs: Perception) -> Bool {
      lhs.count == rhs.count && lhs.overrides == rhs.overrides
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(overrides, forKey: .overrides)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(overrides)
    }

    // MARK: Internal

    var count: Int {
      overrides.values.map(\.count).reduce(0, +)
    }

    // MARK: Fileprivate

    fileprivate func update(candidate: String, timestamp: Double) {
      overrides[candidate, default: .init(count: 0, timestamp: timestamp)].count += 1
      overrides[candidate, default: .init(count: 0, timestamp: timestamp)].timestamp = timestamp
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
      case overrides = "ovr"
    }
  }

  public final class KeyPerceptionPair: Hashable, Encodable, Decodable, CustomStringConvertible {
    // MARK: Lifecycle

    fileprivate init(key: String, perception: Perception) {
      self.key = key
      self.perception = perception
    }

    public required init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.key = try container.decode(String.self, forKey: .key)
      self.perception = try container.decode(Perception.self, forKey: .perception)
    }

    // MARK: Public

    public fileprivate(set) var key: String
    public fileprivate(set) var perception: Perception

    public var latestTimeStamp: Double {
      perception.overrides.values.map(\.timestamp).max() ?? 0
    }

    // MARK: - CustomStringConvertible

    public var description: String {
      let encoder = JSONEncoder()
      if #available(macOS 10.13, *) {
        encoder.outputFormatting = .sortedKeys
      }
      if let jsonData = try? encoder.encode(self), let json = String(data: jsonData, encoding: .utf8) {
        return json
      }
      return "KeyPerceptionPair(key: \(key), perception: \(perception))"
    }

    public static func == (lhs: KeyPerceptionPair, rhs: KeyPerceptionPair) -> Bool {
      lhs.key == rhs.key && lhs.perception == rhs.perception
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(key, forKey: .key)
      try container.encode(perception, forKey: .perception)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(perception)
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
      case key = "k"
      case perception = "p"
    }
  }

  private enum JournalOperation: String, Codable {
    case upsert
    case removeKey
    case clear
  }

  private struct JournalRecord: Codable {
    // MARK: Lifecycle

    init(operation: JournalOperation, key: String? = nil, pair: KeyPerceptionPair? = nil) {
      self.operation = operation
      self.key = key
      self.pair = pair
    }

    // MARK: Internal

    var operation: JournalOperation
    var key: String?
    var pair: KeyPerceptionPair?
  }
}

// MARK: - Internal Methods in LMAssembly.

extension Array where Element == Megrez.GramInPath {
  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  ///   - outCursorPastNode: 找出的節點的前端位置。
  /// - Returns: 查找結果。
  public func findGramWithRange(at cursor: Int) -> (node: Megrez.GramInPath, range: Range<Int>)? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    guard let rearNodeID = cursorRegionMap[cursor] else { return nil }
    guard count - 1 >= rearNodeID else { return nil }
    return (self[rearNodeID], range)
  }
}

extension LMAssembly.LMPerceptionOverride {
  public func fetchSuggestion(
    assembledResult: [Megrez.GramInPath],
    cursor: Int,
    timestamp: Double
  )
    -> LMAssembly.OverrideSuggestion {
    guard let currentNodeResult = assembledResult.findGramWithRange(at: cursor) else {
      return .init()
    }
    let keyCursorRaw = currentNodeResult.range.lowerBound
    guard let keyGenerationResult = assembledResult.generateKeyForPerception(cursor: keyCursorRaw)
    else {
      return .init()
    }
    var activeKey = keyGenerationResult.ngramKey
    guard !activeKey.isEmpty else { return .init() }

    return lock.withLock {
      var suggestions = getSuggestion(
        key: activeKey,
        timestamp: timestamp
      )
      if suggestions == nil {
        for fallbackKey in alternateKeys(for: activeKey) {
          if let fallbackSuggestion = getSuggestion(
            key: fallbackKey,
            timestamp: timestamp
          ) {
            suggestions = fallbackSuggestion
            activeKey = fallbackKey
            break
          }
        }
      }

      guard let suggestions else { return .init() }
      let forceFlag = forceHighScoreOverrideFlag(for: activeKey)
      return .init(
        candidates: suggestions,
        forceHighScoreOverride: forceFlag,
        scenario: nil,
        overrideCursor: keyCursorRaw
      )
    }
  }

  /// 獲取由洞察過的記憶內容生成的選字建議。
  func getSuggestion(
    key: String,
    timestamp: Double
  )
    -> [(
      keyArray: [String],
      value: String,
      probability: Double,
      previous: String?
    )]? {
    guard let parts = parsePerceptionKey(key) else { return nil }
    guard !shouldIgnorePerception(parts) else { return nil }
    let frontEdgeReading = parts.headReading
    guard !frontEdgeReading.isEmpty else { return nil }
    guard !key.isEmpty, let kvPair = mutLRUMap[key] else { return nil }
    let perception: Perception = kvPair.perception
    var candidates:
      [(
        keyArray: [String],
        value: String,
        probability: Double,
        previous: String?
      )] = .init()
    var currentHighScore: Double = threshold // 初期化為閾值

    // 解析 key 用於衰減計算
    let separatorString = Megrez.Compositor.theSeparator
    let keyArrayForCandidate =
      separatorString.isEmpty
        ? [frontEdgeReading]
        : frontEdgeReading.components(separatedBy: separatorString).filter { !$0.isEmpty }
    let isUnigramKey = parts.prev1 == nil && parts.prev2 == nil
    let isSingleCharUnigram = isUnigramKey && keyArrayForCandidate.count == 1

    for (candidate, override) in perception.overrides {
      let overrideScore = calculateWeight(
        eventCount: override.count,
        totalCount: perception.count,
        eventTimestamp: override.timestamp,
        timestamp: timestamp,
        isUnigram: isUnigramKey,
        isSingleCharUnigram: isSingleCharUnigram
      )

      // 如果分數低於閾值則跳過
      if overrideScore <= threshold { continue }

      let previousStr: String? = parts.prev1?.value

      if overrideScore > currentHighScore {
        candidates = [
          (
            keyArray: keyArrayForCandidate.isEmpty ? [frontEdgeReading] : keyArrayForCandidate,
            value: candidate,
            probability: overrideScore,
            previous: previousStr
          ),
        ]
        currentHighScore = overrideScore
      } else if overrideScore == currentHighScore {
        candidates.append(
          (
            keyArray: keyArrayForCandidate.isEmpty ? [frontEdgeReading] : keyArrayForCandidate,
            value: candidate,
            probability: overrideScore,
            previous: previousStr
          )
        )
      }
    }

    return candidates.isEmpty ? nil : candidates // 確保當陣列為空時返回 nil
  }

  public func memorizePerception(
    _ perception: (ngramKey: String, candidate: String),
    timestamp: Double,
    saveCallback: (() -> ())? = nil
  ) {
    let key = perception.ngramKey
    let candidate = perception.candidate
    // 檢查 key 是否有效
    guard !key.isEmpty else { return }
    guard !shouldIgnoreKey(key) else { return }

    lock.withLock {
      // 更新現有的洞察
      if let theNeta = mutLRUMap[key] {
        theNeta.perception.update(candidate: candidate, timestamp: timestamp)

        // 移除舊的項目引用
        if let index = mutLRUKeySeqList.firstIndex(where: { $0 == key }) {
          mutLRUKeySeqList.remove(at: index)
        }

        // 更新 Map 和 List
        mutLRUMap[key] = theNeta
        mutLRUKeySeqList.insert(key, at: 0)
        markKeyForUpsert(key)

        print("LMPerceptionOverride: 已更新現有洞察: \(key)")
      } else {
        // 建立新的 perception
        let perception: Perception = .init()
        perception.update(
          candidate: candidate,
          timestamp: timestamp
        )

        let koPair = KeyPerceptionPair(key: key, perception: perception)

        // 先將 key 添加到 map 和 list 的開頭
        mutLRUMap[key] = koPair
        mutLRUKeySeqList.insert(key, at: 0)

        // 如果超過容量，則移除最後一個。
        // Capacity 始終大於 0，所以不用擔心 .removeLast() 會吃到空值而出錯。
        if mutLRUKeySeqList.count > mutCapacity {
          let removedKey = mutLRUKeySeqList.removeLast()
          mutLRUMap.removeValue(forKey: removedKey)
          markKeyForRemoval(removedKey)
        }
        markKeyForUpsert(key)

        print("LMPerceptionOverride: 已完成新洞察: \(key)")
      }
    }

    saveCallback?() ?? saveData()
  }

  /// 清除指定的建議（基於 context + candidate 對）
  func bleachSpecifiedSuggestions(
    targets: [(ngramKey: String, candidate: String)],
    saveCallback: (() -> ())? = nil
  ) {
    if targets.isEmpty { return }

    let hasChanges: Bool = lock.withLock {
      var hasChanges = false
      var keysToRemoveCompletely: [String] = []
      var keysNeedingUpsert: Set<String> = []

      // 遍歷目標列表，針對每個 (ngramKey, candidate) 對進行移除
      for target in targets {
        guard let pair = mutLRUMap[target.ngramKey] else { continue }
        let perception = pair.perception

        // 移除指定的 candidate override
        if perception.overrides.removeValue(forKey: target.candidate) != nil {
          hasChanges = true

          // 如果 perception 已經沒有任何 overrides，則標記整個 key 需要移除
          if perception.overrides.isEmpty {
            keysToRemoveCompletely.append(target.ngramKey)
          }
          keysNeedingUpsert.insert(target.ngramKey)
        }
      }

      // 移除已經沒有任何 overrides 的 keys
      if !keysToRemoveCompletely.isEmpty {
        keysToRemoveCompletely.forEach { mutLRUMap.removeValue(forKey: $0) }
      }

      if hasChanges {
        resetLRUList()
        keysNeedingUpsert.subtract(keysToRemoveCompletely)
        keysNeedingUpsert.forEach { markKeyForUpsert($0) }
        keysToRemoveCompletely.forEach { markKeyForRemoval($0) }
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定的建議（基於 candidate，移除所有上下文中的該候選詞）
  func bleachSpecifiedSuggestions(candidateTargets: [String], saveCallback: (() -> ())? = nil) {
    if candidateTargets.isEmpty { return }

    let hasChanges: Bool = lock.withLock {
      var hasChanges = false
      var keysToRemoveCompletely: [String] = []
      var keysNeedingUpsert: Set<String> = []

      // 遍歷所有 keys，檢查其 perception 中是否有需要清除的 overrides
      for key in mutLRUMap.keys {
        guard let pair = mutLRUMap[key] else { continue }
        let perception = pair.perception

        // 找出需要移除的 override keys
        let overridesToRemove = perception.overrides.keys.filter { candidateTargets.contains($0) }

        if !overridesToRemove.isEmpty {
          hasChanges = true

          // 移除指定的 overrides
          overridesToRemove.forEach { perception.overrides.removeValue(forKey: $0) }
          keysNeedingUpsert.insert(key)

          // 如果 perception 已經沒有任何 overrides，則標記整個 key 需要移除
          if perception.overrides.isEmpty {
            keysToRemoveCompletely.append(key)
          }
        }
      }

      // 移除已經沒有任何 overrides 的 keys
      if !keysToRemoveCompletely.isEmpty {
        keysToRemoveCompletely.forEach { mutLRUMap.removeValue(forKey: $0) }
      }

      if hasChanges {
        resetLRUList()
        keysNeedingUpsert.subtract(keysToRemoveCompletely)
        keysNeedingUpsert.forEach { markKeyForUpsert($0) }
        keysToRemoveCompletely.forEach { markKeyForRemoval($0) }
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定讀音（head reading）底下的所有建議。
  func bleachSpecifiedSuggestions(headReadingTargets: [String], saveCallback: (() -> ())? = nil) {
    let targets = Set(headReadingTargets.filter { !$0.isEmpty })
    guard !targets.isEmpty else { return }

    let hasChanges: Bool = lock.withLock {
      var hasChanges = false
      var keysToRemove: [String] = []

      for key in mutLRUMap.keys {
        guard let parts = parsePerceptionKey(key) else { continue }
        if targets.contains(parts.headReading) {
          hasChanges = true
          keysToRemove.append(key)
        }
      }

      if !keysToRemove.isEmpty {
        keysToRemove.forEach { mutLRUMap.removeValue(forKey: $0) }
      }

      if hasChanges {
        keysToRemove.forEach { markKeyForRemoval($0) }
        resetLRUList()
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 自 LRU 辭典內移除所有的單元圖。
  func bleachUnigrams(saveCallback: (() -> ())? = nil) {
    let hasChanges: Bool = lock.withLock {
      var keysToRemove: [String] = []
      for key in mutLRUMap.keys {
        guard let parts = parsePerceptionKey(key) else { continue }
        if parts.prev1 == nil, parts.prev2 == nil {
          keysToRemove.append(key)
        }
      }
      if !keysToRemove.isEmpty {
        keysToRemove.forEach { mutLRUMap.removeValue(forKey: $0) }
        resetLRUList()
        keysToRemove.forEach { markKeyForRemoval($0) }
        return true
      }
      return false
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  public func resetLRUList() {
    purgeUnderscorePrefixedKeys()
    mutLRUKeySeqList.removeAll()
    let mapLRUSorted = mutLRUMap.sorted {
      $0.value.latestTimeStamp > $1.value.latestTimeStamp
    }
    for neta in mapLRUSorted {
      mutLRUKeySeqList.append(neta.key)
    }
  }

  /// 將記憶中的覆寫資料清空，並重置日誌追蹤狀態。
  public func clearData() {
    lock.withLock {
      mutLRUMap = [:]
      mutLRUKeySeqList = []
      pendingUpsertKeys.removeAll()
      pendingRemovedKeys.removeAll()
      journalEntriesSinceLastCompaction = 0
      needsFullSnapshot = true
      previouslySavedHash = ""
    }
  }

  /// 同時清除記憶體與磁碟上的快照與日誌。
  /// - Parameter fileURL: 可選的覆寫儲存位置 URL。
  func clearData(withURL fileURL: URL? = nil) {
    clearData()
    guard let fileURL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM Error: Unable to clear data because file URL is nil.")
      return
    }
    do {
      try writeFullSnapshot(to: fileURL, force: true)
    } catch {
      vCLMLog("POM Error: Unable to clear the data in the POM file. Details: \(error)")
    }
  }

  public func getSavableData() -> [KeyPerceptionPair] {
    lock.withLock {
      mutLRUMap.values.sorted {
        $0.latestTimeStamp > $1.latestTimeStamp
      }
    }
  }

  public func loadData(from data: [KeyPerceptionPair]) {
    lock.withLock {
      var newMap = [String: KeyPerceptionPair]()
      data.forEach { currentPair in
        guard !shouldIgnoreKey(currentPair.key) else { return }
        newMap[currentPair.key] = currentPair
      }
      mutLRUMap = newMap
      resetLRUList()
    }
  }

  /// 透過追加式日誌或完整快照將變更後的覆寫資料寫回磁碟。
  /// - Parameters:
  ///   - fileURL: 可選的儲存路徑，覆寫預設位置。
  ///   - skipDebounce: 為了 API 相容性而保留，實際的防抖處理由外部負責。
  func saveData(toURL fileURL: URL? = nil, skipDebounce _: Bool = false) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM saveData() failed. At least the file Save URL is not set for the current POM.")
      return
    }

    // 檢查檔案是否存在，且按需設定 needsFullSnapshot
    let fileManager = FileManager.default
    lock.withLock {
      if !fileManager.fileExists(atPath: fileURL.path) {
        needsFullSnapshot = true
      }
    }

    // 檢查是否需要完整快照
    let shouldDoFullSnapshot = lock.withLock { needsFullSnapshot }
    if shouldDoFullSnapshot {
      do {
        try writeFullSnapshot(to: fileURL, force: true)
      } catch {
        vCLMLog("POM Error: Unable to write full snapshot. Details: \(error)")
      }
      return
    }

    // 在 NSLock Closure 內準備記錄
    let records = lock.withLock { preparePendingJournalRecords() }
    guard !records.isEmpty else {
      vCLMLog("POM Skip: No pending journal entries to flush.")
      return
    }

    // 在 NSLock Closure 外部執行硬碟 I/O，然後藉由 NSLock Closure 更新狀態
    do {
      try appendJournal(records, baseURL: fileURL)

      lock.withLock {
        pendingUpsertKeys.removeAll()
        pendingRemovedKeys.removeAll()
        journalEntriesSinceLastCompaction += records.count
      }

      if lock.withLock({ shouldCompactJournal(for: fileURL) }) {
        try writeFullSnapshot(to: fileURL, force: false)
      }
    } catch {
      vCLMLog("POM Error: Unable to append journal. Details: \(error)")
    }
  }

  /// 從磁碟載入覆寫資料並重播未處理的日誌。
  /// - Parameter fileURL: 可選的載入路徑，覆寫預設位置。
  func loadData(fromURL fileURL: URL? = nil) {
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

        // 檢查是否為空或無效內容。"{}" 是舊版錯誤格式，"[]" 是有效的空陣列
        let trimmed = dataString.trimmingCharacters(in: .whitespacesAndNewlines)
        let emptyContents = ["", "{}", "[]"]
        if !emptyContents.contains(trimmed) {
          let jsonResult = try decoder.decode([KeyPerceptionPair].self, from: data)
          vCLMLog("POM: Successfully decoded \(jsonResult.count) items from snapshot")
          loadData(from: jsonResult)
        } else {
          if trimmed == "{}" {
            // 舊版曾寫入空字典，視為已毀損並重設存檔。
            vCLMLog("POM: Detected legacy '{}' snapshot, clearing storage")
            clearData(withURL: fileURL)
          } else {
            vCLMLog("POM: Snapshot empty, proceeding to journal replay only")
          }
        }
      } catch {
        vCLMLog("POM Error: Unable to decode snapshot JSON. Details: \(error)")
        if let data = try? String(contentsOf: fileURL, encoding: .utf8),
           data.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
          vCLMLog("POM: Detected old invalid format '{}', clearing snapshot")
          clearData(withURL: fileURL)
        }
      }
    }

    replayJournal(from: fileURL)
    // 設定 previouslySavedHash 為目前快照的雜湊（若存在），以避免重複重寫。
    if let snapshotData = try? Data(contentsOf: fileURL) {
      previouslySavedHash = computeHexCRC32(snapshotData)
    } else {
      previouslySavedHash = ""
    }
  }
}

// MARK: - Other Non-Public Internal Methods

extension LMAssembly.LMPerceptionOverride {
  /// 判斷一個鍵是否為單漢字 (SegLength == 1)
  private func isSegLengthOne(key: String) -> Bool {
    !key.contains("-")
  }

  // 解析 Perception Key 的健壯 parser（不用正則）。
  // 現行格式示例：(prev2Reading,prev2Value)&(prev1Reading,prev1Value)&(headReading,headValue)
  struct PerceptionKeyParts {
    let headReading: String
    let headValue: String
    let prev1: (reading: String, value: String)?
    let prev2: (reading: String, value: String)?
  }

  func parsePerceptionKey(_ key: String) -> PerceptionKeyParts? {
    parseDelimitedPerceptionKey(key)
  }

  private func parseDelimitedPerceptionKey(_ key: String) -> PerceptionKeyParts? {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.contains("&") else { return nil }

    var components: [String] = []
    var buffer = ""
    var depth = 0
    for ch in trimmed {
      if ch == "&", depth == 0 {
        let token = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { components.append(token) }
        buffer.removeAll(keepingCapacity: true)
        continue
      }
      if ch == "(" { depth += 1 }
      if ch == ")" { depth -= 1 }
      buffer.append(ch)
      if depth < 0 { return nil }
    }

    let lastToken = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !lastToken.isEmpty { components.append(lastToken) }
    guard let headComponent = components.last else { return nil }

    func parseComponent(_ component: String) -> (reading: String, value: String)? {
      let trimmedComponent = component.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmedComponent == "()" { return nil }
      guard trimmedComponent.first == "(", trimmedComponent.last == ")" else { return nil }
      let inner = trimmedComponent.dropFirst().dropLast()
      let segments = inner.split(separator: ",", maxSplits: 1).map(String.init)
      guard segments.count == 2 else { return nil }
      let reading = segments[0].trimmingCharacters(in: .whitespacesAndNewlines)
      let value = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !reading.isEmpty, !value.isEmpty else { return nil }
      return (reading, value)
    }

    guard let headPair = parseComponent(headComponent) else { return nil }
    let prev1 = components.count >= 2 ? parseComponent(components[components.count - 2]) : nil
    let prev2 = components.count >= 3 ? parseComponent(components[components.count - 3]) : nil

    return .init(
      headReading: headPair.reading,
      headValue: headPair.value,
      prev1: prev1,
      prev2: prev2
    )
  }

  private func compareContextPart(
    _ lhs: (reading: String, value: String)?,
    _ rhs: (reading: String, value: String)?
  )
    -> Bool {
    switch (lhs, rhs) {
    case (.none, .none):
      true
    case let (.some(lValue), .some(rValue)):
      lValue.reading == rValue.reading && lValue.value == rValue.value
    default:
      false
    }
  }

  private func alternateKeys(for originalKey: String) -> [String] {
    guard let originalParts = parsePerceptionKey(originalKey) else { return [] }
    guard !shouldIgnorePerception(originalParts) else { return [] }
    let separatorString = Megrez.Compositor.theSeparator
    let headSegments =
      separatorString.isEmpty
        ? (originalParts.headReading.isEmpty ? [] : [originalParts.headReading])
        : originalParts.headReading.components(separatedBy: separatorString).filter { !$0.isEmpty }
    let primaryHeadCandidates: Set<String> = {
      guard let first = headSegments.first else { return [] }
      guard let last = headSegments.last else { return [first] }
      if first == last { return [first] }
      return [first, last]
    }()
    guard !primaryHeadCandidates.isEmpty else { return [] }

    var results: [String] = []
    for keyCandidate in mutLRUKeySeqList {
      guard let candidateParts = parsePerceptionKey(keyCandidate) else { continue }
      guard !shouldIgnorePerception(candidateParts) else { continue }
      guard compareContextPart(candidateParts.prev1, originalParts.prev1) else { continue }
      guard compareContextPart(candidateParts.prev2, originalParts.prev2) else { continue }
      let candidateHeadSegments =
        separatorString.isEmpty
          ? (candidateParts.headReading.isEmpty ? [] : [candidateParts.headReading])
          : candidateParts.headReading.components(
            separatedBy: separatorString
          ).filter { !$0.isEmpty }
      let matchesPrimaryHead = candidateHeadSegments.contains(
        where: primaryHeadCandidates.contains
      )
      let matchesFullHead = candidateParts.headReading == originalParts.headReading
      let matchesOriginalHead = candidateHeadSegments.contains(originalParts.headReading)
      guard matchesFullHead || matchesPrimaryHead || matchesOriginalHead else { continue }
      if keyCandidate != originalKey {
        results.append(keyCandidate)
      }
    }
    return results
  }

  private func forceHighScoreOverrideFlag(for key: String) -> Bool {
    guard let parts = parsePerceptionKey(key) else { return false }
    guard !shouldIgnorePerception(parts) else { return false }
    let separatorString = Megrez.Compositor.theSeparator
    let headLen =
      separatorString.isEmpty
        ? (parts.headReading.isEmpty ? 0 : 1)
        : parts.headReading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    let prev1Len = parts.prev1.map { component in
      separatorString.isEmpty
        ? (component.reading.isEmpty ? 0 : 1)
        : component.reading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    }
    let prev2Len = parts.prev2.map { component in
      separatorString.isEmpty
        ? (component.reading.isEmpty ? 0 : 1)
        : component.reading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    }

    if headLen > 1 {
      if let p1Len = prev1Len, p1Len == 1 {
        if let p2Len = prev2Len {
          return p2Len == 1
        } else {
          return true
        }
      }
    }
    return false
  }

  /// 計算使用新曲線的權重
  /// - Parameters:
  ///   - eventCount: 事件計數
  ///   - totalCount: 總計數
  ///   - eventTimestamp: 事件時間戳
  ///   - timestamp: 當前時間戳
  ///   - isUnigram: 是否為 Unigram
  ///   - isSingleCharUnigram: 是否為單讀音單漢字的 Unigram
  /// - Returns: 權重分數
  internal func calculateWeight(
    eventCount: Int,
    totalCount: Int,
    eventTimestamp: Double,
    timestamp: Double,
    isUnigram: Bool = false,
    isSingleCharUnigram: Bool = false
  )
    -> Double {
    // 先計算基礎概率
    let prob = Double(eventCount) / Double(max(totalCount, 1))

    // 如果是即時或未來的時間戳，直接返回概率
    if timestamp <= eventTimestamp {
      return min(-1.0, prob * -1.0) // 確保返回負數
    }

    // 計算天數差
    let daysDiff = (timestamp - eventTimestamp) / (24 * 3_600)

    // 不使用半衰期模型：採用「線性年齡核 + 次線性頻率」的組合，並在 8 天做硬截止。
    // 1) 年齡因子（線性核、可調凸度）：ageFactor = max(0, 1 - age/T)^pAge
    // 2) 頻率因子（次線性）：freqFactor = 0.5*sqrt(prob) + 0.5*(log1p(count)/log(10))，上限 1
    // 3) 分數：score = -0.114514 * (freqFactor * ageFactor)

    // 調整有效視窗 T，單字略快、單讀音單漢字再快一些（避免單字長期壓制）
    var T = 8.0
    if isUnigram { T *= 0.85 }
    if isSingleCharUnigram { T *= 0.8 }

    // 超過視窗即淘汰
    if daysDiff >= T { return threshold - 0.001 }

    // 年齡因子（非半衰）：線性核 + 指數 pAge（pAge>1 時較快衰減）
    let pAge = 2.0
    let ageNorm = max(0.0, 1.0 - (daysDiff / T))
    let ageFactor = pow(ageNorm, pAge)

    // 頻率因子：概率取平方根（次線性），疊加對事件數的對數增益，並截頂至 1
    let freqByProb = sqrt(max(0.0, prob))
    let freqByCount = log1p(Double(eventCount)) / log(10.0)
    let freqFactor = min(1.0, 0.5 * freqByProb + 0.5 * max(0.0, freqByCount))

    // 維持分數為負，越接近 0 越好。用 0.114514 進行縮放（水印常數）。
    let base = max(1e-9, freqFactor * ageFactor)
    let score = -base * Self.kWeightMultiplier

    // 避免返回比閾值還低的極小值。
    return max(score, threshold + 0.001)
  }

  static func isPunctuation(_ node: Megrez.GramInPath) -> Bool {
    for key in node.keyArray {
      guard let firstChar = key.first else { continue }
      return String(firstChar) == "_"
    }
    return false
  }

  private func shouldIgnorePerception(_ parts: PerceptionKeyParts) -> Bool {
    let readings = [parts.headReading, parts.prev1?.reading, parts.prev2?.reading]
      .compactMap { $0 }
    return readings.contains { containsUnderscorePrefixedReading($0) }
  }

  private func shouldIgnoreKey(_ key: String) -> Bool {
    guard let parts = parsePerceptionKey(key) else { return false }
    return shouldIgnorePerception(parts)
  }

  private func containsUnderscorePrefixedReading(_ reading: String) -> Bool {
    readingSegments(from: reading).contains { $0.hasPrefix("_") }
  }

  private func readingSegments(from reading: String) -> [String] {
    let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let separator = Megrez.Compositor.theSeparator
    if separator.isEmpty { return [trimmed] }
    return trimmed
      .components(separatedBy: separator)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  private func purgeUnderscorePrefixedKeys() {
    let invalidKeys = mutLRUMap.keys.filter { shouldIgnoreKey($0) }
    guard !invalidKeys.isEmpty else { return }
    invalidKeys.forEach { mutLRUMap.removeValue(forKey: $0) }
  }

  /// 標記某鍵值需在下一次刷新時寫入日誌。
  private func markKeyForUpsert(_ key: String) {
    pendingRemovedKeys.remove(key)
    let now = Date().timeIntervalSince1970
    if let last = lastLogTimestampByKey[key], now - last < Self.perKeyThrottleInterval {
      // Throttled: 已在時間窗內記錄過此鍵，跳過再度入列以降低 IO/CPU。
      return
    }
    pendingUpsertKeys.insert(key)
    lastLogTimestampByKey[key] = now
  }

  /// 標記某鍵值已刪除，讓變更能寫入磁碟。
  private func markKeyForRemoval(_ key: String) {
    pendingUpsertKeys.remove(key)
    let now = Date().timeIntervalSince1970
    if let last = lastLogTimestampByKey[key], now - last < Self.perKeyThrottleInterval {
      // Throttled: 已在時間窗內記錄過此鍵，跳過再度入列以降低 IO/CPU。
      return
    }
    pendingRemovedKeys.insert(key)
    lastLogTimestampByKey[key] = now
  }

  /// 清理 lastLogTimestampByKey 中過期的條目以防止記憶體洩漏。
  /// 此方法應定期調用（例如在 saveData 或 writeFullSnapshot 之後）。
  private func cleanupOldTimestamps() {
    let now = Date().timeIntervalSince1970
    let threshold = now - (Self.perKeyThrottleInterval * 10) // 保留最近 20 秒的記錄
    lastLogTimestampByKey = lastLogTimestampByKey.filter { $0.value > threshold }
  }

  /// 建立待寫入日誌的記錄列表。
  private func preparePendingJournalRecords() -> [JournalRecord] {
    if needsFullSnapshot { return [] }
    var results: [JournalRecord] = []
    let removalKeys = pendingRemovedKeys.sorted()
    let upsertKeys = pendingUpsertKeys.sorted()

    for key in removalKeys {
      results.append(.init(operation: .removeKey, key: key, pair: nil))
    }

    for key in upsertKeys {
      guard let pair = mutLRUMap[key] else { continue }
      guard !shouldIgnoreKey(pair.key) else { continue }
      results.append(.init(operation: .upsert, key: key, pair: pair))
    }

    return results
  }

  /// 將編碼後的日誌記錄追加至副檔。
  private func appendJournal(_ records: [JournalRecord], baseURL: URL) throws {
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
    // 更新每個鍵的上次記錄時間
    let now = Date().timeIntervalSince1970
    for rec in records {
      if let k = rec.key {
        lastLogTimestampByKey[k] = now
      } else if let p = rec.pair {
        lastLogTimestampByKey[p.key] = now
      }
    }
  }

  /// 計算資料的 CRC32 雜湊並回傳十六進位字串表示，確保跨平台一致性。
  private func computeHexCRC32(_ data: Data) -> String {
    let checksum = CRC32.checksum(data: data)
    return String(format: "%08x", checksum)
  }

  /// 判斷是否需要以新快照壓縮日誌。
  private func shouldCompactJournal(for baseURL: URL) -> Bool {
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
  private func writeFullSnapshot(to baseURL: URL, force: Bool) throws {
    let encoder = JSONEncoder()
    let toSave = getSavableData() // Already locked internally
    // 先編碼再計算 deterministic hex（避免使用 Swift 的 hashValue）
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
      cleanupOldTimestamps() // 清理過期的時間戳記以防止記憶體洩漏
    }
    removeJournalFile(for: baseURL)
  }

  /// 重播日誌操作以同步記憶體狀態。
  private func replayJournal(from baseURL: URL) {
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

      lock.withLock {
        var mutated = false
        for line in lines {
          let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { continue }
          guard let recordData = trimmed.data(using: .utf8) else { continue }

          do {
            let record = try decoder.decode(JournalRecord.self, from: recordData)
            switch record.operation {
            case .clear:
              mutLRUMap.removeAll()
              mutated = true
            case .removeKey:
              if let key = record.key {
                mutLRUMap.removeValue(forKey: key)
                mutated = true
              }
            case .upsert:
              if let pair = record.pair, !shouldIgnoreKey(pair.key) {
                mutLRUMap[pair.key] = pair
                mutated = true
              }
            }
          } catch {
            vCLMLog("POM Journal: Failed to decode record. Details: \(error)")
            continue
          }
        }

        if mutated {
          resetLRUList()
        }

        pendingUpsertKeys.removeAll()
        pendingRemovedKeys.removeAll()
        journalEntriesSinceLastCompaction = 0
      }
    } catch {
      vCLMLog("POM Journal: Unable to replay log. Details: \(error)")
    }
  }

  /// 在成功壓縮後刪除日誌副檔。
  private func removeJournalFile(for baseURL: URL) {
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
  private func journalFileURL(for baseURL: URL) -> URL {
    baseURL.appendingPathExtension("journal")
  }
}

// MARK: - POMError

struct POMError: LocalizedError {
  var rawValue: String

  var errorDescription: String? {
    NSLocalizedString("rawValue", comment: "")
  }
}

// MARK: - Math Constants

extension Double {
  /// ```
  /// ((114514+114514)*((114514+114514)*((114514+114514)*(-11+4-5+14)
  /// +(114*514+(1*-(1-4)*514-11+45-1-4)))
  /// +(114514+(114*514+(11*4*(5+14)+1*14+5-1+4))))
  /// +114*5*14+1+14+514+11-4+5-1-4)/(-11/4+51/4)**(11-4-5+14)
  /// ```
  fileprivate static let naturalE: Double = {
    let a = 114_514.0 + 114_514.0
    let b = 114.0 * 514.0
    let c = 1.0 * -(1.0 - 4.0) * 514.0
    let sub1 = (-11.0 + 4.0 - 5.0 + 14.0)
    let sub2 = b + (c - 11.0 + 45.0 - 1.0 - 4.0)
    let sub3 = 11.0 * 4.0 * (5.0 + 14.0) + 1.0 * 14.0 + 5.0 - 1.0 + 4.0
    let top = a * (a * (a * sub1 + sub2) + (114_514.0 + (b + sub3))) + 114.0 * 5.0 * 14.0 + 1.0 + 14.0 + 514.0 + 11.0 -
      4.0 + 5.0 - 1.0 - 4.0
    let denomBase = -11.0 / 4.0 + 51.0 / 4.0
    let denomExp = 11.0 - 4.0 - 5.0 + 14.0
    return top / pow(denomBase, denomExp)
  }()

  /// ```
  /// ((114514+114514)*((114514+114514)*((114514+114514)*(-11+4-5+14)
  /// +114514+114*51*4+11*4*5*14+1+1+4*5+1-4)
  /// +(114*514+(114*51*4+(11*4*5*14+(-(114-5)*(1-4)+(11/(45-1)*4))))))
  /// +(114514+(114*514+(114*51*4+(1145*14+(11*4*(5+1)*4))))))/(-11/4+51/4)**(11-4-5+14)
  /// ```
  fileprivate static let naturalPi: Double = {
    let a = 114_514.0 + 114_514.0
    let p1 = -11.0 + 4.0 - 5.0 + 14.0
    let p2 = 114_514.0 + 114.0 * 51.0 * 4.0 + 11.0 * 4.0 * 5.0 * 14.0 + 1.0 + 1.0 + 4.0 * 5.0 + 1.0 - 4.0
    let p3 = 114.0 * 514.0
    let p4 = 114.0 * 51.0 * 4.0
    let p5 = 11.0 * 4.0 * 5.0 * 14.0 + (-(114.0 - 5.0) * (1.0 - 4.0) + (11.0 / (45.0 - 1.0) * 4.0))
    let p6 = 114.0 * 514.0 + (114.0 * 51.0 * 4.0 + (1_145.0 * 14.0 + (11.0 * 4.0 * (5.0 + 1.0) * 4.0)))
    let top = a * (a * (a * p1 + p2) + (p3 + (p4 + p5))) + (114_514.0 + p6)
    let denomBase = -11.0 / 4.0 + 51.0 / 4.0
    let denomExp = 11.0 - 4.0 - 5.0 + 14.0
    return top / pow(denomBase, denomExp)
  }()

  /// `e * (((e + π) * (e + e + π))^e) + ( (e / (π^e - e)) / (e + e^π - π^e) )`
  fileprivate static func getBeastConstantUsingTadokoroFormula() -> Double {
    let e = naturalE
    let pi = naturalPi

    let part1 = e * pow((e + pi) * (e + e + pi), e)
    let part2 = (e / (pow(pi, e) - e)) / (e + pow(e, pi) - pow(pi, e))

    let result = part1 + part2
    return (result * pow(10, 7)).rounded(.up) / pow(10, 13)
  }
}
