// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Shared

// MARK: - dump-userdef-metadata

extension VCSharedCLI {
  /// 後設資料之外洩格式版本。凡不相容之變更皆須遞增此值。
  static let userDefMetadataSchemaVersion = 1

  /// 後設資料之產生器署名。
  static let userDefMetadataGeneratorName = "vChewingSharedCLI dump-userdef-metadata"

  /// `MetaData` 內所有可本地化之欄位（`userDef` 與 `minimumOS` 除外）。
  static let userDefLocalizableFieldNames = [
    "shortTitle", "prompt", "inlinePrompt", "popupPrompt", "description", "toolTip",
  ]

  // MARK: - 動詞入口

  /// 匯出 `UserDef` 之程式面後設資料（可選帶四語系已翻譯之標籤）。
  ///
  /// 用法：`dump-userdef-metadata [<locale>=<path-to-.strings>]... [--extra-label-prefix=<prefix>]... [--strict]`
  /// - **stdout 只承載純 JSON**（俾使 `> file.json` 直接可用）；一切警告與缺鍵報告走 stderr。
  ///   此點與本 CLI 其餘動詞「進度印 stdout」之慣例刻意不同。
  /// - 不給任何 `locale=path` 時，仍輸出完整之程式面後設資料（標籤為空）——故本動詞在沒有
  ///   `.strings` 的環境下依然可用、且便於測試。
  /// - `--extra-label-prefix` 用於收錄「非 UserDef 命名空間、但助手也需要」之既有 i18n 鍵
  ///   （如 `i18n:KeyboardLayout.`／`i18n:TypingMethod.`——唯音之注音／拼音排列選單名稱係由
  ///   `KeyboardParser.localizedMenuName` 供出，不經 `UserDef.metaData`）。此設計使助手不必
  ///   手抄這些標籤、亦不必為此令本 CLI 相依 Tekkon。
  /// - Parameter arguments: 位置引數。`<locale>=<path>` 與 `--extra-label-prefix=<prefix>` 皆可
  ///   給任意組；`--strict` 至多一次。
  /// - Returns: 行程退出碼——`0` 成功；`1` 引數不合法或 `.strings` 讀不到；
  ///   加 `--strict` 時，任一語系缺任一鍵、或任一 case 確有未遷移之標籤，回 `1`
  ///   （俾使 CI 得以把「i18n 未補齊」變成紅燈；已知之偽陽性見 `metadataPendingReason`）。
  static func dumpUserDefMetadata(arguments: [String]) -> Int32 {
    var localePaths = [(locale: String, path: String)]()
    var extraLabelPrefixes = [String]()
    var strict = false

    for argument in arguments {
      if argument == "--strict" {
        strict = true
        continue
      }
      if argument.hasPrefix("--extra-label-prefix=") {
        let prefix = String(argument.dropFirst("--extra-label-prefix=".count))
        guard !prefix.isEmpty else {
          reportError("不合法的引數：`\(argument)`。前綴不得為空。")
          return 1
        }
        extraLabelPrefixes.append(prefix)
        continue
      }
      guard let separatorIndex = argument.firstIndex(of: "=") else {
        reportError("不合法的引數：`\(argument)`。每個語系引數之形制須為 `<locale>=<path>`。")
        return 1
      }
      let locale = String(argument[argument.startIndex ..< separatorIndex])
      let path = String(argument[argument.index(after: separatorIndex)...])
      guard !locale.isEmpty, !path.isEmpty else {
        reportError("不合法的引數：`\(argument)`。語系名稱與路徑皆不得為空。")
        return 1
      }
      localePaths.append((locale: locale, path: path))
    }

    // 逐語系讀入 `.strings`（old-style plist），並依「首次出現」之次序保留語系清單。
    var locales = [String]()
    var localeStrings = [String: [String: String]]()
    for entry in localePaths {
      let standardizedPath = (entry.path as NSString).standardizingPath
      guard let dict = NSDictionary(contentsOfFile: standardizedPath) as? [String: String] else {
        reportError("無法讀取 .strings 檔：\(standardizedPath)")
        return 1
      }
      if !locales.contains(entry.locale) { locales.append(entry.locale) }
      localeStrings[entry.locale] = dict
    }

    var entries = [[String: Any]]()
    var pendingKeys = [String]()
    for userDef in UserDef.allCases {
      let (entry, pendingReason) = metadataEntry(
        for: userDef, locales: locales, localeStrings: localeStrings
      )
      entries.append(entry)
      if pendingReason != "none" { pendingKeys.append(String(describing: userDef)) }
    }

    let missingI18nKeys = collectMissingI18nKeys(locales: locales, localeStrings: localeStrings)
    let extraLabels = collectExtraLabels(
      prefixes: extraLabelPrefixes, locales: locales, localeStrings: localeStrings
    )

    var root = [String: Any]()
    root["schemaVersion"] = userDefMetadataSchemaVersion
    root["generator"] = userDefMetadataGeneratorName
    root["locales"] = locales
    root["count"] = entries.count
    root["entries"] = entries
    root["missingI18nKeys"] = missingI18nKeys
    root["pendingMetadataKeys"] = pendingKeys
    root["extraLabelPrefixes"] = extraLabelPrefixes
    root["extraLabels"] = extraLabels

    guard JSONSerialization.isValidJSONObject(root),
          let data = try? JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys]
          )
    else {
      reportError("後設資料無法序列化為 JSON。")
      return 1
    }
    assert(entries.count == UserDef.allCases.count)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))

    guard strict else { return 0 }

    var strictViolations = 0
    if !missingI18nKeys.isEmpty {
      strictViolations += 1
      var message = "!! --strict：\(missingI18nKeys.count) 條 i18n 鍵缺漏：\n"
      for item in missingI18nKeys {
        message += "   - [\(item["locale"] ?? "?")] \(item["key"] ?? "?")\n"
      }
      FileHandle.standardError.write(Data(message.utf8))
    }
    if !pendingKeys.isEmpty {
      strictViolations += 1
      var message = "!! --strict：\(pendingKeys.count) 條 UserDef 之標籤尚未完成 i18n 遷移：\n"
      for key in pendingKeys { message += "   - \(key)\n" }
      FileHandle.standardError.write(Data(message.utf8))
    }
    return strictViolations > 0 ? 1 : 0
  }

  // MARK: - 逐鍵後設資料

  /// 組裝單一 `UserDef` case 之後設資料辭典。
  ///
  /// - Returns: 該 case 之辭典，暨其標籤狀態（`none`／`unmigratedLabels`／
  ///   `unmigratedOptionLabels`）——判準與 app 側之 `isMetadataPendingManualUpdate` 同源。
  private static func metadataEntry(
    for userDef: UserDef,
    locales: [String],
    localeStrings: [String: [String: String]]
  )
    -> (entry: [String: Any], pendingReason: String) {
    let caseName = String(describing: userDef)
    let dataType = userDef.dataType
    let metaData = userDef.metaData
    let options = metaData?.options ?? [:]

    var entry = [String: Any]()
    entry["key"] = caseName
    entry["rawValue"] = userDef.rawValue
    entry["type"] = semanticTypeName(of: dataType)
    entry["defaultsType"] = dataType.defaultsCommandTypeName
    entry["default"] = dataType.defaultValue
    if let range = userDef.validNumeralValueRange {
      entry["range"] = [range.lowerBound, range.upperBound]
    } else {
      entry["range"] = NSNull()
    }
    entry["minimumOS"] = metaData?.minimumOS ?? 10.9
    entry["exchangeBlacklisted"] = UserDef.jsonExchangeBlacklist.contains(userDef)

    // 標籤狀態：先看非選項之標籤欄位，再看選項。
    let pendingReason = pendingReason(metaData: metaData)
    entry["metadataPending"] = pendingReason != "none"
    entry["metadataPendingReason"] = pendingReason

    // 單選題之選項：值域 ＋ 各語系之已翻譯標籤。
    // 「標籤即其值之十進位數字」者不承載任何語意（如字級滑桿之 12…196），故不收錄、
    // 而以 `optionsKind: "numeric"` 記明——消費端據 `range` 出數值輸入即可。
    if options.isEmpty {
      entry["options"] = NSNull()
      entry["optionsKind"] = NSNull()
    } else if isNumericOptionSet(options) {
      entry["options"] = NSNull()
      entry["optionsKind"] = "numeric"
    } else {
      var optionEntries = [[String: Any]]()
      for index in options.keys.sorted() {
        let rawLabel = options[index] ?? ""
        var optionEntry = [String: Any]()
        optionEntry["value"] = index
        optionEntry["i18nKey"] = rawLabel
        var labels = [String: Any]()
        for locale in locales {
          labels[locale] = resolvedLabel(
            rawLabel, locale: locale, strings: localeStrings[locale]
          ) ?? NSNull()
        }
        optionEntry["labels"] = labels
        optionEntries.append(optionEntry)
      }
      entry["options"] = optionEntries
      entry["optionsKind"] = "labels"
    }

    // 逐語系之標籤（僅收有值者，以免輸出膨脹）。
    var labels = [String: Any]()
    for locale in locales {
      var fields = [String: Any]()
      for fieldName in userDefLocalizableFieldNames {
        guard let resolved = resolvedLabel(
          localizableFieldValue(metaData: metaData, fieldName: fieldName),
          locale: locale,
          strings: localeStrings[locale]
        ) else { continue }
        fields[fieldName] = resolved
      }
      labels[locale] = fields
    }
    entry["labels"] = labels

    return (entry, pendingReason)
  }

  /// 判定某 case 之標籤狀態（`none`／`unmigratedLabels`／`unmigratedOptionLabels`）。
  ///
  /// 判準與 app 側之 `UserDef.isMetadataPendingManualUpdate` **同源**：後者已於 2026-09-24
  /// 修訂為「凡以 `i18n:` 起頭者即為已遷移」（不再要求鍵名恰等於
  /// `i18n:UserDef.<case>.<field>`），故 `kCandidateListTextSize`／
  /// `kPopupCompositionBufferTextSize`（標籤即其值之數字）與 `kKanjiConversionPreferences`
  /// （用既有之 `i18n:KanjiConversionMode.*` 命名空間）三者之偽陽性已由該處根治。
  /// 本函式只負責把「真欠譯」再細分為標籤欄位與選項兩類，俾便人工稽核。
  private static func pendingReason(metaData: UserDef.MetaData?) -> String {
    guard let metaData, metaData.hasFieldPendingManualUpdate else { return "none" }
    // 非選項之標籤欄位只要出現非 `i18n:` 形式者，即為標籤欠譯。
    for fieldName in userDefLocalizableFieldNames {
      guard let rawValue = localizableFieldValue(metaData: metaData, fieldName: fieldName) else { continue }
      guard !rawValue.hasPrefix(VCSharedCLI.i18nKeyPrefix) else { continue }
      return "unmigratedLabels"
    }
    return "unmigratedOptionLabels"
  }

  /// 該組選項之標籤是否**逐項**皆為其值之十進位數字。
  private static func isNumericOptionSet(_ options: [Int: String]) -> Bool {
    guard !options.isEmpty else { return false }
    for (index, label) in options where label != String(index) { return false }
    return true
  }

  /// `DataType` 之語意型別名稱（`defaults write` 之型別名另見 `defaultsType`）。
  private static func semanticTypeName(of dataType: UserDef.DataType) -> String {
    switch dataType {
    case .string: return "string"
    case .bool: return "bool"
    case .integer: return "integer"
    case .double: return "double"
    case .arrayOfStrings: return "arrayOfStrings"
    case .dictionary: return "dictionary"
    }
  }

  /// 取 `MetaData` 內之單一可本地化欄位值。
  private static func localizableFieldValue(
    metaData: UserDef.MetaData?,
    fieldName: String
  )
    -> String? {
    guard let metaData else { return nil }
    switch fieldName {
    case "shortTitle": return metaData.shortTitle
    case "prompt": return metaData.prompt
    case "inlinePrompt": return metaData.inlinePrompt
    case "popupPrompt": return metaData.popupPrompt
    case "description": return metaData.description
    case "toolTip": return metaData.toolTip
    default: return nil
    }
  }

  /// 把 `i18n:` 形式之鍵解為該語系之譯文。
  ///
  /// - 無值或空字串 ⇒ `nil`（呼叫端據此略去該欄位）。
  /// - 尚未遷移之裸字串 ⇒ 原樣回傳。
  /// - 已遷移但該語系查無此鍵 ⇒ `nil`（並由 `missingI18nKeys` 統一報告）。
  private static func resolvedLabel(
    _ rawValue: String?,
    locale: String,
    strings: [String: String]?
  )
    -> String? {
    guard let rawValue, !rawValue.isEmpty else { return nil }
    guard rawValue.hasPrefix("i18n:") else { return rawValue }
    guard let strings else { return nil }
    return strings[rawValue]
  }

  // MARK: - i18n 覆蓋率報告

  /// 逐語系收集「`UserDef` 標籤宣稱有、但該語系 `.strings` 查無」之鍵。
  ///
  /// 此為本倉既有工具鏈所無之能力：`generate-missing-strings` 只做 `.strings` 之間之互相對位，
  /// 不驗與 `UserDef` 之對位。
  private static func collectMissingI18nKeys(
    locales: [String],
    localeStrings: [String: [String: String]]
  )
    -> [[String: String]] {
    var result = [[String: String]]()
    for locale in locales {
      guard let strings = localeStrings[locale] else { continue }
      for userDef in UserDef.allCases {
        guard let metaData = userDef.metaData else { continue }
        for fieldName in userDefLocalizableFieldNames {
          let rawValue = localizableFieldValue(metaData: metaData, fieldName: fieldName)
          guard let rawValue, rawValue.hasPrefix("i18n:") else { continue }
          guard strings[rawValue] == nil else { continue }
          result.append(["locale": locale, "key": rawValue])
        }
        guard let options = metaData.options, !isNumericOptionSet(options) else { continue }
        for index in options.keys.sorted() {
          guard let rawValue = options[index], rawValue.hasPrefix("i18n:") else { continue }
          guard strings[rawValue] == nil else { continue }
          result.append(["locale": locale, "key": rawValue])
        }
      }
    }
    return result.sorted {
      let lhs = ($0["locale"] ?? "", $0["key"] ?? "")
      let rhs = ($1["locale"] ?? "", $1["key"] ?? "")
      return lhs < rhs
    }
  }

  /// 收集「非 UserDef 命名空間、但助手也需要」之既有 i18n 鍵。
  ///
  /// 逐語系掃描整份 `.strings`、取鍵名前綴命中者；鍵集依前綴排序後取聯集（故各語系之鍵集相同
  /// 者不受字典走訪序影響）。
  private static func collectExtraLabels(
    prefixes: [String],
    locales: [String],
    localeStrings: [String: [String: String]]
  )
    -> [String: [String: String]] {
    guard !prefixes.isEmpty else { return [:] }
    // 先取聯集鍵集（以任一份 .strings 為準即可，因四語系之鍵集相同）。
    var allKeys = Set<String>()
    for (_, strings) in localeStrings {
      for key in strings.keys where prefixes.contains(where: { key.hasPrefix($0) }) {
        allKeys.insert(key)
      }
    }
    var result = [String: [String: String]]()
    for locale in locales {
      guard let strings = localeStrings[locale] else { continue }
      var perLocale = [String: String]()
      for key in allKeys.sorted() {
        guard let value = strings[key] else { continue }
        perLocale[key] = value
      }
      result[locale] = perLocale
    }
    return result
  }

  /// 統一的 stderr 報告出口。
  private static func reportError(_ message: String) {
    FileHandle.standardError.write(Data("!! \(message)\n".utf8))
  }
}
