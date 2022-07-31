// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
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
  @frozen public struct LMReplacments {
    var rangeMap: [String: Range<String.Index>] = [:]
    var strData: String = ""

    public var count: Int {
      rangeMap.count
    }

    public init() {
      rangeMap = [:]
    }

    public func isLoaded() -> Bool {
      !rangeMap.isEmpty
    }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded() {
        return false
      }

      LMConsolidator.fixEOF(path: path)
      LMConsolidator.consolidate(path: path, pragma: true)

      do {
        strData = try String(contentsOfFile: path, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
        strData = strData.replacingOccurrences(of: "\r", with: "\n")
        strData.ranges(splitBy: "\n").filter { !$0.isEmpty }.forEach {
          let neta = strData[$0].split(separator: " ")
          if neta.count >= 2 {
            let theKey = String(neta[0])
            if !neta[0].isEmpty, !neta[1].isEmpty, theKey.first != "#" {
              let theValue = $0
              rangeMap[theKey] = theValue
            }
          }
        }
      } catch {
        IME.prtDebugIntel("\(error)")
        IME.prtDebugIntel("↑ Exception happened when reading data at: \(path).")
        return false
      }

      return true
    }

    public mutating func close() {
      if isLoaded() {
        rangeMap.removeAll()
      }
    }

    public func dump() {
      var strDump = ""
      for entry in rangeMap {
        strDump += strData[entry.value] + "\n"
      }
      IME.prtDebugIntel(strDump)
    }

    public func valuesFor(key: String) -> String {
      guard let range = rangeMap[key] else {
        return ""
      }
      let arrNeta = strData[range].split(separator: " ")
      guard arrNeta.count >= 2 else {
        return ""
      }
      return String(arrNeta[1])
    }

    public func hasValuesFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

// MARK: - StringView Ranges Extension (by Isaac Xen)

extension String {
  fileprivate func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex..<endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}
