// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import ResourceLocator

// MARK: - PunctuationData

/// 原廠標點語料與成對標點關係的唯讀載體。
///
/// 兩份資料檔皆在本 target 的 `Resources` 內，隨 `LibVanguard` 動態庫一同出貨：
/// - `data-punctuations.txt`：`<key> <value> <value>...`；分數恆為 0，故省略。
/// - `data-paired-punctuations.txt`：`<leftKey> <rightKey> <pair> <pair>...`；
///   每個 `pair` 恰為兩個字元。
///
/// 兩者皆為 UTF-8、以 ASCII 空白分欄（tab 亦容忍）、以 `#` 起首之整行視為註解。
/// 解析失敗的行一律跳過，不使輸入法崩潰。
///
/// **查找一律走 `ResourceLocator`，不以 SwiftPM 自動生成的 `Bundle.module` 為入口**：
/// 後者於 Swift 5.10 產出的 accessor 只探「`Bundle.main.bundleURL` ＋ 資源 bundle 名」
/// 與建置機上那條絕對路徑，而資源 bundle 實際住在 `.app/Contents/Resources/`——在別台
/// 機器上這兩條皆落空，且該 accessor 落空時是 `fatalError` 而非回 `nil`。查找落空時
/// 本型別回傳空表（標點由原廠辭典獨自供應）；宿主可經
/// `ResourceProvision.specifyResourceBundle(_:forBundleNamed:)` 指定
/// `LibVanguard_Shared`（資源 bundle 本身或其所在目錄皆可）。
public enum PunctuationData {
  // MARK: Public

  public struct Record: Hashable, Sendable {
    // MARK: Lifecycle

    public init(key: String, value: String, score: Double = 0) {
      self.key = key
      self.value = value
      self.score = score
    }

    // MARK: Public

    public let key: String
    public let value: String
    public let score: Double
  }

  public struct PairedEntry: Hashable, Sendable {
    // MARK: Lifecycle

    public init(left: String, right: String, leftKey: String, rightKey: String) {
      self.left = left
      self.right = right
      self.leftKey = leftKey
      self.rightKey = rightKey
    }

    // MARK: Public

    public let left: String
    public let right: String
    public let leftKey: String
    public let rightKey: String
  }

  public static let records: [Record] = loadRecords()
  public static let pairedEntries: [PairedEntry] = loadPairedEntries()

  public static let recordsByKey: [String: [Record]] = Dictionary(
    grouping: records,
    by: \.key
  )

  /// 標點語料是否已成功載入。載入失敗時為 `false`，此時標點由原廠辭典獨自供應。
  public static var isLoaded: Bool { !records.isEmpty }

  /// 成對標點資料是否已成功載入。載入失敗時為 `false`，此時不提供成對標點之拆對與同步。
  public static var hasPairedEntries: Bool { !pairedEntries.isEmpty }

  // MARK: Internal

  /// 讀取本 target 資源 bundle 內的指定文字檔；查找落空時回傳 `nil`（不崩潰）。
  ///
  /// 刻意非 `private`：測試以 `@testable import` 驗「查無資源時回 `nil`」。
  static func loadText(_ fileNameStem: String) -> String? {
    guard let url = ResourceLocator.url(
      forResource: fileNameStem,
      withExtension: "txt",
      inSwiftPMResourceBundleNamed: resourceBundleName,
      anchor: ResourceBundleAnchor.self
    ) else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
  }

  // MARK: Private

  /// 用於推得編譯產物所在位置的錨定型別。
  private final class ResourceBundleAnchor {}

  /// SwiftPM 資源 bundle 名稱（`套件名_目標名`）。
  private static let resourceBundleName = "LibVanguard_Shared"

  private static func loadRecords() -> [Record] {
    guard let text = loadText("data-punctuations") else { return [] }
    return text.split(whereSeparator: \.isNewline).flatMap { line -> [Record] in
      let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty, !line.hasPrefix("#") else { return [] }
      let cells = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
      guard cells.count >= 2 else { return [] }
      let key = String(cells[0])
      guard key.hasPrefix("_") else { return [] }
      return cells.dropFirst().map { Record(key: key, value: String($0)) }
    }
  }

  private static func loadPairedEntries() -> [PairedEntry] {
    guard let text = loadText("data-paired-punctuations") else { return [] }
    return text.split(whereSeparator: \.isNewline).flatMap { line -> [PairedEntry] in
      let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty, !line.hasPrefix("#") else { return [] }
      let cells = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
      guard cells.count >= 3 else { return [] }
      let leftKey = String(cells[0])
      let rightKey = String(cells[1])
      guard leftKey.hasPrefix("_"), rightKey.hasPrefix("_") else { return [] }
      return cells.dropFirst(2).compactMap { token in
        let chars = Array(token)
        guard chars.count == 2 else { return nil }
        return PairedEntry(
          left: String(chars[0]),
          right: String(chars[1]),
          leftKey: leftKey,
          rightKey: rightKey
        )
      }
    }
  }
}
