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
  /// 判定順序：磁帶優先於一切；狂拼要求狂拼開關＋非逐字選字＋拼音注拼槽；
  /// 其餘以注拼槽是否拼音區分拼音鍵盤／注音鍵盤。
  /// `furiousTypingEnabled4Pinyin` pref 保留為「快速切換」的底層開關，本枚舉是其語義化抽象。
  ///
  /// - Note: 本 phase 只把屬性名跟上 `UserDef` 之兩分，判定語意一行不動 —— 注音側之閘門
  ///   （`furiousTypingEnabled4Zhuyin`）與 `TypingMode.zhuyinFuriousTyping` 之可達性留待 P254。
  public var typingMode: TypingMode {
    if prefs.cassetteEnabled { return .cassette }
    // 狂打開關依注拼槽之鍵盤家族二選一；兩側各自獨立（§7.1）。
    let isFurious = composer.isPinyinMode
      ? prefs.furiousTypingEnabled4Pinyin
      : prefs.furiousTypingEnabled4Zhuyin
    if isFurious, !prefs.useSCPCTypingMode {
      return composer.isPinyinMode ? .pinyinFuriousTyping : .zhuyinFuriousTyping
    }
    return composer.isPinyinMode ? .pinyinKeyblock : .bopomofoKeyblock
  }
}
