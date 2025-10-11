// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Tekkon.Composer

extension Tekkon {
  // MARK: - Syllable Composer

  /// 注音並擊處理的對外介面以注拼槽（Syllable Composer）的形式存在。
  /// 使用時需要單獨初期化為一個副本變數（因為是 Struct 所以必須得是變數）。
  /// 注拼槽只有四格：聲、介、韻、調。
  ///
  /// 因為是 String Literal，所以初期化時可以藉由 @input 參數指定初期已經傳入的按鍵訊號。
  /// 還可以在初期化時藉由 @arrange 參數來指定注音排列（預設為「.ofDachen」大千佈局）。
  @frozen
  public struct Composer: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    // MARK: 注拼槽對外處理函式

    /// 初期化一個新的注拼槽。可以藉由 @input 參數指定初期已經傳入的按鍵訊號。
    /// 還可以在初期化時藉由 @arrange 參數來指定注音排列（預設為「.ofDachen」大千佈局）。
    /// - Parameters:
    ///   - input: 傳入的 String 內容，用以處理單個字元。
    ///   - arrange: 要使用的注音排列。
    ///   - correction: 是否對錯誤的注音讀音組合做出自動糾正處理。
    public init(
      _ input: String = "",
      arrange parser: MandarinParser = .ofDachen,
      correction: Bool = false
    ) {
      self.phonabetCombinationCorrectionEnabled = correction
      ensureParser(arrange: parser)
      receiveKey(fromString: input)
    }

    // MARK: Public

    /// 聲母。
    public internal(set) var consonant: Phonabet = .init()

    /// 介母。
    public internal(set) var semivowel: Phonabet = .init()

    /// 韻母。
    public internal(set) var vowel: Phonabet = .init()

    /// 聲調。
    public internal(set) var intonation: Phonabet = .init()

    /// 拼音組音區。
    public internal(set) var romajiBuffer: String = .init()

    /// 注音排列種類。預設情況下是大千排列（Windows / macOS 預設注音排列）。
    public internal(set) var parser: MandarinParser = .ofDachen

    /// 是否對錯誤的注音讀音組合做出自動糾正處理。
    public var phonabetCombinationCorrectionEnabled = false

    /// 內容值，會直接按照正確的順序拼裝自己的聲介韻調內容、再回傳。
    /// 注意：直接取這個參數的內容的話，陰平聲調會成為一個空格。
    /// 如果是要取不帶空格的注音的話，請使用「.getComposition()」而非「.value」。
    public var value: String {
      consonant.value + semivowel.value + vowel.value + intonation.value
    }

    /// 當前注拼槽是否處於拼音模式。
    public var isPinyinMode: Bool { parser.rawValue >= 100 }

    /// 注拼槽內容是否為空。
    public var isEmpty: Bool {
      guard !isPinyinMode else { return intonation.isEmpty && romajiBuffer.isEmpty }
      return intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
    }

    /// 注拼槽內容是否可唸。
    public var isPronounceable: Bool {
      !vowel.isEmpty || !semivowel.isEmpty || !consonant.isEmpty
    }

    // MARK: - Misc Definitions

    /// 統計有效的聲介韻（調）個數。
    /// - Parameter withIntonation: 是否統計聲調。
    /// - Returns: 統計出的有效 Phonabet 個數。
    public func count(withIntonation: Bool = false) -> Int {
      [consonant.isValid, semivowel.isValid, vowel.isValid]
        .reduce((withIntonation && intonation.isValid) ? 1 : 0) { $0 + ($1 ? 1 : 0) }
    }

    /// 與 value 類似，這個函式就是用來決定輸入法組字區內顯示的注音/拼音內容，
    /// 但可以指定是否輸出教科書格式（拼音的調號在字母上方、注音的輕聲寫在左側）。
    /// - Parameters:
    ///   - isHanyuPinyin: 是否將輸出結果轉成漢語拼音。
    ///   - isTextBookStyle: 是否將輸出的注音/拼音結果轉成教科書排版格式。
    public func getComposition(
      isHanyuPinyin: Bool = false,
      isTextBookStyle: Bool = false
    )
      -> String {
      switch isHanyuPinyin {
      case false: // 注音輸出的場合
        let valReturnZhuyin = value.swapping(" ", with: "")
        return isTextBookStyle ? cnvPhonaToTextbookStyle(target: valReturnZhuyin) : valReturnZhuyin
      case true: // 拼音輸出的場合
        let valReturnPinyin = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: value)
        return isTextBookStyle ? Tekkon
          .cnvHanyuPinyinToTextbookStyle(targetJoined: valReturnPinyin) : valReturnPinyin
      }
    }

    // 該函式僅用來獲取給 macOS InputMethod Kit 的內文組字區使用的顯示字串。
    /// - Parameters:
    ///   - isHanyuPinyin: 是否將輸出結果轉成漢語拼音。
    public func getInlineCompositionForDisplay(isHanyuPinyin: Bool = false) -> String {
      guard isPinyinMode else { return getComposition(isHanyuPinyin: isHanyuPinyin) }
      var toneReturned = ""
      switch intonation.value {
      case " ": toneReturned = "1"
      case "ˊ": toneReturned = "2"
      case "ˇ": toneReturned = "3"
      case "ˋ": toneReturned = "4"
      case "˙": toneReturned = "5"
      default: break
      }
      return romajiBuffer.swapping("v", with: "ü") + toneReturned
    }

    /// 清除自身的內容，就是將聲介韻調全部清空。
    /// 嚴格而言，「注音排列」這個屬性沒有需要清空的概念，只能用 ensureParser 參數變更之。
    public mutating func clear() {
      consonant.clear()
      semivowel.clear()
      vowel.clear()
      intonation.clear()
      romajiBuffer = ""
    }

    // MARK: - Public Functions

    /// 用於檢測「某個輸入字元訊號的合規性」的函式。
    ///
    /// 注意：回傳結果會受到當前注音排列 parser 屬性的影響。
    /// - Parameters:
    ///   - key: 傳入的 UniChar 內容。
    public func inputValidityCheck(key inputKey: UInt16 = 0) -> Bool {
      guard let scalar = UnicodeScalar(inputKey) else { return false }
      return inputValidityCheck(charStr: String(scalar))
    }

    /// 用於檢測「某個輸入字元訊號的合規性」的函式。
    ///
    /// 注意：回傳結果會受到當前注音排列 parser 屬性的影響。
    /// - Parameters:
    ///   - charStr: 傳入的字元（String）。
    public func inputValidityCheck(charStr input: String) -> Bool {
      guard let scalar = input.unicodeScalars.first else { return false }
      switch parser {
      case .ofDachen:
        return Tekkon.mapQwertyDachen[scalar] != nil
      case .ofDachen26:
        return Tekkon.mapDachenCP26StaticKeys[scalar] != nil
      case .ofETen:
        return Tekkon.mapQwertyETenTraditional[scalar] != nil
      case .ofHsu:
        return Tekkon.mapHsuStaticKeys[scalar] != nil
      case .ofETen26:
        return Tekkon.mapETen26StaticKeys[scalar] != nil
      case .ofIBM:
        return Tekkon.mapQwertyIBM[scalar] != nil
      case .ofMiTAC:
        return Tekkon.mapQwertyMiTAC[scalar] != nil
      case .ofSeigyou:
        return Tekkon.mapSeigyou[scalar] != nil
      case .ofFakeSeigyou:
        return Tekkon.mapFakeSeigyou[scalar] != nil
      case .ofStarlight:
        return Tekkon.mapStarlightStaticKeys[scalar] != nil
      case .ofAlvinLiu:
        return Tekkon.mapAlvinLiuStaticKeys[scalar] != nil
      case .ofWadeGilesPinyin:
        return Tekkon.mapWadeGilesPinyinKeys.unicodeScalars.contains(scalar)
      case .ofHanyuPinyin, .ofHualuoPinyin, .ofSecondaryPinyin, .ofUniversalPinyin, .ofYalePinyin:
        return Tekkon.mapArayuruPinyin.unicodeScalars.contains(scalar)
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 String。
    /// 另有同名函式可處理 UniChar 與 Unicode Scalar 訊號。
    ///
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromString: 傳入的 String 內容。
    public mutating func receiveKey(fromString inputStr: String = "") {
      guard let input = inputStr.unicodeScalars.first else { return }
      receiveKey(fromScalar: input)
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 Unicode Scalar。
    /// 另有同名函式可處理 UniChar 與 String 訊號。
    ///
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromString: 傳入的 String 內容。
    public mutating func receiveKey(fromScalar input: Unicode.Scalar?) {
      guard let input else { return }
      guard isPinyinMode else {
        receiveKey(fromPhonabet: translate(key: input))
        return
      }
      if let theTone = mapArayuruPinyinIntonation[input] {
        intonation = Phonabet(theTone)
      } else {
        // 為了防止 romajiBuffer 越敲越長帶來算力負擔，這裡讓它在要溢出時自動丟掉最早輸入的音頭。
        let maxCount: Int = (parser == .ofWadeGilesPinyin) ? 7 : 6
        if romajiBuffer.count > maxCount - 1 {
          romajiBuffer = String(romajiBuffer.dropFirst())
        }
        let romajiBufferBackup = romajiBuffer + String(Character(input))
        receiveSequence(romajiBufferBackup, isRomaji: true)
        romajiBuffer = romajiBufferBackup
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 UniChar。
    /// 其實也就是先將 UniChar 轉為 String 再交給某個同名異參的函式來處理而已。
    ///
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromCharCode: 傳入的 UniChar 內容。
    public mutating func receiveKey(fromCharCode inputCharCode: UInt16 = 0) {
      if let scalar = UnicodeScalar(inputCharCode) {
        receiveKey(fromScalar: scalar)
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為單個注音符號。
    /// 主要就是將注音符號拆分辨識且分配到正確的貯存位置而已。
    /// - Parameters:
    ///   - fromPhonabet: 傳入的單個注音符號字串。
    public mutating func receiveKey(fromPhonabet phonabet: Unicode.Scalar?) {
      guard let phonabet else { return }
      var thePhone: Phonabet = .init(phonabet)
      if phonabetCombinationCorrectionEnabled {
        switch phonabet {
        case "ㄧ", "ㄩ":
          if vowel.value == "ㄜ" { vowel <~ "ㄝ" }
        case "ㄜ":
          if "ㄨ".doesHave(semivowel.value) { semivowel <~ "ㄩ" }
          if "ㄧㄩ".doesHave(semivowel.value) { thePhone <~ "ㄝ" }
        case "ㄝ":
          if "ㄨ".doesHave(semivowel.value) { semivowel <~ "ㄩ" }
        case "ㄛ", "ㄥ":
          if phonabet == "ㄛ", semivowel.value == "ㄩ" { semivowel <~ "ㄨ" }
          if "ㄅㄆㄇㄈ".doesHave(consonant.value), semivowel.value == "ㄨ" { semivowel.clear() }
        case "ㄟ":
          if "ㄋㄌ".doesHave(consonant.value), semivowel.value == "ㄨ" { semivowel.clear() }
        case "ㄨ":
          if "ㄅㄆㄇㄈ".doesHave(consonant.value), "ㄛㄥ".doesHave(vowel.value) { vowel.clear() }
          if "ㄋㄌ".doesHave(consonant.value), "ㄟ".doesHave(vowel.value) { vowel.clear() }
          if "ㄜ".doesHave(vowel.value) { vowel <~ "ㄝ" }
          if "ㄝ".doesHave(vowel.value) { thePhone <~ "ㄩ" }
        case "ㄅ", "ㄆ", "ㄇ", "ㄈ":
          if ["ㄨㄛ", "ㄨㄥ"].contains(semivowel + vowel) { semivowel.clear() }
        default: break
        }
        if [.vowel, .intonation].contains(thePhone.type), "ㄓㄔㄕㄗㄘㄙ".doesHave(consonant.value) {
          switch (semivowel.value, consonant.value) {
          case ("ㄧ", _): semivowel.clear()
          case ("ㄩ", "ㄓ"), ("ㄩ", "ㄗ"): consonant <~ "ㄐ"
          case ("ㄩ", "ㄔ"), ("ㄩ", "ㄘ"): consonant <~ "ㄑ"
          case ("ㄩ", "ㄕ"), ("ㄩ", "ㄙ"): consonant <~ "ㄒ"
          default: break
          }
        }
      }
      switch thePhone.type {
      case .consonant: consonant = thePhone
      case .semivowel: semivowel = thePhone
      case .vowel: vowel = thePhone
      case .intonation: intonation = thePhone
      default: break
      }
      updateRomajiBuffer()
    }

    /// 處理一連串的按鍵輸入。
    /// - Remark: 注意：對各種拼音而言，該函式無法處理聲調。
    /// - Parameters:
    ///   - givenSequence: 傳入的 String 內容，用以處理一整串擊鍵輸入。
    ///   - isRomaji: 如果輸入的字串是諸如漢語拼音這樣的西文字母拼音的話，請啟用此選項。
    /// - Returns: 處理之後的結果。
    @discardableResult
    public mutating func receiveSequence(
      _ givenSequence: String = "",
      isRomaji: Bool = false
    )
      -> String {
      clear()
      guard isRomaji else {
        givenSequence.forEach { receiveKey(fromString: $0.description) }
        return value
      }
      var dictResult: String?
      switch parser {
      case .ofHanyuPinyin:
        dictResult = mapHanyuPinyin[givenSequence]
      case .ofSecondaryPinyin:
        dictResult = mapSecondaryPinyin[givenSequence]
      case .ofYalePinyin:
        dictResult = mapYalePinyin[givenSequence]
      case .ofHualuoPinyin:
        dictResult = mapHualuoPinyin[givenSequence]
      case .ofUniversalPinyin:
        dictResult = mapUniversalPinyin[givenSequence]
      case .ofWadeGilesPinyin:
        dictResult = mapWadeGilesPinyin[givenSequence]
      default: break
      }
      dictResult?.unicodeScalars.forEach { receiveKey(fromPhonabet: $0) }
      return value
    }

    /// 專門用來響應使用者摁下 BackSpace 按鍵時的行為。
    /// 刪除順序：調、韻、介、聲。
    ///
    /// 基本上就是按順序從游標前方開始往後刪。
    public mutating func doBackSpace() {
      if isPinyinMode, !romajiBuffer.isEmpty {
        if !intonation.isEmpty {
          intonation.clear()
        } else {
          romajiBuffer = String(romajiBuffer.dropLast())
        }
      } else if !intonation.isEmpty {
        intonation.clear()
      } else if !vowel.isEmpty {
        vowel.clear()
      } else if !semivowel.isEmpty {
        semivowel.clear()
      } else if !consonant.isEmpty {
        consonant.clear()
      }
    }

    /// 用來檢測是否有調號的函式，預設情況下不判定聲調以外的內容的存無。
    /// - Parameters:
    ///   - withNothingElse: 追加判定「槽內是否僅有調號」。
    public func hasIntonation(withNothingElse: Bool = false) -> Bool {
      if !withNothingElse {
        return !intonation.isEmpty
      }
      return !intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
    }

    // 設定該 Composer 處於何種鍵盤排列分析模式。
    /// - Parameters:
    ///   - arrange: 給該注拼槽指定注音排列。
    public mutating func ensureParser(arrange: MandarinParser = .ofDachen) {
      parser = arrange
    }

    /// 拿取用來進行索引檢索用的注音字串。
    ///
    /// 如果輸入法的辭典索引是漢語拼音的話，你可能用不上這個函式。
    /// - Remark: 該字串結果不能為空，否則組字引擎會炸。
    /// - Parameter pronounceableOnly: 是否可以唸出。
    /// - Returns: 可用的查詢用注音字串，或者 nil。
    public func phonabetKeyForQuery(pronounceableOnly: Bool) -> String? {
      let readingKey = getComposition()
      var validKeyAvailable = false
      let isPinyinMode = isPinyinMode
      switch (isPinyinMode, pronounceableOnly) {
      case (false, true): validKeyAvailable = isPronounceable
      case (false, false): validKeyAvailable = !readingKey.isEmpty
      case (true, _): validKeyAvailable = isPronounceable
      }

      switch isPinyinMode {
      case false:
        switch pronounceableOnly {
        case false:
          validKeyAvailable = !readingKey.isEmpty
        case true:
          validKeyAvailable = isPronounceable
        }
      case true: validKeyAvailable = isPronounceable
      }
      return validKeyAvailable ? readingKey : nil
    }

    // MARK: Internal

    // MARK: - Parser Processing

    // 注拼槽對內處理用函式都在這一小節。

    /// 根據目前的注音排列設定來翻譯傳入的 String 訊號。
    ///
    /// 倚天或許氏鍵盤的處理函式會將分配過程代為處理過，此時回傳結果為空字串。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func translate(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard !isPinyinMode else { return nil }
      switch parser {
      case .ofDachen:
        return Tekkon.mapQwertyDachen[key]
      case .ofDachen26:
        return handleDachen26(key: key)
      case .ofETen:
        return Tekkon.mapQwertyETenTraditional[key]
      case .ofHsu:
        return handleHsu(key: key)
      case .ofETen26:
        return handleETen26(key: key)
      case .ofIBM:
        return Tekkon.mapQwertyIBM[key]
      case .ofMiTAC:
        return Tekkon.mapQwertyMiTAC[key]
      case .ofSeigyou:
        return Tekkon.mapSeigyou[key]
      case .ofFakeSeigyou:
        return Tekkon.mapFakeSeigyou[key]
      case .ofStarlight:
        return handleStarlight(key: key)
      case .ofAlvinLiu:
        return handleAlvinLiu(key: key)
      default:
        return nil
      }
    }

    /// 所有動態注音排列都會用到的共用糾錯處理步驟。
    /// - Parameter incomingPhonabet: 傳入的注音 Phonabet。
    internal mutating func commonFixWhenHandlingDynamicArrangeInputs(
      target incomingPhonabet: Phonabet
    ) {
      // 處理特殊情形。
      switch incomingPhonabet.type {
      case .semivowel:
        // 這裡不處理「ㄍㄧ」到「ㄑㄧ」的轉換，因為只有倚天26需要處理這個。
        switch (consonant.value, incomingPhonabet.value) {
        case ("ㄓ", "ㄧ"), ("ㄓ", "ㄩ"): consonant <~ "ㄐ"
        case ("ㄍ", "ㄩ"), ("ㄔ", "ㄧ"), ("ㄔ", "ㄩ"): consonant <~ "ㄑ"
        case ("ㄕ", "ㄧ"), ("ㄕ", "ㄩ"): consonant <~ "ㄒ"
        default: break
        }
        if incomingPhonabet.value == "ㄨ" {
          fixValue("ㄐ", "ㄓ")
          fixValue("ㄑ", "ㄔ")
          fixValue("ㄒ", "ㄕ")
        }
      case .vowel:
        if semivowel.isEmpty {
          fixValue("ㄐ", "ㄓ")
          fixValue("ㄑ", "ㄔ")
          fixValue("ㄒ", "ㄕ")
        }
      default: break
      }
    }

    /// 倚天忘形注音排列是複合注音排列，需要單獨處理。
    ///
    /// 回傳結果是空字串的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func handleETen26(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard var strReturn = Tekkon.mapETen26StaticKeys[key] else { return nil }

      let keysToHandleHere = "dfhjklmnpqtw"

      switch key {
      case "d" where isPronounceable: strReturn = "˙"
      case "f" where isPronounceable: strReturn = "ˊ"
      case "j" where isPronounceable: strReturn = "ˇ"
      case "k" where isPronounceable: strReturn = "ˋ"
      case "e" where consonant.value == "ㄍ": consonant <~ "ㄑ"
      case "p" where !consonant.isEmpty || semivowel.value == "ㄧ": strReturn = "ㄡ"
      case "h" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄦ"
      case "l" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄥ"
      case "m" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄢ"
      case "n" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄣ"
      case "q" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄟ"
      case "t" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄤ"
      case "w" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄝ"
      default: break
      }

      if keysToHandleHere.doesHave(key) {
        receiveKey(fromPhonabet: strReturn)
      }

      // 處理公共特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: Phonabet(strReturn))

      if "dfjk ".doesHave(key), count() == 1 {
        fixValue("ㄆ", "ㄡ")
        fixValue("ㄇ", "ㄢ")
        fixValue("ㄊ", "ㄤ")
        fixValue("ㄋ", "ㄣ")
        fixValue("ㄌ", "ㄥ")
        fixValue("ㄏ", "ㄦ")
      }

      // 後置修正
      if value == "ㄍ˙" { consonant <~ "ㄑ" }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if keysToHandleHere.doesHave(key) { return nil }

      // 回傳結果是空字串的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 許氏注音排列是複合注音排列，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func handleHsu(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard var strReturn = Tekkon.mapHsuStaticKeys[key] else { return nil }

      let keysToHandleHere = "acdefghjklmns"

      switch key {
      case "d" where isPronounceable: strReturn = "ˊ"
      case "f" where isPronounceable: strReturn = "ˇ"
      case "s" where isPronounceable: strReturn = "˙"
      case "j" where isPronounceable: strReturn = "ˋ"
      case "a" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄟ"
      case "v" where !semivowel.isEmpty: strReturn = "ㄑ"
      case "c" where !semivowel.isEmpty: strReturn = "ㄒ"
      case "e" where !semivowel.isEmpty: strReturn = "ㄝ"
      case "g" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄜ"
      case "h" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄛ"
      case "k" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄤ"
      case "m" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄢ"
      case "n" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄣ"
      case "l":
        if value.isEmpty, !consonant.isEmpty, !semivowel.isEmpty {
          strReturn = "ㄦ"
        } else if consonant.isEmpty, semivowel.isEmpty {
          strReturn = "ㄌ"
        } else {
          strReturn = "ㄥ"
        }
      default: break
      }

      if keysToHandleHere.doesHave(key) {
        receiveKey(fromPhonabet: strReturn)
      }

      // 處理公共特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: Phonabet(strReturn))

      if "dfjs ".doesHave(key), count() == 1 {
        fixValue("ㄒ", "ㄕ")
        fixValue("ㄍ", "ㄜ")
        fixValue("ㄋ", "ㄣ")
        fixValue("ㄌ", "ㄦ")
        fixValue("ㄎ", "ㄤ")
        fixValue("ㄇ", "ㄢ")
        fixValue("ㄐ", "ㄓ")
        fixValue("ㄑ", "ㄔ")
        fixValue("ㄒ", "ㄕ")
        fixValue("ㄏ", "ㄛ")
      }

      // 後置修正
      if value == "ㄔ˙" { consonant <~ "ㄑ" }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if keysToHandleHere.doesHave(key) { return nil }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 星光注音排列是複合注音排列，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func handleStarlight(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard var strReturn = Tekkon.mapStarlightStaticKeys[key] else { return nil }

      let keysToHandleHere = "efgklmnt"

      switch key {
      case "e" where "ㄧㄩ".doesHave(semivowel.value): strReturn = "ㄝ"
      case "f" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄠ"
      case "g" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄥ"
      case "k" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄤ"
      case "l" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄦ"
      case "m" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄢ"
      case "n" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄣ"
      case "t" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄟ"
      default: break
      }

      if keysToHandleHere.doesHave(key) {
        receiveKey(fromPhonabet: strReturn)
      }

      // 處理公共特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: Phonabet(strReturn))

      if "67890 ".doesHave(key), count() == 1 {
        fixValue("ㄈ", "ㄠ")
        fixValue("ㄍ", "ㄥ")
        fixValue("ㄎ", "ㄤ")
        fixValue("ㄌ", "ㄦ")
        fixValue("ㄇ", "ㄢ")
        fixValue("ㄋ", "ㄣ")
        fixValue("ㄊ", "ㄟ")
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if keysToHandleHere.doesHave(key) { return nil }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 酷音大千二十六鍵注音排列是複合注音排列，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func handleDachen26(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard var strReturn = Tekkon.mapDachenCP26StaticKeys[key] else { return nil }

      switch key {
      case "e" where isPronounceable: strReturn = "ˊ"
      case "r" where isPronounceable: strReturn = "ˇ"
      case "d" where isPronounceable: strReturn = "ˋ"
      case "y" where isPronounceable: strReturn = "˙"
      case "b" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄝ"
      case "i" where vowel.isEmpty || vowel.value == "ㄞ": strReturn = "ㄛ"
      case "l" where vowel.isEmpty || vowel.value == "ㄤ": strReturn = "ㄠ"
      case "n" where !consonant.isEmpty || !semivowel.isEmpty:
        if value == "ㄙ" { consonant.clear() }
        strReturn = "ㄥ"
      case "o" where vowel.isEmpty || vowel.value == "ㄢ": strReturn = "ㄟ"
      case "p" where vowel.isEmpty || vowel.value == "ㄦ": strReturn = "ㄣ"
      case "q" where consonant.isEmpty || consonant.value == "ㄅ": strReturn = "ㄆ"
      case "t" where consonant.isEmpty || consonant.value == "ㄓ": strReturn = "ㄔ"
      case "w" where consonant.isEmpty || consonant.value == "ㄉ": strReturn = "ㄊ"
      case "m":
        switch (semivowel.value, vowel.value) {
        case ("ㄩ", _):
          semivowel.clear()
          strReturn = "ㄡ"
        case (_, "ㄡ"):
          vowel.clear()
          strReturn = "ㄩ"
        default:
          strReturn = (!semivowel.isEmpty || !"ㄐㄑㄒ".doesHave(consonant.value)) ? "ㄡ" : "ㄩ"
        }
      case "u":
        switch (semivowel.value, vowel.value) {
        case ("ㄧ", "ㄚ"):
          semivowel.clear()
          vowel.clear()
        case ("ㄧ", _):
          semivowel.clear()
          strReturn = "ㄚ"
        case (_, "ㄚ"):
          strReturn = "ㄧ"
        default: strReturn = semivowel.isEmpty ? "ㄧ" : "ㄚ"
        }
      default: break
      }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 劉氏擬音注音排列是複合注音排列，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Remark: 該處理兼顧了「原旨排列方案」與「微軟新注音相容排列方案」。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    internal mutating func handleAlvinLiu(key: Unicode.Scalar) -> Unicode.Scalar? {
      guard var strReturn = Tekkon.mapAlvinLiuStaticKeys[key] else { return nil }

      // 前置處理專有特殊情形。
      if strReturn != "ㄦ" && !vowel.isEmpty { fixValue("ㄦ", "ㄌ") }

      let keysToHandleHere = "dfjlegnhkbmc"

      switch key {
      case "d" where isPronounceable: strReturn = "˙"
      case "f" where isPronounceable: strReturn = "ˊ"
      case "j" where isPronounceable: strReturn = "ˇ"
      case "l" where isPronounceable: strReturn = "ˋ"
      case "e" where "ㄧㄩ".doesHave(semivowel.value): strReturn = "ㄝ"
      case "g" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄤ"
      case "n" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄣ"
      case "h" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄞ"
      case "k" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄟ"
      case "b" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄢ"
      case "m" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄥ"
      case "c" where !consonant.isEmpty || !semivowel.isEmpty: strReturn = "ㄝ"
      default: break
      }

      if keysToHandleHere.doesHave(key) {
        receiveKey(fromPhonabet: strReturn)
      }

      // 處理公共特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: Phonabet(strReturn))

      if "dfjl ".doesHave(key), count() == 1 {
        fixValue("ㄑ", "ㄔ")
        fixValue("ㄊ", "ㄦ")
        fixValue("ㄍ", "ㄤ")
        fixValue("ㄏ", "ㄞ")
        fixValue("ㄐ", "ㄓ")
        fixValue("ㄎ", "ㄟ")
        fixValue("ㄌ", "ㄦ")
        fixValue("ㄒ", "ㄕ")
        fixValue("ㄅ", "ㄢ")
        fixValue("ㄋ", "ㄣ")
        fixValue("ㄇ", "ㄥ")
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if keysToHandleHere.doesHave(key) { return nil }

      // 回傳結果是空字串的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 按需更新拼音組音區的內容顯示。
    internal mutating func updateRomajiBuffer() {
      romajiBuffer = Tekkon
        .cnvPhonaToHanyuPinyin(targetJoined: consonant.value + semivowel.value + vowel.value)
    }

    /// 自我變換單個注音資料值。
    /// - Parameters:
    ///   - strOf: 要取代的內容。
    ///   - strWith: 要取代成的內容。
    internal mutating func fixValue(_ strOf: Unicode.Scalar, _ strWith: Unicode.Scalar) {
      guard Phonabet(strOf).isValid, Phonabet(strWith).isValid else { return }
      let theOld = Phonabet(strOf)
      switch theOld {
      case consonant: consonant.clear()
      case semivowel: semivowel.clear()
      case vowel: vowel.clear()
      case intonation: intonation.clear()
      default: return
      }
      receiveKey(fromPhonabet: strWith)
    }
  }
}

extension String {
  fileprivate func doesHave(_ target: String) -> Bool {
    has(string: target)
  }

  fileprivate func doesHave(_ target: Unicode.Scalar) -> Bool {
    has(scalar: target)
  }
}
