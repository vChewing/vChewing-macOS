// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - MixedAlphanumericalTypewriter

@frozen
public struct MixedAlphanumericalTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    guard !handler.composer.isPinyinMode else {
      var typewriter = BPMFFullMatchTypewriter(handler)
      typewriter.isToneOverrideEnabled = { false }
      typewriter.isLeadingIntonationAccepted = { false }
      return typewriter.handle(input)
    }
    // 波浪符號鍵（symbol menu physical key）應交還上層分診流程處理。
    // mixed mode 若此時已有可提交內容，先提交全部內容，再放行按鍵事件。
    if input.isSymbolMenuPhysicalKey {
      if !handler.isConsideredEmptyForNow {
        let chineseText = handler.committableDisplayText(sansReading: true)
        let asciiText = handler.mixedAlphanumericalBuffer
        handler.composer.clear()
        handler.mixedAlphanumericalBuffer.removeAll()
        session.switchState(State.ofCommitting(textToCommit: chineseText + asciiText))
      }
      return nil
    }
    // Space 必須先於 isReservedKey guard 處理：Space 的 keyCode 屬於 reserved key，
    // 若不提前攔截，Space 將返回 nil，無法走到注音確認路徑。
    if input.isSpace {
      guard !handler.mixedAlphanumericalBuffer.isEmpty else { return nil }
      let shouldPreferASCIIWordOnSpace = shouldPreferASCIIWordPath(
        fullInput: handler.mixedAlphanumericalBuffer,
        minimumOverwriteCount: 1
      )
      if !shouldPreferASCIIWordOnSpace, tryAutoSplitASCIIAndPhoneticSuffix(
        fullInput: handler.mixedAlphanumericalBuffer + " ",
        inputInvalid: false,
        session: session,
        requiresWordLikePrefix: true
      ) {
        return true
      }
      if !handler.composer.isEmpty, !shouldPreferASCIIWordOnSpace {
        let originalMixedBuffer = handler.mixedAlphanumericalBuffer
        var typewriter = BPMFFullMatchTypewriter(handler)
        typewriter.isToneOverrideEnabled = { false }
        typewriter.isLeadingIntonationAccepted = { false }
        typewriter.onLexiconMatchFailure = { injectedHandler, _, injectedSession in
          // 辭典查詢無結果時，回退為直接提交中文段 + ASCII buffer + 空白。
          guard !originalMixedBuffer.isEmpty else { return nil }
          let chineseText = injectedHandler.committableDisplayText(sansReading: true)
          let asciiText = originalMixedBuffer + " "
          injectedHandler.composer.clear()
          injectedHandler.mixedAlphanumericalBuffer.removeAll()
          injectedSession.switchState(State.ofCommitting(textToCommit: chineseText + asciiText))
          return true
        }
        handler.mixedAlphanumericalBuffer.removeAll()
        let handled = typewriter.handle(input)
        if handled != true {
          handler.mixedAlphanumericalBuffer = originalMixedBuffer
        }
        return handled
      }
      // composer 為空時：commit 已組字的中文（若有）+ ASCII buffer + 空白
      let chineseText = handler.committableDisplayText(sansReading: true)
      let asciiText = handler.mixedAlphanumericalBuffer + " "
      handler.mixedAlphanumericalBuffer.removeAll()
      session.switchState(State.ofCommitting(textToCommit: chineseText + asciiText))
      return true
    }
    // In mixed mode, Option+main-area ASCII keys should commit
    // raw ASCII immediately. Shift still decides whether the committed glyph is the
    // base or shifted ASCII variant, but Option glyph substitutions are ignored.
    if let literalASCIIText = resolveLiteralASCIIMainAreaText(input) {
      return commitLiteralASCIIImmediately(literalASCIIText, session: session)
    }
    let isPunctuationChar = !input.text.isEmpty
      && input.text.unicodeScalars.allSatisfy(isPunctCharOrSymbol)
    guard !(input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey)
      || isPunctuationChar
    else {
      return nil
    }

    // 大寫英文字母保留原大小寫。
    // Shift+符號與 ASCII 標點在 mixed 上下文中需保留可見字元語義，
    // 避免被 charactersIgnoringModifiers 還原為基底鍵而誤入注音判斷。
    let visibleInputText = resolveVisibleInputText(input)
    let isASCIIPunctuation = visibleInputText.unicodeScalars.count == 1
      && visibleInputText.unicodeScalars.allSatisfy {
        $0.isASCII && isPunctCharOrSymbol($0)
      }
    let isUppercaseLetter = visibleInputText.range(of: "^[A-Z]$", options: .regularExpression) != nil
    let bufferHasASCIIAlnum = handler.mixedAlphanumericalBuffer.range(
      of: "[A-Za-z0-9]",
      options: .regularExpression
    ) != nil
    let bufferContainsNonPhoneticKey = handler.mixedAlphanumericalBuffer.contains {
      !handler.composer.inputValidityCheck(charStr: $0.description)
    }
    let baseInputTextIgnoringModifiers = (input.inputTextIgnoringModifiers ?? input.text)
      .lowercased().applyingTransformFW2HW(reverse: false)
    let isBaseInputPhoneticKey = handler.composer.inputValidityCheck(charStr: baseInputTextIgnoringModifiers)
    let shouldForceByBufferContext =
      (bufferHasASCIIAlnum || bufferContainsNonPhoneticKey) && !isBaseInputPhoneticKey
    let forceASCIIPunctuationPath =
      isASCIIPunctuation && (input.isShiftHold || shouldForceByBufferContext)

    var inputText: String
    switch (isUppercaseLetter, forceASCIIPunctuationPath) {
    case (_, true), (true, _):
      inputText = visibleInputText
    default:
      inputText = (input.inputTextIgnoringModifiers ?? input.text)
      inputText = inputText.lowercased().applyingTransformFW2HW(reverse: false)
    }
    let isPhoneticKeyRaw = handler.composer.inputValidityCheck(charStr: inputText)
    // 摁 Shift 敲入的 ASCII 不得被記入注音輸入。
    // 當 Shift 被按住且輸出為 ASCII 可列印字元時，強制視為 ASCII 路徑。
    let isShiftASCII = input.isShiftHold && visibleInputText.range(of: "^[ -~]$", options: .regularExpression) != nil

    // 若當前鍵（含修飾鍵）在標點詞庫有可用項，
    // 視為 CJK 標點輸入，優先回到既有標點管線處理。
    // 但若目前鍵位本身就是合法注音鍵，則必須讓注音輸入優先。
    // 僅 Shift+? 需強制保留 ASCII 語義，不回到 CJK 標點管線。
    // 其餘 Shift 標點（例如 Shift+` 的 ~）仍需維持既有 CJK 標點查詢能力。
    let punctuationQueryStrings = handler.punctuationQueryStrings(input: input)
    let isShiftQuestionMark = input.isShiftHold && ["?", "？"].contains(visibleInputText)
    let matchesCJKPunctuation = !isShiftQuestionMark && isPunctuationChar
      && !isPhoneticKeyRaw && punctuationQueryStrings.contains {
        handler.currentLM.hasUnigramsFor(keyArray: [$0])
      }
    if matchesCJKPunctuation {
      if !handler.mixedAlphanumericalBuffer.isEmpty {
        let chineseText = handler.committableDisplayText(sansReading: true)
        let asciiText = handler.mixedAlphanumericalBuffer
        handler.composer.clear()
        handler.mixedAlphanumericalBuffer.removeAll()
        session.switchState(State.ofCommitting(textToCommit: chineseText + asciiText))
      }
      return nil
    }

    guard !input.isControlHold, !input.isOptionHold, !input.isCommandHold else { return nil }
    // 移除對空 buffer 的 Shift+大寫字母提前返回，改由下方統一處理（保留大寫）。
    let isPhoneticKey = (forceASCIIPunctuationPath || isShiftASCII) ? false : isPhoneticKeyRaw
    let isASCIIPrintable = inputText.range(of: "^[ -~]$", options: .regularExpression) != nil
    guard isPhoneticKey || isASCIIPrintable else { return nil }

    // leading digit / uppercase 阻斷。
    // ASCII 數字與大寫字母不得被 composer 吸收，確保後續 auto-split 有機會正確切分。
    let isASCIIDigit = inputText.range(of: "^[0-9]$", options: .regularExpression) != nil
    let isToneDigit: Bool = {
      guard isASCIIDigit else { return false }
      var testComposer = handler.composer
      testComposer.clear()
      testComposer.receiveKey(fromString: inputText)
      return testComposer.hasIntonation(withNothingElse: true)
    }()
    let shouldBlockPhoneticAbsorption = (isASCIIDigit && isToneDigit) || isUppercaseLetter

    if handler.mixedAlphanumericalBuffer.isEmpty {
      if isPhoneticKey, !shouldBlockPhoneticAbsorption {
        handler.composer.receiveKey(fromString: inputText)
      } else {
        handler.composer.clear()
      }
      handler.mixedAlphanumericalBuffer = inputText
      session.switchState(handler.generateStateOfInputting())
      return true
    }

    let fullInput = handler.mixedAlphanumericalBuffer + inputText
    if !forceASCIIPunctuationPath, tryAutoSplitASCIIAndPhoneticSuffix(
      fullInput: fullInput,
      inputInvalid: input.isInvalid,
      session: session,
      requiresWordLikePrefix: true
    ) {
      return true
    }

    // 若 fullInput 包含 ASCII 數字或大寫字母，視為非 fully-parser-covered，
    // 讓 auto-split 有機會拆出 ASCII 前綴與注音後綴。
    let fullInputHasUppercase = fullInput.range(of: "[A-Z]", options: .regularExpression) != nil
    let isFullyParserCovered = fullInput.allSatisfy {
      handler.composer.inputValidityCheck(charStr: $0.description)
    } && !fullInputHasUppercase
    let shouldPreferASCIIWordPath = shouldPreferASCIIWordPath(fullInput: fullInput)

    if isFullyParserCovered, !forceASCIIPunctuationPath, !shouldPreferASCIIWordPath {
      var trialComposer = handler.composer
      trialComposer.clear()
      trialComposer.receiveSequence(fullInput, isRomaji: false)

      // Mixed mode 永遠不接受聲調前置鍵入。
      // 若 fullInput 以獨立聲調鍵起頭，跳過整段注音路徑。
      let isLeadingToneBlocked: Bool = {
        guard fullInput.count > 1,
              let firstChar = fullInput.first?.description else { return false }
        var test = handler.composer
        test.clear()
        test.receiveKey(fromString: firstChar)
        return test.hasIntonation(withNothingElse: true)
      }()

      if !isLeadingToneBlocked, trialComposer.isPronounceable {
        if trialComposer.hasIntonation() {
          if let readingKey = trialComposer.phonabetKeyForQuery(
            pronounceableOnly: true
          ), handler.currentLM.hasUnigramsForFast(keyArray: [readingKey]) {
            handler.composer = trialComposer
            guard !input.isInvalid, (try? handler.assembler.insertKey(readingKey)) != nil else {
              errorCallback("3CF278C9-B: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
              return true
            }

            let textToCommit = handler.commitOverflownComposition
            handler.retrievePOMSuggestions(apply: true)
            handler.composer.clear()
            handler.mixedAlphanumericalBuffer.removeAll()

            var inputting = handler.generateStateOfInputting()
            inputting.textToCommit = textToCommit
            session.switchState(inputting)
            handler.handleTypewriterSCPCTasks()
            return true
          }
          // 整段可發音但詞庫查無結果時，不提早返回，讓 auto-split 有機會拆出
          // 「ASCII 前綴 + 注音後綴」以支援 hello你好 這類 mixed 輸入。
        } else {
          handler.composer = trialComposer
          handler.mixedAlphanumericalBuffer = fullInput
          session.switchState(handler.generateStateOfInputting())
          return true
        }
      }
    }

    // 當整段無法直接成為可提交注音時，
    // 嘗試將輸入切成「ASCII 前綴 + 注音後綴」，以支援 hello你好 類型混輸。
    if !forceASCIIPunctuationPath, tryAutoSplitASCIIAndPhoneticSuffix(
      fullInput: fullInput,
      inputInvalid: input.isInvalid,
      session: session
    ) {
      return true
    }

    handler.composer.clear()
    handler.mixedAlphanumericalBuffer = fullInput
    session.switchState(handler.generateStateOfInputting())
    return true
  }

  // MARK: Private

  private struct AutoSplitCandidate {
    let suffixLength: Int
    let prefixText: String
    let readingKey: String
    let bestProbability: Double
    let prefersDigitLeadingSuffix: Bool
    let prefersLongerPureAlnumSuffix: Bool
  }

  @inline(__always)
  private func isPunctCharOrSymbol(_ scalar: String.UnicodeScalarView.Element) -> Bool {
    CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar)
  }

  private func tryAutoSplitASCIIAndPhoneticSuffix(
    fullInput: String,
    inputInvalid: Bool,
    session: Session,
    requiresWordLikePrefix: Bool = false
  )
    -> Bool {
    let fullInputChars = Array(fullInput)
    guard fullInputChars.count > 1 else { return false }
    guard let selectedCandidate = bestAutoSplitCandidate(
      fullInputChars: fullInputChars,
      requiresWordLikePrefix: requiresWordLikePrefix
    ) else { return false }
    return applyAutoSplitCandidate(selectedCandidate, inputInvalid: inputInvalid, session: session)
  }

  private func bestAutoSplitCandidate(
    fullInputChars: [Character],
    requiresWordLikePrefix: Bool
  )
    -> AutoSplitCandidate? {
    // Tekkon 的單一注音音節最多只會佔用 4 個鍵位（聲、介、韻、調）。
    // 若多個 raw suffix 最終對應到同一個 reading key，
    // 代表較長者只是用多餘鍵位覆寫出同一個結果，應保留最短 raw suffix。
    // 額外保守排除含 separator / 空白的怪異 query key，避免把多段 key 當成單筆讀音。
    let maxSingleSyllableKeyCount = 4
    let maxSuffixLength = min(maxSingleSyllableKeyCount, fullInputChars.count - 1)
    var candidateByReadingKey: [String: AutoSplitCandidate] = [:]

    for suffixLength in 1 ... maxSuffixLength {
      let prefixLength = fullInputChars.count - suffixLength
      let prefixText = String(fullInputChars.prefix(prefixLength))
      let suffixText = String(fullInputChars.suffix(suffixLength))
      guard !requiresWordLikePrefix || isWordLikeASCIIPrefix(prefixText) else { continue }
      guard let candidate = buildAutoSplitCandidate(
        suffixLength: suffixLength,
        prefixText: prefixText,
        suffixText: suffixText,
        requiresWordLikePrefix: requiresWordLikePrefix
      ) else { continue }

      if let existing = candidateByReadingKey[candidate.readingKey] {
        if candidate.suffixLength < existing.suffixLength {
          candidateByReadingKey[candidate.readingKey] = candidate
        }
      } else {
        candidateByReadingKey[candidate.readingKey] = candidate
      }
    }

    return candidateByReadingKey.values.max(by: {
      if $0.prefersDigitLeadingSuffix != $1.prefersDigitLeadingSuffix {
        return !$0.prefersDigitLeadingSuffix && $1.prefersDigitLeadingSuffix
      }
      if $0.prefersLongerPureAlnumSuffix, $1.prefersLongerPureAlnumSuffix,
         $0.suffixLength != $1.suffixLength {
        return $0.suffixLength < $1.suffixLength
      }
      if $0.bestProbability != $1.bestProbability {
        return $0.bestProbability < $1.bestProbability
      }
      return $0.suffixLength < $1.suffixLength
    })
  }

  private func buildAutoSplitCandidate(
    suffixLength: Int,
    prefixText: String,
    suffixText: String,
    requiresWordLikePrefix: Bool
  )
    -> AutoSplitCandidate? {
    let prefixHasASCIIAlnum = prefixText.range(of: "[A-Za-z0-9]", options: .regularExpression) != nil
    let suffixStartsWithASCIIDigit = suffixText.unicodeScalars.first.map {
      $0.isASCII && CharacterSet.decimalDigits.contains($0)
    } ?? false
    let suffixStartsWithASCIIPunctuation = suffixText.first?.description.range(
      of: "^[!\"#$%&'()*+,\\\\-./:;<=>?@[\\\\\\\\\\]^_`{|}~]$",
      options: .regularExpression
    ) != nil

    if prefixHasASCIIAlnum, suffixStartsWithASCIIPunctuation {
      return nil
    }

    var trialComposer = handler.composer
    trialComposer.clear()
    trialComposer.receiveSequence(suffixText, isRomaji: false)

    // Mixed mode 永遠不接受聲調前置鍵入。
    // 後綴不能以獨立聲調鍵作為首鍵。
    if let firstChar = suffixText.first?.description {
      var firstKeyTest = handler.composer
      firstKeyTest.clear()
      firstKeyTest.receiveKey(fromString: firstChar)
      if firstKeyTest.hasIntonation(withNothingElse: true) { return nil }
    }

    guard trialComposer.isPronounceable, trialComposer.hasIntonation() else {
      return nil
    }

    guard let readingKey = trialComposer.phonabetKeyForQuery(
      pronounceableOnly: true
    ) else {
      return nil
    }

    guard !readingKey.contains(handler.keySeparator),
          readingKey.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    else {
      return nil
    }

    guard handler.currentLM.hasUnigramsForFast(keyArray: [readingKey]) else {
      return nil
    }

    guard let bestProbability = handler.currentLM.unigramsFor(keyArray: [readingKey])
      .map(\.probability).max()
    else {
      return nil
    }

    return .init(
      suffixLength: suffixLength,
      prefixText: prefixText,
      readingKey: readingKey,
      bestProbability: bestProbability,
      prefersDigitLeadingSuffix: isWordLikeASCIIPrefix(prefixText) && suffixStartsWithASCIIDigit,
      prefersLongerPureAlnumSuffix: requiresWordLikePrefix
        && suffixText.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil
    )
  }

  private func applyAutoSplitCandidate(
    _ selectedCandidate: AutoSplitCandidate,
    inputInvalid: Bool,
    session: Session
  )
    -> Bool {
    let priorChineseText = handler.committableDisplayText(sansReading: true)
    let priorChineseKeyCount = handler.assembler.length

    if priorChineseKeyCount > 0, !priorChineseText.isEmpty {
      session.commit(text: priorChineseText)
      handler.assembler.cursor = 0
      for _ in 0 ..< priorChineseKeyCount {
        _ = handler.dropKey(direction: .front)
      }
    }

    guard !inputInvalid, (try? handler.assembler.insertKey(selectedCandidate.readingKey)) != nil else {
      errorCallback("3CF278C9-C: 得檢查對應的語言模組的 hasUnigramsFor() 是否有誤判之情形。")
      return true
    }

    let textToCommit = selectedCandidate.prefixText + handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.composer.clear()
    handler.mixedAlphanumericalBuffer.removeAll()

    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = textToCommit
    session.switchState(inputting)
    handler.handleTypewriterSCPCTasks()
    return true
  }

  private func isWordLikeASCIIPrefix(_ text: String) -> Bool {
    text.range(of: "^[A-Za-z]{3,}[A-Za-z0-9]*$", options: .regularExpression) != nil
  }

  private func shouldPreferASCIIWordPath(fullInput: String, minimumOverwriteCount: Int = 2) -> Bool {
    guard fullInput.count >= 3,
          fullInput.range(of: "^[A-Za-z]+$", options: .regularExpression) != nil
    else {
      return false
    }

    var trialComposer = handler.composer
    trialComposer.clear()
    var destructiveOverwriteCount = 0

    for currentChar in fullInput {
      let beforeSlots = composerSlotValues(of: trialComposer)
      trialComposer.receiveKey(fromString: currentChar.description)
      let afterSlots = composerSlotValues(of: trialComposer)

      if isNonAdvancingSlotConsumption(from: beforeSlots, to: afterSlots) {
        destructiveOverwriteCount += 1
      }
    }

    return destructiveOverwriteCount >= minimumOverwriteCount
  }

  private func composerSlotValues(of composer: Tekkon.Composer) -> [String] {
    [composer.consonant.value, composer.semivowel.value, composer.vowel.value, composer.intonation.value]
  }

  private func isNonAdvancingSlotConsumption(from beforeSlots: [String], to afterSlots: [String]) -> Bool {
    let beforeOccupiedSlotCount = beforeSlots.filter { !$0.isEmpty }.count
    let afterOccupiedSlotCount = afterSlots.filter { !$0.isEmpty }.count
    guard beforeOccupiedSlotCount > 0 else { return false }
    return afterOccupiedSlotCount <= beforeOccupiedSlotCount
  }

  private func resolveVisibleInputText(_ input: some InputSignalProtocol) -> String {
    let transformedInputText = input.text.applyingTransformFW2HW(reverse: false)
    guard input.isShiftHold else { return transformedInputText }

    let transformedInputTextIgnoringModifiers = (input.inputTextIgnoringModifiers ?? input.text)
      .applyingTransformFW2HW(reverse: false)

    // 僅在事件未提供 shifted glyph 時，才以 keyCode 查表回填可見字元。
    guard transformedInputText == transformedInputTextIgnoringModifiers else {
      return transformedInputText
    }

    let keyboardLayout = inferredLatinKeyboardLayout()
    guard let mappedTuple = keyboardLayout.mapTable[input.keyCode] else {
      return transformedInputText
    }
    return mappedTuple.1.applyingTransformFW2HW(reverse: false)
  }

  private func resolveLiteralASCIIMainAreaText(_ input: some InputSignalProtocol) -> String? {
    guard input.isOptionHold,
          !input.isControlHold,
          !input.isCommandHold,
          !input.isSymbolMenuPhysicalKey
    else {
      return nil
    }

    guard let mappedTuple = inferredLatinKeyboardLayout().mapTable[input.keyCode] else {
      return nil
    }

    let literalASCII = (input.isShiftHold ? mappedTuple.1 : mappedTuple.0)
      .applyingTransformFW2HW(reverse: false)
    guard literalASCII.range(of: "^[ -~]$", options: .regularExpression) != nil else {
      return nil
    }
    return literalASCII
  }

  private func commitLiteralASCIIImmediately(_ text: String, session: Session) -> Bool {
    guard !text.isEmpty else { return false }

    let pendingText = handler.committableDisplayText(sansReading: true) + handler.mixedAlphanumericalBuffer
    handler.composer.clear()
    handler.mixedAlphanumericalBuffer.removeAll()

    if !pendingText.isEmpty {
      session.switchState(State.ofCommitting(textToCommit: pendingText))
    }
    session.switchState(State.ofCommitting(textToCommit: text))
    return true
  }

  private func inferredLatinKeyboardLayout() -> LatinKeyboardMappings {
    // 非拼音路徑統一視為 QWERTY，避免額外讀取 keyboardParser（UserDefaults）。
    if !handler.composer.isPinyinMode { return .qwerty }
    return LatinKeyboardMappings(rawValue: handler.prefs.basicKeyboardLayout) ?? .qwerty
  }
}
