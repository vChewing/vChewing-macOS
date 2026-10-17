// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 偏好容器之實例化縫（P315）。
//
// 本套房證明：`PrefMgr` 一旦以 `init(store:)` 建構，其全部 `@AppProperty` 成員即綁定該容器、
// 不再回看 `OSUtils.defaultsStore` 這顆行程級全域。故兩個實例可各自服務不同容器而互不相擾，
// 單元測試亦得在完全不置換全域的前提下隔離——這正是 `UserDefExchangeTests` 之外的新路徑。

import Foundation
@testable import Shared
import Testing

@Suite("偏好容器之實例化縫")
struct PrefMgrInstanceStoreTests {
  @Test("兩實例各持一容器：寫入互不相見，亦不觸及行程級全域")
  func instancesDoNotShareStore() {
    let storeA = InMemoryDefaultsStore()
    let storeB = InMemoryDefaultsStore()
    let globalStore = OSUtils.defaultsStore
    let probeKey = UserDef.kCandidateListTextSize.rawValue

    let prefsA = PrefMgr(store: storeA)
    let prefsB = PrefMgr(store: storeB)

    prefsA.candidateListTextSize = 42

    #expect(prefsA.candidateListTextSize == 42)
    #expect(prefsB.candidateListTextSize != 42)
    #expect(storeA.object(forKey: probeKey) as? Int == 42)
    #expect(storeB.object(forKey: probeKey) as? Int != 42)
    // 行程級全域自始至終未被本用例改動過。
    #expect(OSUtils.defaultsStore === globalStore)
  }

  @Test("注入容器之實例：didSet 回呼照常觸發")
  func didSetStillFiresOnInjectedStore() {
    let store = InMemoryDefaultsStore()
    var fired = 0
    let prefs = PrefMgr(didAskForSyncingLMPrefs: { fired += 1 }, store: store)
    #expect(fired == 0)
    prefs.userPhrasesDatabaseBypassed.toggle()
    #expect(fired == 1)
  }

  @Test("sharedSansDidSetOps 依當前全域容器解析：換容器即換實例")
  func sharedTracksProcessWideStore() {
    let saved = OSUtils.defaultsStore
    defer { OSUtils.defaultsStore = saved }

    OSUtils.defaultsStore = InMemoryDefaultsStore()
    let first = PrefMgr.sharedSansDidSetOps
    #expect(first === PrefMgr.sharedSansDidSetOps)
    #expect(first.store === OSUtils.defaultsStore)

    OSUtils.defaultsStore = InMemoryDefaultsStore()
    let second = PrefMgr.sharedSansDidSetOps
    #expect(second !== first)
    #expect(second.store === OSUtils.defaultsStore)

    OSUtils.defaultsStore = saved
    #expect(PrefMgr.sharedSansDidSetOps.store === saved)
  }
}
