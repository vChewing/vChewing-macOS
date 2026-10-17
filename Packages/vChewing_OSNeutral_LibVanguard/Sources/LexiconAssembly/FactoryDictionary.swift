// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import TrieKit

// MARK: - FactoryDictionary

/// 原廠辭典、磁帶資料、注音文資料的持有者（P316）。
///
/// 這三項在 `LXFacade` 尚為「靜態命名空間」時是行程級全域，於是「換一份辭典」必然是全有全無：
/// 任何一份 `LXFacade` 實例都無從持有自己的一份，兩個測試套房也不可能真並行。
/// 本型別把它們收攏成一個可被注入的物件：
///
/// - 生產：`FactoryDictionary.shared` 由 `Shared.InputMode.lexicon` 之兩份實例共持
///   ——同一份 TextMap 只解析一次、反查索引只建一次，行為與記憶體佔用皆與舊制相同。
/// - 測試：各套房自持一份，於是「連上測試辭典」與「斷開」只影響該套房自己。
///
/// 「世代計數器」亦隨之搬家：辭典與磁帶的異動只令**持有該份資料**的實例之查詢快取失效，
/// 不再因為別處換了一張磁帶而全體作廢。
public final class FactoryDictionary: @unchecked Sendable {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  /// 預設共享實例（生產環境與舊有靜態 API 之落點）。
  public static var shared = FactoryDictionary()

  /// 原廠辭典（TextMapTrie）。指派即遞增辭典世代。
  public var trie: VanguardTrie.TextMapTrie? {
    didSet {
      dictionaryGeneration &+= 1
    }
  }

  // MARK: Internal

  var plainBopomofo = LXAssembly.LXPlainBopomofo()

  /// 原廠辭典世代計數器。
  private(set) var dictionaryGeneration: Int = 0
  /// 磁帶資料世代計數器。
  private(set) var cassetteGeneration: Int = 0

  /// 磁帶資料（唯讀使用；中繼資料由 `LXCassette` 自身提供）。指派即遞增磁帶世代。
  var cassette = LXAssembly.LXCassette() {
    didSet {
      cassetteGeneration &+= 1
    }
  }

  /// 磁帶內容就地變更（而非整顆替換）時，由呼叫端明確遞增世代。
  func bumpCassetteGeneration() {
    cassetteGeneration &+= 1
  }

  /// 辭典內容就地變更時，由呼叫端明確遞增世代。
  func bumpDictionaryGeneration() {
    dictionaryGeneration &+= 1
  }
}
