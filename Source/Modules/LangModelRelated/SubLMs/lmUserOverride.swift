// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the Cpp version of this class by Mengjuei Hsieh (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension vChewing {
  public class LMUserOverride {
    // MARK: - Main

    var mutCapacity: Int
    var mutDecayExponent: Double
    var mutLRUList: [KeyObservationPair] = []
    var mutLRUMap: [String: KeyObservationPair] = [:]
    let kDecayThreshold: Double = 1.0 / 1_048_576.0  // 衰減二十次之後差不多就失效了。

    public static let kObservedOverrideHalfLife: Double = 3600.0 * 6  // 6 小時半衰一次，能持續不到六天的記憶。

    public init(capacity: Int = 500, decayConstant: Double = LMUserOverride.kObservedOverrideHalfLife) {
      mutCapacity = max(capacity, 1)  // Ensures that this integer value is always > 0.
      mutDecayExponent = log(0.5) / decayConstant
    }

    public func performObservation(
      walkedBefore: [Megrez.Compositor.Node], walkedAfter: [Megrez.Compositor.Node],
      cursor: Int, timestamp: Double, saveCallback: @escaping () -> Void
    ) {
      // 參數合規性檢查。
      guard !walkedAfter.isEmpty, !walkedBefore.isEmpty else { return }
      guard walkedBefore.totalReadingsCount == walkedAfter.totalReadingsCount else { return }
      // 先判斷用哪種覆寫方法。
      var actualCursor = 0
      guard let currentNode = walkedAfter.findNode(at: cursor, target: &actualCursor) else { return }
      // 當前節點超過三個字的話，就不記憶了。在這種情形下，使用者可以考慮新增自訂語彙。
      guard currentNode.spanLength <= 3 else { return }
      // 前一個節點得從前一次爬軌結果當中來找。
      guard actualCursor > 0 else { return }  // 該情況應該不會出現。
      let currentNodeIndex = actualCursor
      actualCursor -= 1
      var prevNodeIndex = 0
      guard let prevNode = walkedBefore.findNode(at: actualCursor, target: &prevNodeIndex) else { return }

      let forceHighScoreOverride: Bool = currentNode.spanLength > prevNode.spanLength
      let breakingUp = currentNode.spanLength == 1 && prevNode.spanLength > 1

      let targetNodeIndex = breakingUp ? currentNodeIndex : prevNodeIndex
      let key: String = vChewing.LMUserOverride.formObservationKey(
        walkedNodes: walkedAfter, headIndex: targetNodeIndex
      )
      guard !key.isEmpty else { return }
      doObservation(
        key: key, candidate: currentNode.currentUnigram.value, timestamp: timestamp,
        forceHighScoreOverride: forceHighScoreOverride, saveCallback: { saveCallback() }
      )
    }

    public func fetchSuggestion(
      currentWalk: [Megrez.Compositor.Node], cursor: Int, timestamp: Double
    ) -> Suggestion {
      var headIndex = 0
      guard let nodeIter = currentWalk.findNode(at: cursor, target: &headIndex) else { return .init() }
      let key = vChewing.LMUserOverride.formObservationKey(walkedNodes: currentWalk, headIndex: headIndex)
      return getSuggestion(key: key, timestamp: timestamp, headReading: nodeIter.key)
    }
  }
}

// MARK: - Private Structures

extension vChewing.LMUserOverride {
  enum OverrideUnit: CodingKey { case count, timestamp }
  enum ObservationUnit: CodingKey { case count, overrides }
  enum KeyObservationPairUnit: CodingKey { case key, observation }

  struct Override: Hashable, Encodable, Decodable {
    var count: Int = 0
    var timestamp: Double = 0.0
    var forceHighScoreOverride = false
    static func == (lhs: Override, rhs: Override) -> Bool {
      lhs.count == rhs.count && lhs.timestamp == rhs.timestamp
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: OverrideUnit.self)
      try container.encode(timestamp, forKey: .timestamp)
      try container.encode(count, forKey: .count)
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(count)
      hasher.combine(timestamp)
    }
  }

  struct Observation: Hashable, Encodable, Decodable {
    var count: Int = 0
    var overrides: [String: Override] = [:]
    static func == (lhs: Observation, rhs: Observation) -> Bool {
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

    mutating func update(candidate: String, timestamp: Double, forceHighScoreOverride: Bool = false) {
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
    static func == (lhs: KeyObservationPair, rhs: KeyObservationPair) -> Bool {
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

// MARK: - Hash and Dehash the entire UOM data

extension vChewing.LMUserOverride {
  /// 自 LRU 辭典內移除所有的單元圖。
  public func bleachUnigrams(saveCallback: @escaping () -> Void) {
    for key in mutLRUMap.keys {
      if !key.contains("(),()") { continue }
      mutLRUMap.removeValue(forKey: key)
    }
    resetMRUList()
    saveCallback()
  }

  internal func resetMRUList() {
    mutLRUList.removeAll()
    for neta in mutLRUMap.reversed() {
      mutLRUList.append(neta.value)
    }
  }

  public func clearData(withURL fileURL: URL) {
    mutLRUMap = .init()
    mutLRUList = .init()
    do {
      let nullData = "{}"
      try nullData.write(to: fileURL, atomically: false, encoding: .utf8)
    } catch {
      IME.prtDebugIntel("UOM Error: Unable to clear data. Details: \(error)")
      return
    }
  }

  public func saveData(toURL fileURL: URL) {
    let encoder = JSONEncoder()
    do {
      guard let jsonData = try? encoder.encode(mutLRUMap) else { return }
      try jsonData.write(to: fileURL, options: .atomic)
    } catch {
      IME.prtDebugIntel("UOM Error: Unable to save data, abort saving. Details: \(error)")
      return
    }
  }

  public func loadData(fromURL fileURL: URL) {
    let decoder = JSONDecoder()
    do {
      let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
      guard let jsonResult = try? decoder.decode([String: KeyObservationPair].self, from: data) else {
        IME.prtDebugIntel("UOM Error: Read file content type invalid, abort loading.")
        return
      }
      mutLRUMap = jsonResult
      resetMRUList()
    } catch {
      IME.prtDebugIntel("UOM Error: Unable to read file or parse the data, abort loading. Details: \(error)")
      return
    }
  }

  public struct Suggestion {
    var candidates = [(String, Megrez.Unigram)]()
    var forceHighScoreOverride = false
    var isEmpty: Bool { candidates.isEmpty }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.Compositor.Node {
  public var totalReadingsCount: Int {
    var counter = 0
    for node in self {
      counter += node.keyArray.count
    }
    return counter
  }

  public func findNode(at cursor: Int, target outCursorPastNode: inout Int) -> Megrez.Compositor.Node? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, keys.count))

    if cursor == 0, let theFirst = first {
      outCursorPastNode = theFirst.spanLength
      return theFirst
    }

    // 同時應對「游標在右端」與「游標離右端還差一個位置」的情形。
    if cursor >= keys.count - 1, let theLast = last {
      outCursorPastNode = keys.count
      return theLast
    }

    var accumulated = 0
    for neta in self {
      accumulated += neta.spanLength
      if accumulated > cursor {
        outCursorPastNode = accumulated
        return neta
      }
    }

    // 下述情形本不應該出現。
    return nil
  }
}

// MARK: - Private Methods

extension vChewing.LMUserOverride {
  private func doObservation(
    key: String, candidate: String, timestamp: Double, forceHighScoreOverride: Bool,
    saveCallback: @escaping () -> Void
  ) {
    guard mutLRUMap[key] != nil else {
      var observation: Observation = .init()
      observation.update(candidate: candidate, timestamp: timestamp, forceHighScoreOverride: forceHighScoreOverride)
      let koPair = KeyObservationPair(key: key, observation: observation)
      // 先移除 key 再設定 key 的話，就可以影響這個 key 在辭典內的順位。
      // Swift 原生的辭典是沒有數字索引排序的，但資料的插入順序卻有保存著。
      mutLRUMap.removeValue(forKey: key)
      mutLRUMap[key] = koPair
      mutLRUList.insert(koPair, at: 0)

      if mutLRUList.count > mutCapacity {
        mutLRUMap.removeValue(forKey: mutLRUList[mutLRUList.endIndex].key)
        mutLRUList.removeLast()
      }
      IME.prtDebugIntel("UOM: Observation finished with new observation: \(key)")
      saveCallback()
      return
    }
    // TODO: 降低磁碟寫入次數。唯有失憶的情況下才會更新觀察且記憶。
    if var theNeta = mutLRUMap[key] {
      _ = getSuggestion(
        key: key, timestamp: timestamp, headReading: "",
        decayCallback: {
          theNeta.observation.update(
            candidate: candidate, timestamp: timestamp, forceHighScoreOverride: forceHighScoreOverride
          )
          self.mutLRUList.insert(theNeta, at: 0)
          self.mutLRUMap[key] = theNeta
          IME.prtDebugIntel("UOM: Observation finished with existing observation: \(key)")
          saveCallback()
        }
      )
    }
  }

  private func getSuggestion(
    key: String, timestamp: Double, headReading: String, decayCallback: @escaping () -> Void = {}
  ) -> Suggestion {
    guard !key.isEmpty, let kvPair = mutLRUMap[key] else { return .init() }
    let observation: Observation = kvPair.observation
    var candidates: [(String, Megrez.Unigram)] = .init()
    var forceHighScoreOverride = false
    var currentHighScore: Double = 0
    for (i, theObservation) in observation.overrides {
      let overrideScore = getScore(
        eventCount: theObservation.count, totalCount: observation.count,
        eventTimestamp: theObservation.timestamp, timestamp: timestamp, lambda: mutDecayExponent
      )
      if (0...currentHighScore).contains(overrideScore) { continue }
      let overrideDetectionScore: Double = getScore(
        eventCount: theObservation.count, totalCount: observation.count,
        eventTimestamp: theObservation.timestamp, timestamp: timestamp, lambda: mutDecayExponent * 2
      )
      if (0...currentHighScore).contains(overrideDetectionScore) { decayCallback() }

      candidates.append((headReading, .init(value: i, score: overrideScore)))
      forceHighScoreOverride = theObservation.forceHighScoreOverride
      currentHighScore = overrideScore
    }
    return .init(candidates: candidates, forceHighScoreOverride: forceHighScoreOverride)
  }

  private func getScore(
    eventCount: Int,
    totalCount: Int,
    eventTimestamp: Double,
    timestamp: Double,
    lambda: Double
  ) -> Double {
    let decay = exp((timestamp - eventTimestamp) * lambda)
    if decay < kDecayThreshold { return 0.0 }
    let prob = Double(eventCount) / Double(totalCount)
    return prob * decay
  }

  private static func isPunctuation(_ node: Megrez.Compositor.Node) -> Bool {
    for key in node.keyArray {
      guard let firstChar = key.first else { continue }
      return String(firstChar) == "_"
    }
    return false
  }

  private static func formObservationKey(
    walkedNodes: [Megrez.Compositor.Node], headIndex cursorIndex: Int, readingOnly: Bool = false
  ) -> String {
    let whiteList = "你他妳她祢衪它牠再在"
    var arrNodes: [Megrez.Compositor.Node] = []
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
    guard !kvCurrent.key.contains("_") else {
      return ""
    }

    // 字音數與字數不一致的內容會被拋棄。
    if kvCurrent.key.split(separator: "-").count != kvCurrent.value.count { return "" }

    // 前置單元只記錄讀音，在其後的單元則同時記錄讀音與字詞
    let strCurrent = kvCurrent.key
    var kvPrevious = Megrez.KeyValuePaired()
    var kvAnterior = Megrez.KeyValuePaired()
    var readingStack = ""
    var trigramKey: String { "(\(kvAnterior.toNGramKey),\(kvPrevious.toNGramKey),\(strCurrent))" }
    var result: String {
      // 不要把單個漢字的 kvCurrent 當前鍵值領頭的單元圖記入資料庫，不然對敲字體驗破壞太大。
      if readingStack.contains("_")
        || (!kvPrevious.isValid && kvCurrent.value.count == 1 && !whiteList.contains(kvCurrent.value))
      {
        return ""
      } else {
        return (readingOnly ? strCurrent : trigramKey)
      }
    }

    if arrNodes.count >= 2,
      !kvPrevious.key.contains("_"),
      kvPrevious.key.split(separator: "-").count == kvPrevious.value.count
    {
      kvPrevious = arrNodes[1].currentPair
      readingStack = kvPrevious.key + readingStack
    }

    if arrNodes.count >= 3,
      !kvAnterior.key.contains("_"),
      kvAnterior.key.split(separator: "-").count == kvAnterior.value.count
    {
      kvAnterior = arrNodes[2].currentPair
      readingStack = kvAnterior.key + readingStack
    }

    return result
  }
}
