// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import TrieKit

// MARK: - 多來源掛載（對外）

extension LXAssembly.LXFacade {
  /// 目前已掛載的「額外」語言模組來源，依掛載順序。
  ///
  /// 原廠辭典與各使用者子模組不在此列——它們由 `LXFacade` 自身直接供給；
  /// 本清單只承載宿主或測試額外掛上的來源。
  public var mountedGramSuppliers: [any LXAssembly.LexiconGramSupplierProtocol] {
    gramSupplyHub.mountedSuppliers
  }

  /// 掛載額外的語言模組來源（多來源掛載）。
  ///
  /// 掛載後，該來源的元圖會併入一般查詢（`unigramsFor`）的結果，
  /// 且其存在性會被輕量版在庫檢查（`hasUnigramsForFast`）承認。
  /// 掛載異動會使查詢結果快取失效。
  public func mountGramSupplier(_ supplier: any LXAssembly.LexiconGramSupplierProtocol) {
    gramSupplyHub.mount(supplier)
  }

  /// 卸載所有額外掛載的語言模組來源。
  public func unmountAllGramSuppliers() {
    gramSupplyHub.unmountAll()
  }
}

// MARK: - 供查詢管線使用的內部接點

extension LXAssembly.LXFacade {
  /// 合流所有額外掛載來源的元圖。
  /// - Parameter partiallyMatch: 是否啟用逐位置前綴部分匹配。
  /// - Returns: 合流後的元圖陣列；無掛載來源時為空陣列。
  func mountedSupplierGrams(keyArray: [String], partiallyMatch: Bool) -> [Homa.Gram] {
    gramSupplyHub.queryGrams(keyArray, filterType: [], partiallyMatch: partiallyMatch)
  }

  /// 任一額外掛載來源是否在庫。
  func mountedSuppliersHasGrams(keyArray: [String], partiallyMatch: Bool) -> Bool {
    gramSupplyHub.hasGrams(keyArray, filterType: [], partiallyMatch: partiallyMatch)
  }
}
