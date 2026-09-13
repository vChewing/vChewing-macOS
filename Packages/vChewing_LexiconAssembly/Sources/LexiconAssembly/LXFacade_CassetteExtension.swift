// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

extension LXAssembly.LXFacade {
  /// 磁帶模式專用：當前磁帶所規定的花牌鍵。
  public var cassetteWildcardKey: String { Self.lxCassette.wildcardKey }
  /// 磁帶模式專用：當前磁帶所規定的任意單字元鍵。
  public var cassetteAnySingleCharKey: String { Self.lxCassette.anySingleCharKey }
  /// 磁帶模式專用：當前磁帶規定的最大碼長。
  public var maxCassetteKeyLength: Int { Self.lxCassette.maxKeyLength }
  /// 磁帶模式專用：指定 `%quick` 快速候選結果當中要過濾掉的無效候選字符號。
  public var nullCandidateInCassette: String { Self.lxCassette.nullCandidate }
  /// 磁帶模式專用：選字鍵是否需要敲 Shift 才會生效。
  public var areCassetteCandidateKeysShiftHeld: Bool { Self.lxCassette.areCandidateKeysShiftHeld }
  /// 磁帶模式專用：需要直接递交的按键。
  public var keysToDirectlyCommit: String { Self.lxCassette.keysToDirectlyCommit }
  /// 磁帶模式專用：選字鍵，在唯音輸入法當中僅優先用於快速模式。
  public var cassetteSelectionKey: String? {
    let result = Self.lxCassette.selectionKeys
    return result.isEmpty ? nil : result
  }

  /// 磁帶模式專用：指定 `%quickphrases` 章節所定義的送詞鍵。
  public var cassetteQuickPhraseCommissionKey: String? {
    let key = Self.lxCassette.quickPhraseCommissionKey
    return key.isEmpty ? nil : key
  }

  /// 磁帶模式專用函式：調取 `%quickphrases` 詞彙候選結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  public func cassetteQuickPhrases(for key: String) -> [String]? {
    Self.lxCassette.quickPhrasesFor(key: key)
  }

  /// 磁帶模式專用函式：調取 `%symboldata` 符號選單查詢結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  public func cassetteSymbolDataFor(key: String) -> [String]? {
    guard let fetched = Self.lxCassette.symbolDefMap[key] else { return nil }
    guard !fetched.joined().isEmpty else { return nil }
    return fetched
  }

  /// 磁帶模式專用函式：將當前的按鍵轉換成磁帶內定義了的字根。
  /// - Parameter char: 按鍵字元。
  /// - Returns: 轉換結果。如果轉換失敗，則返回原始按鍵字元。
  public func convertCassetteKeyToDisplay(char: String) -> String {
    Self.lxCassette.convertKeyToDisplay(char: char)
  }

  /// 磁帶模式專用函式：檢查當前的按鍵是否屬於目前的磁帶規定的允許的字根按鍵。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 檢查結果。
  public func isThisCassetteKeyAllowed(key: String) -> Bool {
    Self.lxCassette.allowedKeys.contains(key)
  }

  /// 磁帶模式專用函式：檢查給定的索引鍵在搭上花牌鍵之後是否有匹配結果。
  /// - Parameter key: 給定的索引鍵。
  /// - Returns: 是否有批配結果。
  public func hasCassetteWildcardResultsFor(key: String) -> Bool {
    Self.lxCassette.hasUnigramsFor(key: key + Self.lxCassette.wildcard)
  }

  /// 磁帶模式專用函式：提供磁帶反查結果。
  /// - Parameter value: 要拿來反查的字詞。
  /// - Returns: 反查結果字串陣列。
  public func cassetteReverseLookup(for value: String) -> [String] {
    var lookupResult = Self.lxCassette.reverseCodes(for: value) ?? []
    guard !lookupResult.isEmpty else { return [] }
    lookupResult = lookupResult.map { $0.trimmingCharacters(in: .newlines) }
    return lookupResult.stableSort(by: { $0.count < $1.count }).stableSort {
      Self.lxCassette.unigramsFor(key: $0, keyArray: [$0]).count
        < Self.lxCassette.unigramsFor(key: $1, keyArray: [$1]).count
    }
  }
}

extension LXAssembly.LXFacade.LXQuerier {
  /// 磁帶模式專用函式：調取 `%quick` 快速候選結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  public func cassetteQuickSets(
    for key: String,
    strategy: LXAssembly.LXFacade.SupplementalLookupStrategy
  )
    -> String? {
    guard !key.isEmpty else { return nil }
    switch strategy {
    case .configuredLookup:
      return LXAssembly.LXFacade.lxCassette.quickSetsFor(key: key)
    case .exactMatch:
      let exactMatches = (LXAssembly.LXFacade.lxCassette.charDefMap.valuesFor(key: key) ?? [])
        .filter { $0.count == 1 }
        .deduplicated
        .prefix(LXAssembly.LXFacade.lxCassette.selectionKeys.count * 6)
      return exactMatches.isEmpty ? nil : exactMatches.joined(separator: "\t")
    case .partialMatch:
      let partialMatches = LXAssembly.LXFacade.lxCassette.charDefMap.prefixScan(prefix: key)
        .sorted { $0.key.count < $1.key.count }
        .flatMap(\.values)
        .filter { $0.count == 1 }
        .deduplicated
        .prefix(LXAssembly.LXFacade.lxCassette.selectionKeys.count * 6)
      return partialMatches.isEmpty ? nil : partialMatches.joined(separator: "\t")
    }
  }
}
