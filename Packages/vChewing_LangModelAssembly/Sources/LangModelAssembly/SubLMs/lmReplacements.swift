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

    init() {}

    // MARK: Internal

    /// 單筆置換記錄：key 與整行內容皆直接指向 `rawData` 的位元組範圍。
    struct ReplacementEntry: Sendable {
      let keyStart: UInt32
      let keyEnd: UInt32
      let lineStart: UInt32
      let lineEnd: UInt32
    }

    var filePath: String?

    /// 原始資料的 UTF-8 位元組（取代舊版 `strData: String` 的實體儲存）。
    private(set) var rawData: [UInt8] = []

    /// 資料庫字串陣列（自 `rawData` 即時物化，供外部唯讀消費）。
    var strData: String { String(decoding: rawData, as: UTF8.self) }

    var count: Int { entries.count }

    var isLoaded: Bool { !entries.isEmpty }

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
      let newBytes = Array(rawStrData.utf8)
      if rawData == newBytes { return }
      rawData = newBytes
      var newEntries: [ReplacementEntry] = []
      rawData.parseByteLines { lineRange in
        var keyRange: Range<Int>?
        var hasValueCell = false
        rawData.parseByteCells(in: lineRange) { currentRange, currentIndex in
          switch currentIndex {
          case 0:
            keyRange = currentRange
            return true
          case 1:
            hasValueCell = true
            return false
          default:
            return false
          }
        }
        guard let keyRange, hasValueCell else { return }
        guard rawData[keyRange.lowerBound] != 0x23 else { return } // "#" 開頭的行跳過。
        newEntries.append(.init(
          keyStart: UInt32(keyRange.lowerBound),
          keyEnd: UInt32(keyRange.upperBound),
          lineStart: UInt32(lineRange.lowerBound),
          lineEnd: UInt32(lineRange.upperBound)
        ))
      }
      // 依 key bytes 排序；同 key 時依行位置升冪，去重時保留最後出現的行（與舊版辭典覆寫語義等價）。
      newEntries.sort { lhs, rhs in
        let cmp = rawData.compareByteSlices(
          Int(lhs.keyStart) ..< Int(lhs.keyEnd),
          Int(rhs.keyStart) ..< Int(rhs.keyEnd)
        )
        return cmp != 0 ? cmp < 0 : lhs.lineStart < rhs.lineStart
      }
      var deduped: [ReplacementEntry] = []
      deduped.reserveCapacity(newEntries.count)
      for entry in newEntries {
        if let last = deduped.last,
           rawData.compareByteSlices(
             Int(last.keyStart) ..< Int(last.keyEnd),
             Int(entry.keyStart) ..< Int(entry.keyEnd)
           ) == 0 {
          deduped[deduped.count - 1] = entry
        } else {
          deduped.append(entry)
        }
      }
      entries = deduped
    }

    mutating func clear() {
      filePath = nil
      rawData.removeAll(keepingCapacity: false)
      entries.removeAll(keepingCapacity: false)
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
      for entry in entries {
        strDump += String(
          decoding: rawData[Int(entry.lineStart) ..< Int(entry.lineEnd)],
          as: UTF8.self
        ) + "\n"
      }
      vCLMLog(strDump)
    }

    func valuesFor(key: String) -> String {
      guard let index = entryIndex(for: key) else { return "" }
      let entry = entries[index]
      var fetchedValue = ""
      rawData.parseByteCells(in: Int(entry.lineStart) ..< Int(entry.lineEnd)) { currentRange, currentIndex in
        guard currentIndex <= 1 else { return false }
        if currentIndex == 1 {
          fetchedValue = String(decoding: rawData[currentRange], as: UTF8.self)
          return false
        }
        return true
      }
      return fetchedValue
    }

    func hasValuesFor(key: String) -> Bool {
      entryIndex(for: key) != nil
    }

    // MARK: Private

    /// 按 key UTF-8 位元組排序的索引；同 key 重複時僅保留檔案中較晚出現的行。
    private var entries: [ReplacementEntry] = []

    /// 二分搜尋 key，回傳對應的 entry 索引。
    private func entryIndex(for key: String) -> Int? {
      let keyUTF8 = Array(key.utf8)
      var lo = 0, hi = entries.count - 1
      while lo <= hi {
        let mid = lo + (hi - lo) / 2
        let e = entries[mid]
        let cmp = rawData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
        if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
      }
      return nil
    }
  }
}

extension LMAssembly.LMReplacements {
  var dictRepresented: [String: String] {
    var result = [String: String]()
    entries.forEach { entry in
      let key = String(decoding: rawData[Int(entry.keyStart) ..< Int(entry.keyEnd)], as: UTF8.self)
      result[key] = String(decoding: rawData[Int(entry.lineStart) ..< Int(entry.lineEnd)], as: UTF8.self)
    }
    return result
  }
}
