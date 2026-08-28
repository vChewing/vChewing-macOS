// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - PrefMgr

public final class PrefMgr: PrefMgrProtocol, Sendable {
  // MARK: Lifecycle

  public init(
    didAskForSyncingLMPrefs: (() -> ())? = nil,
    didAskForRefreshingSpeechSputnik: (() -> ())? = nil,
    didAskForSyncingShiftKeyDetectorPrefs: (() -> ())? = nil,
    candidateKeyValidator: ((String) -> (String?))? = nil
  ) {
    self.didAskForSyncingLMPrefs = didAskForSyncingLMPrefs
    self.didAskForRefreshingSpeechSputnik = didAskForRefreshingSpeechSputnik
    self.didAskForSyncingShiftKeyDetectorPrefs = didAskForSyncingShiftKeyDetectorPrefs
    self.candidateKeyValidator = candidateKeyValidator
  }

  // MARK: Public

  public static let sharedSansDidSetOps = PrefMgr()

  public var didAskForSyncingLMPrefs: (() -> ())?
  public var didAskForRefreshingSpeechSputnik: (() -> ())?
  public var didAskForSyncingShiftKeyDetectorPrefs: (() -> ())?
  public var candidateKeyValidator: ((String) -> String?)?

  // MARK: - Settings (Tier 1)

  @AppProperty(userDef: .kIsDebugModeEnabled)
  public var isDebugModeEnabled: Bool

  @AppProperty(userDef: .kFailureFlagForPOMObservation)
  public var failureFlagForPOMObservation: Bool

  @AppProperty(userDef: .kCandidateServiceMenuContents)
  public var candidateServiceMenuContents: [String]

  @AppProperty(userDef: .kRespectClientAccentColor)
  public var respectClientAccentColor: Bool

  @AppProperty(userDef: .kAlwaysUsePCBWithElectronBasedClients)
  public var alwaysUsePCBWithElectronBasedClients: Bool

  @AppProperty(userDef: .kSecurityHardenedCompositionBuffer)
  public var securityHardenedCompositionBuffer: Bool

  @AppProperty(userDef: .kCheckAbusersOfSecureEventInputAPI)
  public var checkAbusersOfSecureEventInputAPI: Bool

  @AppProperty(userDef: .kDeltaOfCalendarYears)
  public var deltaOfCalendarYears: Int

  @AppProperty(userDef: .kMostRecentInputMode)
  public var mostRecentInputMode: String

  @AppProperty(userDef: .kCheckUpdateAutomatically)
  public var checkUpdateAutomatically: Bool

  @AppProperty(userDef: .kUseExternalFactoryDict)
  public var useExternalFactoryDict: Bool

  @AppProperty(userDef: .kReplaceSymbolMenuNodeWithUserSuppliedData)
  public var replaceSymbolMenuNodeWithUserSuppliedData: Bool

  @AppProperty(userDef: .kCassettePath)
  public var cassettePath: String

  @AppProperty(userDef: .kUserDataFolderSpecified)
  public var userDataFolderSpecified: String

  @AppProperty(userDef: .kAppleLanguages)
  public var appleLanguages: [String]

  @AppProperty(userDef: .kKeyboardParser4Pinyin)
  public var keyboardParser4Pinyin: Int

  @AppProperty(userDef: .kKeyboardParser4Zhuyin)
  public var keyboardParser4Zhuyin: Int

  @AppProperty(userDef: .kPinyinTypingEnabled)
  public var pinyinTypingEnabled: Bool

  @AppProperty(userDef: .kKanjiConversionPreferences)
  public var kanjiConversionPreferences: Int

  @AppProperty(userDef: .kBasicKeyboardLayout)
  public var basicKeyboardLayout: String

  @AppProperty(userDef: .kAlphanumericalKeyboardLayout)
  public var alphanumericalKeyboardLayout: String

  @AppProperty(userDef: .kShowNotificationsWhenTogglingCapsLock)
  public var showNotificationsWhenTogglingCapsLock: Bool

  @AppProperty(userDef: .kShowNotificationsWhenTogglingEisu)
  public var showNotificationsWhenTogglingEisu: Bool

  @AppProperty(userDef: .kShowNotificationsWhenTogglingShift)
  public var showNotificationsWhenTogglingShift: Bool

  @AppProperty(userDef: .kSpecifiedNotifyUIColorScheme)
  public var specifiedNotifyUIColorScheme: Int

  @AppProperty(userDef: .kAlwaysExpandCandidateWindow)
  public var alwaysExpandCandidateWindow: Bool

  @AppProperty(userDef: .kCandidateWindowShowOnlyOneLine)
  public var candidateWindowShowOnlyOneLine: Bool

  @AppProperty(userDef: .kEnforceSingleLineCandidateWindowLayout4SCPC)
  public var enforceSingleLineCandidateWindowLayout4SCPC: Bool

  @AppProperty(userDef: .kShouldAutoReloadUserDataFiles)
  public var shouldAutoReloadUserDataFiles: Bool

  @AppProperty(userDef: .kUseRearCursorMode)
  public var useRearCursorMode: Bool

  @AppProperty(userDef: .kCandidateStateJKHLBehavior)
  public var candidateStateJKHLBehavior: Int

  @AppProperty(userDef: .kUseShiftQuestionToCallServiceMenu)
  public var useShiftQuestionToCallServiceMenu: Bool

  @AppProperty(userDef: .kCursorPlacementAfterSelectingCandidate)
  public var cursorPlacementAfterSelectingCandidate: Int

  @AppProperty(userDef: .kDodgeInvalidEdgeCandidateCursorPosition)
  public var dodgeInvalidEdgeCandidateCursorPosition: Bool

  @AppProperty(userDef: .kUseDynamicCandidateWindowOrigin)
  public var useDynamicCandidateWindowOrigin: Bool

  @AppProperty(userDef: .kUseHorizontalCandidateList)
  public var useHorizontalCandidateList: Bool

  @AppProperty(userDef: .kMinCellWidthForHorizontalMatrix)
  public var minCellWidthForHorizontalMatrix: Int

  @AppProperty(userDef: .kSpaceKeyBehaviorAgainstICB)
  public var spaceKeyBehaviorAgainstICB: Int

  @AppProperty(userDef: .kAllowRescoringSingleKanjiCandidates)
  public var allowRescoringSingleKanjiCandidates: Bool

  @AppProperty(userDef: .kFetchSuggestionsFromPerceptionOverrideModel)
  public var fetchSuggestionsFromPerceptionOverrideModel: Bool

  @AppProperty(userDef: .kReducePOMLifetimeToNoMoreThan12Hours)
  public var reducePOMLifetimeToNoMoreThan12Hours: Bool

  @AppProperty(userDef: .kUseFixedCandidateOrderOnSelection)
  public var useFixedCandidateOrderOnSelection: Bool

  @AppProperty(userDef: .kEnforceETenDOSCandidateSequence)
  public var enforceETenDOSCandidateSequence: Bool

  @AppProperty(userDef: .kAutoCorrectReadingCombination)
  public var autoCorrectReadingCombination: Bool

  @AppProperty(userDef: .kAlsoConfirmAssociatedCandidatesByEnter)
  public var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppProperty(userDef: .kKeepReadingUponCompositionError)
  public var keepReadingUponCompositionError: Bool

  @AppProperty(userDef: .kUpperCaseLetterKeyBehavior)
  public var upperCaseLetterKeyBehavior: Int

  @AppProperty(userDef: .kNumPadCharInputBehavior)
  public var numPadCharInputBehavior: Int

  @AppProperty(userDef: .kShiftEisuToggleOffTogetherWithCapsLock)
  public var shiftEisuToggleOffTogetherWithCapsLock: Bool

  @AppProperty(userDef: .kBypassNonAppleCapsLockHandling)
  public var bypassNonAppleCapsLockHandling: Bool

  @AppProperty(userDef: .kConsolidateContextOnCandidateSelection)
  public var consolidateContextOnCandidateSelection: Bool

  @AppProperty(userDef: .kPreferredRevolverForceLevel)
  public var preferredRevolverForceLevel: Int

  @AppProperty(userDef: .kHardenVerticalPunctuations)
  public var hardenVerticalPunctuations: Bool

  @AppProperty(userDef: .kTrimUnfinishedReadingsOnCommit)
  public var trimUnfinishedReadingsOnCommit: Bool

  @AppProperty(userDef: .kAlwaysShowTooltipTextsHorizontally)
  public var alwaysShowTooltipTextsHorizontally: Bool

  @AppProperty(userDef: .kClientsIMKTextInputIncapable)
  public var clientsIMKTextInputIncapable: [String: Bool]

  @AppProperty(userDef: .kShowTranslatedStrokesInCompositionBuffer)
  public var showTranslatedStrokesInCompositionBuffer: Bool

  @AppProperty(userDef: .kForceCassetteChineseConversion)
  public var forceCassetteChineseConversion: Int

  @AppProperty(userDef: .kShowReverseLookupInCandidateUI)
  public var showReverseLookupInCandidateUI: Bool

  @AppProperty(userDef: .kShowCodePointInCandidateUI)
  public var showCodePointInCandidateUI: Bool

  @AppProperty(userDef: .kAutoCompositeWithLongestPossibleCassetteKey)
  public var autoCompositeWithLongestPossibleCassetteKey: Bool

  @AppProperty(userDef: .kShareAlphanumericalModeStatusAcrossClients)
  public var shareAlphanumericalModeStatusAcrossClients: Bool

  @AppProperty(userDef: .kPhraseEditorAutoReloadExternalModifications)
  public var phraseEditorAutoReloadExternalModifications: Bool

  @AppProperty(userDef: .kClassicHaninKeyboardSymbolModeShortcutEnabled)
  public var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  // MARK: - Settings (Tier 2)

  @AppProperty(userDef: .kUseSpaceToCommitHighlightedCandidate4SCPC)
  public var useSpaceToCommitHighlightedCandidate4SCPC: Bool

  @AppProperty(userDef: .kEnableCandidateWindowAnimation)
  public var enableCandidateWindowAnimation: Bool

  @AppProperty(userDef: .kDisableSegmentedThickUnderlineInMarkingModeForManagedClients)
  public var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  // MARK: - Settings (Tier 3)

  @AppProperty(userDef: .kMaxCandidateLength)
  public var maxCandidateLength: Int

  @AppProperty(userDef: .kBeepSoundPreference)
  public var beepSoundPreference: Int

  @AppProperty(userDef: .kShouldNotFartInLieuOfBeep)
  public var shouldNotFartInLieuOfBeep: Bool

  @AppProperty(userDef: .kShowHanyuPinyinInCompositionBuffer)
  public var showHanyuPinyinInCompositionBuffer: Bool

  @AppProperty(userDef: .kInlineDumpPinyinInLieuOfZhuyin)
  public var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppProperty(userDef: .kFilterNonCNSReadingsForCHTInput)
  public var filterNonCNSReadingsForCHTInput: Bool

  @AppProperty(userDef: .kFilterFactoryKanjisOfNonCurrentInputMode)
  public var filterFactoryKanjisOfNonCurrentInputMode: Bool

  @AppProperty(userDef: .kRomanNumeralOutputFormat)
  public var romanNumeralOutputFormat: Int

  @AppProperty(userDef: .kCurrencyNumeralsEnabled)
  public var currencyNumeralsEnabled: Bool

  @AppProperty(userDef: .kHalfWidthPunctuationEnabled)
  public var halfWidthPunctuationEnabled: Bool

  @AppProperty(userDef: .kEscToCleanInputBuffer)
  public var escToCleanInputBuffer: Bool

  @AppProperty(userDef: .kAcceptLeadingIntonations)
  public var acceptLeadingIntonations: Bool

  @AppProperty(userDef: .kSpecifyIntonationKeyBehavior)
  public var specifyIntonationKeyBehavior: Int

  @AppProperty(userDef: .kSpecifyShiftBackSpaceKeyBehavior)
  public var specifyShiftBackSpaceKeyBehavior: Int

  @AppProperty(userDef: .kSpecifyShiftTabKeyBehavior)
  public var specifyShiftTabKeyBehavior: Bool

  @AppProperty(userDef: .kSpecifyShiftSpaceKeyBehavior4CandidateWindow)
  public var specifyShiftSpaceKeyBehavior4CandidateWindow: Bool

  @AppProperty(userDef: .kSpecifyCmdOptCtrlEnterBehavior)
  public var specifyCmdOptCtrlEnterBehavior: Int

  @AppProperty(userDef: .kReflectBPMFVSInCompositionBuffer)
  public var reflectBPMFVSInCompositionBuffer: Bool

  // MARK: - Optional settings

  @AppProperty(userDef: .kCandidateTextFontName)
  public var candidateTextFontName: String

  @AppProperty(userDef: .kCandidateNarrationToggleType)
  public var candidateNarrationToggleType: Int

  // MARK: - Keyboard HotKey Enable / Disable

  @AppProperty(userDef: .kUsingHotKeySCPC)
  public var usingHotKeySCPC: Bool

  @AppProperty(userDef: .kUsingHotKeyAssociates)
  public var usingHotKeyAssociates: Bool

  @AppProperty(userDef: .kUsingHotKeyCNS)
  public var usingHotKeyCNS: Bool

  @AppProperty(userDef: .kUsingHotKeyKanjiConversionMode)
  public var usingHotKeyKanjiConversionMode: Bool

  @AppProperty(userDef: .kUsingHotKeyPinyinZhuyinTypingSwitch)
  public var usingHotKeyPinyinZhuyinTypingSwitch: Bool

  @AppProperty(userDef: .kUsingHotKeyHalfWidthPunctuation)
  public var usingHotKeyHalfWidthPunctuation: Bool

  @AppProperty(userDef: .kUsingHotKeyCurrencyNumerals)
  public var usingHotKeyCurrencyNumerals: Bool

  @AppProperty(userDef: .kUsingHotKeyCassette)
  public var usingHotKeyCassette: Bool

  @AppProperty(userDef: .kUsingHotKeyRevLookup)
  public var usingHotKeyRevLookup: Bool

  @AppProperty(userDef: .kUsingHotKeyInputMode)
  public var usingHotKeyInputMode: Bool

  @AppProperty(userDef: .kMixedAlphanumericalEnabled)
  public var mixedAlphanumericalEnabled: Bool

  @AppProperty(userDef: .kFuriousTypingEnabled)
  public var furiousTypingEnabled: Bool

  /// 舊版單一注拼槽 parser 屬性的相容層：依當前打字模式（注音/拼音）讀寫各自的 parser 槽位。
  ///
  /// - getter：`pinyinTypingEnabled` 時讀 `keyboardParser4Pinyin`，否則讀 `keyboardParser4Zhuyin`。
  /// - setter：依給定值的語系自動分流——值 ≥ 100（拼音系）寫入 `keyboardParser4Pinyin` 並開啟
  ///   `pinyinTypingEnabled`；值 < 100（注音系）寫入 `keyboardParser4Zhuyin` 並關閉 `pinyinTypingEnabled`。
  public var keyboardParser: Int {
    get { pinyinTypingEnabled ? keyboardParser4Pinyin : keyboardParser4Zhuyin }
    set {
      if newValue >= 100 {
        keyboardParser4Pinyin = newValue
        pinyinTypingEnabled = true
      } else {
        keyboardParser4Zhuyin = newValue
        pinyinTypingEnabled = false
      }
    }
  }

  @AppProperty(userDef: .kUserPhrasesDatabaseBypassed)
  public var userPhrasesDatabaseBypassed: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kCandidateListTextSize)
  public var candidateListTextSize: Int {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(12 ... 196).contains(candidateListTextSize) {
        candidateListTextSize = max(12, min(candidateListTextSize, 196))
      }
    }
  }

  @AppProperty(userDef: .kPopupCompositionBufferTextSize)
  public var popupCompositionBufferTextSize: Int {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(18 ... 40).contains(popupCompositionBufferTextSize) {
        popupCompositionBufferTextSize = max(18, min(popupCompositionBufferTextSize, 40))
      }
    }
  }

  @AppProperty(userDef: .kReadingNarrationCoverage)
  public var readingNarrationCoverage: Int {
    didSet { didAskForRefreshingSpeechSputnik?() }
  }

  @AppProperty(userDef: .kTogglingAlphanumericalModeWithLShift)
  public var togglingAlphanumericalModeWithLShift: Bool {
    didSet { didAskForSyncingShiftKeyDetectorPrefs?() }
  }

  @AppProperty(userDef: .kTogglingAlphanumericalModeWithRShift)
  public var togglingAlphanumericalModeWithRShift: Bool {
    didSet { didAskForSyncingShiftKeyDetectorPrefs?() }
  }

  @AppProperty(userDef: .kCNS11643Enabled)
  public var cns11643Enabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kSymbolInputEnabled)
  public var symbolInputEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kCassetteEnabled)
  public var cassetteEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kSuppressFactoryUnigramsOfKanaSyllables)
  public var suppressFactoryUnigramsOfKanaSyllables: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kCandidateKeys)
  public var candidateKeys: String {
    didSet {
      let optimized = candidateKeys.lowercased().deduplicated
      if candidateKeys != optimized { candidateKeys = optimized }
      if candidateKeyValidator?(candidateKeys) != nil {
        candidateKeys = UserDef.kCandidateKeys.stringDefaultValue
      }
    }
  }

  @AppProperty(userDef: .kUseSCPCTypingMode)
  public var useSCPCTypingMode: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kPhraseReplacementEnabled)
  public var phraseReplacementEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }

  @AppProperty(userDef: .kAssociatedPhrasesEnabled)
  public var associatedPhrasesEnabled: Bool {
    didSet { didAskForSyncingLMPrefs?() }
  }
}

extension PrefMgr {
  /// Fix Odd Preferences for platform-independent purposes only.
  public func fixOddPreferencesCore() {
    // 自動糾正選字鍵 (利用其 didSet 特性)
    candidateKeys = candidateKeys
    // 注拼槽注音排列選項糾錯：注音與拼音 parser 分兩路檢查，非法值各自歸回預設。
    if KeyboardParser(rawValue: keyboardParser4Zhuyin) == nil {
      keyboardParser4Zhuyin = 0
    }
    if KeyboardParser(rawValue: keyboardParser4Pinyin) == nil {
      keyboardParser4Pinyin = 100
    }
    // 漢字轉換（當代繁體/康熙/JIS）的枚舉值糾錯。
    if ![0, 1, 2].contains(kanjiConversionPreferences) {
      kanjiConversionPreferences = 0
    }
    // 其它多元選項參數自動糾錯。
    if ![0, 1, 2].contains(specifyIntonationKeyBehavior) {
      specifyIntonationKeyBehavior = 0
    }
    if ![0, 1, 2].contains(specifyShiftBackSpaceKeyBehavior) {
      specifyShiftBackSpaceKeyBehavior = 0
    }
    if ![0, 1, 2, 3, 4].contains(upperCaseLetterKeyBehavior) {
      upperCaseLetterKeyBehavior = 0
    }
    if ![0, 1, 2].contains(readingNarrationCoverage) {
      readingNarrationCoverage = 0
    }
    if ![0, 1, 2, 3].contains(romanNumeralOutputFormat) {
      romanNumeralOutputFormat = 0
    }
    if ![0, 1, 2, 3, 4].contains(specifyCmdOptCtrlEnterBehavior) {
      specifyCmdOptCtrlEnterBehavior = 0
    }
    if ![0, 1, 2].contains(beepSoundPreference) {
      beepSoundPreference = 2
    }
    if ![0, 1, 2].contains(cursorPlacementAfterSelectingCandidate) {
      cursorPlacementAfterSelectingCandidate = 0
    }
    if ![0, 1, 2].contains(candidateNarrationToggleType) {
      candidateNarrationToggleType = 0
    }
    if ![0, 1, 2].contains(candidateStateJKHLBehavior) {
      candidateStateJKHLBehavior = 0
    }
    if ![0, 1, 2].contains(preferredRevolverForceLevel) {
      preferredRevolverForceLevel = 2
    }
    if ![0, 1, 2].contains(spaceKeyBehaviorAgainstICB) {
      spaceKeyBehaviorAgainstICB = 1
    }
    migrateDeprecatedSettings()
  }

  private func migrateDeprecatedSettings() {
    let defaults = UserDefaults.standard
    // 移除被刻意作廢的設定。
    defaults.removeObject(forKey: "AllowBoostingSingleKanjiAsUserPhrase")
    // 遷移舊設定：JK/HL 選字窗行為。
    if candidateStateJKHLBehavior == 0 {
      let legacyJK = defaults.bool(forKey: "UseJKtoMoveCompositorCursorInCandidateState")
      let legacyHL = defaults.bool(forKey: "UseHLtoMoveCompositorCursorInCandidateState")
      switch (legacyJK, legacyHL) {
      case (true, false): candidateStateJKHLBehavior = 1
      case (false, true): candidateStateJKHLBehavior = 2
      case (true, true): candidateStateJKHLBehavior = 1
      default: break
      }
      if legacyJK || legacyHL {
        defaults.removeObject(forKey: "UseJKtoMoveCompositorCursorInCandidateState")
        defaults.removeObject(forKey: "UseHLtoMoveCompositorCursorInCandidateState")
      }
    }
    // 遷移舊設定：Space 鍵對內文組字區的行為（舊版 Bool → 新版 Int）。
    let oldKey = "ChooseCandidateUsingSpace"
    if let oldValue = defaults.object(forKey: oldKey) {
      // oldValue 非 Bool 則忽略，避免舊版 Int 值被意外覆蓋。
      if let oldBool = oldValue as? Bool {
        if spaceKeyBehaviorAgainstICB == 1 { // 僅在仍為預設值時遷移。
          spaceKeyBehaviorAgainstICB = oldBool ? 1 : 0
        }
      }
      defaults.removeObject(forKey: oldKey)
    }
    // 遷移舊設定：單一 KeyboardParser → 注音/拼音雙槽位（P153）。
    // 依舊值的語系分流：≥100（拼音系）寫入 4Pinyin 並開啟拼音模式；
    // <100（注音系）寫入 4Zhuyin 並關閉拼音模式。遷移完畢後移除舊 key。
    if let oldParser = defaults.object(forKey: "KeyboardParser") as? Int {
      if oldParser >= 100 {
        keyboardParser4Pinyin = oldParser
        pinyinTypingEnabled = true
      } else {
        keyboardParser4Zhuyin = oldParser
        pinyinTypingEnabled = false
      }
      defaults.removeObject(forKey: "KeyboardParser")
    }
    // 遷移舊設定：康熙/JIS 兩個布林 → 漢字轉換枚舉（P153）。
    // (true, false) → 1（康熙）；(false, true)／(true, true) → 2（JIS）；其餘 → 0（不轉換）。
    if defaults.object(forKey: "ChineseConversionEnabled") != nil
      || defaults.object(forKey: "ShiftJISShinjitaiOutputEnabled") != nil {
      let oldKangXi = defaults.bool(forKey: "ChineseConversionEnabled")
      let oldJIS = defaults.bool(forKey: "ShiftJISShinjitaiOutputEnabled")
      switch (oldKangXi, oldJIS) {
      case (true, false): kanjiConversionPreferences = 1
      case (false, true), (true, true): kanjiConversionPreferences = 2
      default: kanjiConversionPreferences = 0
      }
      defaults.removeObject(forKey: "ChineseConversionEnabled")
      defaults.removeObject(forKey: "ShiftJISShinjitaiOutputEnabled")
    }
    // 遷移舊設定：半形標點熱鍵 pref 更名（"UsingHotKeyHalfWidthASCII" → "UsingHotKeyHalfWidthPunctuation"）。
    // 舊 key 的用戶設定值搬移至新 key（若使用者曾自行調整過熱鍵開關）。
    if defaults.object(forKey: "UsingHotKeyHalfWidthASCII") != nil {
      usingHotKeyHalfWidthPunctuation = defaults.bool(forKey: "UsingHotKeyHalfWidthASCII")
      defaults.removeObject(forKey: "UsingHotKeyHalfWidthASCII")
    }
  }
}
