// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

extension LMAssembly {
  struct LMPlainBopomofo {
    @usableFromInline typealias DataMap = [String: [String: String]]
    let dataMap: DataMap

    public var count: Int { dataMap.count }

    public init() {
      do {
        let rawData = jsnEtenDosSequence.data(using: .utf8) ?? .init([])
        let rawJSON = try JSONDecoder().decode([String: [String: String]].self, from: rawData)
        dataMap = rawJSON
      } catch {
        vCLog("\(error)")
        vCLog("↑ Exception happened when parsing raw JSON sequence data from vChewing LMAssembly.")
        dataMap = [:]
      }
    }

    public var isLoaded: Bool { !dataMap.isEmpty }

    public func valuesFor(key: String, isCHS: Bool) -> [String] {
      var pairs: [String] = []
      let subKey = isCHS ? "S" : "T"
      if let arrRangeRecords: String = dataMap[key]?[subKey] {
        pairs.append(contentsOf: arrRangeRecords.map(\.description))
      }
      // 這裡不做去重複處理，因為倚天中文系統注音排序適應者們已經形成了肌肉記憶。
      return pairs
    }

    public func hasValuesFor(key: String) -> Bool { dataMap.keys.contains(key) }
  }
}
