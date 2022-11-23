// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

extension vChewingLM {
  @frozen public struct LMReplacements {
    var rangeMap: [String: Range<String.Index>] = [:]
    var strData: String = ""

    public var count: Int { rangeMap.count }

    public init() {
      rangeMap = [:]
    }

    public var isLoaded: Bool { !rangeMap.isEmpty }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }

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
        vCLog("\(error)")
        vCLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      return true
    }

    public mutating func clear() {
      rangeMap.removeAll()
    }

    public func dump() {
      var strDump = ""
      for entry in rangeMap {
        strDump += strData[entry.value] + "\n"
      }
      vCLog(strDump)
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
