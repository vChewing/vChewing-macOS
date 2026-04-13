// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - UserDef

nonisolated public enum UserDef: String, CaseIterable, Identifiable, Sendable {
  // MARK: - Cases.

  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForPOMObservation = "_FailureFlag_POMObservation"
  case kUserPhrasesDatabaseBypassed = "UserPhrasesDatabaseBypassed"
  case kReplaceSymbolMenuNodeWithUserSuppliedData = "ReplaceSymbolMenuNodeWithUserSuppliedData"
  case kCandidateServiceMenuContents = "CandidateServiceMenuContents"
  case kRespectClientAccentColor = "RespectClientAccentColor"
  case kAlwaysUsePCBWithElectronBasedClients = "AlwaysUsePCBWithElectronBasedClients"
  case kSecurityHardenedCompositionBuffer = "SecurityHardenedCompositionBuffer"
  case kCheckAbusersOfSecureEventInputAPI = "CheckAbusersOfSecureEventInputAPI"
  case kDeltaOfCalendarYears = "DeltaOfCalendarYears"
  case kMostRecentInputMode = "MostRecentInputMode"
  case kCassettePath = "CassettePath"
  case kUserDataFolderSpecified = "UserDataFolderSpecified"
  case kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  case kUseExternalFactoryDict = "UseExternalFactoryDict"
  case kKeyboardParser = "KeyboardParser"
  case kBasicKeyboardLayout = "BasicKeyboardLayout"
  case kAlphanumericalKeyboardLayout = "AlphanumericalKeyboardLayout"
  case kShowNotificationsWhenTogglingCapsLock = "ShowNotificationsWhenTogglingCapsLock"
  case kShowNotificationsWhenTogglingEisu = "ShowNotificationsWhenTogglingEisu"
  case kShowNotificationsWhenTogglingShift = "ShowNotificationsWhenTogglingShift"
  case kSpecifiedNotifyUIColorScheme = "OverrideNotifyUIColorScheme"
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAlwaysExpandCandidateWindow = "AlwaysExpandCandidateWindow"
  case kCandidateWindowShowOnlyOneLine = "CandidateWindowShowOnlyOneLine"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "UseRearCursorMode"
  case kCandidateStateJKHLBehavior = "CandidateStateJKHLBehavior"
  case kUseShiftQuestionToCallServiceMenu = "UseShiftQuestionToCallServiceMenu"
  case kUseDynamicCandidateWindowOrigin = "UseDynamicCandidateWindowOrigin"
  case kUseHorizontalCandidateList = "UseHorizontalCandidateList"
  case kMinCellWidthForHorizontalMatrix = "MinCellWidthForHorizontalMatrix"
  case kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
  case kCassetteEnabled = "CassetteEnabled"
  case kCNS11643Enabled = "CNS11643Enabled"
  case kSymbolInputEnabled = "SymbolInputEnabled"
  case kChineseConversionEnabled = "ChineseConversionEnabled"
  case kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
  case kCurrencyNumeralsEnabled = "CurrencyNumeralsEnabled"
  case kHalfWidthPunctuationEnabled = "HalfWidthPunctuationEnable"
  case kCursorPlacementAfterSelectingCandidate = "CursorBehaviorAfterConfirmingCandidate"
  case kDodgeInvalidEdgeCandidateCursorPosition = "DodgeInvalidEdgeCandidateCursorPosition"
  case kEscToCleanInputBuffer = "EscToCleanInputBuffer"
  case kAcceptLeadingIntonations = "AcceptLeadingIntonations"
  case kSpecifyIntonationKeyBehavior = "SpecifyIntonationKeyBehavior"
  case kSpecifyShiftBackSpaceKeyBehavior = "SpecifyShiftBackSpaceKeyBehavior"
  case kSpecifyShiftTabKeyBehavior = "SpecifyShiftTabKeyBehavior"
  case kSpecifyShiftSpaceKeyBehavior = "SpecifyShiftSpaceKeyBehavior"
  case kSpecifyCmdOptCtrlEnterBehavior = "SpecifyCmdOptCtrlEnterBehavior"
  case kReflectBPMFVSInCompositionBuffer = "ReflectBPMFVSInCompositionBuffer"
  case kAllowRescoringSingleKanjiCandidates = "AllowRescoringSingleKanjiCandidates"
  case kUseSCPCTypingMode = "UseSCPCTypingMode"
  case kMaxCandidateLength = "MaxCandidateLength"
  case kBeepSoundPreference = "BeepSoundPreference"
  case kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"
  case kShowHanyuPinyinInCompositionBuffer = "ShowHanyuPinyinInCompositionBuffer"
  case kInlineDumpPinyinInLieuOfZhuyin = "InlineDumpPinyinInLieuOfZhuyin"
  case kFetchSuggestionsFromPerceptionOverrideModel = "FetchSuggestionsFromPerceptionOverrideModel"
  case kUseFixedCandidateOrderOnSelection = "UseFixedCandidateOrderOnSelection"
  case kAutoCorrectReadingCombination = "AutoCorrectReadingCombination"
  case kReadingNarrationCoverage = "ReadingNarrationCoverage"
  case kAlsoConfirmAssociatedCandidatesByEnter = "AlsoConfirmAssociatedCandidatesByEnter"
  case kKeepReadingUponCompositionError = "KeepReadingUponCompositionError"
  case kBypassNonAppleCapsLockHandling = "BypassNonAppleCapsLockHandling"
  case kShiftEisuToggleOffTogetherWithCapsLock = "ShiftEisuToggleOffTogetherWithCapsLock"
  case kTogglingAlphanumericalModeWithLShift = "TogglingAlphanumericalModeWithLShift"
  case kTogglingAlphanumericalModeWithRShift = "TogglingAlphanumericalModeWithRShift"
  case kUpperCaseLetterKeyBehavior = "UpperCaseLetterKeyBehavior"
  case kNumPadCharInputBehavior = "NumPadCharInputBehavior"
  case kConsolidateContextOnCandidateSelection = "ConsolidateContextOnCandidateSelection"
  case kHardenVerticalPunctuations = "HardenVerticalPunctuations"
  case kTrimUnfinishedReadingsOnCommit = "TrimUnfinishedReadingsOnCommit"
  case kAlwaysShowTooltipTextsHorizontally = "AlwaysShowTooltipTextsHorizontally"
  case kClientsIMKTextInputIncapable = "ClientsIMKTextInputIncapable"
  case kShowTranslatedStrokesInCompositionBuffer = "ShowTranslatedStrokesInCompositionBuffer"
  case kForceCassetteChineseConversion = "ForceCassetteChineseConversion"
  case kShowReverseLookupInCandidateUI = "ShowReverseLookupInCandidateUI"
  case kShowCodePointInCandidateUI = "ShowCodePointInCandidateUI"
  case kAutoCompositeWithLongestPossibleCassetteKey = "AutoCompositeWithLongestPossibleCassetteKey"
  case kShareAlphanumericalModeStatusAcrossClients = "ShareAlphanumericalModeStatusAcrossClients"
  case kPhraseEditorAutoReloadExternalModifications = "PhraseEditorAutoReloadExternalModifications"
  case kClassicHaninKeyboardSymbolModeShortcutEnabled =
    "ClassicHaninKeyboardSymbolModeShortcutEnabled"
  case kFilterNonCNSReadingsForCHTInput = "FilterNonCNSReadingsForCHTInput"
  case kEnforceETenDOSCandidateSequence = "enforceETenDOSCandidateSequence"
  case kRomanNumeralOutputFormat = "RomanNumeralOutputFormat"
  case kReducePOMLifetimeToNoMoreThan12Hours = "ReducePOMLifetimeToNoMoreThan12Hours"

  case kUseSpaceToCommitHighlightedSCPCCandidate = "UseSpaceToCommitHighlightedSCPCCandidate"
  case kEnableMouseScrollingForTDKCandidatesCocoa = "EnableMouseScrollingForTDKCandidatesCocoa"
  case kEnableCandidateWindowAnimation = "EnableCandidateWindowAnimation"
  case kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
    = "DisableSegmentedThickUnderlineInMarkingModeForManagedClients"

  case kCandidateTextFontName = "CandidateTextFontName"
  case kCandidateKeys = "CandidateKeys"
  case kCandidateNarrationToggleType = "CandidateNarrationToggleType"

  case kAssociatedPhrasesEnabled = "AssociatedPhrasesEnabled"
  case kPhraseReplacementEnabled = "PhraseReplacementEnabled"

  case kUsingHotKeySCPC = "UsingHotKeySCPC"
  case kUsingHotKeyAssociates = "UsingHotKeyAssociates"
  case kUsingHotKeyCNS = "UsingHotKeyCNS"
  case kUsingHotKeyKangXi = "UsingHotKeyKangXi"
  case kUsingHotKeyJIS = "UsingHotKeyJIS"
  case kUsingHotKeyHalfWidthASCII = "UsingHotKeyHalfWidthASCII"
  case kUsingHotKeyCurrencyNumerals = "UsingHotKeyCurrencyNumerals"
  case kUsingHotKeyCassette = "UsingHotKeyCassette"
  case kUsingHotKeyRevLookup = "UsingHotKeyRevLookup"
  case kUsingHotKeyInputMode = "UsingHotKeyInputMode"

  // MARK: Public

  // MARK: - DataType：以關聯值嵌入預設值的資料型別列舉。

  /// 嵌入式資料型別列舉：每個 case 的關聯值即為該偏好設定的預設值。
  /// 這使得 `UserDef.dataType` 成為預設值的唯一事實來源（Single Source of Truth）。
  public enum DataType {
    case string(String)
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case arrayOfStrings([String])
    case dictionary([String: Bool])

    // MARK: Public

    /// 從 DataType 關聯值取出預設值（以 `Any` 型別回傳）。
    public var defaultValue: Any {
      switch self {
      case let .bool(v): return v
      case let .integer(v): return v
      case let .double(v): return v
      case let .string(v): return v
      case let .arrayOfStrings(v): return v
      case let .dictionary(v): return v
      }
    }

    /// 供 `defaults write` 指令匯出時使用的型別參數名稱。
    public var defaultsCommandTypeName: String {
      switch self {
      case .string: return "string"
      case .bool: return "bool"
      case .integer: return "integer"
      case .double: return "float"
      case .arrayOfStrings: return "array"
      case .dictionary: return "dict"
      }
    }
  }

  public struct MetaData {
    public var userDef: UserDef
    public var shortTitle: String?
    public var prompt: String?
    public var inlinePrompt: String?
    public var popupPrompt: String?
    public var description: String?
    public var minimumOS: Double = 10.9
    public var options: [Int: String]?
    public var toolTip: String?
  }

  public struct Snapshot {
    // MARK: Lifecycle

    public init() {
      UserDef.allCases.forEach {
        data[$0.rawValue] = UserDefaults.current.object(forKey: $0.rawValue)
      }
    }

    // MARK: Public

    public var data: [String: Any] = [:]
  }

  /// 匯入結果：紀錄成功與失敗的項目。
  public struct ImportResult {
    public var successes: [String] = []
    public var failures: [(key: String, reason: String)] = []
  }

  // MARK: - JSON Export / Import

  /// 不應匯出 / 匯入的 UserDef 黑名單。
  /// 包括：Sandbox 相關路徑、介面語言設定、暫態旗標等。
  public static let jsonExchangeBlacklist: Set<UserDef> = [
    .kUserDataFolderSpecified,
    .kCassettePath,
    .kAppleLanguages,
    .kFailureFlagForPOMObservation,
    .kMostRecentInputMode,
    .kCandidateServiceMenuContents,
  ]

  public var id: String { rawValue }

  // MARK: - SnapShot-Related Methods.

  public static func resetAll() {
    Self.allCases.forEach {
      UserDefaults.current.removeObject(forKey: $0.rawValue)
    }
  }

  public static func load(from snapshot: Snapshot) {
    let data = snapshot.data
    guard !data.isEmpty else { return }
    Self.allCases.forEach {
      UserDefaults.current.set(data[$0.rawValue], forKey: $0.rawValue)
    }
  }

  /// 將所有可匯出的 UserDefaults 偏好設定匯出為 JSON Data。
  public static func exportAsJSON() -> Data? {
    var dict = [String: Any]()
    for userDef in Self.allCases {
      guard !jsonExchangeBlacklist.contains(userDef) else { continue }
      guard let value = UserDefaults.current.object(forKey: userDef.rawValue) else { continue }
      dict[userDef.rawValue] = value
    }
    guard JSONSerialization.isValidJSONObject(dict) else { return nil }
    return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
  }

  /// 從 JSON Data 匯入 UserDefaults 偏好設定，回傳匯入結果。
  public static func importFromJSON(_ data: Data) -> ImportResult {
    var result = ImportResult()
    guard let jsonObj = try? JSONSerialization.jsonObject(with: data),
          let dict = jsonObj as? [String: Any]
    else {
      result.failures.append((key: "(root)", reason: "Invalid JSON format"))
      return result
    }
    for (key, value) in dict {
      guard let userDef = Self(rawValue: key) else {
        result.failures.append((key: key, reason: "Unknown key"))
        continue
      }
      guard !jsonExchangeBlacklist.contains(userDef) else {
        result.failures.append((key: key, reason: "Blacklisted key"))
        continue
      }
      if let failReason = validateAndApply(userDef: userDef, value: value) {
        result.failures.append((key: key, reason: failReason))
      } else {
        result.successes.append(key)
      }
    }
    return result
  }

  // MARK: Private

  /// 驗證單一偏好值是否合理，合理則寫入 UserDefaults。
  /// - Returns: 若驗證失敗則回傳失敗原因；成功則回傳 nil。
  private static func validateAndApply(userDef: Self, value: Any) -> String? {
    switch userDef.dataType {
    case .bool:
      // JSON 數字 0/1 也可視為 Bool。
      if let v = value as? Bool {
        UserDefaults.current.set(v, forKey: userDef.rawValue)
        return nil
      } else if let v = value as? Int, (0 ... 1).contains(v) {
        UserDefaults.current.set(v == 1, forKey: userDef.rawValue)
        return nil
      }
      return "Expected Bool"

    case .integer:
      guard let v = value as? Int else {
        // 嘗試從 Double 取整數（JSON 數字皆為 Double）。
        if let d = value as? Double, d == d.rounded() {
          let intVal = Int(d)
          if let reason = validateIntRange(userDef: userDef, value: intVal) { return reason }
          UserDefaults.current.set(intVal, forKey: userDef.rawValue)
          return nil
        }
        return "Expected Int"
      }
      if let reason = validateIntRange(userDef: userDef, value: v) { return reason }
      UserDefaults.current.set(v, forKey: userDef.rawValue)
      return nil

    case .double:
      guard let v = value as? Double ?? (value as? Int).map(Double.init) else {
        return "Expected Double"
      }
      if let reason = validateDoubleRange(userDef: userDef, value: v) { return reason }
      UserDefaults.current.set(v, forKey: userDef.rawValue)
      return nil

    case .string:
      guard let v = value as? String else { return "Expected String" }
      if let reason = validateString(userDef: userDef, value: v) { return reason }
      UserDefaults.current.set(v, forKey: userDef.rawValue)
      return nil

    case .arrayOfStrings:
      guard let v = value as? [String] else {
        // 也接受 [Any]，但需要每個元素都是 String。
        if let arr = value as? [Any] {
          let strings = arr.compactMap { $0 as? String }
          guard strings.count == arr.count else { return "Expected Array of Strings" }
          UserDefaults.current.set(strings, forKey: userDef.rawValue)
          return nil
        }
        return "Expected Array of Strings"
      }
      UserDefaults.current.set(v, forKey: userDef.rawValue)
      return nil

    case .dictionary:
      guard let v = value as? [String: Bool] else {
        // JSON 解析後可能是 [String: Any]，需要檢查值是否為 Bool。
        if let rawDict = value as? [String: Any] {
          var converted = [String: Bool]()
          for (k, val) in rawDict {
            if let b = val as? Bool { converted[k] = b } else if let i = val as? Int,
                                                                 (0 ... 1).contains(i) { converted[k] = i == 1 }
            else { return "Expected Dictionary<String, Bool>" }
          }
          UserDefaults.current.set(converted, forKey: userDef.rawValue)
          return nil
        }
        return "Expected Dictionary<String, Bool>"
      }
      UserDefaults.current.set(v, forKey: userDef.rawValue)
      return nil
    }
  }

  // MARK: - 各型別的範圍驗證，對應 PrefMgr.fixOddPreferencesCore() 的邏輯。

  private static func validateIntRange(userDef: Self, value: Int) -> String? {
    switch userDef {
    case .kKeyboardParser:
      // KeyboardParser(rawValue:) 如果 nil 則不合理。
      if value < 0 || value > 100 { return "Out of range for KeyboardParser" }
    case .kSpecifyIntonationKeyBehavior:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kSpecifyShiftBackSpaceKeyBehavior:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kUpperCaseLetterKeyBehavior:
      if ![0, 1, 2, 3, 4].contains(value) { return "Must be 0..4" }
    case .kReadingNarrationCoverage:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kRomanNumeralOutputFormat:
      if ![0, 1, 2, 3].contains(value) { return "Must be 0..3" }
    case .kSpecifyCmdOptCtrlEnterBehavior:
      if ![0, 1, 2, 3, 4].contains(value) { return "Must be 0..4" }
    case .kBeepSoundPreference:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kCursorPlacementAfterSelectingCandidate:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kCandidateNarrationToggleType:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kCandidateStateJKHLBehavior:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kSpecifiedNotifyUIColorScheme:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kForceCassetteChineseConversion:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    case .kNumPadCharInputBehavior:
      if ![0, 1, 2].contains(value) { return "Must be 0, 1, or 2" }
    default: break
    }
    return nil
  }

  private static func validateDoubleRange(userDef: Self, value: Double) -> String? {
    switch userDef {
    case .kCandidateListTextSize:
      if !(12 ... 196).contains(value) { return "Must be 12..196" }
    default: break
    }
    return nil
  }

  private static func validateString(userDef: Self, value: String) -> String? {
    switch userDef {
    case .kCandidateKeys:
      let optimized = value.lowercased()
      if optimized.isEmpty { return "Candidate keys cannot be empty" }
    default: break
    }
    return nil
  }
}

nonisolated extension UserDef {
  // MARK: - dataType：以 DataType 關聯值嵌入預設值。

  /// 回傳此偏好鍵對應的 DataType，其關聯值即為該偏好的預設值。
  public var dataType: DataType {
    switch self {
    case .kIsDebugModeEnabled: return .bool(false)
    case .kFailureFlagForPOMObservation: return .bool(false)
    case .kUserPhrasesDatabaseBypassed: return .bool(false)
    case .kReplaceSymbolMenuNodeWithUserSuppliedData: return .bool(true)
    case .kCandidateServiceMenuContents: return .arrayOfStrings(Self.defaultValue4CandidateServiceMenuContents)
    case .kRespectClientAccentColor: return .bool(true)
    case .kAlwaysUsePCBWithElectronBasedClients: return .bool(true)
    case .kSecurityHardenedCompositionBuffer: return .bool(false)
    case .kCheckAbusersOfSecureEventInputAPI: return .bool(true)
    case .kDeltaOfCalendarYears: return .integer(-2_000)
    case .kMostRecentInputMode: return .string("")
    case .kCassettePath: return .string("")
    case .kUserDataFolderSpecified: return .string("")
    case .kCheckUpdateAutomatically: return .bool(false)
    case .kUseExternalFactoryDict: return .bool(false)
    case .kKeyboardParser: return .integer(0)
    case .kBasicKeyboardLayout: return .string(Self.kDefaultBasicKeyboardLayout)
    case .kAlphanumericalKeyboardLayout: return .string(Self.kDefaultAlphanumericalKeyboardLayout)
    case .kShowNotificationsWhenTogglingCapsLock: return .bool(true)
    case .kShowNotificationsWhenTogglingEisu: return .bool(true)
    case .kShowNotificationsWhenTogglingShift: return .bool(true)
    case .kSpecifiedNotifyUIColorScheme: return .integer(0)
    case .kCandidateListTextSize: return .double(16)
    case .kAlwaysExpandCandidateWindow: return .bool(false)
    case .kCandidateWindowShowOnlyOneLine: return .bool(false)
    case .kAppleLanguages: return .arrayOfStrings([])
    case .kShouldAutoReloadUserDataFiles: return .bool(true)
    case .kUseRearCursorMode: return .bool(false)
    case .kCandidateStateJKHLBehavior: return .integer(0)
    case .kUseShiftQuestionToCallServiceMenu: return .bool(true)
    case .kUseDynamicCandidateWindowOrigin: return .bool(true)
    case .kUseHorizontalCandidateList: return .bool(true)
    case .kMinCellWidthForHorizontalMatrix: return .integer(0)
    case .kChooseCandidateUsingSpace: return .bool(true)
    case .kCassetteEnabled: return .bool(false)
    case .kCNS11643Enabled: return .bool(false)
    case .kSymbolInputEnabled: return .bool(true)
    case .kChineseConversionEnabled: return .bool(false)
    case .kShiftJISShinjitaiOutputEnabled: return .bool(false)
    case .kCurrencyNumeralsEnabled: return .bool(false)
    case .kHalfWidthPunctuationEnabled: return .bool(false)
    case .kCursorPlacementAfterSelectingCandidate: return .integer(1)
    case .kDodgeInvalidEdgeCandidateCursorPosition: return .bool(true)
    case .kEscToCleanInputBuffer: return .bool(true)
    case .kAcceptLeadingIntonations: return .bool(true)
    case .kSpecifyIntonationKeyBehavior: return .integer(0)
    case .kSpecifyShiftBackSpaceKeyBehavior: return .integer(0)
    case .kSpecifyShiftTabKeyBehavior: return .bool(false)
    case .kSpecifyShiftSpaceKeyBehavior: return .bool(false)
    case .kSpecifyCmdOptCtrlEnterBehavior: return .integer(0)
    case .kReflectBPMFVSInCompositionBuffer: return .bool(true)
    case .kAllowRescoringSingleKanjiCandidates: return .bool(false)
    case .kUseSCPCTypingMode: return .bool(false)
    case .kMaxCandidateLength: return .integer(10)
    case .kBeepSoundPreference: return .integer(2)
    case .kShouldNotFartInLieuOfBeep: return .bool(true)
    case .kShowHanyuPinyinInCompositionBuffer: return .bool(false)
    case .kInlineDumpPinyinInLieuOfZhuyin: return .bool(false)
    case .kFetchSuggestionsFromPerceptionOverrideModel: return .bool(true)
    case .kUseFixedCandidateOrderOnSelection: return .bool(false)
    case .kAutoCorrectReadingCombination: return .bool(true)
    case .kReadingNarrationCoverage: return .integer(0)
    case .kAlsoConfirmAssociatedCandidatesByEnter: return .bool(false)
    case .kKeepReadingUponCompositionError: return .bool(false)
    case .kBypassNonAppleCapsLockHandling: return .bool(false)
    case .kShiftEisuToggleOffTogetherWithCapsLock: return .bool(true)
    case .kTogglingAlphanumericalModeWithLShift: return .bool(true)
    case .kTogglingAlphanumericalModeWithRShift: return .bool(true)
    case .kUpperCaseLetterKeyBehavior: return .integer(0)
    case .kNumPadCharInputBehavior: return .integer(0)
    case .kConsolidateContextOnCandidateSelection: return .bool(true)
    case .kHardenVerticalPunctuations: return .bool(false)
    case .kTrimUnfinishedReadingsOnCommit: return .bool(true)
    case .kAlwaysShowTooltipTextsHorizontally: return .bool(false)
    case .kClientsIMKTextInputIncapable: return .dictionary(Self.defaultValue4ClientsIMKTextInputIncapable)
    case .kShowTranslatedStrokesInCompositionBuffer: return .bool(true)
    case .kForceCassetteChineseConversion: return .integer(0)
    case .kShowReverseLookupInCandidateUI: return .bool(true)
    case .kShowCodePointInCandidateUI: return .bool(true)
    case .kAutoCompositeWithLongestPossibleCassetteKey: return .bool(true)
    case .kShareAlphanumericalModeStatusAcrossClients: return .bool(false)
    case .kPhraseEditorAutoReloadExternalModifications: return .bool(true)
    case .kClassicHaninKeyboardSymbolModeShortcutEnabled: return .bool(false)
    case .kFilterNonCNSReadingsForCHTInput: return .bool(false)
    case .kEnforceETenDOSCandidateSequence: return .bool(true)
    case .kRomanNumeralOutputFormat: return .integer(0)
    case .kReducePOMLifetimeToNoMoreThan12Hours: return .bool(false)
    case .kUseSpaceToCommitHighlightedSCPCCandidate: return .bool(true)
    case .kEnableMouseScrollingForTDKCandidatesCocoa: return .bool(false)
    case .kEnableCandidateWindowAnimation: return .bool(true)
    case .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients: return .bool(false)
    case .kCandidateTextFontName: return .string("")
    case .kCandidateKeys: return .string(Self.kDefaultCandidateKeys)
    case .kCandidateNarrationToggleType: return .integer(0)
    case .kAssociatedPhrasesEnabled: return .bool(false)
    case .kPhraseReplacementEnabled: return .bool(false)
    case .kUsingHotKeySCPC: return .bool(true)
    case .kUsingHotKeyAssociates: return .bool(true)
    case .kUsingHotKeyCNS: return .bool(true)
    case .kUsingHotKeyKangXi: return .bool(true)
    case .kUsingHotKeyJIS: return .bool(true)
    case .kUsingHotKeyHalfWidthASCII: return .bool(true)
    case .kUsingHotKeyCurrencyNumerals: return .bool(true)
    case .kUsingHotKeyCassette: return .bool(true)
    case .kUsingHotKeyRevLookup: return .bool(true)
    case .kUsingHotKeyInputMode: return .bool(true)
    }
  }
}

nonisolated extension UserDef {
  public var metaData: MetaData? {
    switch self {
    case .kIsDebugModeEnabled: return .init(userDef: self, shortTitle: "Debug Mode")
    case .kFailureFlagForPOMObservation: return nil
    case .kEnableCandidateWindowAnimation: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kEnableCandidateWindowAnimation.shortTitle"
      )
    case .kUserPhrasesDatabaseBypassed: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUserPhrasesDatabaseBypassed.shortTitle",
        description: "i18n:UserDef.kUserPhrasesDatabaseBypassed.description"
      )
    case .kReplaceSymbolMenuNodeWithUserSuppliedData: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kReplaceSymbolMenuNodeWithUserSuppliedData.shortTitle",
        description: "i18n:UserDef.kReplaceSymbolMenuNodeWithUserSuppliedData.description"
      )
    case .kCandidateServiceMenuContents: return nil
    case .kRespectClientAccentColor: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kRespectClientAccentColor.shortTitle",
        description: "i18n:UserDef.kRespectClientAccentColor.description"
      )
    case .kAlwaysUsePCBWithElectronBasedClients: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kAlwaysUsePCBWithElectronBasedClients.shortTitle",
        description: "i18n:UserDef.kAlwaysUsePCBWithElectronBasedClients.description"
      )
    case .kSecurityHardenedCompositionBuffer: return .init(
        userDef: self, shortTitle: "Security-harden the composition buffer for all clients",
        description: "This hinders all client apps from unwelcomely accessing your uncommitted contents in the composition buffer. A popup composition buffer will be shown instead."
      )
    case .kCheckAbusersOfSecureEventInputAPI: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.shortTitle",
        description: "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.description"
      )
    case .kDeltaOfCalendarYears: return nil
    case .kMostRecentInputMode: return nil
    case .kCassettePath: return .init(
        userDef: self, shortTitle: "Cassette file path",
        description: "Choose your desired cassette file path. Will be omitted if invalid."
      )
    case .kUserDataFolderSpecified: return .init(
        userDef: self, shortTitle: "User data folder path",
        description: "Choose your desired user data folder path. Will be omitted if invalid."
      )
    case .kCheckUpdateAutomatically: return .init(
        userDef: self, shortTitle: "Check for updates automatically"
      )
    case .kUseExternalFactoryDict: return .init(
        userDef: self, shortTitle: "Read external factory dictionary files if possible",
        description: "This will use the SQLite database deployed by the “make install” command from libvChewing-Data if possible."
      )
    case .kKeyboardParser: return .init(
        userDef: self, shortTitle: "Phonetic Parser:",
        description: "Choose the phonetic layout for Mandarin parser."
      )
    case .kBasicKeyboardLayout: return .init(
        userDef: self, shortTitle: "Basic Keyboard Layout:",
        description: "Choose the macOS-level basic keyboard layout. Non-QWERTY alphanumerical keyboard layouts are for Pinyin parser only. This option will only affect the appearance of the on-screen-keyboard if the current Mandarin parser is neither (any) pinyin nor dynamically reparsable with different western keyboard layouts (like Eten 26, Hsu, etc.)."
      )
    case .kAlphanumericalKeyboardLayout: return .init(
        userDef: self, shortTitle: "Alphanumerical Layout:",
        description: "Choose the macOS-level alphanumerical keyboard layout. This setting is for Shift-toggled alphanumerical mode only."
      )
    case .kShowNotificationsWhenTogglingCapsLock: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingCapsLock.title",
        minimumOS: 12
      )
    case .kShowNotificationsWhenTogglingEisu: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingEisu.title",
        description: "i18n:UserDef.kShowNotificationsWhenTogglingEisu.description"
      )
    case .kShowNotificationsWhenTogglingShift: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingShift.title",
        description: "i18n:UserDef.kShowNotificationsWhenTogglingShift.description",
        minimumOS: 10.15
      )
    case .kSpecifiedNotifyUIColorScheme: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.title",
        minimumOS: 10.14,
        options: [
          -1: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.enforceBright",
          0: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.notSpecified",
          1: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.enforceDark",
        ]
      )
    case .kCandidateListTextSize: return .init(
        userDef: self,
        shortTitle: "Candidate Size:",
        description: "Choose candidate font size for better visual clarity.",
        options: [
          12: "12",
          14: "14",
          16: "16",
          17: "17",
          18: "18",
          20: "20",
          22: "22",
          24: "24",
          32: "32",
          64: "64",
          96: "96",
        ]
      )
    case .kAlwaysExpandCandidateWindow: return .init(
        userDef: self,
        shortTitle: "Always expand candidate window panel"
      )
    case .kCandidateWindowShowOnlyOneLine: return .init(
        userDef: self,
        shortTitle: "Use only one row / column in candidate window",
        description: "Tadokoro candidate window shows 4 rows / columns by default, providing similar experiences from Microsoft New Phonetic IME and macOS bult-in Chinese IME (since macOS 10.9). However, for some users who have presbyopia, they prefer giant candidate font sizes, resulting a concern that multiple rows / columns of candidates can make the candidate window looks too big, hence this option. Note that this option will be dismissed if the typing context is vertical, forcing the candidates to be shown in only one row / column. Only one reverse-lookup result can be made available in single row / column mode due to reduced candidate window size."
      )
    case .kAppleLanguages: return .init(
        userDef: self, shortTitle: "UI Language:",
        description: "Change user interface language (will reboot the IME)."
      )
    case .kShouldAutoReloadUserDataFiles: return .init(
        userDef: self,
        shortTitle: "Automatically reload user data files if changes detected"
      )
    case .kUseRearCursorMode: return .init(
        userDef: self, shortTitle: "Cursor Selection:",
        description: "Choose the cursor position where you want to list possible candidates.",
        options: [
          0: "in front of the phrase (like macOS built-in Zhuyin IME)",
          1: "at the rear of the phrase (like Microsoft New Phonetic)",
        ]
      )
    case .kCandidateStateJKHLBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCandidateStateJKHLBehavior.shortTitle",
        description: "i18n:UserDef.kCandidateStateJKHLBehavior.description",
        options: [
          0: "i18n:UserDef.kCandidateStateJKHLBehavior.option.0",
          1: "i18n:UserDef.kCandidateStateJKHLBehavior.option.1",
          2: "i18n:UserDef.kCandidateStateJKHLBehavior.option.2",
        ]
      )
    case .kUseShiftQuestionToCallServiceMenu: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUseShiftQuestionToCallServiceMenu.shortTitle"
      )
    case .kUseDynamicCandidateWindowOrigin: return .init(
        userDef: self,
        shortTitle: "Adjust candidate window location according to current node length"
      )
    case .kUseHorizontalCandidateList: return .init(
        userDef: self, shortTitle: "Candidate Layout:",
        description: "Choose your preferred layout of the candidate window.",
        options: [0: "Vertical", 1: "Horizontal"]
      )
    case .kMinCellWidthForHorizontalMatrix: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.shortTitle",
        options: [
          0: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.option.0",
          1: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.option.1",
        ]
      )
    case .kChooseCandidateUsingSpace: return .init(
        userDef: self, shortTitle: "Enable Space key for calling candidate window",
        description: "If disabled, this will insert space instead."
      )
    case .kCassetteEnabled: return .init(
        userDef: self, shortTitle: "Enable cassette mode, suppressing phonabet input",
        description: "Cassette mode is similar to the CIN support of the Yahoo! KeyKey IME, allowing users to use their own CIN tables to implement their stroked-based input schema (e.g. Wubi, Cangjie, Boshiamy, etc.) as a plan-B in vChewing IME. However, since vChewing won't compromise its phonabet input mode experience for this cassette mode, users might not feel comfortable enough comparing to their experiences with RIME (recommended) or OpenVanilla (deprecated)."
      )
    case .kCNS11643Enabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kCNS11643Enabled.shortTitle"
      )
    case .kSymbolInputEnabled: return .init(
        userDef: self, shortTitle: "Enable symbol input support (incl. certain emoji symbols)"
      )
    case .kChineseConversionEnabled: return .init(
        userDef: self, shortTitle: "Auto-convert traditional Chinese glyphs to KangXi characters"
      )
    case .kShiftJISShinjitaiOutputEnabled: return .init(
        userDef: self,
        shortTitle: "Auto-convert traditional Chinese glyphs to JIS Shinjitai characters"
      )
    case .kCurrencyNumeralsEnabled: return .init(
        userDef: self,
        shortTitle: "Enable currency numerals output"
      )
    case .kHalfWidthPunctuationEnabled: return .init(
        userDef: self,
        shortTitle: "Enable half-width punctuations"
      )
    case .kCursorPlacementAfterSelectingCandidate: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.shortTitle:",
        description: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.description",
        options: [
          0: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.option.0",
          1: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.option.1",
          2: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.option.2",
        ]
      )
    case .kDodgeInvalidEdgeCandidateCursorPosition: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kDodgeInvalidEdgeCandidateCursorPosition.shortTitle"
      )
    case .kEscToCleanInputBuffer: return .init(
        userDef: self, shortTitle: "Use ESC key to clear the entire input buffer",
        description: "If unchecked, the ESC key will try cleaning the unfinished readings / strokes first, and will commit the current composition buffer if there's no unfinished readings / strokes."
      )
    case .kAcceptLeadingIntonations: return .init(
        userDef: self, shortTitle: "Accept leading intonations in rare cases",
        description: "This feature accommodates certain typing mistakes that the intonation mark might be typed at first (which is sequentially wrong from a common sense that intonation marks are supposed to be used for confirming combinations). It won't work if the current parser is of (any) pinyin. Also, this feature won't work when an intonation override is possible (and enabled)."
      )
    case .kSpecifyIntonationKeyBehavior: return .init(
        userDef: self, shortTitle: "Intonation Key:",
        description: "Specify the behavior of intonation key when syllable composer is empty.",
        options: [
          0: "Override the previous reading's intonation with candidate-reset",
          1: "Only override the intonation of the previous reading if different",
          2: "Always type intonations to the inline composition buffer",
        ]
      )
    case .kSpecifyShiftBackSpaceKeyBehavior: return .init(
        userDef: self, shortTitle: "Shift+BackSpace:",
        description: "Disassembling process does not work with non-phonetic reading keys.",
        options: [
          0: "Disassemble the previous reading, dropping its intonation",
          1: "Clear the entire inline composition buffer like Shift+Delete",
          2: "Always drop the previous reading",
        ]
      )
    case .kSpecifyShiftTabKeyBehavior: return .init(
        userDef: self, shortTitle: "(Shift+)Tab:",
        description: "Choose the behavior of (Shift+)Tab key in the candidate window.",
        options: [
          0: "for revolving candidates",
          1: "for revolving pages",
        ]
      )
    case .kSpecifyShiftSpaceKeyBehavior: return .init(
        userDef: self, shortTitle: "(Shift+)Space:",
        description: "Choose the behavior of (Shift+)Space key with candidates.",
        options: [
          0: "Space to +revolve candidates, Shift+Space to +revolve pages",
          1: "Space to +revolve pages, Shift+Space to +revolve candidates",
        ]
      )
    case .kSpecifyCmdOptCtrlEnterBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.shortTitle",
        description: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.description",
        options: [
          0: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.option.0",
          1: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.option.1",
          2: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.option.2",
          3: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.option.3",
          4: "i18n:UserDef.kSpecifyCmdOptCtrlEnterBehavior.option.4",
        ]
      )
    case .kReflectBPMFVSInCompositionBuffer: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kReflectBPMFVSInCompositionBuffer.shortTitle",
        description: "i18n:UserDef.kReflectBPMFVSInCompositionBuffer.description"
      )
    case .kAllowRescoringSingleKanjiCandidates: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kAllowRescoringSingleKanjiCandidates.shortTitle",
        description: "i18n:UserDef.kAllowRescoringSingleKanjiCandidates.description"
      )
    case .kUseSCPCTypingMode: return .init(
        userDef: self, shortTitle: "Emulating select-candidate-per-character mode",
        description: "An accommodation for elder computer users."
      )
    case .kMaxCandidateLength: return nil
    case .kBeepSoundPreference: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kBeepSoundPreference.shortTitle",
        options: [
          0: "i18n:UserDef.kBeepSoundPreference.option.0", // Disable
          1: "i18n:UserDef.kBeepSoundPreference.option.1", // Follow System
          2: "i18n:UserDef.kBeepSoundPreference.option.2", // Use vChewing SFX (Default Value)
        ]
      )
    case .kShouldNotFartInLieuOfBeep: return .init(
        userDef: self,
        shortTitle: "Stop farting (when typed phonetic combination is invalid, etc.)",
        description: "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas."
      )
    case .kShowHanyuPinyinInCompositionBuffer: return .init(
        userDef: self, shortTitle: "Show Hanyu-Pinyin in the inline composition buffer"
      )
    case .kInlineDumpPinyinInLieuOfZhuyin: return .init(
        userDef: self, shortTitle: "Commit Hanyu-Pinyin instead on Ctrl(+Option)+Command+Enter",
        description: "i18n:UserDef.kInlineDumpPinyinInLieuOfZhuyin.description"
      )
    case .kFetchSuggestionsFromPerceptionOverrideModel: return .init(
        userDef: self, shortTitle: "Applying typing suggestions from perception override model",
        description: "The user override model only possesses memories temporarily. Each memory record gradually becomes ineffective within approximately less than 6 days. You can erase all memory records through the input method menu."
      )
    case .kReducePOMLifetimeToNoMoreThan12Hours: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kReducePOMLifetimeToNoMoreThan12Hours.shortTitle",
        description: "i18n:UserDef.kReducePOMLifetimeToNoMoreThan12Hours.description"
      )
    case .kUseFixedCandidateOrderOnSelection: return .init(
        userDef: self, shortTitle: "Always use fixed listing order in candidate window",
        description: "This will stop user override model from affecting how candidates get sorted."
      )
    case .kAutoCorrectReadingCombination: return .init(
        userDef: self,
        shortTitle: "Automatically correct reading combinations when typing"
      )
    case .kReadingNarrationCoverage: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kReadingNarrationCoverage.shortTitle",
        description: "i18n:UserDef.kReadingNarrationCoverage.description",
        options: [
          0: "i18n:UserDef.kReadingNarrationCoverage.option.nothing",
          1: "i18n:UserDef.kReadingNarrationCoverage.option.confirmed",
          2: "i18n:UserDef.kReadingNarrationCoverage.option.realtime",
        ]
      )
    case .kAlsoConfirmAssociatedCandidatesByEnter: return .init(
        userDef: self,
        shortTitle: "Allow using Enter key to confirm associated candidate selection",
        description: "Otherwise, only the candidate keys are allowed to confirm associates."
      )
    case .kKeepReadingUponCompositionError: return .init(
        userDef: self,
        shortTitle: "Allow backspace-editing miscomposed readings"
      )
    case .kBypassNonAppleCapsLockHandling: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kBypassNonAppleCapsLockHandling.shortTitle",
        description: "i18n:UserDef.kBypassNonAppleCapsLockHandling.description",
        minimumOS: 10.15
      )
    case .kShiftEisuToggleOffTogetherWithCapsLock: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShiftEisuToggleOffTogetherWithCapsLock.shortTitle",
        description: "i18n:UserDef.kShiftEisuToggleOffTogetherWithCapsLock.description",
        minimumOS: 10.15
      )
    case .kTogglingAlphanumericalModeWithLShift: return .init(
        userDef: self, shortTitle: "Toggle alphanumerical mode with Left-Shift", minimumOS: 10.15
      )
    case .kTogglingAlphanumericalModeWithRShift: return .init(
        userDef: self, shortTitle: "Toggle alphanumerical mode with Right-Shift", minimumOS: 10.15
      )
    case .kUpperCaseLetterKeyBehavior: return .init(
        userDef: self, shortTitle: "Shift+Letter:",
        description: "Choose the behavior of Shift+Letter key with letter inputs.",
        options: [
          0: "Type them into inline composition buffer",
          1: "Always directly commit lowercased letters",
          2: "Always directly commit uppercased letters",
          3: "Directly commit lowercased letters only if the compositor is empty",
          4: "Directly commit uppercased letters only if the compositor is empty",
        ]
      )
    case .kNumPadCharInputBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kNumPadCharInputBehavior.shortTitle",
        description: "i18n:UserDef.kNumPadCharInputBehavior.description",
        options: [
          0: "i18n:UserDef.kNumPadCharInputBehavior.option.0",
          1: "i18n:UserDef.kNumPadCharInputBehavior.option.1",
          2: "i18n:UserDef.kNumPadCharInputBehavior.option.2",
          3: "i18n:UserDef.kNumPadCharInputBehavior.option.3",
          4: "i18n:UserDef.kNumPadCharInputBehavior.option.4",
          5: "i18n:UserDef.kNumPadCharInputBehavior.option.5",
        ]
      )
    case .kConsolidateContextOnCandidateSelection: return .init(
        userDef: self, shortTitle: "Consolidate the context on confirming candidate selection",
        description: "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is."
      )
    case .kHardenVerticalPunctuations: return .init(
        userDef: self,
        shortTitle: "Harden vertical punctuations during vertical typing (not recommended)",
        description: "⚠︎ This feature is useful ONLY WHEN the font you are using doesn't support dynamic vertical punctuations. However, typed vertical punctuations will always shown as vertical punctuations EVEN IF your editor has changed the typing direction to horizontal."
      )
    case .kTrimUnfinishedReadingsOnCommit: return .init(
        userDef: self,
        shortTitle: "Trim unfinished readings / strokes on commit"
      )
    case .kAlwaysShowTooltipTextsHorizontally: return .init(
        userDef: self,
        shortTitle: "Always show tooltip texts horizontally",
        description: "Key names in tooltip will be shown as symbols when the tooltip is vertical. However, this option will be ignored since tooltip will always be horizontal if the UI language is English."
      )
    case .kClientsIMKTextInputIncapable: return .init(userDef: self)
    case .kShowTranslatedStrokesInCompositionBuffer: return .init(
        userDef: self,
        shortTitle: "Show translated strokes in composition buffer",
        description: "All strokes in the composition buffer will be shown as ASCII keyboard characters unless this option is enabled. Stroke is definable in the “%keyname” section of the CIN file."
      )
    case .kForceCassetteChineseConversion: return .init(
        userDef: self,
        shortTitle: "Chinese Conversion:",
        description: "This conversion only affects the cassette module, converting typed contents to either Simplified Chinese or Traditional Chinese in accordance with this setting and your current input mode.",
        options: [
          0: "Disable forced conversion for cassette outputs",
          1: "Enforce conversion in both input modes",
          2: "Only enforce conversion in Simplified Chinese mode",
          3: "Only enforce conversion in Traditional Chinese mode",
        ]
      )
    case .kShowReverseLookupInCandidateUI: return .init(
        userDef: self, shortTitle: "Show available reverse-lookup results in candidate window",
        description: "The lookup results are supplied by the CIN cassette module."
      )
    case .kShowCodePointInCandidateUI: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kShowCodePointInCandidateUI.shortTitle"
      )
    case .kAutoCompositeWithLongestPossibleCassetteKey: return .init(
        userDef: self, shortTitle: "Auto-composite when the longest possible key is formed"
      )
    case .kShareAlphanumericalModeStatusAcrossClients: return .init(
        userDef: self, shortTitle: "Share alphanumerical mode status across all clients",
        description: "This only works when being toggled by Shift key and JIS Eisu key."
      )
    case .kPhraseEditorAutoReloadExternalModifications: return .init(
        userDef: self,
        shortTitle: "This editor only: Auto-reload modifications happened outside of this editor"
      )
    case .kClassicHaninKeyboardSymbolModeShortcutEnabled: return .init(
        userDef: self, shortTitle: "Also use “\\” or “¥” key for Hanin Keyboard Symbol Input"
      )
    case .kFilterNonCNSReadingsForCHTInput: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kFilterNonCNSReadingsForCHTInput.shortTitle"
      )
    case .kEnforceETenDOSCandidateSequence: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kEnforceETenDOSCandidateSequence.shortTitle",
        description: "i18n:UserDef.kEnforceETenDOSCandidateSequence.description"
      )
    case .kRomanNumeralOutputFormat: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kRomanNumeralOutputFormat.shortTitle",
        description: "i18n:UserDef.kRomanNumeralOutputFormat.description",
        options: [
          0: "i18n:UserDef.kRomanNumeralOutputFormat.option.0", // uppercaseASCII
          1: "i18n:UserDef.kRomanNumeralOutputFormat.option.1", // lowercaseASCII
          2: "i18n:UserDef.kRomanNumeralOutputFormat.option.2", // uppercaseURN
          3: "i18n:UserDef.kRomanNumeralOutputFormat.option.3", // lowercaseURN
        ]
      )
    case .kUseSpaceToCommitHighlightedSCPCCandidate: return .init(
        userDef: self,
        shortTitle: "Use Space to confirm highlighted candidate in Per-Char Select Mode"
      )
    case .kEnableMouseScrollingForTDKCandidatesCocoa: return .init(
        userDef: self, shortTitle: "Enable mouse wheel support for Tadokoro Candidate Window"
      )
    case .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients: return .init(
        userDef: self,
        shortTitle: "Disable segmented thick underline in marking mode for managed clients",
        description: "Some clients with web-based front UI may have issues rendering segmented thick underlines drawn by their implemented “setMarkedText()”. This option stops the input method from delivering segmented thick underlines to “client().setMarkedText()”. Note that segmented thick underlines are only used in marking mode, unless the client itself misimplements the IMKTextInput method “setMarkedText()”. This option only affects the inline composition buffer."
      )
    case .kCandidateTextFontName: return nil
    case .kCandidateKeys: return .init(
        userDef: self, shortTitle: "Selection Keys:",
        inlinePrompt: "Choose or hit Enter to confim your prefered keys for selecting candidates.",
        description: "This will also affect the row / column capacity of the candidate window."
      )
    case .kCandidateNarrationToggleType: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCandidateNarrationToggleType.shortTitle",
        description: "i18n:UserDef.kCandidateNarrationToggleType.description",
        options: [
          0: "i18n:UserDef.kCandidateNarrationToggleType.option.alwaysOff",
          1: "i18n:UserDef.kCandidateNarrationToggleType.option.alwaysOn",
          2: "i18n:UserDef.kCandidateNarrationToggleType.option.onlyWhenVoiceOverIsOn",
        ]
      )
    case .kAssociatedPhrasesEnabled: return nil
    case .kPhraseReplacementEnabled: return .init(
        userDef: self, shortTitle: "Enable phrase replacement table",
        description: "This will batch-replace specified candidates."
      )
    case .kUsingHotKeySCPC: return .init(userDef: self, shortTitle: "Per-Char Select Mode")
    case .kUsingHotKeyAssociates: return .init(userDef: self, shortTitle: "Associated Phrases")
    case .kUsingHotKeyCNS: return .init(userDef: self, shortTitle: "CNS11643 Mode")
    case .kUsingHotKeyKangXi: return .init(userDef: self, shortTitle: "Force KangXi Writing")
    case .kUsingHotKeyJIS: return .init(userDef: self, shortTitle: "Reverse Lookup (Phonabets)")
    case .kUsingHotKeyHalfWidthASCII: return .init(
        userDef: self,
        shortTitle: "JIS Shinjitai Output"
      )
    case .kUsingHotKeyCurrencyNumerals: return .init(
        userDef: self,
        shortTitle: "Half-Width Punctuation Mode"
      )
    case .kUsingHotKeyCassette: return .init(userDef: self, shortTitle: "Currency Numeral Output")
    case .kUsingHotKeyRevLookup: return .init(userDef: self, shortTitle: "CIN Cassette Mode")
    case .kUsingHotKeyInputMode: return .init(
        userDef: self,
        shortTitle: "CHS / CHT Input Mode Switch"
      )
    }
  }
}

nonisolated extension UserDef {
  // MARK: - 型別化預設值存取器（從 DataType 關聯值萃取）

  /// Bool 型別預設值。若該偏好鍵的 DataType 不是 `.bool`，則回傳 `false`。
  public var boolDefaultValue: Bool {
    guard case let .bool(v) = dataType else { return false }
    return v
  }

  /// Int 型別預設值。若該偏好鍵的 DataType 不是 `.integer`，則回傳 `0`。
  public var intDefaultValue: Int {
    guard case let .integer(v) = dataType else { return 0 }
    return v
  }

  /// Double 型別預設值。若該偏好鍵的 DataType 不是 `.double`，則回傳 `0`。
  public var doubleDefaultValue: Double {
    guard case let .double(v) = dataType else { return 0 }
    return v
  }

  /// String 型別預設值。若該偏好鍵的 DataType 不是 `.string`，則回傳空字串。
  public var stringDefaultValue: String {
    guard case let .string(v) = dataType else { return "" }
    return v
  }
}

nonisolated extension UserDef {
  // MARK: - 預設值常數

  /// 候選字服務選單的預設內容。
  public static let defaultValue4CandidateServiceMenuContents: [String] = [
    #"Unicode Metadata: %s"# + "\t" + #"@SEL:copyUnicodeMetadata:"#,
    #"macOS Dict: %s"# + "\t" + #"@URL:dict://%s"#,
    #"Bing: %s"# + "\t" + #"@WEB:https://www.bing.com/search?q=%s"#,
    #"DuckDuckGo: %s"# + "\t" + #"@WEB:https://duckduckgo.com/?t=h_&q=%s"#,
    #"Ecosia: %s"# + "\t" + #"@WEB:https://www.ecosia.org/search?method=index&q=%s"#,
    #"Google: %s"# + "\t" + #"@WEB:https://www.google.com/search?q=%s"#,
    #"MoeDict: %s"# + "\t" + #"@WEB:https://www.moedict.tw/%s"#,
    #"Wikitonary: %s"# + "\t" + #"@WEB:https://zh.wiktionary.org/wiki/Special:Search?search=%s"#,
    #"Unihan: %s"# + "\t" + #"@WEB:https://www.unicode.org/cgi-bin/GetUnihanData.pl?codepoint=%s"#,
    #"Zi-Hi: %s"# + "\t" + #"@WEB:https://zi-hi.com/sp/uni/%s"#,
    #"HTML Ruby Zhuyin: %s"# + "\t" + #"@SEL:copyRubyHTMLZhuyinTextbookStyle:"#,
    #"HTML Ruby Pinyin: %s"# + "\t" + #"@SEL:copyRubyHTMLHanyuPinyinTextbookStyle:"#,
    #"Zhuyin Annotation: %s"# + "\t" + #"@SEL:copyInlineZhuyinAnnotationTextbookStyle:"#,
    #"Pinyin Annotation: %s"# + "\t" + #"@SEL:copyInlineHanyuPinyinAnnotationTextbookStyle:"#,
    #"Braille 1947: %s"# + "\t" + #"@SEL:copyBraille1947:"#,
    #"Braille 2018: %s"# + "\t" + #"@SEL:copyBraille2018:"#,
    #"Baidu: %s"# + "\t" + #"@WEB:https://www.baidu.com/s?wd=%s"#,
    #"BiliBili: %s"# + "\t" + #"@WEB:https://search.bilibili.com/all?keyword=%s"#,
    #"Genshin BiliWiki: %s"# + "\t" + #"@WEB:https://wiki.biligame.com/ys/%s"#,
    #"HSR BiliWiki: %s"# + "\t" + #"@WEB:https://wiki.biligame.com/sr/%s"#,
  ]

  /// IMK 文字輸入不相容的客體清單預設值。
  public static let defaultValue4ClientsIMKTextInputIncapable: [String: Bool] = [
    "com.valvesoftware.steam": true,
    "jp.naver.line.mac": true,
    "com.openai.chat": true,
  ]

  private static let kDefaultCandidateKeys = "123456"
  private static let kDefaultBasicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
  private static let kDefaultAlphanumericalKeyboardLayout = {
    if #available(macOS 10.13, *) {
      return "com.apple.keylayout.ABC"
    }
    return "com.apple.keylayout.US"
  }()
}

// MARK: - AppProperty 便利初始化器

extension AppProperty {
  /// 以 `UserDef` 為來源的便利初始化器：自動從 `DataType` 關聯值取得預設值。
  ///
  /// 此初始化器使 `UserDef.dataType` 成為預設值的唯一事實來源（Single Source of Truth），
  /// 無需在 `PrefMgr` 中重複指定預設值。
  public init(userDef: UserDef) {
    guard let typedDefault = userDef.dataType.defaultValue as? Value else {
      fatalError(
        "[AppProperty] UserDef.\(userDef) 的 DataType 關聯值型別與 AppProperty<\(Value.self)> 不符。"
      )
    }
    self.init(key: userDef.rawValue, defaultValue: typedDefault)
  }
}
