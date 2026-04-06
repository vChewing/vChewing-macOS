// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 括號配對規則常數定義。
// 全形括號在中文組字區內有效；半形括號預留供 Phase 2 的英文緩衝區使用。

// MARK: - BracketPairingRules

/// 括號自動配對規則常數。
///
/// 全形括號：在中文組字區（compositor）內觸發自動配對。
/// 半形括號：預留供 Phase 2 使用（需英文緩衝區游標支援）。
public enum BracketPairingRules {

  // MARK: - 括號對照表

  /// 全形括號對照表：中文組字區內有效
  public static let fullWidthPairs: [(left: Character, right: Character)] = [
    ("『", "』"),
    ("「", "」"),
    ("《", "》"),
    ("〈", "〉"),
    ("【", "】"),
    ("〔", "〕"),
    ("｛", "｝"),
    ("（", "）"),
    ("\u{201C}", "\u{201D}"), // " "（彎引號）
    ("\u{2018}", "\u{2019}"), // ' '（彎單引號）
  ]

  /// 半形括號對照表：預留供 Phase 2（智慧中英文英文緩衝區）使用
  public static let halfWidthPairs: [(left: Character, right: Character)] = [
    ("(", ")"),
    ("[", "]"),
    ("{", "}"),
  ]

  // MARK: - 快查集合

  static let allPairs = fullWidthPairs + halfWidthPairs

  /// 全形左括號集合（快速查詢是否需要觸發自動配對）
  public static let fullWidthLeftSet: Set<Character> = Set(fullWidthPairs.map(\.left))

  /// 半形左括號集合（Phase 2 預留）
  public static let halfWidthLeftSet: Set<Character> = Set(halfWidthPairs.map(\.left))

  /// 所有右括號字元集合（用於 Smart Overwrite 識別）
  public static let isRightBracket: Set<Character> = Set(allPairs.map(\.right))

  /// 左括號 → 對應右括號的對照字典
  public static let rightOf: [Character: Character] = Dictionary(
    uniqueKeysWithValues: allPairs.map { ($0.left, $0.right) }
  )

  /// 右括號 → 對應左括號的對照字典（用於 Backspace 配對刪除驗證）
  public static let leftOf: [Character: Character] = Dictionary(
    uniqueKeysWithValues: allPairs.map { ($0.right, $0.left) }
  )
}
