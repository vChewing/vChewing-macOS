// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import LexiconAssembly
@testable import LibVanguard
import LXAssemblyMaterials4Tests
import Shared
import Testing

// MARK: - TestEnvironment

/// 單一套件用例專屬之執行環境（P316）。
///
/// 每個用例各自 `let env = TestEnvironment()`，於是：
/// - 辭典（`FactoryDictionary`）各自一份：連上／斷開測試辭典只影響本用例。
/// - 宿主（`SessionHost`）各自一份：`SessionHost.shared` 不再被測試改寫。
/// - 偏好（`PrefMgr(store:)`）各自一份：記憶體容器不再需要「換全域」。
///
/// 全域偏好容器（`OSUtils.defaultsStore`）亦不再被本環境改寫：需要 `UserDef` 之
/// 交換 API 者一律以顯式參數傳入 `store`。
final class TestEnvironment {
  // MARK: Lifecycle

  init(textMapData: String = LXATestsData.textMapTestCoreLXData) {
    self.store = InMemoryDefaultsStore()
    OSUtils.isRunningUnitTests = true
    UserDef.resetAll(store: store)
    prefs = PrefMgr(store: store)
    let prefs = prefs
    host.prefs = { prefs }
    host.isCoreDBConnected = { true }
    host.factoryDictionary = LXAssembly.LXFacade.makeTestFactoryDictionary(textMapData: textMapData)
    let factory = host.factoryDictionary
    self._lxCHT = LXAssembly.LXFacade(isCHS: false, prefs: prefs, factory: factory)
    self._lxCHS = LXAssembly.LXFacade(isCHS: true, prefs: prefs, factory: factory)
  }

  // MARK: Internal

  let host = SessionHost()
  let store: InMemoryDefaultsStore
  let prefs: PrefMgr

  /// 本環境之簡體中文側辭典副本。
  var lxCHS: LXAssembly.LXFacade { _lxCHS }
  /// 本環境之繁體中文側辭典副本。
  var lxCHT: LXAssembly.LXFacade { _lxCHT }
  /// 慣用之辭典副本（繁體中文）。
  var lx: LXAssembly.LXFacade { lxCHT }

  // MARK: Private

  private let _lxCHS: LXAssembly.LXFacade
  private let _lxCHT: LXAssembly.LXFacade
}
