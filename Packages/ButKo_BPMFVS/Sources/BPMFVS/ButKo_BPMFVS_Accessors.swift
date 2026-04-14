// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 該檔案不包括 ButKo BPMFVS 原始資料實作。BPMFVS 原始資料著作權資訊詳見：
// http://github.com/ButTaiwan/bpmfvs/raw/refs/heads/master/NOTICE.txt

import Foundation

public enum BPMFVS {
  // MARK: Public

  public static func getBPMFVSDataURL() -> URL? {
    // Bundle.module is MainActor-isolated in this context.
    Bundle.module.url(forResource: "phonic_table_Z", withExtension: "txt")
  }

  public static func normalizeBPMFVSReading(_ reading: String) -> String {
    var normalized = reading.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.last == "1" {
      normalized.removeLast()
    }
    if normalized.last == "˙" {
      normalized.removeLast()
      normalized.insert("˙", at: normalized.startIndex)
    }
    return normalized
  }

  public static func convert(value: String, reading: String) -> String {
    guard value.count == 1 else { return value }
    let normalizedReading = normalizeBPMFVSReading(reading)
    guard let slot = cachedLookupTable?.slot(of: value, for: normalizedReading) else {
      return value
    }
    guard slot > 0 else { return value }
    guard let selector = UnicodeScalar(variationSelectorBase + UInt32(slot)) else {
      return value
    }
    return value + String(selector)
  }

  public static func convert(value: String, readings: [String]) -> String {
    guard value.count == readings.count else { return value }
    return zip(value, readings).reduce(into: "") { partialResult, pair in
      partialResult += convert(value: String(pair.0), reading: pair.1)
    }
  }

  public static func convertToBPMFVS(smashedPairs: [(key: String, value: String)]) -> String {
    var converted = ""
    smashedPairs.forEach { key, value in
      let subKeys = key.split(separator: "\t")
      switch subKeys.count {
      case 1:
        let reading = subKeys[0].description
        if reading.isEmpty || reading.first == "_" {
          converted += value
          return
        }
        converted += convert(value: value, reading: reading)
      default:
        converted += value
      }
    }
    return converted
  }

  // MARK: Private

  private struct LookupTable {
    // MARK: Lifecycle

    init(fileURL: URL) throws {
      var readingsByValue = [String: [String: Int]]()
      let rawText = try String(contentsOf: fileURL, encoding: .utf8)
      rawText.enumerateLines { currentLine, _ in
        guard !currentLine.isEmpty, currentLine.first != "#" else { return }
        let cells = currentLine.split(separator: "\t", omittingEmptySubsequences: false)
        guard cells.count >= 4 else { return }
        let value = cells[0].description
        var readingMap = [String: Int]()
        cells.dropFirst(3).enumerated().forEach { index, reading in
          let normalizedReading = BPMFVS.normalizeBPMFVSReading(reading.description)
          if readingMap[normalizedReading] == nil {
            readingMap[normalizedReading] = index
          }
        }
        readingsByValue[value] = readingMap
      }
      self.readingsByValue = readingsByValue
    }

    // MARK: Internal

    let readingsByValue: [String: [String: Int]]

    func slot(of value: String, for reading: String) -> Int? {
      readingsByValue[value]?[reading]
    }
  }

  private static let variationSelectorBase: UInt32 = 0xE01E0

  private static let cachedLookupTable: LookupTable? = {
    guard let fileURL = getBPMFVSDataURL() else { return nil }
    return try? LookupTable(fileURL: fileURL)
  }()
}
