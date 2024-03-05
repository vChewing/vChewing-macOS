// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Megrez

extension LMAssembly {
  struct LMAssociates {
    public private(set) var filePath: String?
    var rangeMap: [String: [(Range<String.Index>, Int)]] = [:]
    var strData: String = ""

    public var count: Int { rangeMap.count }

    public init() {
      rangeMap = [:]
    }

    public var isLoaded: Bool { !rangeMap.isEmpty }

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

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil

      LMConsolidator.fixEOF(path: path)
      LMConsolidator.consolidate(path: path, pragma: true)

      do {
        let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
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
    public mutating func replaceData(textData rawStrData: String) {
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
      newMap.removeAll()
    }

    public mutating func clear() {
      filePath = nil
      strData.removeAll()
      rangeMap.removeAll()
    }

    public func saveData() {
      guard let filePath = filePath else { return }
      do {
        try strData.write(toFile: filePath, atomically: true, encoding: .utf8)
      } catch {
        vCLMLog("Failed to save current database to: \(filePath)")
      }
    }

    public func valuesFor(pair: Megrez.KeyValuePaired) -> [String] {
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
      return pairs.deduplicated
    }

    public func hasValuesFor(pair: Megrez.KeyValuePaired) -> Bool {
      if rangeMap[pair.toNGramKey] != nil { return true }
      return rangeMap[pair.value] != nil
    }
  }
}
