// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Megrez
import PinyinPhonaConverter
import Shared

extension vChewingLM {
  @frozen public struct LMAssociates {
    var rangeMap: [String: [(Range<String.Index>, Int)]] = [:]
    var strData: String = ""

    public var count: Int { rangeMap.count }

    public init() {
      rangeMap = [:]
    }

    public var isLoaded: Bool { !rangeMap.isEmpty }

    internal func cnvNGramKeyFromPinyinToPhona(target: String) -> String {
      guard target.contains("("), target.contains(","), target.contains(")") else {
        return target
      }
      let arrTarget = target.dropLast().dropFirst().split(separator: ",")
      guard arrTarget.count == 2 else { return target }
      var arrTarget0 = String(arrTarget[0]).lowercased()
      arrTarget0.converToPhonabets()
      return "(\(arrTarget0),\(arrTarget[1]))"
    }

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
            if !theKey.isEmpty, theKey.first != "#" {
              for (i, _) in neta.filter({ $0.first != "#" && !$0.isEmpty }).enumerated() {
                if i == 0 { continue }
                rangeMap[cnvNGramKeyFromPinyinToPhona(target: theKey), default: []].append(($0, i))
              }
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

    public mutating func close() {
      rangeMap.removeAll()
    }

    public func valuesFor(pair: Megrez.Compositor.KeyValuePaired) -> [String] {
      var pairs: [String] = []
      if let arrRangeRecords: [(Range<String.Index>, Int)] = rangeMap[pair.toNGramKey] {
        for (netaRange, index) in arrRangeRecords {
          let neta = strData[netaRange].split(separator: " ")
          let theValue: String = .init(neta[index])
          pairs.append(theValue)
        }
      }
      if let arrRangeRecords: [(Range<String.Index>, Int)] = rangeMap[pair.value] {
        for (netaRange, index) in arrRangeRecords {
          let neta = strData[netaRange].split(separator: " ")
          let theValue: String = .init(neta[index])
          pairs.append(theValue)
        }
      }
      var set = Set<String>()
      return pairs.filter { set.insert($0).inserted }
    }

    public func hasValuesFor(pair: Megrez.Compositor.KeyValuePaired) -> Bool {
      if rangeMap[pair.toNGramKey] != nil { return true }
      return rangeMap[pair.value] != nil
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
