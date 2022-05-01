// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
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

extension Megrez {
	@frozen public struct KeyValuePair: Equatable, Hashable, Comparable {
		public var key: String
		public var value: String
		// public var paired: String

		public init(key: String = "", value: String = "") {
			self.key = key
			self.value = value
			// paired = "(" + key + "," + value + ")"
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(key)
			hasher.combine(value)
			// hasher.combine(paired)
		}

		public static func == (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
			lhs.key.count == rhs.key.count && lhs.value == rhs.value
		}

		public static func < (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
			(lhs.key.count < rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value < rhs.value)
		}

		public static func > (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
			(lhs.key.count > rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value > rhs.value)
		}

		public static func <= (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
			(lhs.key.count <= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value <= rhs.value)
		}

		public static func >= (lhs: KeyValuePair, rhs: KeyValuePair) -> Bool {
			(lhs.key.count >= rhs.key.count) || (lhs.key.count == rhs.key.count && lhs.value >= rhs.value)
		}

		public var description: String {
			"(\(key), \(value))"
		}

		public var debugDescription: String {
			"KeyValuePair(key: \(key), value: \(value))"
		}
	}
}
