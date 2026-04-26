// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - BPMFFullMatchTypewriter

/// 注音按鍵輸入處理 (Handle BPMF Keys)
@frozen
public struct BPMFFullMatchTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public typealias Phonabet = Tekkon.Phonabet

  public let handler: Handler

  /// 用來處理 InputHandler.HandleInput() 當中的與注音输入有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    var inputText = (input.inputTextIgnoringModifiers ?? input.text)
    inputText = inputText.lowercased().applyingTransformFW2HW(reverse: false)
    let prefs = handler.prefs
    let existedIntonation = handler.composer.intonation
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold
    let confirmCombination = input.isSpace || input.isEnter

    // 先嘗試讓注拼槽消化當前按鍵（含可能的聲調覆寫），以保留既有行為。
    let consumption = consumeReadingInputIfNeeded(
      input: input,
      inputText: &inputText,
      skipPhoneticHandling: skipPhoneticHandling,
      confirmCombination: confirmCombination,
      prefs: prefs,
      session: session
    )
    if let handled = consumption.handled { return handled }

    // 若讀音已備妥，嘗試組字並進入候選或直接提交。
    if let composed = composeReadingIfReady(
      input: input,
      inputText: inputText,
      confirmCombination: confirmCombination,
      existedIntonation: existedIntonation,
      prefs: prefs,
      session: session
    ) {
      return composed
    }

    // 若僅有聲調暫存，處理獨立聲調行為或清空暫存。
    if let handled = handleStandaloneIntonation(
      input: input,
      existedIntonation: existedIntonation,
      keyConsumedByReading: consumption.keyConsumed,
      session: session
    ) {
      return handled
    }
    return nil
  }

  // MARK: Private

  private var intonationKeyBehavior: IntonationKeyBehavior {
    .init(pref: handler.prefs)
  }

  /// 生成本次組字查詢要使用的讀音索引鍵。
  ///
  /// 若本次是拼音無調的確認組字，則會將單一讀音擴成同音節的聲調候選桶；
  /// 否則維持既有的單一 full-match 索引鍵。
  /// - Parameters:
  ///   - confirmCombination: 是否為用來確認組字的按鍵。
  ///   - existedIntonation: 接收本拍按鍵之前，composer 內既有的聲調狀態。
  ///   - prefs: 與讀音查詢相關的偏好設定。
  /// - Returns: 可供語言模組檢索的讀音索引鍵；若目前讀音尚不可查詢則回傳 nil。
  private func readingKeyForQuery(
    confirmCombination: Bool,
    existedIntonation: Tekkon.Phonabet,
    prefs: some PrefMgrProtocol
  )
    -> [String]? {
    guard let readingKey = handler.composer.phonabetKeyForQuery(
      pronounceableOnly: prefs.acceptLeadingIntonations
    ) else {
      return nil
    }
    guard shouldUseToneInsensitivePinyinLookup(
      confirmCombination: confirmCombination,
      existedIntonation: existedIntonation
    ) else {
      return [readingKey]
    }
    return makeToneInsensitivePinyinQueryKey(from: readingKey)
  }

  /// 判斷本次是否應將無調拼音改以聲調候選桶查詢。
  /// - Parameters:
  ///   - confirmCombination: 是否為用來確認組字的按鍵。
  ///   - existedIntonation: 接收本拍按鍵之前，composer 內既有的聲調狀態。
  /// - Returns: 僅當本次為拼音模式下的無調確認組字時回傳 true。
  private func shouldUseToneInsensitivePinyinLookup(
    confirmCombination: Bool,
    existedIntonation: Tekkon.Phonabet
  )
    -> Bool {
    let composer = handler.composer
    return confirmCombination
      && composer.isPinyinMode
      && composer.isPronounceable
      && existedIntonation.isEmpty
  }

  /// 將單一無調拼音讀音展開成同音節的聲調候選桶。
  /// - Parameter readingKey: 不帶顯式聲調的單一讀音索引鍵。
  /// - Returns: 該讀音的所有聲調變體陣列。
  private func makeToneInsensitivePinyinQueryKey(from readingKey: String) -> [String] {
    var toneVariants = [String]()
    Tekkon.allowedIntonations.forEach { tone in
      let intonationNow = (tone != " ") ? String(tone) : ""
      let candidate = "\(readingKey)\(intonationNow)"
      if !toneVariants.contains(candidate) {
        toneVariants.append(candidate)
      }
    }
    return toneVariants
  }

  private func consumeReadingInputIfNeeded(
    input: some InputSignalProtocol,
    inputText: inout String,
    skipPhoneticHandling: Bool,
    confirmCombination: Bool,
    prefs: some PrefMgrProtocol,
    session: Session
  )
    -> (handled: Bool?, keyConsumed: Bool) {
    // 讓注拼槽先嘗試吸收鍵入內容，並在必要時套用「後置聲調覆寫」。
    var keyConsumedByReading = false
    if (!skipPhoneticHandling && handler.composer.inputValidityCheck(charStr: inputText))
      || confirmCombination {
      if let overrideHandled = performRearIntonationOverrideIfNeeded(
        input,
        inputText: &inputText
      ) {
        return (overrideHandled, keyConsumedByReading)
      }
      if let autoChopHandled = performPinyinAutoChopIfNeeded(
        inputText: inputText,
        prefs: prefs,
        session: session
      ) {
        return (autoChopHandled, true)
      }
      handler.composer.receiveKey(fromString: confirmCombination ? " " : inputText)
      keyConsumedByReading = true
      narrateTheComposer(
        narrator: handler.narrator,
        when: prefs.readingNarrationCoverage >= 2,
        allowDuplicates: false
      )
      if !handler.composer.hasIntonation() {
        session.switchState(handler.generateStateOfInputting())
        return (true, keyConsumedByReading)
      }
    }
    return (nil, keyConsumedByReading)
  }

  private func performPinyinAutoChopIfNeeded(
    inputText: String,
    prefs: some PrefMgrProtocol,
    session: Session
  )
    -> Bool? {
    guard let autoChop = handler.composer.pinyinAutoChopResult(appending: inputText) else {
      return nil
    }

    let choppedReadingKeys = autoChop.committedReadings.map {
      makeToneInsensitivePinyinQueryKey(from: $0)
    }
    guard choppedReadingKeys.allSatisfy({ key in
      key.contains(where: { handler.currentLM.hasUnigramsForFast(keyArray: [$0]) })
    }) else {
      return nil
    }

    for readingKey in choppedReadingKeys {
      guard (try? handler.assembler.insertKey(readingKey)) != nil else {
        errorCallback(
          "6C2CBEE8: Pinyin auto-chop generated an insertion key rejected by the assembler."
        )
        return true
      }
    }

    handler.assemble()
    let textToCommit = handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.composer.replacePinyinBuffer(with: autoChop.remainingRomaji)
    narrateTheComposer(
      narrator: handler.narrator,
      when: prefs.readingNarrationCoverage >= 2,
      allowDuplicates: false
    )

    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)
    handler.handleTypewriterSCPCTasks()
    return true
  }

  private func composeReadingIfReady(
    input: some InputSignalProtocol,
    inputText: String,
    confirmCombination: Bool,
    existedIntonation: Tekkon.Phonabet,
    prefs: some PrefMgrProtocol,
    session: Session
  )
    -> Bool? {
    // 讀音齊備時，檢索 LM、寫入組字器並刷新狀態；同時維持旁白朗讀行為。
    var composeReading = handler.composer.hasIntonation()
      && handler.composer.inputValidityCheck(charStr: inputText)
    composeReading = composeReading || (!handler.composer.isEmpty && confirmCombination)
    guard composeReading else { return nil }

    if input.isControlHold, input.isCommandHold, input.isEnter,
       !input.isOptionHold, !input.isShiftHold, handler.assembler.isEmpty {
      return handler.handleEnter(input: input, readingOnly: true)
    }

    guard let readingKey = readingKeyForQuery(
      confirmCombination: confirmCombination,
      existedIntonation: existedIntonation,
      prefs: prefs
    ) else { return nil }

    let hasAnyResult = readingKey.contains { alt in
      handler.currentLM.hasUnigramsForFast(keyArray: [alt])
    }
    if !hasAnyResult {
      errorCallback("B49C0979：語彙庫內無「\(readingKey.joined(separator: "/"))」的匹配記錄。")

      if prefs.keepReadingUponCompositionError {
        if handler.composer.hasIntonation() { handler.composer.doBackSpace() }
        session.switchState(handler.generateStateOfInputting())
        return true
      }

      handler.composer.clear()
      switch handler.assembler.isEmpty {
      case false: session.switchState(handler.generateStateOfInputting())
      case true: session.switchState(State.ofAbortion())
      }
      return true
    }

    if input.isInvalid {
      errorCallback("22017F76: 不合規的按鍵輸入。")
      return true
    } else if (try? handler.assembler.insertKey(readingKey)) == nil {
      errorCallback(
        "3CF278C9: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。"
      )
      return true
    }

    handler.assemble()

    let targetIndex = handler.assembler.cursor - 1
    narrateTheComposer(
      narrator: handler.narrator,
      with: handler.assembler.actualKeys.indices.contains(targetIndex)
        ? handler.assembler.actualKeys[targetIndex] : nil,
      when: prefs.readingNarrationCoverage == 1
    )
    let textToCommit = handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.composer.clear()

    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)

    // 處理逐字選字。
    handler.handleTypewriterSCPCTasks()
    return true
  }

  private func handleStandaloneIntonation(
    input: some InputSignalProtocol,
    existedIntonation: Tekkon.Phonabet,
    keyConsumedByReading: Bool,
    session: Session
  )
    -> Bool? {
    // 專門處理僅有聲調暫存的情況：嘗試將聲調作為讀音或提示使用。
    guard keyConsumedByReading else { return nil }
    if handler.composer.phonabetKeyForQuery(pronounceableOnly: false) == nil {
      if !handler.composer.isPinyinMode, input.isSpace,
         (try? handler.assembler.insertKey(existedIntonation.value)) != nil {
        handler.assemble()
        var theInputting = handler.generateStateOfInputting()
        theInputting.textToCommit = handler.commitOverflownComposition
        handler.composer.clear()
        session.switchState(theInputting)
        return true
      }
      handler.composer.clear()
      return nil
    }

    var resultState = handler.generateStateOfInputting()
    resultState.tooltip = handler.tooltipForStandaloneIntonationMark
    resultState.tooltipDuration = 0
    resultState.data.tooltipColorState = .prompt
    session.switchState(resultState)
    return true
  }
}

extension BPMFFullMatchTypewriter {
  /// 以結構化形式返回前一個游標位置的讀音與字面資訊。
  /// - Returns: 可用於聲調覆寫的讀音快照。
  func getPreviousRearSyllableSnapshot() -> RearSyllableSnapshot? {
    let assembler = handler.assembler
    if assembler.cursor == 0 { return nil }
    let cursorPrevious = max(assembler.cursor - 1, 0)
    guard assembler.keys.indices.contains(cursorPrevious) else { return nil }
    let readingKey = assembler.actualKeys[cursorPrevious]
    guard !readingKey.isEmpty else { return nil }
    var playbackComposer = handler.composer
    playbackComposer.clear()
    // 直接使用注音符號重建 composer 狀態，繞過鍵盤佈局轉換。
    // 注意：actualKeys 永遠是注音符號，與 parser 模式無關。
    for scalar in readingKey.unicodeScalars {
      playbackComposer.receiveKey(fromPhonabet: scalar)
    }
    let cachedIntonation = playbackComposer.intonation.isValid ? playbackComposer.intonation : nil
    if playbackComposer.hasIntonation() { playbackComposer.doBackSpace() }
    // 注意：移除聲調後的 composer 可能無法查詢，但仍可用於重建讀音。
    let surfaceText: String? = {
      let gramHit = assembler.assembledSentence.findGram(at: cursorPrevious)
      guard let gramHit else { return nil }
      let offset = cursorPrevious - gramHit.range.lowerBound
      let characters = gramHit.gram.value.map(\.description)
      if characters.indices.contains(offset) { return characters[offset] }
      return gramHit.gram.value
    }()
    return RearSyllableSnapshot(
      readingKey: readingKey,
      composerSansIntonation: playbackComposer,
      intonation: cachedIntonation,
      surfaceText: surfaceText
    )
  }

  func narrateTheComposer(
    narrator: (any SpeechNarratorProtocol)?,
    with maybeKey: String? = nil,
    when condition: Bool,
    allowDuplicates: Bool = true
  ) {
    guard condition, let narrator else { return }
    let composer = handler.composer
    let prefs = handler.prefs
    guard var keyToNarrate = maybeKey ?? composer
      .phonabetKeyForQuery(pronounceableOnly: prefs.acceptLeadingIntonations)
    else { return }

    // 防禦性轉換：若內容含 ASCII 字母（可能是拼音殘留），嘗試轉為注音
    if keyToNarrate.contains(where: { $0.isASCII && $0.isLetter }) {
      let converted = Tekkon.cnvHanyuPinyinToPhona(targetJoined: keyToNarrate, newToneOne: "")
      if !converted.contains(where: { $0.isASCII && $0.isLetter }) {
        keyToNarrate = converted
      } else {
        let fallback = composer.value.replacingOccurrences(of: " ", with: "")
        guard !fallback.isEmpty else { return }
        keyToNarrate = fallback
      }
    }

    // 若 key 本身無明確聲調記號，補上 ˉ（陰平）以便 TTS 正確朗讀
    let hasExplicitTone = keyToNarrate.unicodeScalars.last.map {
      ["ˊ", "ˇ", "ˋ", "˙"].contains($0.description)
    } ?? false
    if !hasExplicitTone {
      keyToNarrate.append("ˉ")
    }

    narrator.narrate(keyToNarrate, allowDuplicates: allowDuplicates)
  }

  /// 偵測某個傳入的按鍵訊號是否為聲調鍵。
  /// - Parameter input: 傳入的按鍵訊號。
  /// - Returns: 判斷結果：是否為聲調鍵。
  func isIntonationKey(_ input: InputSignalProtocol) -> Bool {
    var theComposer = handler.composer // 複製一份用來做實驗。
    theComposer.clear() // 清空各種槽的內容。
    theComposer.receiveKey(fromString: input.text)
    return theComposer.hasIntonation(withNothingElse: true)
  }

  /// 引入 macOS 內建注音輸入法的行為，允許用除了陰平以外的聲調鍵覆寫前一個漢字的讀音。
  /// 但如果要覆寫的內容會導致游標身後的字音沒有對應的辭典記錄的話，那就只蜂鳴警告一下。
  func performRearIntonationOverrideIfNeeded(
    _ input: InputSignalProtocol,
    inputText: inout String
  )
    -> Bool? {
    guard let session = handler.session else { return nil }
    guard !intonationKeyBehavior.skipHandling else { return nil }
    guard handler.composer.isEmpty else { return nil }
    guard !input.isSpace else { return nil }
    guard isIntonationKey(input) else { return nil }
    guard let snapshot = getPreviousRearSyllableSnapshot() else { return nil }
    // 將輸入的按鍵轉換為實際的聲調符號，以便與快照中的聲調進行比較。
    var tempComposer = handler.composer
    tempComposer.clear()
    tempComposer.receiveKey(fromString: inputText)
    let incomingIntonation = tempComposer.intonation
    guard incomingIntonation.isValid else { return true }
    if let existingIntonation = snapshot.intonation,
       existingIntonation == incomingIntonation,
       intonationKeyBehavior.onlyOverrideDifferentTones {
      return nil
    }
    guard let overrideRequest = snapshot.makeOverrideRequest(
      newIntonation: incomingIntonation
    ) else {
      errorCallback("E2FAD61C：覆寫聲調時無法生成讀音快照。")
      return true
    }
    switch overrideRearKey(with: overrideRequest) {
    case .success:
      handler.retrievePOMSuggestions(apply: true)
      let textToCommit = handler.commitOverflownComposition
      let targetIndex = handler.assembler.cursor - 1
      if handler.assembler.actualKeys.indices.contains(targetIndex) {
        narrateTheComposer(
          narrator: handler.narrator,
          with: handler.assembler.actualKeys[targetIndex],
          when: handler.prefs.readingNarrationCoverage >= 1,
          allowDuplicates: true
        )
      }
      var refreshedState = handler.generateStateOfInputting()
      refreshedState.textToCommit = textToCommit
      refreshedState.tooltip = "Previous intonation has been overridden.".i18n
      refreshedState.tooltipDuration = 2
      refreshedState.data.tooltipColorState = .normal
      session.switchState(refreshedState)
      return true
    case .noLexiconRecord:
      let replacementReading = overrideRequest.replacementReading
      errorCallback(
        "4B0DD2D4：語彙庫內無「\(replacementReading)」的匹配記錄，放棄覆寫游標身後的內容。"
      )
      return true
    case .cursorAtRearestPosition, .stateMismatch:
      return nil
    case .failedToFinalize:
      errorCallback("E0F67CE5：覆寫聲調時發生非預期錯誤。")
      return true
    }
  }

  /// 處理游標身後單一讀音的聲調覆寫需求。
  /// - Parameter request: 聲調覆寫請求資料。
  /// - Returns: 覆寫結果狀態。
  fileprivate func overrideRearKey(with request: ToneOverrideRequest) -> ToneOverrideResult {
    let assembler = handler.assembler
    guard assembler.cursor > 0 else { return .stateMismatch }
    let targetIndex = assembler.cursor - 1
    guard assembler.keys.indices.contains(targetIndex) else { return .stateMismatch }
    guard assembler.actualKeys[targetIndex] == request.originalReading else { return .stateMismatch }
    guard handler.currentLM.hasUnigramsFor(keyArray: [request.replacementReading]) else {
      return .noLexiconRecord
    }
    guard (try? assembler.dropKey(direction: .rear)) != nil else { return .cursorAtRearestPosition }
    /// 從這個位置開始，assembler 的內容已有所改變，得重新組句。
    defer {
      handler.assemble()
    }
    guard (try? assembler.insertKey(request.replacementReading)) != nil else {
      try? assembler.dropKey(direction: .front)
      try? assembler.insertKey(request.originalReading)
      return .failedToFinalize
    }
    return .success
  }

  // MARK: - RearSyllableSnapshot

  struct RearSyllableSnapshot {
    /// 組字器當中的既有讀音索引鍵。
    let readingKey: String
    /// 不含聲調的注拼槽狀態，供覆寫運算重建讀音字串。
    let composerSansIntonation: Tekkon.Composer
    /// 原本的聲調內容（若有）。
    let intonation: Tekkon.Phonabet?
    /// 對應的字面顯示內容（若可取得）。
    let surfaceText: String?

    /// 生成對應的聲調覆寫請求資料。
    /// - Parameter newIntonation: 使用者新指定的聲調。
    /// - Returns: 供組字器消化的覆寫請求。
    func makeOverrideRequest(newIntonation: Tekkon.Phonabet) -> ToneOverrideRequest? {
      var composerCopy = composerSansIntonation
      // 直接使用注音符號，繞過鍵盤佈局轉換。
      if let scalar = newIntonation.value.unicodeScalars.first {
        composerCopy.receiveKey(fromPhonabet: scalar)
      }
      guard let replacementReading = composerCopy
        .phonabetKeyForQuery(pronounceableOnly: true)
      else {
        return nil
      }
      return ToneOverrideRequest(
        originalReading: readingKey,
        replacementReading: replacementReading,
        newIntonation: newIntonation,
        surfaceText: surfaceText
      )
    }
  }

  // MARK: - ToneOverrideRequest

  struct ToneOverrideRequest {
    /// 原本存在於組字器內的讀音索引鍵。
    let originalReading: String
    /// 準備覆寫的新讀音索引鍵。
    let replacementReading: String
    /// 使用者指定的新聲調內容。
    let newIntonation: Tekkon.Phonabet
    /// 供未來延伸用途的字面顯示內容。
    let surfaceText: String?
  }

  // MARK: - ToneOverrideResult

  enum ToneOverrideResult {
    /// 覆寫成功。
    case success
    /// 缺少對應的語彙記錄。
    case noLexiconRecord
    /// 游標或讀音狀態不符預期。
    case stateMismatch
    /// 游標身後沒有位置了，也就是說游標已經位於最後方的位置。
    case cursorAtRearestPosition
    /// 插入新讀音時未能完成必要的節點更新。
    case failedToFinalize
  }

  // MARK: - IntonationKeyBehavior

  enum IntonationKeyBehavior: Int {
    /// 嘗試對游標正後方的字音覆寫聲調，且重設其選字狀態。
    case overridePreviousPosIntonationWithCandidateReset = 0
    /// 僅在鍵入的聲調與游標正後方的字音不同時，嘗試覆寫。
    case onlyOverridePreviousPosIfDifferentTone = 1
    /// 始終在內文組字區內鍵入聲調符號。
    case alwaysTypeIntonationsToTheCompositionBuffer = 2

    // MARK: Lifecycle

    init(pref: (any PrefMgrProtocol)? = nil) {
      self = .init(
        rawValue: (pref ?? PrefMgr.sharedSansDidSetOps).specifyIntonationKeyBehavior
      ) ?? .overridePreviousPosIntonationWithCandidateReset
    }

    // MARK: Internal

    /// 僅在鍵入的聲調與游標正後方的字音不同時，嘗試覆寫。
    var onlyOverrideDifferentTones: Bool {
      self == .onlyOverridePreviousPosIfDifferentTone
    }

    var skipHandling: Bool {
      self == .alwaysTypeIntonationsToTheCompositionBuffer
    }
  }
}
