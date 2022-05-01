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
		let kDecayThreshold: Double = 1.0 / 1_048_576.0

		public init(capacity: Int = 0, decayExponent: Double = 0) {
			mutCapacity = capacity
			mutDecayExponent = decayExponent
		}

		public func observe(
			walkedNodes: [Megrez.NodeAnchor],
			cursorIndex: Int,
			candidate: String,
			timestamp: Double
		) {
			let key = getWalkedNodesToKey(walkedNodes: walkedNodes, cursorIndex: cursorIndex)
			if mutLRUMap[key] == nil {
				let keyValuePair = KeyObservationPair(key: key, observation: Observation())
				var observation: Observation = keyValuePair.observation
				observation.update(candidate: candidate, timestamp: timestamp)

				mutLRUList.insert(keyValuePair, at: 0)
				mutLRUMap[key] = KeyObservationPair(key: key, observation: observation)

				if mutLRUList.count > mutCapacity {
					mutLRUMap[mutLRUList.reversed()[0].key] = nil
					mutLRUList.removeLast()
				}
			} else {
				var obs = mutLRUMap[key]!.observation
				obs.update(candidate: candidate, timestamp: timestamp)
				let pair = KeyObservationPair.init(key: key, observation: obs)
				mutLRUList.insert(pair, at: 0)
			}
		}

		public func suggest(
			walkedNodes: [Megrez.NodeAnchor],
			cursorIndex: Int,
			timestamp: Double
		) -> String {
			let key = getWalkedNodesToKey(walkedNodes: walkedNodes, cursorIndex: cursorIndex)
			guard let keyValuePair = mutLRUMap[key] else {
				return ""
			}
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
			var s = ""
			var n: [Megrez.NodeAnchor] = []
			var ll = 0
			for i in walkedNodes {
				let nn = i
				n.append(nn)
				ll += nn.spanningLength
				if ll >= cursorIndex {
					break
				}
			}

			var r: [Megrez.NodeAnchor] = []
			r.append(contentsOf: n.reversed())

			if r.isEmpty {
				return ""
			}

			if let theAnchor = r.first, theAnchor.node != nil {
				let theNode = theAnchor.node!
				let current = theNode.currentKeyValue().key
				r.removeFirst()

				s = ""  // 保險起見，這裡也清空 s。
				if !r.isEmpty {
					let value = theNode.currentKeyValue().value
					if isEndingPunctuation(value: value) {
						s = "()"
						r = []
					} else {
						s = "(\(theNode.currentKeyValue().key),\(value))"
						r.removeFirst()
					}
				} else {
					s = "()"
				}
				let prev = s

				s = ""
				if !r.isEmpty {
					let value = theNode.currentKeyValue().value
					if isEndingPunctuation(value: value) {
						s = "()"
						r = []
					} else {
						s = "(\(theNode.currentKeyValue().key),\(value))"
						r.removeFirst()
					}
				} else {
					s = "()"
				}
				let anterior = s

				s = "(\(anterior),\(prev),\(current))"
			}
			return s
		}

		// MARK: - Private Structures

		var mutCapacity: Int
		var mutDecayExponent: Double
		var mutLRUList = [KeyObservationPair]()
		var mutLRUMap: [String: KeyObservationPair] = [:]

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
	}
}
