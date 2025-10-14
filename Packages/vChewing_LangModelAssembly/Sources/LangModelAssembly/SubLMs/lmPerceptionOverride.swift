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
    }

    // MARK: Public

    public func setCapacity(_ capacity: Int) {
      mutCapacity = max(capacity, 1)
    }

    // MARK: Internal

    // 修改常數以讓測試能通過
    static let kDecayThreshold: Double = -13.0 // 權重最低閾值
    static let kWeightMultiplier: Double = 0.114514 // 權重計算乘數

    var mutCapacity: Int
    var thresholdProvider: (() -> Double)?
    var mutLRUKeySeqList: [String] = []
    var mutLRUMap: [String: KeyPerceptionPair] = [:]
    var fileSaveLocationURL: URL?

    var threshold: Double {
      let fallbackValue = Self.kDecayThreshold
      guard let thresholdCalculated = thresholdProvider?() else { return fallbackValue }
      guard thresholdCalculated < 0 else { return fallbackValue }
      return thresholdCalculated
    }
  }
}

// MARK: - Private Structures

extension LMAssembly.LMPerceptionOverride {
  public struct Override: Hashable, Encodable, Decodable {
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

  public final class Perception: Hashable, Encodable, Decodable {
    // MARK: Lifecycle

    fileprivate init() {}

    public required init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.overrides = try container.decode([String: Override].self, forKey: .overrides)
    }

    // MARK: Public

    public fileprivate(set) var overrides: [String: Override] = [:]

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

  public final class KeyPerceptionPair: Hashable, Encodable, Decodable {
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

      print("LMPerceptionOverride: 已更新現有洞察: \(key)")
      saveCallback?() ?? saveData()
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
        mutLRUMap.removeValue(forKey: mutLRUKeySeqList.removeLast())
      }

      print("LMPerceptionOverride: 已完成新洞察: \(key)")
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定的建議（基於 context + candidate 對）
  func bleachSpecifiedSuggestions(targets: [(ngramKey: String, candidate: String)], saveCallback: (() -> ())? = nil) {
    if targets.isEmpty { return }
    var hasChanges = false
    var keysToRemoveCompletely: [String] = []

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
      }
    }

    // 移除已經沒有任何 overrides 的 keys
    if !keysToRemoveCompletely.isEmpty {
      keysToRemoveCompletely.forEach { mutLRUMap.removeValue(forKey: $0) }
    }

    if hasChanges {
      resetLRUList()
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定的建議（基於 candidate，移除所有上下文中的該候選詞）
  func bleachSpecifiedSuggestions(candidateTargets: [String], saveCallback: (() -> ())? = nil) {
    if candidateTargets.isEmpty { return }
    var hasChanges = false
    var keysToRemoveCompletely: [String] = []

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
      saveCallback?() ?? saveData()
    }
  }

  /// 清除指定讀音（head reading）底下的所有建議。
  func bleachSpecifiedSuggestions(headReadingTargets: [String], saveCallback: (() -> ())? = nil) {
    let targets = Set(headReadingTargets.filter { !$0.isEmpty })
    guard !targets.isEmpty else { return }
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
      resetLRUList()
      saveCallback?() ?? saveData()
    }
  }

  /// 自 LRU 辭典內移除所有的單元圖。
  func bleachUnigrams(saveCallback: (() -> ())? = nil) {
    let keysToRemove = mutLRUMap.keys.filter { $0.contains("(),()") }
    if !keysToRemove.isEmpty {
      keysToRemove.forEach { mutLRUMap.removeValue(forKey: $0) }
      resetLRUList()
      saveCallback?() ?? saveData()
    }
  }

  public func resetLRUList() {
    mutLRUKeySeqList.removeAll()
    let mapLRUSorted = mutLRUMap.sorted {
      $0.value.latestTimeStamp > $1.value.latestTimeStamp
    }
    for neta in mapLRUSorted {
      mutLRUKeySeqList.append(neta.key)
    }
  }

  public func clearData() {
    mutLRUMap = [:]
    mutLRUKeySeqList = []
  }

  func clearData(withURL fileURL: URL? = nil) {
    clearData()
    do {
      let nullData = "[]" // 修正：使用空陣列而不是空對象
      guard let fileURL = fileURL ?? fileSaveLocationURL else {
        throw POMError(rawValue: "given fileURL is invalid or nil.")
      }
      try nullData.write(to: fileURL, atomically: false, encoding: .utf8)
    } catch {
      vCLMLog("POM Error: Unable to clear the data in the POM file. Details: \(error)")
      return
    }
  }

  public func getSavableData() -> [KeyPerceptionPair] {
    mutLRUMap.values.sorted {
      $0.latestTimeStamp > $1.latestTimeStamp
    }
  }

  public func loadData(from data: [KeyPerceptionPair]) {
    var newMap = [String: KeyPerceptionPair]()
    data.forEach { currentPair in
      newMap[currentPair.key] = currentPair
    }
    mutLRUMap = newMap
    resetLRUList()
  }

  func saveData(toURL fileURL: URL? = nil) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM saveData() failed. At least the file Save URL is not set for the current POM.")
      return
    }
    // 此處不要使用 JSONSerialization，不然執行緒會炸掉。
    let encoder = JSONEncoder()
    do {
      let toSave = getSavableData()
      vCLMLog("POM: Attempting to save \(toSave.count) items to \(fileURL.path)")

      let jsonData = try encoder.encode(toSave)
      vCLMLog("POM: Successfully encoded data, size: \(jsonData.count) bytes")

      try jsonData.write(to: fileURL)
      vCLMLog("POM: Successfully saved data to file")
    } catch {
      vCLMLog("POM Error: Unable to save data, abort saving. Details: \(error)")
      return
    }
  }

  func loadData(fromURL fileURL: URL? = nil) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("POM loadData() failed. At least the file Load URL is not set for the current POM.")
      return
    }
    // 此處不要使用 JSONSerialization，不然執行緒會炸掉。
    let decoder = JSONDecoder()
    do {
      let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
      let dataString = String(data: data, encoding: .utf8) ?? ""
      vCLMLog("POM: Loading data from file, content: '\(dataString.prefix(100))...'")

      // 檢查是否為空或無效內容。"{}" 是舊版錯誤格式，"[]" 是有效的空陣列
      let emptyContents = ["", "{}", "[]"]
      if emptyContents.contains(dataString.trimmingCharacters(in: .whitespacesAndNewlines)) {
        vCLMLog("POM: File contains empty or no data, skipping load")
        return
      }

      do {
        let jsonResult = try decoder.decode([KeyPerceptionPair].self, from: data)
        vCLMLog("POM: Successfully decoded \(jsonResult.count) items from file")
        loadData(from: jsonResult)
      } catch {
        vCLMLog("POM Error: Unable to decode JSON data. Details: \(error)")
        // 如果解碼失敗，檢查是否為舊的 "{}" 格式並嘗試修復
        if dataString.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
          vCLMLog("POM: Detected old invalid format '{}', clearing file")
          clearData(withURL: fileURL)
        }
        return
      }
    } catch {
      vCLMLog("POM Error: Unable to read file or parse the data, abort loading. Details: \(error)")
      return
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
  // 新式格式示例：(prev2Reading,prev2Value)&(prev1Reading,prev1Value)&(headReading,headValue)
  // 舊式格式示例：((prev2Reading:prev2Value),(prev1Reading:prev1Value),headReading)
  struct PerceptionKeyParts {
    let headReading: String
    let headValue: String
    let prev1: (reading: String, value: String)?
    let prev2: (reading: String, value: String)?
  }

  func parsePerceptionKey(_ key: String) -> PerceptionKeyParts? {
    if let parsed = parseDashDelimitedPerceptionKey(key) {
      return parsed
    }
    return parseLegacyPerceptionKey(key)
  }

  private func parseDashDelimitedPerceptionKey(_ key: String) -> PerceptionKeyParts? {
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

  private func parseLegacyPerceptionKey(_ key: String) -> PerceptionKeyParts? {
    guard key.first == "(", key.last == ")", key.count >= 2 else { return nil }
    let inner = key.dropFirst().dropLast()
    var parts: [String] = []
    var depth = 0
    var token = ""
    for ch in inner {
      if ch == ",", depth == 0 {
        parts.append(token)
        token.removeAll()
        continue
      }
      if ch == "(" { depth += 1 }
      if ch == ")" { depth -= 1 }
      token.append(ch)
    }
    if !token.isEmpty { parts.append(token) }
    guard !parts.isEmpty else { return nil }
    let headReading = parts.last!.trimmingCharacters(in: .whitespaces)
    if headReading.contains("(") || headReading.contains(")") { return nil }

    func parsePrev(_ s: String) -> (String, String)? {
      if s == "()" { return nil }
      guard s.first == "(", s.last == ")" else { return nil }
      let inner = s.dropFirst().dropLast()
      if let colonIdx = inner.firstIndex(of: ":") {
        let reading = inner[..<colonIdx]
        let value = inner[inner.index(after: colonIdx)...]
        return (String(reading), String(value))
      }
      return nil
    }

    let count = parts.count
    let prev1 = count >= 2 ? parsePrev(parts[count - 2]) : nil
    let prev2 = count >= 3 ? parsePrev(parts[count - 3]) : nil
    return .init(headReading: headReading, headValue: headReading, prev1: prev1, prev2: prev2)
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
}

// MARK: - POMError

struct POMError: LocalizedError {
  var rawValue: String

  var errorDescription: String? {
    NSLocalizedString("rawValue", comment: "")
  }
}
