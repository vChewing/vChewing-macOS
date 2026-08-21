// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa

// MARK: - LMAssembly.LMAssociates

extension LMAssembly {
  struct LMAssociates {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    /// 單筆關聯詞語 key entry（轉換後的 key → line refs 範圍）。
    struct AssociatesEntry: Sendable {
      /// 轉換後 key 在 `keyData` 內的範圍。
      let keyStart: UInt32
      let keyEnd: UInt32
      /// 指向 `lineRefs` 的範圍。
      let refsStart: UInt32
      let refsEnd: UInt32
    }

    /// 單筆行引用：同行的 value 是 dense 索引 1...valueCellCount 的連續 cells。
    struct AssociatesLineRef: Sendable {
      /// 整行在 `rawData` 內的範圍。
      let lineStart: UInt32
      let lineEnd: UInt32
      /// 該行被記錄的 value cell 數量（遇 `#` 開頭的 cell 即停止計數）。
      let valueCellCount: UInt32
    }

    var filePath: String?

    /// 原始資料的 UTF-8 位元組（取代舊版 `strData: String` 的實體儲存）。
    private(set) var rawData: [UInt8] = []

    /// 資料庫字串陣列（自 `rawData` 即時物化，供外部唯讀消費）。
    var strData: String { String(decoding: rawData, as: UTF8.self) }

    var count: Int { entries.count }

    var isLoaded: Bool { !entries.isEmpty }

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
        // 直接以位元組讀入：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
        let newBytes: [UInt8] = try LMAssembly.withFileHandleQueueSync {
          LMConsolidator.fixEOF(path: path)
          LMConsolidator.consolidate(path: path, pragma: true)
          return [UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
        }
        replaceData(bytes: newBytes)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將資料從字串讀入至資料庫辭典內。
    /// - parameters:
    ///   - textData: 給定資料字串。
    mutating func replaceData(textData rawStrData: String) {
      replaceData(bytes: Array(rawStrData.utf8))
    }

    /// 將資料從位元組緩衝讀入至資料庫辭典內（非法 UTF-8 位元組原樣保留）。
    /// - parameters:
    ///   - bytes: 給定資料位元組。
    mutating func replaceData(bytes newBytes: [UInt8]) {
      if rawData == newBytes { return }
      rawData = newBytes
      // 載入期暫存：每個唯一轉換 key 對應的行引用（依行位置排列）。
      var protoKeys: [String] = []
      var protoKeyIndex: [String: Int] = [:]
      var protoRefs: [[AssociatesLineRef]] = []
      rawData.parseByteLines { lineRange in
        var keyRange: Range<Int>?
        var valueCellCount = 0
        rawData.parseByteCells(in: lineRange) { currentRange, currentIndex in
          if currentIndex == 0 {
            // "#" 開頭的 key cell 視為註解行，整行跳過。
            guard rawData[currentRange.lowerBound] != 0x23 else { return false }
            keyRange = currentRange
            return true
          }
          // "#" 開頭的 value cell：該行後續 cells 全部不錄。
          guard rawData[currentRange.lowerBound] != 0x23 else { return false }
          valueCellCount = currentIndex
          return true
        }
        guard let keyRange, valueCellCount > 0 else { return }
        let convertedKey = Self.cnvNGramKeyFromPinyinToPhona(
          target: String(decoding: rawData[keyRange], as: UTF8.self)
        )
        let lineRef = AssociatesLineRef(
          lineStart: UInt32(lineRange.lowerBound),
          lineEnd: UInt32(lineRange.upperBound),
          valueCellCount: UInt32(valueCellCount)
        )
        if let existing = protoKeyIndex[convertedKey] {
          protoRefs[existing].append(lineRef)
        } else {
          protoKeyIndex[convertedKey] = protoKeys.count
          protoKeys.append(convertedKey)
          protoRefs.append([lineRef])
        }
      }
      // 依 key bytes 排序（同 key 的行引用已在暫存階段依行位置排列）。
      let sortedOrder = protoKeys.indices.sorted {
        protoKeys[$0].utf8.lexicographicallyPrecedes(protoKeys[$1].utf8)
      }
      var newKeyData = [UInt8]()
      var newEntries: [AssociatesEntry] = []
      newEntries.reserveCapacity(sortedOrder.count)
      var newLineRefs: [AssociatesLineRef] = []
      for sourceIndex in sortedOrder {
        let keyStart = UInt32(newKeyData.count)
        newKeyData.append(contentsOf: protoKeys[sourceIndex].utf8)
        let keyEnd = UInt32(newKeyData.count)
        let refsStart = UInt32(newLineRefs.count)
        newLineRefs.append(contentsOf: protoRefs[sourceIndex])
        newEntries.append(.init(
          keyStart: keyStart,
          keyEnd: keyEnd,
          refsStart: refsStart,
          refsEnd: UInt32(newLineRefs.count)
        ))
      }
      keyData = newKeyData
      entries = newEntries
      lineRefs = newLineRefs
    }

    mutating func clear() {
      filePath = nil
      rawData.removeAll(keepingCapacity: false)
      keyData.removeAll(keepingCapacity: false)
      entries.removeAll(keepingCapacity: false)
      lineRefs.removeAll(keepingCapacity: false)
    }

    func saveData() {
      guard let filePath = filePath else { return }
      LMAssembly.withFileHandleQueueSync {
        do {
          // 以原始位元組寫回：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
          try Data(rawData).write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
          vCLMLog("Failed to save current database to: \(filePath)")
        }
      }
    }

    func valuesFor(pair: Homa.CandidatePair) -> [String] {
      var pairs: [String] = []
      if let index = entryIndex(for: pair.toNGramKey) {
        pairs.append(contentsOf: valuesAt(entryIndex: index))
      }
      if let index = entryIndex(for: pair.value) {
        pairs.append(contentsOf: valuesAt(entryIndex: index))
      }
      return pairs.deduplicated
    }

    func hasValuesFor(pair: Homa.CandidatePair) -> Bool {
      if entryIndex(for: pair.toNGramKey) != nil { return true }
      return entryIndex(for: pair.value) != nil
    }

    // MARK: Private

    /// 轉換後 keys 的 UTF-8 位元組 blob（key 經 `cnvNGramKeyFromPinyinToPhona` 轉換，非原文子字串）。
    private var keyData: [UInt8] = []
    /// 按 key bytes 排序的索引；同 key 多行時 refs 依行位置排列。
    private var entries: [AssociatesEntry] = []
    /// 全部行引用的平坦陣列。
    private var lineRefs: [AssociatesLineRef] = []

    /// 二分搜尋轉換後的 key，回傳對應的 entry 索引。
    private func entryIndex(for key: String) -> Int? {
      let keyUTF8 = Array(key.utf8)
      var lo = 0, hi = entries.count - 1
      while lo <= hi {
        let mid = lo + (hi - lo) / 2
        let e = entries[mid]
        let cmp = keyData.compareByteRange(Int(e.keyStart) ..< Int(e.keyEnd), with: keyUTF8)
        if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
      }
      return nil
    }

    /// 取出指定 entry 的全部關聯詞語（依行位置、再行內 cell 順序，不去重）。
    private func valuesAt(entryIndex index: Int) -> [String] {
      let e = entries[index]
      var pairs: [String] = []
      for i in Int(e.refsStart) ..< Int(e.refsEnd) {
        let ref = lineRefs[i]
        let lastValueIndex = Int(ref.valueCellCount)
        rawData.parseByteCells(in: Int(ref.lineStart) ..< Int(ref.lineEnd)) { currentRange, currentIndex in
          if currentIndex >= 1 {
            pairs.append(String(decoding: rawData[currentRange], as: UTF8.self))
          }
          return currentIndex < lastValueIndex
        }
      }
      return pairs
    }
  }
}

extension LMAssembly.LMAssociates {
  var dictRepresented: [String: [String]] {
    var result = [String: [String]]()
    entries.indices.forEach { index in
      let e = entries[index]
      let key = String(decoding: keyData[Int(e.keyStart) ..< Int(e.keyEnd)], as: UTF8.self)
      result[key] = valuesAt(entryIndex: index)
    }
    return result
  }
}
