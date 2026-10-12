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
  /// 磁帶（Cin Cassette）模式：以使用者提供的鍵盤對照表輸入（部首筆畫等由磁帶承載；
  /// 雙拼已有原生實作，不復倚賴磁帶）。
  case cassette
  /// 注音鍵盤模式（Bopomofo Keyblock）。
  case bopomofoKeyblock
  /// 拼音鍵盤模式（Hanyu Pinyin Keyblock）。
  case pinyinKeyblock
  /// 狂拼模式（Furious Typing）：拼音鍵盤＋快速自動 chop 組句。
  case pinyinFuriousTyping
  /// 雙拼模式（Dualpin）：以「聲母鍵＋韻母鍵」兩鍵取一音節，組音區仍住漢語拼音。
  ///
  /// - Important: 本值與 `.pinyinFuriousTyping` **不可互相取代**：雙拼之組音區雖為拼音家族、
  ///   且狂打諸義（copilot 候選窗、前方預覽、無調確認組字）一律沿用拼音側，惟其按鍵並非
  ///   拼音字母流 —— 兩鍵成碼、碼非逐鍵累積，故須由 `DualpinTypewriter` 前控辨識。
  ///   又：空白鍵於雙拼下之語義為「無調確認組字」（同拼音鍵盤），而非注音側之「固化前方
  ///   讀音」⇒ 本值**不屬於** `isPinyinFuriousTypingModeEffective`（見該處註釋）。
  case DualPin
  /// 狂注模式（Furious Zhuyin Typing）：注音鍵盤＋快速自動切音節組句。
  ///
  /// - Important: 本值之可達性由 `prefs.furiousTypingEnabled4Zhuyin` 決定，而該偏好之出廠
  ///   預設為 `false`、且其使用者介面要到 P258 才存在 ⇒ **在 P254／P255 之交付狀態下，
  ///   本值不會出現於任何正式使用情境**（唯一觸及途徑是手改 `UserDefaults` 或匯入配置包）。
  ///   **中英混合輸入回退不再是本值之否決者**（P273）：兩者可以並存，惟彼時 ASCII 按鍵
  ///   仍走 `MixedAlphanumericalTypewriter`（見 `handleComposition` 之分派）——本值於該
  ///   情境之語意為「狂注之讀音素材＝混打緩衝」，而非「ASCII 按鍵逕由狂打吸收」。
  case zhuyinFuriousTyping

  // MARK: Public

  /// 該打字模式用於「內文模式提示」（於對接輸入客體時顯示）的 i18n key。
  public var i18nKey4InlineModeHint: String {
    switch self {
    case .DualPin: return "i18n:TypingMode.i18nKey4InlineModeHint.dualPin"
    default: return "i18n:TypingMode.i18nKey4InlineModeHint.\(rawValue)"
    }
  }
}

extension InputHandlerProtocol {
  /// 當前打字模式（於 `currentTypingMethod == .vChewingFactory` 時才有意義）。
  ///
  /// 判定順序：磁帶優先於一切；雙拼次之（鍵盤種類即其方案之選擇）；
  /// 狂打要求狂打開關＋非逐字選字＋注拼槽之鍵盤家族；
  /// 其餘以注拼槽是否拼音區分拼音鍵盤／注音鍵盤。
  /// `furiousTypingEnabled4Pinyin` pref 保留為「快速切換」的底層開關，本枚舉是其語義化抽象。
  ///
  /// - Important: **注音側與「中英混合輸入回退」可以並存**（P273 起；P258–P272 期間
  ///   前者被後者否決）。兩者對**同一批 ASCII 按鍵**各執一義：回退把該批按鍵先當注音、
  ///   整段不再構成讀音時才回退為原始 ASCII；狂打則要求連續注音即時自動切音節。
  ///   **分工**：按鍵仍由回退之打字機接管（它本即「同一批按鍵之消化器」），而其 ASCII
  ///   緩衝區即狂打之「未完成讀音」素材 ⇒ copilot 候選窗據以顯示（見 `furiousFrontContext`
  ///   之資料源分流）。**純狂打之自動切音節在此情境下不生效**——自動切音節會把逐鍵累積中
  ///   的緩衝區提早固化，與回退「先吸收、整段不成立才回退」之語義相衝（見
  ///   `isZhuyinFuriousTypingModeEffective`）。
  ///   **拼音側不受此議題影響**：中英混合輸入回退本即「注音鍵盤專屬」（拼音輸入下不可用，
  ///   見 `kMixedAlphanumericalEnabled.description`）。
  public var typingMode: TypingMode {
    if prefs.cassetteEnabled { return .cassette }
    // 雙拼：拼音側打字中樞成立、且「雙拼模式」開關（`dualpinEnabledForPinyinTyping`）開啟時，
    // `currentKeyboardParserType` 即改讀方案槽 `keyboardParser4Dualpin`（內建雙拼／自訂雙拼），
    // 而其組音區仍為拼音家族。此閘門只問「方案是否為雙拼」，**不問**方案資料是否可用 —— 後者之驗證成本高
    // （須遍歷音節清單），故一律交由 `DualpinTypewriter` 於實際收鍵時惰性解析；
    // 資料不可用時該打字機自行退位給 `BPMFFullMatchTypewriter`，按鍵不因而遭吞。
    // 逐字選字模式下雙拼不生效（同狂打：該模式為逐鍵選字，與「兩鍵成碼」相衝）。
    if currentKeyboardParserType.isDualpin, composer.isPinyinMode, !prefs.useSCPCTypingMode {
      return .DualPin
    }
    // 狂打開關依注拼槽之鍵盤家族二選一；兩側各自獨立（§7.1）。
    let isFurious = composer.isPinyinMode
      ? prefs.furiousTypingEnabled4Pinyin
      : prefs.furiousTypingEnabled4Zhuyin
    if isFurious, !prefs.useSCPCTypingMode {
      return composer.isPinyinMode ? .pinyinFuriousTyping : .zhuyinFuriousTyping
    }
    return composer.isPinyinMode ? .pinyinKeyblock : .bopomofoKeyblock
  }

  /// 「中英混合輸入回退」與「注音狂打」並存之合取閘——即「混打緩衝區正充當狂打之讀音素材」。
  ///
  /// - Important: 本旗子**不是** `isFuriousTypingModeEffective` 之同義詞，而是它的一個
  ///   **限定子集**：狂打之模式判定（`typingMode`）與按鍵之接管者（`handleComposition` 之
  ///   分派）自 P273 起脫鉤 ⇒ 本旗子即「狂打之讀音素材確實存在於混打緩衝區」之唯一判準。
  ///   凡「以讀音素材為前提」之狂打特性（copilot 候選窗、前方預覽、未完成讀音之顯示源）
  ///   一律問本旗子；凡「以連續注音之自動切音節為前提」者（簡拼 cells、自動切音節、固化）
  ///   仍問 `isZhuyinFuriousTypingModeEffective`——彼等會把逐鍵累積中之緩衝區提早固化，
  ///   與回退「先吸收、整段不成立才回退」之語義相衝。
  public var mixedAlnumZhuyinFuriousInEffect: Bool {
    currentTypingMethod == .vChewingFactory
      && prefs.mixedAlphanumericalEnabled
      && typingMode == .zhuyinFuriousTyping
  }
}
