// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Arimitsu
import CoreFoundation
import Foundation

// MARK: - DualpinImportIssue

/// 雙拼方案校驗未過時，單條錯誤之可攜形（錯誤碼 ＋ 引擎給出之說明）。
public struct DualpinImportIssue: Equatable, Sendable {
  // MARK: Lifecycle

  public init(code: String, detail: String) {
    self.code = code
    self.detail = detail
  }

  // MARK: Public

  /// 錯誤碼（`E1`…`E9`）。
  public let code: String
  /// 引擎給出之說明。
  public let detail: String
}

// MARK: - DualpinImportFailure

/// 雙拼資料匯入失敗之因由。
public enum DualpinImportFailure: Equatable, Sendable {
  /// 檔案無法讀取（權限、I/O，或非 UTF-8 文字）。
  case unreadable
  /// 檔案過大（上限見 `DualpinSchemaStore.maximumImportByteCount`）。
  case tooLarge
  /// JSON 無法解碼為雙拼方案。
  case malformed
  /// 方案未通過校驗（`E1`…`E9`）。
  case invalid([DualpinImportIssue])
}

// MARK: - DualpinImportOutcome

/// 雙拼資料匯入之結果。
public enum DualpinImportOutcome: Equatable, Sendable {
  /// 匯入成功。附方案之 `rawID` 與依當前語系解析之標題。
  case success(rawID: String, title: String)
  /// 匯入失敗。
  case failure(DualpinImportFailure)
}

// MARK: - DualpinSchemaStore

/// 雙拼（Dualpin）自訂方案之查詢與匯入。
///
/// 方案以 JSON 原文單筆存於 `UserDef.kDualpinSchemaJSON`：匯入即整份取代，不另存檔案。
/// 本型別只呼叫 `Arimitsu` 之公開面（解碼、校驗、標題），**不自行實作任何檢證邏輯**——
/// 檢證語義屬引擎，設定介面只負責轉述其結論。
public enum DualpinSchemaStore {
  // MARK: Public

  /// 匯入檔之大小上限（1 MiB）。
  public static let maximumImportByteCount = 1_048_576

  /// 官方網站所發表之 JSON Schema 之 canonical URL，供新建之方案自報 `$schema` 用。
  public static let canonicalSchemaURLString =
    "https://vchewing.github.io/valueadd/dualpin-schema-files/vChewing_dualpin_Schema.schema.json"

  /// 目前偏好設定內之自訂方案。無方案、或原文無法解碼時為 `nil`。
  public static var currentParser: DualpinParser? {
    let json = PrefMgr.shared.dualpinSchemaJSON
    guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(DualpinParser.self, from: data)
  }

  /// 目前自訂方案之標題（依當前語系）。無方案時為 `nil`。
  public static var currentTitle: String? {
    let tag = PrefMgr.shared.appleLanguages.first ?? "en"
    return currentParser?.title(forLocaleTag: tag)
  }

  /// 目前方案原文內之 `$schema` 值（若有）。供方案編輯器往返時保住該欄。
  public static var currentSchemaURLString: String? {
    schemaURLString(inJSON: PrefMgr.shared.dualpinSchemaJSON)
  }

  /// 自方案 JSON 原文抽出 `$schema` 之值。原文非 JSON、或無該欄時為 `nil`。
  public static func schemaURLString(inJSON json: String) -> String? {
    guard !json.isEmpty, let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let value = object["$schema"] as? String,
          !value.isEmpty
    else { return nil }
    return value
  }

  /// 將方案序列化為 JSON 原文（與官網所發表者同格式）。
  ///
  /// `JSONEncoder` 不保證鍵序（其實作以雜湊序走訪），而本格式之可讀性與既有檔案之
  /// diff 穩定性皆倚賴鍵序。故先交由 `JSONEncoder` 編碼以取得引擎認可之欄位集合與其
  /// 取值，再以 `JSONSerialization` 取回物件、自寫有序之 pretty-printer 重排。
  ///
  /// 頂層鍵序＝`DualpinParser.CodingKeys` 之宣告序（`$schema` 置首）；巢狀表之鍵一律排序，
  /// 以求決定性。縮排 2 空格、結尾換行。
  ///
  /// - Parameters:
  ///   - parser: 待序列化之方案。
  ///   - schemaURLString: 要寫入 `$schema` 之值。`nil` 時用 `canonicalSchemaURLString`。
  /// - Returns: JSON 原文；編碼失敗時為 `nil`。
  public static func serialize(
    _ parser: DualpinParser,
    schemaURLString: String? = nil
  )
    -> String? {
    guard let data = try? JSONEncoder().encode(parser),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dict = object as? [String: Any]
    else { return nil }
    let topLevelKeyOrder = [
      "rawID", "rawTitle", "localizedTitle", "initials", "finals",
      "nullOnset", "keyInterception", "autochopPolicy",
      "overrides", "aliases", "acknowledgedUnreachable",
    ]
    var lines: [String] = [
      jsonLine(
        key: "$schema",
        value: schemaURLString ?? canonicalSchemaURLString,
        indent: 1
      ),
    ]
    for key in topLevelKeyOrder {
      guard let value = dict[key] else { continue }
      lines.append(jsonLine(key: key, value: value, indent: 1))
    }
    return "{\n" + lines.joined(separator: ",\n") + "\n}\n"
  }

  /// 將方案存回偏好設定（不經任何檔案面板）。
  ///
  /// 收尾與 `importSchema(from:)` 同：方案唯有切至「自訂雙拼」且開啟雙拼模式時才被使用，
  /// 故一併設定該三鍵。校驗未過時不寫入，逕回 `.failure(.invalid(_:))`。
  ///
  /// - Parameters:
  ///   - parser: 待儲存之方案。
  ///   - schemaURLString: 要寫入 `$schema` 之值。`nil` 時沿用現行原文之值
  ///     （再無則用 `canonicalSchemaURLString`）。
  /// - Returns: 儲存結果。
  public static func save(
    _ parser: DualpinParser,
    schemaURLString: String? = nil
  )
    -> DualpinImportOutcome {
    let report = parser.validate(conflictingRawIDs: DualpinParser.builtinRawIDs)
    guard report.isUsable else {
      let issues = report.errors.map { DualpinImportIssue(code: $0.code.rawValue, detail: $0.detail) }
      return .failure(.invalid(issues))
    }
    let schema = schemaURLString ?? currentSchemaURLString
    guard let json = serialize(parser, schemaURLString: schema) else {
      return .failure(.malformed)
    }
    PrefMgr.shared.dualpinSchemaJSON = json
    PrefMgr.shared.keyboardParser4Dualpin = KeyboardParser.ofDualpinCustom.rawValue
    PrefMgr.shared.pinyinTypingEnabled = true
    PrefMgr.shared.dualpinEnabledForPinyinTyping = true
    PrefMgr.shared.reconcileAfterExternalPrefsImport()
    let tag = PrefMgr.shared.appleLanguages.first ?? "en"
    return .success(rawID: parser.rawID, title: parser.title(forLocaleTag: tag))
  }

  /// 自所選檔案匯入雙拼方案。
  ///
  /// 成功時以偏好設定之 setter 寫入（故 `@AppProperty` 之推式副作用照常觸發），
  /// 並將雙拼方案切至「自訂雙拼」、開啟雙拼模式——該方案唯有在此模式下才被使用。
  ///
  /// 三個偏好鍵於此明寫，不經 `keyboardParser` 之 setter：該 setter 之 getter 恆回拼音／
  /// 注音方案，已不再能表達「當前採用之雙拼方案」（雙拼方案自 Phase 302 起另立門戶，
  /// 見 `UserDef.kKeyboardParser4Dualpin`）。
  ///
  /// - Parameter url: 使用者於開啟面板／`fileImporter` 選定之檔案。
  /// - Returns: 匯入結果。
  public static func importSchema(from url: URL) -> DualpinImportOutcome {
    let needsScopeRelease = url.startAccessingSecurityScopedResource()
    defer {
      if needsScopeRelease { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: url) else { return .failure(.unreadable) }
    guard data.count <= maximumImportByteCount else { return .failure(.tooLarge) }
    guard let json = String(data: data, encoding: .utf8),
          let parser = try? JSONDecoder().decode(DualpinParser.self, from: data)
    else { return .failure(.malformed) }
    let report = parser.validate(conflictingRawIDs: DualpinParser.builtinRawIDs)
    guard report.isUsable else {
      let issues = report.errors.map { DualpinImportIssue(code: $0.code.rawValue, detail: $0.detail) }
      return .failure(.invalid(issues))
    }
    PrefMgr.shared.dualpinSchemaJSON = json
    PrefMgr.shared.keyboardParser4Dualpin = KeyboardParser.ofDualpinCustom.rawValue
    PrefMgr.shared.pinyinTypingEnabled = true
    PrefMgr.shared.dualpinEnabledForPinyinTyping = true
    PrefMgr.shared.reconcileAfterExternalPrefsImport()
    let tag = PrefMgr.shared.appleLanguages.first ?? "en"
    return .success(rawID: parser.rawID, title: parser.title(forLocaleTag: tag))
  }

  /// 匯入區之狀態文案。
  ///
  /// - Parameters:
  ///   - outcome: 最近一次匯入之結果。`nil` 時改依偏好設定現值推斷。
  ///   - schemaJSON: 偏好設定內現存之方案原文（呼叫者傳入自身可觀察之值，
  ///     使 SwiftUI 側得以隨偏好鍵之變更重繪）。
  /// - Returns: 供設定介面直接顯示之文案。
  public static func statusText(
    after outcome: DualpinImportOutcome?,
    schemaJSON: String
  )
    -> String {
    if let outcome {
      switch outcome {
      case let .success(_, title):
        return importedStatusText(title: title)
      case let .failure(failure):
        switch failure {
        case .unreadable:
          return "i18n:Settings.DualpinScheme.Status.Unreadable".i18n
        case .tooLarge:
          return "i18n:Settings.DualpinScheme.Status.TooLarge".i18n
        case .malformed:
          return "i18n:Settings.DualpinScheme.Status.Malformed".i18n
        case let .invalid(issues):
          let details = issues.map { "\($0.code) \($0.detail)" }.joined(separator: "\n")
          return String(
            format: "i18n:Settings.DualpinScheme.Status.Invalid:%@".i18n,
            arguments: [details]
          )
        }
      }
    }
    guard !schemaJSON.isEmpty else {
      return "i18n:Settings.DualpinScheme.Status.None".i18n
    }
    guard let title = currentTitle else {
      return "i18n:Settings.DualpinScheme.Status.Malformed".i18n
    }
    return importedStatusText(title: title)
  }

  // MARK: Private

  /// 已匯入之狀態文案。
  private static func importedStatusText(title: String) -> String {
    String(
      format: "i18n:Settings.DualpinScheme.Status.Imported:%@".i18n,
      arguments: [title]
    )
  }

  /// 將一組鍵值渲為 pretty 之單行（鍵在前、值在後）。
  private static func jsonLine(key: String, value: Any, indent: Int) -> String {
    String(repeating: "  ", count: indent) + jsonString(key) + ": " + jsonValue(value, indent: indent)
  }

  /// 將 `JSONSerialization` 取出之值渲為 pretty 之 JSON 片段。
  private static func jsonValue(_ value: Any, indent: Int) -> String {
    switch value {
    case let string as String:
      return jsonString(string)
    case let number as NSNumber:
      // `NSNumber` 亦承載布林值；`JSONSerialization` 不會產生本格式未用及之數值型別歧義。
      if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
      return number.stringValue
    case let array as [Any]:
      guard !array.isEmpty else { return "[]" }
      let pad = String(repeating: "  ", count: indent)
      let inner = array.map { pad + "  " + jsonValue($0, indent: indent + 1) }
      return "[\n" + inner.joined(separator: ",\n") + "\n" + pad + "]"
    case let dict as [String: Any]:
      guard !dict.isEmpty else { return "{}" }
      let pad = String(repeating: "  ", count: indent)
      let inner = dict.keys.sorted().compactMap { key -> String? in
        guard let value = dict[key] else { return nil }
        return pad + "  " + jsonString(key) + ": " + jsonValue(value, indent: indent + 1)
      }
      return "{\n" + inner.joined(separator: ",\n") + "\n" + pad + "}"
    default:
      return "null"
    }
  }

  /// 將字串渲為 JSON 字串字面（非 ASCII 一律照原樣輸出，與官網所發表者一致）。
  private static func jsonString(_ string: String) -> String {
    var result = "\""
    for scalar in string.unicodeScalars {
      switch scalar {
      case "\"": result += "\\\""
      case "\\": result += "\\\\"
      case "\n": result += "\\n"
      case "\r": result += "\\r"
      case "\t": result += "\\t"
      default:
        if scalar.value < 0x20 {
          result += String(format: "\\u%04x", scalar.value)
        } else {
          result.unicodeScalars.append(scalar)
        }
      }
    }
    return result + "\""
  }
}
