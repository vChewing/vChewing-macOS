// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Megrez

// MARK: - LMAssembly.LMAssociates

extension LMAssembly {
  struct LMAssociates {
    // MARK: Lifecycle

    init() {
      self.rangeMap = [:]
    }

    // MARK: Internal

    var filePath: String?
    /// Range 只可能是一整行，所以必須得有 index。
    var rangeMap: [String: [(Range<String.Index>, Int)]] = [:]
    var strData: String = ""

    var count: Int { rangeMap.count }

    var isLoaded: Bool { !rangeMap.isEmpty }

    internal static func cnvNGramKeyFromPinyinToPhona(target: String) -> String {
      guard target.contains("("), target.contains(","), target.contains(")") else {
        return target
      }
      let arrTarget = target.dropLast().dropFirst().split(separator: ",")
      guard arrTarget.count == 2 else { return target }
      var arrTarget0 = String(arrTarget[0]).lowercased()
      arrTarget0.convertToPhonabets()
      return "(\(arrTarget0),\(arrTarget[1]))"
    }

    @discardableResult
    mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil

      do {
        let rawStrData: String = try LMAssembly.withFileHandleQueueSync {
          LMConsolidator.fixEOF(path: path)
          LMConsolidator.consolidate(path: path, pragma: true)
          return try String(contentsOfFile: path, encoding: .utf8)
        }
        replaceData(textData: rawStrData)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    mutating func replaceData(textData rawStrData: String) {
      if strData == rawStrData { return }
      strData = rawStrData
      var newMap: [String: [(Range<String.Index>, Int)]] = [:]
      strData.parse(splitee: "\n") { theRange in
        let theCells = rawStrData[theRange].split(separator: " ")
        if theCells.count >= 2 {
          let theKey = theCells[0].description
          if theKey.first != "#" {
            for (i, _) in theCells.enumerated() {
              if i == 0 { continue }
              if theCells[i].first == "#" { continue }
              let newKey = Self.cnvNGramKeyFromPinyinToPhona(target: theKey)
              newMap[newKey, default: []].append((theRange, i))
            }
          }
        }
      }
      rangeMap = newMap
      newMap.removeAll(keepingCapacity: false)
    }

    mutating func clear() {
      filePath = nil
      strData.removeAll()
      rangeMap.removeAll()
    }

    func saveData() {
      guard let filePath = filePath else { return }
      LMAssembly.withFileHandleQueueSync {
        do {
          try strData.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
          vCLMLog("Failed to save current database to: \(filePath)")
        }
      }
    }

    func valuesFor(pair: Megrez.KeyValuePaired) -> [String] {
      var pairs: [String] = []
      let availableResults = [rangeMap[pair.toNGramKey], rangeMap[pair.value]].compactMap { $0 }
      availableResults.forEach { arrRangeRecords in
        arrRangeRecords.forEach { netaRange, index in
          let neta = strData[netaRange].split(separator: " ")
          let theValue: String = .init(neta[index])
          pairs.append(theValue)
        }
      }
      return pairs.deduplicated
    }

    func hasValuesFor(pair: Megrez.KeyValuePaired) -> Bool {
      if rangeMap[pair.toNGramKey] != nil { return true }
      return rangeMap[pair.value] != nil
    }
  }
}

extension LMAssembly.LMAssociates {
  var dictRepresented: [String: [String]] {
    var result = [String: [String]]()
    rangeMap.forEach { key, arrRangeRecords in
      arrRangeRecords.forEach { netaRange, index in
        let neta = strData[netaRange].split(separator: " ")
        let theValue: String = .init(neta[index])
        result[key, default: []].append(theValue)
      }
    }
    return result
  }
}
