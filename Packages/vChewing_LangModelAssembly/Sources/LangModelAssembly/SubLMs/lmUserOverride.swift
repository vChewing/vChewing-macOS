// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the Cpp version of this class by Lukhnos Liu (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez

// MARK: - LMAssembly.OverrideSuggestion

extension LMAssembly {
  public struct OverrideSuggestion {
    public var candidates = [(String, Megrez.Unigram)]()
    public var forceHighScoreOverride = false

    public var isEmpty: Bool { candidates.isEmpty }
  }
}

// MARK: - LMAssembly.LMUserOverride

extension LMAssembly {
  class LMUserOverride {
    // MARK: Lifecycle

    init(
      capacity: Int = 500,
      decayConstant: Double = LMUserOverride.kObservedOverrideHalfLife,
      dataURL: URL? = nil
    ) {
      self.mutCapacity = max(capacity, 1) // Ensures that this integer value is always > 0.
      self.mutDecayExponent = log(0.5) / decayConstant
      self.fileSaveLocationURL = dataURL
    }

    // MARK: Internal

    static let kObservedOverrideHalfLife: Double = 3_600.0 * 6 // 6 小時半衰一次，能持續不到六天的記憶。

    var mutCapacity: Int
    var mutDecayExponent: Double
    var mutLRUList: [KeyObservationPair] = []
    var mutLRUMap: [String: KeyObservationPair] = [:]
    let kDecayThreshold: Double = 1.0 / 1_048_576.0 // 衰減二十次之後差不多就失效了。
    var fileSaveLocationURL: URL?
  }
}

// MARK: - Private Structures

extension LMAssembly.LMUserOverride {
  enum OverrideUnit: CodingKey { case count, timestamp, forceHighScoreOverride }
  enum ObservationUnit: CodingKey { case count, overrides }
  enum KeyObservationPairUnit: CodingKey { case key, observation }

  struct Override: Hashable, Encodable, Decodable {
    var count: Int = 0
    var timestamp: Double = 0.0
    var forceHighScoreOverride = false

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.count == rhs.count && lhs.timestamp == rhs.timestamp
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: OverrideUnit.self)
      try container.encode(count, forKey: .count)
      try container.encode(timestamp, forKey: .timestamp)
      try container.encode(forceHighScoreOverride, forKey: .forceHighScoreOverride)
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(count)
      hasher.combine(timestamp)
      hasher.combine(forceHighScoreOverride)
    }
  }

  struct Observation: Hashable, Encodable, Decodable {
    var count: Int = 0
    var overrides: [String: Override] = [:]

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.count == rhs.count && lhs.overrides == rhs.overrides
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: ObservationUnit.self)
      try container.encode(count, forKey: .count)
      try container.encode(overrides, forKey: .overrides)
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(count)
      hasher.combine(overrides)
    }

    mutating func update(
      candidate: String,
      timestamp: Double,
      forceHighScoreOverride: Bool = false
    ) {
      count += 1
      if overrides.keys.contains(candidate) {
        overrides[candidate]?.timestamp = timestamp
        overrides[candidate]?.count += 1
        overrides[candidate]?.forceHighScoreOverride = forceHighScoreOverride
      } else {
        overrides[candidate] = .init(count: 1, timestamp: timestamp)
      }
    }
  }

  struct KeyObservationPair: Hashable, Encodable, Decodable {
    var key: String
    var observation: Observation

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.key == rhs.key && lhs.observation == rhs.observation
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: KeyObservationPairUnit.self)
      try container.encode(key, forKey: .key)
      try container.encode(observation, forKey: .observation)
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(observation)
    }
  }
}

// MARK: - Internal Methods in LMAssembly.

extension Array where Element == Megrez.Node {
  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  ///   - outCursorPastNode: 找出的節點的前端位置。
  /// - Returns: 查找結果。
  public func findNodeWithRange(at cursor: Int) -> (node: Megrez.Node, range: Range<Int>)? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    guard let rearNodeID = cursorRegionMap[cursor] else { return nil }
    guard count - 1 >= rearNodeID else { return nil }
    return (self[rearNodeID], range)
  }
}

extension LMAssembly.LMUserOverride {
  @discardableResult
  func performObservation(
    walkedBefore: [Megrez.Node], walkedAfter: [Megrez.Node],
    cursor: Int, timestamp: Double, saveCallback: (() -> ())? = nil
  )
    -> (key: String, candidate: String)? {
    // 參數合規性檢查。
    let countBefore = walkedBefore.totalKeyCount
    let countAfter = walkedAfter.totalKeyCount
    guard countBefore == countAfter, countBefore * countAfter > 0 else { return nil }
    // 先判斷用哪種覆寫方法。
    let currentNodeResult = walkedAfter.findNodeWithRange(at: cursor)
    guard let currentNodeResult else { return nil }
    let currentNode = currentNodeResult.node
    // 當前節點超過三個字的話，就不記憶了。在這種情形下，使用者可以考慮新增自訂語彙。
    guard currentNode.spanLength <= 3 else { return nil }
    // 前一個節點得從前一次爬軌結果當中來找。
    guard currentNodeResult.range.upperBound > 0 else { return nil } // 該例外應該不會出現。
    let prevNodeResult = walkedBefore.findNodeWithRange(at: currentNodeResult.range.upperBound - 1)
    guard let prevNodeResult else { return nil }
    let prevNode = prevNodeResult.node
    // 此處不宜僅比較 spanLength 長短差異，否則可能會生成無效的洞察 Key。
    // 錯誤範例：`let breakingUp = currentNode.spanLength == 1 && prevNode.spanLength > 1`。
    // 會生成這種錯誤結果：`"((liu2:留),(yi4-lv3:一縷),fang1)", "一縷"`。
    // 對洞察 key 有效性的判斷鐵則：給出的建議候選字詞的讀音必須與洞察 key 的 head 端的讀音完全一致。
    // 正確範例：`"((neng2:能),(liu2:留),yi4-lv3)", "一縷"`。
    let currentNodeScope = currentNodeResult.range
    let prevNodeScope = prevNodeResult.range
    let scopeChanged = currentNodeScope != prevNodeScope
    let forceHighScoreOverride: Bool = currentNode.spanLength > prevNode.spanLength
    let targetNodeIndex = scopeChanged ? currentNodeScope.upperBound : prevNodeScope.upperBound
    let key: String = LMAssembly.LMUserOverride.formObservationKey(
      walkedNodes: walkedAfter, headIndex: targetNodeIndex
    )
    guard !key.isEmpty else { return nil }
    doObservation(
      key: key, candidate: currentNode.currentUnigram.value, timestamp: timestamp,
      forceHighScoreOverride: forceHighScoreOverride, saveCallback: saveCallback
    )
    return (key, currentNode.value)
  }

  func fetchSuggestion(
    currentWalk: [Megrez.Node], cursor: Int, timestamp: Double
  )
    -> LMAssembly.OverrideSuggestion {
    var headIndex = 0
    guard let nodeIter = currentWalk.findNode(at: cursor, target: &headIndex)
    else { return .init() }
    let key = LMAssembly.LMUserOverride.formObservationKey(
      walkedNodes: currentWalk,
      headIndex: headIndex
    )
    return getSuggestion(key: key, timestamp: timestamp, headReading: nodeIter.joinedKey())
  }

  func bleachSpecifiedSuggestions(targets: [String], saveCallback: (() -> ())? = nil) {
    if targets.isEmpty { return }
    for neta in mutLRUMap {
      for target in targets {
        if neta.value.observation.overrides.keys.contains(target) {
          mutLRUMap.removeValue(forKey: neta.key)
        }
      }
    }
    resetMRUList()
    saveCallback?() ?? saveData()
  }

  /// 自 LRU 辭典內移除所有的單元圖。
  func bleachUnigrams(saveCallback: (() -> ())? = nil) {
    for key in mutLRUMap.keys {
      if !key.contains("(),()") { continue }
      mutLRUMap.removeValue(forKey: key)
    }
    resetMRUList()
    saveCallback?() ?? saveData()
  }

  func resetMRUList() {
    mutLRUList.removeAll()
    for neta in mutLRUMap.reversed() {
      mutLRUList.append(neta.value)
    }
  }

  func clearData(withURL fileURL: URL? = nil) {
    mutLRUMap = .init()
    mutLRUList = .init()
    do {
      let nullData = "{}"
      guard let fileURL = fileURL ?? fileSaveLocationURL else {
        throw UOMError(rawValue: "given fileURL is invalid or nil.")
      }
      try nullData.write(to: fileURL, atomically: false, encoding: .utf8)
    } catch {
      vCLMLog("UOM Error: Unable to clear the data in the UOM file. Details: \(error)")
      return
    }
  }

  func saveData(toURL fileURL: URL? = nil) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("UOM saveData() failed. At least the file Save URL is not set for the current UOM.")
      return
    }
    // 此處不要使用 JSONSerialization，不然執行緒會炸掉。
    let encoder = JSONEncoder()
    do {
      guard let jsonData = try? encoder.encode(mutLRUMap) else { return }
      try jsonData.write(to: fileURL, options: .atomic)
    } catch {
      vCLMLog("UOM Error: Unable to save data, abort saving. Details: \(error)")
      return
    }
  }

  func loadData(fromURL fileURL: URL? = nil) {
    guard let fileURL: URL = fileURL ?? fileSaveLocationURL else {
      vCLMLog("UOM loadData() failed. At least the file Load URL is not set for the current UOM.")
      return
    }
    // 此處不要使用 JSONSerialization，不然執行緒會炸掉。
    let decoder = JSONDecoder()
    do {
      let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
      if ["", "{}"].contains(String(data: data, encoding: .utf8)) { return }
      guard let jsonResult = try? decoder.decode([String: KeyObservationPair].self, from: data)
      else {
        vCLMLog("UOM Error: Read file content type invalid, abort loading.")
        return
      }
      mutLRUMap = jsonResult
      resetMRUList()
    } catch {
      vCLMLog("UOM Error: Unable to read file or parse the data, abort loading. Details: \(error)")
      return
    }
  }
}

// MARK: - Other Non-Public Internal Methods

extension LMAssembly.LMUserOverride {
  func doObservation(
    key: String, candidate: String, timestamp: Double, forceHighScoreOverride: Bool,
    saveCallback: (() -> ())?
  ) {
    guard mutLRUMap[key] != nil else {
      var observation: Observation = .init()
      observation.update(
        candidate: candidate,
        timestamp: timestamp,
        forceHighScoreOverride: forceHighScoreOverride
      )
      let koPair = KeyObservationPair(key: key, observation: observation)
      // 先移除 key 再設定 key 的話，就可以影響這個 key 在辭典內的順位。
      // Swift 原生的辭典是沒有數字索引排序的，但資料的插入順序卻有保存著。
      mutLRUMap.removeValue(forKey: key)
      mutLRUMap[key] = koPair
      mutLRUList.insert(koPair, at: 0)

      if mutLRUList.count > mutCapacity {
        mutLRUMap.removeValue(forKey: mutLRUList[mutLRUList.endIndex - 1].key)
        mutLRUList.removeLast()
      }
      vCLMLog("UOM: Observation finished with new observation: \(key)")
      saveCallback?() ?? saveData()
      return
    }
    // 這裡還是不要做 decayCallback 判定「是否不急著更新觀察」了，不然會在嘗試覆寫掉錯誤的記憶時失敗。
    if var theNeta = mutLRUMap[key] {
      theNeta.observation.update(
        candidate: candidate, timestamp: timestamp, forceHighScoreOverride: forceHighScoreOverride
      )
      mutLRUList.insert(theNeta, at: 0)
      mutLRUMap[key] = theNeta
      vCLMLog("UOM: Observation finished with existing observation: \(key)")
      saveCallback?() ?? saveData()
    }
  }

  func getSuggestion(key: String, timestamp: Double, headReading: String) -> LMAssembly
    .OverrideSuggestion {
    guard !key.isEmpty, let kvPair = mutLRUMap[key] else { return .init() }
    let observation: Observation = kvPair.observation
    var candidates: [(String, Megrez.Unigram)] = .init()
    var forceHighScoreOverride = false
    var currentHighScore: Double = 0
    for (i, theObservation) in observation.overrides {
      // 對 Unigram 只給大約六小時的半衰期。
      let isUnigramKey = key.contains("(),(),")
      var decayExp = mutDecayExponent * (isUnigramKey ? 24 : 1)
      // 對於單漢字 Unigram，讓半衰期繼續除以 12。
      if isUnigramKey,
         !key.replacingOccurrences(of: "(),(),", with: "").contains("-") { decayExp *= 12 }
      let overrideScore = getScore(
        eventCount: theObservation.count, totalCount: observation.count,
        eventTimestamp: theObservation.timestamp, timestamp: timestamp, lambda: decayExp
      )
      if (0 ... currentHighScore).contains(overrideScore) { continue }

      candidates.append((headReading, .init(value: i, score: overrideScore)))
      forceHighScoreOverride = theObservation.forceHighScoreOverride
      currentHighScore = overrideScore
    }
    return .init(candidates: candidates, forceHighScoreOverride: forceHighScoreOverride)
  }

  func getScore(
    eventCount: Int,
    totalCount: Int,
    eventTimestamp: Double,
    timestamp: Double,
    lambda: Double
  )
    -> Double {
    let decay = exp((timestamp - eventTimestamp) * lambda)
    if decay < kDecayThreshold { return 0.0 }
    let prob = Double(eventCount) / Double(totalCount)
    return prob * decay
  }

  static func isPunctuation(_ node: Megrez.Node) -> Bool {
    for key in node.keyArray {
      guard let firstChar = key.first else { continue }
      return String(firstChar) == "_"
    }
    return false
  }

  static func formObservationKey(
    walkedNodes: [Megrez.Node], headIndex cursorIndex: Int, readingOnly: Bool = false
  )
    -> String {
    // let whiteList = "你他妳她祢衪它牠再在"
    var arrNodes: [Megrez.Node] = []
    var intLength = 0
    for theNodeAnchor in walkedNodes {
      arrNodes.append(theNodeAnchor)
      intLength += theNodeAnchor.spanLength
      if intLength >= cursorIndex {
        break
      }
    }

    if arrNodes.isEmpty { return "" }

    arrNodes = Array(arrNodes.reversed())

    let kvCurrent = arrNodes[0].currentPair
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
      let maybeKvPrevious = arrNodes[1].currentPair
      if checkKeyValueValidityInThisContext(maybeKvPrevious) {
        kvPrevious = maybeKvPrevious
        readingStack = kvPrevious.joinedKey() + readingStack
      }
    }

    if arrNodes.count >= 3 {
      let maybeKvAnterior = arrNodes[2].currentPair
      if checkKeyValueValidityInThisContext(maybeKvAnterior) {
        kvAnterior = maybeKvAnterior
        readingStack = kvAnterior.joinedKey() + readingStack
      }
    }

    return result
  }
}

// MARK: - UOMError

struct UOMError: LocalizedError {
  var rawValue: String

  var errorDescription: String? {
    NSLocalizedString("rawValue", comment: "")
  }
}
