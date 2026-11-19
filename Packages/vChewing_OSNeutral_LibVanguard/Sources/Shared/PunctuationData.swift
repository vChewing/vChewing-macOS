// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

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

  // MARK: Private

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

  private static func loadText(_ fileNameStem: String) -> String? {
    guard let url = Bundle.module.url(forResource: fileNameStem, withExtension: "txt") else {
      return nil
    }
    return try? String(contentsOf: url, encoding: .utf8)
  }
}
