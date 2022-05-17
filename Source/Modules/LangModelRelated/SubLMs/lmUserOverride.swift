// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by Mengjuei Hsieh (MIT License).
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
    // MARK: - Private Structures

    struct Override {
      var count: Int = 0
      var timestamp: Double = 0.0
    }

    struct Observation {
      var count: Int = 0
      var overrides: [String: Override] = [:]

      mutating func update(candidate: String, timestamp: Double) {
        count += 1
        if var neta = overrides[candidate] {
          neta.timestamp = timestamp
          neta.count += 1
        }
      }
    }

    struct KeyObservationPair: Equatable {
      var key: String
      var observation: Observation

      var hashValue: Int { key.hashValue }

      init(key: String, observation: Observation) {
        self.key = key
        self.observation = observation
      }

      static func == (lhs: KeyObservationPair, rhs: KeyObservationPair) -> Bool {
        lhs.key == rhs.key
      }
    }

    // MARK: - Main

    var mutCapacity: Int
    var mutDecayExponent: Double
    var mutLRUList: [KeyObservationPair] = []
    var mutLRUMap: [String: KeyObservationPair] = [:]
    let kDecayThreshold: Double = 1.0 / 1_048_576.0

    public init(capacity: Int = 500, decayConstant: Double = 5400.0) {
      mutCapacity = abs(capacity)  // Ensures that this value is always > 0.
      if mutCapacity == 0 {
        mutCapacity = 1
      }
      mutDecayExponent = log(0.5) / decayConstant
    }

    public func observe(
      walkedNodes: [Megrez.NodeAnchor],
      cursorIndex: Int,
      candidate: String,
      timestamp: Double
    ) {
      let key = convertKeyFrom(walkedNodes: walkedNodes, cursorIndex: cursorIndex)

      guard mutLRUMap[key] != nil else {
        var observation: Observation = .init()
        observation.update(candidate: candidate, timestamp: timestamp)
        let koPair = KeyObservationPair(key: key, observation: observation)
        mutLRUMap[key] = koPair
        mutLRUList.insert(koPair, at: 0)

        if mutLRUList.count > mutCapacity {
          mutLRUMap[mutLRUList[mutLRUList.endIndex].key] = nil
          mutLRUList.removeLast()
        }
        IME.prtDebugIntel("UOM: Observation finished with new observation: \(key)")
        return
      }
      if var theNeta = mutLRUMap[key] {
        theNeta.observation.update(candidate: candidate, timestamp: timestamp)
        mutLRUList.insert(theNeta, at: 0)
        mutLRUMap[key] = theNeta
        IME.prtDebugIntel("UOM: Observation finished with existing observation: \(key)")
      }
    }

    public func suggest(
      walkedNodes: [Megrez.NodeAnchor],
      cursorIndex: Int,
      timestamp: Double
    ) -> String {
      let key = convertKeyFrom(walkedNodes: walkedNodes, cursorIndex: cursorIndex)
      guard let koPair = mutLRUMap[key] else {
        IME.prtDebugIntel("UOM: mutLRUMap[key] is nil, throwing blank suggestion for key: \(key).")
        return ""
      }

      let observation = koPair.observation

      var candidate = ""
      var score = 0.0
      for overrideNeta in Array(observation.overrides) {
        let override: Override = overrideNeta.value
        let overrideScore: Double = getScore(
          eventCount: override.count,
          totalCount: observation.count,
          eventTimestamp: override.timestamp,
          timestamp: timestamp,
          lambda: mutDecayExponent
        )

        if overrideScore == 0.0 {
          continue
        }

        if overrideScore > score {
          candidate = overrideNeta.key
          score = overrideScore
        }
      }
      if candidate.isEmpty {
        IME.prtDebugIntel("UOM: No usable suggestions in the result for key: \(key).")
      }
      return candidate
    }

    public func getScore(
      eventCount: Int,
      totalCount: Int,
      eventTimestamp: Double,
      timestamp: Double,
      lambda: Double
    ) -> Double {
      let decay = exp((timestamp - eventTimestamp) * lambda)
      if decay < kDecayThreshold {
        return 0.0
      }

      let prob = Double(eventCount) / Double(totalCount)
      return prob * decay
    }

    func convertKeyFrom(
      walkedNodes: [Megrez.NodeAnchor], cursorIndex: Int
    ) -> String {
      let arrEndingPunctuation = ["，", "。", "！", "？", "」", "』", "”", "’"]
      var arrNodesReversed: [Megrez.NodeAnchor] = []
      var intLength = 0
      for theNodeAnchor in walkedNodes {
        // 這裡直接生成一個反向排序的陣列，之後就不用再「.reverse()」了。
        arrNodesReversed = [theNodeAnchor] + arrNodesReversed
        intLength += theNodeAnchor.spanningLength
        if intLength >= cursorIndex {
          break
        }
      }

      if arrNodesReversed.isEmpty { return "" }

      var strCurrent = "()"
      var strPrevious = "()"
      var strAnterior = "()"

      guard let kvCurrent = arrNodesReversed[0].node?.currentKeyValue(),
        !arrEndingPunctuation.contains(kvCurrent.value)
      else {
        return ""
      }

      // 前置單元只記錄讀音，在其後的單元則同時記錄讀音與字詞
      strCurrent = kvCurrent.key

      if arrNodesReversed.count >= 2,
        let kvPrevious = arrNodesReversed[1].node?.currentKeyValue(),
        !arrEndingPunctuation.contains(kvPrevious.value)
      {
        strPrevious = "(\(kvPrevious.key),\(kvPrevious.value))"
      }

      if arrNodesReversed.count >= 3,
        let kvAnterior = arrNodesReversed[2].node?.currentKeyValue(),
        !arrEndingPunctuation.contains(kvAnterior.value)
      {
        strAnterior = "(\(kvAnterior.key),\(kvAnterior.value))"
      }

      return "(\(strAnterior),\(strPrevious),\(strCurrent))"
    }
  }
}
