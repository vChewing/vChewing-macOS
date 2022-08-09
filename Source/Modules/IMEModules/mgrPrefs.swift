// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public enum UserDef: String, CaseIterable {
  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForUOMObservation = "_FailureFlag_UOMObservation"
  case kDeltaOfCalendarYears = "DeltaOfCalendarYears"
  case kMostRecentInputMode = "MostRecentInputMode"
  case kUserDataFolderSpecified = "UserDataFolderSpecified"
  case kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  case kMandarinParser = "MandarinParser"
  case kBasicKeyboardLayout = "BasicKeyboardLayout"
  case kShowPageButtonsInCandidateWindow = "ShowPageButtonsInCandidateWindow"
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "useRearCursorMode"
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
}

private let kDefaultCandidateListTextSize: CGFloat = 18
private let kDefaultMinKeyLabelSize: CGFloat = 10
private let kMinCandidateListTextSize: CGFloat = 12
private let kMaxCandidateListTextSize: CGFloat = 196

private let kDefaultKeys = "123456789"

// MARK: - UserDefaults extension.

extension UserDefaults {
  func setDefault(_ value: Any?, forKey defaultName: String) {
    if object(forKey: defaultName) == nil {
      set(value, forKey: defaultName)
    }
  }
}

// MARK: - Property wrappers

@propertyWrapper
struct UserDefault<Value> {
  let key: String
  let defaultValue: Value
  var container: UserDefaults = .standard

  var wrappedValue: Value {
    get {
      container.object(forKey: key) as? Value ?? defaultValue
    }
    set {
      container.set(newValue, forKey: key)
    }
  }
}

@propertyWrapper
struct CandidateListTextSize {
  let key: String
  let defaultValue: CGFloat = kDefaultCandidateListTextSize
  lazy var container: UserDefault = .init(key: key, defaultValue: defaultValue)

  var wrappedValue: CGFloat {
    mutating get {
      var value = container.wrappedValue
      if value < kMinCandidateListTextSize {
        value = kMinCandidateListTextSize
      } else if value > kMaxCandidateListTextSize {
        value = kMaxCandidateListTextSize
      }
      return value
    }
    set {
      var value = newValue
      if value < kMinCandidateListTextSize {
        value = kMinCandidateListTextSize
      } else if value > kMaxCandidateListTextSize {
        value = kMaxCandidateListTextSize
      }
      container.wrappedValue = value
    }
  }
}

// MARK: -

enum MandarinParser: Int {
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

  var name: String {
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

// MARK: -

public enum mgrPrefs {
  public static func setMissingDefaults() {
    UserDefaults.standard.setDefault(mgrPrefs.isDebugModeEnabled, forKey: UserDef.kIsDebugModeEnabled.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.failureFlagForUOMObservation, forKey: UserDef.kFailureFlagForUOMObservation.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.deltaOfCalendarYears, forKey: UserDef.kDeltaOfCalendarYears.rawValue
    )
    UserDefaults.standard.setDefault(mgrPrefs.mostRecentInputMode, forKey: UserDef.kMostRecentInputMode.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.checkUpdateAutomatically, forKey: UserDef.kCheckUpdateAutomatically.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.showPageButtonsInCandidateWindow, forKey: UserDef.kShowPageButtonsInCandidateWindow.rawValue
    )
    UserDefaults.standard.setDefault(mgrPrefs.symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled.rawValue)
    UserDefaults.standard.setDefault(mgrPrefs.candidateListTextSize, forKey: UserDef.kCandidateListTextSize.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.chooseCandidateUsingSpace, forKey: UserDef.kChooseCandidateUsingSpace.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.shouldAutoReloadUserDataFiles, forKey: UserDef.kShouldAutoReloadUserDataFiles.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.specifyShiftTabKeyBehavior, forKey: UserDef.kSpecifyShiftTabKeyBehavior.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.specifyShiftSpaceKeyBehavior, forKey: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue
    )
    UserDefaults.standard.setDefault(mgrPrefs.useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.useRearCursorMode, forKey: UserDef.kUseRearCursorMode.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.moveCursorAfterSelectingCandidate, forKey: UserDef.kMoveCursorAfterSelectingCandidate.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.useHorizontalCandidateList, forKey: UserDef.kUseHorizontalCandidateList.rawValue
    )
    UserDefaults.standard.setDefault(mgrPrefs.cns11643Enabled, forKey: UserDef.kCNS11643Enabled.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.showHanyuPinyinInCompositionBuffer, forKey: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.inlineDumpPinyinInLieuOfZhuyin, forKey: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.allowBoostingSingleKanjiAsUserPhrase, forKey: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.fetchSuggestionsFromUserOverrideModel, forKey: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.useFixecCandidateOrderOnSelection, forKey: UserDef.kUseFixecCandidateOrderOnSelection.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.autoCorrectReadingCombination, forKey: UserDef.kAutoCorrectReadingCombination.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.alsoConfirmAssociatedCandidatesByEnter, forKey: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.currencyNumeralsEnabled, forKey: UserDef.kCurrencyNumeralsEnabled.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.keepReadingUponCompositionError, forKey: UserDef.kKeepReadingUponCompositionError.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.togglingAlphanumericalModeWithLShift, forKey: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.upperCaseLetterKeyBehavior, forKey: UserDef.kUpperCaseLetterKeyBehavior.rawValue
    )

    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeySCPC, forKey: UserDef.kUsingHotKeySCPC.rawValue)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyAssociates, forKey: UserDef.kUsingHotKeyAssociates.rawValue)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyCNS, forKey: UserDef.kUsingHotKeyCNS.rawValue)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyKangXi, forKey: UserDef.kUsingHotKeyKangXi.rawValue)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyJIS, forKey: UserDef.kUsingHotKeyJIS.rawValue)
    UserDefaults.standard.setDefault(
      mgrPrefs.usingHotKeyHalfWidthASCII, forKey: UserDef.kUsingHotKeyHalfWidthASCII.rawValue
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.usingHotKeyCurrencyNumerals, forKey: UserDef.kUsingHotKeyCurrencyNumerals.rawValue
    )

    UserDefaults.standard.synchronize()
  }

  // MARK: - Settings (Tier 1)

  @UserDefault(key: UserDef.kIsDebugModeEnabled.rawValue, defaultValue: false)
  static var isDebugModeEnabled: Bool

  @UserDefault(key: UserDef.kFailureFlagForUOMObservation.rawValue, defaultValue: false)
  static var failureFlagForUOMObservation: Bool

  @UserDefault(key: UserDef.kDeltaOfCalendarYears.rawValue, defaultValue: -2000)
  static var deltaOfCalendarYears: Int

  @UserDefault(key: UserDef.kMostRecentInputMode.rawValue, defaultValue: "")
  static var mostRecentInputMode: String

  @UserDefault(key: UserDef.kCheckUpdateAutomatically.rawValue, defaultValue: false)
  static var checkUpdateAutomatically: Bool

  @UserDefault(key: UserDef.kUserDataFolderSpecified.rawValue, defaultValue: "")
  static var userDataFolderSpecified: String

  static func ifSpecifiedUserDataPathExistsInPlist() -> Bool {
    UserDefaults.standard.object(forKey: UserDef.kUserDataFolderSpecified.rawValue) != nil
  }

  static func resetSpecifiedUserDataFolder() {
    UserDefaults.standard.removeObject(forKey: "UserDataFolderSpecified")
    IME.initLangModels(userOnly: true)
  }

  @UserDefault(key: UserDef.kAppleLanguages.rawValue, defaultValue: [])
  static var appleLanguages: [String]

  @UserDefault(key: UserDef.kMandarinParser.rawValue, defaultValue: 0)
  static var mandarinParser: Int

  static var mandarinParserName: String {
    (MandarinParser(rawValue: mandarinParser) ?? MandarinParser.ofStandard).name
  }

  @UserDefault(
    key: UserDef.kBasicKeyboardLayout.rawValue, defaultValue: "com.apple.keylayout.ZhuyinBopomofo"
  )
  static var basicKeyboardLayout: String

  @UserDefault(key: UserDef.kShowPageButtonsInCandidateWindow.rawValue, defaultValue: true)
  static var showPageButtonsInCandidateWindow: Bool

  @CandidateListTextSize(key: UserDef.kCandidateListTextSize.rawValue)
  static var candidateListTextSize: CGFloat

  static var minKeyLabelSize: CGFloat { kDefaultMinKeyLabelSize }

  @UserDefault(key: UserDef.kShouldAutoReloadUserDataFiles.rawValue, defaultValue: true)
  static var shouldAutoReloadUserDataFiles: Bool

  @UserDefault(key: UserDef.kUseRearCursorMode.rawValue, defaultValue: false)
  static var useRearCursorMode: Bool

  @UserDefault(key: UserDef.kMoveCursorAfterSelectingCandidate.rawValue, defaultValue: true)
  static var moveCursorAfterSelectingCandidate: Bool

  @UserDefault(key: UserDef.kUseHorizontalCandidateList.rawValue, defaultValue: true)
  static var useHorizontalCandidateList: Bool

  @UserDefault(key: UserDef.kChooseCandidateUsingSpace.rawValue, defaultValue: true)
  static var chooseCandidateUsingSpace: Bool

  @UserDefault(key: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue, defaultValue: false)
  static var allowBoostingSingleKanjiAsUserPhrase: Bool

  @UserDefault(key: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue, defaultValue: true)
  static var fetchSuggestionsFromUserOverrideModel: Bool

  @UserDefault(key: UserDef.kUseFixecCandidateOrderOnSelection.rawValue, defaultValue: false)
  static var useFixecCandidateOrderOnSelection: Bool

  @UserDefault(key: UserDef.kAutoCorrectReadingCombination.rawValue, defaultValue: true)
  static var autoCorrectReadingCombination: Bool

  @UserDefault(key: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue, defaultValue: true)
  static var alsoConfirmAssociatedCandidatesByEnter: Bool

  @UserDefault(key: UserDef.kKeepReadingUponCompositionError.rawValue, defaultValue: false)
  static var keepReadingUponCompositionError: Bool

  @UserDefault(key: UserDef.kUpperCaseLetterKeyBehavior.rawValue, defaultValue: 0)
  static var upperCaseLetterKeyBehavior: Int

  // MARK: - Settings (Tier 2)

  @UserDefault(key: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue, defaultValue: true)
  static var togglingAlphanumericalModeWithLShift: Bool

  static var minCandidateLength: Int {
    mgrPrefs.allowBoostingSingleKanjiAsUserPhrase ? 1 : 2
  }

  @UserDefault(key: UserDef.kUseSCPCTypingMode.rawValue, defaultValue: false)
  static var useSCPCTypingMode: Bool

  static func toggleSCPCTypingModeEnabled() -> Bool {
    useSCPCTypingMode = !useSCPCTypingMode
    UserDefaults.standard.set(useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode.rawValue)
    return useSCPCTypingMode
  }

  @UserDefault(key: UserDef.kMaxCandidateLength.rawValue, defaultValue: 10)
  static var maxCandidateLength: Int

  @UserDefault(key: UserDef.kShouldNotFartInLieuOfBeep.rawValue, defaultValue: true)
  static var shouldNotFartInLieuOfBeep: Bool

  @UserDefault(key: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue, defaultValue: false)
  static var showHanyuPinyinInCompositionBuffer: Bool

  @UserDefault(key: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue, defaultValue: false)
  static var inlineDumpPinyinInLieuOfZhuyin: Bool

  static func toggleShouldNotFartInLieuOfBeep() -> Bool {
    shouldNotFartInLieuOfBeep = !shouldNotFartInLieuOfBeep
    UserDefaults.standard.set(shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep.rawValue)
    return shouldNotFartInLieuOfBeep
  }

  @UserDefault(key: UserDef.kCNS11643Enabled.rawValue, defaultValue: false)
  static var cns11643Enabled: Bool

  static func toggleCNS11643Enabled() -> Bool {
    cns11643Enabled = !cns11643Enabled
    mgrLangModel.setCNSEnabled(cns11643Enabled)  // 很重要
    UserDefaults.standard.set(cns11643Enabled, forKey: UserDef.kCNS11643Enabled.rawValue)
    return cns11643Enabled
  }

  @UserDefault(key: UserDef.kSymbolInputEnabled.rawValue, defaultValue: true)
  static var symbolInputEnabled: Bool

  static func toggleSymbolInputEnabled() -> Bool {
    symbolInputEnabled = !symbolInputEnabled
    mgrLangModel.setSymbolEnabled(symbolInputEnabled)  // 很重要
    UserDefaults.standard.set(symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled.rawValue)
    return symbolInputEnabled
  }

  @UserDefault(key: UserDef.kChineseConversionEnabled.rawValue, defaultValue: false)
  static var chineseConversionEnabled: Bool

  @discardableResult static func toggleChineseConversionEnabled() -> Bool {
    chineseConversionEnabled = !chineseConversionEnabled
    // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
    if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
      toggleShiftJISShinjitaiOutputEnabled()
      UserDefaults.standard.set(
        shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
      )
    }
    UserDefaults.standard.set(chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue)
    return chineseConversionEnabled
  }

  @UserDefault(key: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue, defaultValue: false)
  static var shiftJISShinjitaiOutputEnabled: Bool

  @discardableResult static func toggleShiftJISShinjitaiOutputEnabled() -> Bool {
    shiftJISShinjitaiOutputEnabled = !shiftJISShinjitaiOutputEnabled
    // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
    if shiftJISShinjitaiOutputEnabled, chineseConversionEnabled {
      toggleChineseConversionEnabled()
    }
    UserDefaults.standard.set(
      shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
    )
    return shiftJISShinjitaiOutputEnabled
  }

  @UserDefault(key: UserDef.kCurrencyNumeralsEnabled.rawValue, defaultValue: false)
  static var currencyNumeralsEnabled: Bool

  static func toggleCurrencyNumeralsEnabled() -> Bool {
    currencyNumeralsEnabled = !currencyNumeralsEnabled
    return currencyNumeralsEnabled
  }

  @UserDefault(key: UserDef.kHalfWidthPunctuationEnabled.rawValue, defaultValue: false)
  static var halfWidthPunctuationEnabled: Bool

  static func toggleHalfWidthPunctuationEnabled() -> Bool {
    halfWidthPunctuationEnabled = !halfWidthPunctuationEnabled
    return halfWidthPunctuationEnabled
  }

  @UserDefault(key: UserDef.kEscToCleanInputBuffer.rawValue, defaultValue: true)
  static var escToCleanInputBuffer: Bool

  @UserDefault(key: UserDef.kSpecifyShiftTabKeyBehavior.rawValue, defaultValue: false)
  static var specifyShiftTabKeyBehavior: Bool

  @UserDefault(key: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue, defaultValue: false)
  static var specifyShiftSpaceKeyBehavior: Bool

  // MARK: - Optional settings

  @UserDefault(key: UserDef.kCandidateTextFontName.rawValue, defaultValue: nil)
  static var candidateTextFontName: String?

  @UserDefault(key: UserDef.kCandidateKeyLabelFontName.rawValue, defaultValue: nil)
  static var candidateKeyLabelFontName: String?

  @UserDefault(key: UserDef.kCandidateKeys.rawValue, defaultValue: kDefaultKeys)
  static var candidateKeys: String

  static var defaultCandidateKeys: String {
    kDefaultKeys
  }

  static var suggestedCandidateKeys: [String] {
    [kDefaultKeys, "234567890", "QWERTYUIO", "QWERTASDF", "ASDFGHJKL", "ASDFZXCVB"]
  }

  static func validate(candidateKeys: String) throws {
    let trimmed = candidateKeys.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      throw CandidateKeyError.empty
    }
    if !trimmed.canBeConverted(to: .ascii) {
      throw CandidateKeyError.invalidCharacters
    }
    if trimmed.contains(" ") {
      throw CandidateKeyError.containSpace
    }
    if trimmed.count < 4 {
      throw CandidateKeyError.tooShort
    }
    if trimmed.count > 15 {
      throw CandidateKeyError.tooLong
    }
    let set = Set(Array(trimmed))
    if set.count != trimmed.count {
      throw CandidateKeyError.duplicatedCharacters
    }
  }

  enum CandidateKeyError: Error, LocalizedError {
    case empty
    case invalidCharacters
    case containSpace
    case duplicatedCharacters
    case tooShort
    case tooLong

    var errorDescription: String? {
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

  @UserDefault(key: UserDef.kPhraseReplacementEnabled.rawValue, defaultValue: false)
  static var phraseReplacementEnabled: Bool

  static func togglePhraseReplacementEnabled() -> Bool {
    phraseReplacementEnabled = !phraseReplacementEnabled
    mgrLangModel.setPhraseReplacementEnabled(phraseReplacementEnabled)
    UserDefaults.standard.set(phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled.rawValue)
    return phraseReplacementEnabled
  }

  @UserDefault(key: UserDef.kAssociatedPhrasesEnabled.rawValue, defaultValue: false)
  static var associatedPhrasesEnabled: Bool

  static func toggleAssociatedPhrasesEnabled() -> Bool {
    associatedPhrasesEnabled = !associatedPhrasesEnabled
    UserDefaults.standard.set(associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled.rawValue)
    return associatedPhrasesEnabled
  }

  // MARK: - Keyboard HotKey Enable / Disable

  @UserDefault(key: UserDef.kUsingHotKeySCPC.rawValue, defaultValue: true)
  static var usingHotKeySCPC: Bool

  @UserDefault(key: UserDef.kUsingHotKeyAssociates.rawValue, defaultValue: true)
  static var usingHotKeyAssociates: Bool

  @UserDefault(key: UserDef.kUsingHotKeyCNS.rawValue, defaultValue: true)
  static var usingHotKeyCNS: Bool

  @UserDefault(key: UserDef.kUsingHotKeyKangXi.rawValue, defaultValue: true)
  static var usingHotKeyKangXi: Bool

  @UserDefault(key: UserDef.kUsingHotKeyJIS.rawValue, defaultValue: true)
  static var usingHotKeyJIS: Bool

  @UserDefault(key: UserDef.kUsingHotKeyHalfWidthASCII.rawValue, defaultValue: true)
  static var usingHotKeyHalfWidthASCII: Bool

  @UserDefault(key: UserDef.kUsingHotKeyCurrencyNumerals.rawValue, defaultValue: true)
  static var usingHotKeyCurrencyNumerals: Bool
}

// MARK: Snapshot Extension

var snapshot: [String: Any]?

extension mgrPrefs {
  func reset() {
    UserDef.allCases.forEach {
      UserDefaults.standard.removeObject(forKey: $0.rawValue)
    }
  }

  func makeSnapshot() -> [String: Any] {
    var dict = [String: Any]()
    UserDef.allCases.forEach {
      dict[$0.rawValue] = UserDefaults.standard.object(forKey: $0.rawValue)
    }
    return dict
  }

  func restore(from snapshot: [String: Any]) {
    UserDef.allCases.forEach {
      UserDefaults.standard.set(snapshot[$0.rawValue], forKey: $0.rawValue)
    }
  }
}
