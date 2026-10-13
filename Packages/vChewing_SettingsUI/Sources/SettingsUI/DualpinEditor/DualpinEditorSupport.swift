// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為雙拼方案編輯器之共用素材：鍵位格之版面、政策列舉之對位、與引擎報告之轉述。
// 與 `DualpinSchemaDraft.swift` 同：只依賴 `Foundation` 與引擎，供兩版渲染器共用，
// 且 5.10 路徑亦可編譯。

import Arimitsu
import Foundation

// MARK: - DualpinEditorKeyboard

/// 編輯器鍵位格之版面（與微軟拼音之預覽格同形：26 字母＋`;`）。
public enum DualpinEditorKeyboard {
  public static let rows: [[Character]] = [
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"],
    ["z", "x", "c", "v", "b", "n", "m"],
  ]

  public static let allKeys: [Character] = rows.flatMap { $0 }
}

// MARK: - DualpinNullOnsetMode

/// 零聲母政策之「界面可編輯」形。引擎之 `.fixedKey(_:)` 另帶一鍵值，故不對位。
public enum DualpinNullOnsetMode: String, CaseIterable, Sendable {
  case fixedKey
  case finalInitial
  case finalInitialOrVerbatimDigraph

  // MARK: Lifecycle

  /// 自引擎之政策對位。`.fixedKey(_:)` 一律視作 `.fixedKey`。
  public init(_ policy: DualpinParser.NullOnsetPolicy) {
    switch policy {
    case .fixedKey: self = .fixedKey
    case .finalInitial: self = .finalInitial
    case .finalInitialOrVerbatimDigraph: self = .finalInitialOrVerbatimDigraph
    }
  }

  // MARK: Public

  public func policy(fixedKey: Character) -> DualpinParser.NullOnsetPolicy {
    switch self {
    case .fixedKey: return .fixedKey(fixedKey)
    case .finalInitial: return .finalInitial
    case .finalInitialOrVerbatimDigraph: return .finalInitialOrVerbatimDigraph
    }
  }
}

extension DualpinParser.NullOnsetPolicy {
  /// 本政策若為 `.fixedKey(_:)`，其固定鍵；否則為 `nil`。
  public var fixedKeyCharacter: Character? {
    guard case let .fixedKey(key) = self else { return nil }
    return key
  }
}

// MARK: - DualpinEditorKeyAnnotation

/// 鍵位格內單一按鍵之標註：內容一律由引擎之報告推得，界面不自算。
public struct DualpinEditorKeyAnnotation: Equatable, Sendable {
  // MARK: Lifecycle

  public init(
    key: Character,
    initialSyllables: [String],
    finalSyllables: [String],
    isUsedByAnyCode: Bool,
    isUnusedTableKey: Bool,
    isReservedInUse: Bool
  ) {
    self.key = key
    self.initialSyllables = initialSyllables
    self.finalSyllables = finalSyllables
    self.isUsedByAnyCode = isUsedByAnyCode
    self.isUnusedTableKey = isUnusedTableKey
    self.isReservedInUse = isReservedInUse
  }

  // MARK: Public

  public let key: Character
  /// 用到本鍵之聲母音節。
  public let initialSyllables: [String]
  /// 用到本鍵之尾綴音節。
  public let finalSyllables: [String]
  /// 本鍵是否為某些碼所用到（`DualpinValidationReport.Stats.usedKeys`）。
  public let isUsedByAnyCode: Bool
  /// 兩表給了本鍵、卻無任何碼用及（即引擎之 `W5`）。
  public let isUnusedTableKey: Bool
  /// 有碼用及主機保留鍵（即引擎之 `W3`）。
  public let isReservedInUse: Bool
}

extension DualpinSchemaDraft {
  /// 依引擎報告推得鍵位格之各鍵標註。
  public func keyAnnotations(
    report: DualpinValidationReport
  )
    -> [DualpinEditorKeyAnnotation] {
    DualpinEditorKeyboard.allKeys.map { key in
      let usedByAnyCode = report.stats.usedKeys.contains(key)
      let initialsHere = syllables(atKey: key, in: .initials)
      let finalsHere = syllables(atKey: key, in: .finals)
      let inTable = !(initialsHere.isEmpty && finalsHere.isEmpty)
      return DualpinEditorKeyAnnotation(
        key: key,
        initialSyllables: initialsHere,
        finalSyllables: finalsHere,
        isUsedByAnyCode: usedByAnyCode,
        isUnusedTableKey: inTable && !usedByAnyCode,
        isReservedInUse: usedByAnyCode && DualpinParser.hostReservedKeys.contains(key)
      )
    }
  }
}

// MARK: - DualpinEditorText

/// 編輯器之文案（與 `Localizable.strings` 之鍵名對位）。
public enum DualpinEditorText {
  // MARK: Public

  // MARK: 區塊與動作

  public static var sectionTitle: String { "i18n:Settings.DualpinEditor.SectionTitle".i18n }
  public static var save: String { "i18n:Settings.DualpinEditor.Action.Save".i18n }
  public static var revert: String { "i18n:Settings.DualpinEditor.Action.Revert".i18n }
  public static var export: String { "i18n:Settings.DualpinEditor.Action.Export".i18n }
  public static var importSchema: String { "i18n:Settings.DualpinEditor.Action.Import".i18n }
  public static var saveAsBuiltinCopy: String {
    "i18n:Settings.DualpinEditor.Action.SaveAsBuiltinCopy".i18n
  }

  // MARK: 身分

  public static var name: String { "i18n:Settings.DualpinEditor.Name".i18n }
  public static var namePlaceholder: String { "i18n:Settings.DualpinEditor.NamePlaceholder".i18n }
  public static var rawID: String { "i18n:Settings.DualpinEditor.RawID".i18n }
  public static var rawIDHelp: String { "i18n:Settings.DualpinEditor.RawIDHelp".i18n }

  // MARK: 範本

  public static var template: String { "i18n:Settings.DualpinEditor.Template".i18n }
  public static var templateNone: String { "i18n:Settings.DualpinEditor.Template.None".i18n }
  public static var templateBuiltin: String { "i18n:Settings.DualpinEditor.Template.Builtin".i18n }
  public static var templateCurrent: String { "i18n:Settings.DualpinEditor.Template.Current".i18n }

  // MARK: 零聲母

  public static var nullOnsetMode: String { "i18n:Settings.DualpinEditor.NullOnset.Mode".i18n }
  public static var nullOnsetKey: String { "i18n:Settings.DualpinEditor.NullOnset.Key".i18n }

  // MARK: 按鍵自訂

  public static var assignmentSyllable: String {
    "i18n:Settings.DualpinEditor.Assignment.Syllable".i18n
  }

  public static var assignmentKey: String { "i18n:Settings.DualpinEditor.Assignment.Key".i18n }

  // MARK: 鍵位格

  public static var keyboardPreview: String { "i18n:Settings.DualpinEditor.Keyboard.Preview".i18n }
  public static var keyboardUnusedKey: String { "i18n:Settings.DualpinEditor.Keyboard.UnusedKey".i18n }
  public static var keyboardReservedKey: String {
    "i18n:Settings.DualpinEditor.Keyboard.ReservedKey".i18n
  }

  // MARK: 校驗

  public static var validationOK: String { "i18n:Settings.DualpinEditor.Validation.OK".i18n }
  public static var validationAdvanced: String { "i18n:Settings.DualpinEditor.Validation.Advanced".i18n }
  public static var validationDetails: String { "i18n:Settings.DualpinEditor.Validation.Details".i18n }
  public static var validationDIPENote: String { "i18n:Settings.DualpinEditor.Validation.DIPENote".i18n }

  /// 範本之顯示名。
  public static func templateName(_ template: DualpinSchemaTemplate) -> String {
    switch template {
    case .blank: return templateNone
    case .microsoft: return DualpinParser.mspy.title(forLocaleTag: currentLocaleTag)
    case .gbt17: return DualpinParser.gbt17.title(forLocaleTag: currentLocaleTag)
    case .current: return templateCurrent
    }
  }

  /// 兩表之顯示名。
  public static func tableName(_ table: DualpinEditorTable) -> String {
    switch table {
    case .initials: return "i18n:Settings.DualpinEditor.Assignment.Initials".i18n
    case .finals: return "i18n:Settings.DualpinEditor.Assignment.Finals".i18n
    }
  }

  /// 零聲母模式之顯示名。
  public static func nullOnsetModeName(_ mode: DualpinNullOnsetMode) -> String {
    switch mode {
    case .fixedKey: return "i18n:Settings.DualpinEditor.NullOnset.FixedKey".i18n
    case .finalInitial: return "i18n:Settings.DualpinEditor.NullOnset.FinalInitial".i18n
    case .finalInitialOrVerbatimDigraph:
      return "i18n:Settings.DualpinEditor.NullOnset.FinalInitialOrVerbatimDigraph".i18n
    }
  }

  /// 校驗項目之單行（`碼 說明`）。
  public static func issueLine(_ issue: DualpinValidationReport.Issue) -> String {
    "\(issue.code.rawValue) \(issue.detail)"
  }

  /// 按鍵之顯示名（`;` 之外一律以原字元示人）。
  public static func keyLabel(_ key: Character) -> String {
    String(key)
  }

  /// 校驗之摘要行：可用與否、或錯誤數。
  public static func validationSummary(_ report: DualpinValidationReport) -> String {
    guard !report.isUsable else { return validationOK }
    return String(
      format: "i18n:Settings.DualpinEditor.Validation.Errors:%d".i18n,
      arguments: [report.errors.count]
    )
  }

  /// 得碼數之摘要行（`eh` 屬 DIPE，故七份已發表者一律 425／426）。
  public static func codableSummary(_ report: DualpinValidationReport) -> String {
    String(
      format: "i18n:Settings.DualpinEditor.Validation.Summary:%@".i18n,
      arguments: ["\(report.stats.codableCount)／\(report.stats.inventoryCount)"]
    )
  }

  /// 儲存／匯出之結果文案。
  public static func statusText(_ outcome: DualpinImportOutcome) -> String {
    switch outcome {
    case let .success(_, title):
      return String(
        format: "i18n:Settings.DualpinEditor.Status.Saved:%@".i18n,
        arguments: [title]
      )
    case let .failure(failure):
      let reason = DualpinSchemaStore.statusText(after: .failure(failure), schemaJSON: "")
      return String(
        format: "i18n:Settings.DualpinEditor.Status.SaveFailed:%@".i18n,
        arguments: [reason]
      )
    }
  }

  /// 匯出成功之文案。
  public static func exportSucceededText(destination: String) -> String {
    String(
      format: "i18n:Settings.DualpinEditor.Status.Exported:%@".i18n,
      arguments: [destination]
    )
  }

  /// 匯出時改走路徑傾印之文案。
  public static func exportDumpedText(destination: String) -> String {
    String(
      format: "i18n:Settings.DualpinEditor.Status.ExportDumped:%@".i18n,
      arguments: [destination]
    )
  }

  /// 匯出失敗之文案。
  public static func exportFailedText(reason: String) -> String {
    String(
      format: "i18n:Settings.DualpinEditor.Status.ExportFailed:%@".i18n,
      arguments: [reason]
    )
  }

  /// 匯出時之建議檔名。
  public static func suggestedFileName(rawTitle: String) -> String {
    let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed.isEmpty ? "DualpinSchema" : trimmed) + ".dualpin.json"
  }

  // MARK: Private

  /// 當前語系標籤（供內建方案之標題解析）。
  private static var currentLocaleTag: String {
    PrefMgr.shared.appleLanguages.first ?? "en"
  }
}
