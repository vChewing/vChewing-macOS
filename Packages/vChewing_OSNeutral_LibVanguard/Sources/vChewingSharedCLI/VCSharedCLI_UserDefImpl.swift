// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Shared

extension VCSharedCLI {
  /// 本地化鍵之前綴。凡以此起頭者即為「已遷移」之標籤。
  static let i18nKeyPrefix = "i18n:"

  /// 該選項標籤是否為「值即標籤」之數字（如字級之 `"12"`…`"196"`）。
  ///
  /// 此類標籤不承載語意、亦非待遷移之英文原文，故不算欠譯、亦不入轉換表。
  static func isLiteralNumeralLabel(_ label: String, index: Int) -> Bool {
    label == String(index)
  }
}

extension UserDef.MetaData {
  /// 回傳「是否有任一可本地化欄位仍為未遷移之裸字串」。
  ///
  /// 判準（2026-09-24 修訂）：**凡以 `i18n:` 起頭者即為已遷移**——不要求鍵名恰好等於
  /// `i18n:UserDef.<case>.<field>`。舊制以「鍵名是否等於該 canonical 形式」為判準，
  /// 對三條鍵誤報：
  /// - `kCandidateListTextSize`／`kPopupCompositionBufferTextSize`：其 `options` 係
  ///   「以值域逐值生成、標籤即該值本身」（`"12"`…`"196"`／`"18"`…`"40"`）；
  /// - `kKanjiConversionPreferences`：其 `options` 用既有之 `i18n:KanjiConversionMode.*`
  ///   命名空間（已遷移，只是不在 `UserDef` 之命名空間內）。
  ///
  /// 三者皆非「待遷移之英文原文」。修訂後 `list-pending-userdef` 與
  /// `dump-userdef-metadata --strict` 只對**真欠譯**亮紅燈。
  ///
  /// 以 `Mirror` 走訪儲存屬性，使本檢查與 `UserDef.i18nKeyConvMap` 自動對位、不必重複欄位清單。
  public var hasFieldPendingManualUpdate: Bool {
    let mirror = Mirror(reflecting: self)
    let skippedLabels: Set<String> = ["userDef", "minimumOS"]

    for child in mirror.children {
      guard let label = child.label, !skippedLabels.contains(label) else { continue }

      if label == "options" {
        guard let options = child.value as? [Int: String], !options.isEmpty else { continue }
        for idx in options.keys.sorted() {
          guard let rawValue = options[idx] else { continue }
          if rawValue.hasPrefix(VCSharedCLI.i18nKeyPrefix) { continue }
          if VCSharedCLI.isLiteralNumeralLabel(rawValue, index: idx) { continue }
          return true
        }
      } else if let rawString = child.value as? String {
        if rawString.hasPrefix(VCSharedCLI.i18nKeyPrefix) { continue }
        return true
      }
    }

    return false
  }
}

extension UserDef {
  public var isMetadataPendingManualUpdate: Bool {
    metaData?.hasFieldPendingManualUpdate ?? false
  }

  /// 產生「`i18n:` 形式之新鍵 → 現行裸字串值」之對照表，涵蓋所有尚未遷移之 `MetaData` 欄位。
  ///
  /// 以 `Mirror` 走訪 `MetaData` 之儲存屬性，故新增欄位自動涵蓋、無須人工清點。
  ///
  /// 判準同 `hasFieldPendingManualUpdate`（2026-09-24 修訂）：**已以 `i18n:` 起頭者、
  /// 以及「值即標籤」之數字選項，一概不進此表**——否則 `convert-userdef-source` 會去
  /// 改寫已是鍵的字串，`generate-missing-strings` 更會為 `"12"` 一類數字憑空生出
  /// `i18n:UserDef.<case>.option.12 = "12"` 這種無用條目。
  ///
  /// - Returns: `nil` 表示該 case 無 `MetaData`、或所有欄位皆已遷移。
  public var i18nKeyConvMap: [String: String]? {
    guard let metaData else { return nil }
    var result = [String: String]()
    let caseName = String(describing: self)
    let mirror = Mirror(reflecting: metaData)

    // These MetaData fields are not localizable strings and must be skipped.
    let skippedLabels: Set<String> = ["userDef", "minimumOS"]

    for child in mirror.children {
      guard let label = child.label, !skippedLabels.contains(label) else { continue }

      if label == "options" {
        guard let options = child.value as? [Int: String] else { continue }
        guard !options.isEmpty else { continue }
        let stem = "\(VCSharedCLI.i18nKeyPrefix)UserDef.\(caseName).option"
        for idx in options.keys.sorted() {
          guard let oldVal = options[idx] else { continue }
          guard !oldVal.hasPrefix(VCSharedCLI.i18nKeyPrefix) else { continue }
          guard !VCSharedCLI.isLiteralNumeralLabel(oldVal, index: idx) else { continue }
          let newKey = "\(stem).\(idx)"
          guard newKey != oldVal else { continue }
          result[newKey] = oldVal
        }
      } else if let oldString = child.value as? String {
        guard !oldString.hasPrefix(VCSharedCLI.i18nKeyPrefix) else { continue }
        let newKey = "\(VCSharedCLI.i18nKeyPrefix)UserDef.\(caseName).\(label)"
        guard newKey != oldString else { continue }
        result[newKey] = oldString
      }
    }

    return result.isEmpty ? nil : result
  }

  public static var i18nKeyConvMapTotal: [String: String] {
    Self.allCases.reduce(into: [String: String]()) { result, userDef in
      guard let map = userDef.i18nKeyConvMap else { return }
      result.merge(map) { _, new in new }
    }
  }
}
