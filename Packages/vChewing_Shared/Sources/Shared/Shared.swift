// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// MARK: - UserDef Snapshot Manager

public enum UserDef: String, CaseIterable {
  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForUOMObservation = "_FailureFlag_UOMObservation"
  case kDeltaOfCalendarYears = "DeltaOfCalendarYears"
  case kMostRecentInputMode = "MostRecentInputMode"
  case kCassettePath = "CassettePath"
  case kUserDataFolderSpecified = "UserDataFolderSpecified"
  case kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  case kKeyboardParser = "KeyboardParser"
  case kBasicKeyboardLayout = "BasicKeyboardLayout"
  case kAlphanumericalKeyboardLayout = "AlphanumericalKeyboardLayout"
  case kShowNotificationsWhenTogglingCapsLock = "ShowNotificationsWhenTogglingCapsLock"
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "UseRearCursorMode"
  case kUseHorizontalCandidateList = "UseHorizontalCandidateList"
  case kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
  case kCassetteEnabled = "CassetteEnabled"
  case kCNS11643Enabled = "CNS11643Enabled"
  case kSymbolInputEnabled = "SymbolInputEnabled"
  case kChineseConversionEnabled = "ChineseConversionEnabled"
  case kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
  case kCurrencyNumeralsEnabled = "CurrencyNumeralsEnabled"
  case kHalfWidthPunctuationEnabled = "HalfWidthPunctuationEnable"
  case kMoveCursorAfterSelectingCandidate = "MoveCursorAfterSelectingCandidate"
  case kEscToCleanInputBuffer = "EscToCleanInputBuffer"
  case kSpecifyIntonationKeyBehavior = "SecifyIntonationKeyBehavior"
  case kSpecifyShiftBackSpaceKeyBehavior = "SpecifyShiftBackSpaceKeyBehavior"
  case kSpecifyShiftTabKeyBehavior = "SpecifyShiftTabKeyBehavior"
  case kSpecifyShiftSpaceKeyBehavior = "SpecifyShiftSpaceKeyBehavior"
  case kAllowBoostingSingleKanjiAsUserPhrase = "AllowBoostingSingleKanjiAsUserPhrase"
  case kUseSCPCTypingMode = "UseSCPCTypingMode"
  case kMaxCandidateLength = "MaxCandidateLength"
  case kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"
  case kShowHanyuPinyinInCompositionBuffer = "ShowHanyuPinyinInCompositionBuffer"
  case kInlineDumpPinyinInLieuOfZhuyin = "InlineDumpPinyinInLieuOfZhuyin"
  case kFetchSuggestionsFromUserOverrideModel = "FetchSuggestionsFromUserOverrideModel"
  case kUseFixecCandidateOrderOnSelection = "UseFixecCandidateOrderOnSelection"
  case kAutoCorrectReadingCombination = "AutoCorrectReadingCombination"
  case kAlsoConfirmAssociatedCandidatesByEnter = "AlsoConfirmAssociatedCandidatesByEnter"
  case kKeepReadingUponCompositionError = "KeepReadingUponCompositionError"
  case kTogglingAlphanumericalModeWithLShift = "TogglingAlphanumericalModeWithLShift"
  case kUpperCaseLetterKeyBehavior = "UpperCaseLetterKeyBehavior"
  case kDisableShiftTogglingAlphanumericalMode = "DisableShiftTogglingAlphanumericalMode"
  case kConsolidateContextOnCandidateSelection = "ConsolidateContextOnCandidateSelection"
  case kHardenVerticalPunctuations = "HardenVerticalPunctuations"
  case kTrimUnfinishedReadingsOnCommit = "TrimUnfinishedReadingsOnCommit"
  case kAlwaysShowTooltipTextsHorizontally = "AlwaysShowTooltipTextsHorizontally"
  case kClientsIMKTextInputIncapable = "ClientsIMKTextInputIncapable"
  case kOnlyLoadFactoryLangModelsIfNeeded = "OnlyLoadFactoryLangModelsIfNeeded"
  case kShowTranslatedStrokesInCompositionBuffer = "ShowTranslatedStrokesInCompositionBuffer"
  case kForceCassetteChineseConversion = "ForceCassetteChineseConversion"
  case kShowReverseLookupInCandidateUI = "ShowReverseLookupInCandidateUI"

  case kUseIMKCandidateWindow = "UseIMKCandidateWindow"
  case kHandleDefaultCandidateFontsByLangIdentifier = "HandleDefaultCandidateFontsByLangIdentifier"
  case kShiftKeyAccommodationBehavior = "ShiftKeyAccommodationBehavior"

  case kCandidateTextFontName = "CandidateTextFontName"
  case kCandidateKeys = "CandidateKeys"

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

  public static func resetAll() {
    UserDef.allCases.forEach {
      UserDefaults.standard.removeObject(forKey: $0.rawValue)
    }
  }

  public static func load(from snapshot: Snapshot) {
    let data = snapshot.data
    guard !data.isEmpty else { return }
    UserDef.allCases.forEach {
      UserDefaults.standard.set(data[$0.rawValue], forKey: $0.rawValue)
    }
  }

  public struct Snapshot {
    public var data: [String: Any] = [:]
    public init() {
      UserDef.allCases.forEach {
        data[$0.rawValue] = UserDefaults.standard.object(forKey: $0.rawValue)
      }
    }
  }
}

// MARK: - Tooltip Color States

public enum TooltipColorState {
  case normal
  case redAlert
  case warning
  case denialOverflow
  case denialInsufficiency
  case prompt
}

// MARK: - IMEState types.

// 用以讓每個狀態自描述的 enum。
public enum StateType: String {
  case ofDeactivated = "Deactivated"
  case ofEmpty = "Empty"
  case ofAbortion = "Abortion"  // 該狀態會自動轉為 Empty
  case ofCommitting = "Committing"
  case ofAssociates = "Associates"
  case ofNotEmpty = "NotEmpty"
  case ofInputting = "Inputting"
  case ofMarking = "Marking"
  case ofCandidates = "Candidates"
  case ofSymbolTable = "SymbolTable"
}

// MARK: - Parser for Syllable composer

public enum KeyboardParser: Int, CaseIterable {
  case ofStandard = 0
  case ofETen = 1
  case ofHsu = 2
  case ofETen26 = 3
  case ofIBM = 4
  case ofMiTAC = 5
  case ofFakeSeigyou = 6
  case ofDachen26 = 7
  case ofSeigyou = 8
  case ofStarlight = 9
  case ofHanyuPinyin = 10
  case ofSecondaryPinyin = 11
  case ofYalePinyin = 12
  case ofHualuoPinyin = 13
  case ofUniversalPinyin = 14

  public var name: String {
    switch self {
      case .ofStandard:
        return "Standard"
      case .ofETen:
        return "ETen"
      case .ofHsu:
        return "Hsu"
      case .ofETen26:
        return "ETen26"
      case .ofIBM:
        return "IBM"
      case .ofMiTAC:
        return "MiTAC"
      case .ofFakeSeigyou:
        return "FakeSeigyou"
      case .ofDachen26:
        return "Dachen26"
      case .ofSeigyou:
        return "Seigyou"
      case .ofStarlight:
        return "Starlight"
      case .ofHanyuPinyin:
        return "HanyuPinyin"
      case .ofSecondaryPinyin:
        return "SecondaryPinyin"
      case .ofYalePinyin:
        return "YalePinyin"
      case .ofHualuoPinyin:
        return "HualuoPinyin"
      case .ofUniversalPinyin:
        return "UniversalPinyin"
    }
  }
}

public enum CandidateKey {
  public static var defaultKeys: String { suggestions[0] }
  public static let suggestions: [String] = [
    "123456789", "234567890", "QWERTYUIO", "QWERTASDF", "ASDFGHJKL", "ASDFZXCVB",
  ]

  /// 僅列舉那些需要專門檢查才能發現的那種無法自動排除的錯誤。
  public enum ValidationError {
    case noError
    case invalidCharacters
    case countMismatch

    public var description: String {
      switch self {
        case .invalidCharacters:
          return "- "
            + NSLocalizedString(
              "Candidate keys can only contain printable ASCII characters like alphanumericals.",
              comment: ""
            ) + "\n" + "- " + NSLocalizedString("Candidate keys cannot contain space.", comment: "")
        case .countMismatch:
          return "- "
            + NSLocalizedString(
              "Minimum 6 candidate keys allowed.", comment: ""
            ) + "\n" + "- " + NSLocalizedString("Maximum 9 candidate keys allowed.", comment: "")
        case .noError:
          return ""
      }
    }
  }

  /// 校驗選字鍵參數資料值的合法性。
  /// - Remark: 傳入的參數值得事先做過下述處理：
  /// ```
  /// .trimmingCharacters(in: .whitespacesAndNewlines).deduplicated
  /// ```
  /// - Parameter candidateKeys: 傳入的參數值
  /// - Returns: 返回 nil 的話，證明沒有錯誤；否則會返回錯誤描述訊息。
  public static func validate(keys candidateKeys: String) -> String? {
    var result = ValidationError.noError
    charValidityCheck: for neta in candidateKeys {
      if String(neta) == " " {
        result = CandidateKey.ValidationError.invalidCharacters
        break charValidityCheck
      }
      for subNeta in neta.unicodeScalars {
        if !subNeta.isPrintableASCII {
          result = CandidateKey.ValidationError.invalidCharacters
          break charValidityCheck
        }
      }
    }
    if !(6...9).contains(candidateKeys.count) {
      result = CandidateKey.ValidationError.countMismatch
    }
    return result == ValidationError.noError ? nil : result.description
  }
}

public func vCLog(_ strPrint: StringLiteralType) {
  if UserDefaults.standard.bool(forKey: "_DebugMode") {
    NSLog("vChewingDebug: %@", strPrint)
  }
}

public enum Shared {
  // MARK: - 瀏覽器 Bundle Identifier 關鍵詞匹配黑名單

  /// 瀏覽器 Bundle Identifier 關鍵詞匹配黑名單，匹配到的瀏覽器會做出特殊的 Shift 鍵擊劍判定處理。
  public static let arrClientShiftHandlingExceptionList: [String] = [
    "com.avast.browser", "com.brave.Browser", "com.brave.Browser.beta", "com.coccoc.Coccoc", "com.fenrir-inc.Sleipnir",
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.hiddenreflex.Epic",
    "com.maxthon.Maxthon", "com.microsoft.edgemac", "com.microsoft.edgemac.Canary", "com.microsoft.edgemac.Dev",
    "com.naver.Whale", "com.operasoftware.Opera", "com.valvesoftware.steam", "com.vivaldi.Vivaldi",
    "net.qihoo.360browser", "org.blisk.Blisk", "org.chromium.Chromium", "org.qt-project.Qt.QtWebEngineCore",
    "ru.yandex.desktop.yandex-browser",
  ]

  public static let arrSupportedLocales: [String] = ["en", "zh-Hant", "zh-Hans", "ja"]

  // The type of input modes.
  public enum InputMode: String, CaseIterable {
    case imeModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
    case imeModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
    case imeModeNULL = ""
    public var reversed: Shared.InputMode {
      switch self {
        case .imeModeCHS:
          return .imeModeCHT
        case .imeModeCHT:
          return .imeModeCHS
        case .imeModeNULL:
          return .imeModeNULL
      }
    }
  }
}
