// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import TrieKit

// MARK: - LXAssembly.LexiconGramSupplierProtocol

extension LXAssembly {
  /// 語言模組來源（Language Model Gram Supplier）的統一供應協定。
  ///
  /// 只要某個物件能回答「給定讀音索引鍵是否存在元圖」與「取出該索引鍵的元圖」，
  /// 就可以被掛載成一個辭典來源。`LXFacade.mountGramSupplier(_:)` 接受任意本協定
  /// 的實作者，故辭典來源可插拔：多來源掛載、測試替身、宿主自帶辭典皆走同一介面。
  ///
  /// - Important: 本協定限定參照語意（`AnyObject`），因為來源是以「參照」被掛載、而非被複製。
  ///   唯音自身的子語言模組（`LXCoreEX`、`LXCassette`、`LXAssociates`）皆為值型別、
  ///   由 `LXFacade` 就地持有，故不實作本協定；它們的內容仍由 `LXFacade` 直接供給。
  public protocol LexiconGramSupplierProtocol: AnyObject {
    /// 確認給定讀音索引鍵是否存在元圖。
    /// - Parameters:
    ///   - keys: 讀音索引鍵陣列。
    ///   - filterType: 條目型別過濾；傳入空集合代表不過濾。
    ///   - partiallyMatch: 是否啟用逐位置前綴部分匹配。
    ///   - partiallyMatchedKeysHandler: 實際命中的索引鍵集合的回報通道。
    /// - Returns: 是否存在元圖。
    func hasGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysHandler: ((Set<[String]>) -> ())?
    )
      -> Bool

    /// 取出給定讀音索引鍵的元圖。
    /// - Parameters:
    ///   - keys: 讀音索引鍵陣列。
    ///   - filterType: 條目型別過濾；傳入空集合代表不過濾。
    ///   - partiallyMatch: 是否啟用逐位置前綴部分匹配。
    ///   - partiallyMatchedKeysPostHandler: 實際命中的索引鍵集合的回報通道。
    /// - Returns: 元圖陣列。
    func queryGrams(
      _ keys: [String],
      filterType: VanguardTrie.Trie.EntryType,
      partiallyMatch: Bool,
      partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())?
    )
      -> [Homa.Gram]

    /// 關聯詞語檢索。
    /// - Parameters:
    ///   - previous: 前一個詞對（讀音索引鍵陣列 ＋ 詞值）。
    ///   - anteriorValue: 前前詞值；傳入空字串代表「僅取無 anterior 者」。
    ///   - filterType: 條目型別過濾；傳入空集合代表不過濾。
    /// - Returns: 元圖陣列；無結果時為 `nil`。
    func queryAssociatedPhrasesAsGrams(
      _ previous: (keyArray: [String], value: String),
      anterior anteriorValue: String?,
      filterType: VanguardTrie.Trie.EntryType
    )
      -> [Homa.Gram]?
  }
}

// MARK: - Default Arguments

extension LXAssembly.LexiconGramSupplierProtocol {
  public func queryGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool = false,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())? = nil
  )
    -> [Homa.Gram] {
    queryGrams(
      keys,
      filterType: filterType,
      partiallyMatch: partiallyMatch,
      partiallyMatchedKeysPostHandler: partiallyMatchedKeysPostHandler
    )
  }

  public func hasGrams(
    _ keys: [String],
    filterType: VanguardTrie.Trie.EntryType,
    partiallyMatch: Bool = false,
    partiallyMatchedKeysHandler: ((Set<[String]>) -> ())? = nil
  )
    -> Bool {
    hasGrams(
      keys,
      filterType: filterType,
      partiallyMatch: partiallyMatch,
      partiallyMatchedKeysHandler: partiallyMatchedKeysHandler
    )
  }

  public func queryAssociatedPhrasesAsGrams(
    _ previous: (keyArray: [String], value: String),
    anterior anteriorValue: String? = nil,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [Homa.Gram]? {
    queryAssociatedPhrasesAsGrams(previous, anterior: anteriorValue, filterType: filterType)
  }

  /// 關聯詞語檢索的平文版：僅回傳「讀音索引鍵 ＋ 詞值」，且在切除前綴幅長之後依字面去重。
  ///
  /// 與 `VanguardTrieProtocol.queryAssociatedPhrasesPlain` 語義一致（僅資料容器由
  /// `VanguardTrie.TrieGram` 換成 `Homa.Gram`）。主要供ㄅ半模式使用。
  public func queryAssociatedPhrasesPlain(
    _ previous: (keyArray: [String], value: String),
    anterior anteriorValue: String? = nil,
    filterType: VanguardTrie.Trie.EntryType
  )
    -> [(keyArray: [String], value: String)]? {
    let rawResults = queryAssociatedPhrasesAsGrams(
      previous,
      anterior: anteriorValue,
      filterType: filterType
    )
    guard let rawResults else { return nil }
    let prevSegLength = previous.keyArray.count
    var results = [(keyArray: [String], value: String)]()
    var inserted = Set<Int>()
    rawResults.forEach { entry in
      let newResult = (
        keyArray: Array(entry.keyArray[prevSegLength...]),
        value: entry.current.map(\.description)[prevSegLength...].joined()
      )
      // 此處只能用基於 String 的 Hash（與既有實作一致）。
      let theHash = "\(newResult)".hashValue
      guard inserted.insert(theHash).inserted else { return }
      results.append(newResult)
    }
    guard !results.isEmpty else { return nil }
    return results
  }
}

// MARK: - VanguardTrie.TrieGram → Homa.Gram

extension Homa.Gram {
  /// 由 TrieKit 的原廠辭典檢索結果直接轉換；欄位逐一對應，不做任何後處理
  /// （不施假名抑制、不補半形變體、不改權重正負號）。
  @inlinable
  public init(_ trieGram: VanguardTrie.TrieGram) {
    self.init(
      keyArray: trieGram.keyArray,
      current: trieGram.value,
      previous: trieGram.previous,
      anterior: trieGram.anterior,
      probability: trieGram.probability
    )
  }
}
