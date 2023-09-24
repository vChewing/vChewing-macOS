// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftUI

@available(macOS 13, *)
public class PrefMgrObservable: NSObject, PrefMgrProtocol, ObservableObject {
  public static let sharedInstance = PrefMgrObservable()
  public static let kDefaultCandidateKeys = PrefMgr.kDefaultCandidateKeys
  public static let kDefaultBasicKeyboardLayout = PrefMgr.kDefaultBasicKeyboardLayout
  public static let kDefaultAlphanumericalKeyboardLayout = PrefMgr.kDefaultAlphanumericalKeyboardLayout
  public static let kDefaultClientsIMKTextInputIncapable: [String: Bool] = PrefMgr.kDefaultClientsIMKTextInputIncapable

  // MARK: - Settings (Tier 1)

  @AppStorage(wrappedValue: false, UserDef.kIsDebugModeEnabled.rawValue)
  public var isDebugModeEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kFailureFlagForUOMObservation.rawValue)
  public var failureFlagForUOMObservation: Bool

  @AppStorage(wrappedValue: false, UserDef.kSecurityHardenedCompositionBuffer.rawValue)
  public var securityHardenedCompositionBuffer: Bool

  @AppStorage(wrappedValue: -2000, UserDef.kDeltaOfCalendarYears.rawValue)
  public var deltaOfCalendarYears: Int

  @AppStorage(wrappedValue: "", UserDef.kMostRecentInputMode.rawValue)
  public var mostRecentInputMode: String

  @AppStorage(wrappedValue: false, UserDef.kCheckUpdateAutomatically.rawValue)
  public var checkUpdateAutomatically: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseExternalFactoryDict.rawValue)
  public var useExternalFactoryDict: Bool

  @AppStorage(wrappedValue: "", UserDef.kCassettePath.rawValue)
  public var cassettePath: String

  @AppStorage(wrappedValue: "", UserDef.kUserDataFolderSpecified.rawValue)
  public var userDataFolderSpecified: String

  public var appleLanguages: [String] {
    get { PrefMgr.shared.appleLanguages }
    set { PrefMgr.shared.appleLanguages = newValue }
  }

  @AppStorage(wrappedValue: 0, UserDef.kKeyboardParser.rawValue)
  public var keyboardParser: Int

  @AppStorage(wrappedValue: kDefaultBasicKeyboardLayout, UserDef.kBasicKeyboardLayout.rawValue)
  public var basicKeyboardLayout: String

  @AppStorage(wrappedValue: kDefaultAlphanumericalKeyboardLayout, UserDef.kAlphanumericalKeyboardLayout.rawValue)
  public var alphanumericalKeyboardLayout: String

  @AppStorage(wrappedValue: true, UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue)
  public var showNotificationsWhenTogglingCapsLock: Bool

  @AppStorage(wrappedValue: 16, UserDef.kCandidateListTextSize.rawValue)
  public var candidateListTextSize: Double {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(12 ... 196).contains(candidateListTextSize) {
        candidateListTextSize = max(12, min(candidateListTextSize, 196))
      }
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kAlwaysExpandCandidateWindow.rawValue)
  public var alwaysExpandCandidateWindow: Bool

  @AppStorage(wrappedValue: false, UserDef.kCandidateWindowShowOnlyOneLine.rawValue)
  public var candidateWindowShowOnlyOneLine: Bool

  @AppStorage(wrappedValue: true, UserDef.kShouldAutoReloadUserDataFiles.rawValue)
  public var shouldAutoReloadUserDataFiles: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseRearCursorMode.rawValue)
  public var useRearCursorMode: Bool

  @AppStorage(wrappedValue: true, UserDef.kMoveCursorAfterSelectingCandidate.rawValue)
  public var moveCursorAfterSelectingCandidate: Bool

  @AppStorage(wrappedValue: true, UserDef.kUseDynamicCandidateWindowOrigin.rawValue)
  public var useDynamicCandidateWindowOrigin: Bool

  @AppStorage(wrappedValue: true, UserDef.kUseHorizontalCandidateList.rawValue)
  public var useHorizontalCandidateList: Bool

  @AppStorage(wrappedValue: true, UserDef.kChooseCandidateUsingSpace.rawValue)
  public var chooseCandidateUsingSpace: Bool

  @AppStorage(wrappedValue: false, UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue)
  public var allowBoostingSingleKanjiAsUserPhrase: Bool

  @AppStorage(wrappedValue: true, UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue)
  public var fetchSuggestionsFromUserOverrideModel: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseFixedCandidateOrderOnSelection.rawValue)
  public var useFixedCandidateOrderOnSelection: Bool

  @AppStorage(wrappedValue: true, UserDef.kAutoCorrectReadingCombination.rawValue)
  public var autoCorrectReadingCombination: Bool

  @AppStorage(wrappedValue: false, UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue)
  public var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppStorage(wrappedValue: false, UserDef.kKeepReadingUponCompositionError.rawValue)
  public var keepReadingUponCompositionError: Bool

  @AppStorage(wrappedValue: 0, UserDef.kUpperCaseLetterKeyBehavior.rawValue)
  public var upperCaseLetterKeyBehavior: Int

  @AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithLShift.rawValue)
  public var togglingAlphanumericalModeWithLShift: Bool {
    didSet {
      SessionCtl.theShiftKeyDetector.toggleWithLShift = togglingAlphanumericalModeWithLShift
    }
  }

  @AppStorage(wrappedValue: true, UserDef.kTogglingAlphanumericalModeWithRShift.rawValue)
  public var togglingAlphanumericalModeWithRShift: Bool {
    didSet {
      SessionCtl.theShiftKeyDetector.toggleWithRShift = togglingAlphanumericalModeWithRShift
    }
  }

  @AppStorage(wrappedValue: true, UserDef.kConsolidateContextOnCandidateSelection.rawValue)
  public var consolidateContextOnCandidateSelection: Bool

  @AppStorage(wrappedValue: false, UserDef.kHardenVerticalPunctuations.rawValue)
  public var hardenVerticalPunctuations: Bool

  @AppStorage(wrappedValue: true, UserDef.kTrimUnfinishedReadingsOnCommit.rawValue)
  public var trimUnfinishedReadingsOnCommit: Bool

  @AppStorage(wrappedValue: false, UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue)
  public var alwaysShowTooltipTextsHorizontally: Bool

  public var clientsIMKTextInputIncapable: [String: Bool] {
    get { PrefMgr.shared.clientsIMKTextInputIncapable }
    set { PrefMgr.shared.clientsIMKTextInputIncapable = newValue }
  }

  @AppStorage(wrappedValue: true, UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue)
  public var onlyLoadFactoryLangModelsIfNeeded: Bool {
    didSet {
      if !onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
    }
  }

  @AppStorage(wrappedValue: true, UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue)
  public var showTranslatedStrokesInCompositionBuffer: Bool

  @AppStorage(wrappedValue: 0, UserDef.kForceCassetteChineseConversion.rawValue)
  public var forceCassetteChineseConversion: Int

  @AppStorage(wrappedValue: true, UserDef.kShowReverseLookupInCandidateUI.rawValue)
  public var showReverseLookupInCandidateUI: Bool

  @AppStorage(wrappedValue: true, UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue)
  public var autoCompositeWithLongestPossibleCassetteKey: Bool

  @AppStorage(wrappedValue: false, UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue)
  public var shareAlphanumericalModeStatusAcrossClients: Bool

  @AppStorage(wrappedValue: true, UserDef.kPhraseEditorAutoReloadExternalModifications.rawValue)
  public var phraseEditorAutoReloadExternalModifications: Bool

  @AppStorage(wrappedValue: false, UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue)
  public var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  // MARK: - Settings (Tier 2)

  @AppStorage(wrappedValue: true, UserDef.kUseSpaceToCommitHighlightedSCPCCandidate.rawValue)
  public var useSpaceToCommitHighlightedSCPCCandidate: Bool

  @AppStorage(wrappedValue: false, UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue)
  public var enableMouseScrollingForTDKCandidatesCocoa: Bool

  @AppStorage(wrappedValue: false, UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.rawValue)
  public var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  // MARK: - Settings (Tier 3)

  @AppStorage(wrappedValue: 10, UserDef.kMaxCandidateLength.rawValue)
  public var maxCandidateLength: Int

  @AppStorage(wrappedValue: true, UserDef.kShouldNotFartInLieuOfBeep.rawValue)
  public var shouldNotFartInLieuOfBeep: Bool

  @AppStorage(wrappedValue: false, UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue)
  public var showHanyuPinyinInCompositionBuffer: Bool

  @AppStorage(wrappedValue: false, UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue)
  public var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppStorage(wrappedValue: false, UserDef.kCNS11643Enabled.rawValue)
  public var cns11643Enabled: Bool {
    didSet {
      LMMgr.setCNSEnabled(cns11643Enabled) // 很重要
    }
  }

  @AppStorage(wrappedValue: true, UserDef.kSymbolInputEnabled.rawValue)
  public var symbolInputEnabled: Bool {
    didSet {
      LMMgr.setSymbolEnabled(symbolInputEnabled) // 很重要
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kCassetteEnabled.rawValue)
  public var cassetteEnabled: Bool {
    didSet {
      LMMgr.setCassetteEnabled(cassetteEnabled) // 很重要
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kChineseConversionEnabled.rawValue)
  public var chineseConversionEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
        shiftJISShinjitaiOutputEnabled.toggle()
        UserDefaults.current.set(
          shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
        )
      }
      UserDefaults.current.set(
        chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
      )
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kShiftJISShinjitaiOutputEnabled.rawValue)
  public var shiftJISShinjitaiOutputEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if shiftJISShinjitaiOutputEnabled, chineseConversionEnabled {
        chineseConversionEnabled.toggle()
        UserDefaults.current.set(
          chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
        )
      }
      UserDefaults.current.set(
        shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
      )
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kCurrencyNumeralsEnabled.rawValue)
  public var currencyNumeralsEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kHalfWidthPunctuationEnabled.rawValue)
  public var halfWidthPunctuationEnabled: Bool

  @AppStorage(wrappedValue: true, UserDef.kEscToCleanInputBuffer.rawValue)
  public var escToCleanInputBuffer: Bool

  @AppStorage(wrappedValue: true, UserDef.kAcceptLeadingIntonations.rawValue)
  public var acceptLeadingIntonations: Bool

  @AppStorage(wrappedValue: 0, UserDef.kSpecifyIntonationKeyBehavior.rawValue)
  public var specifyIntonationKeyBehavior: Int

  @AppStorage(wrappedValue: 0, UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue)
  public var specifyShiftBackSpaceKeyBehavior: Int

  @AppStorage(wrappedValue: false, UserDef.kSpecifyShiftTabKeyBehavior.rawValue)
  public var specifyShiftTabKeyBehavior: Bool

  @AppStorage(wrappedValue: false, UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue)
  public var specifyShiftSpaceKeyBehavior: Bool

  // MARK: - Optional settings

  @AppStorage(wrappedValue: "", UserDef.kCandidateTextFontName.rawValue)
  public var candidateTextFontName: String

  @AppStorage(wrappedValue: kDefaultCandidateKeys, UserDef.kCandidateKeys.rawValue)
  public var candidateKeys: String {
    didSet {
      let optimized = candidateKeys.lowercased().deduplicated
      if candidateKeys != optimized { candidateKeys = optimized }
      if CandidateKey.validate(keys: candidateKeys) != nil {
        candidateKeys = Self.kDefaultCandidateKeys
      }
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kUseSCPCTypingMode.rawValue)
  public var useSCPCTypingMode: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserSCPCSequencesData()
      }
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kPhraseReplacementEnabled.rawValue)
  public var phraseReplacementEnabled: Bool {
    willSet {
      LMMgr.setPhraseReplacementEnabled(newValue)
      if newValue {
        LMMgr.loadUserPhraseReplacement()
      }
    }
  }

  @AppStorage(wrappedValue: false, UserDef.kAssociatedPhrasesEnabled.rawValue)
  public var associatedPhrasesEnabled: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserAssociatesData()
      }
    }
  }

  // MARK: - Keyboard HotKey Enable / Disable

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeySCPC.rawValue)
  public var usingHotKeySCPC: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyAssociates.rawValue)
  public var usingHotKeyAssociates: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCNS.rawValue)
  public var usingHotKeyCNS: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyKangXi.rawValue)
  public var usingHotKeyKangXi: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyJIS.rawValue)
  public var usingHotKeyJIS: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyHalfWidthASCII.rawValue)
  public var usingHotKeyHalfWidthASCII: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCurrencyNumerals.rawValue)
  public var usingHotKeyCurrencyNumerals: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyCassette.rawValue)
  public var usingHotKeyCassette: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyRevLookup.rawValue)
  public var usingHotKeyRevLookup: Bool

  @AppStorage(wrappedValue: true, UserDef.kUsingHotKeyInputMode.rawValue)
  public var usingHotKeyInputMode: Bool
}
