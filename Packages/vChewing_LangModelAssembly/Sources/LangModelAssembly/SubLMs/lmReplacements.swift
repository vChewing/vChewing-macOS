// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - LMAssembly.LMReplacements

extension LMAssembly {
  struct LMReplacements {
    // MARK: Lifecycle

    init() {
      self.rangeMap = [:]
    }

    // MARK: Internal

    var filePath: String?

    var rangeMap: [String: Range<String.Index>] = [:]
    var strData: String = ""

    var count: Int { rangeMap.count }

    var isLoaded: Bool { !rangeMap.isEmpty }

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
      var newMap: [String: Range<String.Index>] = [:]
      strData.parse(splitee: "\n") { theRange in
        var keyRange: Range<String.Index>?
        var valueRange: Range<String.Index>?
        rawStrData.parseCells(in: theRange, splitee: " ") { currentRange, currentIndex in
          switch currentIndex {
          case 0:
            keyRange = currentRange
            return true
          case 1:
            valueRange = currentRange
            return false
          default:
            return false
          }
        }
        guard let keyRange, valueRange != nil else { return }
        let theKey = String(rawStrData[keyRange])
        if theKey.first != "#" { newMap[theKey] = theRange }
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

    func dump() {
      var strDump = ""
      for entry in rangeMap {
        strDump += strData[entry.value] + "\n"
      }
      vCLMLog(strDump)
    }

    func valuesFor(key: String) -> String {
      guard let range = rangeMap[key] else {
        return ""
      }
      var fetchedValue = ""
      strData.parseCells(in: range, splitee: " ") { currentRange, currentIndex in
        guard currentIndex <= 1 else { return false }
        if currentIndex == 1 {
          fetchedValue = String(strData[currentRange])
          return false
        }
        return true
      }
      return fetchedValue
    }

    func hasValuesFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

extension LMAssembly.LMReplacements {
  var dictRepresented: [String: String] {
    var result = [String: String]()
    rangeMap.forEach { key, valueRange in
      result[key] = strData[valueRange].description
    }
    return result
  }
}
