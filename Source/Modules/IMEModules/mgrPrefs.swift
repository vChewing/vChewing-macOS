// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

struct UserDef {
  static let kIsDebugModeEnabled = "_DebugMode"
  static let kMostRecentInputMode = "MostRecentInputMode"
  static let kUserDataFolderSpecified = "UserDataFolderSpecified"
  static let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  static let kMandarinParser = "MandarinParser"
  static let kBasicKeyboardLayout = "BasicKeyboardLayout"
  static let kShowPageButtonsInCandidateWindow = "ShowPageButtonsInCandidateWindow"
  static let kCandidateListTextSize = "CandidateListTextSize"
  static let kAppleLanguages = "AppleLanguages"
  static let kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  static let kuseRearCursorMode = "useRearCursorMode"
  static let kUseHorizontalCandidateList = "UseHorizontalCandidateList"
  static let kComposingBufferSize = "ComposingBufferSize"
  static let kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
  static let kCNS11643Enabled = "CNS11643Enabled"
  static let kSymbolInputEnabled = "SymbolInputEnabled"
  static let kChineseConversionEnabled = "ChineseConversionEnabled"
  static let kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
  static let kCurrencyNumeralsEnabled = "CurrencyNumeralsEnabled"
  static let kHalfWidthPunctuationEnabled = "HalfWidthPunctuationEnable"
  static let kMoveCursorAfterSelectingCandidate = "MoveCursorAfterSelectingCandidate"
  static let kEscToCleanInputBuffer = "EscToCleanInputBuffer"
  static let kSpecifyShiftTabKeyBehavior = "SpecifyShiftTabKeyBehavior"
  static let kSpecifyShiftSpaceKeyBehavior = "SpecifyShiftSpaceKeyBehavior"
  static let kAllowBoostingSingleKanjiAsUserPhrase = "AllowBoostingSingleKanjiAsUserPhrase"
  static let kUseSCPCTypingMode = "UseSCPCTypingMode"
  static let kMaxCandidateLength = "MaxCandidateLength"
  static let kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"
  static let kShowHanyuPinyinInCompositionBuffer = "ShowHanyuPinyinInCompositionBuffer"
  static let kInlineDumpPinyinInLieuOfZhuyin = "InlineDumpPinyinInLieuOfZhuyin"
  static let kFetchSuggestionsFromUserOverrideModel = "FetchSuggestionsFromUserOverrideModel"
  static let kUseFixecCandidateOrderOnSelection = "UseFixecCandidateOrderOnSelection"
  static let kAutoCorrectReadingCombination = "AutoCorrectReadingCombination"
  static let kAlsoConfirmAssociatedCandidatesByEnter = "AlsoConfirmAssociatedCandidatesByEnter"

  static let kCandidateTextFontName = "CandidateTextFontName"
  static let kCandidateKeyLabelFontName = "CandidateKeyLabelFontName"
  static let kCandidateKeys = "CandidateKeys"

  static let kAssociatedPhrasesEnabled = "AssociatedPhrasesEnabled"
  static let kPhraseReplacementEnabled = "PhraseReplacementEnabled"

  static let kUsingHotKeySCPC = "UsingHotKeySCPC"
  static let kUsingHotKeyAssociates = "UsingHotKeyAssociates"
  static let kUsingHotKeyCNS = "UsingHotKeyCNS"
  static let kUsingHotKeyKangXi = "UsingHotKeyKangXi"
  static let kUsingHotKeyJIS = "UsingHotKeyJIS"
  static let kUsingHotKeyHalfWidthASCII = "UsingHotKeyHalfWidthASCII"
  static let kUsingHotKeyCurrencyNumerals = "UsingHotKeyCurrencyNumerals"
}

private let kDefaultCandidateListTextSize: CGFloat = 18
private let kDefaultMinKeyLabelSize: CGFloat = 10
private let kMinCandidateListTextSize: CGFloat = 12
private let kMaxCandidateListTextSize: CGFloat = 196

// default, min and max composing buffer size (in codepoints)
// modern Macs can usually work up to 16 codepoints when the compositor still
// walks the grid with good performance slower Macs (like old PowerBooks)
// will start to sputter beyond 12 such is the algorithmatic complexity
// of the Viterbi algorithm used in the Megrez library (at O(N^2))
private let kDefaultComposingBufferSize = 20
private let kMinComposingBufferSize = 10
private let kMaxComposingBufferSize = 40

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

@propertyWrapper
struct ComposingBufferSize {
  let key: String
  let defaultValue: Int = kDefaultComposingBufferSize
  lazy var container: UserDefault = .init(key: key, defaultValue: defaultValue)

  var wrappedValue: Int {
    mutating get {
      let currentValue = container.wrappedValue
      if currentValue < kMinComposingBufferSize {
        return kMinComposingBufferSize
      } else if currentValue > kMaxComposingBufferSize {
        return kMaxComposingBufferSize
      }
      return currentValue
    }
    set {
      var value = newValue
      if value < kMinComposingBufferSize {
        value = kMinComposingBufferSize
      } else if value > kMaxComposingBufferSize {
        value = kMaxComposingBufferSize
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
    UserDefaults.standard.setDefault(mgrPrefs.isDebugModeEnabled, forKey: UserDef.kIsDebugModeEnabled)
    UserDefaults.standard.setDefault(mgrPrefs.mostRecentInputMode, forKey: UserDef.kMostRecentInputMode)
    UserDefaults.standard.setDefault(mgrPrefs.checkUpdateAutomatically, forKey: UserDef.kCheckUpdateAutomatically)
    UserDefaults.standard.setDefault(
      mgrPrefs.showPageButtonsInCandidateWindow, forKey: UserDef.kShowPageButtonsInCandidateWindow
    )
    UserDefaults.standard.setDefault(mgrPrefs.symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled)
    UserDefaults.standard.setDefault(mgrPrefs.candidateListTextSize, forKey: UserDef.kCandidateListTextSize)
    UserDefaults.standard.setDefault(mgrPrefs.chooseCandidateUsingSpace, forKey: UserDef.kChooseCandidateUsingSpace)
    UserDefaults.standard.setDefault(
      mgrPrefs.shouldAutoReloadUserDataFiles, forKey: UserDef.kShouldAutoReloadUserDataFiles
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.specifyShiftTabKeyBehavior, forKey: UserDef.kSpecifyShiftTabKeyBehavior
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.specifyShiftSpaceKeyBehavior, forKey: UserDef.kSpecifyShiftSpaceKeyBehavior
    )
    UserDefaults.standard.setDefault(mgrPrefs.useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode)
    UserDefaults.standard.setDefault(mgrPrefs.associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled)
    UserDefaults.standard.setDefault(
      mgrPrefs.useRearCursorMode, forKey: UserDef.kuseRearCursorMode
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.moveCursorAfterSelectingCandidate, forKey: UserDef.kMoveCursorAfterSelectingCandidate
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.useHorizontalCandidateList, forKey: UserDef.kUseHorizontalCandidateList
    )
    UserDefaults.standard.setDefault(mgrPrefs.cns11643Enabled, forKey: UserDef.kCNS11643Enabled)
    UserDefaults.standard.setDefault(mgrPrefs.chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled)
    UserDefaults.standard.setDefault(
      mgrPrefs.shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled
    )
    UserDefaults.standard.setDefault(mgrPrefs.phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled)
    UserDefaults.standard.setDefault(mgrPrefs.shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep)
    UserDefaults.standard.setDefault(
      mgrPrefs.showHanyuPinyinInCompositionBuffer, forKey: UserDef.kShowHanyuPinyinInCompositionBuffer
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.inlineDumpPinyinInLieuOfZhuyin, forKey: UserDef.kInlineDumpPinyinInLieuOfZhuyin
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.allowBoostingSingleKanjiAsUserPhrase, forKey: UserDef.kAllowBoostingSingleKanjiAsUserPhrase
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.fetchSuggestionsFromUserOverrideModel, forKey: UserDef.kFetchSuggestionsFromUserOverrideModel
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.useFixecCandidateOrderOnSelection, forKey: UserDef.kUseFixecCandidateOrderOnSelection
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.autoCorrectReadingCombination, forKey: UserDef.kAutoCorrectReadingCombination
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.alsoConfirmAssociatedCandidatesByEnter, forKey: UserDef.kAlsoConfirmAssociatedCandidatesByEnter
    )
    UserDefaults.standard.setDefault(
      mgrPrefs.currencyNumeralsEnabled, forKey: UserDef.kCurrencyNumeralsEnabled
    )

    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeySCPC, forKey: UserDef.kUsingHotKeySCPC)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyAssociates, forKey: UserDef.kUsingHotKeyAssociates)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyCNS, forKey: UserDef.kUsingHotKeyCNS)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyKangXi, forKey: UserDef.kUsingHotKeyKangXi)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyJIS, forKey: UserDef.kUsingHotKeyJIS)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyHalfWidthASCII, forKey: UserDef.kUsingHotKeyHalfWidthASCII)
    UserDefaults.standard.setDefault(mgrPrefs.usingHotKeyCurrencyNumerals, forKey: UserDef.kUsingHotKeyCurrencyNumerals)

    UserDefaults.standard.synchronize()
  }

  @UserDefault(key: UserDef.kIsDebugModeEnabled, defaultValue: false)
  static var isDebugModeEnabled: Bool

  @UserDefault(key: UserDef.kMostRecentInputMode, defaultValue: "")
  static var mostRecentInputMode: String

  @UserDefault(key: UserDef.kCheckUpdateAutomatically, defaultValue: false)
  static var checkUpdateAutomatically: Bool

  @UserDefault(key: UserDef.kUserDataFolderSpecified, defaultValue: "")
  static var userDataFolderSpecified: String

  static func ifSpecifiedUserDataPathExistsInPlist() -> Bool {
    UserDefaults.standard.object(forKey: UserDef.kUserDataFolderSpecified) != nil
  }

  static func resetSpecifiedUserDataFolder() {
    UserDefaults.standard.removeObject(forKey: "UserDataFolderSpecified")
    IME.initLangModels(userOnly: true)
  }

  @UserDefault(key: UserDef.kAppleLanguages, defaultValue: [])
  static var appleLanguages: [String]

  @UserDefault(key: UserDef.kMandarinParser, defaultValue: 0)
  static var mandarinParser: Int

  static var mandarinParserName: String {
    (MandarinParser(rawValue: mandarinParser) ?? MandarinParser.ofStandard).name
  }

  @UserDefault(
    key: UserDef.kBasicKeyboardLayout, defaultValue: "com.apple.keylayout.ZhuyinBopomofo"
  )
  static var basicKeyboardLayout: String

  @UserDefault(key: UserDef.kShowPageButtonsInCandidateWindow, defaultValue: true)
  static var showPageButtonsInCandidateWindow: Bool

  @CandidateListTextSize(key: UserDef.kCandidateListTextSize)
  static var candidateListTextSize: CGFloat

  static var minKeyLabelSize: CGFloat { kDefaultMinKeyLabelSize }

  @UserDefault(key: UserDef.kShouldAutoReloadUserDataFiles, defaultValue: true)
  static var shouldAutoReloadUserDataFiles: Bool

  @UserDefault(key: UserDef.kuseRearCursorMode, defaultValue: false)
  static var useRearCursorMode: Bool

  @UserDefault(key: UserDef.kMoveCursorAfterSelectingCandidate, defaultValue: true)
  static var moveCursorAfterSelectingCandidate: Bool

  @UserDefault(key: UserDef.kUseHorizontalCandidateList, defaultValue: true)
  static var useHorizontalCandidateList: Bool

  @ComposingBufferSize(key: UserDef.kComposingBufferSize)
  static var composingBufferSize: Int

  @UserDefault(key: UserDef.kChooseCandidateUsingSpace, defaultValue: true)
  static var chooseCandidateUsingSpace: Bool

  @UserDefault(key: UserDef.kAllowBoostingSingleKanjiAsUserPhrase, defaultValue: false)
  static var allowBoostingSingleKanjiAsUserPhrase: Bool

  @UserDefault(key: UserDef.kFetchSuggestionsFromUserOverrideModel, defaultValue: true)
  static var fetchSuggestionsFromUserOverrideModel: Bool

  @UserDefault(key: UserDef.kUseFixecCandidateOrderOnSelection, defaultValue: false)
  static var useFixecCandidateOrderOnSelection: Bool

  @UserDefault(key: UserDef.kAutoCorrectReadingCombination, defaultValue: true)
  static var autoCorrectReadingCombination: Bool

  @UserDefault(key: UserDef.kAlsoConfirmAssociatedCandidatesByEnter, defaultValue: true)
  static var alsoConfirmAssociatedCandidatesByEnter: Bool

  static var minCandidateLength: Int {
    mgrPrefs.allowBoostingSingleKanjiAsUserPhrase ? 1 : 2
  }

  @UserDefault(key: UserDef.kUseSCPCTypingMode, defaultValue: false)
  static var useSCPCTypingMode: Bool

  static func toggleSCPCTypingModeEnabled() -> Bool {
    useSCPCTypingMode = !useSCPCTypingMode
    UserDefaults.standard.set(useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode)
    return useSCPCTypingMode
  }

  @UserDefault(key: UserDef.kMaxCandidateLength, defaultValue: 10)
  static var maxCandidateLength: Int

  @UserDefault(key: UserDef.kShouldNotFartInLieuOfBeep, defaultValue: true)
  static var shouldNotFartInLieuOfBeep: Bool

  @UserDefault(key: UserDef.kShowHanyuPinyinInCompositionBuffer, defaultValue: false)
  static var showHanyuPinyinInCompositionBuffer: Bool

  @UserDefault(key: UserDef.kInlineDumpPinyinInLieuOfZhuyin, defaultValue: false)
  static var inlineDumpPinyinInLieuOfZhuyin: Bool

  static func toggleShouldNotFartInLieuOfBeep() -> Bool {
    shouldNotFartInLieuOfBeep = !shouldNotFartInLieuOfBeep
    UserDefaults.standard.set(shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep)
    return shouldNotFartInLieuOfBeep
  }

  @UserDefault(key: UserDef.kCNS11643Enabled, defaultValue: false)
  static var cns11643Enabled: Bool

  static func toggleCNS11643Enabled() -> Bool {
    cns11643Enabled = !cns11643Enabled
    mgrLangModel.setCNSEnabled(cns11643Enabled)  // ?????????
    UserDefaults.standard.set(cns11643Enabled, forKey: UserDef.kCNS11643Enabled)
    return cns11643Enabled
  }

  @UserDefault(key: UserDef.kSymbolInputEnabled, defaultValue: true)
  static var symbolInputEnabled: Bool

  static func toggleSymbolInputEnabled() -> Bool {
    symbolInputEnabled = !symbolInputEnabled
    mgrLangModel.setSymbolEnabled(symbolInputEnabled)  // ?????????
    UserDefaults.standard.set(symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled)
    return symbolInputEnabled
  }

  @UserDefault(key: UserDef.kChineseConversionEnabled, defaultValue: false)
  static var chineseConversionEnabled: Bool

  @discardableResult static func toggleChineseConversionEnabled() -> Bool {
    chineseConversionEnabled = !chineseConversionEnabled
    // ??????????????? JIS ?????????????????????????????????????????????????????????????????????
    if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
      toggleShiftJISShinjitaiOutputEnabled()
      UserDefaults.standard.set(
        shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled
      )
    }
    UserDefaults.standard.set(chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled)
    return chineseConversionEnabled
  }

  @UserDefault(key: UserDef.kShiftJISShinjitaiOutputEnabled, defaultValue: false)
  static var shiftJISShinjitaiOutputEnabled: Bool

  @discardableResult static func toggleShiftJISShinjitaiOutputEnabled() -> Bool {
    shiftJISShinjitaiOutputEnabled = !shiftJISShinjitaiOutputEnabled
    // ??????????????? JIS ?????????????????????????????????????????????????????????????????????
    if shiftJISShinjitaiOutputEnabled, chineseConversionEnabled {
      toggleChineseConversionEnabled()
    }
    UserDefaults.standard.set(
      shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled
    )
    return shiftJISShinjitaiOutputEnabled
  }

  @UserDefault(key: UserDef.kCurrencyNumeralsEnabled, defaultValue: false)
  static var currencyNumeralsEnabled: Bool

  static func toggleCurrencyNumeralsEnabled() -> Bool {
    currencyNumeralsEnabled = !currencyNumeralsEnabled
    return currencyNumeralsEnabled
  }

  @UserDefault(key: UserDef.kHalfWidthPunctuationEnabled, defaultValue: false)
  static var halfWidthPunctuationEnabled: Bool

  static func toggleHalfWidthPunctuationEnabled() -> Bool {
    halfWidthPunctuationEnabled = !halfWidthPunctuationEnabled
    return halfWidthPunctuationEnabled
  }

  @UserDefault(key: UserDef.kEscToCleanInputBuffer, defaultValue: true)
  static var escToCleanInputBuffer: Bool

  @UserDefault(key: UserDef.kSpecifyShiftTabKeyBehavior, defaultValue: false)
  static var specifyShiftTabKeyBehavior: Bool

  @UserDefault(key: UserDef.kSpecifyShiftSpaceKeyBehavior, defaultValue: false)
  static var specifyShiftSpaceKeyBehavior: Bool

  // MARK: - Optional settings

  @UserDefault(key: UserDef.kCandidateTextFontName, defaultValue: nil)
  static var candidateTextFontName: String?

  @UserDefault(key: UserDef.kCandidateKeyLabelFontName, defaultValue: nil)
  static var candidateKeyLabelFontName: String?

  @UserDefault(key: UserDef.kCandidateKeys, defaultValue: kDefaultKeys)
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

  @UserDefault(key: UserDef.kPhraseReplacementEnabled, defaultValue: false)
  static var phraseReplacementEnabled: Bool

  static func togglePhraseReplacementEnabled() -> Bool {
    phraseReplacementEnabled = !phraseReplacementEnabled
    mgrLangModel.setPhraseReplacementEnabled(phraseReplacementEnabled)
    UserDefaults.standard.set(phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled)
    return phraseReplacementEnabled
  }

  @UserDefault(key: UserDef.kAssociatedPhrasesEnabled, defaultValue: false)
  static var associatedPhrasesEnabled: Bool

  static func toggleAssociatedPhrasesEnabled() -> Bool {
    associatedPhrasesEnabled = !associatedPhrasesEnabled
    UserDefaults.standard.set(associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled)
    return associatedPhrasesEnabled
  }

  // MARK: - Keyboard HotKey Enable / Disable

  @UserDefault(key: UserDef.kUsingHotKeySCPC, defaultValue: true)
  static var usingHotKeySCPC: Bool

  @UserDefault(key: UserDef.kUsingHotKeyAssociates, defaultValue: true)
  static var usingHotKeyAssociates: Bool

  @UserDefault(key: UserDef.kUsingHotKeyCNS, defaultValue: true)
  static var usingHotKeyCNS: Bool

  @UserDefault(key: UserDef.kUsingHotKeyKangXi, defaultValue: true)
  static var usingHotKeyKangXi: Bool

  @UserDefault(key: UserDef.kUsingHotKeyJIS, defaultValue: true)
  static var usingHotKeyJIS: Bool

  @UserDefault(key: UserDef.kUsingHotKeyHalfWidthASCII, defaultValue: true)
  static var usingHotKeyHalfWidthASCII: Bool

  @UserDefault(key: UserDef.kUsingHotKeyCurrencyNumerals, defaultValue: true)
  static var usingHotKeyCurrencyNumerals: Bool
}

// MARK: Snapshot Extension

var snapshot: [String: Any]?

extension mgrPrefs {
  static var allKeys: [String] {
    [
      UserDef.kIsDebugModeEnabled, UserDef.kMostRecentInputMode, UserDef.kUserDataFolderSpecified,
      UserDef.kCheckUpdateAutomatically, UserDef.kMandarinParser, UserDef.kBasicKeyboardLayout,
      UserDef.kShowPageButtonsInCandidateWindow, UserDef.kCandidateListTextSize, UserDef.kAppleLanguages,
      UserDef.kShouldAutoReloadUserDataFiles, UserDef.kuseRearCursorMode, UserDef.kUseHorizontalCandidateList,
      UserDef.kComposingBufferSize, UserDef.kChooseCandidateUsingSpace, UserDef.kCNS11643Enabled,
      UserDef.kSymbolInputEnabled, UserDef.kChineseConversionEnabled, UserDef.kShiftJISShinjitaiOutputEnabled,
      UserDef.kHalfWidthPunctuationEnabled, UserDef.kMoveCursorAfterSelectingCandidate, UserDef.kEscToCleanInputBuffer,
      UserDef.kSpecifyShiftTabKeyBehavior, UserDef.kSpecifyShiftSpaceKeyBehavior,
      UserDef.kAllowBoostingSingleKanjiAsUserPhrase, UserDef.kUseSCPCTypingMode, UserDef.kMaxCandidateLength,
      UserDef.kShouldNotFartInLieuOfBeep, UserDef.kShowHanyuPinyinInCompositionBuffer,
      UserDef.kInlineDumpPinyinInLieuOfZhuyin, UserDef.kFetchSuggestionsFromUserOverrideModel,
      UserDef.kCandidateTextFontName, UserDef.kCandidateKeyLabelFontName, UserDef.kCandidateKeys,
      UserDef.kAssociatedPhrasesEnabled, UserDef.kPhraseReplacementEnabled, UserDef.kUsingHotKeySCPC,
      UserDef.kUsingHotKeyAssociates, UserDef.kUsingHotKeyCNS, UserDef.kUsingHotKeyKangXi, UserDef.kUsingHotKeyJIS,
      UserDef.kUsingHotKeyHalfWidthASCII, UserDef.kUseFixecCandidateOrderOnSelection,
      UserDef.kAutoCorrectReadingCombination, UserDef.kAlsoConfirmAssociatedCandidatesByEnter,
      UserDef.kCurrencyNumeralsEnabled, UserDef.kUsingHotKeyCurrencyNumerals,
    ]
  }

  func reset() {
    mgrPrefs.allKeys.forEach {
      UserDefaults.standard.removeObject(forKey: $0)
    }
  }

  func makeSnapshot() -> [String: Any] {
    var dict = [String: Any]()
    mgrPrefs.allKeys.forEach {
      dict[$0] = UserDefaults.standard.object(forKey: $0)
    }
    return dict
  }

  func restore(from snapshot: [String: Any]) {
    mgrPrefs.allKeys.forEach {
      UserDefaults.standard.set(snapshot[$0], forKey: $0)
    }
  }
}
