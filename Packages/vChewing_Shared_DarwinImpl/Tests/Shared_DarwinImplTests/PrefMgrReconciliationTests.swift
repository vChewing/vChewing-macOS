// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
@testable import Shared
@testable import Shared_DarwinImpl
import Testing

/// `PrefMgr.reconcileAfterExternalPrefsImport()` 之測試。
///
/// 測試隔離比照 `Packages/vChewing_SettingsUI/Tests/SettingsUITests/CtlSettingsUITests.swift`：
/// 以本套件專屬 suite 覆蓋 `UserDefaults.current`（`UserDefaults.unitTests` ＋
/// `UserDefaults.pendingUnitTests`），並於 `deinit` 復原開關。
///
/// 未含 `UserDef.importFromDictionary` 之端到端斷言：該 API 屬 L1
/// （`Packages/vChewing_OSNeutral_LibVanguard`）之產物，本測試建立時尚未就緒。
@Suite(.serialized)
final class PrefMgrReconciliationTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.SharedDarwinImpl.UnitTests")
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
  }

  deinit {
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  /// 斷言「匯入後之和解」確實觸發三組推式副作用回呼。
  ///
  /// 以下數字即 `reconcileAfterExternalPrefsImport()` 所涵蓋之鍵數；日後新增帶 `didSet` 之偏好時，
  /// 該函式與本測試須一併更新。
  @Test
  func testReconcileTriggersAllPushBasedSideEffects() throws {
    var countSyncingLMPrefs = 0
    var countRefreshingSpeechSputnik = 0
    var countSyncingShiftKeyDetectorPrefs = 0
    let prefs = PrefMgr(
      didAskForSyncingLMPrefs: { countSyncingLMPrefs += 1 },
      didAskForRefreshingSpeechSputnik: { countRefreshingSpeechSputnik += 1 },
      didAskForSyncingShiftKeyDetectorPrefs: { countSyncingShiftKeyDetectorPrefs += 1 }
    )
    prefs.reconcileAfterExternalPrefsImport()
    // `didAskForSyncingLMPrefs` 恰 8 次：userPhrasesDatabaseBypassed、cns11643Enabled、
    // symbolInputEnabled、cassetteEnabled、suppressFactoryUnigramsOfKanaSyllables、
    // useSCPCTypingMode、phraseReplacementEnabled、associatedPhrasesEnabled。
    #expect(countSyncingLMPrefs == 8)
    // `didAskForRefreshingSpeechSputnik` 恰 1 次：readingNarrationCoverage。
    #expect(countRefreshingSpeechSputnik == 1)
    // `didAskForSyncingShiftKeyDetectorPrefs` 恰 2 次：togglingAlphanumericalModeWithLShift、
    // togglingAlphanumericalModeWithRShift。
    #expect(countSyncingShiftKeyDetectorPrefs == 2)
  }

  /// 斷言「匯入後之和解」亦已執行 `fixOddPreferencesCore()` 之值域與正規化。
  @Test
  func testReconcileNormalizesOutOfRangeValues() throws {
    let prefs = PrefMgr()
    // 直寫 `UserDefaults`：此即匯入路徑之行為，繞過 `@AppProperty` setter。
    UserDefaults.current.set(9_999, forKey: UserDef.kCandidateListTextSize.rawValue)
    UserDefaults.current.set(9_999, forKey: UserDef.kPopupCompositionBufferTextSize.rawValue)
    UserDefaults.current.set("ABCDDD", forKey: UserDef.kCandidateKeys.rawValue)
    prefs.reconcileAfterExternalPrefsImport()
    // 字級之自我夾限：12...196 與 18...40。
    #expect(prefs.candidateListTextSize == 196)
    #expect(prefs.popupCompositionBufferTextSize == 40)
    // 選字鍵之小寫化＋去重複（此處未掛 candidateKeyValidator，故不觸發「歸回預設」那一路）。
    #expect(prefs.candidateKeys == "abcd")
  }
}
