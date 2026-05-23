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
  case kMixedAlphanumericalEnabled = "MixedAlphanumericalEnabled"
  case kCNS11643Enabled = "CNS11643Enabled"
  case kSymbolInputEnabled = "SymbolInputEnabled"
  case kChineseConversionEnabled = "ChineseConversionEnabled"
  case kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
  case kSuppressFactoryUnigramsOfKanaSyllables = "SuppressFactoryUnigramsOfKanaSyllables"
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

  case kUseSpaceToCommitHighlightedCandidate4SCPC = "UseSpaceToCommitHighlightedSCPCCandidate"
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
  case kFilterFactoryKanjisOfNonCurrentInputMode = "FilterFactoryKanjisOfNonCurrentInputMode"

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
    case .kMixedAlphanumericalEnabled: return .bool(false)
    case .kCNS11643Enabled: return .bool(false)
    case .kSymbolInputEnabled: return .bool(true)
    case .kChineseConversionEnabled: return .bool(false)
    case .kShiftJISShinjitaiOutputEnabled: return .bool(false)
    case .kSuppressFactoryUnigramsOfKanaSyllables: return .bool(false)
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
    case .kReflectBPMFVSInCompositionBuffer: return .bool(false)
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
    case .kUseSpaceToCommitHighlightedCandidate4SCPC: return .bool(false)
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
    case .kFilterFactoryKanjisOfNonCurrentInputMode: return .bool(false)
    }
  }
}

nonisolated extension UserDef {
  public var metaData: MetaData? {
    switch self {
    case .kIsDebugModeEnabled: return .init(userDef: self, shortTitle: "i18n:UserDef.kIsDebugModeEnabled.shortTitle")
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
        userDef: self, shortTitle: "i18n:UserDef.kSecurityHardenedCompositionBuffer.shortTitle",
        description: "i18n:UserDef.kSecurityHardenedCompositionBuffer.description"
      )
    case .kCheckAbusersOfSecureEventInputAPI: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.shortTitle",
        description: "i18n:UserDef.kCheckAbusersOfSecureEventInputAPI.description"
      )
    case .kDeltaOfCalendarYears: return nil
    case .kMostRecentInputMode: return nil
    case .kCassettePath: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCassettePath.shortTitle",
        description: "i18n:UserDef.kCassettePath.description"
      )
    case .kUserDataFolderSpecified: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUserDataFolderSpecified.shortTitle",
        description: "i18n:UserDef.kUserDataFolderSpecified.description"
      )
    case .kCheckUpdateAutomatically: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCheckUpdateAutomatically.shortTitle"
      )
    case .kUseExternalFactoryDict: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUseExternalFactoryDict.shortTitle",
        description: "i18n:UserDef.kUseExternalFactoryDict.description"
      )
    case .kKeyboardParser: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kKeyboardParser.shortTitle",
        description: "i18n:UserDef.kKeyboardParser.description"
      )
    case .kBasicKeyboardLayout: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kBasicKeyboardLayout.shortTitle",
        description: "i18n:UserDef.kBasicKeyboardLayout.description"
      )
    case .kAlphanumericalKeyboardLayout: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kAlphanumericalKeyboardLayout.shortTitle",
        description: "i18n:UserDef.kAlphanumericalKeyboardLayout.description"
      )
    case .kShowNotificationsWhenTogglingCapsLock: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingCapsLock.shortTitle",
        minimumOS: 12
      )
    case .kShowNotificationsWhenTogglingEisu: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingEisu.shortTitle",
        description: "i18n:UserDef.kShowNotificationsWhenTogglingEisu.description"
      )
    case .kShowNotificationsWhenTogglingShift: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowNotificationsWhenTogglingShift.shortTitle",
        description: "i18n:UserDef.kShowNotificationsWhenTogglingShift.description",
        minimumOS: 10.15
      )
    case .kSpecifiedNotifyUIColorScheme: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.shortTitle",
        minimumOS: 10.14,
        options: [
          -1: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.-1",
          0: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.0",
          1: "i18n:UserDef.kSpecifiedNotifyUIColorScheme.option.1",
        ]
      )
    case .kCandidateListTextSize: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kCandidateListTextSize.shortTitle",
        description: "i18n:UserDef.kCandidateListTextSize.description",
        options: [
          12: "i18n:UserDef.kCandidateListTextSize.option.12",
          14: "i18n:UserDef.kCandidateListTextSize.option.14",
          16: "i18n:UserDef.kCandidateListTextSize.option.16",
          17: "i18n:UserDef.kCandidateListTextSize.option.17",
          18: "i18n:UserDef.kCandidateListTextSize.option.18",
          20: "i18n:UserDef.kCandidateListTextSize.option.20",
          22: "i18n:UserDef.kCandidateListTextSize.option.22",
          24: "i18n:UserDef.kCandidateListTextSize.option.24",
          32: "i18n:UserDef.kCandidateListTextSize.option.32",
          64: "i18n:UserDef.kCandidateListTextSize.option.64",
          96: "i18n:UserDef.kCandidateListTextSize.option.96",
        ]
      )
    case .kAlwaysExpandCandidateWindow: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kAlwaysExpandCandidateWindow.shortTitle"
      )
    case .kCandidateWindowShowOnlyOneLine: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kCandidateWindowShowOnlyOneLine.shortTitle",
        description: "i18n:UserDef.kCandidateWindowShowOnlyOneLine.description"
      )
    case .kAppleLanguages: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kAppleLanguages.shortTitle",
        description: "i18n:UserDef.kAppleLanguages.description"
      )
    case .kShouldAutoReloadUserDataFiles: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShouldAutoReloadUserDataFiles.shortTitle"
      )
    case .kUseRearCursorMode: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUseRearCursorMode.shortTitle",
        description: "i18n:UserDef.kUseRearCursorMode.description",
        options: [
          0: "i18n:UserDef.kUseRearCursorMode.option.0",
          1: "i18n:UserDef.kUseRearCursorMode.option.1",
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
        shortTitle: "i18n:UserDef.kUseDynamicCandidateWindowOrigin.shortTitle"
      )
    case .kUseHorizontalCandidateList: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUseHorizontalCandidateList.shortTitle",
        description: "i18n:UserDef.kUseHorizontalCandidateList.description",
        options: [
          0: "i18n:UserDef.kUseHorizontalCandidateList.option.0",
          1: "i18n:UserDef.kUseHorizontalCandidateList.option.1",
        ]
      )
    case .kMinCellWidthForHorizontalMatrix: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.shortTitle",
        options: [
          0: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.option.0",
          1: "i18n:UserDef.kMinCellWidthForHorizontalMatrix.option.1",
        ]
      )
    case .kChooseCandidateUsingSpace: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kChooseCandidateUsingSpace.shortTitle",
        description: "i18n:UserDef.kChooseCandidateUsingSpace.description"
      )
    case .kCassetteEnabled: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCassetteEnabled.shortTitle",
        description: "i18n:UserDef.kCassetteEnabled.description"
      )
    case .kMixedAlphanumericalEnabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kMixedAlphanumericalEnabled.shortTitle",
        description: "i18n:UserDef.kMixedAlphanumericalEnabled.description"
      )
    case .kCNS11643Enabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kCNS11643Enabled.shortTitle"
      )
    case .kSymbolInputEnabled: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSymbolInputEnabled.shortTitle"
      )
    case .kChineseConversionEnabled: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kChineseConversionEnabled.shortTitle"
      )
    case .kShiftJISShinjitaiOutputEnabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShiftJISShinjitaiOutputEnabled.shortTitle"
      )
    case .kSuppressFactoryUnigramsOfKanaSyllables: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kSuppressFactoryUnigramsOfKanaSyllables.shortTitle",
        description: "i18n:UserDef.kSuppressFactoryUnigramsOfKanaSyllables.description",
      )
    case .kCurrencyNumeralsEnabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kCurrencyNumeralsEnabled.shortTitle"
      )
    case .kHalfWidthPunctuationEnabled: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kHalfWidthPunctuationEnabled.shortTitle"
      )
    case .kCursorPlacementAfterSelectingCandidate: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCursorPlacementAfterSelectingCandidate.shortTitle",
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
        userDef: self, shortTitle: "i18n:UserDef.kEscToCleanInputBuffer.shortTitle",
        description: "i18n:UserDef.kEscToCleanInputBuffer.description"
      )
    case .kAcceptLeadingIntonations: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kAcceptLeadingIntonations.shortTitle",
        description: "i18n:UserDef.kAcceptLeadingIntonations.description"
      )
    case .kSpecifyIntonationKeyBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSpecifyIntonationKeyBehavior.shortTitle",
        description: "i18n:UserDef.kSpecifyIntonationKeyBehavior.description",
        options: [
          0: "i18n:UserDef.kSpecifyIntonationKeyBehavior.option.0",
          1: "i18n:UserDef.kSpecifyIntonationKeyBehavior.option.1",
          2: "i18n:UserDef.kSpecifyIntonationKeyBehavior.option.2",
        ]
      )
    case .kSpecifyShiftBackSpaceKeyBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSpecifyShiftBackSpaceKeyBehavior.shortTitle",
        description: "i18n:UserDef.kSpecifyShiftBackSpaceKeyBehavior.description",
        options: [
          0: "i18n:UserDef.kSpecifyShiftBackSpaceKeyBehavior.option.0",
          1: "i18n:UserDef.kSpecifyShiftBackSpaceKeyBehavior.option.1",
          2: "i18n:UserDef.kSpecifyShiftBackSpaceKeyBehavior.option.2",
        ]
      )
    case .kSpecifyShiftTabKeyBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSpecifyShiftTabKeyBehavior.shortTitle",
        description: "i18n:UserDef.kSpecifyShiftTabKeyBehavior.description",
        options: [
          0: "i18n:UserDef.kSpecifyShiftTabKeyBehavior.option.0",
          1: "i18n:UserDef.kSpecifyShiftTabKeyBehavior.option.1",
        ]
      )
    case .kSpecifyShiftSpaceKeyBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kSpecifyShiftSpaceKeyBehavior.shortTitle",
        description: "i18n:UserDef.kSpecifyShiftSpaceKeyBehavior.description",
        options: [
          0: "i18n:UserDef.kSpecifyShiftSpaceKeyBehavior.option.0",
          1: "i18n:UserDef.kSpecifyShiftSpaceKeyBehavior.option.1",
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
        userDef: self, shortTitle: "i18n:UserDef.kUseSCPCTypingMode.shortTitle",
        description: "i18n:UserDef.kUseSCPCTypingMode.description"
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
        shortTitle: "i18n:UserDef.kShouldNotFartInLieuOfBeep.shortTitle",
        description: "i18n:UserDef.kShouldNotFartInLieuOfBeep.description"
      )
    case .kShowHanyuPinyinInCompositionBuffer: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kShowHanyuPinyinInCompositionBuffer.shortTitle"
      )
    case .kInlineDumpPinyinInLieuOfZhuyin: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kInlineDumpPinyinInLieuOfZhuyin.shortTitle",
        description: "i18n:UserDef.kInlineDumpPinyinInLieuOfZhuyin.description"
      )
    case .kFetchSuggestionsFromPerceptionOverrideModel: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kFetchSuggestionsFromPerceptionOverrideModel.shortTitle",
        description: "i18n:UserDef.kFetchSuggestionsFromPerceptionOverrideModel.description"
      )
    case .kReducePOMLifetimeToNoMoreThan12Hours: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kReducePOMLifetimeToNoMoreThan12Hours.shortTitle",
        description: "i18n:UserDef.kReducePOMLifetimeToNoMoreThan12Hours.description"
      )
    case .kUseFixedCandidateOrderOnSelection: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUseFixedCandidateOrderOnSelection.shortTitle",
        description: "i18n:UserDef.kUseFixedCandidateOrderOnSelection.description"
      )
    case .kAutoCorrectReadingCombination: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kAutoCorrectReadingCombination.shortTitle",
        description: "i18n:UserDef.kAutoCorrectReadingCombination.description"
      )
    case .kReadingNarrationCoverage: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kReadingNarrationCoverage.shortTitle",
        description: "i18n:UserDef.kReadingNarrationCoverage.description",
        options: [
          0: "i18n:UserDef.kReadingNarrationCoverage.option.0",
          1: "i18n:UserDef.kReadingNarrationCoverage.option.1",
          2: "i18n:UserDef.kReadingNarrationCoverage.option.2",
        ]
      )
    case .kAlsoConfirmAssociatedCandidatesByEnter: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kAlsoConfirmAssociatedCandidatesByEnter.shortTitle",
        description: "i18n:UserDef.kAlsoConfirmAssociatedCandidatesByEnter.description"
      )
    case .kKeepReadingUponCompositionError: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kKeepReadingUponCompositionError.shortTitle"
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
        userDef: self, shortTitle: "i18n:UserDef.kTogglingAlphanumericalModeWithLShift.shortTitle", minimumOS: 10.15
      )
    case .kTogglingAlphanumericalModeWithRShift: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kTogglingAlphanumericalModeWithRShift.shortTitle", minimumOS: 10.15
      )
    case .kUpperCaseLetterKeyBehavior: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kUpperCaseLetterKeyBehavior.shortTitle",
        description: "i18n:UserDef.kUpperCaseLetterKeyBehavior.description",
        options: [
          0: "i18n:UserDef.kUpperCaseLetterKeyBehavior.option.0",
          1: "i18n:UserDef.kUpperCaseLetterKeyBehavior.option.1",
          2: "i18n:UserDef.kUpperCaseLetterKeyBehavior.option.2",
          3: "i18n:UserDef.kUpperCaseLetterKeyBehavior.option.3",
          4: "i18n:UserDef.kUpperCaseLetterKeyBehavior.option.4",
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
        userDef: self, shortTitle: "i18n:UserDef.kConsolidateContextOnCandidateSelection.shortTitle",
        description: "i18n:UserDef.kConsolidateContextOnCandidateSelection.description"
      )
    case .kHardenVerticalPunctuations: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kHardenVerticalPunctuations.shortTitle",
        description: "i18n:UserDef.kHardenVerticalPunctuations.description"
      )
    case .kTrimUnfinishedReadingsOnCommit: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kTrimUnfinishedReadingsOnCommit.shortTitle"
      )
    case .kAlwaysShowTooltipTextsHorizontally: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kAlwaysShowTooltipTextsHorizontally.shortTitle",
        description: "i18n:UserDef.kAlwaysShowTooltipTextsHorizontally.description"
      )
    case .kClientsIMKTextInputIncapable: return .init(userDef: self)
    case .kShowTranslatedStrokesInCompositionBuffer: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kShowTranslatedStrokesInCompositionBuffer.shortTitle",
        description: "i18n:UserDef.kShowTranslatedStrokesInCompositionBuffer.description"
      )
    case .kForceCassetteChineseConversion: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kForceCassetteChineseConversion.shortTitle",
        description: "i18n:UserDef.kForceCassetteChineseConversion.description",
        options: [
          0: "i18n:UserDef.kForceCassetteChineseConversion.option.0",
          1: "i18n:UserDef.kForceCassetteChineseConversion.option.1",
          2: "i18n:UserDef.kForceCassetteChineseConversion.option.2",
          3: "i18n:UserDef.kForceCassetteChineseConversion.option.3",
        ]
      )
    case .kShowReverseLookupInCandidateUI: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kShowReverseLookupInCandidateUI.shortTitle",
        description: "i18n:UserDef.kShowReverseLookupInCandidateUI.description"
      )
    case .kShowCodePointInCandidateUI: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kShowCodePointInCandidateUI.shortTitle"
      )
    case .kAutoCompositeWithLongestPossibleCassetteKey: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kAutoCompositeWithLongestPossibleCassetteKey.shortTitle"
      )
    case .kShareAlphanumericalModeStatusAcrossClients: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kShareAlphanumericalModeStatusAcrossClients.shortTitle",
        description: "i18n:UserDef.kShareAlphanumericalModeStatusAcrossClients.description"
      )
    case .kPhraseEditorAutoReloadExternalModifications: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kPhraseEditorAutoReloadExternalModifications.shortTitle"
      )
    case .kClassicHaninKeyboardSymbolModeShortcutEnabled: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.shortTitle"
      )
    case .kFilterNonCNSReadingsForCHTInput: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kFilterNonCNSReadingsForCHTInput.shortTitle",
        description: "i18n:UserDef.kFilterNonCNSReadingsForCHTInput.description"
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
    case .kUseSpaceToCommitHighlightedCandidate4SCPC: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.shortTitle",
        description: "i18n:UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.description"
      )
    case .kEnableMouseScrollingForTDKCandidatesCocoa: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.shortTitle"
      )
    case .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.shortTitle",
        description: "i18n:UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.description"
      )
    case .kCandidateTextFontName: return nil
    case .kCandidateKeys: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCandidateKeys.shortTitle",
        inlinePrompt: "i18n:UserDef.kCandidateKeys.inlinePrompt",
        description: "i18n:UserDef.kCandidateKeys.description"
      )
    case .kCandidateNarrationToggleType: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kCandidateNarrationToggleType.shortTitle",
        description: "i18n:UserDef.kCandidateNarrationToggleType.description",
        options: [
          0: "i18n:UserDef.kCandidateNarrationToggleType.option.0",
          1: "i18n:UserDef.kCandidateNarrationToggleType.option.1",
          2: "i18n:UserDef.kCandidateNarrationToggleType.option.2",
        ]
      )
    case .kAssociatedPhrasesEnabled: return nil
    case .kPhraseReplacementEnabled: return .init(
        userDef: self, shortTitle: "i18n:UserDef.kPhraseReplacementEnabled.shortTitle",
        description: "i18n:UserDef.kPhraseReplacementEnabled.description"
      )
    case .kUsingHotKeySCPC: return .init(userDef: self, shortTitle: "i18n:UserDef.kUsingHotKeySCPC.shortTitle")
    case .kUsingHotKeyAssociates: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUsingHotKeyAssociates.shortTitle"
      )
    case .kUsingHotKeyCNS: return .init(userDef: self, shortTitle: "i18n:UserDef.kUsingHotKeyCNS.shortTitle")
    case .kUsingHotKeyKangXi: return .init(userDef: self, shortTitle: "i18n:UserDef.kUsingHotKeyKangXi.shortTitle")
    case .kUsingHotKeyJIS: return .init(userDef: self, shortTitle: "i18n:UserDef.kUsingHotKeyJIS.shortTitle")
    case .kUsingHotKeyHalfWidthASCII: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUsingHotKeyHalfWidthASCII.shortTitle"
      )
    case .kUsingHotKeyCurrencyNumerals: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUsingHotKeyCurrencyNumerals.shortTitle"
      )
    case .kUsingHotKeyCassette: return .init(userDef: self, shortTitle: "i18n:UserDef.kUsingHotKeyCassette.shortTitle")
    case .kUsingHotKeyRevLookup: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUsingHotKeyRevLookup.shortTitle"
      )
    case .kUsingHotKeyInputMode: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kUsingHotKeyInputMode.shortTitle"
      )
    case .kFilterFactoryKanjisOfNonCurrentInputMode: return .init(
        userDef: self,
        shortTitle: "i18n:UserDef.kFilterFactoryKanjisOfNonCurrentInputMode.shortTitle",
        description: "i18n:UserDef.kFilterFactoryKanjisOfNonCurrentInputMode.description"
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

// MARK: - AppProperty 便利初期化器

extension AppProperty {
  /// 以 `UserDef` 為來源的便利初期化器：自動從 `DataType` 關聯值取得預設值。
  ///
  /// 此初期化器使 `UserDef.dataType` 成為預設值的唯一事實來源（Single Source of Truth），
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
