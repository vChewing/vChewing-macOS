// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import TrieKit

// MARK: - LXAssembly.LXGramSupplyHub

extension LXAssembly {
  /// 多來源元圖供應中樞：把任意數量的 `LexiconGramSupplierProtocol` 掛載成單一來源。
  ///
  /// 合流政策由 `concatFlags` 決定：預設（空集合）為「原樣串接、依掛載順序」，
  /// 也可要求 `[.sort]`、`[.deduplicate]` 或 `.all`。
  /// `hasGrams` 一律採「任一來源在庫即在庫」。
  nonisolated public final class LXGramSupplyHub: LexiconGramSupplierProtocol {
    // MARK: Lifecycle

    public init(concatFlags: LXAssembly.GramConcatFlags = []) {
      self.concatFlags = concatFlags
    }

    // MARK: Public

    /// 合流時套用的整理標記。
    public var concatFlags: LXAssembly.GramConcatFlags = []

    /// 目前已掛載的來源，依掛載順序。
    public private(set) var mountedSuppliers: [any LexiconGramSupplierProtocol] = []

    /// 掛載異動世代計數器：每次掛載／卸載遞增。
    /// 供 `LXFacade` 的查詢結果快取指紋使用，確保掛載異動後舊快取自動失效。
    public private(set) var generation: Int = 0

    public func mount(_ supplier: any LexiconGramSupplierProtocol) {
      mountedSuppliers.append(supplier)
      generation &+= 1
    }

    public func unmountAll() {
      guard !mountedSuppliers.isEmpty else { return }
      mountedSuppliers.removeAll()
      generation &+= 1
    }

    public func hasGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysHandler: ((Set<[String]>) -> ())?
    )
      -> Bool {
      guard !mountedSuppliers.isEmpty, !keys.isEmpty else { return false }
      var partiallyMatchedKeys: Set<[String]> = []
      defer { partiallyMatchedKeysHandler?(partiallyMatchedKeys) }
      return LXAssembly.concatGramAvailabilityCheckResults {
        for supplier in mountedSuppliers {
          supplier.hasGrams(
            keys,
            filterType: filterType,
            partiallyMatch: partiallyMatch
          ) { matchedKeys in
            partiallyMatchedKeys.formUnion(matchedKeys)
          }
        }
      }
    }

    public func queryGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())?
    )
      -> [Homa.Gram] {
      guard !mountedSuppliers.isEmpty, !keys.isEmpty else { return [] }
      var partiallyMatchedKeys: Set<[String]> = []
      defer { partiallyMatchedKeysPostHandler?(partiallyMatchedKeys) }
      let concatenated: [Homa.Gram]? = LXAssembly.concatGramQueryResults(flags: concatFlags) {
        for supplier in mountedSuppliers {
          supplier.queryGrams(
            keys,
            filterType: filterType,
            partiallyMatch: partiallyMatch
          ) { matchedKeys in
            partiallyMatchedKeys.formUnion(matchedKeys)
          }
        }
      }
      return concatenated ?? []
    }

    public func queryAssociatedPhrasesAsGrams(
      _ previous: (keyArray: [String], value: String),
      anterior anteriorValue: String?,
      filterType: VanguardTrie.Trie.EntryType
    )
      -> [Homa.Gram]? {
      guard !mountedSuppliers.isEmpty else { return nil }
      return LXAssembly.concatGramQueryResults(flags: concatFlags) {
        for supplier in mountedSuppliers {
          supplier.queryAssociatedPhrasesAsGrams(
            previous,
            anterior: anteriorValue,
            filterType: filterType
          )
        }
      }
    }
  }
}

// MARK: - LXAssembly.LXFactoryGramSupplier

extension LXAssembly {
  /// 把原廠辭典後端（`VanguardTrie.TextMapTrie`）包成可掛載的來源。
  ///
  /// 每次查詢都即時向 `LXFacade.factoryTrie` 取值，故原廠辭典被重新連接或卸載之後，
  /// 本供應器無須重新掛載即反映最新狀態。
  ///
  /// - Warning: 本供應器提供的是**未經後處理**的原始元圖（不施假名抑制、不補半形變體、
  ///   不改權重正負號、不走語言模組替換）。若同時把它掛進 `LXFacade`，同一批原廠資料
  ///   會與內建原廠查詢路徑重複供應；僅在宿主自行組裝中樞時才適合單獨使用。
  nonisolated public final class LXFactoryGramSupplier: LexiconGramSupplierProtocol {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func hasGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysHandler: ((Set<[String]>) -> ())?
    )
      -> Bool {
      guard let trie = LXAssembly.LXFacade.factoryTrie else { return false }
      return trie.hasGrams(
        keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        partiallyMatchedKeysHandler: partiallyMatchedKeysHandler
      )
    }

    public func queryGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())?
    )
      -> [Homa.Gram] {
      guard let trie = LXAssembly.LXFacade.factoryTrie else { return [] }
      let trieGrams = trie.queryGrams(
        keys,
        filterType: filterType,
        partiallyMatch: partiallyMatch,
        partiallyMatchedKeysPostHandler: partiallyMatchedKeysPostHandler
      )
      return trieGrams.map(Homa.Gram.init)
    }

    public func queryAssociatedPhrasesAsGrams(
      _ previous: (keyArray: [String], value: String),
      anterior anteriorValue: String?,
      filterType: VanguardTrie.Trie.EntryType
    )
      -> [Homa.Gram]? {
      guard let trie = LXAssembly.LXFacade.factoryTrie else { return nil }
      return trie.queryAssociatedPhrasesAsGrams(
        previous,
        anterior: anteriorValue,
        filterType: filterType
      )?.map(Homa.Gram.init)
    }
  }
}
