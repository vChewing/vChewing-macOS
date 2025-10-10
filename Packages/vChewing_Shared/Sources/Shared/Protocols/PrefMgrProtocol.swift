// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

public protocol PrefMgrProtocol {
  var isDebugModeEnabled: Bool { get set }
  var failureFlagForPOMObservation: Bool { get set }
  var candidateServiceMenuContents: [String] { get set }
  var respectClientAccentColor: Bool { get set }
  var alwaysUsePCBWithElectronBasedClients: Bool { get set }
  var securityHardenedCompositionBuffer: Bool { get set }
  var checkAbusersOfSecureEventInputAPI: Bool { get set }
  var deltaOfCalendarYears: Int { get set }
  var mostRecentInputMode: String { get set }
  var useExternalFactoryDict: Bool { get set }
  var checkUpdateAutomatically: Bool { get set }
  var cassettePath: String { get set }
  var userDataFolderSpecified: String { get set }
  var appleLanguages: [String] { get set }
  var keyboardParser: Int { get set }
  var basicKeyboardLayout: String { get set }
  var alphanumericalKeyboardLayout: String { get set }
  var showNotificationsWhenTogglingCapsLock: Bool { get set }
  var candidateListTextSize: Double { get set }
  var alwaysExpandCandidateWindow: Bool { get set }
  var candidateWindowShowOnlyOneLine: Bool { get set }
  var shouldAutoReloadUserDataFiles: Bool { get set }
  var useRearCursorMode: Bool { get set }
  var useHLtoMoveCompositorCursorInCandidateState: Bool { get set }
  var useJKtoMoveCompositorCursorInCandidateState: Bool { get set }
  var useShiftQuestionToCallServiceMenu: Bool { get set }
  var cursorPlacementAfterSelectingCandidate: Int { get set }
  var dodgeInvalidEdgeCandidateCursorPosition: Bool { get set }
  var useDynamicCandidateWindowOrigin: Bool { get set }
  var useHorizontalCandidateList: Bool { get set }
  var minCellWidthForHorizontalMatrix: Int { get set }
  var chooseCandidateUsingSpace: Bool { get set }
  var allowBoostingSingleKanjiAsUserPhrase: Bool { get set }
  var fetchSuggestionsFromPerceptionOverrideModel: Bool { get set }
  var useFixedCandidateOrderOnSelection: Bool { get set }
  var autoCorrectReadingCombination: Bool { get set }
  var readingNarrationCoverage: Int { get set }
  var alsoConfirmAssociatedCandidatesByEnter: Bool { get set }
  var keepReadingUponCompositionError: Bool { get set }
  var upperCaseLetterKeyBehavior: Int { get set }
  var numPadCharInputBehavior: Int { get set }
  var shiftEisuToggleOffTogetherWithCapsLock: Bool { get set }
  var bypassNonAppleCapsLockHandling: Bool { get set }
  var togglingAlphanumericalModeWithLShift: Bool { get set }
  var togglingAlphanumericalModeWithRShift: Bool { get set }
  var consolidateContextOnCandidateSelection: Bool { get set }
  var hardenVerticalPunctuations: Bool { get set }
  var trimUnfinishedReadingsOnCommit: Bool { get set }
  var alwaysShowTooltipTextsHorizontally: Bool { get set }
  var clientsIMKTextInputIncapable: [String: Bool] { get set }
  var useSpaceToCommitHighlightedSCPCCandidate: Bool { get set }
  var enableMouseScrollingForTDKCandidatesCocoa: Bool { get set }
  var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool { get set }
  var maxCandidateLength: Int { get set }
  var beepSoundPreference: Int { get set }
  var shouldNotFartInLieuOfBeep: Bool { get set }
  var showHanyuPinyinInCompositionBuffer: Bool { get set }
  var inlineDumpPinyinInLieuOfZhuyin: Bool { get set }
  var showTranslatedStrokesInCompositionBuffer: Bool { get set }
  var forceCassetteChineseConversion: Int { get set }
  var showReverseLookupInCandidateUI: Bool { get set }
  var showCodePointInCandidateUI: Bool { get set }
  var autoCompositeWithLongestPossibleCassetteKey: Bool { get set }
  var shareAlphanumericalModeStatusAcrossClients: Bool { get set }
  var phraseEditorAutoReloadExternalModifications: Bool { get set }
  var classicHaninKeyboardSymbolModeShortcutEnabled: Bool { get set }
  var filterNonCNSReadingsForCHTInput: Bool { get set }
  var cns11643Enabled: Bool { get set }
  var cassetteEnabled: Bool { get set }
  var symbolInputEnabled: Bool { get set }
  var chineseConversionEnabled: Bool { get set }
  var shiftJISShinjitaiOutputEnabled: Bool { get set }
  var currencyNumeralsEnabled: Bool { get set }
  var halfWidthPunctuationEnabled: Bool { get set }
  var escToCleanInputBuffer: Bool { get set }
  var acceptLeadingIntonations: Bool { get set }
  var specifyIntonationKeyBehavior: Int { get set }
  var specifyShiftBackSpaceKeyBehavior: Int { get set }
  var specifyShiftTabKeyBehavior: Bool { get set }
  var specifyShiftSpaceKeyBehavior: Bool { get set }
  var specifyCmdOptCtrlEnterBehavior: Int { get set }
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
  var usingHotKeyRevLookup: Bool { get set }
  var usingHotKeyInputMode: Bool { get set }
}
