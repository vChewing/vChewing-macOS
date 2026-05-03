// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension LMAssembly {
  struct LMPlainBopomofo {
    // MARK: Lifecycle

    init() {
      do {
        let rawData = jsnEtenDosSequence.data(using: .utf8) ?? .init([])
        let rawJSON = try JSONDecoder().decode([String: [String: String]].self, from: rawData)
        var dataMapNew = rawJSON
        if let fung4 = dataMapNew["ㄈㄨㄥˋ"] {
          fung4.forEach { fKey, fValue in
            if let existingValue = dataMapNew["ㄈㄥˋ"]?[fKey] {
              dataMapNew["ㄈㄥˋ", default: [:]][fKey] = existingValue + fValue
            }
          }
        }
        self.dataMap = dataMapNew
        self.sortedKeys = rawJSON.keys.sorted {
          if $0.count == $1.count { return $0 < $1 }
          return $0.count < $1.count
        }
      } catch {
        vCLMLog("\(error)")
        vCLMLog(
          "↑ Exception happened when parsing raw JSON sequence data from vChewing LMAssembly."
        )
        self.dataMap = [:]
        self.sortedKeys = []
      }
    }

    // MARK: Internal

    @usableFromInline typealias DataMap = [String: [String: String]]

    let dataMap: DataMap
    let sortedKeys: [String]

    var count: Int { dataMap.count }

    var isLoaded: Bool { !dataMap.isEmpty }

    func valuesFor(key: String, isCHS: Bool) -> [String] {
      var pairs: [String] = []
      let subKey = isCHS ? "S" : "T"
      if let arrRangeRecords: String = dataMap[key]?[subKey] {
        pairs.append(contentsOf: arrRangeRecords.map(\.description))
      }
      // 這裡不做去重複處理，因為倚天中文系統注音排序適應者們已經形成了肌肉記憶。
      return pairs
    }

    func partiallyMatchedValuesFor(prefix: String, isCHS: Bool) -> [String] {
      guard !prefix.isEmpty else { return [] }
      let subKey = isCHS ? "S" : "T"
      var seen = Set<String>()
      var results: [String] = []
      for currentKey in sortedKeys where currentKey.hasPrefix(prefix) {
        guard let records = dataMap[currentKey]?[subKey] else { continue }
        for value in records.map(\.description) where !seen.contains(value) {
          seen.insert(value)
          results.append(value)
        }
      }
      return results
    }

    func hasValuesFor(key: String) -> Bool { dataMap.keys.contains(key) }
  }
}
