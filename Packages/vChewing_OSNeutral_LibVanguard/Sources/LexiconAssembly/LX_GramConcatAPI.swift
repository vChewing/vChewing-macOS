// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import SwiftExtension

// MARK: - LXAssembly.GramConcatFlags

extension LXAssembly {
  /// 多來源元圖合流時的整理標記。
  ///
  /// 空集合即「原樣串接」——依來源掛載順序保留所有結果（含重複），完全不動次序。
  public struct GramConcatFlags: OptionSet, Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(rawValue: UInt) {
      self.rawValue = rawValue
    }

    // MARK: Public

    /// 依 `LXAssembly.sortGrams` 的既定次序排序（長度降冪 → 讀音索引鍵字面升冪 → 權重降冪）。
    public static let sort = Self(rawValue: 1 << 1)
    /// 依元圖身分雜湊去除重複，保留最先出現者。
    public static let deduplicate = Self(rawValue: 1 << 2)
    public static let all: Self = [.sort, .deduplicate]

    public let rawValue: UInt
  }
}

// MARK: - LXAssembly.concatGramAvailabilityCheckResults

extension LXAssembly {
  /// 用以統整「多來源在庫檢查」結果的 API：只要任一來源在庫即在庫。
  /// - Parameter subResults: 各來源的在庫檢查結果；`nil` 視為「該來源未表態」（等同 `false`）。
  public static func concatGramAvailabilityCheckResults(
    @ArrayBuilder<Bool?> subResults: () -> [Bool?]
  )
    -> Bool {
    subResults().reduce(false) { $0 || $1 ?? false }
  }

  /// 用以統整「多來源元圖檢索結果」的 API。
  /// - Parameters:
  ///   - flags: 整理時要做的事情的標記。
  ///   - forbiddenKeyValueHashes: 用以過濾結果的元圖身分雜湊集合；非空時改以該集合作為唯一過濾依據
  ///     （此時 `.deduplicate` 不再另行去重，語義與 LibVanguard 的同名 API 一致）。
  ///   - grams: 各來源的檢索結果；`nil` 代表該來源未表態（略過）。
  /// - Remark: 雜湊的生成方法為 `LXAssembly.makeGramIdentityHash(_:)`。
  /// - Returns: 整理後的結果；全空時回傳 `nil`。
  public static func concatGramQueryResults(
    flags: GramConcatFlags = [],
    forbiddenKeyValueHashes: Set<Int> = [],
    @ArrayBuilder<[Homa.Gram]?> grams: () -> [[Homa.Gram]?]
  )
    -> [Homa.Gram]? {
    var concatenated: [Homa.Gram] = grams().compactMap { $0 }.flatMap { $0 }
    guard !concatenated.isEmpty else { return nil }
    if flags.contains(.sort) { concatenated.sort(by: Self.sortGrams) }
    var insertedThings: Set<Int> = []
    concatenated = concatenated.compactMap { theGram in
      let kvHash = makeGramIdentityHash(theGram)
      if !forbiddenKeyValueHashes.isEmpty {
        guard !forbiddenKeyValueHashes.contains(kvHash) else { return nil }
        return theGram
      }
      if flags.contains(.deduplicate) {
        return insertedThings.insert(kvHash).inserted ? theGram : nil
      }
      return theGram
    }
    return concatenated
  }

  /// 元圖的合流排序準則：幅長降冪 → 讀音索引鍵字面升冪 → 權重降冪。
  ///
  /// 這是「多來源合流」的既定政策，與 `Homa.Assembler` 內部的排序準則（先權重、後字面）
  /// 刻意不同：此處以幅長與讀音索引鍵為首要鍵，確保跨來源的同讀音者相鄰、便於人工核對。
  public static func sortGrams(_ lhs: Homa.Gram, _ rhs: Homa.Gram) -> Bool {
    if lhs.keyArray.count != rhs.keyArray.count {
      return lhs.keyArray.count > rhs.keyArray.count
    }
    if lhs.keyArray != rhs.keyArray {
      return lhs.keyArray.lexicographicallyPrecedes(rhs.keyArray)
    }
    return lhs.probability > rhs.probability
  }

  /// 元圖身分雜湊：以「讀音索引鍵 ＋ 詞值 ＋ 前驗詞值」為身分。
  ///
  /// - Note: 刻意不含 `anterior` 與權重——前者與本專案的歷史身分定義一致，
  ///   後者不屬於身分。兩個來源給出同讀音同詞值但權重不同者，會被視為同一筆。
  public static func makeGramIdentityHash(_ gram: Homa.Gram) -> Int {
    makeGramIdentityHash(keyArray: gram.keyArray, value: gram.current, previous: gram.previous)
  }

  /// 元圖身分雜湊的三元版本。
  public static func makeGramIdentityHash(
    keyArray: [String],
    value: String,
    previous: String?
  )
    -> Int {
    var hasher = Hasher()
    hasher.combine(keyArray)
    hasher.combine(value)
    hasher.combine(previous)
    return hasher.finalize()
  }
}
