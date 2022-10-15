// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public protocol PrefMgrProtocol {
  var isDebugModeEnabled: Bool { get set }
  var failureFlagForUOMObservation: Bool { get set }
  var deltaOfCalendarYears: Int { get set }
  var mostRecentInputMode: String { get set }
  var checkUpdateAutomatically: Bool { get set }
  var cassettePath: String { get set }
  var userDataFolderSpecified: String { get set }
  var appleLanguages: [String] { get set }
  var keyboardParser: Int { get set }
  var basicKeyboardLayout: String { get set }
  var alphanumericalKeyboardLayout: String { get set }
  var showNotificationsWhenTogglingCapsLock: Bool { get set }
  var candidateListTextSize: Double { get set }
  var shouldAutoReloadUserDataFiles: Bool { get set }
  var useRearCursorMode: Bool { get set }
  var moveCursorAfterSelectingCandidate: Bool { get set }
  var useHorizontalCandidateList: Bool { get set }
  var chooseCandidateUsingSpace: Bool { get set }
  var allowBoostingSingleKanjiAsUserPhrase: Bool { get set }
  var fetchSuggestionsFromUserOverrideModel: Bool { get set }
  var useFixecCandidateOrderOnSelection: Bool { get set }
  var autoCorrectReadingCombination: Bool { get set }
  var alsoConfirmAssociatedCandidatesByEnter: Bool { get set }
  var keepReadingUponCompositionError: Bool { get set }
  var upperCaseLetterKeyBehavior: Int { get set }
  var togglingAlphanumericalModeWithLShift: Bool { get set }
  var disableShiftTogglingAlphanumericalMode: Bool { get set }
  var consolidateContextOnCandidateSelection: Bool { get set }
  var hardenVerticalPunctuations: Bool { get set }
  var trimUnfinishedReadingsOnCommit: Bool { get set }
  var alwaysShowTooltipTextsHorizontally: Bool { get set }
  var clientsIMKTextInputIncapable: [String] { get set }
  var onlyLoadFactoryLangModelsIfNeeded: Bool { get set }
  var useIMKCandidateWindow: Bool { get set }
  var handleDefaultCandidateFontsByLangIdentifier: Bool { get set }
  var shiftKeyAccommodationBehavior: Int { get set }
  var maxCandidateLength: Int { get set }
  var shouldNotFartInLieuOfBeep: Bool { get set }
  var showHanyuPinyinInCompositionBuffer: Bool { get set }
  var inlineDumpPinyinInLieuOfZhuyin: Bool { get set }
  var showTranslatedStrokesInCompositionBuffer: Bool { get set }
  var forceCassetteChineseConversion: Int { get set }
  var cns11643Enabled: Bool { get set }
  var cassetteEnabled: Bool { get set }
  var symbolInputEnabled: Bool { get set }
  var chineseConversionEnabled: Bool { get set }
  var shiftJISShinjitaiOutputEnabled: Bool { get set }
  var currencyNumeralsEnabled: Bool { get set }
  var halfWidthPunctuationEnabled: Bool { get set }
  var escToCleanInputBuffer: Bool { get set }
  var specifyIntonationKeyBehavior: Int { get set }
  var specifyShiftBackSpaceKeyBehavior: Int { get set }
  var specifyShiftTabKeyBehavior: Bool { get set }
  var specifyShiftSpaceKeyBehavior: Bool { get set }
  var candidateTextFontName: String { get set }
  var candidateKeys: String { get set }
  var useSCPCTypingMode: Bool { get set }
  var phraseReplacementEnabled: Bool { get set }
  var associatedPhrasesEnabled: Bool { get set }
  var usingHotKeySCPC: Bool { get set }
  var usingHotKeyAssociates: Bool { get set }
  var usingHotKeyCNS: Bool { get set }
  var usingHotKeyKangXi: Bool { get set }
  var usingHotKeyJIS: Bool { get set }
  var usingHotKeyHalfWidthASCII: Bool { get set }
  var usingHotKeyCurrencyNumerals: Bool { get set }
  var usingHotKeyCassette: Bool { get set }
}
