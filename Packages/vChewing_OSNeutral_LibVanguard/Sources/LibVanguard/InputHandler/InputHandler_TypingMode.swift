// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - TypingMode

/// 打字模式枚舉：描述「vChewingFactory 輸入方法」之下（即注音／拼音／磁帶系）的輸入風格。
///
/// 注意：`TypingMethod`（vChewingFactory／codePoint／haninKeyboardSymbol／romanNumerals）
/// 是另一層「輸入方法」概念，兩者勿混淆。本枚舉僅在 `currentTypingMethod == .vChewingFactory`
/// 時有意義。
public enum TypingMode: String, Equatable {
  /// 磁帶（Cin Cassette）模式：以使用者提供的鍵盤對照表輸入（雙拼、部首筆畫等由磁帶承載）。
  case cassette
  /// 注音鍵盤模式（Bopomofo Keyblock）。
  case bopomofoKeyblock
  /// 拼音鍵盤模式（Hanyu Pinyin Keyblock）。
  case pinyinKeyblock
  /// 狂拼模式（Furious Typing）：拼音鍵盤＋快速自動 chop 組句。
  case pinyinFuriousTyping
  /// 狂注模式（Furious Zhuyin Typing）：注音鍵盤＋快速自動切音節組句。
  ///
  /// - Important: 本值之可達性由 `prefs.furiousTypingEnabled4Zhuyin` 決定，而該偏好之出廠
  ///   預設為 `false`、且其使用者介面要到 P258 才存在 ⇒ **在 P254／P255 之交付狀態下，
  ///   本值不會出現於任何正式使用情境**（唯一觸及途徑是手改 `UserDefaults` 或匯入配置包）。
  ///   **P265**：另須 `!prefs.mixedAlphanumericalEnabled`（見下 `typingMode` 之說明）。
  case zhuyinFuriousTyping

  // MARK: Public

  /// 該打字模式用於「內文模式提示」（於對接輸入客體時顯示）的 i18n key。
  public var i18nKey4InlineModeHint: String {
    "i18n:TypingMode.i18nKey4InlineModeHint.\(rawValue)"
  }
}

extension InputHandlerProtocol {
  /// 當前打字模式（於 `currentTypingMethod == .vChewingFactory` 時才有意義）。
  ///
  /// 判定順序：磁帶優先於一切；狂打要求狂打開關＋非逐字選字＋注拼槽之鍵盤家族；
  /// 其餘以注拼槽是否拼音區分拼音鍵盤／注音鍵盤。
  /// `furiousTypingEnabled4Pinyin` pref 保留為「快速切換」的底層開關，本枚舉是其語義化抽象。
  ///
  /// - Important: **注音側另受「中英混合輸入回退」否決**（P265）：只要
  ///   `prefs.mixedAlphanumericalEnabled` 為真，注音狂打即一律被視為關閉（即便其開關仍為真）。
  ///   兩者對**同一批 ASCII 按鍵**爭奪語義：回退模式要求逐鍵累積 ASCII 緩衝、待整段不再構成
  ///   讀音時再回退；狂打則要求連續注音即時自動切音節。前者係使用者顯式指定之相容行為，
  ///   故由前者勝出。否決置於**本屬性**（而非各閘門）之理由：本屬性即「當前處於哪個打字模式」
  ///   之單一出口，`handleComposition` 之分派、行內模式提示、以及狂打各閘門皆由此推導
  ///   ⇒ 一處否決即上下游一致，且按鍵自動改走 `MixedAlphanumericalTypewriter`。
  ///   **拼音側不受此否決**：中英混合輸入回退本即「注音鍵盤專屬」（拼音輸入下不可用，
  ///   見 `kMixedAlphanumericalEnabled.description`），若連帶否決拼音狂打，則一位注音時期
  ///   遺留該偏好、其後改用拼音之使用者會無故失去狂拼。
  public var typingMode: TypingMode {
    if prefs.cassetteEnabled { return .cassette }
    // 狂打開關依注拼槽之鍵盤家族二選一；兩側各自獨立（§7.1）。
    let isFurious = composer.isPinyinMode
      ? prefs.furiousTypingEnabled4Pinyin
      : (prefs.furiousTypingEnabled4Zhuyin && !prefs.mixedAlphanumericalEnabled)
    if isFurious, !prefs.useSCPCTypingMode {
      return composer.isPinyinMode ? .pinyinFuriousTyping : .zhuyinFuriousTyping
    }
    return composer.isPinyinMode ? .pinyinKeyblock : .bopomofoKeyblock
  }
}
