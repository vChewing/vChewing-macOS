// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension vChewing {
  @frozen public struct LMPlainBopomofo {
    var rangeMap: [String: String] = [:]

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

      do {
        let rawData = try Data(contentsOf: URL(fileURLWithPath: path))
        let rawPlist: [String: String] =
          try PropertyListSerialization.propertyList(from: rawData, format: nil) as? [String: String] ?? .init()
        rangeMap = rawPlist
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
      // We remove this function in order to reduce out maintenance workload.
      // This function will be implemented only if further hard-necessity comes.
    }

    public func valuesFor(key: String) -> [String] {
      var pairs: [String] = []
      if let arrRangeRecords: String = rangeMap[key] {
        pairs.append(contentsOf: arrRangeRecords.map { String($0) })
      }
      var set = Set<String>()
      return pairs.filter { set.insert($0).inserted }
    }

    public func hasValuesFor(key: String) -> Bool { rangeMap.keys.contains(key) }
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
