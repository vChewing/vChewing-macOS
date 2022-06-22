// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the Cpp version of this class by Mengjuei Hsieh (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

extension vChewing {
  public class LMUserOverride {
    // MARK: - Main

    var mutCapacity: Int
    var mutDecayExponent: Double
    var mutLRUList: [KeyObservationPair] = []
    var mutLRUMap: [String: KeyObservationPair] = [:]
    let kDecayThreshold: Double = 1.0 / 1_048_576.0

    public init(capacity: Int = 500, decayConstant: Double = 5400.0) {
      mutCapacity = max(capacity, 1)  // Ensures that this integer value is always > 0.
      mutDecayExponent = log(0.5) / decayConstant
    }

    public func observe(
      walkedAnchors: [Megrez.NodeAnchor],
      cursorIndex: Int,
      candidate: String,
      timestamp: Double
    ) {
      let key = convertKeyFrom(walkedAnchors: walkedAnchors, cursorIndex: cursorIndex)
      guard !key.isEmpty else { return }

      guard mutLRUMap[key] != nil else {
        var observation: Observation = .init()
        observation.update(candidate: candidate, timestamp: timestamp)
        let koPair = KeyObservationPair(key: key, observation: observation)
        mutLRUMap[key] = koPair
        mutLRUList.insert(koPair, at: 0)

        if mutLRUList.count > mutCapacity {
          mutLRUMap.removeValue(forKey: mutLRUList[mutLRUList.endIndex].key)
          mutLRUList.removeLast()
        }
        IME.prtDebugIntel("UOM: Observation finished with new observation: \(key)")
        mgrLangModel.saveUserOverrideModelData()
        return
      }
      if var theNeta = mutLRUMap[key] {
        theNeta.observation.update(candidate: candidate, timestamp: timestamp)
        mutLRUList.insert(theNeta, at: 0)
        mutLRUMap[key] = theNeta
        IME.prtDebugIntel("UOM: Observation finished with existing observation: \(key)")
        mgrLangModel.saveUserOverrideModelData()
      }
    }

    public func suggest(
      walkedAnchors: [Megrez.NodeAnchor],
      cursorIndex: Int,
      timestamp: Double
    ) -> [Megrez.Unigram] {
      let key = convertKeyFrom(walkedAnchors: walkedAnchors, cursorIndex: cursorIndex)
      let currentReadingKey = convertKeyFrom(walkedAnchors: walkedAnchors, cursorIndex: cursorIndex, readingOnly: true)
      guard let koPair = mutLRUMap[key] else {
        IME.prtDebugIntel("UOM: mutLRUMap[key] is nil, throwing blank suggestion for key: \(key).")
        return .init()
      }

      let observation = koPair.observation

      var arrResults = [Megrez.Unigram]()
      var currentHighScore = 0.0
      for overrideNeta in Array(observation.overrides) {
        let override: Override = overrideNeta.value
        let overrideScore: Double = getScore(
          eventCount: override.count,
          totalCount: observation.count,
          eventTimestamp: override.timestamp,
          timestamp: timestamp,
          lambda: mutDecayExponent
        )
        if (0...currentHighScore).contains(overrideScore) { continue }
        let newUnigram = Megrez.Unigram(
          keyValue: .init(key: currentReadingKey, value: overrideNeta.key), score: overrideScore
        )
        arrResults.insert(newUnigram, at: 0)
        currentHighScore = overrideScore
      }
      if arrResults.isEmpty {
        IME.prtDebugIntel("UOM: No usable suggestions in the result for key: \(key).")
      }
      return arrResults
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

    func convertKeyFrom(
      walkedAnchors: [Megrez.NodeAnchor], cursorIndex: Int, readingOnly: Bool = false
    ) -> String {
      let arrEndingPunctuation = ["，", "。", "！", "？", "」", "』", "”", "’"]
      var arrNodes: [Megrez.NodeAnchor] = []
      var intLength = 0
      for theNodeAnchor in walkedAnchors {
        arrNodes.append(theNodeAnchor)
        intLength += theNodeAnchor.spanningLength
        if intLength >= cursorIndex {
          break
        }
      }

      if arrNodes.isEmpty { return "" }

      arrNodes = Array(arrNodes.reversed())

      guard let kvCurrent = arrNodes[0].node?.currentKeyValue,
        !arrEndingPunctuation.contains(kvCurrent.value)
      else {
        return ""
      }

      // 字音數與字數不一致的內容會被拋棄。
      if kvCurrent.key.split(separator: "-").count != kvCurrent.value.count { return "" }

      // 前置單元只記錄讀音，在其後的單元則同時記錄讀音與字詞
      let strCurrent = kvCurrent.key

      var strPrevious = "()"
      var strAnterior = "()"
      var readingStack = ""
      var trigramKey: String { "(\(strAnterior),\(strPrevious),\(strCurrent))" }
      var result: String {
        readingStack.contains("_") ? "" : (readingOnly ? strCurrent : trigramKey)
      }

      if arrNodes.count >= 2,
        let kvPrevious = arrNodes[1].node?.currentKeyValue,
        !arrEndingPunctuation.contains(kvPrevious.value),
        kvPrevious.key.split(separator: "-").count == kvPrevious.value.count
      {
        strPrevious = "(\(kvPrevious.key),\(kvPrevious.value))"
        readingStack = kvPrevious.key + readingStack
      }

      if arrNodes.count >= 3,
        let kvAnterior = arrNodes[2].node?.currentKeyValue,
        !arrEndingPunctuation.contains(kvAnterior.value),
        kvAnterior.key.split(separator: "-").count == kvAnterior.value.count
      {
        strAnterior = "(\(kvAnterior.key),\(kvAnterior.value))"
        readingStack = kvAnterior.key + readingStack
      }

      return result
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

    mutating func update(candidate: String, timestamp: Double) {
      count += 1
      if overrides.keys.contains(candidate) {
        overrides[candidate]?.timestamp = timestamp
        overrides[candidate]?.count += 1
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
  public func saveData(toURL fileURL: URL) {
    let encoder = JSONEncoder()
    do {
      if let jsonData = try? encoder.encode(mutLRUMap) {
        try jsonData.write(to: fileURL, options: .atomic)
      }
    } catch {
      IME.prtDebugIntel("UOM Error: Unable to save data, abort saving. Details: \(error)")
      return
    }
  }

  public func loadData(fromURL fileURL: URL) {
    let decoder = JSONDecoder()
    do {
      let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
      guard let jsonResult = try? decoder.decode(Dictionary<String, KeyObservationPair>.self, from: data) else {
        IME.prtDebugIntel("UOM Error: Read file content type invalid, abort loading.")
        return
      }
      mutLRUMap = jsonResult
      mutLRUList.removeAll()
      for neta in mutLRUMap.reversed() {
        mutLRUList.append(neta.value)
      }
    } catch {
      IME.prtDebugIntel("UOM Error: Unable to read file or parse the data, abort loading. Details: \(error)")
      return
    }
  }
}
