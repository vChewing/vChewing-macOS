// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Tekkon

// MARK: - DualpinTypewriter

/// 雙拼（Dualpin）之打字機：前控式自收「碼鍵」，餘者一律轉交 BPMF 打字機。
///
/// 雙拼之語義是「一碼一音節、兩鍵成一碼」。首鍵只作顯示（pending），**從不**進入組音區；
/// 次鍵得碼時，先前那個尚未固化的音節先連同其同碼重碼詞幹一併固化入組字器，
/// 再以本碼之詞幹重寫組音區（`replacePinyinBuffer(with:)` 收的是拼音詞幹、非注音）。
///
/// 本碼自身之固化時機隨**狂打開關**而異：狂打側把讀音續留組音區，交由狂打之自動套用、
/// 重切分與 copilot 候選窗諸義處置；**非狂打側**則於次鍵當下即固化入組字器——兩鍵既已
/// 成碼，該碼之讀音節點即是「合理之桶」，沒有再等下一鍵或空白鍵之理。
///
/// 一切與主機有關之舉措（示警、顯示、狀態切換）皆由本型別施作：`Arimitsu` 只管純邏輯，
/// OS 中立模組內**永不**發聲——示警一律走 `errorCallback`（生產環境下會接通至鈴聲）。
///
/// 無效之兩鍵序一律出聲示警並丟棄此二鍵，**不得**使其落為原文；示警除鈴聲外，另以
/// Tooltip（`redAlert` 配色、1.2 秒）告知按鍵者方才之雙拼碼不合規。
///
/// 待配之首鍵係「已顯示、尚未落地」之組字素材（以讀音欄呈現），故**凡丟棄該首鍵者，
/// 皆須連帶刷新組字區**：否則它會以幽靈讀音留在顯示上，而其後之刪除鍵將因注拼槽與組字器
/// 俱空而只出聲示警、不切換狀態，幽靈遂永留。退位予 `BPMFFullMatchTypewriter` 之三處
/// 皆走 `delegateToBPMF(_:session:)`，由彼收拾此事。
@frozen
public struct DualpinTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    // 狂打 copilot 窗顯示中，Shift＋選字鍵就地選字（含待配之首鍵：雙拼之首鍵即未完成之讀音）。
    // 雙拼之按鍵一律先經本型別，`BPMFFullMatchTypewriter` 之同名前置判斷於本路徑不復見，
    // 故須於此處受理——否則 Shift＋選字鍵會被下方之「非碼鍵」分支作廢首鍵、再落入符號輸入。
    if handler.handleFuriousShiftCandidateSelectionIfNeeded(input) { return true }
    // 方案不可用（未選雙拼、自訂方案原文不可解、或校驗有誤）時，本型別無以自處，一切照舊。
    guard let config = handler.resolveDualpinConfigIfNeeded(), config.isUsable else {
      return delegateToBPMF(input, session: session)
    }
    // 刪除鍵：待配之首鍵係「已顯示、尚未落地」之組字素材，故本鍵應就地撤銷該首鍵。
    // 若放任其流入下方之「非碼鍵」分支，首鍵會先在此作廢、再落入常規之刪除流程：對已然
    // 為空之組字器誤發蜂鳴（9D69908D），且該早退不切換狀態 ⇒ 首鍵殘留於組字區顯示。
    if input.isBackSpace, handler.dualpinPendingDisplayText != nil {
      handler.dualpinFlushPending()
      // 收尾與常規之刪除鍵同一口徑：素材盡去時收為 `.ofAbortion()`，否則刷新組字區。
      session.switchState(
        handler.isConsideredEmptyForNow ? State.ofAbortion() : handler.generateStateOfInputting()
      )
      return true
    }
    // 刪除鍵：雙拼以「碼」為打字單位，故未決碼所譯出之音節亦以整個音節為退格粒度。
    // 逐字母刪拼音只會留下不合任何碼之半截讀音：既不成碼，亦難查詞；且使用者若欲改碼，
    // 重按兩鍵反而更快。
    if input.isBackSpace, !handler.composer.isEmpty {
      handler.composer.clear()
      handler.dualpinDiscardTranslatedReading()
      session.switchState(
        handler.isConsideredEmptyForNow ? State.ofAbortion() : handler.generateStateOfInputting()
      )
      return true
    }
    let inputText = (input.inputTextIgnoringModifiers ?? input.text).lowercased()
      .applyingTransformFW2HW(reverse: false)
    guard isCodeKeyCandidate(input, inputText: inputText), let key = inputText.first else {
      // 非單一可列印字元者（修飾鍵、功能鍵、多字元輸入）一律照舊，但待配之首鍵就此作廢。
      return delegateToBPMF(input, session: session)
    }
    // 碼鍵：組音區內若尚有前一音節，先固化它——連同其同碼重碼詞幹。
    // 必須先於 `ingest`：`ingest` 會以新碼之重碼詞幹覆寫 `siblingStems`。
    if config.parser.alphabet.contains(key), !handler.composer.isEmpty {
      solidifyPendingSyllable(session: session)
    }
    guard let action = handler.dualpinIngest(key) else {
      return delegateToBPMF(input, session: session)
    }
    switch action {
    case .bufferOnly:
      // 首鍵只更新顯示，不進組音區。
      session.switchState(handler.generateStateOfInputting())
      return true
    case let .translate(_, _, stems):
      guard let primary = stems.first else {
        handler.dualpinFlushPending()
        session.switchState(handler.generateStateOfInputting())
        return true
      }
      handler.composer.replacePinyinBuffer(with: primary)
      // 狂打側：讀音續留組音區（狂打之自動套用與重切分皆以之為素材）。
      guard !handler.isFuriousTypingModeEffective else {
        session.switchState(handler.generateStateOfInputting())
        return true
      }
      // 非狂打側：兩鍵既已成碼，本碼之讀音節點於次鍵當下即為合理之桶，逕行固化入組字器。
      solidifyPendingSyllable(session: session)
      return true
    case let .invalid(firstKey, secondKey):
      errorCallback("4E1A9C37：雙拼鍵序「\(firstKey)\(secondKey)」不成碼。")
      handler.dualpinFlushPending()
      session.switchState(handler.generateStateOfInputting())
      // 除鈴聲外，另以 Tooltip 示警（`redAlert` 配色、1.2 秒）：按鍵者方知方才那兩鍵
      // 不成碼，而非按鍵被吞。不走「狀態自帶 tooltip」之路：本 case 之組字器已空，
      // `generateStateOfInputting()` 只會回 `.ofAbortion()`，而該型別於 `switchState` 內
      // 會被換成全新的 `.ofEmpty()`、連帶丟棄其 tooltip（`SessionProtocol.swift` 之
      // `showStatusHint` doc 亦載此事），故逕於狀態切換後直接呼叫 Tooltip。
      session.showTooltip(
        "i18n:ErrorMessage.InvalidDualpinCode".i18n,
        colorState: .redAlert,
        duration: 1.2
      )
      return true
    case .passthrough:
      // 非碼鍵：本鍵若會被 BPMF 打字機當成拼音之續接字母，須先固化未決音節，
      // 免得前一首節遭續接污染（自訂方案之字母表未必覆蓋 a–z）。
      if isPinyinReadingContinuationKey(key), !handler.composer.isEmpty {
        solidifyPendingSyllable(session: session)
      }
      return delegateToBPMF(input, session: session)
    }
  }

  // MARK: Private

  /// 作廢待配之首鍵後退位予 `BPMFFullMatchTypewriter`，並收拾該首鍵之顯示殘留。
  ///
  /// 待配之首鍵係以組字區之讀音欄呈現（`dualpinPendingDisplayText` 參與
  /// `generateStateOfInputting()` 之組裝），而 `dualpinFlushPending()` 只動翻譯狀態機、
  /// **不觸狀態**。退位對象若消化了本鍵，其狀態切換即已帶走該顯示；但修飾鍵、功能鍵、
  /// 方向鍵與多數標點皆非其所收（`consumeReadingInputIfNeeded` 之消費條件不合），
  /// 本鍵遂落回分診，而那條路多半亦不切換狀態 ⇒ 幽靈首鍵永留顯示，其後之刪除鍵又因
  /// 注拼槽與組字器俱空而落進 `handleBackSpace` 之早退分支，只出聲示警（9D69908D）。
  ///
  /// 故於退位對象回 `nil`（本鍵未經其消化、逕落回分診）時，由本處依常規刪除鍵之同一口徑
  /// 刷新狀態：素材盡去時收為 `.ofAbortion()`，否則刷新組字區。退位前**不**刷，免得
  /// 同一輪內切兩次狀態。
  private func delegateToBPMF(
    _ input: some InputSignalProtocol,
    session: Handler.Session
  )
    -> Bool? {
    let hadPending = handler.dualpinPendingDisplayText != nil
    handler.dualpinFlushPending()
    let handled = BPMFFullMatchTypewriter(handler).handle(input)
    guard handled == nil, hadPending else { return handled }
    session.switchState(
      handler.isConsideredEmptyForNow ? State.ofAbortion() : handler.generateStateOfInputting()
    )
    return handled
  }

  /// 本鍵是否可能為雙拼之碼鍵：單一可列印字元、且未挾帶任何修飾鍵。
  ///
  /// 修飾鍵之口徑同 `BPMFFullMatchTypewriter` 之 `skipPhoneticHandling`。
  private func isCodeKeyCandidate(_ input: some InputSignalProtocol, inputText: String) -> Bool {
    guard inputText.count == 1 else { return false }
    guard !input.isReservedKey, !input.isNumericPadKey, !input.isNonLaptopFunctionKey else {
      return false
    }
    guard !input.isControlHeld, !input.isOptionHeld, !input.isShiftHeld, !input.isCommandHeld
    else { return false }
    return true
  }

  /// 本鍵是否會被 BPMF 打字機當成拼音讀音之續接字母。
  ///
  /// 雙拼之組音區恆為漢語拼音，字母表限於 ASCII 字母，故判準即「ASCII 字母」。
  /// 刻意不以 `composer.inputValidityCheck(charStr:)` 判定：該函式對漢語拼音之允許範圍含
  /// 數字與空白，無從區分「字母」與「聲調鍵」。
  private func isPinyinReadingContinuationKey(_ key: Character) -> Bool {
    key.isASCII && key.isLetter
  }

  /// 固化組音區內之未決音節。
  ///
  /// 呼叫時機有二：①下一碼之首鍵進場時（前一音節之收尾）；②**非狂打模式**下本碼之次鍵
  /// 進場時（見 `handle`）。狂打模式下②不由本處施作——讀音須留在組音區供狂打諸義取用。
  ///
  /// 與狂拼之自動切分不同：雙拼之讀音素材恆為**一個完整音節**（`replacePinyinBuffer` 所寫入者），
  /// 故不經 `pinyinAutoChopResult`；逕取讀音鍵、於無調時展開聲調桶、併入同碼重碼詞幹，
  /// 再交組字器。重碼詞幹必須併入同一位置（`insertKey(_: [String])` 之 `.multipleKeys`），
  /// 否則同碼諸讀音之候選會漏。
  private func solidifyPendingSyllable(session: Handler.Session) {
    guard let readingKey = handler.composer.phonabetKeyForQuery(pronounceableOnly: true) else { return }
    let toneInsensitive = handler.composer.isPinyinMode && handler.composer.intonation.isEmpty
    var keys = toneInsensitive ? Tekkon.makeToneInsensitiveVariants(of: readingKey) : [readingKey]
    let siblings = handler.dualpinSiblingReadingKeys(toneInsensitiveExpansion: toneInsensitive)
    if !siblings.isEmpty {
      var seen = Set(keys)
      keys.append(contentsOf: siblings.filter { seen.insert($0).inserted })
    }
    try? handler.assembler.insertKey(keys)
    let textToCommit = handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.composer.clear()
    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)
  }
}
