// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
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
    var mutLRUList = [KeyObservationPair]()
    var mutLRUMap: [String: KeyObservationPair] = [:]
    let kDecayThreshold: Double = 1.0 / 1_048_576.0

    public init(capacity: Int = 500, decayConstant: Double = 5400.0) {
      mutCapacity = abs(capacity)  // Ensures that this value is always > 0.
      mutDecayExponent = log(0.5) / decayConstant
    }

    public func observe(
      walkedNodes: [Megrez.NodeAnchor],
      cursorIndex: Int,
      candidate: String,
      timestamp: Double
    ) {
      let key = getWalkedNodesToKey(walkedNodes: walkedNodes, cursorIndex: cursorIndex)
      guard !key.isEmpty
      else {
        return
      }
      guard let map = mutLRUMap[key] else {
        var observation: Observation = .init()
        observation.update(candidate: candidate, timestamp: timestamp)
        mutLRUMap[key] = KeyObservationPair(key: key, observation: observation)
        mutLRUList.insert(KeyObservationPair(key: key, observation: observation), at: 0)

        if mutLRUList.count > mutCapacity {
          mutLRUMap[mutLRUList.reversed()[0].key] = nil
          mutLRUList.removeLast()
        }
        return
      }
      var obs = map.observation
      obs.update(candidate: candidate, timestamp: timestamp)
      let pair = KeyObservationPair(key: key, observation: obs)
      mutLRUList.insert(pair, at: 0)
    }

    public func suggest(
      walkedNodes: [Megrez.NodeAnchor],
      cursorIndex: Int,
      timestamp: Double
    ) -> String {
      let key = getWalkedNodesToKey(walkedNodes: walkedNodes, cursorIndex: cursorIndex)
      guard let keyValuePair = mutLRUMap[key],
        !key.isEmpty
      else {
        return ""
      }

      IME.prtDebugIntel("Suggest - A: \(key)")
      IME.prtDebugIntel("Suggest - B: \(keyValuePair.key)")

      let observation = keyValuePair.observation

      var candidate = ""
      var score = 0.0
      for overrideNeta in Array(observation.overrides) {
        let overrideScore = getScore(
          eventCount: overrideNeta.value.count,
          totalCount: observation.count,
          eventTimestamp: overrideNeta.value.timestamp,
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
      return candidate
    }

    func isEndingPunctuation(value: String) -> Bool {
      ["，", "。", "！", "？", "」", "』", "”", "’"].contains(value)
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

    func getWalkedNodesToKey(
      walkedNodes: [Megrez.NodeAnchor], cursorIndex: Int
    ) -> String {
      var strOutput = ""
      var arrNodes: [Megrez.NodeAnchor] = []
      var intLength = 0
      for nodeNeta in walkedNodes {
        arrNodes.append(nodeNeta)
        intLength += nodeNeta.spanningLength
        if intLength >= cursorIndex {
          break
        }
      }

      // 一個被 .reversed 過的陣列不能直接使用，因為不是正常的 Swift 陣列。
      // 那就新開一個正常的陣列、然後將內容拓印過去。
      var arrNodesReversed: [Megrez.NodeAnchor] = []
      arrNodesReversed.append(contentsOf: arrNodes.reversed())

      if arrNodesReversed.isEmpty {
        return ""
      }

      var strCurrent = "()"
      var strPrev = "()"
      var strAnterior = "()"

      for (theIndex, theAnchor) in arrNodesReversed.enumerated() {
        if strCurrent != "()", let nodeCurrent = theAnchor.node {
          let keyCurrent = nodeCurrent.currentKeyValue().key
          let valCurrent = nodeCurrent.currentKeyValue().value
          strCurrent = "(\(keyCurrent), \(valCurrent))"
          if let nodePrev = arrNodesReversed[theIndex + 1].node {
            let keyPrev = nodePrev.currentKeyValue().key
            let valPrev = nodePrev.currentKeyValue().value
            strPrev = "(\(keyPrev), \(valPrev))"
          }
          if let nodeAnterior = arrNodesReversed[theIndex + 2].node {
            let keyAnterior = nodeAnterior.currentKeyValue().key
            let valAnterior = nodeAnterior.currentKeyValue().value
            strAnterior = "(\(keyAnterior), \(valAnterior))"
          }
          break  // 我們只取第一個有效結果。
        }
      }

      strOutput = "(\(strAnterior),\(strPrev),\(strCurrent))"
      if strOutput == "((),(),())" {
        strOutput = ""
      }

      return strOutput
    }
  }
}
