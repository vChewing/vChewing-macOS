// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

extension vChewingLM {
  @frozen public struct LMPlainBopomofo {
    public private(set) var filePath: String?
    var dataMap: [String: String] = [:]

    public var count: Int { dataMap.count }

    public init() {
      dataMap = [:]
    }

    public var isLoaded: Bool { !dataMap.isEmpty }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil

      do {
        let rawData = try Data(contentsOf: URL(fileURLWithPath: path))
        let rawPlist: [String: String] =
          try PropertyListSerialization.propertyList(from: rawData, format: nil) as? [String: String] ?? .init()
        dataMap = rawPlist
      } catch {
        filePath = oldPath
        vCLog("\(error)")
        vCLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    public mutating func clear() {
      filePath = nil
      dataMap.removeAll()
    }

    public func valuesFor(key: String) -> [String] {
      var pairs: [String] = []
      if let arrRangeRecords: String = dataMap[key]?.trimmingCharacters(in: .newlines) {
        pairs.append(contentsOf: arrRangeRecords.map { String($0) })
      }
      return pairs.deduplicated
    }

    public func hasValuesFor(key: String) -> Bool { dataMap.keys.contains(key) }
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
