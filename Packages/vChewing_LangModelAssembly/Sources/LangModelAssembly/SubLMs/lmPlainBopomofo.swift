// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - LMAssembly.LMPlainBopomofo

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
        self.distinctionTables = Self.generateDistinctionHashTables(using: dataMap)
      } catch {
        vCLMLog("\(error)")
        vCLMLog(
          "↑ Exception happened when parsing raw JSON sequence data from vChewing LMAssembly."
        )
        self.dataMap = [:]
        self.sortedKeys = []
        self.distinctionTables = [:]
      }
    }

    // MARK: Internal

    @usableFromInline typealias DataMap = [String: [String: String]]
    @usableFromInline typealias KVHashMap = [String: [Bool: Set<Character>]]

    let dataMap: DataMap
    let sortedKeys: [String]
    let distinctionTables: KVHashMap

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

extension LMAssembly.LMPlainBopomofo {
  static func generateDistinctionHashTables(
    using dataMap: DataMap
  )
    -> KVHashMap {
    var resultMap = KVHashMap()

    dataMap.forEach { key, valueMap in
      guard let simpChars = valueMap["S"],
            let tradChars = valueMap["T"],
            simpChars != tradChars
      else {
        return
      }

      // 直接比較字串中的 Character
      let simpSet = Set(simpChars)
      let tradSet = Set(tradChars)

      let simpOnly = simpSet.subtracting(tradSet)
      let tradOnly = tradSet.subtracting(simpSet)

      guard !simpOnly.isEmpty || !tradOnly.isEmpty else { return }

      resultMap[key] = [
        true: simpOnly, // true = 簡體特有
        false: tradOnly, // false = 繁體特有
      ]
    }

    return resultMap
  }

  /// 檢查某個字在特定讀音下是否為簡/繁體特有
  /// - Parameters:
  ///   - isCHS: `true` 檢查簡體特有，`false` 檢查繁體特有
  ///   - reading: 注音（如 "ㄅㄚ"）
  ///   - target: 要檢查的漢字
  /// - Returns:
  ///   - `true`: 該字是當前體系特有的
  ///   - `false`: 該字不是當前體系特有的（存在於另一體系中）
  ///   - `nil`: 讀音不存在，或該字不在任何體系中
  func isExclusive(isCHS: Bool, reading: String, target: Character?) -> Bool? {
    guard let target else { return nil }
    return distinctionTables[reading]?[isCHS]?.contains(target)
  }
}
