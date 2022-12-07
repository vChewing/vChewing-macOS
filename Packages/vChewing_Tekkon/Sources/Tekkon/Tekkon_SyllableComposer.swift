// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension Tekkon {
  // MARK: - Syllable Composer

  /// 注音並擊處理的對外介面以注拼槽（Syllable Composer）的形式存在。
  /// 使用時需要單獨初期化為一個副本變數（因為是 Struct 所以必須得是變數）。
  /// 注拼槽只有四格：聲、介、韻、調。
  ///
  /// 因為是 String Literal，所以初期化時可以藉由 @input 參數指定初期已經傳入的按鍵訊號。
  /// 還可以在初期化時藉由 @arrange 參數來指定注音排列（預設為「.ofDachen」大千佈局）。
  @frozen public struct Composer: Equatable, Hashable, ExpressibleByStringLiteral {
    /// 聲母。
    public var consonant: Phonabet = ""

    /// 介母。
    public var semivowel: Phonabet = ""

    /// 韻母。
    public var vowel: Phonabet = ""

    /// 聲調。
    public var intonation: Phonabet = ""

    /// 拼音組音區。
    public var romajiBuffer: String = ""

    /// 注音排列種類。預設情況下是大千排列（Windows / macOS 預設注音排列）。
    public var parser: MandarinParser = .ofDachen

    /// 是否對錯誤的注音讀音組合做出自動糾正處理。
    public var phonabetCombinationCorrectionEnabled = false

    /// 內容值，會直接按照正確的順序拼裝自己的聲介韻調內容、再回傳。
    /// 注意：直接取這個參數的內容的話，陰平聲調會成為一個空格。
    /// 如果是要取不帶空格的注音的話，請使用「.getComposition()」而非「.value」。
    public var value: String {
      consonant.value + semivowel.value + vowel.value + intonation.value
    }

    /// 與 value 類似，這個函式就是用來決定輸入法組字區內顯示的注音/拼音內容，
    /// 但可以指定是否輸出教科書格式（拼音的調號在字母上方、注音的輕聲寫在左側）。
    /// - Parameters:
    ///   - isHanyuPinyin: 是否將輸出結果轉成漢語拼音。
    ///   - isTextBookStyle: 是否將輸出的注音/拼音結果轉成教科書排版格式。
    public func getComposition(isHanyuPinyin: Bool = false, isTextBookStyle: Bool = false) -> String {
      switch isHanyuPinyin {
        case false:  // 注音輸出的場合
          let valReturnZhuyin = value.replacingOccurrences(of: " ", with: "")
          return isTextBookStyle ? cnvZhuyinChainToTextbookReading(targetJoined: valReturnZhuyin) : valReturnZhuyin
        case true:  // 拼音輸出的場合
          let valReturnPinyin = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: value)
          return isTextBookStyle ? Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: valReturnPinyin) : valReturnPinyin
      }
    }

    // 該函式僅用來獲取給 macOS InputMethod Kit 的內文組字區使用的顯示字串。
    /// - Parameters:
    ///   - isHanyuPinyin: 是否將輸出結果轉成漢語拼音。
    public func getInlineCompositionForDisplay(isHanyuPinyin: Bool = false) -> String {
      switch parser {
        case .ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin:
          var toneReturned = ""
          switch intonation.value {
            case " ": toneReturned = "1"
            case "ˊ": toneReturned = "2"
            case "ˇ": toneReturned = "3"
            case "ˋ": toneReturned = "4"
            case "˙": toneReturned = "5"
            default: break
          }
          return romajiBuffer + toneReturned
        default: return getComposition(isHanyuPinyin: isHanyuPinyin)
      }
    }

    /// 注拼槽內容是否為空。
    public var isEmpty: Bool {
      switch parser {
        case .ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin:
          return intonation.isEmpty && romajiBuffer.isEmpty
        default: return intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
      }
    }

    /// 注拼槽內容是否可唸。
    public var isPronouncable: Bool {
      !vowel.isEmpty || !semivowel.isEmpty || !consonant.isEmpty
    }

    // MARK: 注拼槽對外處理函式

    /// 初期化一個新的注拼槽。可以藉由 @input 參數指定初期已經傳入的按鍵訊號。
    /// 還可以在初期化時藉由 @arrange 參數來指定注音排列（預設為「.ofDachen」大千佈局）。
    /// - Parameters:
    ///   - input: 傳入的 String 內容，用以處理單個字符。
    ///   - arrange: 要使用的注音排列。
    ///   - correction: 是否對錯誤的注音讀音組合做出自動糾正處理。
    public init(_ input: String = "", arrange parser: MandarinParser = .ofDachen, correction: Bool = false) {
      phonabetCombinationCorrectionEnabled = correction
      ensureParser(arrange: parser)
      receiveKey(fromString: input)
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

    /// 用於檢測「某個輸入字符訊號的合規性」的函式。
    ///
    /// 注意：回傳結果會受到當前注音排列 parser 屬性的影響。
    /// - Parameters:
    ///   - key: 傳入的 UniChar 內容。
    public func inputValidityCheck(key inputKey: UniChar = 0) -> Bool {
      if let scalar = UnicodeScalar(inputKey) {
        let input = String(scalar)
        switch parser {
          case .ofDachen:
            return Tekkon.mapQwertyDachen[input] != nil
          case .ofDachen26:
            return Tekkon.mapDachenCP26StaticKeys[input] != nil
          case .ofETen:
            return Tekkon.mapQwertyETenTraditional[input] != nil
          case .ofHsu:
            return Tekkon.mapHsuStaticKeys[input] != nil
          case .ofETen26:
            return Tekkon.mapETen26StaticKeys[input] != nil
          case .ofIBM:
            return Tekkon.mapQwertyIBM[input] != nil
          case .ofMiTAC:
            return Tekkon.mapQwertyMiTAC[input] != nil
          case .ofSeigyou:
            return Tekkon.mapSeigyou[input] != nil
          case .ofFakeSeigyou:
            return Tekkon.mapFakeSeigyou[input] != nil
          case .ofStarlight:
            return Tekkon.mapStarlightStaticKeys[input] != nil
          case .ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin:
            return Tekkon.mapArayuruPinyin.contains(input)
        }
      }
      return false
    }

    /// 按需更新拼音組音區的內容顯示。
    mutating func updateRomajiBuffer() {
      romajiBuffer = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: consonant.value + semivowel.value + vowel.value)
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 String。
    /// 另有同名函式可處理 UniChar 訊號。
    ///
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromString: 傳入的 String 內容。
    public mutating func receiveKey(fromString input: String = "") {
      switch parser {
        case .ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin:
          if mapArayuruPinyinIntonation.keys.contains(input) {
            if let theTone = mapArayuruPinyinIntonation[input] {
              intonation = Phonabet(theTone)
            }
          } else {
            // 為了防止 romajiBuffer 越敲越長帶來算力負擔，這裡讓它在要溢出時自動丟掉最早輸入的音頭。
            if romajiBuffer.count > 5 {
              romajiBuffer = String(romajiBuffer.dropFirst())
            }
            let romajiBufferBackup = romajiBuffer + input
            receiveSequence(romajiBufferBackup, isRomaji: true)
            romajiBuffer = romajiBufferBackup
          }
        default: receiveKey(fromPhonabet: translate(key: input))
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 UniChar。
    /// 其實也就是先將 UniChar 轉為 String 再交給某個同名異參的函式來處理而已。
    ///
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromCharCode: 傳入的 UniChar 內容。
    public mutating func receiveKey(fromCharCode inputCharCode: UniChar = 0) {
      if let scalar = UnicodeScalar(inputCharCode) {
        receiveKey(fromString: String(scalar))
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為單個注音符號。
    /// 主要就是將注音符號拆分辨識且分配到正確的貯存位置而已。
    /// - Parameters:
    ///   - fromPhonabet: 傳入的單個注音符號字串。
    public mutating func receiveKey(fromPhonabet phonabet: String = "") {
      var thePhone: Phonabet = .init(phonabet)
      if phonabetCombinationCorrectionEnabled {
        switch phonabet {
          case "ㄧ", "ㄩ":
            if vowel.value == "ㄜ" { vowel = "ㄝ" }
          case "ㄜ":
            if "ㄨ".contains(semivowel.value) { semivowel = "ㄩ" }
            if "ㄧㄩ".contains(semivowel.value) { thePhone = "ㄝ" }
          case "ㄝ":
            if "ㄨ".contains(semivowel.value) { semivowel = "ㄩ" }
          case "ㄛ", "ㄥ":
            if phonabet == "ㄛ", semivowel.value == "ㄩ" { semivowel = "ㄨ" }
            if "ㄅㄆㄇㄈ".contains(consonant.value), semivowel.value == "ㄨ" { semivowel.clear() }
          case "ㄟ":
            if "ㄋㄌ".contains(consonant.value), semivowel.value == "ㄨ" { semivowel.clear() }
          case "ㄨ":
            if "ㄅㄆㄇㄈ".contains(consonant.value), "ㄛㄥ".contains(vowel.value) { vowel.clear() }
            if "ㄋㄌ".contains(consonant.value), "ㄟ".contains(vowel.value) { vowel.clear() }
            if "ㄜ".contains(vowel.value) { vowel = "ㄝ" }
            if "ㄝ".contains(vowel.value) { thePhone = "ㄩ" }
          case "ㄅ", "ㄆ", "ㄇ", "ㄈ":
            if ["ㄨㄛ", "ㄨㄥ"].contains(semivowel.value + vowel.value) { semivowel.clear() }
          default: break
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
    public mutating func receiveSequence(_ givenSequence: String = "", isRomaji: Bool = false) {
      clear()
      if isRomaji {
        switch parser {
          case .ofHanyuPinyin:
            if let dictResult = mapHanyuPinyin[givenSequence] {
              for phonabet in dictResult {
                receiveKey(fromPhonabet: String(phonabet))
              }
            }
          case .ofSecondaryPinyin:
            if let dictResult = mapSecondaryPinyin[givenSequence] {
              for phonabet in dictResult {
                receiveKey(fromPhonabet: String(phonabet))
              }
            }
          case .ofYalePinyin:
            if let dictResult = mapYalePinyin[givenSequence] {
              for phonabet in dictResult {
                receiveKey(fromPhonabet: String(phonabet))
              }
            }
          case .ofHualuoPinyin:
            if let dictResult = mapHualuoPinyin[givenSequence] {
              for phonabet in dictResult {
                receiveKey(fromPhonabet: String(phonabet))
              }
            }
          case .ofUniversalPinyin:
            if let dictResult = mapUniversalPinyin[givenSequence] {
              for phonabet in dictResult {
                receiveKey(fromPhonabet: String(phonabet))
              }
            }
          default: break
        }
      } else {
        for key in givenSequence {
          receiveKey(fromString: String(key))
        }
      }
    }

    /// 處理一連串的按鍵輸入、且返回被處理之後的注音（陰平為空格）。
    /// - Parameters:
    ///   - givenSequence: 傳入的 String 內容，用以處理一整串擊鍵輸入。
    public mutating func convertSequenceToRawComposition(_ givenSequence: String = "") -> String {
      receiveSequence(givenSequence)
      return value
    }

    /// 專門用來響應使用者摁下 BackSpace 按鍵時的行為。
    /// 刪除順序：調、韻、介、聲。
    ///
    /// 基本上就是按順序從游標前方開始往後刪。
    public mutating func doBackSpace() {
      if [.ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin].contains(parser),
        !romajiBuffer.isEmpty
      {
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

    // MARK: - Parser Processings

    // 注拼槽對內處理用函式都在這一小節。

    /// 根據目前的注音排列設定來翻譯傳入的 String 訊號。
    ///
    /// 倚天或許氏鍵盤的處理函式會將分配過程代為處理過，此時回傳結果為空字串。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    public mutating func translate(key: String = "") -> String {
      switch parser {
        case .ofDachen:
          return Tekkon.mapQwertyDachen[key] ?? ""
        case .ofDachen26:
          return handleDachen26(key: key)
        case .ofETen:
          return Tekkon.mapQwertyETenTraditional[key] ?? ""
        case .ofHsu:
          return handleHsu(key: key)
        case .ofETen26:
          return handleETen26(key: key)
        case .ofIBM:
          return Tekkon.mapQwertyIBM[key] ?? ""
        case .ofMiTAC:
          return Tekkon.mapQwertyMiTAC[key] ?? ""
        case .ofSeigyou:
          return Tekkon.mapSeigyou[key] ?? ""
        case .ofFakeSeigyou:
          return Tekkon.mapFakeSeigyou[key] ?? ""
        case .ofStarlight:
          return handleStarlight(key: key)
        case .ofHanyuPinyin, .ofSecondaryPinyin, .ofYalePinyin, .ofHualuoPinyin, .ofUniversalPinyin:
          break  // 漢語拼音單獨用另外的函式處理
      }
      return ""
    }

    /// 所有動態注音鍵盤佈局都會用到的共用糾錯處理步驟。
    /// - Parameter incomingPhonabet: 傳入的注音 Phonabet。
    public mutating func commonFixWhenHandlingDynamicArrangeInputs(target incomingPhonabet: Phonabet) {
      // 處理特殊情形。
      switch incomingPhonabet.type {
        case .semivowel:
          switch consonant {
            case "ㄍ":
              switch incomingPhonabet {
                case "ㄧ": consonant = "ㄑ"  // ㄑㄧ
                case "ㄨ": consonant = "ㄍ"  // ㄍㄨ
                case "ㄩ": consonant = "ㄑ"  // ㄑㄩ
                default: break
              }
            case "ㄓ":
              switch incomingPhonabet {
                case "ㄧ": consonant = "ㄐ"  // ㄐㄧ
                case "ㄨ": consonant = "ㄓ"  // ㄓㄨ
                case "ㄩ": consonant = "ㄐ"  // ㄐㄩ
                default: break
              }
            case "ㄔ":
              switch incomingPhonabet {
                case "ㄧ": consonant = "ㄑ"  // ㄐㄧ
                case "ㄨ": consonant = "ㄔ"  // ㄓㄨ
                case "ㄩ": consonant = "ㄑ"  // ㄐㄩ
                default: break
              }
            case "ㄕ":
              switch incomingPhonabet {
                case "ㄧ": consonant = "ㄒ"  // ㄒㄧ
                case "ㄨ": consonant = "ㄕ"  // ㄕㄨ
                case "ㄩ": consonant = "ㄒ"  // ㄒㄩ
                default: break
              }
            default: break
          }
        case .vowel:
          if semivowel.isEmpty {
            consonant.selfReplace("ㄐ", "ㄓ")
            consonant.selfReplace("ㄑ", "ㄔ")
            consonant.selfReplace("ㄒ", "ㄕ")
          }
        default: break
      }
    }

    /// 倚天忘形注音排列比較麻煩，需要單獨處理。
    ///
    /// 回傳結果是空字串的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    public mutating func handleETen26(key: String = "") -> String {
      var strReturn = Tekkon.mapETen26StaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)

      switch key {
        case "d": if !isPronouncable { consonant = "ㄉ" } else { intonation = "˙" }
        case "f": if !isPronouncable { consonant = "ㄈ" } else { intonation = "ˊ" }
        case "j": if !isPronouncable { consonant = "ㄖ" } else { intonation = "ˇ" }
        case "k": if !isPronouncable { consonant = "ㄎ" } else { intonation = "ˋ" }
        case "h": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄏ" } else { vowel = "ㄦ" }
        case "l": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄌ" } else { vowel = "ㄥ" }
        case "m": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄇ" } else { vowel = "ㄢ" }
        case "n": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄋ" } else { vowel = "ㄣ" }
        case "q": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄗ" } else { vowel = "ㄟ" }
        case "t": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄊ" } else { vowel = "ㄤ" }
        case "w": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄘ" } else { vowel = "ㄝ" }
        case "p":
          if consonant.isEmpty, semivowel.isEmpty {
            consonant = "ㄆ"
          } else if consonant.isEmpty, semivowel == "ㄧ" {
            vowel = "ㄡ"
          } else if consonant.isEmpty {
            vowel = "ㄆ"
          } else {
            vowel = "ㄡ"
          }
        default: break
      }

      // 處理特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: incomingPhonabet)

      if "dfjk ".contains(key),
        !consonant.isEmpty, semivowel.isEmpty, vowel.isEmpty
      {
        consonant.selfReplace("ㄆ", "ㄡ")
        consonant.selfReplace("ㄇ", "ㄢ")
        consonant.selfReplace("ㄊ", "ㄤ")
        consonant.selfReplace("ㄋ", "ㄣ")
        consonant.selfReplace("ㄌ", "ㄥ")
        consonant.selfReplace("ㄏ", "ㄦ")
      }

      // 後置修正
      if value == "ㄍ˙" { consonant = "ㄑ" }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "dfhjklmnpqtw".contains(key) { strReturn = "" }

      // 回傳結果是空字串的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 許氏鍵盤與倚天忘形一樣同樣也比較麻煩，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    public mutating func handleHsu(key: String = "") -> String {
      var strReturn = Tekkon.mapHsuStaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)

      if key == " ", value == "ㄋ" {
        consonant.clear()
        vowel = "ㄣ"
      }

      switch key {
        case "d": if isPronouncable { intonation = "ˊ" } else { consonant = "ㄉ" }
        case "f": if isPronouncable { intonation = "ˇ" } else { consonant = "ㄈ" }
        case "s": if isPronouncable { intonation = "˙" } else { consonant = "ㄙ" }
        case "j": if isPronouncable { intonation = "ˋ" } else { consonant = "ㄓ" }
        case "a": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄘ" } else { vowel = "ㄟ" }
        case "v": if semivowel.isEmpty { consonant = "ㄔ" } else { consonant = "ㄑ" }
        case "c": if semivowel.isEmpty { consonant = "ㄕ" } else { consonant = "ㄒ" }
        case "e": if semivowel.isEmpty { semivowel = "ㄧ" } else { vowel = "ㄝ" }
        case "g": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄍ" } else { vowel = "ㄜ" }
        case "h": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄏ" } else { vowel = "ㄛ" }
        case "k": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄎ" } else { vowel = "ㄤ" }
        case "m": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄇ" } else { vowel = "ㄢ" }
        case "n": if consonant.isEmpty, semivowel.isEmpty { consonant = "ㄋ" } else { vowel = "ㄣ" }
        case "l":
          if value.isEmpty, !consonant.isEmpty, !semivowel.isEmpty {
            vowel = "ㄦ"
          } else if consonant.isEmpty, semivowel.isEmpty {
            consonant = "ㄌ"
          } else {
            vowel = "ㄥ"
          }
        default: break
      }

      // 處理特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: incomingPhonabet)

      if "dfjs ".contains(key) {
        if !consonant.isEmpty, semivowel.isEmpty, vowel.isEmpty {
          consonant.selfReplace("ㄍ", "ㄜ")
          consonant.selfReplace("ㄋ", "ㄣ")
          consonant.selfReplace("ㄌ", "ㄦ")
          consonant.selfReplace("ㄎ", "ㄤ")
          consonant.selfReplace("ㄇ", "ㄢ")
        }
        if !consonant.isEmpty, vowel.isEmpty {
          consonant.selfReplace("ㄧ", "ㄝ")
        }
        if "ㄢㄣㄤㄥ".contains(vowel.value), semivowel.isEmpty {
          consonant.selfReplace("ㄐ", "ㄓ")
          consonant.selfReplace("ㄑ", "ㄔ")
          consonant.selfReplace("ㄒ", "ㄕ")
        }
        if "ㄐㄑㄒ".contains(consonant.value), semivowel.isEmpty {
          consonant.selfReplace("ㄐ", "ㄓ")
          consonant.selfReplace("ㄑ", "ㄔ")
          consonant.selfReplace("ㄒ", "ㄕ")
        }
        if consonant == "ㄏ", semivowel.isEmpty, vowel.isEmpty {
          consonant.clear()
          vowel = "ㄛ"
        }
      }

      // 後置修正
      if value == "ㄔ˙" { consonant = "ㄑ" }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "acdefghjklmns".contains(key) { strReturn = "" }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 星光排列一樣同樣也比較麻煩，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    public mutating func handleStarlight(key: String) -> String {
      var strReturn = Tekkon.mapStarlightStaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)
      switch key {
        case "e": return "ㄧㄩ".contains(semivowel.value) ? "ㄝ" : "ㄜ"
        case "f": return vowel == "ㄠ" || !isPronouncable ? "ㄈ" : "ㄠ"
        case "g": return vowel == "ㄥ" || !isPronouncable ? "ㄍ" : "ㄥ"
        case "k": return vowel == "ㄤ" || !isPronouncable ? "ㄎ" : "ㄤ"
        case "l": return vowel == "ㄦ" || !isPronouncable ? "ㄌ" : "ㄦ"
        case "m": return vowel == "ㄢ" || !isPronouncable ? "ㄇ" : "ㄢ"
        case "n": return vowel == "ㄣ" || !isPronouncable ? "ㄋ" : "ㄣ"
        case "t": return vowel == "ㄟ" || !isPronouncable ? "ㄊ" : "ㄟ"
        default: break
      }

      // 處理特殊情形。
      commonFixWhenHandlingDynamicArrangeInputs(target: incomingPhonabet)

      if "67890 ".contains(key) {
        if !consonant.isEmpty, semivowel.isEmpty, vowel.isEmpty {
          consonant.selfReplace("ㄈ", "ㄠ")
          consonant.selfReplace("ㄍ", "ㄥ")
          consonant.selfReplace("ㄎ", "ㄤ")
          consonant.selfReplace("ㄌ", "ㄦ")
          consonant.selfReplace("ㄇ", "ㄢ")
          consonant.selfReplace("ㄋ", "ㄣ")
          consonant.selfReplace("ㄊ", "ㄟ")
        }
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "efgklmn".contains(key) { strReturn = "" }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 大千忘形一樣同樣也比較麻煩，需要單獨處理。
    ///
    /// 回傳結果是空的話，不要緊，因為該函式內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    public mutating func handleDachen26(key: String = "") -> String {
      var strReturn = Tekkon.mapDachenCP26StaticKeys[key] ?? ""

      switch key {
        case "e": if isPronouncable { intonation = "ˊ" } else { consonant = "ㄍ" }
        case "r": if isPronouncable { intonation = "ˇ" } else { consonant = "ㄐ" }
        case "d": if isPronouncable { intonation = "ˋ" } else { consonant = "ㄎ" }
        case "y": if isPronouncable { intonation = "˙" } else { consonant = "ㄗ" }
        case "b": if !consonant.isEmpty || !semivowel.isEmpty { vowel = "ㄝ" } else { consonant = "ㄖ" }
        case "i": if vowel.isEmpty || vowel == "ㄞ" { vowel = "ㄛ" } else { vowel = "ㄞ" }
        case "l": if vowel.isEmpty || vowel == "ㄤ" { vowel = "ㄠ" } else { vowel = "ㄤ" }
        case "n":
          if !consonant.isEmpty || !semivowel.isEmpty {
            if consonant == "ㄙ", semivowel.isEmpty, vowel.isEmpty { consonant.clear() }
            vowel = "ㄥ"
          } else {
            consonant = "ㄙ"
          }
        case "o": if vowel.isEmpty || vowel == "ㄢ" { vowel = "ㄟ" } else { vowel = "ㄢ" }
        case "p": if vowel.isEmpty || vowel == "ㄦ" { vowel = "ㄣ" } else { vowel = "ㄦ" }
        case "q": if consonant.isEmpty || consonant == "ㄅ" { consonant = "ㄆ" } else { consonant = "ㄅ" }
        case "t": if consonant.isEmpty || consonant == "ㄓ" { consonant = "ㄔ" } else { consonant = "ㄓ" }
        case "w": if consonant.isEmpty || consonant == "ㄉ" { consonant = "ㄊ" } else { consonant = "ㄉ" }
        case "m":
          if semivowel == "ㄩ", vowel != "ㄡ" {
            semivowel.clear()
            vowel = "ㄡ"
          } else if semivowel != "ㄩ", vowel == "ㄡ" {
            semivowel = "ㄩ"
            vowel.clear()
          } else if !semivowel.isEmpty {
            vowel = "ㄡ"
          } else {
            receiveKey(fromPhonabet: "ㄐㄑㄒ".contains(consonant.value) ? "ㄩ" : "ㄡ")
          }
        case "u":
          if semivowel == "ㄧ", vowel != "ㄚ" {
            semivowel.clear()
            vowel = "ㄚ"
          } else if semivowel != "ㄧ", vowel == "ㄚ" {
            semivowel = "ㄧ"
          } else if semivowel == "ㄧ", vowel == "ㄚ" {
            semivowel.clear()
            vowel.clear()
          } else if !semivowel.isEmpty {
            vowel = "ㄚ"
          } else {
            semivowel = "ㄧ"
          }
        default: break
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "qwtilopnbmuerdy".contains(key) { strReturn = "" }

      // 回傳結果是空的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    // MARK: - Misc Definitions

    /// 這些內容用來滿足 "Equatable, Hashable, ExpressibleByStringLiteral" 需求。

    public static func == (lhs: Composer, rhs: Composer) -> Bool {
      lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(consonant)
      hasher.combine(semivowel)
      hasher.combine(vowel)
      hasher.combine(intonation)
    }

    public init(stringLiteral value: String) {
      self.init(value)
    }

    public init(unicodeScalarLiteral value: String) {
      self.init(stringLiteral: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
      self.init(stringLiteral: value)
    }
  }
}
