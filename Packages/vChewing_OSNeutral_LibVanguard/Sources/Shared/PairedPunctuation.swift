// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - PairedPunctuation

/// 成對標點之對照表。
///
/// 全形資料來自 `vChewing-VanguardLexicon/Sources/LibVanguardChewingData/Resources/components/
/// common/data-punctuations.txt` 之三組單邊候選：
/// `_punctuation_[`／`_punctuation_]`、`_punctuation_{`／`_punctuation_}`、
/// `_punctuation_(`／`_punctuation_)`。三組之左右候選逐項對位；本表即該對位之固化。
///
/// 半形候選四對（`[]`、`{}`、`()`、`<>`）之單邊索引鍵為 `_half_punctuation_` 系列；
/// 其候選由 `InputHandler` 依本表注入，不依賴辭典版本。另收 `｢｣` 一對，供 `[`／`]`
/// 輪替時同步。
///
/// 本表刻意不依賴執行期辭典：成對關係是輸入法之語義，不是候選權重；且拆對與同步
/// 皆須在候選窗之外獨立判定。
public enum PairedPunctuation {
  // MARK: Public

  /// 左元件 → 右元件。
  public static let leftToRight: [String: String] = Dictionary(
    uniqueKeysWithValues: pairs.map { ($0.left, $0.right) }
  )

  /// 右元件 → 左元件。
  public static let rightToLeft: [String: String] = Dictionary(
    uniqueKeysWithValues: pairs.map { ($0.right, $0.left) }
  )

  /// 左元件 → 其所屬之單邊索引鍵。
  public static let leftKeyMap: [String: String] = Dictionary(
    uniqueKeysWithValues: pairs.map { ($0.left, $0.leftKey) }
  )

  /// 右元件 → 其所屬之單邊索引鍵。
  public static let rightKeyMap: [String: String] = Dictionary(
    uniqueKeysWithValues: pairs.map { ($0.right, $0.rightKey) }
  )

  /// 半形模式下、`\`／`|` 兩鍵可注入之完整成對候選（依序）。
  public static let halfWidthPairValues: [String] = ["[]", "{}", "()", "<>"]

  /// 該索引鍵是否屬於成對標點之單邊元件（全形或半形）。
  public static func isPunctuationComponentKey(_ key: String) -> Bool {
    key.hasPrefix("_punctuation_") || key.hasPrefix("_half_punctuation_")
  }

  public static func isLeftComponent(_ value: String) -> Bool {
    leftToRight[value] != nil
  }

  public static func isRightComponent(_ value: String) -> Bool {
    rightToLeft[value] != nil
  }

  /// 給定之字串是否為完整的一對（兩個字元，且左元件對應右元件）。
  public static func isFullPair(_ value: String) -> Bool {
    guard value.count == 2 else { return false }
    let chars = Array(value)
    return leftToRight[String(chars[0])] == String(chars[1])
  }

  /// 回傳給定元件之另一半；非成對元件者回 `nil`。
  public static func counterpart(of value: String) -> String? {
    leftToRight[value] ?? rightToLeft[value]
  }

  /// 將完整的一對拆成左右元件與其索引鍵；非完整成對者回 `nil`。
  public static func decompose(
    fullPair value: String
  )
    -> (leftKey: String, leftValue: String, rightKey: String, rightValue: String)? {
    guard isFullPair(value) else { return nil }
    let chars = Array(value)
    let leftValue = String(chars[0])
    let rightValue = String(chars[1])
    guard let leftKey = leftKeyMap[leftValue], let rightKey = rightKeyMap[rightValue] else {
      return nil
    }
    return (leftKey, leftValue, rightKey, rightValue)
  }

  // MARK: Private

  /// 三元組：(左元件, 右元件, 左索引鍵, 右索引鍵)。
  ///
  /// 三組索引鍵之左右候選在 `data-punctuations.txt` 中逐項對位；此處照錄，不另排序。
  private static let pairs: [(left: String, right: String, leftKey: String, rightKey: String)] = [
    ("「", "」", "_punctuation_[", "_punctuation_]"),
    ("“", "”", "_punctuation_[", "_punctuation_]"),
    ("《", "》", "_punctuation_[", "_punctuation_]"),
    ("〔", "〕", "_punctuation_[", "_punctuation_]"),
    ("【", "】", "_punctuation_[", "_punctuation_]"),
    ("［", "］", "_punctuation_[", "_punctuation_]"),
    ("﹁", "﹂", "_punctuation_[", "_punctuation_]"),
    ("«", "»", "_punctuation_[", "_punctuation_]"),
    ("︽", "︾", "_punctuation_[", "_punctuation_]"),
    ("︹", "︺", "_punctuation_[", "_punctuation_]"),
    ("︻", "︼", "_punctuation_[", "_punctuation_]"),
    ("﹇", "﹈", "_punctuation_[", "_punctuation_]"),
    ("『", "』", "_punctuation_{", "_punctuation_}"),
    ("‘", "’", "_punctuation_{", "_punctuation_}"),
    ("｛", "｝", "_punctuation_{", "_punctuation_}"),
    ("〈", "〉", "_punctuation_{", "_punctuation_}"),
    ("〖", "〗", "_punctuation_{", "_punctuation_}"),
    ("﹃", "﹄", "_punctuation_{", "_punctuation_}"),
    ("‹", "›", "_punctuation_{", "_punctuation_}"),
    ("︷", "︸", "_punctuation_{", "_punctuation_}"),
    ("︿", "﹀", "_punctuation_{", "_punctuation_}"),
    ("︗", "︘", "_punctuation_{", "_punctuation_}"),
    ("（", "）", "_punctuation_(", "_punctuation_)"),
    ("︵", "︶", "_punctuation_(", "_punctuation_)"),
    // 半形：候選由 InputHandler 注入，索引鍵用 `_half_punctuation_` 系列。
    ("[", "]", "_half_punctuation_[", "_half_punctuation_]"),
    ("｢", "｣", "_half_punctuation_[", "_half_punctuation_]"),
    ("{", "}", "_half_punctuation_{", "_half_punctuation_}"),
    ("(", ")", "_half_punctuation_(", "_half_punctuation_)"),
    ("<", ">", "_half_punctuation_<", "_half_punctuation_>"),
  ]
}
