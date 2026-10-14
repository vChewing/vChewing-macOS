// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Arimitsu
import Foundation
import Tekkon

// MARK: - DualpinConfig

/// 雙拼輸入模式（Dualpin）之執行期狀態。
///
/// 本型別持有「當前生效之方案」與其「鍵序翻譯狀態機」。方案資料一律由偏好設定指路：
/// 內建方案取自 `DualpinParser` 之內建原文，自訂方案取自 `prefs.dualpinSchemaJSON`。
/// 至若「當前該用哪個方案」，則由 `currentKeyboardParserType` 指認——拼音側且
/// `prefs.dualpinEnabledForPinyinTyping` 開啟時，該值改讀 `prefs.keyboardParser4Dualpin`。
///
/// 之所以要連同校驗報告一起快取，是因為「逐條走訪 426 條詞幹」之代價遠高於一次按鍵：
/// 本型別以 `schemaIdentity` 為指紋，指紋不變則整批沿用。校驗失敗之方案亦予以快取，
/// 以免每一次按鍵都重跑一次全詞幹校驗。
public struct DualpinConfig: Sendable {
  // MARK: Lifecycle

  public init(parser: DualpinParser, report: DualpinValidationReport, schemaIdentity: String) {
    self.parser = parser
    self.report = report
    self.schemaIdentity = schemaIdentity
    self.translator = DualpinTranslator(report: report, alphabet: parser.alphabet)
  }

  // MARK: Public

  /// 當前生效之雙拼方案。
  public let parser: DualpinParser
  /// 當前方案之校驗報告。
  public let report: DualpinValidationReport
  /// 快取指紋：方案種類與自訂方案原文之合成。指紋一變即整批重算。
  public let schemaIdentity: String
  /// 鍵序翻譯狀態機。
  public var translator: DualpinTranslator

  /// 「客體顯示之刷新已延後至本輪分診事件末」之旗標。
  ///
  /// 只由雙拼首鍵退位一路設定（見 `SessionCoreProtocol.switchState` 之
  /// `deferringDisplayRefresh` 與 `settleDeferredCompositionDisplayIfNeeded()`）。
  public var hasDeferredCompositionDisplayRefresh: Bool = false

  /// 當前方案是否可用（校驗無誤）。
  public var isUsable: Bool { report.isUsable }

  /// 重設整批執行期狀態。
  public mutating func resetAll() {
    translator.resetAll()
    hasDeferredCompositionDisplayRefresh = false
  }
}

// MARK: - InputHandlerProtocol 之雙拼支援

extension InputHandlerProtocol {
  /// 當前偏好設定所指之雙拼方案。無方案、或自訂方案原文不可解時回 nil。
  var dualpinParserFromPrefs: DualpinParser? {
    switch currentKeyboardParserType {
    case .ofDualpinMSPY: return .mspy
    case .ofDualpinGBT17: return .gbt17
    case .ofDualpinCustom:
      let raw = prefs.dualpinSchemaJSON.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
      // 自訂方案之原文來自使用者：解碼失敗時靜默退位，不得大聲失敗。
      return try? JSONDecoder().decode(DualpinParser.self, from: data)
    default: return nil
    }
  }

  /// 快取指紋：當前鍵盤種類與（自訂方案時之）方案原文。
  var dualpinSchemaIdentity: String {
    let custom = currentKeyboardParserType == .ofDualpinCustom ? prefs.dualpinSchemaJSON : ""
    return currentKeyboardParserType.name + "\u{1F}" + custom
  }

  /// 解析（並快取）當前雙拼方案之執行期狀態。
  ///
  /// 校驗時併入 `DualpinParser.builtinRawIDs` 之用意：自訂方案不得冒用內建方案之 `rawID`（E9）。
  @discardableResult
  func resolveDualpinConfigIfNeeded() -> DualpinConfig? {
    guard currentKeyboardParserType.isDualpin else {
      dualpinConfig = nil
      return nil
    }
    let identity = dualpinSchemaIdentity
    if let cached = dualpinConfig, cached.schemaIdentity == identity { return cached }
    dualpinConfig = nil
    guard let parser = dualpinParserFromPrefs else { return nil }
    let config = DualpinConfig(
      parser: parser,
      report: parser.validate(conflictingRawIDs: DualpinParser.builtinRawIDs),
      schemaIdentity: identity
    )
    dualpinConfig = config
    return config
  }

  /// 收一鍵入雙拼翻譯狀態機。回 nil 表示雙拼當前不可用（呼叫端應退位）。
  func dualpinIngest(_ key: Character) -> DualpinTranslator.Action? {
    guard var config = resolveDualpinConfigIfNeeded(), config.isUsable else { return nil }
    let action = config.translator.ingest(key)
    dualpinConfig = config
    return action
  }

  /// 丟棄待配之首鍵。
  ///
  /// 呼叫時機與 `DualpinTranslator.flush()` 相同：確認鍵、方向鍵、輸入法切換、游標移動。
  func dualpinFlushPending() {
    guard var config = dualpinConfig else { return }
    config.translator.flush()
    dualpinConfig = config
  }

  /// 見 `DualpinConfig.hasDeferredCompositionDisplayRefresh`。
  var hasDeferredCompositionDisplayRefresh: Bool {
    get { dualpinConfig?.hasDeferredCompositionDisplayRefresh ?? false }
    set { dualpinConfig?.hasDeferredCompositionDisplayRefresh = newValue }
  }

  /// 標記「客體顯示須於本輪分診事件末補刷」。
  ///
  /// 由 `SessionCoreProtocol.switchState` 之 `deferringDisplayRefresh` 路徑呼叫：該路徑
  /// 丟棄了素材卻又在同一輪事件內交給後續分診落筆，故此刻之客體顯示內容旋即失效，
  /// 刷新應留待本輪事件末一次結算。
  func markDeferredCompositionDisplayRefresh() {
    hasDeferredCompositionDisplayRefresh = true
  }

  /// 結算 `markDeferredCompositionDisplayRefresh()` 所標記之補刷；旗標一次即清，
  /// 重複呼叫為空操作（分診入口之 `defer` 亦可能因遞迴而多次觸及）。
  ///
  /// 補刷之落筆若與客體現下所見相同，會為 `doSetMarkedText` 之寫入快取逕行吞掉
  /// （同文同範圍者不再送客體），故不至於多出一趟客體往返。
  func settleDeferredCompositionDisplayIfNeeded() {
    guard hasDeferredCompositionDisplayRefresh else { return }
    hasDeferredCompositionDisplayRefresh = false
    session?.updateCompositionBufferDisplay()
  }

  /// 丟棄未決碼所譯出之音節時，連帶清掉其重碼詞幹。
  ///
  /// 重碼詞幹係「併走即消耗」之材料，本應隨該音節定案而去；音節既遭退格撤銷，若只清
  /// 組音區而獨留詞幹，它們會錯配於下一音節（`dualpinSiblingReadingKeys` 之註記）。
  func dualpinDiscardTranslatedReading() {
    guard var config = dualpinConfig else { return }
    config.translator.resetAll()
    dualpinConfig = config
  }

  /// 未決音節之同碼重碼詞幹（首選以外者）所能構成之讀音鍵。
  ///
  /// 同碼詞幹共用一碼，故其讀音亦須一併入組字器，否則候選會漏。
  ///
  /// 併走即消耗：本函式只在「該音節定案」之兩處併入點被呼叫（固化前一音節、
  /// 以及查詢讀音鍵），故一經取用即清空，免其殘留而錯配於下一音節。
  ///
  /// - Parameter toneInsensitiveExpansion: 與 `BPMFFullMatchTypewriter` 取鍵之口徑一致：
  ///   無調且待確認時展開聲調桶，否則只取本調。
  func dualpinSiblingReadingKeys(toneInsensitiveExpansion: Bool) -> [String] {
    guard var config = dualpinConfig, config.isUsable else { return [] }
    let siblings = config.translator.consumeSiblingStems()
    guard !siblings.isEmpty else { return [] }
    dualpinConfig = config
    // 陰平在 Tekkon 內以空白表示，而讀音鍵不含空白（見 `phonabetKeyForQuery`）。
    let rawTone = composer.intonation.value
    let toneSymbol = rawTone == " " ? "" : rawTone
    let pinyinTrie = Tekkon.PinyinTrie.shared(parser: .ofHanyuPinyin)
    return siblings.flatMap { stem -> [String] in
      // 同碼詞幹恆為完整音節，故 `zhuyinReadings` 只回該音節之無調注音（可能多於一條）。
      pinyinTrie.zhuyinReadings(forPinyinFragment: stem).flatMap { zhuyin -> [String] in
        guard !toneInsensitiveExpansion else { return Tekkon.makeToneInsensitiveVariants(of: zhuyin) }
        return [zhuyin + toneSymbol]
      }
    }
  }

  /// 待配首鍵所能開啟之諸讀音（無調注音、依碼序去重）。
  ///
  /// 首鍵尚未成碼，故其桶只能以「以該鍵為首之諸碼之諸詞幹」推算；一經成碼，桶即改由
  /// `composer.romajiBuffer` 反推（見 `furiousFrontContext`），兩者之展開口徑一致。
  /// - Returns: 無待配首鍵或方案不可用時回空。
  func dualpinPendingPrefixReadingKeys() -> [String] {
    guard let config = resolveDualpinConfigIfNeeded(), config.isUsable,
          let firstKey = config.translator.pendingFirstKey
    else { return [] }
    let pinyinTrie = Tekkon.PinyinTrie.shared(parser: .ofHanyuPinyin)
    var seen = Set<String>()
    return config.translator.stemsStarting(with: firstKey)
      .flatMap { pinyinTrie.zhuyinReadings(forPinyinFragment: $0) }
      .filter { seen.insert($0).inserted }
  }

  /// 雙拼待配首鍵之顯示原文。nil 表無可顯示者。
  ///
  /// 此處**不**觸發方案解析：顯示需求遠多於按鍵需求，且解析成本不菲。
  var dualpinPendingDisplayText: String? {
    guard let text = dualpinConfig?.translator.displayText, !text.isEmpty else { return nil }
    return text
  }

  /// 雙拼待配首鍵之「原始碼 → 首鍵碼義」提示（狂打 copilot 候選窗頂部 pane 用）。
  ///
  /// 右側列該鍵於**首鍵之位**所代表者（聲母；零聲母鍵則予記號，或依政策列韻母之首字元），而
  /// **非**「以該鍵為首之諸詞幹」：後者係前綴窮舉，於微軟雙拼之 `v` 即二十條（`zha`…
  /// `zhuo`），pane 一寬即不可讀（事主 2026-10-14 首次指正）；**亦非**「值等於該鍵之韻母」：
  /// 韻母於第二鍵位置方成其碼義，一併列入則首鍵 `u`（實為聲母 `sh`）誤示為 `sh u`
  /// （同日以實機二次指正）。詞幹仍為桶之所需，惟該處由 `dualpinPendingPrefixReadingKeys`
  /// 另行取用（見 `DualpinParser.meanings(ofKey:)`）。
  ///
  /// 雙拼之首鍵只作顯示、**從不**進注拼槽（見 `DualpinTypewriter`），故「未完成讀音素材」
  /// 住在翻譯狀態機（`translator.pendingFirstKey`）而非注拼槽。惟雙拼之音節恆為兩鍵，
  /// 故首鍵（半截之碼）即「未完成之讀音」——狂打之 copilot 候選窗已由該首鍵所能開啟之諸碼
  /// 開出（`dualpinPendingPrefixReadingKeys`），`hasFuriousFrontPending` 於該拍即成立
  /// （見 `furiousFrontUnfinishedReading` 之 `.DualPin` 臂），Shift+選字鍵亦可提前選字；
  /// 該窗若無 pane，看起來即不似 copilot 窗（事主 2026-10-13 回報）。
  ///
  /// - Important: 本提示只供**顯示**；首鍵之拍不得固化——半截之碼不成音節，其桶係「該首鍵
  ///   所能開啟之全部詞幹之全部讀音」（數百鍵），逕插將令同一音節重複入庫。故
  ///   `solidifyFuriousFrontReading()` 於該拍讓位，而使用者若以 Shift+選字鍵提前選字，
  ///   `confirmFuriousFrontCandidate()` 會消費翻譯狀態機之待配首鍵（以免次鍵再與之成碼）。
  /// - Returns: 非狂打模式、組音區非空（碼已成）、無待配首鍵、或方案不可用時回 nil。
  var dualpinPendingFirstKeyPaneText: String? {
    guard isFuriousTypingModeEffective else { return nil }
    guard composer.romajiBuffer.isEmpty else { return nil }
    guard let config = resolveDualpinConfigIfNeeded(), config.isUsable,
          let firstKey = config.translator.pendingFirstKey
    else { return nil }
    let meanings = config.parser.meanings(ofKey: firstKey)
    guard !meanings.isEmpty else { return nil }
    return "\(firstKey) → \(meanings.joined(separator: " "))"
  }
}
