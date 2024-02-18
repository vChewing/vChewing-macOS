// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import Shared

public extension LMAssembly.LMInstantiator {
  /// 磁帶模式專用：當前磁帶所規定的花牌鍵。
  var cassetteWildcardKey: String { Self.lmCassette.wildcardKey }
  /// 磁帶模式專用：當前磁帶規定的最大碼長。
  var maxCassetteKeyLength: Int { Self.lmCassette.maxKeyLength }
  /// 磁帶模式專用：指定 `%quick` 快速候選結果當中要過濾掉的無效候選字符號。
  var nullCandidateInCassette: String { Self.lmCassette.nullCandidate }
  /// 磁帶模式專用：選字鍵是否需要敲 Shift 才會生效。
  var areCassetteCandidateKeysShiftHeld: Bool { Self.lmCassette.areCandidateKeysShiftHeld }
  /// 磁帶模式專用：需要直接递交的按键。
  var keysToDirectlyCommit: String { Self.lmCassette.keysToDirectlyCommit }
  /// 磁帶模式專用：選字鍵，在威注音輸入法當中僅優先用於快速模式。
  var cassetteSelectionKey: String? {
    let result = Self.lmCassette.selectionKeys
    return result.isEmpty ? nil : result
  }

  /// 磁帶模式專用函式：調取 `%quick` 快速候選結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  func cassetteQuickSetsFor(key: String) -> String? {
    Self.lmCassette.quickSetsFor(key: key)
  }

  /// 磁帶模式專用函式：調取 `%symboldata` 符號選單查詢結果。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 結果。
  func cassetteSymbolDataFor(key: String) -> [String]? {
    guard let fetched = Self.lmCassette.symbolDefMap[key] else { return nil }
    guard !fetched.joined().isEmpty else { return nil }
    return fetched
  }

  /// 磁帶模式專用函式：將當前的按鍵轉換成磁帶內定義了的字根。
  /// - Parameter char: 按鍵字元。
  /// - Returns: 轉換結果。如果轉換失敗，則返回原始按鍵字元。
  func convertCassetteKeyToDisplay(char: String) -> String {
    Self.lmCassette.convertKeyToDisplay(char: char)
  }

  /// 磁帶模式專用函式：檢查當前的按鍵是否屬於目前的磁帶規定的允許的字根按鍵。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 檢查結果。
  func isThisCassetteKeyAllowed(key: String) -> Bool {
    Self.lmCassette.allowedKeys.contains(key)
  }

  /// 磁帶模式專用函式：檢查給定的索引鍵在搭上花牌鍵之後是否有匹配結果。
  /// - Parameter key: 給定的索引鍵。
  /// - Returns: 是否有批配結果。
  func hasCassetteWildcardResultsFor(key: String) -> Bool {
    Self.lmCassette.hasUnigramsFor(key: key + Self.lmCassette.wildcard)
  }

  /// 磁帶模式專用函式：提供磁帶反查結果。
  /// - Parameter value: 要拿來反查的字詞。
  /// - Returns: 反查結果字串陣列。
  func cassetteReverseLookup(for value: String) -> [String] {
    var lookupResult = Self.lmCassette.reverseLookupMap[value] ?? []
    guard !lookupResult.isEmpty else { return [] }
    lookupResult = lookupResult.map { $0.trimmingCharacters(in: .newlines) }
    return lookupResult.stableSort(by: { $0.count < $1.count }).stableSort {
      Self.lmCassette.unigramsFor(key: $0).count
        < Self.lmCassette.unigramsFor(key: $1).count
    }
  }
}
