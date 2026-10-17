// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

extension LXAssembly.LXFacade {
  /// 磁帶模式專用：當前磁帶所規定的花牌鍵。
  public var cassetteWildcardKey: String { factory.cassette.wildcardKey }
  /// 磁帶模式專用：當前磁帶所規定的任意單字元鍵。
  public var cassetteAnySingleCharKey: String { factory.cassette.anySingleCharKey }
  /// 磁帶模式專用：當前磁帶規定的最大碼長。
  public var maxCassetteKeyLength: Int { factory.cassette.maxKeyLength }
  /// 磁帶模式專用：指定 `%quick` 快速候選結果當中要過濾掉的無效候選字符號。
  public var nullCandidateInCassette: String { factory.cassette.nullCandidate }
  /// 磁帶模式專用：選字鍵是否需要敲 Shift 才會生效。
  public var areCassetteCandidateKeysShiftHeld: Bool { factory.cassette.areCandidateKeysShiftHeld }
  /// 磁帶模式專用：需要直接递交的按键。
  public var keysToDirectlyCommit: String { factory.cassette.keysToDirectlyCommit }
  /// 磁帶模式專用：選字鍵，在唯音輸入法當中僅優先用於快速模式。
  public var cassetteSelectionKey: String? {
    let result = factory.cassette.selectionKeys
    return result.isEmpty ? nil : result
  }

  /// 磁帶模式專用：指定 `%quickphrases` 章節所定義的送詞鍵。
  public var cassetteQuickPhraseCommissionKey: String? {
    let key = factory.cassette.quickPhraseCommissionKey
    return key.isEmpty ? nil : key
  }

  /// 磁帶模式專用函式：調取 `%quickphrases` 詞彙候選結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  public func cassetteQuickPhrases(for key: String) -> [String]? {
    factory.cassette.quickPhrasesFor(key: key)
  }

  /// 磁帶模式專用函式：調取 `%symboldata` 符號選單查詢結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  public func cassetteSymbolDataFor(key: String) -> [String]? {
    guard let fetched = factory.cassette.symbolDefMap[key] else { return nil }
    guard !fetched.joined().isEmpty else { return nil }
    return fetched
  }

  /// 磁帶模式專用函式：將當前的按鍵轉換成磁帶內定義了的字根。
  /// - Parameter char: 按鍵字元。
  /// - Returns: 轉換結果。如果轉換失敗，則返回原始按鍵字元。
  public func convertCassetteKeyToDisplay(char: String) -> String {
    factory.cassette.convertKeyToDisplay(char: char)
  }

  /// 磁帶模式專用函式：檢查當前的按鍵是否屬於目前的磁帶規定的允許的字根按鍵。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 檢查結果。
  public func isThisCassetteKeyAllowed(key: String) -> Bool {
    factory.cassette.allowedKeys.contains(key)
  }

  /// 磁帶模式專用函式：檢查給定的索引鍵在搭上花牌鍵之後是否有匹配結果。
  /// - Parameter key: 給定的索引鍵。
  /// - Returns: 是否有批配結果。
  public func hasCassetteWildcardResultsFor(key: String) -> Bool {
    factory.cassette.hasUnigramsFor(key: key + factory.cassette.wildcard)
  }

  /// 磁帶模式專用函式：提供磁帶反查結果。
  /// - Parameter value: 要拿來反查的字詞。
  /// - Returns: 反查結果字串陣列。
  public func cassetteReverseLookup(for value: String) -> [String] {
    var lookupResult = factory.cassette.reverseCodes(for: value) ?? []
    guard !lookupResult.isEmpty else { return [] }
    lookupResult = lookupResult.map { $0.trimmingCharacters(in: .newlines) }
    return lookupResult.stableSort(by: { $0.count < $1.count }).stableSort {
      factory.cassette.unigramsFor(key: $0, keyArray: [$0]).count
        < factory.cassette.unigramsFor(key: $1, keyArray: [$1]).count
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
    let cassette = lxFacade.factory.cassette
    switch strategy {
    case .configuredLookup:
      return cassette.quickSetsFor(key: key)
    case .exactMatch:
      let exactRaw: [String] = cassette.charDefMap.valuesFor(key: key) ?? []
      let exactFiltered: [String] = exactRaw.filter { $0.count == 1 }.deduplicated
      let exactMatches = exactFiltered.prefix(cassette.selectionKeys.count * 6)
      return exactMatches.isEmpty ? nil : exactMatches.joined(separator: "\t")
    case .partialMatch:
      let partialScanned = cassette.charDefMap.prefixScan(prefix: key)
      let partialFlat: [String] = partialScanned
        .sorted { $0.key.count < $1.key.count }
        .flatMap(\.values)
      let partialFiltered: [String] = partialFlat.filter { $0.count == 1 }.deduplicated
      let partialMatches = partialFiltered.prefix(cassette.selectionKeys.count * 6)
      return partialMatches.isEmpty ? nil : partialMatches.joined(separator: "\t")
    }
  }
}
