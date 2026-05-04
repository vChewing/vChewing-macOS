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
      // shouldPreferASCIIWordPath 會阻斷 auto-split，以防止 tod / film 等英文詞被誤拆為注音。
      // 但該啟發式也會誤傷 mixed 輸入（如 aiq / aijo6）。
      // 若前兩個字元本身即可組成佔用 >= 2 個注拼槽且詞庫有命中的讀音，
      // 則更可能是 mixed 輸入（如 ai=ㄇㄛ），此時仍應嘗試 auto-split。
      // 反之若前兩字僅佔 1 槽（如 he=ㄍ）或無詞庫命中（如 to=ㄔㄟ），
      // 則維持 ASCII 提交（保護 tod / film / hell 等）。
      let twoCharPrefixIsPhonetic: Bool = {
        let buffer = handler.mixedAlphanumericalBuffer
        guard buffer.count >= 3 else { return false }
        let prefix = String(buffer.prefix(2))
        guard prefix.range(of: "[A-Za-z]", options: .regularExpression) != nil else { return false }
        var trialComposer = handler.composer
        trialComposer.clear()
        trialComposer.receiveSequence(prefix, isRomaji: false)
        guard let readingKey = trialComposer.phonabetKeyForQuery(pronounceableOnly: true) else {
          return false
        }
        let occupiedSlots = [
          trialComposer.consonant.value,
          trialComposer.semivowel.value,
          trialComposer.vowel.value,
        ].filter { !$0.isEmpty }.count
        let hasUnigrams = !handler.currentLM.unigramsFor(keyArray: [readingKey]).isEmpty
        return occupiedSlots >= 2 && hasUnigrams
      }()
      // 當 buffer 完全是合法注音按鍵且無大寫字母，且整段長度不超過單一音節鍵位上限，
      // 且 composer 內容可發音，則整段視為單一注音，優先走 BPMF 全匹配路徑。
      // 這防止 auto-split 將純注音序列（如 "1u," = ㄅㄧㄝ）誤拆為
      // ASCII 前綴 + 注音後綴（如 "1u" + ㄝ），導致音節被撕裂。
      let bufferIsSingleSyllablePhonetic: Bool = {
        let buffer = handler.mixedAlphanumericalBuffer
        guard buffer.count >= 1, buffer.count <= maxSingleSyllableKeyCount else { return false }
        let hasUppercase = buffer.range(of: "[A-Z]", options: .regularExpression) != nil
        guard !hasUppercase else { return false }
        let isFullyParserCovered = buffer.allSatisfy {
          handler.composer.inputValidityCheck(charStr: $0.description)
        }
        guard isFullyParserCovered else { return false }
        // dachen26 碼長不定（4 或 5），暫時不啟用此檢查。
        guard handler.composer.parser != .ofDachen26 else { return false }
        var trialComposer = handler.composer
        trialComposer.clear()
        trialComposer.receiveSequence(buffer, isRomaji: false)
        guard trialComposer.isPronounceable else { return false }
        // 對於非 dachen26 排列，檢查鍵位數量與 composer 內有效 slot 數量是否一致。
        // 若一致，表示無 destructive overwrite，整段為單一音節。
        let occupiedSlotCount = [
          trialComposer.consonant.value,
          trialComposer.semivowel.value,
          trialComposer.vowel.value,
          trialComposer.intonation.value,
        ].filter { !$0.isEmpty }.count
        return buffer.count == occupiedSlotCount
      }()
      // 優先嘗試 BPMF 全匹配：當 buffer 可視為單一注音時，
      // 避免 auto-split 將音節撕裂。若 BPMF 失敗，仍回退到 auto-split。
      if !shouldPreferASCIIWordOnSpace, bufferIsSingleSyllablePhonetic {
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
        if handled == true { return true }
        // BPMF 失敗，恢復 buffer 並繼續嘗試 auto-split
        handler.mixedAlphanumericalBuffer = originalMixedBuffer
      }
      if !shouldPreferASCIIWordOnSpace || twoCharPrefixIsPhonetic {
        // 先嘗試無 word-like 限制的 auto-split（fallback），以正確保留常見雙字母前綴（如 ai）。
        // 若 fallback 失敗，再嘗試 word-like 限制，以支援 hello你好 類型混輸。
        if tryAutoSplitASCIIAndPhoneticSuffix(
          fullInput: handler.mixedAlphanumericalBuffer + " ",
          inputInvalid: false,
          session: session
        ) {
          return true
        }
        if tryAutoSplitASCIIAndPhoneticSuffix(
          fullInput: handler.mixedAlphanumericalBuffer + " ",
          inputInvalid: false,
          session: session,
          requiresWordLikePrefix: true
        ) {
          return true
        }
      }
      if !handler.composer.isEmpty, !shouldPreferASCIIWordOnSpace, !twoCharPrefixIsPhonetic {
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

    // 決定處理順序：長後綴優先 auto-split，短後綴優先整段注音。
    // 這可正確區分 aijo6（ai + jo6，後綴 3 碼）與 xu.6（整段 ㄌㄧㄡˊ，後綴 2 碼）。
    let longSuffixCandidate = bestAutoSplitCandidate(
      fullInputChars: Array(fullInput),
      requiresWordLikePrefix: false
    )
    let hasLongSuffix = (longSuffixCandidate?.suffixLength ?? 0) >= 3

    if hasLongSuffix {
      if !forceASCIIPunctuationPath, tryAutoSplitASCIIAndPhoneticSuffix(
        fullInput: fullInput,
        inputInvalid: input.isInvalid,
        session: session
      ) {
        return true
      }
      if !forceASCIIPunctuationPath, tryAutoSplitASCIIAndPhoneticSuffix(
        fullInput: fullInput,
        inputInvalid: input.isInvalid,
        session: session,
        requiresWordLikePrefix: true
      ) {
        return true
      }
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
        let occupiedSlotCount = [
          trialComposer.consonant.value,
          trialComposer.semivowel.value,
          trialComposer.vowel.value,
          trialComposer.intonation.value,
        ].filter { !$0.isEmpty }.count
        let hasNoDestructiveOverwrite = fullInput.count == occupiedSlotCount

        if trialComposer.hasIntonation() {
          if let readingKey = trialComposer.phonabetKeyForQuery(
            pronounceableOnly: true
          ), handler.currentLM.hasUnigramsForFast(keyArray: [readingKey]) {
            // 當 fullInput 超過單一注音音節的最大鍵位數時，trialComposer 只能保留
            // 最後一個音節，前面的鍵位會被無聲覆寫。此時應優先讓 auto-split 處理，
            // 避免將「ASCII 前綴 + 注音後綴」的 mixed 輸入誤吞為單一音節。
            // 同樣地，若鍵位數與實際佔用槽數不一致（destructive overwrite），
            // 也表示前面的 ASCII 前綴被 composer 誤吸收了，應交給 auto-split 處理。
            if fullInput.count <= maxSingleSyllableKeyCount,
               hasNoDestructiveOverwrite {
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
          }
          // 整段可發音但詞庫查無結果時，若整段為單一音節（無 destructive overwrite），
          // 保留 composer 狀態、不嘗試 auto-split，避免純注音序列被誤拆。
          // 反之則讓 auto-split 有機會拆出「ASCII 前綴 + 注音後綴」以支援 hello你好 類型混輸。
          // 修正：即使無 destructive overwrite，若詞庫查無結果，仍應讓 auto-split 嘗試拆分，
          // 以避免 mixed 輸入中的假合法組合（如 aiu3 → ㄇㄧㄛˇ）被誤保留。
          if hasNoDestructiveOverwrite,
             handler.composer.parser != .ofDachen26,
             let readingKey = trialComposer.phonabetKeyForQuery(pronounceableOnly: true),
             handler.currentLM.hasUnigramsForFast(keyArray: [readingKey]) {
            handler.composer = trialComposer
            handler.mixedAlphanumericalBuffer = fullInput
            session.switchState(handler.generateStateOfInputting())
            return true
          }
        } else if hasNoDestructiveOverwrite,
                  let readingKey = trialComposer.phonabetKeyForQuery(pronounceableOnly: false),
                  handler.currentLM.hasUnigramsForFast(keyArray: [readingKey]) {
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

  // Tekkon 的單一注音音節最多只會佔用 4 個鍵位（聲、介、韻、調）。
  private var maxSingleSyllableKeyCount: Int {
    switch handler.composer.parser {
    case .ofDachen26: 6 // 這是酷音大千26鍵的顯著缺點。
    case .ofETen26: 5 // 僅一例：`ㄍㄧㄠˊ → vezf`。
    default: 4 // 其餘所有注音排列，無論動態還是靜態排列，最大碼長均為 4。
    }
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
    let maxSuffixLength = min(maxSingleSyllableKeyCount, fullInputChars.count - 1)
    // 重用單一 trial composer 以減少 struct 複製與 heap 分配。
    var sharedComposer = handler.composer
    // 計算開頭的「被阻斷 ASCII 前綴」長度（大寫字母與聲調數字鍵）。
    // 這些鍵位在 buffer 為空時不會被 composer 吸收，理應視為固定 ASCII 前綴。
    let blockedPrefixLength: Int = {
      var length = 0
      for char in fullInputChars {
        let charStr = char.description
        let isUppercase = charStr.range(of: "^[A-Z]$", options: .regularExpression) != nil
        let isToneDigit: Bool = {
          sharedComposer.clear()
          sharedComposer.receiveKey(fromString: charStr)
          return sharedComposer.hasIntonation(withNothingElse: true)
        }()
        if isUppercase || isToneDigit {
          length += 1
        } else {
          break
        }
      }
      return length
    }()
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
        requiresWordLikePrefix: requiresWordLikePrefix,
        trialComposer: &sharedComposer
      ) else { continue }

      if let existing = candidateByReadingKey[candidate.readingKey] {
        if candidate.suffixLength < existing.suffixLength {
          candidateByReadingKey[candidate.readingKey] = candidate
        }
      } else {
        candidateByReadingKey[candidate.readingKey] = candidate
      }
    }

    // 選擇最長的有效後綴，但前綴長度必須滿足最小限制：
    // - 若開頭有被阻斷鍵（大寫/聲調數字），最小前綴長度 = 被阻斷段落長度。
    // - 若前綴含有英文字母，最小前綴長度 = 2。這避免單一字母（如 a=ㄇ）被誤認為
    //   ASCII 前綴，同時保留常見雙字母前綴（如 ai）於 mixed 輸入中的 ASCII 語義。
    // - 若前綴僅含數字與符號（皆為大千鍵盤下的合法注音鍵），最小前綴長度 = 1，
    //   使「5k4」等純注音輸入仍可正確以整段注音路徑處理。
    let validCandidates = candidateByReadingKey.values.filter { candidate in
      if blockedPrefixLength > 0 {
        return candidate.prefixText.count >= blockedPrefixLength
      }
      let hasASCIILetter = candidate.prefixText.range(
        of: "[A-Za-z]", options: .regularExpression
      ) != nil
      let hasOnlyDigits = !hasASCIILetter
        && candidate.prefixText.range(of: "[0-9]", options: .regularExpression) != nil
      let requiredMinLength = hasASCIILetter || hasOnlyDigits ? 2 : 1
      return candidate.prefixText.count >= requiredMinLength
    }

    return validCandidates.max(by: {
      let lhsDigitLeading = $0.prefersDigitLeadingSuffix
      let rhsDigitLeading = $1.prefersDigitLeadingSuffix
      if lhsDigitLeading != rhsDigitLeading {
        let digitLeadingCandidate = lhsDigitLeading ? $0 : $1
        let nonDigitLeadingCandidate = lhsDigitLeading ? $1 : $0
        // 僅當 digit-leading 後綴長度 >= 非 digit-leading 後綴時，
        // 才優先 digit-leading（保留 This5jp3 行為）。
        // 否則優先非 digit-leading（避免 ainj03 被誤拆為 ai + ㄢˇ）。
        if digitLeadingCandidate.suffixLength >= nonDigitLeadingCandidate.suffixLength {
          return !lhsDigitLeading && rhsDigitLeading
        } else {
          return lhsDigitLeading && !rhsDigitLeading
        }
      }
      if $0.prefersLongerPureAlnumSuffix, $1.prefersLongerPureAlnumSuffix,
         $0.suffixLength != $1.suffixLength {
        return $0.suffixLength < $1.suffixLength
      }
      let lhsPrefixWordLike = isWordLikeASCIIPrefix($0.prefixText)
      let rhsPrefixWordLike = isWordLikeASCIIPrefix($1.prefixText)
      let bothWordLike = lhsPrefixWordLike && rhsPrefixWordLike
      // 若雙方前綴皆為 word-like，優先以概率排序（保留 Twinsu.4 行為）。
      // 否則優先以後綴長度排序（保留 aizj/4 與 aijo6 行為）。
      if bothWordLike {
        if $0.bestProbability != $1.bestProbability {
          return $0.bestProbability < $1.bestProbability
        }
      } else {
        if $0.suffixLength != $1.suffixLength {
          return $0.suffixLength < $1.suffixLength
        }
        if $0.bestProbability != $1.bestProbability {
          return $0.bestProbability < $1.bestProbability
        }
      }
      return $0.suffixLength < $1.suffixLength
    })
  }

  // 接受 inout trialComposer 以在 bestAutoSplitCandidate 的迴圈中重用。
  private func buildAutoSplitCandidate(
    suffixLength: Int,
    prefixText: String,
    suffixText: String,
    requiresWordLikePrefix: Bool,
    trialComposer: inout Tekkon.Composer
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

    let suffixEndsWithSpace = suffixText.hasSuffix(" ")
    let effectiveSuffixText = suffixEndsWithSpace ? String(suffixText.dropLast()) : suffixText

    // Mixed mode 永遠不接受聲調前置鍵入。
    // 後綴不能以獨立聲調鍵作為首鍵（在 receiveSequence 前先檢查，避免破壞 composer 狀態）。
    if let firstChar = effectiveSuffixText.first?.description {
      trialComposer.clear()
      trialComposer.receiveKey(fromString: firstChar)
      if trialComposer.hasIntonation(withNothingElse: true) { return nil }
    }

    trialComposer.clear()
    // 在評估 mixed 輸入時，暫時停用自動糾正。否則 auto-correct 會讓不同的 suffix
    // 坍縮到同一個 reading key（例如「zj/4」被糾正為「ㄈㄥˋ」而與「z/4」相同），
    // 導致 dedup 誤刪較長的合法 suffix，使 ASCII prefix 被錯誤拉長。
    trialComposer.phonabetCombinationCorrectionEnabled = false
    trialComposer.receiveSequence(effectiveSuffixText, isRomaji: false)

    // Space handler 會以「buffer + " "」呼叫 auto-split，此時 space 本身即為無聲調確認。
    // 因此 suffix 若以 space 結尾，允許無調音但可發音的後綴（如 "u " → ㄧ）。
    guard trialComposer.isPronounceable,
          trialComposer.hasIntonation() || suffixEndsWithSpace
    else {
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

    let hasFast = handler.currentLM.hasUnigramsForFast(keyArray: [readingKey])
    let unigrams = handler.currentLM.unigramsFor(keyArray: [readingKey])
    // Word-like 情境維持 fast-path 限制，避免 digit-leading 後綴意外勝出；
    // 非 word-like fallback 則放寬為接受 ETenDOS 條目，以支援合法注音前綴的保留。
    let hasUnigrams = hasFast || (!requiresWordLikePrefix && !unigrams.isEmpty)
    guard hasUnigrams else { return nil }
    guard let bestProbability = unigrams.map(\.probability).max() else {
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
