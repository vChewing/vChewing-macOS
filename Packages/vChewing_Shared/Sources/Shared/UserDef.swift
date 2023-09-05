// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - UserDef

public enum UserDef: String, CaseIterable {
  public enum DataType: CaseIterable {
    case string, bool, integer, double, array, dictionary, other
  }

  public struct MetaData {
    public var userDef: UserDef
    public var shortTitle: String?
    public var control: AnyObject?
    public var prompt: String?
    public var popupPrompt: String?
    public var description: String?
    public var minimumOS: Double?
    public var options: [Int: String]?
    public var toolTip: String?
  }

  // MARK: - Cases.

  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForUOMObservation = "_FailureFlag_UOMObservation"
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
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAlwaysExpandCandidateWindow = "AlwaysExpandCandidateWindow"
  case kCandidateWindowShowOnlyOneLine = "CandidateWindowShowOnlyOneLine"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "UseRearCursorMode"
  case kUseDynamicCandidateWindowOrigin = "UseDynamicCandidateWindowOrigin"
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
  case kAcceptLeadingIntonations = "AcceptLeadingIntonations"
  case kSpecifyIntonationKeyBehavior = "SpecifyIntonationKeyBehavior"
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
  case kUseFixedCandidateOrderOnSelection = "UseFixedCandidateOrderOnSelection"
  case kAutoCorrectReadingCombination = "AutoCorrectReadingCombination"
  case kAlsoConfirmAssociatedCandidatesByEnter = "AlsoConfirmAssociatedCandidatesByEnter"
  case kKeepReadingUponCompositionError = "KeepReadingUponCompositionError"
  case kTogglingAlphanumericalModeWithLShift = "TogglingAlphanumericalModeWithLShift"
  case kTogglingAlphanumericalModeWithRShift = "TogglingAlphanumericalModeWithRShift"
  case kUpperCaseLetterKeyBehavior = "UpperCaseLetterKeyBehavior"
  case kConsolidateContextOnCandidateSelection = "ConsolidateContextOnCandidateSelection"
  case kHardenVerticalPunctuations = "HardenVerticalPunctuations"
  case kTrimUnfinishedReadingsOnCommit = "TrimUnfinishedReadingsOnCommit"
  case kAlwaysShowTooltipTextsHorizontally = "AlwaysShowTooltipTextsHorizontally"
  case kClientsIMKTextInputIncapable = "ClientsIMKTextInputIncapable"
  case kOnlyLoadFactoryLangModelsIfNeeded = "OnlyLoadFactoryLangModelsIfNeeded"
  case kShowTranslatedStrokesInCompositionBuffer = "ShowTranslatedStrokesInCompositionBuffer"
  case kForceCassetteChineseConversion = "ForceCassetteChineseConversion"
  case kShowReverseLookupInCandidateUI = "ShowReverseLookupInCandidateUI"
  case kAutoCompositeWithLongestPossibleCassetteKey = "AutoCompositeWithLongestPossibleCassetteKey"
  case kShareAlphanumericalModeStatusAcrossClients = "ShareAlphanumericalModeStatusAcrossClients"
  case kPhraseEditorAutoReloadExternalModifications = "PhraseEditorAutoReloadExternalModifications"
  case kClassicHaninKeyboardSymbolModeShortcutEnabled = "ClassicHaninKeyboardSymbolModeShortcutEnabled"

  case kUseSpaceToCommitHighlightedSCPCCandidate = "UseSpaceToCommitHighlightedSCPCCandidate"
  case kEnableSwiftUIForTDKCandidates = "EnableSwiftUIForTDKCandidates"
  case kEnableMouseScrollingForTDKCandidatesCocoa = "EnableMouseScrollingForTDKCandidatesCocoa"
  case kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
    = "DisableSegmentedThickUnderlineInMarkingModeForManagedClients"

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
  case kUsingHotKeyRevLookup = "UsingHotKeyRevLookup"
  case kUsingHotKeyInputMode = "UsingHotKeyInputMode"

  // MARK: - SnapShot-Related Methods.

  public static func resetAll() {
    UserDef.allCases.forEach {
      UserDefaults.current.removeObject(forKey: $0.rawValue)
    }
  }

  public static func load(from snapshot: Snapshot) {
    let data = snapshot.data
    guard !data.isEmpty else { return }
    UserDef.allCases.forEach {
      UserDefaults.current.set(data[$0.rawValue], forKey: $0.rawValue)
    }
  }

  public struct Snapshot {
    public var data: [String: Any] = [:]
    public init() {
      UserDef.allCases.forEach {
        data[$0.rawValue] = UserDefaults.current.object(forKey: $0.rawValue)
      }
    }
  }
}

public extension UserDef {
  var dataType: DataType {
    switch self {
    case .kIsDebugModeEnabled: return .bool
    case .kFailureFlagForUOMObservation: return .bool
    case .kDeltaOfCalendarYears: return .integer
    case .kMostRecentInputMode: return .string
    case .kCassettePath: return .string
    case .kUserDataFolderSpecified: return .string
    case .kCheckUpdateAutomatically: return .bool
    case .kUseExternalFactoryDict: return .bool
    case .kKeyboardParser: return .integer
    case .kBasicKeyboardLayout: return .string
    case .kAlphanumericalKeyboardLayout: return .string
    case .kShowNotificationsWhenTogglingCapsLock: return .bool
    case .kCandidateListTextSize: return .double
    case .kAlwaysExpandCandidateWindow: return .bool
    case .kCandidateWindowShowOnlyOneLine: return .bool
    case .kAppleLanguages: return .array
    case .kShouldAutoReloadUserDataFiles: return .bool
    case .kUseRearCursorMode: return .bool
    case .kUseDynamicCandidateWindowOrigin: return .bool
    case .kUseHorizontalCandidateList: return .bool
    case .kChooseCandidateUsingSpace: return .bool
    case .kCassetteEnabled: return .bool
    case .kCNS11643Enabled: return .bool
    case .kSymbolInputEnabled: return .bool
    case .kChineseConversionEnabled: return .bool
    case .kShiftJISShinjitaiOutputEnabled: return .bool
    case .kCurrencyNumeralsEnabled: return .bool
    case .kHalfWidthPunctuationEnabled: return .bool
    case .kMoveCursorAfterSelectingCandidate: return .bool
    case .kEscToCleanInputBuffer: return .bool
    case .kAcceptLeadingIntonations: return .bool
    case .kSpecifyIntonationKeyBehavior: return .integer
    case .kSpecifyShiftBackSpaceKeyBehavior: return .integer
    case .kSpecifyShiftTabKeyBehavior: return .bool
    case .kSpecifyShiftSpaceKeyBehavior: return .bool
    case .kAllowBoostingSingleKanjiAsUserPhrase: return .bool
    case .kUseSCPCTypingMode: return .bool
    case .kMaxCandidateLength: return .integer
    case .kShouldNotFartInLieuOfBeep: return .bool
    case .kShowHanyuPinyinInCompositionBuffer: return .bool
    case .kInlineDumpPinyinInLieuOfZhuyin: return .bool
    case .kFetchSuggestionsFromUserOverrideModel: return .bool
    case .kUseFixedCandidateOrderOnSelection: return .bool
    case .kAutoCorrectReadingCombination: return .bool
    case .kAlsoConfirmAssociatedCandidatesByEnter: return .bool
    case .kKeepReadingUponCompositionError: return .bool
    case .kTogglingAlphanumericalModeWithLShift: return .bool
    case .kTogglingAlphanumericalModeWithRShift: return .bool
    case .kUpperCaseLetterKeyBehavior: return .integer
    case .kConsolidateContextOnCandidateSelection: return .bool
    case .kHardenVerticalPunctuations: return .bool
    case .kTrimUnfinishedReadingsOnCommit: return .bool
    case .kAlwaysShowTooltipTextsHorizontally: return .bool
    case .kClientsIMKTextInputIncapable: return .dictionary
    case .kOnlyLoadFactoryLangModelsIfNeeded: return .bool
    case .kShowTranslatedStrokesInCompositionBuffer: return .bool
    case .kForceCassetteChineseConversion: return .integer
    case .kShowReverseLookupInCandidateUI: return .bool
    case .kAutoCompositeWithLongestPossibleCassetteKey: return .bool
    case .kShareAlphanumericalModeStatusAcrossClients: return .bool
    case .kPhraseEditorAutoReloadExternalModifications: return .bool
    case .kClassicHaninKeyboardSymbolModeShortcutEnabled: return .bool
    case .kUseSpaceToCommitHighlightedSCPCCandidate: return .bool
    case .kEnableSwiftUIForTDKCandidates: return .bool
    case .kEnableMouseScrollingForTDKCandidatesCocoa: return .bool
    case .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients: return .bool
    case .kCandidateTextFontName: return .string
    case .kCandidateKeys: return .string
    case .kAssociatedPhrasesEnabled: return .bool
    case .kPhraseReplacementEnabled: return .bool
    case .kUsingHotKeySCPC: return .bool
    case .kUsingHotKeyAssociates: return .bool
    case .kUsingHotKeyCNS: return .bool
    case .kUsingHotKeyKangXi: return .bool
    case .kUsingHotKeyJIS: return .bool
    case .kUsingHotKeyHalfWidthASCII: return .bool
    case .kUsingHotKeyCurrencyNumerals: return .bool
    case .kUsingHotKeyCassette: return .bool
    case .kUsingHotKeyRevLookup: return .bool
    case .kUsingHotKeyInputMode: return .bool
    }
  }
}

public extension UserDef {
  var metaData: MetaData? {
    switch self {
    case .kIsDebugModeEnabled: return .init(userDef: self, shortTitle: "Debug Mode")
    case .kFailureFlagForUOMObservation: return nil
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
        prompt: "Read external factory dictionary files if possible"
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
        userDef: self, shortTitle: "Show notifications when toggling Caps Lock", minimumOS: 12
      )
    case .kCandidateListTextSize: return .init(
        userDef: self, shortTitle: "Candidate Size:", description: "Choose candidate font size for better visual clarity."
      )
    case .kAlwaysExpandCandidateWindow: return .init(userDef: self, shortTitle: "Always expand candidate window panel")
    case .kCandidateWindowShowOnlyOneLine: return .init(userDef: self, shortTitle: "Use only one row / column in candidate window")
    case .kAppleLanguages: return .init(
        userDef: self, shortTitle: "UI Language:",
        description: "Change user interface language (will reboot the IME)."
      )
    case .kShouldAutoReloadUserDataFiles: return .init(userDef: self, shortTitle: "Automatically reload user data files if changes detected")
    case .kUseRearCursorMode: return .init(
        userDef: self, shortTitle: "Cursor Selection:",
        description: "Choose the cursor position where you want to list possible candidates.",
        options: [
          0: "in front of the phrase (like macOS built-in Zhuyin IME)",
          1: "at the rear of the phrase (like Microsoft New Phonetic)",
        ]
      )
    case .kUseDynamicCandidateWindowOrigin: return .init(
        userDef: self, shortTitle: "Adjust candidate window location according to current node length"
      )
    case .kUseHorizontalCandidateList: return .init(
        userDef: self, shortTitle: "Candidate Layout:",
        description: "Choose your preferred layout of the candidate window.",
        options: [0: "Vertical", 1: "Horizontal"]
      )
    case .kChooseCandidateUsingSpace: return .init(
        userDef: self, shortTitle: "Enable Space key for calling candidate window",
        description: "If disabled, this will insert space instead."
      )
    case .kCassetteEnabled: return .init(
        userDef: self, shortTitle: "Enable cassette mode, suppressing phonabet input",
        description: "Cassette mode is similar to the CIN support of the Yahoo Kimo IME, allowing users to use their own CIN tables to implement their stroked-based input schema (e.g. Wubi, Cangjie, Boshiamy, etc.) as a plan-B in vChewing IME. However, since vChewing won't compromise its phonabet input mode experience for this cassette mode, users might not feel comfortable enough comparing to their experiences with RIME (recommended) or OpenVanilla (deprecated)."
      )
    case .kCNS11643Enabled: return .init(userDef: self, shortTitle: "Enable CNS11643 Support (2023-05-19)")
    case .kSymbolInputEnabled: return .init(
        userDef: self, shortTitle: "Enable symbol input support (incl. certain emoji symbols)"
      )
    case .kChineseConversionEnabled: return .init(
        userDef: self, shortTitle: "Auto-convert traditional Chinese glyphs to KangXi characters"
      )
    case .kShiftJISShinjitaiOutputEnabled: return .init(
        userDef: self, shortTitle: "Auto-convert traditional Chinese glyphs to JIS Shinjitai characters"
      )
    case .kCurrencyNumeralsEnabled: return .init(userDef: self, shortTitle: "Enable currency numerals output")
    case .kHalfWidthPunctuationEnabled: return .init(userDef: self, shortTitle: "Enable half-width punctuations")
    case .kMoveCursorAfterSelectingCandidate: return .init(
        userDef: self, shortTitle: "Push the cursor in front of the phrase after selection"
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
    case .kAllowBoostingSingleKanjiAsUserPhrase: return .init(
        userDef: self, shortTitle: "Allow boosting / excluding a candidate of single kanji when marking",
        description: "⚠︎ This may hinder the walking algorithm from giving appropriate results."
      )
    case .kUseSCPCTypingMode: return .init(
        userDef: self, shortTitle: "Emulating select-candidate-per-character mode",
        description: "An accommodation for elder computer users."
      )
    case .kMaxCandidateLength: return nil
    case .kShouldNotFartInLieuOfBeep: return .init(
        userDef: self, shortTitle: "Stop farting (when typed phonetic combination is invalid, etc.)",
        description: "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas."
      )
    case .kShowHanyuPinyinInCompositionBuffer: return .init(
        userDef: self, shortTitle: "Show Hanyu-Pinyin in the inline composition buffer"
      )
    case .kInlineDumpPinyinInLieuOfZhuyin: return .init(
        userDef: self, shortTitle: "Commit Hanyu-Pinyin instead on Ctrl(+Option)+Command+Enter"
      )
    case .kFetchSuggestionsFromUserOverrideModel: return .init(
        userDef: self, shortTitle: "Applying typing suggestions from half-life user override model",
        description: "The user override model only possesses memories temporarily. Each memory record gradually becomes ineffective within approximately less than 6 days. You can erase all memory records through the input method menu."
      )
    case .kUseFixedCandidateOrderOnSelection: return .init(
        userDef: self, shortTitle: "Always use fixed listing order in candidate window",
        description: "This will stop user override model from affecting how candidates get sorted."
      )
    case .kAutoCorrectReadingCombination: return .init(userDef: self, shortTitle: "Automatically correct reading combinations when typing")
    case .kAlsoConfirmAssociatedCandidatesByEnter: return .init(
        userDef: self, shortTitle: "Allow using Enter key to confirm associated candidate selection",
        description: "Otherwise, only the candidate keys are allowed to confirm associates."
      )
    case .kKeepReadingUponCompositionError: return .init(userDef: self, shortTitle: "Allow backspace-editing miscomposed readings")
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
    case .kConsolidateContextOnCandidateSelection: return .init(
        userDef: self, shortTitle: "Consolidate the context on confirming candidate selection",
        description: "For example: When typing “章太炎” and you want to override the “太” with “泰”, and the raw operation index range [1,2) which bounds are cutting the current node “章太炎” in range [0,3). If having lack of the pre-consolidation process, this word will become something like “張泰言” after the candidate selection. Only if we enable this consolidation, this word will become “章泰炎” which is the expected result that the context is kept as-is."
      )
    case .kHardenVerticalPunctuations: return .init(
        userDef: self, shortTitle: "Harden vertical punctuations during vertical typing (not recommended)",
        description: "⚠︎ This feature is useful ONLY WHEN the font you are using doesn't support dynamic vertical punctuations. However, typed vertical punctuations will always shown as vertical punctuations EVEN IF your editor has changed the typing direction to horizontal."
      )
    case .kTrimUnfinishedReadingsOnCommit: return .init(userDef: self, shortTitle: "Trim unfinished readings / strokes on commit")
    case .kAlwaysShowTooltipTextsHorizontally: return .init(userDef: self, shortTitle: "Always show tooltip texts horizontally")
    case .kClientsIMKTextInputIncapable: return nil
    case .kOnlyLoadFactoryLangModelsIfNeeded: return .init(userDef: self, shortTitle: "Only load factory language models if needed")
    case .kShowTranslatedStrokesInCompositionBuffer: return .init(userDef: self, shortTitle: "Show translated strokes in composition buffer")
    case .kForceCassetteChineseConversion: return .init(
        userDef: self,
        shortTitle: "Chinese conversion for cassette module",
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
    case .kAutoCompositeWithLongestPossibleCassetteKey: return .init(
        userDef: self, shortTitle: "Auto-composite when the longest possible key is formed"
      )
    case .kShareAlphanumericalModeStatusAcrossClients: return .init(
        userDef: self, shortTitle: "Share alphanumerical mode status across all clients"
      )
    case .kPhraseEditorAutoReloadExternalModifications: return .init(
        userDef: self, shortTitle: "This editor only: Auto-reload modifications happened outside of this editor"
      )
    case .kClassicHaninKeyboardSymbolModeShortcutEnabled: return .init(
        userDef: self, shortTitle: "Also use “\\” or “¥” key for Hanin Keyboard Symbol Input"
      )
    case .kUseSpaceToCommitHighlightedSCPCCandidate: return .init(
        userDef: self, shortTitle: "Use Space to confirm highlighted candidate in Per-Char Select Mode"
      )
    case .kEnableSwiftUIForTDKCandidates: return .init(
        userDef: self, shortTitle: "Enable experimental Swift UI typesetting method",
        description: "By checking this, Tadokoro Candidate Window will use SwiftUI. SwiftUI was being used in vChewing 3.3.8 and before. However, SwiftUI has unacceptable responsiveness & latency & efficiency problems in rendering the candidate panel UI. That's why a refactored version has been introduced since vChewing 3.3.9 using Cocoa, providing an optimized user experience with blasing-fast operation responsiveness, plus experimental mouse-wheel support.",
        minimumOS: 10.15
      )
    case .kEnableMouseScrollingForTDKCandidatesCocoa: return .init(
        userDef: self, shortTitle: "Enable mouse wheel support for Tadokoro Candidate Window"
      )
    case .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients: return .init(
        userDef: self, shortTitle: "Disable segmented thick underline in marking mode for managed clients",
        description: "Some clients with web-based front UI may have issues rendering segmented thick underlines drawn by their implemented “setMarkedText()”. This option stops the input method from delivering segmented thick underlines to “client().setMarkedText()”. Note that segmented thick underlines are only used in marking mode, unless the client itself misimplements the IMKTextInput method “setMarkedText()”. This option only affects the inline composition buffer."
      )
    case .kCandidateTextFontName: return nil
    case .kCandidateKeys: return .init(userDef: self, shortTitle: "Selection Keys:", prompt: "Choose or hit Enter to confim your prefered keys for selecting candidates.", description: "This will also affect the row / column capacity of the candidate window.")
    case .kAssociatedPhrasesEnabled: return nil
    case .kPhraseReplacementEnabled: return .init(
        userDef: self, shortTitle: "Enable phrase replacement table",
        description: "This will batch-replace specified candidates."
      )
    case .kUsingHotKeySCPC: return .init(userDef: self, shortTitle: "Per-Char Select Mode")
    case .kUsingHotKeyAssociates: return .init(userDef: self, shortTitle: "Per-Char Associated Phrases")
    case .kUsingHotKeyCNS: return .init(userDef: self, shortTitle: "CNS11643 Mode")
    case .kUsingHotKeyKangXi: return .init(userDef: self, shortTitle: "Force KangXi Writing")
    case .kUsingHotKeyJIS: return .init(userDef: self, shortTitle: "Reverse Lookup (Phonabets)")
    case .kUsingHotKeyHalfWidthASCII: return .init(userDef: self, shortTitle: "JIS Shinjitai Output")
    case .kUsingHotKeyCurrencyNumerals: return .init(userDef: self, shortTitle: "Half-Width Punctuation Mode")
    case .kUsingHotKeyCassette: return .init(userDef: self, shortTitle: "Currency Numeral Output")
    case .kUsingHotKeyRevLookup: return .init(userDef: self, shortTitle: "CIN Cassette Mode")
    case .kUsingHotKeyInputMode: return .init(userDef: self, shortTitle: "CHS / CHT Input Mode Switch")
    }
  }
}