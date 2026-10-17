// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import LXAssemblyMaterials4Tests
import Shared
import Testing

@testable import LexiconAssembly
@testable import LibVanguard

// MARK: - LibVanguardTestsRoot.TestEnvironmentTests

/// 驗證 P316 之核心不變式：兩份 `TestEnvironment` 之間沒有任何行程級共享。
///
/// 這是「`LibVanguardTests` 得以並行」的根據：若下列任一斷言失敗，各 suite 便會互相踩踏，
/// 屆時必須把 `.serialized` 加回去，而不是放任偶發紅燈。
extension LibVanguardTestsRoot {
  @Suite("TestEnvironmentIsolation")
  final class TestEnvironmentTests {
    @Test("Two environments own distinct factories")
    func twoEnvironmentsOwnDistinctFactories() {
      let envA = TestEnvironment()
      let envB = TestEnvironment()

      #expect(envA.host.factoryDictionary !== envB.host.factoryDictionary)
      #expect(envA.lx.factory === envA.host.factoryDictionary)
      #expect(envB.lx.factory === envB.host.factoryDictionary)

      // 兩份辭典都各自載入了測試用 TextMap，故與行程級共享者無涉。
      #expect(envA.host.factoryDictionary.trie != nil)
      #expect(envB.host.factoryDictionary.trie != nil)
      #expect(envA.host.factoryDictionary !== FactoryDictionary.shared)
    }

    @Test("Two environments own distinct preference stores")
    func twoEnvironmentsOwnDistinctPreferenceStores() {
      let envA = TestEnvironment()
      let envB = TestEnvironment()

      envA.prefs.candidateKeys = "asdfghjkl"
      envB.prefs.candidateKeys = "123456789"

      #expect(envA.prefs.candidateKeys == "asdfghjkl")
      #expect(envB.prefs.candidateKeys == "123456789")
      #expect(envA.store !== envB.store)
    }

    @Test("Disconnecting one factory dictionary leaves the other intact")
    func disconnectingOneFactoryDictionaryLeavesOtherIntact() {
      let envA = TestEnvironment()
      let envB = TestEnvironment()

      envA.lx.disconnectFactoryDictionary()

      #expect(envA.host.factoryDictionary.trie == nil)
      #expect(envB.host.factoryDictionary.trie != nil)
    }
  }
}
