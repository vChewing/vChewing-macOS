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

extension vChewingLM.LMInstantiator {
  /// 當前磁帶所規定的花牌鍵。
  public var cassetteWildcardKey: String { Self.lmCassette.wildcardKey }
  /// 當前磁帶規定的最大碼長。
  public var maxCassetteKeyLength: Int { Self.lmCassette.maxKeyLength }

  /// 將當前的按鍵轉換成磁帶內定義了的字根。
  /// - Parameter char: 按鍵字元。
  /// - Returns: 轉換結果。如果轉換失敗，則返回原始按鍵字元。
  public func convertCassetteKeyToDisplay(char: String) -> String {
    Self.lmCassette.convertKeyToDisplay(char: char)
  }

  /// 檢查當前的按鍵是否屬於目前的磁帶規定的允許的字根按鍵。
  /// - Parameter key: 按鍵字元。
  /// - Returns: 檢查結果。
  public func isThisCassetteKeyAllowed(key: String) -> Bool {
    Self.lmCassette.allowedKeys.contains(key)
  }

  /// 檢查給定的索引鍵在搭上花牌鍵之後是否有匹配結果。
  /// - Parameter key: 給定的索引鍵。
  /// - Returns: 是否有批配結果。
  public func hasCassetteWildcardResultsFor(key: String) -> Bool {
    Self.lmCassette.hasUnigramsFor(key: key + Self.lmCassette.wildcard)
  }

  /// 提供磁帶反查結果。
  /// - Parameter value: 要拿來反查的字詞。
  /// - Returns: 反查結果字串陣列。
  public func cassetteReverseLookup(for value: String) -> [String] {
    var lookupResult = Self.lmCassette.reverseLookupMap[value] ?? []
    guard !lookupResult.isEmpty else { return [] }
    lookupResult = lookupResult.map { $0.trimmingCharacters(in: .newlines) }
    return lookupResult.stableSort(by: { $0.count < $1.count }).stableSort {
      Self.lmCassette.unigramsFor(key: $0).count
        < Self.lmCassette.unigramsFor(key: $1).count
    }
  }
}
