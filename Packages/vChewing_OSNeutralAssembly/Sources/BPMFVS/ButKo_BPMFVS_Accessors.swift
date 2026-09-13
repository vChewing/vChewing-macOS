// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 該檔案不包括 ButKo BPMFVS 原始資料實作。BPMFVS 原始資料著作權資訊詳見：
// http://github.com/ButTaiwan/bpmfvs/raw/refs/heads/master/NOTICE.txt

import Foundation
import ResourceLocator

public enum BPMFVS {
  // MARK: Public

  /// 手動指定的 BPMFVS 資料表位置。`nil` 代表退回預設查找邏輯。
  ///
  /// 本模組被編譯成動態庫、或被置於非 SwiftPM 佈局時，預設查找會落空；
  /// 宿主可藉此指定資料表位置，或改由
  /// `ResourceLocator.specifyResourceBundleURL(_:forBundleNamed:)` 指定整包資源。
  public static var dataURLOverride: URL? {
    didSet { cachedLookupTable = loadLookupTable() }
  }

  /// 資料表是否已成功載入。載入失敗時，所有轉換皆原樣回傳輸入值。
  public static var isDataTableLoaded: Bool { cachedLookupTable != nil }

  /// 手動指定 BPMFVS 資料表位置。傳入 `nil` 代表清除指定、退回預設查找。
  public static func specifyDataURL(_ url: URL?) {
    dataURLOverride = url
  }

  /// BPMFVS 資料表的路徑。查找失敗時回傳 `nil`，呼叫端須自行實裝 fail-safe。
  public static func getBPMFVSDataURL() -> URL? {
    dataURLOverride ?? ResourceLocator.url(
      forResource: "phonic_table_Z",
      withExtension: "txt",
      inSwiftPMResourceBundleNamed: Self.resourceBundleName,
      anchor: ResourceBundleAnchor.self
    )
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

  /// 用於推得編譯產物所在位置的錨定型別。
  private final class ResourceBundleAnchor {}

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

  /// SwiftPM 資源 bundle 名稱（`套件名_目標名`）。
  private static let resourceBundleName = "OSNeutralAssembly_BPMFVS"

  /// 查找結果的快取。查找落空時為 `nil`，此時所有轉換皆原樣回傳輸入值。
  private static var cachedLookupTable: LookupTable? = loadLookupTable()

  private static func loadLookupTable() -> LookupTable? {
    guard let fileURL = getBPMFVSDataURL() else { return nil }
    return try? LookupTable(fileURL: fileURL)
  }
}
