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
	public class LMLiteMono {
		var keyValueMap: [String: [Megrez.KeyValuePair]] = [:]
		var theData: String = ""
		var allowConsolidation = false

		public init(consolidate: Bool = false) {
			keyValueMap = [:]
			theData = ""
			allowConsolidation = consolidate
		}

		deinit {
			if isLoaded() {
				close()
			}
		}

		public func isLoaded() -> Bool {
			!keyValueMap.isEmpty
		}

		@discardableResult public func open(_ path: String) -> Bool {
			if isLoaded() {
				return false
			}

			if allowConsolidation {
				if !LMConsolidator.fixEOF(path: path) {
					return false
				}
				if !LMConsolidator.consolidate(path: path, pragma: true) {
					return false
				}
			}

			do {
				theData = try String(contentsOfFile: path, encoding: .utf8)
			} catch {
				IME.prtDebugIntel("\(error)")
				IME.prtDebugIntel("↑ Exception happened when reading Associated Phrases data.")
				return false
			}

			let length = theData.count
			guard length > 0 else {
				return false
			}

			let arrData = theData.components(separatedBy: "\n")
			for (lineID, lineContent) in arrData.enumerated() {
				if !lineContent.hasPrefix("#") {
					if lineContent.components(separatedBy: " ").count < 2 {
						if arrData.last != "" {
							IME.prtDebugIntel("Line #\(lineID + 1) Wrecked: \(lineContent)")
						}
						continue
					}
					var currentKV = Megrez.KeyValuePair()
					for (unitID, unitContent) in lineContent.components(separatedBy: " ").enumerated() {
						switch unitID {
							case 0:
								currentKV.value = unitContent
							case 1:
								currentKV.key = unitContent
							default: break
						}
					}
					keyValueMap[currentKV.key, default: []].append(currentKV)
				}
			}
			// IME.prtDebugIntel("\(self.keyValueMap.count) entries of data loaded from: \(path)")
			theData = ""
			if path.contains("vChewing/") {
				dump()
			}
			return true
		}

		public func close() {
			if isLoaded() {
				keyValueMap.removeAll()
			}
		}

		public func dump() {
			var strDump = ""
			for entry in keyValueMap {
				let rows: [Megrez.KeyValuePair] = entry.1
				for row in rows {
					let addline = row.key + " " + row.value + "\n"
					strDump += addline
				}
			}
			IME.prtDebugIntel(strDump)
		}

		public func unigramsFor(key: String, score givenScore: Double = 0.0) -> [Megrez.Unigram] {
			var v: [Megrez.Unigram] = []
			if let matched = keyValueMap[key] {
				for entry in matched as [Megrez.KeyValuePair] {
					v.append(Megrez.Unigram(keyValue: entry, score: givenScore))
				}
			}
			return v
		}

		public func hasUnigramsFor(key: String) -> Bool {
			keyValueMap[key] != nil
		}
	}
}
