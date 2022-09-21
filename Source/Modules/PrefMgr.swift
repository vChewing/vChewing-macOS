// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftExtension

private let kDefaultKeys = "123456789"
private let kDefaultBasicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
private let kDefaultAlphanumericalKeyboardLayout = "com.apple.keylayout.ABC"

// MARK: -

public class PrefMgr: PrefMgrProtocol {
  public static let shared = PrefMgr()

  // MARK: - Settings (Tier 1)

  @AppProperty(key: UserDef.kIsDebugModeEnabled.rawValue, defaultValue: false)
  public var isDebugModeEnabled: Bool

  @AppProperty(key: UserDef.kFailureFlagForUOMObservation.rawValue, defaultValue: false)
  public var failureFlagForUOMObservation: Bool

  @AppProperty(key: UserDef.kDeltaOfCalendarYears.rawValue, defaultValue: -2000)
  public var deltaOfCalendarYears: Int

  @AppProperty(key: UserDef.kMostRecentInputMode.rawValue, defaultValue: "")
  public var mostRecentInputMode: String

  @AppProperty(key: UserDef.kCheckUpdateAutomatically.rawValue, defaultValue: false)
  public var checkUpdateAutomatically: Bool

  @AppProperty(key: UserDef.kUserDataFolderSpecified.rawValue, defaultValue: "")
  public var userDataFolderSpecified: String

  @AppProperty(key: UserDef.kAppleLanguages.rawValue, defaultValue: [])
  public var appleLanguages: [String]

  @AppProperty(key: UserDef.kKeyboardParser.rawValue, defaultValue: 0)
  public var keyboardParser: Int

  @AppProperty(
    key: UserDef.kBasicKeyboardLayout.rawValue, defaultValue: kDefaultBasicKeyboardLayout
  )
  public var basicKeyboardLayout: String

  @AppProperty(
    key: UserDef.kAlphanumericalKeyboardLayout.rawValue, defaultValue: kDefaultAlphanumericalKeyboardLayout
  )
  public var alphanumericalKeyboardLayout: String

  @AppProperty(key: UserDef.kShowPageButtonsInCandidateWindow.rawValue, defaultValue: true)
  public var showPageButtonsInCandidateWindow: Bool

  @AppProperty(key: UserDef.kCandidateListTextSize.rawValue, defaultValue: 18)
  public var candidateListTextSize: Double {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(12...196).contains(candidateListTextSize) {
        candidateListTextSize = max(12, min(candidateListTextSize, 196))
      }
    }
  }

  @AppProperty(key: UserDef.kShouldAutoReloadUserDataFiles.rawValue, defaultValue: true)
  public var shouldAutoReloadUserDataFiles: Bool

  @AppProperty(key: UserDef.kUseRearCursorMode.rawValue, defaultValue: false)
  public var useRearCursorMode: Bool

  @AppProperty(key: UserDef.kMoveCursorAfterSelectingCandidate.rawValue, defaultValue: true)
  public var moveCursorAfterSelectingCandidate: Bool

  @AppProperty(key: UserDef.kUseHorizontalCandidateList.rawValue, defaultValue: true)
  public var useHorizontalCandidateList: Bool

  @AppProperty(key: UserDef.kChooseCandidateUsingSpace.rawValue, defaultValue: true)
  public var chooseCandidateUsingSpace: Bool

  @AppProperty(key: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue, defaultValue: false)
  public var allowBoostingSingleKanjiAsUserPhrase: Bool

  @AppProperty(key: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue, defaultValue: true)
  public var fetchSuggestionsFromUserOverrideModel: Bool

  @AppProperty(key: UserDef.kUseFixecCandidateOrderOnSelection.rawValue, defaultValue: false)
  public var useFixecCandidateOrderOnSelection: Bool

  @AppProperty(key: UserDef.kAutoCorrectReadingCombination.rawValue, defaultValue: true)
  public var autoCorrectReadingCombination: Bool

  @AppProperty(key: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue, defaultValue: true)
  public var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppProperty(key: UserDef.kKeepReadingUponCompositionError.rawValue, defaultValue: false)
  public var keepReadingUponCompositionError: Bool

  @AppProperty(key: UserDef.kUpperCaseLetterKeyBehavior.rawValue, defaultValue: 0)
  public var upperCaseLetterKeyBehavior: Int

  @AppProperty(key: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue, defaultValue: true)
  public var togglingAlphanumericalModeWithLShift: Bool

  @AppProperty(key: UserDef.kDisableShiftTogglingAlphanumericalMode.rawValue, defaultValue: false)
  public var disableShiftTogglingAlphanumericalMode: Bool

  @AppProperty(key: UserDef.kConsolidateContextOnCandidateSelection.rawValue, defaultValue: true)
  public var consolidateContextOnCandidateSelection: Bool

  @AppProperty(key: UserDef.kHardenVerticalPunctuations.rawValue, defaultValue: false)
  public var hardenVerticalPunctuations: Bool

  @AppProperty(key: UserDef.kTrimUnfinishedReadingsOnCommit.rawValue, defaultValue: true)
  public var trimUnfinishedReadingsOnCommit: Bool

  @AppProperty(key: UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue, defaultValue: false)
  public var alwaysShowTooltipTextsHorizontally: Bool

  @AppProperty(key: UserDef.kClientsIMKTextInputIncapable.rawValue, defaultValue: ["com.valvesoftware.steam"])
  public var clientsIMKTextInputIncapable: [String]

  @AppProperty(key: UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue, defaultValue: true)
  public var onlyLoadFactoryLangModelsIfNeeded: Bool {
    didSet {
      if !onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
    }
  }

  // MARK: - Settings (Tier 2)

  @AppProperty(key: UserDef.kUseIMKCandidateWindow.rawValue, defaultValue: false)
  public var useIMKCandidateWindow: Bool

  @AppProperty(key: UserDef.kHandleDefaultCandidateFontsByLangIdentifier.rawValue, defaultValue: false)
  public var handleDefaultCandidateFontsByLangIdentifier: Bool

  @AppProperty(key: UserDef.kShiftKeyAccommodationBehavior.rawValue, defaultValue: 0)
  public var shiftKeyAccommodationBehavior: Int

  // MARK: - Settings (Tier 3)

  @AppProperty(key: UserDef.kMaxCandidateLength.rawValue, defaultValue: 10)
  public var maxCandidateLength: Int

  @AppProperty(key: UserDef.kShouldNotFartInLieuOfBeep.rawValue, defaultValue: true)
  public var shouldNotFartInLieuOfBeep: Bool

  @AppProperty(key: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue, defaultValue: false)
  public var showHanyuPinyinInCompositionBuffer: Bool

  @AppProperty(key: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue, defaultValue: false)
  public var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppProperty(key: UserDef.kCNS11643Enabled.rawValue, defaultValue: false)
  public var cns11643Enabled: Bool {
    didSet {
      LMMgr.setCNSEnabled(cns11643Enabled)  // 很重要
    }
  }

  @AppProperty(key: UserDef.kSymbolInputEnabled.rawValue, defaultValue: true)
  public var symbolInputEnabled: Bool {
    didSet {
      LMMgr.setSymbolEnabled(symbolInputEnabled)  // 很重要
    }
  }

  @AppProperty(key: UserDef.kChineseConversionEnabled.rawValue, defaultValue: false)
  public var chineseConversionEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
        shiftJISShinjitaiOutputEnabled.toggle()
        UserDefaults.standard.set(
          shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
        )
      }
      UserDefaults.standard.set(
        chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
      )
    }
  }

  @AppProperty(key: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue, defaultValue: false)
  public var shiftJISShinjitaiOutputEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if shiftJISShinjitaiOutputEnabled, chineseConversionEnabled {
        chineseConversionEnabled.toggle()
        UserDefaults.standard.set(
          chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
        )
      }
      UserDefaults.standard.set(
        shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
      )
    }
  }

  @AppProperty(key: UserDef.kCurrencyNumeralsEnabled.rawValue, defaultValue: false)
  public var currencyNumeralsEnabled: Bool

  @AppProperty(key: UserDef.kHalfWidthPunctuationEnabled.rawValue, defaultValue: false)
  public var halfWidthPunctuationEnabled: Bool

  @AppProperty(key: UserDef.kEscToCleanInputBuffer.rawValue, defaultValue: true)
  public var escToCleanInputBuffer: Bool

  @AppProperty(key: UserDef.kSpecifyIntonationKeyBehavior.rawValue, defaultValue: 0)
  public var specifyIntonationKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue, defaultValue: 0)
  public var specifyShiftBackSpaceKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftTabKeyBehavior.rawValue, defaultValue: false)
  public var specifyShiftTabKeyBehavior: Bool

  @AppProperty(key: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue, defaultValue: false)
  public var specifyShiftSpaceKeyBehavior: Bool

  // MARK: - Optional settings

  @AppProperty(key: UserDef.kCandidateTextFontName.rawValue, defaultValue: "")
  public var candidateTextFontName: String

  @AppProperty(key: UserDef.kCandidateKeyLabelFontName.rawValue, defaultValue: "")
  public var candidateKeyLabelFontName: String

  @AppProperty(key: UserDef.kCandidateKeys.rawValue, defaultValue: kDefaultKeys)
  public var candidateKeys: String {
    didSet {
      if useIMKCandidateWindow {
        candidateKeys = kDefaultKeys
      }
    }
  }

  @AppProperty(key: UserDef.kUseSCPCTypingMode.rawValue, defaultValue: false)
  public var useSCPCTypingMode: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserSCPCSequencesData()
      }
    }
  }

  @AppProperty(key: UserDef.kPhraseReplacementEnabled.rawValue, defaultValue: false)
  public var phraseReplacementEnabled: Bool {
    willSet {
      LMMgr.setPhraseReplacementEnabled(newValue)
      if newValue {
        LMMgr.loadUserPhraseReplacement()
      }
    }
  }

  @AppProperty(key: UserDef.kAssociatedPhrasesEnabled.rawValue, defaultValue: false)
  public var associatedPhrasesEnabled: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserAssociatesData()
      }
    }
  }

  // MARK: - Keyboard HotKey Enable / Disable

  @AppProperty(key: UserDef.kUsingHotKeySCPC.rawValue, defaultValue: true)
  public var usingHotKeySCPC: Bool

  @AppProperty(key: UserDef.kUsingHotKeyAssociates.rawValue, defaultValue: true)
  public var usingHotKeyAssociates: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCNS.rawValue, defaultValue: true)
  public var usingHotKeyCNS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyKangXi.rawValue, defaultValue: true)
  public var usingHotKeyKangXi: Bool

  @AppProperty(key: UserDef.kUsingHotKeyJIS.rawValue, defaultValue: true)
  public var usingHotKeyJIS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyHalfWidthASCII.rawValue, defaultValue: true)
  public var usingHotKeyHalfWidthASCII: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCurrencyNumerals.rawValue, defaultValue: true)
  public var usingHotKeyCurrencyNumerals: Bool
}

// MARK: Auto parameter fix procedures, executed everytime on ctlInputMethod.activateServer().

extension PrefMgr {
  public func fixOddPreferences() {
    // 防呆。macOS 10.11 用 IMK 選字窗會崩潰，macOS 10.13 的 IMK 選字窗仍有問題。
    // 一般人想用的 IMK 選字窗基於 macOS 10.09 系統內建的注音輸入法的那種矩陣選字窗。
    // 然而，該選字窗的體驗直到 macOS 10.14 開始才在 IMKCandidates 當中正式提供。
    if #unavailable(macOS 10.13) { useIMKCandidateWindow = false }
    if #unavailable(macOS 10.15) {
      handleDefaultCandidateFontsByLangIdentifier = false
      shiftKeyAccommodationBehavior = 0
      disableShiftTogglingAlphanumericalMode = false
      togglingAlphanumericalModeWithLShift = false
    }
    // 客體黑名單自動排序去重複。
    clientsIMKTextInputIncapable = Array(Set(clientsIMKTextInputIncapable)).sorted()
    // 注拼槽注音排列選項糾錯。
    var isKeyboardParserOptionValid = false
    KeyboardParser.allCases.forEach {
      if $0.rawValue == keyboardParser { isKeyboardParserOptionValid = true }
    }
    if !isKeyboardParserOptionValid {
      keyboardParser = 0
    }
    // 基礎鍵盤排列選項糾錯。
    if TISInputSource.generate(from: basicKeyboardLayout) == nil {
      basicKeyboardLayout = kDefaultBasicKeyboardLayout
    }
    if TISInputSource.generate(from: alphanumericalKeyboardLayout) == nil {
      alphanumericalKeyboardLayout = kDefaultAlphanumericalKeyboardLayout
    }
    // 其它多元選項參數自動糾錯。
    if ![0, 1, 2].contains(specifyIntonationKeyBehavior) {
      specifyIntonationKeyBehavior = 0
    }
    if ![0, 1, 2].contains(specifyShiftBackSpaceKeyBehavior) {
      specifyShiftBackSpaceKeyBehavior = 0
    }
    if ![0, 1, 2].contains(upperCaseLetterKeyBehavior) {
      upperCaseLetterKeyBehavior = 0
    }
    if ![0, 1, 2].contains(shiftKeyAccommodationBehavior) {
      shiftKeyAccommodationBehavior = 0
    }
  }
}
