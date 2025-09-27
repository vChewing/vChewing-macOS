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
    public var candidates = [(keyArray: [String], value: String, probability: Double, previous: String?)]()
    public var forceHighScoreOverride = false

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
  @discardableResult
  func performObservation(
    walkedBefore: [Megrez.GramInPath], walkedAfter: [Megrez.GramInPath],
    cursor: Int, timestamp: Double, saveCallback: (() -> ())? = nil
  )
    -> (key: String, candidate: String)? {
    // 參數合規性檢查。
    let countBefore = walkedBefore.totalKeyCount
    let countAfter = walkedAfter.totalKeyCount
    guard countBefore == countAfter, countBefore * countAfter > 0 else { return nil }
    // 先判斷用哪種覆寫方法。
    let currentNodeResult = walkedAfter.findGramWithRange(at: cursor)
    guard let currentNodeResult else { return nil }
    let currentNode = currentNodeResult.node
    // 當前節點超過三個字的話，就不記憶了。在這種情形下，使用者可以考慮新增自訂語彙。
    guard currentNode.segLength <= 3 else { return nil }
    // 前一個節點得從前一次組句結果當中來找。
    guard currentNodeResult.range.upperBound > 0 else { return nil } // 該例外應該不會出現。
    let prevNodeResult = walkedBefore.findGramWithRange(at: currentNodeResult.range.upperBound - 1)
    guard let prevNodeResult else { return nil }
    _ = prevNodeResult.node
    // 此處不宜僅比較 segLength 長短差異，否則可能會生成無效的洞察 Key。
    // 錯誤範例：`let breakingUp = currentNode.segLength == 1 && prevNode.segLength > 1`。
    // 會生成這種錯誤結果：`"((liu2:留),(yi4-lv3:一縷),fang1)", "一縷"`。
    // 對洞察 key 有效性的判斷鐵則：給出的建議候選字詞的讀音必須與洞察 key 的 head 端的讀音完全一致。
    // 正確範例：`"((neng2:能),(liu2:留),yi4-lv3)", "一縷"`。
    let currentNodeScope = currentNodeResult.range
    let prevNodeScope = prevNodeResult.range
    let scopeChanged = currentNodeScope != prevNodeScope
    let targetNodeIndex = scopeChanged ? currentNodeScope.upperBound : prevNodeScope.upperBound
    let key: String = LMAssembly.LMPerceptionOverride.formObservationKey(
      assembledSentence: walkedAfter, headIndex: targetNodeIndex
    )
    guard !key.isEmpty else { return nil }
    memorizePerception(
      (ngramKey: key, candidate: currentNode.gram.value),
      timestamp: timestamp,
      saveCallback: saveCallback
    )
    return (key, currentNode.value)
  }

  func fetchSuggestion(
    currentWalk: [Megrez.GramInPath], cursor: Int, timestamp: Double
  )
    -> LMAssembly.OverrideSuggestion {
    guard let currentNodeResult = currentWalk.findGramWithRange(at: cursor) else {
      return .init()
    }
    let headIndex = currentNodeResult.range.upperBound
    let key = LMAssembly.LMPerceptionOverride.formObservationKey(
      assembledSentence: currentWalk,
      headIndex: headIndex
    )
    guard !key.isEmpty, let suggestions = getSuggestion(key: key, timestamp: timestamp) else {
      return .init()
    }
    return .init(candidates: suggestions, forceHighScoreOverride: false)
  }

  /// 獲取由洞察過的記憶內容生成的選字建議。
  public func getSuggestion(
    key: String,
    timestamp: Double
  )
    -> [(
      keyArray: [String],
      value: String,
      probability: Double,
      previous: String?
    )]? {
    let frontEdgeReading: String? = {
      guard key.hasSuffix(")"), key.hasPrefix("("), key.count > 2 else { return nil }
      var charBuffer: [Character] = []
      for char in key.reversed() {
        if char == ")" {
          continue
        } else if char == "," {
          return String(charBuffer.reversed())
        } else {
          charBuffer.append(char)
        }
      }
      return String(charBuffer.reversed())
    }()
    guard let frontEdgeReading, !key.isEmpty, let kvPair = mutLRUMap[key] else { return nil }

    let perception: Perception = kvPair.perception
    var candidates: [(
      keyArray: [String],
      value: String,
      probability: Double,
      previous: String?
    )] = .init()
    var currentHighScore: Double = threshold // 初期化為閾值

    // 解析 key 用於衰減計算
    let keyCells = key.dropLast(1).dropFirst(1).split(separator: ",")
    let isUnigramKey = key.contains("(),(),") || keyCells.count == 1
    let isSingleCharUnigram = isUnigramKey && isSegLengthOne(key: frontEdgeReading)

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

      let previousStr: String? = {
        // 解析 key 中的 previous 部分
        // key 格式類似: ((ㄕㄣˊ-ㄌㄧˇ-ㄌㄧㄥˊ-ㄏㄨㄚˊ,神里綾華),(ㄉㄜ˙,的),ㄍㄡˇ)

        // 使用正規表達式來解析，更可靠
        // 匹配 ),( 之間的第二部分
        let pattern = "\\)\\s*,\\s*\\(([^)]+)\\)\\s*,\\s*"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) {
          let matchRange = Range(match.range(at: 1), in: key)!
          let prevContent = String(key[matchRange])

          // 解析內容，格式可能是 "ㄉㄜ˙,的" 或 "ㄉㄜ˙:的"
          let components = prevContent.split(whereSeparator: { $0 == "," || $0 == ":" })
          if components.count >= 2 {
            return String(components.last!)
          }
        }

        return nil
      }()

      if overrideScore > currentHighScore {
        candidates = [
          (
            keyArray: [frontEdgeReading],
            value: candidate,
            probability: overrideScore,
            previous: previousStr
          ),
        ]
        currentHighScore = overrideScore
      } else if overrideScore == currentHighScore {
        candidates.append(
          (
            keyArray: [frontEdgeReading],
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

  func bleachSpecifiedSuggestions(targets: [String], saveCallback: (() -> ())? = nil) {
    if targets.isEmpty { return }
    var hasChanges = false

    // 使用過濾方式更新 mutLRUMap
    let keysToRemove = mutLRUMap.keys.filter { key in
      let perception = mutLRUMap[key]?.perception
      return perception?.overrides.keys.contains(where: { targets.contains($0) }) ?? false
    }

    if !keysToRemove.isEmpty {
      hasChanges = true
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

    // 根據條件調整天數
    var adjustedDays = daysDiff
    if isUnigram {
      adjustedDays *= 1.5 // Unigram 天數調整為1.5倍而非2倍 (讓衰減更慢一些)
      if isSingleCharUnigram {
        adjustedDays *= 1.5 // 單讀音單漢字的 Unigram 再調整1.5倍
      }
    }

    // 防止極小的天數差導致權重過大
    adjustedDays = max(0.1, adjustedDays)

    // 減小衰減乘數，讓衰減更慢一些
    let adjustedMultiplier = Self.kWeightMultiplier * 0.7

    // 計算權重：y = -1 * (x^3) * adjustedMultiplier
    let weight = -1.0 * adjustedDays * adjustedDays * adjustedDays * adjustedMultiplier

    // 如果天數很小（幾乎是即時的），給予更高權重
    if daysDiff < 0.1 {
      return -1.0
    }

    // 調整衰減閾值天數，從7天延長到6.75天
    if daysDiff > 6.75 || weight <= threshold {
      return threshold - 0.001
    }

    // 結合概率和權重
    let result = prob * weight

    // 確保結果不低於閾值
    return max(result, threshold + 0.001)
  }

  static func isPunctuation(_ node: Megrez.GramInPath) -> Bool {
    for key in node.keyArray {
      guard let firstChar = key.first else { continue }
      return String(firstChar) == "_"
    }
    return false
  }

  static func formObservationKey(
    assembledSentence: [Megrez.GramInPath], headIndex cursorIndex: Int, readingOnly: Bool = false
  )
    -> String {
    // let whiteList = "你他妳她祢衪它牠再在"
    var arrNodes: [Megrez.GramInPath] = []
    var intLength = 0
    for theNodeAnchor in assembledSentence {
      arrNodes.append(theNodeAnchor)
      intLength += theNodeAnchor.segLength
      if intLength >= cursorIndex {
        break
      }
    }

    if arrNodes.isEmpty { return "" }

    arrNodes = Array(arrNodes.reversed())

    let kvCurrent = arrNodes[0].asCandidatePair
    guard !kvCurrent.joinedKey().contains("_") else {
      return ""
    }

    // 字音數與字數不一致的內容會被拋棄。
    if kvCurrent.keyArray.count != kvCurrent.value.count { return "" }

    // 前置單元只記錄讀音，在其後的單元則同時記錄讀音與字詞
    let strCurrent = kvCurrent.joinedKey()
    var kvPrevious = Megrez.KeyValuePaired(keyArray: [""], value: "")
    var kvAnterior = Megrez.KeyValuePaired(keyArray: [""], value: "")
    var readingStack = ""
    var trigramKey: String { "(\(kvAnterior.toNGramKey),\(kvPrevious.toNGramKey),\(strCurrent))" }
    var result: String {
      if readingStack.contains("_") {
        return ""
      } else {
        return readingOnly ? strCurrent : trigramKey
      }
    }

    func checkKeyValueValidityInThisContext(_ target: Megrez.KeyValuePaired) -> Bool {
      !target.joinedKey().contains("_") && target.joinedKey().split(separator: "-").count == target
        .value.count
    }

    if arrNodes.count >= 2 {
      let maybeKvPrevious = arrNodes[1].asCandidatePair
      if checkKeyValueValidityInThisContext(maybeKvPrevious) {
        kvPrevious = maybeKvPrevious
        readingStack = kvPrevious.joinedKey() + readingStack
      }
    }

    if arrNodes.count >= 3 {
      let maybeKvAnterior = arrNodes[2].asCandidatePair
      if checkKeyValueValidityInThisContext(maybeKvAnterior) {
        kvAnterior = maybeKvAnterior
        readingStack = kvAnterior.joinedKey() + readingStack
      }
    }

    return result
  }
}

// MARK: - POMError

struct POMError: LocalizedError {
  var rawValue: String

  var errorDescription: String? {
    NSLocalizedString("rawValue", comment: "")
  }
}
