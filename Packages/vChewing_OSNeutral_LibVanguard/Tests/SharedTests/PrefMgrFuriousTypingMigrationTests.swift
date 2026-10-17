// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 狂打開關之鍵遷移測試。
//
// `"FuriousTypingEnabled"` → `"FuriousTypingEnabled4Pinyin"`（承接舊值）
//                          ＋ `"FuriousTypingEnabled4Zhuyin"`（**不**承接，維持出廠預設 `false`）。
//
// - Important: 被測之 `migrateDeprecatedSettings()` 與 `@AppProperty` 之讀寫現皆以
//   `OSUtils.defaultsStore` 為據（見 `PrefMgr_Core.swift`），故兩者天然落在同一個 domain，
//   無須再強制 `OSUtils.isRunningUnitTests` 之真偽，亦不再碰觸 `UserDefaults.standard`。
// - Important: `migrateDeprecatedSettings()` 為 `private`，唯一入口是 `fixOddPreferencesCore()`。
//   該函式於每次 `InputSession.activateServer()` 執行，故**冪等**是硬性要求（測試 ④）。
// - Note: `@AppProperty` 之 `init` 會自我註冊出廠預設值。
//   故凡「先壓成非預設值、再驗證遷移把它改回來」之斷言，都必須在**建立 `PrefMgr()` 之後**
//   才壓值——否則測到的是註冊、不是遷移。

import Foundation
@testable import Shared
import Testing

@Suite("狂打開關之鍵遷移")
struct PrefMgrFuriousTypingMigrationTests {
  // MARK: Internal

  @Test("① 舊鍵為 true → 拼音側承接為 true、舊鍵消失")
  func legacyTrueIsCarriedToPinyin() {
    withCleanDefaults { defaults in
      defaults.set(true, forKey: Self.legacyKey)
      let prefs = PrefMgr(store: defaults)
      // 建立之後才壓成 false ⇒ 若最終為 true，其來源必是遷移碼而非註冊。
      defaults.set(false, forKey: Self.pinyinKey)
      prefs.fixOddPreferencesCore()
      #expect(defaults.bool(forKey: Self.pinyinKey))
      #expect(prefs.furiousTypingEnabled4Pinyin)
      #expect(defaults.object(forKey: Self.legacyKey) == nil)
    }
  }

  @Test("② 舊鍵為 false → 拼音側承接為 false")
  func legacyFalseIsCarriedToPinyin() {
    withCleanDefaults { defaults in
      defaults.set(false, forKey: Self.legacyKey)
      let prefs = PrefMgr(store: defaults)
      defaults.set(true, forKey: Self.pinyinKey) // 先壓成 true，確保 false 來自遷移。
      prefs.fixOddPreferencesCore()
      #expect(!defaults.bool(forKey: Self.pinyinKey))
      #expect(!prefs.furiousTypingEnabled4Pinyin)
      #expect(defaults.object(forKey: Self.legacyKey) == nil)
    }
  }

  @Test("③ 舊鍵不存在 → 兩側皆不動（不重設為出廠值）")
  func absentLegacyKeyLeavesBothSidesAlone() {
    withCleanDefaults { defaults in
      let prefs = PrefMgr(store: defaults)
      // 人為把兩側都推離出廠值；若遷移碼誤以「無條件寫入」實作，這裡就會被抓到。
      defaults.set(false, forKey: Self.pinyinKey)
      defaults.set(true, forKey: Self.zhuyinKey)
      prefs.fixOddPreferencesCore()
      #expect(!defaults.bool(forKey: Self.pinyinKey))
      #expect(defaults.bool(forKey: Self.zhuyinKey))
      #expect(defaults.object(forKey: Self.legacyKey) == nil)
    }
  }

  @Test("④ 冪等：連跑兩次之結果相同（舊鍵為 true 與 false 兩種情形）")
  func migrationIsIdempotent() {
    for legacyValue in [true, false] {
      withCleanDefaults { defaults in
        defaults.set(legacyValue, forKey: Self.legacyKey)
        let prefs = PrefMgr(store: defaults)
        prefs.fixOddPreferencesCore()
        let afterFirst = Self.snapshot(defaults)
        prefs.fixOddPreferencesCore()
        let afterSecond = Self.snapshot(defaults)
        #expect(afterFirst == afterSecond, "legacyValue=\(legacyValue)")
        #expect(defaults.bool(forKey: Self.pinyinKey) == legacyValue)
        #expect(defaults.object(forKey: Self.legacyKey) == nil)
      }
    }
  }

  @Test("⑤ 注音側於三種情形下皆為出廠預設 false（不承接舊值）")
  func zhuyinSideNeverInherits() {
    // 三種情形：舊鍵為 true／為 false／不存在。
    for legacyValue in [true, false] as [Bool?] + [nil] {
      withCleanDefaults { defaults in
        if let legacyValue { defaults.set(legacyValue, forKey: Self.legacyKey) }
        let prefs = PrefMgr(store: defaults)
        prefs.fixOddPreferencesCore()
        #expect(!prefs.furiousTypingEnabled4Zhuyin, "legacy=\(String(describing: legacyValue))")
        #expect(!defaults.bool(forKey: Self.zhuyinKey))
      }
    }
  }

  @Test("⑥ 遷移不影響既有之五段舊遷移")
  func migrationDoesNotDisturbTheOlderSegments() {
    withCleanDefaults { defaults in
      // 本段（狂打）之輸入。
      defaults.set(true, forKey: Self.legacyKey)
      // 既有五段之輸入。
      defaults.set(true, forKey: "UseJKtoMoveCompositorCursorInCandidateState")
      defaults.set(false, forKey: "UseHLtoMoveCompositorCursorInCandidateState")
      defaults.set(false, forKey: "ChooseCandidateUsingSpace")
      defaults.set(0, forKey: "KeyboardParser") // < 100 ⇒ 注音系
      defaults.set(true, forKey: "ChineseConversionEnabled")
      defaults.set(false, forKey: "ShiftJISShinjitaiOutputEnabled")
      defaults.set(false, forKey: "UsingHotKeyHalfWidthASCII")

      let prefs = PrefMgr(store: defaults)
      prefs.fixOddPreferencesCore()

      // ① 本案：拼音側承接、舊鍵消失。
      #expect(prefs.furiousTypingEnabled4Pinyin)
      #expect(defaults.object(forKey: Self.legacyKey) == nil)

      // ② 段一：JK/HL 選字窗行為（(true, false) → 1），舊鍵已清。
      #expect(prefs.candidateStateJKHLBehavior == 1)
      #expect(defaults.object(forKey: "UseJKtoMoveCompositorCursorInCandidateState") == nil)
      #expect(defaults.object(forKey: "UseHLtoMoveCompositorCursorInCandidateState") == nil)

      // ③ 段二：Space 鍵對內文組字區之行為（舊 Bool → 新 Int），舊鍵已清。
      #expect(prefs.spaceKeyBehaviorAgainstICB == 0)
      #expect(defaults.object(forKey: "ChooseCandidateUsingSpace") == nil)

      // ④ 段三：單一 KeyboardParser → 雙槽位（< 100 ⇒ 注音側），舊鍵已清。
      #expect(prefs.keyboardParser4Zhuyin == 0)
      #expect(!prefs.pinyinTypingEnabled)
      #expect(defaults.object(forKey: "KeyboardParser") == nil)

      // ⑤ 段四：康熙／JIS 兩布林 → 漢字轉換枚舉（(true, false) → 1），舊鍵已清。
      #expect(prefs.kanjiConversionPreferences == 1)
      #expect(defaults.object(forKey: "ChineseConversionEnabled") == nil)
      #expect(defaults.object(forKey: "ShiftJISShinjitaiOutputEnabled") == nil)

      // ⑥ 段五：半形標點熱鍵 pref 更名，舊鍵已清。
      #expect(!prefs.usingHotKeyHalfWidthPunctuation)
      #expect(defaults.object(forKey: "UsingHotKeyHalfWidthASCII") == nil)
    }
  }

  // MARK: Private

  private static let legacyKey = "FuriousTypingEnabled"
  private static let pinyinKey = UserDef.kFuriousTypingEnabled4Pinyin.rawValue
  private static let zhuyinKey = UserDef.kFuriousTypingEnabled4Zhuyin.rawValue

  /// 某鍵之現值快照（含「不存在」與「存在但為 false」之區分）。
  private static func snapshot(_ store: InMemoryDefaultsStore) -> [String: Bool?] {
    var result: [String: Bool?] = [:]
    [legacyKey, pinyinKey, zhuyinKey].forEach { key in
      result[key] = store.object(forKey: key) == nil ? nil : store.bool(forKey: key)
    }
    return result
  }

  /// 於**全新的記憶體容器**內執行：容器不觸及磁碟、不跨行程，故無須清理或還原任何鍵，
  /// 亦不存在「跨測試共用之 `UserDefaults.standard`」所導致的輸出鍵殘留問題。
  private func withCleanDefaults(_ body: (InMemoryDefaultsStore) -> ()) {
    // 每一測試用例各得一份全新的記憶體容器，且**不**經行程級全域：
    // 偏好管理器直接綁定該容器，故用例之間、套房之間皆無共享狀態。
    body(InMemoryDefaultsStore())
  }
}
