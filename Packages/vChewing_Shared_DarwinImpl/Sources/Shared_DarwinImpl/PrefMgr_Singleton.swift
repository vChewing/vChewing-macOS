// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

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
  /// 依當前儲存後端取得共用之 `PrefMgr`：同一後端只會有一份實例，換過後端即換一份實例。
  /// 這與 `sharedSansDidSetOps` 之取法一致——兩者皆不得把建構當下之 `OSUtils.defaultsStore`
  /// 永久捕獲，否則測試把全域換成記憶體容器之後，經此單例之讀寫仍會落在舊後端上
  /// （`LXMgr` 之磁帶路徑即同時經此單例與 `OSUtils.defaultsStore` 讀寫，兩者必須看同一份）。
  public static var shared: PrefMgr {
    let store = OSUtils.defaultsStore
    let key = ObjectIdentifier(store as AnyObject)
    return sharedCache.withLock { cache -> PrefMgr in
      if let cached = cache[key] { return cached }
      let made = PrefMgr(
        didAskForRefreshingSpeechSputnik: { SpeechSputnik.shared.refreshStatus() },
        store: store
      )
      made.candidateKeyValidator = { candidateKeys in
        made.validate(candidateKeys: candidateKeys)
      }
      cache[key] = made
      return made
    }
  }

  private static let sharedCache = NSMutex<[ObjectIdentifier: PrefMgr]>([:])
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
