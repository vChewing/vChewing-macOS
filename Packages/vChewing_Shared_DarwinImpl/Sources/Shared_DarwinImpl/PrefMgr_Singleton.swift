// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

// MARK: - PrefMgr Singleton (Darwin Implementation)

// 此單例原先定義於 MainAssembly4Darwin 的 PrefMgr_Singleton.swift，
// 但因為 vChewing_SettingsUI 不得依賴 MainAssembly4Darwin，
// 故將此單例與選字鍵驗證函式移至 Shared_DarwinImpl，供兩個模組共用。

extension PrefMgr {
  /// 偏好設定單例。與 `sharedSansDidSetOps` 不同，此單例已掛載
  /// `didAskForRefreshingSpeechSputnik` 與 `candidateKeyValidator`；
  /// 而 `didAskForSyncingLMPrefs` 與 `didAskForSyncingShiftKeyDetectorPrefs`
  /// 則由宿主（MainAssembly4Darwin）於啟動時另行注入（見 SettingsUIHost 的 wiring）。
  public static let shared: PrefMgr = {
    var result = PrefMgr(
      didAskForRefreshingSpeechSputnik: { SpeechSputnik.shared.refreshStatus() }
    )
    result.candidateKeyValidator = { candidateKeys in
      result.validate(candidateKeys: candidateKeys)
    }
    return result
  }()
}

// MARK: Guarded Method for Validating Candidate Keys.

extension PrefMgrProtocol {
  public func validate(candidateKeys: String) -> String? {
    var excluded = ""
    // 這個選項只要不是 0，那就是這四個鍵都被佔用了。
    if candidateStateJKHLBehavior != 0 { excluded.append("jkhl") }
    if useShiftQuestionToCallServiceMenu { excluded.append("?") }
    excluded.append(IMEApp.isKeyboardJIS ? "_" : "`~")
    return CandidateKey.validate(keys: candidateKeys, excluding: excluded)
  }
}
