// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - PhonabetTypewriter

/// 注音按鍵輸入處理 (Handle BPMF Keys)
@frozen
public struct PhonabetTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public typealias Phonabet = Tekkon.Phonabet

  public let handler: Handler

  /// Backspace 雙擊的時間門檻（秒）
  private let backspaceDoubleTapThreshold: TimeInterval = 0.3

  /// 用來處理 InputHandler.HandleInput() 當中的與注音输入有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
   public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    let prefs = handler.prefs

    // MARK: 智慧中英文切換 - 臨時英文模式攔截
    if prefs.smartChineseEnglishSwitchEnabled, handler.smartSwitchState.isTempEnglishMode {
      if let result = handleTempEnglishMode(input, session: session) {
        return result
      }
    }

    var inputText = (input.inputTextIgnoringModifiers ?? input.text)
    inputText = inputText.lowercased().applyingTransformFW2HW(reverse: false)
    let existedIntonation = handler.composer.intonation
    let skipPhoneticHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isShiftHold || input.isCommandHold
    let confirmCombination = input.isSpace || input.isEnter

    // MARK: 智慧中英文切換 - 觸發偵測（在 composer 接收之前記錄狀態）
    let smartSwitchEnabled = prefs.smartChineseEnglishSwitchEnabled
    let composerValueBefore = handler.composer.value
    let consonantBefore = handler.composer.consonant.value
    let semivowelBefore = handler.composer.semivowel.value
    let vowelBefore = handler.composer.vowel.value
    let isLetterInput = !skipPhoneticHandling && !confirmCombination
      && inputText.count == 1 && inputText.first?.isLetter == true
    let isValidPhonabetKey = handler.composer.inputValidityCheck(charStr: inputText)

    // 重置智慧切換計數（Enter/Esc/Ctrl/Cmd 時）
    if smartSwitchEnabled, shouldResetSmartSwitchState(input) {
      handler.smartSwitchState.reset()
    }

    // 先嘗試讓注拼槽消化當前按鍵（含可能的聲調覆寫），以保留既有行為。
    let consumption = consumeReadingInputIfNeeded(
      input: input,
      inputText: &inputText,
      skipPhoneticHandling: skipPhoneticHandling,
      confirmCombination: confirmCombination,
      prefs: prefs,
      session: session
    )

    // MARK: 智慧中英文切換 - composer 接收後立即判斷（在 handled 提前返回之前）
    if smartSwitchEnabled, isLetterInput {
      if let result = evaluateSmartSwitch(
        inputText: inputText,
        isValidPhonabetKey: isValidPhonabetKey,
        composerValueBefore: composerValueBefore,
        consonantBefore: consonantBefore,
        semivowelBefore: semivowelBefore,
        vowelBefore: vowelBefore,
        keyConsumedByReading: consumption.keyConsumed,
        session: session
      ) {
        return result
      }
    }

    if let handled = consumption.handled { return handled }

    // 若讀音已備妥，嘗試組字並進入候選或直接提交。
    if let composed = composeReadingIfReady(
      input: input,
      inputText: inputText,
      confirmCombination: confirmCombination,
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

  private func composeReadingIfReady(
    input: some InputSignalProtocol,
    inputText: String,
    confirmCombination: Bool,
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

    let maybeKey = handler.composer.phonabetKeyForQuery(pronounceableOnly: prefs.acceptLeadingIntonations)
    guard let readingKey = maybeKey else { return nil }

    if !handler.currentLM.hasUnigramsFor(keyArray: [readingKey]) {
      errorCallback("B49C0979：語彙庫內無「\(readingKey)」的匹配記錄。")

      if prefs.keepReadingUponCompositionError {
        if handler.composer.hasIntonation() { handler.composer.doBackSpace() }
        session.switchState(handler.generateStateOfInputting())
        return true
      }

      // 路徑 D：讀音無效時，若智慧中英文切換啟用且有按鍵序列記錄，
      // 則直接將 keySequence 作為英文 commit 出去（如：ㄔㄟ → "to"）。
      if prefs.smartChineseEnglishSwitchEnabled,
         !handler.smartSwitchState.isTempEnglishMode,
         !handler.smartSwitchState.keySequence.isEmpty {
        let keysToCommit = handler.smartSwitchState.keySequence
        handler.smartSwitchState.reset()
        handler.composer.clear()
        freezeAssemblerContentIfNeeded()
        handler.assembler.clear()
        session.switchState(State.ofCommitting(textToCommit: keysToCommit))
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
    } else if !handler.assembler.insertKey(readingKey) {
      errorCallback(
        "3CF278C9: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。"
      )
      return true
    }

    narrateTheComposer(
      narrator: handler.narrator,
      with: readingKey,
      when: prefs.readingNarrationCoverage == 1
    )

    handler.assemble()
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
         handler.assembler.insertKey(existedIntonation.value) {
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

extension PhonabetTypewriter {
  /// 以結構化形式返回前一個游標位置的讀音與字面資訊。
  /// - Returns: 可用於聲調覆寫的讀音快照。
  func getPreviousRearSyllableSnapshot() -> RearSyllableSnapshot? {
    let assembler = handler.assembler
    if assembler.cursor == 0 { return nil }
    let cursorPrevious = max(assembler.cursor - 1, 0)
    guard assembler.keys.indices.contains(cursorPrevious) else { return nil }
    let readingKey = assembler.keys[cursorPrevious]
    guard !readingKey.isEmpty else { return nil }
    var playbackComposer = handler.composer
    playbackComposer.clear()
    // 直接使用注音符號重建 composer 狀態，繞過鍵盤佈局轉換。
    if playbackComposer.isPinyinMode {
      playbackComposer.receiveSequence(readingKey, isRomaji: true)
    } else {
      for scalar in readingKey.unicodeScalars {
        playbackComposer.receiveKey(fromPhonabet: scalar)
      }
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
    let maybeKey = maybeKey ?? composer
      .phonabetKeyForQuery(pronounceableOnly: prefs.acceptLeadingIntonations)
    guard var keyToNarrate = maybeKey else { return }
    if composer.intonation == Phonabet(" ") { keyToNarrate.append("ˉ") }
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
    guard assembler.keys[targetIndex] == request.originalReading else { return .stateMismatch }
    guard assembler.langModel.hasUnigramsFor(keyArray: [request.replacementReading]) else {
      return .noLexiconRecord
    }
    guard assembler.dropKey(direction: .rear) else { return .cursorAtRearestPosition }
    /// 從這個位置開始，assembler 的內容已有所改變，得重新組句。
    defer {
      handler.assemble()
    }
    guard assembler.insertKey(request.replacementReading) else {
      _ = assembler.dropKey(direction: .front)
      _ = assembler.insertKey(request.originalReading)
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

  // MARK: - Smart Switch Helpers

  /// 檢查是否應該重置智慧切換狀態
  private func shouldResetSmartSwitchState(_ input: InputSignalProtocol) -> Bool {
    // 當輸入 Enter、Esc 或其他特殊按鍵時重置
    return input.isEnter || input.isEsc ||
      (input.isControlHold || input.isCommandHold)
  }

  /// 處理臨時英文模式下的按鍵輸入
  private func handleTempEnglishMode(
    _ input: some InputSignalProtocol,
    session: Session
  ) -> Bool? {
    // 檢查是否為返回中文模式的觸發鍵
    if isTriggerToReturnToChinese(input) {
      return freezeAndReturnToChinese(session: session)
    }

    // 處理 Backspace
    if input.isBackSpace {
      return handleBackspaceInTempEnglishMode(input, session: session)
    }

    // Enter 鍵：提交凍結段落 + 英文緩衝，消耗 Enter 避免穿透給應用程式。
    if input.isEnter {
      let frozen = handler.smartSwitchState.frozenDisplayText
      let englishText = handler.smartSwitchState.exitTempEnglishMode()
      handler.smartSwitchState.clearFrozenSegments()
      let textToCommit = frozen + englishText
      if !textToCommit.isEmpty {
        session.switchState(State.ofCommitting(textToCommit: textToCommit))
      }
      return true
    }

    // 處理一般英文字母輸入
    let char = input.text
    if char.count == 1, char.first?.isLetter == true {
      handler.smartSwitchState.appendEnglishChar(char)
      // 建構 ofInputting 狀態：凍結段落（若有）+ 英文緩衝。
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let combinedDisplay = frozen + buffer
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }

    // 其他按鍵直接提交並處理
    return commitEnglishAndProcess(input, session: session)
  }

  /// 檢查是否為返回中文模式的觸發鍵
  private func isTriggerToReturnToChinese(_ input: InputSignalProtocol) -> Bool {
    return input.isSpace || input.isTab || isPunctuationKey(input)
  }

  /// 檢查是否為標點符號鍵
  private func isPunctuationKey(_ input: InputSignalProtocol) -> Bool {
    let text = input.text
    guard text.count == 1 else { return false }
    let punctuationChars = CharacterSet(charactersIn: ",.?!;:'\"[]{}()+-*/=<>@#$%^&~`|\\")
    return text.unicodeScalars.allSatisfy { punctuationChars.contains($0) }
  }

  /// 凍結英文緩衝並返回中文模式（不提交給 OS）
  private func freezeAndReturnToChinese(session: Session) -> Bool {
    let englishText = handler.smartSwitchState.exitTempEnglishMode()

    if !englishText.isEmpty {
      handler.smartSwitchState.freezeSegment(englishText)
    }

    // 更新顯示：以 generateStateOfInputting 產生包含凍結段落的組字區狀態。
    // 若組字區（含凍結）非空，顯示 ofInputting；否則顯示 ofAbortion。
    if !handler.smartSwitchState.frozenSegments.isEmpty || !handler.assembler.isEmpty {
      session.switchState(handler.generateStateOfInputting(guarded: true))
    } else {
      session.switchState(State.ofAbortion())
    }

    return false // 讓後續邏輯繼續處理（如空格觸發選字等）
  }

  /// 提交英文並處理當前按鍵
  private func commitEnglishAndProcess(
    _ input: InputSignalProtocol,
    session: Session
  ) -> Bool {
    let englishText = handler.smartSwitchState.exitTempEnglishMode()

    if !englishText.isEmpty {
      // 使用 ofCommitting 狀態直接提交英文文字。
      session.switchState(State.ofCommitting(textToCommit: englishText))
    }

    return false // 讓後續邏輯處理當前按鍵
  }

  /// 在臨時英文模式下處理 Backspace
  private func handleBackspaceInTempEnglishMode(
    _ input: InputSignalProtocol,
    session: Session
  ) -> Bool {
    let now = Date()
    let timeDiff = now.timeIntervalSince(handler.smartSwitchState.lastBackspaceTime ?? Date.distantPast)

    if timeDiff <= backspaceDoubleTapThreshold {
      // 雙擊 Backspace：刪除所有並返回中文模式
      handler.smartSwitchState.reset()
      session.switchState(State.ofAbortion())
      return true
    } else {
      // 單擊 Backspace：刪除最後一個字母
      handler.smartSwitchState.deleteLastEnglishChar()
      handler.smartSwitchState.lastBackspaceTime = now
      handler.smartSwitchState.backspaceCount = 1

      if handler.smartSwitchState.englishBuffer.isEmpty {
        // 如果已經刪完，返回中文模式
        handler.smartSwitchState.reset()
        session.switchState(State.ofAbortion())
      } else {
        // 顯示剩餘的英文緩衝（直接建構 ofInputting）
        let buffer = handler.smartSwitchState.englishBuffer
        let state = State.ofInputting(
          displayTextSegments: [buffer],
          cursor: buffer.count,
          highlightAt: nil
        )
        session.switchState(state)
      }
      return true
    }
  }

  /// 若 assembler 非空，將已組漢字凍結至 frozenSegments（不提交給 OS）。
  /// 用於智慧中英文切換觸發前，保留組字區的漢字內容讓使用者最後一併提交。
  private func freezeAssemblerContentIfNeeded() {
    guard !handler.assembler.isEmpty else { return }
    // `generateStateOfInputting(sansReading:)` 在 InputHandler_HandleStates.swift 中已將
    // frozenSegments 前置於顯示段落，因此 fullDisplayed = frozenDisplayText + assemblerText。
    // 這裡剝除已知的凍結前綴，只取 assembler 部分做為新的凍結段落。
    let fullDisplayed = handler.generateStateOfInputting(sansReading: true).displayedText
    let alreadyFrozen = handler.smartSwitchState.frozenDisplayText
    guard fullDisplayed.hasPrefix(alreadyFrozen) else {
      assertionFailure("freezeAssemblerContentIfNeeded: fullDisplayed '\(fullDisplayed)' does not start with alreadyFrozen '\(alreadyFrozen)'")
      return
    }
    let assemblerPart = String(fullDisplayed.dropFirst(alreadyFrozen.count))
    guard !assemblerPart.isEmpty else { return }
    handler.smartSwitchState.freezeSegment(assemblerPart)
  }

  /// 在 composer 接收按鍵後，判斷是否應觸發智慧中英文切換。
  ///
  /// 三條觸發路徑：
  /// - 路徑 A（有無效鍵的排列，如倚天/許氏）：`inputValidityCheck` 返回 false，
  ///   代表該字母根本不是有效注音按鍵，composer 沒有接收 → 立即觸發
  /// - 路徑 B（consonant 覆蓋）：composer 接收前 consonant slot 非空，
  ///   接收後 consonant slot 值改變（被另一個聲母覆蓋）→ 立即觸發
  /// - 路徑 C（semivowel/vowel 後接 consonant）：composer 接收前 semivowel 或 vowel slot 非空且
  ///   consonant slot 空，接收後 consonant slot 從空變成非空 → 立即觸發
  ///   （在大千排列中，正常注音輸入者會先打聲母再打介音/韻母；介音或韻母後接聲母是英文輸入的標誌）
  ///   典型例子：'i'（ㄛ）後接 's'（ㄋ）→ 英文 "is" 而非日文「の」（ㄋㄛ）
  ///
  /// keySequence 從 composer 不為空的第一個按鍵開始累積，包含所有有效的注音按鍵。
  /// 觸發時把整個 keySequence 轉成英文緩衝輸出。
  ///
  /// - Returns: `true` 表示已攔截並觸發英文模式，`nil` 表示繼續正常注音處理
  private func evaluateSmartSwitch(
    inputText: String,
    isValidPhonabetKey: Bool,
    composerValueBefore: String,
    consonantBefore: String,
    semivowelBefore: String,
    vowelBefore: String,
    keyConsumedByReading: Bool,
    session: Session
  ) -> Bool? {
    // 路徑 A：排列中本來就沒有這個字母（倚天 q/x 等），composer 未接收
    if !isValidPhonabetKey {
      handler.smartSwitchState.keySequence.append(inputText)
      return triggerTempEnglishMode(session: session)
    }

    guard keyConsumedByReading else { return nil }

    let composerValueAfter = handler.composer.value
    let consonantAfter = handler.composer.consonant.value

    // composer 從空變成非空（第一個按鍵進入 composer），開始追蹤按鍵序列
    if composerValueBefore.isEmpty, !composerValueAfter.isEmpty {
      handler.smartSwitchState.keySequence = inputText
      handler.smartSwitchState.invalidKeyCount = 0
      return nil
    }

    // composer 非空時繼續追蹤
    if !composerValueBefore.isEmpty {
      if composerValueAfter.isEmpty {
        // composer 被清空（組字成功或被清除）→ 重置狀態，不觸發
        handler.smartSwitchState.reset()
        return nil
      }

      // 路徑 B：consonant slot 被覆蓋（consonant 從某值變成另一個值）
      if !consonantBefore.isEmpty, consonantAfter != consonantBefore {
        handler.smartSwitchState.keySequence.append(inputText)
        handler.composer.clear()
        freezeAssemblerContentIfNeeded()
        handler.assembler.clear()
        return triggerTempEnglishMode(session: session)
      }

      // 路徑 B'：vowel slot 被再次填入（vowelBefore 非空 + consonant 沒有改變 + vowelAfter 非空）
      // 在大千排列中，韻母後繼續打字母，若該字母又被解讀為韻母，是英文輸入的標誌
      // 有聲母：'a'=ㄇ + 'p'=ㄡ（有聲母時）+ 'p'=ㄡ（再次 vowel）→ "app"
      // 無聲母：（Shift+A 系統輸出後）'p'=ㄣ + 'p'=ㄣ（再次 vowel）→ "pp"（"App" 場景）
      let vowelAfter = handler.composer.vowel.value
      if !vowelBefore.isEmpty, consonantAfter == consonantBefore, !vowelAfter.isEmpty {
        handler.smartSwitchState.keySequence.append(inputText)
        handler.composer.clear()
        freezeAssemblerContentIfNeeded()
        handler.assembler.clear()
        return triggerTempEnglishMode(session: session)
      }

      // 路徑 C（含 C'）：semivowel 或 vowel 後接 consonant
      // 在大千排列中，正常注音輸入者會先打聲母再打介音/韻母；
      // 介音或韻母後接聲母是英文輸入的標誌（如 'i'=ㄛ 後接 's'=ㄋ → "is" 非「の」）
      if (!semivowelBefore.isEmpty || !vowelBefore.isEmpty), consonantBefore.isEmpty, !consonantAfter.isEmpty {
        handler.smartSwitchState.keySequence.append(inputText)
        handler.composer.clear()
        freezeAssemblerContentIfNeeded()
        handler.assembler.clear()
        return triggerTempEnglishMode(session: session)
      }

      // 按鍵讓 composer 有正常進展 → 追加到序列，重置計數
      handler.smartSwitchState.keySequence.append(inputText)
      handler.smartSwitchState.invalidKeyCount = 0
    }

    return nil
  }

  /// 執行進入臨時英文模式的動作，將 `keySequence` 內容放入英文緩衝並更新畫面。
  private func triggerTempEnglishMode(session: Session) -> Bool {
    let keysToConvert = handler.smartSwitchState.keySequence
    handler.smartSwitchState.enterTempEnglishMode()
    handler.smartSwitchState.appendEnglishChar(keysToConvert)

    // 先用 ofAbortion 清除 composer 的注音顯示（不會 commit previous displayedText）。
    session.switchState(State.ofAbortion())

    // 建構顯示狀態：凍結漢字（若有）+ 英文緩衝。
    let frozen = handler.smartSwitchState.frozenDisplayText
    let buffer = handler.smartSwitchState.englishBuffer
    let combinedDisplay = frozen + buffer
    if !combinedDisplay.isEmpty {
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
      session.switchState(state)
    }
    return true
  }
}
