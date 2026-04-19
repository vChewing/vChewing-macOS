// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import Shared
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

    public var suggestedOverrideType: Homa.Node.OverrideType {
      forceHighScoreOverride ? .withSpecified : .withTopGramScore
    }
  }
}

// MARK: - LMAssembly.LXPerceptor

extension LMAssembly {
  /// 漸退記憶模組，用來學習使用者的打字行為偏好、且在之後的打字過程中給出建議。
  ///
  /// POM 使用野獸常數作為衰減曲線。
  /// 預設整個生存週期是八天，但可以藉由偏好設定銳減至 12 小時內。
  nonisolated public final class LXPerceptor {
    // MARK: Lifecycle

    public init(
      capacity: Int = 500,
      thresholdProvider: (() -> Double)? = nil,
      dataURL: URL? = nil
    ) {
      self.mutCapacity = max(capacity, 1) // 該參數得始終大於 0.
      self.thresholdProvider = thresholdProvider
      self.persistor = .init(baseURL: dataURL)
    }

    // MARK: Public

    public func setCapacity(_ capacity: Int) {
      lock.withLock {
        mutCapacity = max(capacity, 1)
      }
    }

    // MARK: Internal

    /// 權重最低閾值。
    static let kDecayThreshold: Double = -13.0
    /// 權重計算乘數
    static let kWeightMultiplier: Double = .getBeastConstantUsingTadokoroFormula()

    var mutCapacity: Int
    var thresholdProvider: (() -> Double)?
    var mutLRUKeySeqList: [String] = []
    var mutLRUMap: [String: KeyPerceptionPair] = [:]

    /// 持久化層，負責 WAL 日誌與 JSON 快照。
    let persistor: LMAssembly.PerceptionPersistor

    /// 是否啟用急速遺忘模式（縮短 POM 壽命至 12 小時以內）。
    /// 由外部注入，取代 `calculateWeight` 內部直接讀取 `UserDefaults`。
    var reducedLifetime: Bool = false

    /// 僅供測試：注入的建議用於測試中以繞過內部評分邏輯。
    /// 設置後，`fetchSuggestion` 會立即返回此建議並將其清除。
    var testInjectedSuggestion: LMAssembly.OverrideSuggestion?

    var threshold: Double {
      let fallbackValue = Self.kDecayThreshold
      guard let thresholdCalculated = thresholdProvider?() else { return fallbackValue }
      guard thresholdCalculated < 0 else { return fallbackValue }
      return thresholdCalculated
    }

    // MARK: Private

    /// 用於保護所有可變狀態的鎖，確保執行緒安全。
    private let lock = NSLock()
  }
}

// MARK: - Private Structures

extension LMAssembly.LXPerceptor {
  nonisolated public struct Override: Hashable, Encodable, Decodable, CustomStringConvertible {
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

  nonisolated public final class Perception: Hashable, Encodable, Decodable, CustomStringConvertible {
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

  nonisolated public final class KeyPerceptionPair: Hashable, Encodable, Decodable, CustomStringConvertible {
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
}

// MARK: - Internal Methods in LMAssembly.

extension Array where Element == Homa.GramInPath {
  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  ///   - outCursorPastNode: 找出的節點的前端位置。
  /// - Returns: 查找結果。
  nonisolated public func findGramWithRange(at cursor: Int) -> (node: Homa.GramInPath, range: Range<Int>)? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    guard let rearNodeID = cursorRegionMap[cursor] else { return nil }
    guard count - 1 >= rearNodeID else { return nil }
    return (self[rearNodeID], range)
  }
}

extension LMAssembly.LXPerceptor {
  nonisolated public func fetchSuggestion(
    assembledResult: [Homa.GramInPath],
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
      if let injected = testInjectedSuggestion {
        testInjectedSuggestion = nil
        return injected
      }
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
  nonisolated func getSuggestion(
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
    let separatorString = Homa.Assembler.theSeparator
    let keyArrayForCandidate =
      separatorString.isEmpty
        ? [frontEdgeReading]
        : frontEdgeReading.components(separatedBy: separatorString).filter { !$0.isEmpty }
    let isUnigramKey = parts.previous == nil && parts.anterior == nil
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

      let previousStr: String? = parts.previous?.value

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

  nonisolated public func memorizePerception(
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
        persistor.markKeyForUpsert(key)
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
          persistor.markKeyForRemoval(removedKey)
        }
        persistor.markKeyForUpsert(key)
      }
    }

    saveCallback?() ?? saveData()
  }

  /// 清除指定的建議（基於 context + candidate 對）
  nonisolated func bleachSpecifiedSuggestions(
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
        keysNeedingUpsert.forEach { persistor.markKeyForUpsert($0) }
        keysToRemoveCompletely.forEach { persistor.markKeyForRemoval($0) }
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定的建議（基於 candidate，移除所有上下文中的該候選詞）
  nonisolated func bleachSpecifiedSuggestions(candidateTargets: [String], saveCallback: (() -> ())? = nil) {
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
        keysNeedingUpsert.forEach { persistor.markKeyForUpsert($0) }
        keysToRemoveCompletely.forEach { persistor.markKeyForRemoval($0) }
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定讀音（head reading）底下的所有建議。
  nonisolated func bleachSpecifiedSuggestions(headReadingTargets: [String], saveCallback: (() -> ())? = nil) {
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
        keysToRemove.forEach { persistor.markKeyForRemoval($0) }
        resetLRUList()
      }

      return hasChanges
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  /// 自 LRU 辭典內移除所有的單元圖。
  nonisolated func bleachUnigrams(saveCallback: (() -> ())? = nil) {
    let hasChanges: Bool = lock.withLock {
      var keysToRemove: [String] = []
      for key in mutLRUMap.keys {
        guard let parts = parsePerceptionKey(key) else { continue }
        if parts.previous == nil, parts.anterior == nil {
          keysToRemove.append(key)
        }
      }
      if !keysToRemove.isEmpty {
        keysToRemove.forEach { mutLRUMap.removeValue(forKey: $0) }
        resetLRUList()
        keysToRemove.forEach { persistor.markKeyForRemoval($0) }
        return true
      }
      return false
    }

    if hasChanges {
      saveCallback?() ?? saveData()
    }
  }

  nonisolated public func resetLRUList() {
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
  nonisolated public func clearData() {
    lock.withLock {
      mutLRUMap = [:]
      mutLRUKeySeqList = []
    }
    persistor.resetPendingState()
  }

  /// 同時清除記憶體與磁碟上的快照與日誌。
  /// - Parameter fileURL: 可選的覆寫儲存位置 URL。
  nonisolated func clearData(withURL fileURL: URL? = nil) {
    clearData()
    persistor.clearDataOnDisk(fileURL: fileURL, dataProvider: { [] })
  }

  nonisolated public func getSavableData() -> [KeyPerceptionPair] {
    lock.withLock {
      mutLRUMap.values.sorted {
        $0.latestTimeStamp > $1.latestTimeStamp
      }
    }
  }

  nonisolated public func loadData(from data: [KeyPerceptionPair]) {
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
  nonisolated func saveData(toURL fileURL: URL? = nil, skipDebounce _: Bool = false) {
    persistor.saveData(
      dataProvider: { [self] in getSavableData() },
      mapProvider: { [self] in lock.withLock { mutLRUMap } },
      keyValidator: { [self] in !shouldIgnoreKey($0) },
      toURL: fileURL
    )
  }

  /// 從磁碟載入覆寫資料並重播未處理的日誌。
  /// - Parameter fileURL: 可選的載入路徑，覆寫預設位置。
  nonisolated func loadData(fromURL fileURL: URL? = nil) {
    persistor.loadData(
      loadCallback: { [self] in loadData(from: $0) },
      replayApplicator: { [self] tempMap, mutated in
        lock.withLock {
          for (key, pair) in tempMap {
            mutLRUMap[key] = pair
            mutated = true
          }
        }
      },
      keyValidator: { [self] in !shouldIgnoreKey($0) },
      fromURL: fileURL
    )
  }
}

// MARK: - Other Non-Public Internal Methods

extension LMAssembly.LXPerceptor {
  /// 判斷一個鍵是否為單漢字 (SegLength == 1)
  nonisolated private func isSegLengthOne(key: String) -> Bool {
    !key.contains("-")
  }

  // 解析 Perception Key 的健壯 parser（不用正則）。
  // 現行格式示例：(anteReading,anteValue)&(prevReading,prevValue)&(headReading,headValue)
  nonisolated struct PerceptionKeyParts {
    let headReading: String
    let headValue: String
    let previous: (reading: String, value: String)?
    let anterior: (reading: String, value: String)?
  }

  nonisolated func parsePerceptionKey(_ key: String) -> PerceptionKeyParts? {
    parseDelimitedPerceptionKey(key)
  }

  nonisolated private func parseDelimitedPerceptionKey(_ key: String) -> PerceptionKeyParts? {
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
    let previous = components.count >= 2 ? parseComponent(components[components.count - 2]) : nil
    let anterior = components.count >= 3 ? parseComponent(components[components.count - 3]) : nil

    return .init(
      headReading: headPair.reading,
      headValue: headPair.value,
      previous: previous,
      anterior: anterior
    )
  }

  nonisolated private func compareContextPart(
    _ lhs: (reading: String, value: String)?,
    _ rhs: (reading: String, value: String)?,
    separatorString: String
  )
    -> Bool {
    // 若原始（rhs）沒有上下文，則無論 lhs 為何都接受該候選。
    // 這允許短段候選（可能帶有額外的 previous/anterior 上下文）
    // 被視為多段原始的備選。
    if rhs == nil { return true }

    func splitSegments(_ reading: String) -> [String] {
      guard !separatorString.isEmpty else { return reading.isEmpty ? [] : [reading] }
      return reading.components(separatedBy: separatorString).filter { !$0.isEmpty }
    }

    func isSuffixContextMatch(
      _ candidate: (reading: String, value: String),
      within original: (reading: String, value: String)
    )
      -> Bool {
      let candidateSegments = splitSegments(candidate.reading)
      let originalSegments = splitSegments(original.reading)
      guard !candidateSegments.isEmpty, originalSegments.count > candidateSegments.count else {
        return false
      }
      guard Array(originalSegments.suffix(candidateSegments.count)) == candidateSegments else {
        return false
      }
      return original.value.hasSuffix(candidate.value)
    }

    switch (lhs, rhs) {
    case (.none, .none):
      return true
    case let (.some(lValue), .some(rValue)):
      if lValue.reading == rValue.reading, lValue.value == rValue.value { return true }
      return isSuffixContextMatch(lValue, within: rValue)
    default:
      return false
    }
  }

  nonisolated private func alternateKeys(for originalKey: String) -> [String] {
    guard let originalParts = parsePerceptionKey(originalKey) else { return [] }
    guard !shouldIgnorePerception(originalParts) else { return [] }
    let separatorString = Homa.Assembler.theSeparator
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
      guard compareContextPart(
        candidateParts.previous,
        originalParts.previous,
        separatorString: separatorString
      ) else { continue }
      guard compareContextPart(
        candidateParts.anterior,
        originalParts.anterior,
        separatorString: separatorString
      ) else { continue }
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
      // 若候選的 previous 與 head 串接後等於原始 head（例如切分候選
      // (B,B)&(C,C) 與原始 (BC,BC)），則視為匹配。
      let candidateCombinedHead: String = {
        if let prev = candidateParts.previous { return prev.reading + candidateParts.headReading }
        return candidateParts.headReading
      }()
      let matchesCombinedHead = candidateCombinedHead == originalParts.headReading

      // 處理 primary segment 配對的特例：
      // 當原始 head 有多個 segment，且候選為單段時，僅靠 primary segment 配對會導致
      // 單段候選插斷多段原始頭（例如原始為 B-C，但候選僅為 B）。為避免誤插斷，
      // 對於這種 single-seg primary match 我們會拒絕；例外情況為該候選同時提供且其
      // `previous` 與原始 `previous` 完全相同時，此時才接受（以保留測試案例「再創世的凱歌」的
      // short->long 使用情境）。
      let originalSegmentCount = headSegments.count
      let candidateSegmentCount = candidateHeadSegments.count

      let acceptMatch: Bool = {
        if matchesFullHead || matchesOriginalHead || matchesCombinedHead { return true }
        if matchesPrimaryHead {
          // 若原始 head 有多個 segment，且候選只有單段，僅靠 primary segment 配對可能會導致
          // 單段候選插斷多段原始頭（例如原始為 B-C，但候選僅為 B）。
          // 在此情況下，僅在候選提供與原始一致的 previous context 時才接受（可避免誤插斷
          // 同時保留 Saisouki 的 short->long 場景）。
          if originalSegmentCount > 1, candidateSegmentCount == 1 {
            if let cPrev = candidateParts.previous, let oPrev = originalParts.previous {
              if cPrev.reading == oPrev.reading, cPrev.value == oPrev.value { return true }
            }
            return false
          }
          return true
        }
        return false
      }()

      guard acceptMatch else { continue }

      if keyCandidate != originalKey {
        results.append(keyCandidate)
      }
    }
    return results
  }

  // 僅供單元測試使用：用於專門曝露替代 Key 的 API。
  nonisolated internal func alternateKeysForTesting(_ originalKey: String) -> [String] {
    alternateKeys(for: originalKey)
  }

  nonisolated private func forceHighScoreOverrideFlag(for key: String) -> Bool {
    guard let parts = parsePerceptionKey(key) else { return false }
    guard !shouldIgnorePerception(parts) else { return false }
    let separatorString = Homa.Assembler.theSeparator
    let headLen =
      separatorString.isEmpty
        ? (parts.headReading.isEmpty ? 0 : 1)
        : parts.headReading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    let previousLen = parts.previous.map { component in
      separatorString.isEmpty
        ? (component.reading.isEmpty ? 0 : 1)
        : component.reading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    }
    let anteriorLen = parts.anterior.map { component in
      separatorString.isEmpty
        ? (component.reading.isEmpty ? 0 : 1)
        : component.reading.components(separatedBy: separatorString).filter { !$0.isEmpty }.count
    }

    if headLen > 1 {
      if let previousLen, previousLen == 1 {
        if let anteriorLen {
          return anteriorLen == 1
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
  nonisolated internal func calculateWeight(
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

    // 調整有效視窗 wT，單字略快、單讀音單漢字再快一些（避免單字長期壓制）
    // 根據偏好設定決定基礎時間窗 wT：如果啟用急速遺忘模式，則從約一週降低至 12 小時內
    var wT: Double = reducedLifetime ? 0.5 : 8.0
    if isUnigram { wT *= 0.85 }
    if isSingleCharUnigram { wT *= 0.8 }

    // 超過或抵達視窗即淘汰
    if daysDiff >= wT { return threshold - 0.001 }

    // 年齡因子（非半衰）：線性核 + 指數 pAge（pAge>1 時較快衰減）
    let pAge = 2.0
    let ageNorm = max(0.0, 1.0 - (daysDiff / wT))
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

  nonisolated static func isPunctuation(_ node: Homa.GramInPath) -> Bool {
    for key in node.keyArray {
      guard let firstChar = key.first else { continue }
      return String(firstChar) == "_"
    }
    return false
  }

  nonisolated private func shouldIgnorePerception(_ parts: PerceptionKeyParts) -> Bool {
    let readings = [parts.headReading, parts.previous?.reading, parts.anterior?.reading]
      .compactMap { $0 }
    return readings.contains { containsUnderscorePrefixedReading($0) }
  }

  nonisolated private func shouldIgnoreKey(_ key: String) -> Bool {
    guard let parts = parsePerceptionKey(key) else { return false }
    return shouldIgnorePerception(parts)
  }

  nonisolated private func containsUnderscorePrefixedReading(_ reading: String) -> Bool {
    readingSegments(from: reading).contains { $0.hasPrefix("_") }
  }

  nonisolated private func readingSegments(from reading: String) -> [String] {
    let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let separator = Homa.Assembler.theSeparator
    if separator.isEmpty { return [trimmed] }
    return trimmed
      .components(separatedBy: separator)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  nonisolated private func purgeUnderscorePrefixedKeys() {
    let invalidKeys = mutLRUMap.keys.filter { shouldIgnoreKey($0) }
    guard !invalidKeys.isEmpty else { return }
    invalidKeys.forEach { mutLRUMap.removeValue(forKey: $0) }
  }
}

// MARK: - POMError

nonisolated struct POMError: LocalizedError {
  nonisolated var rawValue: String

  nonisolated var errorDescription: String? {
    "rawValue".i18n
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
  nonisolated fileprivate static let naturalE: Double = {
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
  nonisolated fileprivate static let naturalPi: Double = {
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
  nonisolated fileprivate static func getBeastConstantUsingTadokoroFormula() -> Double {
    let e = naturalE
    let pi = naturalPi

    let part1 = e * pow((e + pi) * (e + e + pi), e)
    let part2 = (e / (pow(pi, e) - e)) / (e + pow(e, pi) - pow(pi, e))

    let result = part1 + part2
    return (result * pow(10, 7)).rounded(.up) / pow(10, 13)
  }
}
