// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - UserDef Snapshot Manager

public enum UserDef: String, CaseIterable {
  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForUOMObservation = "_FailureFlag_UOMObservation"
  case kDeltaOfCalendarYears = "DeltaOfCalendarYears"
  case kMostRecentInputMode = "MostRecentInputMode"
  case kUserDataFolderSpecified = "UserDataFolderSpecified"
  case kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  case kKeyboardParser = "KeyboardParser"
  case kBasicKeyboardLayout = "BasicKeyboardLayout"
  case kAlphanumericalKeyboardLayout = "AlphanumericalKeyboardLayout"
  case kShowPageButtonsInCandidateWindow = "ShowPageButtonsInCandidateWindow"
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "UseRearCursorMode"
  case kUseHorizontalCandidateList = "UseHorizontalCandidateList"
  case kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
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

  case kUseIMKCandidateWindow = "UseIMKCandidateWindow"
  case kHandleDefaultCandidateFontsByLangIdentifier = "HandleDefaultCandidateFontsByLangIdentifier"
  case kShiftKeyAccommodationBehavior = "ShiftKeyAccommodationBehavior"

  case kCandidateTextFontName = "CandidateTextFontName"
  case kCandidateKeyLabelFontName = "CandidateKeyLabelFontName"
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

// MARK: - Enums and Structs used by Candidate Window

public enum CandidateLayout {
  case horizontal
  case vertical
}

public struct CandidateKeyLabel {
  public private(set) var key: String
  public private(set) var displayedText: String

  public init(key: String, displayedText: String) {
    self.key = key
    self.displayedText = displayedText
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

  public enum ErrorType: Error, LocalizedError {
    case empty
    case invalidCharacters
    case containSpace
    case duplicatedCharacters
    case tooShort
    case tooLong

    public var errorDescription: String {
      switch self {
        case .empty:
          return NSLocalizedString("Candidates keys cannot be empty.", comment: "")
        case .invalidCharacters:
          return NSLocalizedString(
            "Candidate keys can only contain ASCII characters like alphanumericals.",
            comment: ""
          )
        case .containSpace:
          return NSLocalizedString("Candidate keys cannot contain space.", comment: "")
        case .duplicatedCharacters:
          return NSLocalizedString("There should not be duplicated keys.", comment: "")
        case .tooShort:
          return NSLocalizedString(
            "Please specify at least 4 candidate keys.", comment: ""
          )
        case .tooLong:
          return NSLocalizedString("Maximum 15 candidate keys allowed.", comment: "")
      }
    }
  }

  public static func validate(keys candidateKeys: String) throws {
    let trimmed = candidateKeys.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      throw CandidateKey.ErrorType.empty
    }
    if !trimmed.canBeConverted(to: .ascii) {
      throw CandidateKey.ErrorType.invalidCharacters
    }
    if trimmed.contains(" ") {
      throw CandidateKey.ErrorType.containSpace
    }
    if trimmed.count < 4 {
      throw CandidateKey.ErrorType.tooShort
    }
    if trimmed.count > 15 {
      throw CandidateKey.ErrorType.tooLong
    }
    let set = Set(Array(trimmed))
    if set.count != trimmed.count {
      throw CandidateKey.ErrorType.duplicatedCharacters
    }
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
