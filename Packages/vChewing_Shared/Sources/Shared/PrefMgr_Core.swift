// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// MARK: -

@objcMembers
public class PrefMgr: NSObject, PrefMgrProtocol {
  public static let kDefaultCandidateKeys = "123456"
  public static let kDefaultBasicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
  public static let kDefaultAlphanumericalKeyboardLayout = {
    if #available(macOS 10.13, *) {
      return "com.apple.keylayout.ABC"
    }
    return "com.apple.keylayout.US"
  }()

  public static let kDefaultClientsIMKTextInputIncapable: [String: Bool] = [
    "com.valvesoftware.steam": true,
    "jp.naver.line.mac": true,
    "com.openai.chat": true,
  ]

  public static let kDefaultCandidateServiceMenuItem: [String] = [
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

  public var didAskForSyncingLMPrefs: (() -> ())?
  public var didAskForRefreshingSpeechSputnik: (() -> ())?
  public var didAskForSyncingShiftKeyDetectorPrefs: (() -> ())?

  // MARK: - Settings (Tier 1)

  @AppProperty(key: UserDef.kIsDebugModeEnabled.rawValue, defaultValue: false)
  public dynamic var isDebugModeEnabled: Bool

  @AppProperty(key: UserDef.kFailureFlagForPOMObservation.rawValue, defaultValue: false)
  public dynamic var failureFlagForPOMObservation: Bool

  @AppProperty(
    key: UserDef.kCandidateServiceMenuContents.rawValue,
    defaultValue: kDefaultCandidateServiceMenuItem
  )
  public dynamic var candidateServiceMenuContents: [String]

  @AppProperty(key: UserDef.kRespectClientAccentColor.rawValue, defaultValue: true)
  public dynamic var respectClientAccentColor: Bool

  @AppProperty(key: UserDef.kAlwaysUsePCBWithElectronBasedClients.rawValue, defaultValue: true)
  public dynamic var alwaysUsePCBWithElectronBasedClients: Bool

  @AppProperty(key: UserDef.kSecurityHardenedCompositionBuffer.rawValue, defaultValue: false)
  public dynamic var securityHardenedCompositionBuffer: Bool

  @AppProperty(key: UserDef.kCheckAbusersOfSecureEventInputAPI.rawValue, defaultValue: true)
  public dynamic var checkAbusersOfSecureEventInputAPI: Bool

  @AppProperty(key: UserDef.kDeltaOfCalendarYears.rawValue, defaultValue: -2_000)
  public dynamic var deltaOfCalendarYears: Int

  @AppProperty(key: UserDef.kMostRecentInputMode.rawValue, defaultValue: "")
  public dynamic var mostRecentInputMode: String

  @AppProperty(key: UserDef.kCheckUpdateAutomatically.rawValue, defaultValue: false)
  public dynamic var checkUpdateAutomatically: Bool

  @AppProperty(key: UserDef.kUseExternalFactoryDict.rawValue, defaultValue: false)
  public dynamic var useExternalFactoryDict: Bool

  @AppProperty(key: UserDef.kCassettePath.rawValue, defaultValue: "")
  public dynamic var cassettePath: String

  @AppProperty(key: UserDef.kUserDataFolderSpecified.rawValue, defaultValue: "")
  public dynamic var userDataFolderSpecified: String

  @AppProperty(key: UserDef.kAppleLanguages.rawValue, defaultValue: [])
  public dynamic var appleLanguages: [String]

  @AppProperty(key: UserDef.kKeyboardParser.rawValue, defaultValue: 0)
  public dynamic var keyboardParser: Int

  @AppProperty(
    key: UserDef.kBasicKeyboardLayout.rawValue, defaultValue: kDefaultBasicKeyboardLayout
  )
  public dynamic var basicKeyboardLayout: String

  @AppProperty(
    key: UserDef.kAlphanumericalKeyboardLayout.rawValue,
    defaultValue: kDefaultAlphanumericalKeyboardLayout
  )
  public dynamic var alphanumericalKeyboardLayout: String

  @AppProperty(key: UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue, defaultValue: true)
  public dynamic var showNotificationsWhenTogglingCapsLock: Bool

  @AppProperty(key: UserDef.kAlwaysExpandCandidateWindow.rawValue, defaultValue: false)
  public dynamic var alwaysExpandCandidateWindow: Bool

  @AppProperty(key: UserDef.kCandidateWindowShowOnlyOneLine.rawValue, defaultValue: false)
  public dynamic var candidateWindowShowOnlyOneLine: Bool

  @AppProperty(key: UserDef.kShouldAutoReloadUserDataFiles.rawValue, defaultValue: true)
  public dynamic var shouldAutoReloadUserDataFiles: Bool

  @AppProperty(key: UserDef.kUseRearCursorMode.rawValue, defaultValue: false)
  public dynamic var useRearCursorMode: Bool

  @AppProperty(
    key: UserDef.kUseHLtoMoveCompositorCursorInCandidateState.rawValue,
    defaultValue: false
  )
  public var useHLtoMoveCompositorCursorInCandidateState: Bool

  @AppProperty(
    key: UserDef.kUseJKtoMoveCompositorCursorInCandidateState.rawValue,
    defaultValue: false
  )
  public var useJKtoMoveCompositorCursorInCandidateState: Bool

  @AppProperty(key: UserDef.kUseShiftQuestionToCallServiceMenu.rawValue, defaultValue: true)
  public var useShiftQuestionToCallServiceMenu: Bool

  @AppProperty(key: UserDef.kMoveCursorAfterSelectingCandidate.rawValue, defaultValue: true)
  public dynamic var moveCursorAfterSelectingCandidate: Bool

  @AppProperty(key: UserDef.kDodgeInvalidEdgeCandidateCursorPosition.rawValue, defaultValue: true)
  public dynamic var dodgeInvalidEdgeCandidateCursorPosition: Bool

  @AppProperty(key: UserDef.kUseDynamicCandidateWindowOrigin.rawValue, defaultValue: true)
  public dynamic var useDynamicCandidateWindowOrigin: Bool

  @AppProperty(key: UserDef.kUseHorizontalCandidateList.rawValue, defaultValue: true)
  public dynamic var useHorizontalCandidateList: Bool

  @AppProperty(key: UserDef.kMinCellWidthForHorizontalMatrix.rawValue, defaultValue: 0)
  public dynamic var minCellWidthForHorizontalMatrix: Int

  @AppProperty(key: UserDef.kChooseCandidateUsingSpace.rawValue, defaultValue: true)
  public dynamic var chooseCandidateUsingSpace: Bool

  @AppProperty(key: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue, defaultValue: false)
  public dynamic var allowBoostingSingleKanjiAsUserPhrase: Bool

  @AppProperty(key: UserDef.kFetchSuggestionsFromPerceptionOverrideModel.rawValue, defaultValue: true)
  public dynamic var fetchSuggestionsFromPerceptionOverrideModel: Bool

  @AppProperty(key: UserDef.kUseFixedCandidateOrderOnSelection.rawValue, defaultValue: false)
  public dynamic var useFixedCandidateOrderOnSelection: Bool

  @AppProperty(key: UserDef.kAutoCorrectReadingCombination.rawValue, defaultValue: true)
  public dynamic var autoCorrectReadingCombination: Bool

  @AppProperty(key: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue, defaultValue: false)
  public dynamic var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppProperty(key: UserDef.kKeepReadingUponCompositionError.rawValue, defaultValue: false)
  public dynamic var keepReadingUponCompositionError: Bool

  @AppProperty(key: UserDef.kUpperCaseLetterKeyBehavior.rawValue, defaultValue: 0)
  public dynamic var upperCaseLetterKeyBehavior: Int

  @AppProperty(key: UserDef.kNumPadCharInputBehavior.rawValue, defaultValue: 0)
  public var numPadCharInputBehavior: Int

  @AppProperty(key: UserDef.kShiftEisuToggleOffTogetherWithCapsLock.rawValue, defaultValue: true)
  public dynamic var shiftEisuToggleOffTogetherWithCapsLock: Bool

  @AppProperty(key: UserDef.kBypassNonAppleCapsLockHandling.rawValue, defaultValue: false)
  public dynamic var bypassNonAppleCapsLockHandling: Bool

  @AppProperty(key: UserDef.kConsolidateContextOnCandidateSelection.rawValue, defaultValue: true)
  public dynamic var consolidateContextOnCandidateSelection: Bool

  @AppProperty(key: UserDef.kHardenVerticalPunctuations.rawValue, defaultValue: false)
  public dynamic var hardenVerticalPunctuations: Bool

  @AppProperty(key: UserDef.kTrimUnfinishedReadingsOnCommit.rawValue, defaultValue: true)
  public dynamic var trimUnfinishedReadingsOnCommit: Bool

  @AppProperty(key: UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue, defaultValue: false)
  public dynamic var alwaysShowTooltipTextsHorizontally: Bool

  @AppProperty(
    key: UserDef.kClientsIMKTextInputIncapable.rawValue,
    defaultValue: kDefaultClientsIMKTextInputIncapable
  )
  public dynamic var clientsIMKTextInputIncapable: [String: Bool]

  @AppProperty(key: UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue, defaultValue: true)
  public dynamic var showTranslatedStrokesInCompositionBuffer: Bool

  @AppProperty(key: UserDef.kForceCassetteChineseConversion.rawValue, defaultValue: 0)
  public dynamic var forceCassetteChineseConversion: Int

  @AppProperty(key: UserDef.kShowReverseLookupInCandidateUI.rawValue, defaultValue: true)
  public dynamic var showReverseLookupInCandidateUI: Bool

  @AppProperty(key: UserDef.kShowCodePointInCandidateUI.rawValue, defaultValue: true)
  public dynamic var showCodePointInCandidateUI: Bool

  @AppProperty(
    key: UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue,
    defaultValue: true
  )
  public dynamic var autoCompositeWithLongestPossibleCassetteKey: Bool

  @AppProperty(
    key: UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue,
    defaultValue: false
  )
  public dynamic var shareAlphanumericalModeStatusAcrossClients: Bool

  @AppProperty(
    key: UserDef.kPhraseEditorAutoReloadExternalModifications.rawValue,
    defaultValue: true
  )
  public dynamic var phraseEditorAutoReloadExternalModifications: Bool

  @AppProperty(
    key: UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue,
    defaultValue: false
  )
  public dynamic var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  // MARK: - Settings (Tier 2)

  @AppProperty(key: UserDef.kUseSpaceToCommitHighlightedSCPCCandidate.rawValue, defaultValue: true)
  public dynamic var useSpaceToCommitHighlightedSCPCCandidate: Bool

  @AppProperty(
    key: UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue,
    defaultValue: false
  )
  public dynamic var enableMouseScrollingForTDKCandidatesCocoa: Bool

  @AppProperty(
    key: UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.rawValue,
    defaultValue: false
  )
  public dynamic var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  // MARK: - Settings (Tier 3)

  @AppProperty(key: UserDef.kMaxCandidateLength.rawValue, defaultValue: 10)
  public dynamic var maxCandidateLength: Int

  @AppProperty(key: UserDef.kBeepSoundPreference.rawValue, defaultValue: 2)
  public dynamic var beepSoundPreference: Int

  @AppProperty(key: UserDef.kShouldNotFartInLieuOfBeep.rawValue, defaultValue: true)
  public dynamic var shouldNotFartInLieuOfBeep: Bool

  @AppProperty(key: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue, defaultValue: false)
  public dynamic var showHanyuPinyinInCompositionBuffer: Bool

  @AppProperty(key: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue, defaultValue: false)
  public dynamic var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppProperty(key: UserDef.kFilterNonCNSReadingsForCHTInput.rawValue, defaultValue: false)
  public dynamic var filterNonCNSReadingsForCHTInput: Bool

  @AppProperty(key: UserDef.kCurrencyNumeralsEnabled.rawValue, defaultValue: false)
  public dynamic var currencyNumeralsEnabled: Bool

  @AppProperty(key: UserDef.kHalfWidthPunctuationEnabled.rawValue, defaultValue: false)
  public dynamic var halfWidthPunctuationEnabled: Bool

  @AppProperty(key: UserDef.kEscToCleanInputBuffer.rawValue, defaultValue: true)
  public dynamic var escToCleanInputBuffer: Bool

  @AppProperty(key: UserDef.kAcceptLeadingIntonations.rawValue, defaultValue: true)
  public dynamic var acceptLeadingIntonations: Bool

  @AppProperty(key: UserDef.kSpecifyIntonationKeyBehavior.rawValue, defaultValue: 0)
  public dynamic var specifyIntonationKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue, defaultValue: 0)
  public dynamic var specifyShiftBackSpaceKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftTabKeyBehavior.rawValue, defaultValue: false)
  public dynamic var specifyShiftTabKeyBehavior: Bool

  @AppProperty(key: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue, defaultValue: false)
  public dynamic var specifyShiftSpaceKeyBehavior: Bool

  @AppProperty(key: UserDef.kSpecifyCmdOptCtrlEnterBehavior.rawValue, defaultValue: 0)
  public dynamic var specifyCmdOptCtrlEnterBehavior: Int

  // MARK: - Optional settings

  @AppProperty(key: UserDef.kCandidateTextFontName.rawValue, defaultValue: "")
  public dynamic var candidateTextFontName: String

  // MARK: - Keyboard HotKey Enable / Disable

  @AppProperty(key: UserDef.kUsingHotKeySCPC.rawValue, defaultValue: true)
  public dynamic var usingHotKeySCPC: Bool

  @AppProperty(key: UserDef.kUsingHotKeyAssociates.rawValue, defaultValue: true)
  public dynamic var usingHotKeyAssociates: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCNS.rawValue, defaultValue: true)
  public dynamic var usingHotKeyCNS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyKangXi.rawValue, defaultValue: true)
  public dynamic var usingHotKeyKangXi: Bool

  @AppProperty(key: UserDef.kUsingHotKeyJIS.rawValue, defaultValue: true)
  public dynamic var usingHotKeyJIS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyHalfWidthASCII.rawValue, defaultValue: true)
  public dynamic var usingHotKeyHalfWidthASCII: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCurrencyNumerals.rawValue, defaultValue: true)
  public dynamic var usingHotKeyCurrencyNumerals: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCassette.rawValue, defaultValue: true)
  public dynamic var usingHotKeyCassette: Bool

  @AppProperty(key: UserDef.kUsingHotKeyRevLookup.rawValue, defaultValue: true)
  public dynamic var usingHotKeyRevLookup: Bool

  @AppProperty(key: UserDef.kUsingHotKeyInputMode.rawValue, defaultValue: true)
  public dynamic var usingHotKeyInputMode: Bool

  @AppProperty(key: UserDef.kCandidateListTextSize.rawValue, defaultValue: 16)
  public dynamic var candidateListTextSize: Double {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(12 ... 196).contains(candidateListTextSize) {
        candidateListTextSize = max(12, min(candidateListTextSize, 196))
      }
    }
  }

  @AppProperty(key: UserDef.kReadingNarrationCoverage.rawValue, defaultValue: 0)
  public dynamic var readingNarrationCoverage: Int {
    didSet { didAskForRefreshingSpeechSputnik?() }
  }

  @AppProperty(key: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue, defaultValue: true)
  public dynamic var togglingAlphanumericalModeWithLShift: Bool {
    didSet { didAskForSyncingShiftKeyDetectorPrefs?() }
  }

  @AppProperty(key: UserDef.kTogglingAlphanumericalModeWithRShift.rawValue, defaultValue: true)
  public dynamic var togglingAlphanumericalModeWithRShift: Bool {
    didSet { didAskForSyncingShiftKeyDetectorPrefs?() }
  }

  @AppProperty(key: UserDef.kCNS11643Enabled.rawValue, defaultValue: false)
  public dynamic var cns11643Enabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(key: UserDef.kSymbolInputEnabled.rawValue, defaultValue: true)
  public dynamic var symbolInputEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(key: UserDef.kCassetteEnabled.rawValue, defaultValue: false)
  public dynamic var cassetteEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(key: UserDef.kChineseConversionEnabled.rawValue, defaultValue: false)
  public dynamic var chineseConversionEnabled: Bool {
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

  @AppProperty(key: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue, defaultValue: false)
  public dynamic var shiftJISShinjitaiOutputEnabled: Bool {
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

  @AppProperty(key: UserDef.kCandidateKeys.rawValue, defaultValue: kDefaultCandidateKeys)
  public dynamic var candidateKeys: String {
    didSet {
      let optimized = candidateKeys.lowercased().deduplicated
      if candidateKeys != optimized { candidateKeys = optimized }
      if validate(candidateKeys: candidateKeys) != nil {
        candidateKeys = Self.kDefaultCandidateKeys
      }
    }
  }

  @AppProperty(key: UserDef.kUseSCPCTypingMode.rawValue, defaultValue: false)
  public dynamic var useSCPCTypingMode: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(key: UserDef.kPhraseReplacementEnabled.rawValue, defaultValue: false)
  public dynamic var phraseReplacementEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(key: UserDef.kAssociatedPhrasesEnabled.rawValue, defaultValue: false)
  public dynamic var associatedPhrasesEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }
}
