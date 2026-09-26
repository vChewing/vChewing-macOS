// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
    // 閂滯於英打時：可列印 ASCII 一律即刻遞交，不進緩衝、亦不經任何判定管線。
    // 本分支置於中文標點查詢之前，故 `matchesCJKPunctuation` 在此狀態下不會被求值。
    if handler.mixedAlnumConfig.isLatchedToAlnum {
      return handleLatchedAlnumInput(input, session: session)
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
    // Shift+Space 在 non-empty 狀態下放棄注音處理，
    // 直接遞交 mixed buffer 內容 + ASCII 空格。
    // 偏好「空格鍵對內文組字區的行為」設為「插入空格」（值 0）時，**混打緩衝非空**者亦比照
    // 辦理：該偏好即使用者對「空白鍵＝插入空格」之明示，混打路徑不得逕自改判為「遞交尾段
    // ASCII ＋ 將尾鍵送進注拼槽」。**緩衝區為空者不在此攔截**——仍交還既有流程處置，
    // 故純中文組字之空白鍵語意不因本偏好而變。
    let commitsWholeMixedBufferOnSpace = input.isShiftHeld
      || (!handler.mixedAlphanumericalBuffer.isEmpty && handler.prefs.spaceKeyBehaviorAgainstICB == 0)
    if input.isSpace, commitsWholeMixedBufferOnSpace {
      guard !handler.isConsideredEmptyForNow else { return nil }
      let chineseText = handler.committableDisplayText(sansReading: true)
      let asciiText = handler.mixedAlphanumericalBuffer + " "
      handler.composer.clear()
      handler.mixedAlphanumericalBuffer.removeAll()
      session.switchState(State.ofCommitting(textToCommit: chineseText + asciiText))
      return true
    }
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
        let hasUnigrams = !handler.currentLM.lxQuerier.grams(for: [readingKey]).isEmpty
        return occupiedSlots >= 2 && hasUnigrams
      }()
      // 當 buffer 完全是合法注音按鍵且無大寫字母，且整段長度不超過單一音節鍵位上限，
      // 且整段為「依槽序鍵入之讀音」，則整段視為單一注音，優先走 BPMF 全匹配路徑。
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
        // 動態注音排列之合法編碼本即跨鍵改寫槽值（大千26 之 "qquu"＝ㄅㄚ 為 4 鍵 2 槽），
        // 「鍵數 == 佔用槽數」對之恆不成立。啟用槽序檢定時，動態排列一律委由引擎層判定；
        // 停用（舊制）時則退回計數式——動態排列之中僅大千26 因碼長不定而整條停用本檢查。
        if handler.composer.parser.isDynamic {
          if judgeReadingsBySequentialRawKeyOrder {
            return handler.composer.isSequentiallyTypedRawKeyOrder(buffer)
          }
          guard handler.composer.parser != .ofDachen26 else { return false }
        }
        var trialComposer = handler.composer
        trialComposer.clear()
        trialComposer.receiveSequence(buffer, isRomaji: false)
        guard trialComposer.isPronounceable else { return false }
        // 「鍵數 == 佔用槽數」即「無冗餘鍵」：靜態注音排列之一鍵一槽前提成立；停用槽序檢定時，
        // 動態排列（大千26 除外）亦回到此式。此式比引擎層之槽序檢定略嚴（另含同鍵之重寫），
        // 而該嚴格度在混打語境下是必要的——冗餘鍵正是「ASCII 前綴 + 注音後綴」之分界證據。
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
      // 若 buffer 含多個大寫字母且有小寫字母（camelCase/縮寫，如 cOS、macOS），
      // 即使 shouldPreferASCIIWordOnSpace 為 true，仍應嘗試 auto-split，
      // 以支援「cOS + 注音」這類混輸。
      // 條件：≥2 個大寫 + ≥1 個小寫，可區分於簡單首字大寫詞（Hello、Mac）或全大寫詞（HELLO）。
      let bufferHasMultipleUppercaseAndLowercase: Bool = {
        let buffer = handler.mixedAlphanumericalBuffer
        let hasLower = buffer.range(of: "[a-z]", options: .regularExpression) != nil
        let ucCount = buffer.unicodeScalars.filter { "A" ... "Z" ~= $0 }.count
        return hasLower && ucCount >= 2
      }()
      // 當 buffer 較長（>= 5 字元）時，即使 shouldPreferASCIIWordOnSpace 為 true
      // 也嘗試 auto-split，以支援 hello你好 等長 ASCII prefix 的混輸情境。
      if !shouldPreferASCIIWordOnSpace || twoCharPrefixIsPhonetic
        || handler.mixedAlphanumericalBuffer.count >= 5
        || bufferHasMultipleUppercaseAndLowercase {
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
      isASCIIPunctuation && (input.isShiftHeld || shouldForceByBufferContext)

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
    let isShiftASCII = input.isShiftHeld && visibleInputText.range(of: "^[ -~]$", options: .regularExpression) != nil

    // 若當前鍵（含修飾鍵）在標點詞庫有可用項，
    // 視為 CJK 標點輸入，優先回到既有標點管線處理。
    // 但若目前鍵位本身就是合法注音鍵，則必須讓注音輸入優先。
    // 僅 Shift+? 需強制保留 ASCII 語義，不回到 CJK 標點管線。
    // 其餘 Shift 標點（例如 Shift+` 的 ~）仍需維持既有 CJK 標點查詢能力。
    let punctuationQueryStrings = handler.punctuationQueryStrings(input: input)
    let isShiftQuestionMark = input.isShiftHeld && ["?", "？"].contains(visibleInputText)
    let matchesCJKPunctuation = !isShiftQuestionMark && isPunctuationChar
      && !isPhoneticKeyRaw && (punctuationQueryStrings?.contains {
        handler.currentLM.lxQuerier.hasUnigrams(for: [$0])
      } ?? false)
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

    guard !input.isControlHeld, !input.isOptionHeld, !input.isCommandHeld else { return nil }
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

    // 英數閂滯之上鎖點：該段不可能是一個依槽序鍵入的讀音，即判定為英文意圖並上鎖。
    // 上鎖後其後每一顆可列印 ASCII 皆即刻遞交（見 `handle` 開頭之分支）。
    if isLatchedAlnumStateEnabled, isNotSequentiallyTypedReading(fullInput) {
      return commitLatchedAlnum(fullInput, session: session)
    }

    // 決定處理順序：長後綴優先 auto-split，短後綴優先整段注音。
    // 這可正確區分 aijo6（ai + jo6，後綴 3 碼）與 xu.6（整段 ㄌㄧㄡˊ，後綴 2 碼）。
    let longSuffixCandidate = bestAutoSplitCandidate(
      fullInput: fullInput,
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

    // 僅在 fullInput 不超過單音節最大碼長時才進入 full-phonetic 路徑。
    // 過長的輸入（如 hello + bopomofo）應跳過此路徑，交由 auto-split 處理。
    if isFullyParserCovered, !forceASCIIPunctuationPath, !shouldPreferASCIIWordPath,
       fullInput.count <= maxSingleSyllableKeyCount {
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
        // 「整段是否為單一讀音」之判準：
        // - 動態注音排列之合法編碼本即跨鍵改寫槽值（大千26 之 "qquu"＝ㄅㄚ 為 4 鍵 2 槽），
        //   「鍵數 == 佔用槽數」對之恆不成立，故啟用槽序檢定時委由引擎層判定。
        // - 靜態注音排列恆維持「鍵數 == 佔用槽數」：該式即「無冗餘鍵」，而冗餘鍵在混打語境下
        //   是「ASCII 前綴 + 注音後綴」之分界證據（如 "ai" + "i6"），不得放行。
        // - 停用槽序檢定（舊制）時，動態排列一併退回「鍵數 == 佔用槽數」。
        //   該式之值域恆 ≤ 4（單一讀音最多四槽），故本處無須如上方 buffer 檢查另設大千26 之豁免：
        //   大千26 之跨鍵改寫編碼（`qquu`）本即無法通過該式。
        let fullInputIsSingleReading: Bool = {
          guard judgeReadingsBySequentialRawKeyOrder, handler.composer.parser.isDynamic else {
            return fullInput.count == occupiedSlotCount
          }
          return handler.composer.isSequentiallyTypedRawKeyOrder(fullInput)
        }()

        if trialComposer.hasIntonation() {
          if let readingKey = trialComposer.phonabetKeyForQuery(
            pronounceableOnly: true
          ), handler.currentLM.lxQuerier.hasGrams(for: [readingKey]) {
            // 整段可發音且詞庫有命中時，僅在整段確為單一讀音時才予以吸收；
            // 否則表示前面的 ASCII 前綴被 composer 誤收了，應交給 auto-split 處理。
            if fullInputIsSingleReading {
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
          // 整段可發音但詞庫查無結果時，若整段為單一讀音，保留 composer 狀態、
          // 不嘗試 auto-split，避免純注音序列被誤拆。
          // 反之則讓 auto-split 有機會拆出「ASCII 前綴 + 注音後綴」以支援 hello你好 類型混輸。
          if fullInputIsSingleReading,
             let readingKey = trialComposer.phonabetKeyForQuery(pronounceableOnly: true),
             handler.currentLM.lxQuerier.hasGrams(for: [readingKey]) {
            handler.composer = trialComposer
            handler.mixedAlphanumericalBuffer = fullInput
            session.switchState(handler.generateStateOfInputting())
            return true
          }
        } else if fullInputIsSingleReading,
                  let readingKey = trialComposer.phonabetKeyForQuery(pronounceableOnly: false),
                  handler.currentLM.lxQuerier.hasGrams(for: [readingKey]) {
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

  /// 英數閂滯開關是否生效（須中英混打模式與閂滯開關兩者皆啟用）。
  private var isLatchedAlnumStateEnabled: Bool {
    handler.prefs.mixedAlphanumericalEnabled
      && handler.prefs.enableLatchedAlnumStateInMixedAlnumMode
  }

  /// 「整段緩衝是否為一個依槽序鍵入之讀音」之判準是否委由引擎層
  /// （`isSequentiallyTypedRawKeyOrder`）。
  ///
  /// 停用時退回舊制：動態注音排列不再委由引擎層判定（大千26 之相關檢定整條停用、
  /// 其餘動態排列改採「鍵數 == 佔用槽數」），且 `shouldPreferASCIIWordPath` 之
  /// 第一項證據（鍵序無以成讀音）一併失效。
  private var judgeReadingsBySequentialRawKeyOrder: Bool {
    handler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder
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
    guard fullInput.count > 1 else { return false }
    guard let selectedCandidate = bestAutoSplitCandidate(
      fullInput: fullInput,
      requiresWordLikePrefix: requiresWordLikePrefix
    ) else { return false }
    return applyAutoSplitCandidate(selectedCandidate, inputInvalid: inputInvalid, session: session)
  }

  private func bestAutoSplitCandidate(
    fullInput: String,
    requiresWordLikePrefix: Bool
  )
    -> AutoSplitCandidate? {
    // Tekkon 的單一注音音節最多只會佔用 4 個鍵位（聲、介、韻、調）。
    // 若多個 raw suffix 最終對應到同一個 reading key，
    // 代表較長者只是用多餘鍵位覆寫出同一個結果，應保留最短 raw suffix。
    // 額外保守排除含 separator / 空白的怪異 query key，避免把多段 key 當成單筆讀音。
    let maxSuffixLength = min(maxSingleSyllableKeyCount, fullInput.count - 1)
    // 重用單一 trial composer 以減少 struct 複製與 heap 分配。
    var sharedComposer = handler.composer
    // 計算開頭的「被阻斷 ASCII 前綴」長度（大寫字母與聲調數字鍵）。
    // 這些鍵位在 buffer 為空時不會被 composer 吸收，理應視為固定 ASCII 前綴。
    let blockedPrefixLength: Int = {
      var length = 0
      for char in fullInput {
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
      let prefixLength = fullInput.count - suffixLength
      let prefixText = String(fullInput.prefix(prefixLength))
      let suffixText = String(fullInput.suffix(suffixLength))
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

    // 若多個候選的 suffix 存在 subset/superset 關係（如 "u4" 是 "qu4" 的後綴），
    // 僅保留 superset（更長的 suffix = 更完整的讀音），捨棄 subset。
    // 這解決 helloqu4 中 u4（ㄧˋ）擊敗 qu4（ㄆㄧˋ）的問題。
    let suffixTextsByKey: [String: String] = Dictionary(
      uniqueKeysWithValues: candidateByReadingKey.map { key, candidate in
        (key, String(fullInput.suffix(candidate.suffixLength)))
      }
    )
    let keysToRemove = candidateByReadingKey.compactMap { key, candidate -> String? in
      let mySuffix = String(fullInput.suffix(candidate.suffixLength))
      for (otherKey, otherSuffix) in suffixTextsByKey where otherKey != key {
        if otherSuffix.hasSuffix(mySuffix), otherSuffix.count > mySuffix.count {
          return key
        }
      }
      return nil
    }
    for key in keysToRemove { candidateByReadingKey.removeValue(forKey: key) }

    // 選擇最長的有效後綴，但前綴長度必須滿足最小限制：
    // - 若開頭有被阻斷鍵（大寫/聲調數字），最小前綴長度 = 被阻斷段落長度。
    // - 若前綴含有英文字母，最小前綴長度 = 2。這避免單一字母（如 a=ㄇ）被誤認為
    //   ASCII 前綴，同時保留常見雙字母前綴（如 ai）於 mixed 輸入中的 ASCII 語義。
    // - 若前綴僅含數字與符號（皆為大千鍵盤下的合法注音鍵），最小前綴長度 = 1，
    //   使「5k4」等純注音輸入仍可正確以整段注音路徑處理。
    let validCandidates = candidateByReadingKey.values.filter { candidate in
      if blockedPrefixLength > 0 {
        // 當開頭有被阻斷鍵（聲調數字或大寫字母）且後綴全為 ASCII 數字時，
        // 整段輸入極可能為純數字序列（如 IP 位址 192.168.100.1），不應拆分。
        // 此狀況特別影響倚天傳統佈局：1-4 為聲調鍵、7-9/0 為韻母鍵，
        // 導致如 192 被拆為 1(˙) + 92(ㄣˊ=嗯)。
        let suffixStr = String(fullInput.suffix(candidate.suffixLength))
        let suffixIsPureDigits = suffixStr.unicodeScalars.allSatisfy {
          $0.isASCII && CharacterSet.decimalDigits.contains($0)
        }
        if suffixIsPureDigits {
          return false
        }
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
      // 若雙方前綴皆為 word-like，優先以概率排序（保留 Twinsu.4 行為）。
      // 若僅一方為 word-like，優先保留 word-like 前綴（避免 ello→el 等誤拆）。
      // 若雙方皆非 word-like，優先以後綴長度排序（保留 aizj/4 與 aijo6 行為）。
      switch (lhsPrefixWordLike, rhsPrefixWordLike) {
      case (true, true):
        if $0.bestProbability != $1.bestProbability {
          return $0.bestProbability < $1.bestProbability
        }
        // 同為 word-like 且概率相同時，偏好較長的前綴（較短的後綴），
        // 避免 ello→el 或 hello→hel 等誤拆。
        if $0.prefixText.count != $1.prefixText.count {
          return $0.prefixText.count < $1.prefixText.count
        }
      case (false, false):
        if $0.suffixLength != $1.suffixLength {
          return $0.suffixLength < $1.suffixLength
        }
        if $0.bestProbability != $1.bestProbability {
          return $0.bestProbability < $1.bestProbability
        }
      case (true, false): return false
      case (false, true): return true
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

    // 單一標點字元不得作為 ASCII 前綴（如倚天傳統布局的 ;→ㄗ ,→ㄓ .→ㄔ）。
    if prefixText.count == 1, !prefixHasASCIIAlnum,
       prefixText.unicodeScalars.allSatisfy(isPunctCharOrSymbol) {
      return nil
    }

    let suffixEndsWithSpace = suffixText.last == " "

    // Mixed mode 永遠不接受聲調前置鍵入。
    // 後綴不能以獨立聲調鍵作為首鍵（在 receiveSequence 前先檢查，避免破壞 composer 狀態）。
    let suffixScalars = suffixText.unicodeScalars
    let scalarCount = suffixEndsWithSpace ? suffixScalars.count - 1 : suffixScalars.count
    if scalarCount > 0, let firstScalar = suffixScalars.first {
      trialComposer.clear()
      trialComposer.receiveKey(fromScalar: firstScalar)
      if trialComposer.hasIntonation(withNothingElse: true) { return nil }
    }

    // 後綴若包含大寫字母，不得被視為注音後綴。
    // 大寫字母只能透過 Shift 鍵入，在 mixed mode 下明確代表 ASCII 意圖。
    // 若允許大寫字母進入注音 composer（因 receiveKey 對大小寫不敏感），
    // 則「macOS 」這類 camelCase 輸入會被誤拆為 ASCII 前綴 + 注音後綴。
    let suffixHasUppercase = suffixText.range(of: "[A-Z]", options: .regularExpression) != nil
    guard !suffixHasUppercase else { return nil }

    trialComposer.clear()
    // 在評估 mixed 輸入時，暫時停用自動糾正。否則 auto-correct 會讓不同的 suffix
    // 坍縮到同一個 reading key（例如「zj/4」被糾正為「ㄈㄥˋ」而與「z/4」相同），
    // 導致 dedup 誤刪較長的合法 suffix，使 ASCII prefix 被錯誤拉長。
    trialComposer.phonabetCombinationCorrectionEnabled = false
    // 啟用 CSVT 順序強制，逐字檢查 receiveKey 返回值。
    // 若任何字元被 CSVT 拒絕，整個 suffix 候選直接作廢（return nil），
    // 避免半成品 composer（如僅有 vowel）被 trailing space 誤判為合法。
    trialComposer.enforceCSVTOrdering = true
    // 使用 UnicodeScalar iteration + receiveKey(fromScalar:) 繞過 Character/String 的 CFString 橋接。
    var scalarIndex = 0
    for scalar in suffixScalars {
      if scalarIndex >= scalarCount { break }
      if !trialComposer.receiveKey(fromScalar: scalar) { return nil }
      scalarIndex += 1
    }

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

    let hasFast = handler.currentLM.lxQuerier.hasGrams(for: [readingKey])
    let unigrams = handler.currentLM.lxQuerier.grams(for: [readingKey])
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

    let prefixText = selectedCandidate.prefixText
    let overflowText = handler.commitOverflownComposition
    handler.retrievePOMSuggestions(apply: true)
    handler.composer.clear()
    handler.mixedAlphanumericalBuffer.removeAll()

    var inputting = handler.generateStateOfInputting()
    inputting.textToCommit = prefixText + overflowText
    session.switchState(inputting)
    handler.handleTypewriterSCPCTasks()
    return true
  }

  private func isWordLikeASCIIPrefix(_ text: String) -> Bool {
    text.range(of: "^[A-Za-z]{3,}[A-Za-z0-9]*$", options: .regularExpression) != nil
  }

  /// 判斷純英文字母之輸入是否應改走 ASCII 路徑（而非被注音吸收）。
  ///
  /// 證據有兩項，任一成立即可：
  /// 一、**鍵序無以成讀音**——該序列不是一個依注音槽序鍵入之讀音（亂序、覆寫修正、無以發音）；
  ///     權威為引擎層之 `isSequentiallyTypedRawKeyOrder`，對長度 ≥ 2 者即生效。
  ///     此項可經偏好 `MixedAlnumJudgeReadingsBySequentialRawKeyOrder` 停用（停用時本函式僅剩證據二）。
  /// 二、**冗餘鍵**——鍵數多於其所佔用之槽數（如 "tod" 之 3 鍵僅佔 2 槽）。此項預設「一鍵一槽」，
  ///     僅靜態注音排列適用：動態排列之合法編碼本即跨鍵改寫槽值，計數無意義
  ///     （停用槽序檢定者，此項之適用範圍亦回到舊制）。
  /// - Parameter minimumOverwriteCount: 證據二所需之冗餘鍵次數下限。
  private func shouldPreferASCIIWordPath(fullInput: String, minimumOverwriteCount: Int = 2) -> Bool {
    guard fullInput.range(of: "^[A-Za-z]+$", options: .regularExpression) != nil else {
      return false
    }
    if judgeReadingsBySequentialRawKeyOrder {
      // 證據一：鍵序無以成讀音。
      if isNotSequentiallyTypedReading(fullInput) { return true }
      // 證據二預設「一鍵一槽」，僅靜態注音排列適用。
      guard !handler.composer.parser.isDynamic, !handler.composer.isPinyinMode else { return false }
    }
    guard fullInput.count >= 3 else { return false }
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

  /// 判斷純英文字母之緩衝是否「不可能是一個依注音槽序鍵入之讀音」。
  ///
  /// 此為英文意圖之證據，與「冗餘鍵」互不相干：此者證「鍵序無以成讀音」，彼者證「鍵數多於槽數」。
  /// 權威為 Tekkon 引擎層之 `isSequentiallyTypedRawKeyOrder`——其對動態排列以「最終值首見鍵序」
  /// 為準（故大千26 之 "qquu" 不被誤列），對靜態排列則另禁「以另一鍵改寫既有槽值」。
  /// 僅對「全為 ASCII 英文字母且長度 ≥ 2」者成立，其餘情形一律回 false。
  private func isNotSequentiallyTypedReading(_ text: String) -> Bool {
    guard text.count >= 2,
          text.range(of: "^[A-Za-z]+$", options: .regularExpression) != nil
    else { return false }
    return !handler.composer.isSequentiallyTypedRawKeyOrder(text)
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
    guard input.isShiftHeld else { return transformedInputText }

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
    guard input.isOptionHeld,
          !input.isControlHeld,
          !input.isCommandHeld,
          !input.isSymbolMenuPhysicalKey
    else {
      return nil
    }

    guard let mappedTuple = inferredLatinKeyboardLayout().mapTable[input.keyCode] else {
      return nil
    }

    let literalASCII = (input.isShiftHeld ? mappedTuple.1 : mappedTuple.0)
      .applyingTransformFW2HW(reverse: false)
    guard literalASCII.range(of: "^[ -~]$", options: .regularExpression) != nil else {
      return nil
    }
    return literalASCII
  }

  /// 閂滯於英打時之按鍵處置：可列印 ASCII 一律即刻遞交；其餘交還既有流程。
  ///
  /// 回傳 `nil` 表示本函式不處理該按鍵（例如非 ASCII、或帶 Option 之替換字符），
  /// 交由 `handle(_:)` 之後續流程處置（如 `resolveLiteralASCIIMainAreaText`）。
  private func handleLatchedAlnumInput(
    _ input: some InputSignalProtocol,
    session: Session
  )
    -> Bool? {
    let visibleText = resolveVisibleInputText(input)
    let scalars = visibleText.unicodeScalars
    guard scalars.count == 1,
          let scalar = scalars.first,
          scalar.isASCII,
          (0x20 ... 0x7E).contains(scalar.value)
    else { return nil }
    let pendingText = handler.committableDisplayText(sansReading: true) + visibleText
    handler.composer.clear()
    handler.mixedAlnumConfig.resetContent()
    session.switchState(State.ofCommitting(textToCommit: pendingText))
    return true
  }

  /// 將當前狀態上鎖為「閂滯於英打」，並即刻遞交當前整段 ASCII 內容。
  private func commitLatchedAlnum(_ fullInput: String, session: Session) -> Bool {
    let pendingText = handler.committableDisplayText(sansReading: true) + fullInput
    handler.composer.clear()
    handler.mixedAlnumConfig.resetContent()
    handler.mixedAlnumConfig.isLatchedToAlnum = true
    session.switchState(State.ofCommitting(textToCommit: pendingText))
    // 上鎖提示改由 StatusUI 承載（不經 state）：以內文提示（空狀態＋tooltip）承載者會被緊接著的
    // 按鍵事件之 switchState 一併換掉，連續打字時看不到；且空狀態之 tooltip 亦非穩定之提示載體。
    session.showStatusHint(
      "i18n:StateOfInputting.Tooltip.MixedAlnumLatchedStateEntered".i18n,
      duration: 1.5
    )
    return true
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
