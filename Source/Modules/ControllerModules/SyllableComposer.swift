// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

/// The namespace for this package.
public struct Tekkon {
  // MARK: - Static Constants and Basic Enums

  /// 定義注音符號的種類
  public enum PhoneType: Int {
    case null = 0  // 假
    case consonant = 1  // 聲
    case semivowel = 2  // 介
    case vowel = 3  // 韻
    case intonation = 4  // 調
  }

  /// 定義注音排列的類型
  public enum MandarinParser: Int {
    case ofDachen = 0
    case ofDachen26 = 1
    case ofETen = 2
    case ofETen26 = 3
    case ofHsu = 4
    case ofIBM = 5
    case ofMiTAC = 6
    case ofSeigyou = 7
    case ofFakeSeigyou = 8
    case ofStarlight = 9
    case ofHanyuPinyin = 100
    case ofSecondaryPinyin = 101
    case ofYalePinyin = 102
    case ofHualuoPinyin = 103
    case ofUniversalPinyin = 104

    var name: String {
      switch self {
        case .ofDachen:
          return "Dachen"
        case .ofDachen26:
          return "Dachen26"
        case .ofETen:
          return "ETen"
        case .ofHsu:
          return "Hsu"
        case .ofETen26:
          return "ETen26"
        case .ofIBM:
          return "IBM"
        case .ofMiTAC:
          return "MiTAC"
        case .ofFakeSeigyou:
          return "FakeSeigyou"
        case .ofSeigyou:
          return "Seigyou"
        case .ofStarlight:
          return "Starlight"
        case .ofHanyuPinyin:
          return "HanyuPinyin"
        case .ofSecondaryPinyin:
          return "SecondaryPinyin"
        case .ofYalePinyin:
          return "YalePinyin"
        case .ofHualuoPinyin:
          return "HualuoPinyin"
        case .ofUniversalPinyin:
          return "UniversalPinyin"
      }
    }
  }

  /// 引擎僅接受這些記號作為聲母
  public static let allowedConsonants = [
    "ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄉ", "ㄊ", "ㄋ", "ㄌ",
    "ㄍ", "ㄎ", "ㄏ", "ㄐ", "ㄑ", "ㄒ",
    "ㄓ", "ㄔ", "ㄕ", "ㄖ", "ㄗ", "ㄘ", "ㄙ",
  ]

  /// 引擎僅接受這些記號作為介母
  public static let allowedSemivowels = ["ㄧ", "ㄨ", "ㄩ"]

  /// 引擎僅接受這些記號作為韻母
  public static let allowedVowels = [
    "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ",
    "ㄠ", "ㄡ", "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
  ]

  /// 引擎僅接受這些記號作為聲調
  public static let allowedIntonations = [" ", "ˊ", "ˇ", "ˋ", "˙"]

  /// 引擎僅接受這些記號作為注音（聲介韻調四個集合加起來）
  public static var allowedPhonabets: [String] {
    allowedConsonants + allowedSemivowels + allowedVowels + allowedIntonations
  }

  // MARK: - Phonabet Structure

  /// 注音符號型別。本身與字串差不多，但卻只能被設定成一個注音符號字符。
  /// 然後會根據自身的 value 的內容值自動計算自身的 PhoneType 類型（聲介韻調假）。
  /// 如果遇到被設為多個字符、或者字符不對的情況的話，value 會被清空、PhoneType 會變成 null。
  /// 賦值時最好直接重新 init 且一直用 let 來初期化 Phonabet。
  /// 其實 value 對外只讀，對內的話另有 valueStorage 代為存儲內容。這樣比較安全一些。
  @frozen public struct Phonabet: Equatable, Hashable, ExpressibleByStringLiteral {
    public var type: PhoneType = .null
    private var valueStorage = ""
    public var value: String { valueStorage }
    public var isEmpty: Bool {
      value.isEmpty
    }

    /// 初期化，會根據傳入的 input 字串參數來自動判定自身的 PhoneType 類型屬性值。
    public init(_ input: String = "") {
      if !input.isEmpty {
        if allowedPhonabets.contains(String(input.reversed()[0])) {
          valueStorage = String(input.reversed()[0])
          ensureType()
        }
      }
    }

    /// 自我清空內容。
    public mutating func clear() {
      valueStorage = ""
      type = .null
    }

    /// 自我變換資料值。
    /// - Parameters:
    ///   - strOf: 要取代的內容。
    ///   - strWith: 要取代成的內容。
    mutating func selfReplace(_ strOf: String, _ strWith: String = "") {
      valueStorage = valueStorage.replacingOccurrences(of: strOf, with: strWith)
      ensureType()
    }

    /// 用來自動更新自身的屬性值的函式。
    mutating func ensureType() {
      if Tekkon.allowedConsonants.contains(value) {
        type = .consonant
      } else if Tekkon.allowedSemivowels.contains(value) {
        type = .semivowel
      } else if Tekkon.allowedVowels.contains(value) {
        type = .vowel
      } else if Tekkon.allowedIntonations.contains(value) {
        type = .intonation
      } else {
        type = .null
        valueStorage = ""
      }
    }

    // MARK: - Misc Definitions

    /// 這些內容用來滿足 "Equatable, Hashable, ExpressibleByStringLiteral" 需求。

    public static func == (lhs: Phonabet, rhs: Phonabet) -> Bool {
      lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(value)
      hasher.combine(type)
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

    /// 為拉丁字母專用的組音區。
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
          return isTextBookStyle ? cnvZhuyinChainToTextbookReading(target: valReturnZhuyin) : valReturnZhuyin
        case true:  // 拼音輸出的場合
          let valReturnPinyin = Tekkon.cnvPhonaToHanyuPinyin(target: value)
          return isTextBookStyle ? Tekkon.cnvHanyuPinyinToTextbookStyle(target: valReturnPinyin) : valReturnPinyin
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
    }

    /// 處理一連串的按鍵輸入。
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
    public func hasToneMarker(withNothingElse: Bool = false) -> Bool {
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
    mutating func translate(key: String = "") -> String {
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
    mutating func commonFixWhenHandlingDynamicArrangeInputs(target incomingPhonabet: Phonabet) {
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
    mutating func handleETen26(key: String = "") -> String {
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
    mutating func handleHsu(key: String = "") -> String {
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
    mutating func handleStarlight(key: String) -> String {
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
    mutating func handleDachen26(key: String = "") -> String {
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

  // MARK: - Phonabet to Hanyu-Pinyin Conversion Processing

  /// 注音轉拼音，要求陰平必須是空格。
  /// - Parameters:
  ///   - target: 傳入的 String 對象物件。
  static func cnvPhonaToHanyuPinyin(target: String) -> String {
    var targetConverted = target
    for pair in arrPhonaToHanyuPinyin {
      targetConverted = targetConverted.replacingOccurrences(of: pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 漢語拼音數字標調式轉漢語拼音教科書格式，要求陰平必須是數字 1。
  /// - Parameters:
  ///   - target: 傳入的 String 對象物件。
  static func cnvHanyuPinyinToTextbookStyle(target: String) -> String {
    var targetConverted = target
    for pair in arrHanyuPinyinTextbookStyleConversionTable {
      targetConverted = targetConverted.replacingOccurrences(of: pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 該函式負責將注音轉為教科書印刷的方式（先寫輕聲）。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音鏈，以英文減號來分隔每個讀音。
  ///   - newSeparator: 新的讀音分隔符。
  /// - Returns: 經過轉換處理的讀音鏈。
  static func cnvZhuyinChainToTextbookReading(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newString = String(neta)
      if String(neta.reversed()[0]) == "˙" {
        newString = String(neta.dropLast())
        newString.insert("˙", at: newString.startIndex)
      }
      arrReturn.append(newString)
    }
    return arrReturn.joined(separator: newSeparator)
  }

  /// 該函式用來恢復注音當中的陰平聲調，恢復之後會以「1」表示陰平。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音鏈，以英文減號來分隔每個讀音。
  ///   - newSeparator: 新的讀音分隔符。
  /// - Returns: 經過轉換處理的讀音鏈。
  static func restoreToneOneInZhuyinKey(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newNeta = String(neta)
      if !"ˊˇˋ˙".contains(String(neta.reversed()[0])), !neta.contains("_") {
        newNeta += "1"
      }
      arrReturn.append(newNeta)
    }
    return arrReturn.joined(separator: newSeparator)
  }

  /// 該函式用來將漢語拼音轉為注音。
  /// - Parameters:
  ///   - target: 要轉換的漢語拼音內容，要求必須帶有 12345 數字標調。
  ///   - newToneOne: 對陰平指定新的標記。預設情況下該標記為空字串。
  /// - Returns: 轉換結果。
  static func cnvHanyuPinyinToPhona(target: String, newToneOne: String = "") -> String {
    /// 如果當前內容有任何除了半形英數內容以外的內容的話，就直接放棄轉換。
    if target.contains("_") || !target.isNotPureAlphanumerical { return target }
    var result = target
    for key in Tekkon.mapHanyuPinyin.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapHanyuPinyin[key] else { continue }
      result = result.replacingOccurrences(of: key, with: value)
    }
    for key in Tekkon.mapArayuruPinyinIntonation.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapArayuruPinyinIntonation[key] else { continue }
      result = result.replacingOccurrences(of: key, with: (key == "1") ? newToneOne : value)
    }
    return result
  }

  /// 原始轉換對照表資料貯存專用佇列（數字標調格式）
  static let arrPhonaToHanyuPinyin = [  // 排序很重要。先處理最長的，再處理短的。不然會出亂子。
    [" ", "1"], ["ˊ", "2"], ["ˇ", "3"], ["ˋ", "4"], ["˙", "5"],

    ["ㄅㄧㄝ", "bie"], ["ㄅㄧㄠ", "biao"], ["ㄅㄧㄢ", "bian"], ["ㄅㄧㄣ", "bin"], ["ㄅㄧㄥ", "bing"], ["ㄆㄧㄚ", "pia"], ["ㄆㄧㄝ", "pie"],
    ["ㄆㄧㄠ", "piao"], ["ㄆㄧㄢ", "pian"], ["ㄆㄧㄣ", "pin"], ["ㄆㄧㄥ", "ping"], ["ㄇㄧㄝ", "mie"], ["ㄇㄧㄠ", "miao"], ["ㄇㄧㄡ", "miu"],
    ["ㄇㄧㄢ", "mian"], ["ㄇㄧㄣ", "min"], ["ㄇㄧㄥ", "ming"], ["ㄈㄧㄠ", "fiao"], ["ㄈㄨㄥ", "fong"], ["ㄉㄧㄚ", "dia"], ["ㄉㄧㄝ", "die"],
    ["ㄉㄧㄠ", "diao"], ["ㄉㄧㄡ", "diu"], ["ㄉㄧㄢ", "dian"], ["ㄉㄧㄥ", "ding"], ["ㄉㄨㄛ", "duo"], ["ㄉㄨㄟ", "dui"], ["ㄉㄨㄢ", "duan"],
    ["ㄉㄨㄣ", "dun"], ["ㄉㄨㄥ", "dong"], ["ㄊㄧㄝ", "tie"], ["ㄊㄧㄠ", "tiao"], ["ㄊㄧㄢ", "tian"], ["ㄊㄧㄥ", "ting"], ["ㄊㄨㄛ", "tuo"],
    ["ㄊㄨㄟ", "tui"], ["ㄊㄨㄢ", "tuan"], ["ㄊㄨㄣ", "tun"], ["ㄊㄨㄥ", "tong"], ["ㄋㄧㄝ", "nie"], ["ㄋㄧㄠ", "niao"], ["ㄋㄧㄡ", "niu"],
    ["ㄋㄧㄢ", "nian"], ["ㄋㄧㄣ", "nin"], ["ㄋㄧㄤ", "niang"], ["ㄋㄧㄥ", "ning"], ["ㄋㄨㄛ", "nuo"], ["ㄋㄨㄟ", "nui"],
    ["ㄋㄨㄢ", "nuan"], ["ㄋㄨㄣ", "nun"], ["ㄋㄨㄥ", "nong"], ["ㄋㄩㄝ", "nve"], ["ㄌㄧㄚ", "lia"], ["ㄌㄧㄝ", "lie"], ["ㄌㄧㄠ", "liao"],
    ["ㄌㄧㄡ", "liu"], ["ㄌㄧㄢ", "lian"], ["ㄌㄧㄣ", "lin"], ["ㄌㄧㄤ", "liang"], ["ㄌㄧㄥ", "ling"], ["ㄌㄨㄛ", "luo"],
    ["ㄌㄨㄢ", "luan"], ["ㄌㄨㄣ", "lun"], ["ㄌㄨㄥ", "long"], ["ㄌㄩㄝ", "lve"], ["ㄌㄩㄢ", "lvan"], ["ㄍㄧㄠ", "giao"], ["ㄍㄧㄣ", "gin"],
    ["ㄍㄨㄚ", "gua"], ["ㄍㄨㄛ", "guo"], ["ㄍㄨㄜ", "gue"], ["ㄍㄨㄞ", "guai"], ["ㄍㄨㄟ", "gui"], ["ㄍㄨㄢ", "guan"], ["ㄍㄨㄣ", "gun"],
    ["ㄍㄨㄤ", "guang"], ["ㄍㄨㄥ", "gong"], ["ㄎㄧㄡ", "kiu"], ["ㄎㄧㄤ", "kiang"], ["ㄎㄨㄚ", "kua"], ["ㄎㄨㄛ", "kuo"],
    ["ㄎㄨㄞ", "kuai"], ["ㄎㄨㄟ", "kui"], ["ㄎㄨㄢ", "kuan"], ["ㄎㄨㄣ", "kun"], ["ㄎㄨㄤ", "kuang"], ["ㄎㄨㄥ", "kong"],
    ["ㄏㄨㄚ", "hua"], ["ㄏㄨㄛ", "huo"], ["ㄏㄨㄞ", "huai"], ["ㄏㄨㄟ", "hui"], ["ㄏㄨㄢ", "huan"], ["ㄏㄨㄣ", "hun"], ["ㄏㄨㄤ", "huang"],
    ["ㄏㄨㄥ", "hong"], ["ㄐㄧㄚ", "jia"], ["ㄐㄧㄝ", "jie"], ["ㄐㄧㄠ", "jiao"], ["ㄐㄧㄡ", "jiu"], ["ㄐㄧㄢ", "jian"], ["ㄐㄧㄣ", "jin"],
    ["ㄐㄧㄤ", "jiang"], ["ㄐㄧㄥ", "jing"], ["ㄐㄩㄝ", "jue"], ["ㄐㄩㄢ", "juan"], ["ㄐㄩㄣ", "jun"], ["ㄐㄩㄥ", "jiong"],
    ["ㄑㄧㄚ", "qia"], ["ㄑㄧㄝ", "qie"], ["ㄑㄧㄠ", "qiao"], ["ㄑㄧㄡ", "qiu"], ["ㄑㄧㄢ", "qian"], ["ㄑㄧㄣ", "qin"], ["ㄑㄧㄤ", "qiang"],
    ["ㄑㄧㄥ", "qing"], ["ㄑㄩㄝ", "que"], ["ㄑㄩㄢ", "quan"], ["ㄑㄩㄣ", "qun"], ["ㄑㄩㄥ", "qiong"], ["ㄒㄧㄚ", "xia"], ["ㄒㄧㄝ", "xie"],
    ["ㄒㄧㄠ", "xiao"], ["ㄒㄧㄡ", "xiu"], ["ㄒㄧㄢ", "xian"], ["ㄒㄧㄣ", "xin"], ["ㄒㄧㄤ", "xiang"], ["ㄒㄧㄥ", "xing"],
    ["ㄒㄩㄝ", "xue"], ["ㄒㄩㄢ", "xuan"], ["ㄒㄩㄣ", "xun"], ["ㄒㄩㄥ", "xiong"], ["ㄓㄨㄚ", "zhua"], ["ㄓㄨㄛ", "zhuo"],
    ["ㄓㄨㄞ", "zhuai"], ["ㄓㄨㄟ", "zhui"], ["ㄓㄨㄢ", "zhuan"], ["ㄓㄨㄣ", "zhun"], ["ㄓㄨㄤ", "zhuang"], ["ㄓㄨㄥ", "zhong"],
    ["ㄔㄨㄚ", "chua"], ["ㄔㄨㄛ", "chuo"], ["ㄔㄨㄞ", "chuai"], ["ㄔㄨㄟ", "chui"], ["ㄔㄨㄢ", "chuan"], ["ㄔㄨㄣ", "chun"],
    ["ㄔㄨㄤ", "chuang"], ["ㄔㄨㄥ", "chong"], ["ㄕㄨㄚ", "shua"], ["ㄕㄨㄛ", "shuo"], ["ㄕㄨㄞ", "shuai"], ["ㄕㄨㄟ", "shui"],
    ["ㄕㄨㄢ", "shuan"], ["ㄕㄨㄣ", "shun"], ["ㄕㄨㄤ", "shuang"], ["ㄖㄨㄛ", "ruo"], ["ㄖㄨㄟ", "rui"], ["ㄖㄨㄢ", "ruan"],
    ["ㄖㄨㄣ", "run"], ["ㄖㄨㄥ", "rong"], ["ㄗㄨㄛ", "zuo"], ["ㄗㄨㄟ", "zui"], ["ㄗㄨㄢ", "zuan"], ["ㄗㄨㄣ", "zun"], ["ㄗㄨㄥ", "zong"],
    ["ㄘㄨㄛ", "cuo"], ["ㄘㄨㄟ", "cui"], ["ㄘㄨㄢ", "cuan"], ["ㄘㄨㄣ", "cun"], ["ㄘㄨㄥ", "cong"], ["ㄙㄨㄛ", "suo"], ["ㄙㄨㄟ", "sui"],
    ["ㄙㄨㄢ", "suan"], ["ㄙㄨㄣ", "sun"], ["ㄙㄨㄥ", "song"], ["ㄅㄧㄤ", "biang"], ["ㄉㄨㄤ", "duang"],

    ["ㄅㄚ", "ba"], ["ㄅㄛ", "bo"], ["ㄅㄞ", "bai"], ["ㄅㄟ", "bei"], ["ㄅㄠ", "bao"], ["ㄅㄢ", "ban"], ["ㄅㄣ", "ben"],
    ["ㄅㄤ", "bang"], ["ㄅㄥ", "beng"], ["ㄅㄧ", "bi"], ["ㄅㄨ", "bu"], ["ㄆㄚ", "pa"], ["ㄆㄛ", "po"], ["ㄆㄞ", "pai"],
    ["ㄆㄟ", "pei"], ["ㄆㄠ", "pao"], ["ㄆㄡ", "pou"], ["ㄆㄢ", "pan"], ["ㄆㄣ", "pen"], ["ㄆㄤ", "pang"], ["ㄆㄥ", "peng"],
    ["ㄆㄧ", "pi"], ["ㄆㄨ", "pu"], ["ㄇㄚ", "ma"], ["ㄇㄛ", "mo"], ["ㄇㄜ", "me"], ["ㄇㄞ", "mai"], ["ㄇㄟ", "mei"], ["ㄇㄠ", "mao"],
    ["ㄇㄡ", "mou"], ["ㄇㄢ", "man"], ["ㄇㄣ", "men"], ["ㄇㄤ", "mang"], ["ㄇㄥ", "meng"], ["ㄇㄧ", "mi"], ["ㄇㄨ", "mu"],
    ["ㄈㄚ", "fa"], ["ㄈㄛ", "fo"], ["ㄈㄟ", "fei"], ["ㄈㄡ", "fou"], ["ㄈㄢ", "fan"], ["ㄈㄣ", "fen"], ["ㄈㄤ", "fang"],
    ["ㄈㄥ", "feng"], ["ㄈㄨ", "fu"], ["ㄉㄚ", "da"], ["ㄉㄜ", "de"], ["ㄉㄞ", "dai"], ["ㄉㄟ", "dei"], ["ㄉㄠ", "dao"],
    ["ㄉㄡ", "dou"], ["ㄉㄢ", "dan"], ["ㄉㄣ", "den"], ["ㄉㄤ", "dang"], ["ㄉㄥ", "deng"], ["ㄉㄧ", "di"], ["ㄉㄨ", "du"],
    ["ㄊㄚ", "ta"], ["ㄊㄜ", "te"], ["ㄊㄞ", "tai"], ["ㄊㄠ", "tao"], ["ㄊㄡ", "tou"], ["ㄊㄢ", "tan"], ["ㄊㄤ", "tang"],
    ["ㄊㄥ", "teng"], ["ㄊㄧ", "ti"], ["ㄊㄨ", "tu"], ["ㄋㄚ", "na"], ["ㄋㄜ", "ne"], ["ㄋㄞ", "nai"], ["ㄋㄟ", "nei"],
    ["ㄋㄠ", "nao"], ["ㄋㄡ", "nou"], ["ㄋㄢ", "nan"], ["ㄋㄣ", "nen"], ["ㄋㄤ", "nang"], ["ㄋㄥ", "neng"], ["ㄋㄧ", "ni"],
    ["ㄋㄨ", "nu"], ["ㄋㄩ", "nv"], ["ㄌㄚ", "la"], ["ㄌㄛ", "lo"], ["ㄌㄜ", "le"], ["ㄌㄞ", "lai"], ["ㄌㄟ", "lei"], ["ㄌㄠ", "lao"],
    ["ㄌㄡ", "lou"], ["ㄌㄢ", "lan"], ["ㄌㄤ", "lang"], ["ㄌㄥ", "leng"], ["ㄌㄧ", "li"], ["ㄌㄨ", "lu"], ["ㄌㄩ", "lv"],
    ["ㄍㄚ", "ga"], ["ㄍㄜ", "ge"], ["ㄍㄞ", "gai"], ["ㄍㄟ", "gei"], ["ㄍㄠ", "gao"], ["ㄍㄡ", "gou"], ["ㄍㄢ", "gan"],
    ["ㄍㄣ", "gen"], ["ㄍㄤ", "gang"], ["ㄍㄥ", "geng"], ["ㄍㄧ", "gi"], ["ㄍㄨ", "gu"], ["ㄎㄚ", "ka"], ["ㄎㄜ", "ke"],
    ["ㄎㄞ", "kai"], ["ㄎㄠ", "kao"], ["ㄎㄡ", "kou"], ["ㄎㄢ", "kan"], ["ㄎㄣ", "ken"], ["ㄎㄤ", "kang"], ["ㄎㄥ", "keng"],
    ["ㄎㄨ", "ku"], ["ㄏㄚ", "ha"], ["ㄏㄜ", "he"], ["ㄏㄞ", "hai"], ["ㄏㄟ", "hei"], ["ㄏㄠ", "hao"], ["ㄏㄡ", "hou"],
    ["ㄏㄢ", "han"], ["ㄏㄣ", "hen"], ["ㄏㄤ", "hang"], ["ㄏㄥ", "heng"], ["ㄏㄨ", "hu"], ["ㄐㄧ", "ji"], ["ㄐㄩ", "ju"],
    ["ㄑㄧ", "qi"], ["ㄑㄩ", "qu"], ["ㄒㄧ", "xi"], ["ㄒㄩ", "xu"], ["ㄓㄚ", "zha"], ["ㄓㄜ", "zhe"], ["ㄓㄞ", "zhai"],
    ["ㄓㄟ", "zhei"], ["ㄓㄠ", "zhao"], ["ㄓㄡ", "zhou"], ["ㄓㄢ", "zhan"], ["ㄓㄣ", "zhen"], ["ㄓㄤ", "zhang"], ["ㄓㄥ", "zheng"],
    ["ㄓㄨ", "zhu"], ["ㄔㄚ", "cha"], ["ㄔㄜ", "che"], ["ㄔㄞ", "chai"], ["ㄔㄠ", "chao"], ["ㄔㄡ", "chou"], ["ㄔㄢ", "chan"],
    ["ㄔㄣ", "chen"], ["ㄔㄤ", "chang"], ["ㄔㄥ", "cheng"], ["ㄔㄨ", "chu"], ["ㄕㄚ", "sha"], ["ㄕㄜ", "she"], ["ㄕㄞ", "shai"],
    ["ㄕㄟ", "shei"], ["ㄕㄠ", "shao"], ["ㄕㄡ", "shou"], ["ㄕㄢ", "shan"], ["ㄕㄣ", "shen"], ["ㄕㄤ", "shang"], ["ㄕㄥ", "sheng"],
    ["ㄕㄨ", "shu"], ["ㄖㄜ", "re"], ["ㄖㄠ", "rao"], ["ㄖㄡ", "rou"], ["ㄖㄢ", "ran"], ["ㄖㄣ", "ren"], ["ㄖㄤ", "rang"],
    ["ㄖㄥ", "reng"], ["ㄖㄨ", "ru"], ["ㄗㄚ", "za"], ["ㄗㄜ", "ze"], ["ㄗㄞ", "zai"], ["ㄗㄟ", "zei"], ["ㄗㄠ", "zao"],
    ["ㄗㄡ", "zou"], ["ㄗㄢ", "zan"], ["ㄗㄣ", "zen"], ["ㄗㄤ", "zang"], ["ㄗㄥ", "zeng"], ["ㄗㄨ", "zu"], ["ㄘㄚ", "ca"],
    ["ㄘㄜ", "ce"], ["ㄘㄞ", "cai"], ["ㄘㄟ", "cei"], ["ㄘㄠ", "cao"], ["ㄘㄡ", "cou"], ["ㄘㄢ", "can"], ["ㄘㄣ", "cen"],
    ["ㄘㄤ", "cang"], ["ㄘㄥ", "ceng"], ["ㄘㄨ", "cu"], ["ㄙㄚ", "sa"], ["ㄙㄜ", "se"], ["ㄙㄞ", "sai"], ["ㄙㄟ", "sei"],
    ["ㄙㄠ", "sao"], ["ㄙㄡ", "sou"], ["ㄙㄢ", "san"], ["ㄙㄣ", "sen"], ["ㄙㄤ", "sang"], ["ㄙㄥ", "seng"], ["ㄙㄨ", "su"],
    ["ㄧㄚ", "ya"], ["ㄧㄛ", "yo"], ["ㄧㄝ", "ye"], ["ㄧㄞ", "yai"], ["ㄧㄠ", "yao"], ["ㄧㄡ", "you"], ["ㄧㄢ", "yan"],
    ["ㄧㄣ", "yin"], ["ㄧㄤ", "yang"], ["ㄧㄥ", "ying"], ["ㄨㄚ", "wa"], ["ㄨㄛ", "wo"], ["ㄨㄞ", "wai"], ["ㄨㄟ", "wei"],
    ["ㄨㄢ", "wan"], ["ㄨㄣ", "wen"], ["ㄨㄤ", "wang"], ["ㄨㄥ", "weng"], ["ㄩㄝ", "yue"], ["ㄩㄢ", "yuan"], ["ㄩㄣ", "yun"],
    ["ㄩㄥ", "yong"],

    ["ㄅ", "b"], ["ㄆ", "p"], ["ㄇ", "m"], ["ㄈ", "f"], ["ㄉ", "d"], ["ㄊ", "t"], ["ㄋ", "n"],
    ["ㄌ", "l"], ["ㄍ", "g"], ["ㄎ", "k"], ["ㄏ", "h"], ["ㄐ", "j"], ["ㄑ", "q"], ["ㄒ", "x"], ["ㄓ", "zhi"], ["ㄔ", "chi"],
    ["ㄕ", "shi"], ["ㄖ", "ri"], ["ㄗ", "zi"], ["ㄘ", "ci"], ["ㄙ", "si"], ["ㄚ", "a"], ["ㄛ", "o"], ["ㄜ", "e"], ["ㄝ", "eh"],
    ["ㄞ", "ai"], ["ㄟ", "ei"], ["ㄠ", "ao"], ["ㄡ", "ou"], ["ㄢ", "an"], ["ㄣ", "en"], ["ㄤ", "ang"], ["ㄥ", "eng"],
    ["ㄦ", "er"], ["ㄧ", "yi"], ["ㄨ", "wu"], ["ㄩ", "yu"],
  ]

  /// 漢語拼音韻母轉換對照表資料貯存專用佇列
  static let arrHanyuPinyinTextbookStyleConversionTable = [  // 排序很重要。先處理最長的，再處理短的。不然會出亂子。
    ["iang1", "iāng"], ["iang2", "iáng"], ["iang3", "iǎng"], ["iang4", "iàng"], ["iong1", "iōng"], ["iong2", "ióng"],
    ["iong3", "iǒng"], ["iong4", "iòng"], ["uang1", "uāng"], ["uang2", "uáng"], ["uang3", "uǎng"], ["uang4", "uàng"],
    ["uang5", "uang"],

    ["ang1", "āng"], ["ang2", "áng"], ["ang3", "ǎng"], ["ang4", "àng"], ["ang5", "ang"], ["eng1", "ēng"],
    ["eng2", "éng"], ["eng3", "ěng"], ["eng4", "èng"], ["ian1", "iān"], ["ian2", "ián"], ["ian3", "iǎn"],
    ["ian4", "iàn"], ["iao1", "iāo"], ["iao2", "iáo"], ["iao3", "iǎo"], ["iao4", "iào"], ["ing1", "īng"],
    ["ing2", "íng"], ["ing3", "ǐng"], ["ing4", "ìng"], ["ong1", "ōng"], ["ong2", "óng"], ["ong3", "ǒng"],
    ["ong4", "òng"], ["uai1", "uāi"], ["uai2", "uái"], ["uai3", "uǎi"], ["uai4", "uài"], ["uan1", "uān"],
    ["uan2", "uán"], ["uan3", "uǎn"], ["uan4", "uàn"], ["van2", "üán"], ["van3", "üǎn"],

    ["ai1", "āi"], ["ai2", "ái"], ["ai3", "ǎi"], ["ai4", "ài"], ["ai5", "ai"], ["an1", "ān"], ["an2", "án"],
    ["an3", "ǎn"], ["an4", "àn"], ["ao1", "āo"], ["ao2", "áo"], ["ao3", "ǎo"], ["ao4", "ào"], ["ao5", "ao"],
    ["eh2", "ế"], ["eh3", "êˇ"], ["eh4", "ề"], ["eh5", "ê"], ["ei1", "ēi"], ["ei2", "éi"], ["ei3", "ěi"],
    ["ei4", "èi"], ["ei5", "ei"], ["en1", "ēn"], ["en2", "én"], ["en3", "ěn"], ["en4", "èn"], ["en5", "en"],
    ["er1", "ēr"], ["er2", "ér"], ["er3", "ěr"], ["er4", "èr"], ["er5", "er"], ["ia1", "iā"], ["ia2", "iá"],
    ["ia3", "iǎ"], ["ia4", "ià"], ["ie1", "iē"], ["ie2", "ié"], ["ie3", "iě"], ["ie4", "iè"], ["ie5", "ie"],
    ["in1", "īn"], ["in2", "ín"], ["in3", "ǐn"], ["in4", "ìn"], ["iu1", "iū"], ["iu2", "iú"], ["iu3", "iǔ"],
    ["iu4", "iù"], ["ou1", "ōu"], ["ou2", "óu"], ["ou3", "ǒu"], ["ou4", "òu"], ["ou5", "ou"], ["ua1", "uā"],
    ["ua2", "uá"], ["ua3", "uǎ"], ["ua4", "uà"], ["ue1", "uē"], ["ue2", "ué"], ["ue3", "uě"], ["ue4", "uè"],
    ["ui1", "uī"], ["ui2", "uí"], ["ui3", "uǐ"], ["ui4", "uì"], ["un1", "ūn"], ["un2", "ún"], ["un3", "ǔn"],
    ["un4", "ùn"], ["uo1", "uō"], ["uo2", "uó"], ["uo3", "uǒ"], ["uo4", "uò"], ["uo5", "uo"], ["ve1", "üē"],
    ["ve3", "üě"], ["ve4", "üè"],

    ["a1", "ā"], ["a2", "á"], ["a3", "ǎ"], ["a4", "à"], ["a5", "a"], ["e1", "ē"], ["e2", "é"], ["e3", "ě"],
    ["e4", "è"], ["e5", "e"], ["i1", "ī"], ["i2", "í"], ["i3", "ǐ"], ["i4", "ì"], ["i5", "i"], ["o1", "ō"],
    ["o2", "ó"], ["o3", "ǒ"], ["o4", "ò"], ["o5", "o"], ["u1", "ū"], ["u2", "ú"], ["u3", "ǔ"], ["u4", "ù"],
    ["v1", "ǖ"], ["v2", "ǘ"], ["v3", "ǚ"], ["v4", "ǜ"],
  ]

  // MARK: - Maps for Keyboard-to-Pinyin parsers

  /// 任何形式的拼音排列都會用到的陣列，用 Strings 反而省事一些。
  /// 這裡同時兼容大千注音的調號數字，所以也將 6、7 號數字鍵放在允許範圍內。
  static let mapArayuruPinyin: String = "abcdefghijklmnopqrstuvwxyz1234567 "

  /// 任何拼音都會用到的聲調鍵陣列
  static let mapArayuruPinyinIntonation: [String: String] = [
    "1": " ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙", "6": "ˊ", "7": "˙", " ": " ",
  ]
  /// 漢語拼音排列專用處理陣列
  static let mapHanyuPinyin: [String: String] = [
    "chuang": "ㄔㄨㄤ", "shuang": "ㄕㄨㄤ", "zhuang": "ㄓㄨㄤ",
    "chang": "ㄔㄤ", "cheng": "ㄔㄥ", "chong": "ㄔㄨㄥ", "chuai": "ㄔㄨㄞ", "chuan": "ㄔㄨㄢ", "guang": "ㄍㄨㄤ", "huang": "ㄏㄨㄤ",
    "jiang": "ㄐㄧㄤ", "jiong": "ㄐㄩㄥ", "kiang": "ㄎㄧㄤ", "kuang": "ㄎㄨㄤ", "biang": "ㄅㄧㄤ", "duang": "ㄉㄨㄤ", "liang": "ㄌㄧㄤ",
    "niang": "ㄋㄧㄤ", "qiang": "ㄑㄧㄤ", "qiong": "ㄑㄩㄥ", "shang": "ㄕㄤ", "sheng": "ㄕㄥ", "shuai": "ㄕㄨㄞ", "shuan": "ㄕㄨㄢ",
    "xiang": "ㄒㄧㄤ", "xiong": "ㄒㄩㄥ", "zhang": "ㄓㄤ", "zheng": "ㄓㄥ", "zhong": "ㄓㄨㄥ", "zhuai": "ㄓㄨㄞ", "zhuan": "ㄓㄨㄢ",
    "bang": "ㄅㄤ", "beng": "ㄅㄥ", "bian": "ㄅㄧㄢ", "biao": "ㄅㄧㄠ", "bing": "ㄅㄧㄥ", "cang": "ㄘㄤ", "ceng": "ㄘㄥ", "chai": "ㄔㄞ",
    "chan": "ㄔㄢ", "chao": "ㄔㄠ", "chen": "ㄔㄣ", "chou": "ㄔㄡ", "chua": "ㄔㄨㄚ", "chui": "ㄔㄨㄟ", "chun": "ㄔㄨㄣ", "chuo": "ㄔㄨㄛ",
    "cong": "ㄘㄨㄥ", "cuan": "ㄘㄨㄢ", "dang": "ㄉㄤ", "deng": "ㄉㄥ", "dian": "ㄉㄧㄢ", "diao": "ㄉㄧㄠ", "ding": "ㄉㄧㄥ",
    "dong": "ㄉㄨㄥ", "duan": "ㄉㄨㄢ", "fang": "ㄈㄤ", "feng": "ㄈㄥ", "fiao": "ㄈㄧㄠ", "fong": "ㄈㄨㄥ", "gang": "ㄍㄤ", "geng": "ㄍㄥ",
    "giao": "ㄍㄧㄠ", "gong": "ㄍㄨㄥ", "guai": "ㄍㄨㄞ", "guan": "ㄍㄨㄢ", "hang": "ㄏㄤ", "heng": "ㄏㄥ", "hong": "ㄏㄨㄥ",
    "huai": "ㄏㄨㄞ", "huan": "ㄏㄨㄢ", "jian": "ㄐㄧㄢ", "jiao": "ㄐㄧㄠ", "jing": "ㄐㄧㄥ", "juan": "ㄐㄩㄢ", "kang": "ㄎㄤ",
    "keng": "ㄎㄥ", "kong": "ㄎㄨㄥ", "kuai": "ㄎㄨㄞ", "kuan": "ㄎㄨㄢ", "lang": "ㄌㄤ", "leng": "ㄌㄥ", "lian": "ㄌㄧㄢ", "liao": "ㄌㄧㄠ",
    "ling": "ㄌㄧㄥ", "long": "ㄌㄨㄥ", "luan": "ㄌㄨㄢ", "lvan": "ㄌㄩㄢ", "mang": "ㄇㄤ", "meng": "ㄇㄥ", "mian": "ㄇㄧㄢ",
    "miao": "ㄇㄧㄠ", "ming": "ㄇㄧㄥ", "nang": "ㄋㄤ", "neng": "ㄋㄥ", "nian": "ㄋㄧㄢ", "niao": "ㄋㄧㄠ", "ning": "ㄋㄧㄥ",
    "nong": "ㄋㄨㄥ", "nuan": "ㄋㄨㄢ", "pang": "ㄆㄤ", "peng": "ㄆㄥ", "pian": "ㄆㄧㄢ", "piao": "ㄆㄧㄠ", "ping": "ㄆㄧㄥ",
    "qian": "ㄑㄧㄢ", "qiao": "ㄑㄧㄠ", "qing": "ㄑㄧㄥ", "quan": "ㄑㄩㄢ", "rang": "ㄖㄤ", "reng": "ㄖㄥ", "rong": "ㄖㄨㄥ",
    "ruan": "ㄖㄨㄢ", "sang": "ㄙㄤ", "seng": "ㄙㄥ", "shai": "ㄕㄞ", "shan": "ㄕㄢ", "shao": "ㄕㄠ", "shei": "ㄕㄟ", "shen": "ㄕㄣ",
    "shou": "ㄕㄡ", "shua": "ㄕㄨㄚ", "shui": "ㄕㄨㄟ", "shun": "ㄕㄨㄣ", "shuo": "ㄕㄨㄛ", "song": "ㄙㄨㄥ", "suan": "ㄙㄨㄢ",
    "tang": "ㄊㄤ", "teng": "ㄊㄥ", "tian": "ㄊㄧㄢ", "tiao": "ㄊㄧㄠ", "ting": "ㄊㄧㄥ", "tong": "ㄊㄨㄥ", "tuan": "ㄊㄨㄢ", "wang": "ㄨㄤ",
    "weng": "ㄨㄥ", "xian": "ㄒㄧㄢ", "xiao": "ㄒㄧㄠ", "xing": "ㄒㄧㄥ", "xuan": "ㄒㄩㄢ", "yang": "ㄧㄤ", "ying": "ㄧㄥ", "yong": "ㄩㄥ",
    "yuan": "ㄩㄢ", "zang": "ㄗㄤ", "zeng": "ㄗㄥ", "zhai": "ㄓㄞ", "zhan": "ㄓㄢ", "zhao": "ㄓㄠ", "zhei": "ㄓㄟ", "zhen": "ㄓㄣ",
    "zhou": "ㄓㄡ", "zhua": "ㄓㄨㄚ", "zhui": "ㄓㄨㄟ", "zhun": "ㄓㄨㄣ", "zhuo": "ㄓㄨㄛ", "zong": "ㄗㄨㄥ", "zuan": "ㄗㄨㄢ",
    "jun": "ㄐㄩㄣ", "ang": "ㄤ", "bai": "ㄅㄞ", "ban": "ㄅㄢ", "bao": "ㄅㄠ", "bei": "ㄅㄟ", "ben": "ㄅㄣ", "bie": "ㄅㄧㄝ",
    "bin": "ㄅㄧㄣ", "cai": "ㄘㄞ", "can": "ㄘㄢ", "cao": "ㄘㄠ", "cei": "ㄘㄟ", "cen": "ㄘㄣ", "cha": "ㄔㄚ", "che": "ㄔㄜ", "chi": "ㄔ",
    "chu": "ㄔㄨ", "cou": "ㄘㄡ", "cui": "ㄘㄨㄟ", "cun": "ㄘㄨㄣ", "cuo": "ㄘㄨㄛ", "dai": "ㄉㄞ", "dan": "ㄉㄢ", "dao": "ㄉㄠ",
    "dei": "ㄉㄟ", "den": "ㄉㄣ", "dia": "ㄉㄧㄚ", "die": "ㄉㄧㄝ", "diu": "ㄉㄧㄡ", "dou": "ㄉㄡ", "dui": "ㄉㄨㄟ", "dun": "ㄉㄨㄣ",
    "duo": "ㄉㄨㄛ", "eng": "ㄥ", "fan": "ㄈㄢ", "fei": "ㄈㄟ", "fen": "ㄈㄣ", "fou": "ㄈㄡ", "gai": "ㄍㄞ", "gan": "ㄍㄢ", "gao": "ㄍㄠ",
    "gei": "ㄍㄟ", "gin": "ㄍㄧㄣ", "gen": "ㄍㄣ", "gou": "ㄍㄡ", "gua": "ㄍㄨㄚ", "gue": "ㄍㄨㄜ", "gui": "ㄍㄨㄟ", "gun": "ㄍㄨㄣ",
    "guo": "ㄍㄨㄛ", "hai": "ㄏㄞ", "han": "ㄏㄢ", "hao": "ㄏㄠ", "hei": "ㄏㄟ", "hen": "ㄏㄣ", "hou": "ㄏㄡ", "hua": "ㄏㄨㄚ",
    "hui": "ㄏㄨㄟ", "hun": "ㄏㄨㄣ", "huo": "ㄏㄨㄛ", "jia": "ㄐㄧㄚ", "jie": "ㄐㄧㄝ", "jin": "ㄐㄧㄣ", "jiu": "ㄐㄧㄡ", "jue": "ㄐㄩㄝ",
    "kai": "ㄎㄞ", "kan": "ㄎㄢ", "kao": "ㄎㄠ", "ken": "ㄎㄣ", "kiu": "ㄎㄧㄡ", "kou": "ㄎㄡ", "kua": "ㄎㄨㄚ", "kui": "ㄎㄨㄟ",
    "kun": "ㄎㄨㄣ", "kuo": "ㄎㄨㄛ", "lai": "ㄌㄞ", "lan": "ㄌㄢ", "lao": "ㄌㄠ", "lei": "ㄌㄟ", "lia": "ㄌㄧㄚ", "lie": "ㄌㄧㄝ",
    "lin": "ㄌㄧㄣ", "liu": "ㄌㄧㄡ", "lou": "ㄌㄡ", "lun": "ㄌㄨㄣ", "luo": "ㄌㄨㄛ", "lve": "ㄌㄩㄝ", "mai": "ㄇㄞ", "man": "ㄇㄢ",
    "mao": "ㄇㄠ", "mei": "ㄇㄟ", "men": "ㄇㄣ", "mie": "ㄇㄧㄝ", "min": "ㄇㄧㄣ", "miu": "ㄇㄧㄡ", "mou": "ㄇㄡ", "nai": "ㄋㄞ",
    "nan": "ㄋㄢ", "nao": "ㄋㄠ", "nei": "ㄋㄟ", "nen": "ㄋㄣ", "nie": "ㄋㄧㄝ", "nin": "ㄋㄧㄣ", "niu": "ㄋㄧㄡ", "nou": "ㄋㄡ",
    "nui": "ㄋㄨㄟ", "nun": "ㄋㄨㄣ", "nuo": "ㄋㄨㄛ", "nve": "ㄋㄩㄝ", "pai": "ㄆㄞ", "pan": "ㄆㄢ", "pao": "ㄆㄠ", "pei": "ㄆㄟ",
    "pen": "ㄆㄣ", "pia": "ㄆㄧㄚ", "pie": "ㄆㄧㄝ", "pin": "ㄆㄧㄣ", "pou": "ㄆㄡ", "qia": "ㄑㄧㄚ", "qie": "ㄑㄧㄝ", "qin": "ㄑㄧㄣ",
    "qiu": "ㄑㄧㄡ", "que": "ㄑㄩㄝ", "qun": "ㄑㄩㄣ", "ran": "ㄖㄢ", "rao": "ㄖㄠ", "ren": "ㄖㄣ", "rou": "ㄖㄡ", "rui": "ㄖㄨㄟ",
    "run": "ㄖㄨㄣ", "ruo": "ㄖㄨㄛ", "sai": "ㄙㄞ", "san": "ㄙㄢ", "sao": "ㄙㄠ", "sei": "ㄙㄟ", "sen": "ㄙㄣ", "sha": "ㄕㄚ",
    "she": "ㄕㄜ", "shi": "ㄕ", "shu": "ㄕㄨ", "sou": "ㄙㄡ", "sui": "ㄙㄨㄟ", "sun": "ㄙㄨㄣ", "suo": "ㄙㄨㄛ", "tai": "ㄊㄞ",
    "tan": "ㄊㄢ", "tao": "ㄊㄠ", "tie": "ㄊㄧㄝ", "tou": "ㄊㄡ", "tui": "ㄊㄨㄟ", "tun": "ㄊㄨㄣ", "tuo": "ㄊㄨㄛ", "wai": "ㄨㄞ",
    "wan": "ㄨㄢ", "wei": "ㄨㄟ", "wen": "ㄨㄣ", "xia": "ㄒㄧㄚ", "xie": "ㄒㄧㄝ", "xin": "ㄒㄧㄣ", "xiu": "ㄒㄧㄡ", "xue": "ㄒㄩㄝ",
    "xun": "ㄒㄩㄣ", "yai": "ㄧㄞ", "yan": "ㄧㄢ", "yao": "ㄧㄠ", "yin": "ㄧㄣ", "you": "ㄧㄡ", "yue": "ㄩㄝ", "yun": "ㄩㄣ",
    "zai": "ㄗㄞ", "zan": "ㄗㄢ", "zao": "ㄗㄠ", "zei": "ㄗㄟ", "zen": "ㄗㄣ", "zha": "ㄓㄚ", "zhe": "ㄓㄜ", "zhi": "ㄓ", "zhu": "ㄓㄨ",
    "zou": "ㄗㄡ", "zui": "ㄗㄨㄟ", "zun": "ㄗㄨㄣ", "zuo": "ㄗㄨㄛ",
    "ai": "ㄞ", "an": "ㄢ", "ao": "ㄠ", "ba": "ㄅㄚ", "bi": "ㄅㄧ", "bo": "ㄅㄛ", "bu": "ㄅㄨ", "ca": "ㄘㄚ", "ce": "ㄘㄜ", "ci": "ㄘ",
    "cu": "ㄘㄨ", "da": "ㄉㄚ", "de": "ㄉㄜ", "di": "ㄉㄧ", "du": "ㄉㄨ", "eh": "ㄝ", "ei": "ㄟ", "en": "ㄣ", "er": "ㄦ", "fa": "ㄈㄚ",
    "fo": "ㄈㄛ", "fu": "ㄈㄨ", "ga": "ㄍㄚ", "ge": "ㄍㄜ", "gi": "ㄍㄧ", "gu": "ㄍㄨ", "ha": "ㄏㄚ", "he": "ㄏㄜ", "hu": "ㄏㄨ",
    "ji": "ㄐㄧ", "ju": "ㄐㄩ", "ka": "ㄎㄚ", "ke": "ㄎㄜ", "ku": "ㄎㄨ", "la": "ㄌㄚ", "le": "ㄌㄜ", "li": "ㄌㄧ", "lo": "ㄌㄛ",
    "lu": "ㄌㄨ", "lv": "ㄌㄩ", "ma": "ㄇㄚ", "me": "ㄇㄜ", "mi": "ㄇㄧ", "mo": "ㄇㄛ", "mu": "ㄇㄨ", "na": "ㄋㄚ", "ne": "ㄋㄜ",
    "ni": "ㄋㄧ", "nu": "ㄋㄨ", "nv": "ㄋㄩ", "ou": "ㄡ", "pa": "ㄆㄚ", "pi": "ㄆㄧ", "po": "ㄆㄛ", "pu": "ㄆㄨ", "qi": "ㄑㄧ",
    "qu": "ㄑㄩ", "re": "ㄖㄜ", "ri": "ㄖ", "ru": "ㄖㄨ", "sa": "ㄙㄚ", "se": "ㄙㄜ", "si": "ㄙ", "su": "ㄙㄨ", "ta": "ㄊㄚ",
    "te": "ㄊㄜ", "ti": "ㄊㄧ", "tu": "ㄊㄨ", "wa": "ㄨㄚ", "wo": "ㄨㄛ", "wu": "ㄨ", "xi": "ㄒㄧ", "xu": "ㄒㄩ", "ya": "ㄧㄚ",
    "ye": "ㄧㄝ", "yi": "ㄧ", "yo": "ㄧㄛ", "yu": "ㄩ", "za": "ㄗㄚ", "ze": "ㄗㄜ", "zi": "ㄗ", "zu": "ㄗㄨ",
    "a": "ㄚ", "e": "ㄜ", "o": "ㄛ", "q": "ㄑ",
  ]

  /// 國音二式排列專用處理陣列
  static let mapSecondaryPinyin: [String: String] = [
    "chuang": "ㄔㄨㄤ", "shuang": "ㄕㄨㄤ", "chiang": "ㄑㄧㄤ", "chiung": "ㄑㄩㄥ", "chiuan": "ㄑㄩㄢ", "shiang": "ㄒㄧㄤ",
    "shiung": "ㄒㄩㄥ", "shiuan": "ㄒㄩㄢ",
    "biang": "ㄅㄧㄤ", "duang": "ㄉㄨㄤ", "juang": "ㄓㄨㄤ", "jiang": "ㄐㄧㄤ", "jiung": "ㄐㄩㄥ", "niang": "ㄋㄧㄤ", "liang": "ㄌㄧㄤ",
    "guang": "ㄍㄨㄤ", "kuang": "ㄎㄨㄤ", "huang": "ㄏㄨㄤ", "chang": "ㄔㄤ", "cheng": "ㄔㄥ", "chuai": "ㄔㄨㄞ", "chuan": "ㄔㄨㄢ",
    "chung": "ㄔㄨㄥ", "shang": "ㄕㄤ", "sheng": "ㄕㄥ", "shuai": "ㄕㄨㄞ", "shuan": "ㄕㄨㄢ", "jiuan": "ㄐㄩㄢ", "chiau": "ㄑㄧㄠ",
    "chian": "ㄑㄧㄢ", "ching": "ㄑㄧㄥ", "shing": "ㄒㄧㄥ", "tzang": "ㄗㄤ", "tzeng": "ㄗㄥ", "tzuan": "ㄗㄨㄢ", "tzung": "ㄗㄨㄥ",
    "tsang": "ㄘㄤ", "tseng": "ㄘㄥ", "tsuan": "ㄘㄨㄢ", "tsung": "ㄘㄨㄥ", "chiue": "ㄑㄩㄝ", "liuan": "ㄌㄩㄢ", "chuei": "ㄔㄨㄟ",
    "chuen": "ㄔㄨㄣ", "shuei": "ㄕㄨㄟ", "shuen": "ㄕㄨㄣ", "chiou": "ㄑㄧㄡ", "chiun": "ㄑㄩㄣ", "tzuei": "ㄗㄨㄟ", "tzuen": "ㄗㄨㄣ",
    "tsuei": "ㄘㄨㄟ", "tsuen": "ㄘㄨㄣ", "kiang": "ㄎㄧㄤ", "shiau": "ㄒㄧㄠ", "shian": "ㄒㄧㄢ", "shiue": "ㄒㄩㄝ", "shiou": "ㄒㄧㄡ",
    "shiun": "ㄒㄩㄣ",
    "jang": "ㄓㄤ", "jeng": "ㄓㄥ", "juai": "ㄓㄨㄞ", "juan": "ㄓㄨㄢ", "jung": "ㄓㄨㄥ", "jiau": "ㄐㄧㄠ", "jian": "ㄐㄧㄢ",
    "jing": "ㄐㄧㄥ", "jiue": "ㄐㄩㄝ", "chie": "ㄑㄧㄝ", "bang": "ㄅㄤ", "beng": "ㄅㄥ", "biau": "ㄅㄧㄠ", "bian": "ㄅㄧㄢ",
    "bing": "ㄅㄧㄥ", "pang": "ㄆㄤ", "peng": "ㄆㄥ", "piau": "ㄆㄧㄠ", "pian": "ㄆㄧㄢ", "ping": "ㄆㄧㄥ", "mang": "ㄇㄤ", "meng": "ㄇㄥ",
    "miau": "ㄇㄧㄠ", "mian": "ㄇㄧㄢ", "ming": "ㄇㄧㄥ", "fang": "ㄈㄤ", "feng": "ㄈㄥ", "fiau": "ㄈㄧㄠ", "dang": "ㄉㄤ", "deng": "ㄉㄥ",
    "diau": "ㄉㄧㄠ", "dian": "ㄉㄧㄢ", "ding": "ㄉㄧㄥ", "duan": "ㄉㄨㄢ", "dung": "ㄉㄨㄥ", "tang": "ㄊㄤ", "teng": "ㄊㄥ",
    "tiau": "ㄊㄧㄠ", "tian": "ㄊㄧㄢ", "ting": "ㄊㄧㄥ", "tuan": "ㄊㄨㄢ", "tung": "ㄊㄨㄥ", "nang": "ㄋㄤ", "neng": "ㄋㄥ",
    "niau": "ㄋㄧㄠ", "nian": "ㄋㄧㄢ", "ning": "ㄋㄧㄥ", "nuan": "ㄋㄨㄢ", "nung": "ㄋㄨㄥ", "lang": "ㄌㄤ", "leng": "ㄌㄥ",
    "liau": "ㄌㄧㄠ", "lian": "ㄌㄧㄢ", "ling": "ㄌㄧㄥ", "luan": "ㄌㄨㄢ", "lung": "ㄌㄨㄥ", "gang": "ㄍㄤ", "geng": "ㄍㄥ",
    "guai": "ㄍㄨㄞ", "guan": "ㄍㄨㄢ", "gung": "ㄍㄨㄥ", "kang": "ㄎㄤ", "keng": "ㄎㄥ", "kuai": "ㄎㄨㄞ", "kuan": "ㄎㄨㄢ",
    "kung": "ㄎㄨㄥ", "hang": "ㄏㄤ", "heng": "ㄏㄥ", "huai": "ㄏㄨㄞ", "huan": "ㄏㄨㄢ", "hung": "ㄏㄨㄥ", "juei": "ㄓㄨㄟ",
    "juen": "ㄓㄨㄣ", "chai": "ㄔㄞ", "chau": "ㄔㄠ", "chou": "ㄔㄡ", "chan": "ㄔㄢ", "chen": "ㄔㄣ", "chua": "ㄔㄨㄚ", "shai": "ㄕㄞ",
    "shei": "ㄕㄟ", "shau": "ㄕㄠ", "shou": "ㄕㄡ", "shan": "ㄕㄢ", "shen": "ㄕㄣ", "shua": "ㄕㄨㄚ", "shuo": "ㄕㄨㄛ", "rang": "ㄖㄤ",
    "reng": "ㄖㄥ", "ruan": "ㄖㄨㄢ", "rung": "ㄖㄨㄥ", "sang": "ㄙㄤ", "seng": "ㄙㄥ", "suan": "ㄙㄨㄢ", "sung": "ㄙㄨㄥ", "yang": "ㄧㄤ",
    "ying": "ㄧㄥ", "wang": "ㄨㄤ", "weng": "ㄨㄥ", "yuan": "ㄩㄢ", "yung": "ㄩㄥ", "niue": "ㄋㄩㄝ", "liue": "ㄌㄩㄝ", "guei": "ㄍㄨㄟ",
    "kuei": "ㄎㄨㄟ", "jiou": "ㄐㄧㄡ", "jiun": "ㄐㄩㄣ", "chia": "ㄑㄧㄚ", "chin": "ㄑㄧㄣ", "shin": "ㄒㄧㄣ", "tzai": "ㄗㄞ",
    "tzei": "ㄗㄟ", "tzau": "ㄗㄠ", "tzou": "ㄗㄡ", "tzan": "ㄗㄢ", "tzen": "ㄗㄣ", "tsai": "ㄘㄞ", "tsau": "ㄘㄠ", "tsou": "ㄘㄡ",
    "tsan": "ㄘㄢ", "tsen": "ㄘㄣ", "chuo": "ㄔㄨㄛ", "miou": "ㄇㄧㄡ", "diou": "ㄉㄧㄡ", "duei": "ㄉㄨㄟ", "duen": "ㄉㄨㄣ",
    "tuei": "ㄊㄨㄟ", "tuen": "ㄊㄨㄣ", "niou": "ㄋㄧㄡ", "nuei": "ㄋㄨㄟ", "nuen": "ㄋㄨㄣ", "liou": "ㄌㄧㄡ", "luen": "ㄌㄨㄣ",
    "guen": "ㄍㄨㄣ", "kuen": "ㄎㄨㄣ", "huei": "ㄏㄨㄟ", "huen": "ㄏㄨㄣ", "ruei": "ㄖㄨㄟ", "ruen": "ㄖㄨㄣ", "tzuo": "ㄗㄨㄛ",
    "tsuo": "ㄘㄨㄛ", "suei": "ㄙㄨㄟ", "suen": "ㄙㄨㄣ", "chiu": "ㄑㄩ", "giau": "ㄍㄧㄠ", "shie": "ㄒㄧㄝ", "shia": "ㄒㄧㄚ",
    "shiu": "ㄒㄩ",
    "jie": "ㄐㄧㄝ", "jai": "ㄓㄞ", "jei": "ㄓㄟ", "jau": "ㄓㄠ", "jou": "ㄓㄡ", "jan": "ㄓㄢ", "jen": "ㄓㄣ", "jua": "ㄓㄨㄚ",
    "bie": "ㄅㄧㄝ", "pie": "ㄆㄧㄝ", "mie": "ㄇㄧㄝ", "die": "ㄉㄧㄝ", "tie": "ㄊㄧㄝ", "nie": "ㄋㄧㄝ", "lie": "ㄌㄧㄝ", "jia": "ㄐㄧㄚ",
    "jin": "ㄐㄧㄣ", "chr": "ㄔ", "shr": "ㄕ", "yue": "ㄩㄝ", "juo": "ㄓㄨㄛ", "bai": "ㄅㄞ", "bei": "ㄅㄟ", "bau": "ㄅㄠ", "ban": "ㄅㄢ",
    "ben": "ㄅㄣ", "bin": "ㄅㄧㄣ", "pai": "ㄆㄞ", "pei": "ㄆㄟ", "pau": "ㄆㄠ", "pou": "ㄆㄡ", "pan": "ㄆㄢ", "pen": "ㄆㄣ",
    "pia": "ㄆㄧㄚ", "pin": "ㄆㄧㄣ", "mai": "ㄇㄞ", "mei": "ㄇㄟ", "mau": "ㄇㄠ", "mou": "ㄇㄡ", "man": "ㄇㄢ", "men": "ㄇㄣ",
    "min": "ㄇㄧㄣ", "fei": "ㄈㄟ", "fou": "ㄈㄡ", "fan": "ㄈㄢ", "fen": "ㄈㄣ", "dai": "ㄉㄞ", "dei": "ㄉㄟ", "dau": "ㄉㄠ",
    "dou": "ㄉㄡ", "dan": "ㄉㄢ", "den": "ㄉㄣ", "dia": "ㄉㄧㄚ", "tai": "ㄊㄞ", "tau": "ㄊㄠ", "tou": "ㄊㄡ", "tan": "ㄊㄢ",
    "nai": "ㄋㄞ", "nei": "ㄋㄟ", "nau": "ㄋㄠ", "nou": "ㄋㄡ", "nan": "ㄋㄢ", "nen": "ㄋㄣ", "nin": "ㄋㄧㄣ", "lai": "ㄌㄞ",
    "lei": "ㄌㄟ", "lau": "ㄌㄠ", "lou": "ㄌㄡ", "lan": "ㄌㄢ", "lia": "ㄌㄧㄚ", "lin": "ㄌㄧㄣ", "gai": "ㄍㄞ", "gei": "ㄍㄟ",
    "gau": "ㄍㄠ", "gou": "ㄍㄡ", "gan": "ㄍㄢ", "gen": "ㄍㄣ", "gua": "ㄍㄨㄚ", "guo": "ㄍㄨㄛ", "gue": "ㄍㄨㄜ", "kai": "ㄎㄞ",
    "kau": "ㄎㄠ", "kou": "ㄎㄡ", "kan": "ㄎㄢ", "ken": "ㄎㄣ", "kua": "ㄎㄨㄚ", "kuo": "ㄎㄨㄛ", "hai": "ㄏㄞ", "hei": "ㄏㄟ",
    "hau": "ㄏㄠ", "hou": "ㄏㄡ", "han": "ㄏㄢ", "hen": "ㄏㄣ", "hua": "ㄏㄨㄚ", "huo": "ㄏㄨㄛ", "cha": "ㄔㄚ", "che": "ㄔㄜ",
    "chu": "ㄔㄨ", "sha": "ㄕㄚ", "she": "ㄕㄜ", "shu": "ㄕㄨ", "rau": "ㄖㄠ", "rou": "ㄖㄡ", "ran": "ㄖㄢ", "ren": "ㄖㄣ", "sai": "ㄙㄞ",
    "sei": "ㄙㄟ", "sau": "ㄙㄠ", "sou": "ㄙㄡ", "san": "ㄙㄢ", "sen": "ㄙㄣ", "ang": "ㄤ", "eng": "ㄥ", "yai": "ㄧㄞ", "yau": "ㄧㄠ",
    "yan": "ㄧㄢ", "yin": "ㄧㄣ", "wai": "ㄨㄞ", "wei": "ㄨㄟ", "wan": "ㄨㄢ", "wen": "ㄨㄣ", "yun": "ㄩㄣ", "jiu": "ㄐㄩ", "chi": "ㄑㄧ",
    "shi": "ㄒㄧ", "tza": "ㄗㄚ", "tze": "ㄗㄜ", "tzu": "ㄗㄨ", "tsz": "ㄘ", "tsa": "ㄘㄚ", "tse": "ㄘㄜ", "tsu": "ㄘㄨ", "duo": "ㄉㄨㄛ",
    "tuo": "ㄊㄨㄛ", "nuo": "ㄋㄨㄛ", "luo": "ㄌㄨㄛ", "ruo": "ㄖㄨㄛ", "suo": "ㄙㄨㄛ", "you": "ㄧㄡ", "niu": "ㄋㄩ", "liu": "ㄌㄩ",
    "gin": "ㄍㄧㄣ",
    "bo": "ㄅㄛ", "po": "ㄆㄛ", "mo": "ㄇㄛ", "fo": "ㄈㄛ", "jr": "ㄓ", "ja": "ㄓㄚ", "je": "ㄓㄜ", "ju": "ㄓㄨ", "ji": "ㄐㄧ",
    "tz": "ㄗ", "sz": "ㄙ", "er": "ㄦ", "ye": "ㄧㄝ", "ba": "ㄅㄚ", "bi": "ㄅㄧ", "bu": "ㄅㄨ", "pa": "ㄆㄚ", "pi": "ㄆㄧ", "pu": "ㄆㄨ",
    "ma": "ㄇㄚ", "me": "ㄇㄜ", "mi": "ㄇㄧ", "mu": "ㄇㄨ", "fa": "ㄈㄚ", "fu": "ㄈㄨ", "da": "ㄉㄚ", "de": "ㄉㄜ", "di": "ㄉㄧ",
    "du": "ㄉㄨ", "ta": "ㄊㄚ", "te": "ㄊㄜ", "ti": "ㄊㄧ", "tu": "ㄊㄨ", "na": "ㄋㄚ", "ne": "ㄋㄜ", "ni": "ㄋㄧ", "nu": "ㄋㄨ",
    "la": "ㄌㄚ", "lo": "ㄌㄛ", "le": "ㄌㄜ", "li": "ㄌㄧ", "lu": "ㄌㄨ", "ga": "ㄍㄚ", "ge": "ㄍㄜ", "gu": "ㄍㄨ", "ka": "ㄎㄚ",
    "ke": "ㄎㄜ", "ku": "ㄎㄨ", "ha": "ㄏㄚ", "he": "ㄏㄜ", "hu": "ㄏㄨ", "re": "ㄖㄜ", "ru": "ㄖㄨ", "sa": "ㄙㄚ", "se": "ㄙㄜ",
    "su": "ㄙㄨ", "eh": "ㄝ", "ai": "ㄞ", "ei": "ㄟ", "au": "ㄠ", "ou": "ㄡ", "an": "ㄢ", "en": "ㄣ", "ya": "ㄧㄚ", "yo": "ㄧㄛ",
    "wu": "ㄨ", "wa": "ㄨㄚ", "wo": "ㄨㄛ", "yu": "ㄩ", "ch": "ㄑ", "yi": "ㄧ",
    "r": "ㄖ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ",
  ]

  /// 耶魯拼音排列專用處理陣列
  static let mapYalePinyin: [String: String] = [
    "chwang": "ㄔㄨㄤ", "shwang": "ㄕㄨㄤ", "chyang": "ㄑㄧㄤ", "chyung": "ㄑㄩㄥ", "chywan": "ㄑㄩㄢ",
    "byang": "ㄅㄧㄤ", "dwang": "ㄉㄨㄤ", "jwang": "ㄓㄨㄤ", "syang": "ㄒㄧㄤ", "syung": "ㄒㄩㄥ", "jyang": "ㄐㄧㄤ", "jyung": "ㄐㄩㄥ",
    "nyang": "ㄋㄧㄤ", "lyang": "ㄌㄧㄤ", "gwang": "ㄍㄨㄤ", "kwang": "ㄎㄨㄤ", "hwang": "ㄏㄨㄤ", "chang": "ㄔㄤ", "cheng": "ㄔㄥ",
    "chwai": "ㄔㄨㄞ", "chwan": "ㄔㄨㄢ", "chung": "ㄔㄨㄥ", "shang": "ㄕㄤ", "sheng": "ㄕㄥ", "shwai": "ㄕㄨㄞ", "shwan": "ㄕㄨㄢ",
    "sywan": "ㄒㄩㄢ", "jywan": "ㄐㄩㄢ", "chyau": "ㄑㄧㄠ", "chyan": "ㄑㄧㄢ", "ching": "ㄑㄧㄥ", "sying": "ㄒㄧㄥ", "dzang": "ㄗㄤ",
    "dzeng": "ㄗㄥ", "dzwan": "ㄗㄨㄢ", "dzung": "ㄗㄨㄥ", "tsang": "ㄘㄤ", "tseng": "ㄘㄥ", "tswan": "ㄘㄨㄢ", "tsung": "ㄘㄨㄥ",
    "chywe": "ㄑㄩㄝ", "lywan": "ㄌㄩㄢ", "chwei": "ㄔㄨㄟ", "chwun": "ㄔㄨㄣ", "shwei": "ㄕㄨㄟ", "shwun": "ㄕㄨㄣ", "chyou": "ㄑㄧㄡ",
    "chyun": "ㄑㄩㄣ", "dzwei": "ㄗㄨㄟ", "dzwun": "ㄗㄨㄣ", "tswei": "ㄘㄨㄟ", "tswun": "ㄘㄨㄣ", "kyang": "ㄎㄧㄤ",
    "jang": "ㄓㄤ", "jeng": "ㄓㄥ", "jwai": "ㄓㄨㄞ", "jwan": "ㄓㄨㄢ", "jung": "ㄓㄨㄥ", "syau": "ㄒㄧㄠ", "syan": "ㄒㄧㄢ",
    "jyau": "ㄐㄧㄠ", "jyan": "ㄐㄧㄢ", "jing": "ㄐㄧㄥ", "sywe": "ㄒㄩㄝ", "jywe": "ㄐㄩㄝ", "chye": "ㄑㄧㄝ", "bang": "ㄅㄤ",
    "beng": "ㄅㄥ", "byau": "ㄅㄧㄠ", "byan": "ㄅㄧㄢ", "bing": "ㄅㄧㄥ", "pang": "ㄆㄤ", "peng": "ㄆㄥ", "pyau": "ㄆㄧㄠ", "pyan": "ㄆㄧㄢ",
    "ping": "ㄆㄧㄥ", "mang": "ㄇㄤ", "meng": "ㄇㄥ", "myau": "ㄇㄧㄠ", "myan": "ㄇㄧㄢ", "ming": "ㄇㄧㄥ", "fang": "ㄈㄤ", "feng": "ㄈㄥ",
    "fyau": "ㄈㄧㄠ", "dang": "ㄉㄤ", "deng": "ㄉㄥ", "dyau": "ㄉㄧㄠ", "dyan": "ㄉㄧㄢ", "ding": "ㄉㄧㄥ", "dwan": "ㄉㄨㄢ",
    "dung": "ㄉㄨㄥ", "tang": "ㄊㄤ", "teng": "ㄊㄥ", "tyau": "ㄊㄧㄠ", "tyan": "ㄊㄧㄢ", "ting": "ㄊㄧㄥ", "twan": "ㄊㄨㄢ",
    "tung": "ㄊㄨㄥ", "nang": "ㄋㄤ", "neng": "ㄋㄥ", "nyau": "ㄋㄧㄠ", "nyan": "ㄋㄧㄢ", "ning": "ㄋㄧㄥ", "nwan": "ㄋㄨㄢ",
    "nung": "ㄋㄨㄥ", "lang": "ㄌㄤ", "leng": "ㄌㄥ", "lyau": "ㄌㄧㄠ", "lyan": "ㄌㄧㄢ", "ling": "ㄌㄧㄥ", "lwan": "ㄌㄨㄢ",
    "lung": "ㄌㄨㄥ", "gang": "ㄍㄤ", "geng": "ㄍㄥ", "gwai": "ㄍㄨㄞ", "gwan": "ㄍㄨㄢ", "gung": "ㄍㄨㄥ", "kang": "ㄎㄤ", "keng": "ㄎㄥ",
    "kwai": "ㄎㄨㄞ", "kwan": "ㄎㄨㄢ", "kung": "ㄎㄨㄥ", "hang": "ㄏㄤ", "heng": "ㄏㄥ", "hwai": "ㄏㄨㄞ", "hwan": "ㄏㄨㄢ",
    "hung": "ㄏㄨㄥ", "jwei": "ㄓㄨㄟ", "jwun": "ㄓㄨㄣ", "chai": "ㄔㄞ", "chau": "ㄔㄠ", "chou": "ㄔㄡ", "chan": "ㄔㄢ", "chen": "ㄔㄣ",
    "chwa": "ㄔㄨㄚ", "shai": "ㄕㄞ", "shei": "ㄕㄟ", "shau": "ㄕㄠ", "shou": "ㄕㄡ", "shan": "ㄕㄢ", "shen": "ㄕㄣ", "shwa": "ㄕㄨㄚ",
    "shwo": "ㄕㄨㄛ", "rang": "ㄖㄤ", "reng": "ㄖㄥ", "rwan": "ㄖㄨㄢ", "rung": "ㄖㄨㄥ", "sang": "ㄙㄤ", "seng": "ㄙㄥ", "swan": "ㄙㄨㄢ",
    "sung": "ㄙㄨㄥ", "yang": "ㄧㄤ", "ying": "ㄧㄥ", "wang": "ㄨㄤ", "weng": "ㄨㄥ", "ywan": "ㄩㄢ", "yung": "ㄩㄥ", "syou": "ㄒㄧㄡ",
    "syun": "ㄒㄩㄣ", "nywe": "ㄋㄩㄝ", "lywe": "ㄌㄩㄝ", "gwei": "ㄍㄨㄟ", "kwei": "ㄎㄨㄟ", "jyou": "ㄐㄧㄡ", "jyun": "ㄐㄩㄣ",
    "chya": "ㄑㄧㄚ", "chin": "ㄑㄧㄣ", "syin": "ㄒㄧㄣ", "dzai": "ㄗㄞ", "dzei": "ㄗㄟ", "dzau": "ㄗㄠ", "dzou": "ㄗㄡ", "dzan": "ㄗㄢ",
    "dzen": "ㄗㄣ", "tsai": "ㄘㄞ", "tsau": "ㄘㄠ", "tsou": "ㄘㄡ", "tsan": "ㄘㄢ", "tsen": "ㄘㄣ", "chwo": "ㄔㄨㄛ", "myou": "ㄇㄧㄡ",
    "dyou": "ㄉㄧㄡ", "dwei": "ㄉㄨㄟ", "dwun": "ㄉㄨㄣ", "twei": "ㄊㄨㄟ", "twun": "ㄊㄨㄣ", "nyou": "ㄋㄧㄡ", "nwei": "ㄋㄨㄟ",
    "nwun": "ㄋㄨㄣ", "lyou": "ㄌㄧㄡ", "lwun": "ㄌㄨㄣ", "gwun": "ㄍㄨㄣ", "kwun": "ㄎㄨㄣ", "hwei": "ㄏㄨㄟ", "hwun": "ㄏㄨㄣ",
    "rwei": "ㄖㄨㄟ", "rwun": "ㄖㄨㄣ", "dzwo": "ㄗㄨㄛ", "tswo": "ㄘㄨㄛ", "swei": "ㄙㄨㄟ", "swun": "ㄙㄨㄣ", "chyu": "ㄑㄩ",
    "giau": "ㄍㄧㄠ",
    "sye": "ㄒㄧㄝ", "jye": "ㄐㄧㄝ", "jai": "ㄓㄞ", "jei": "ㄓㄟ", "jau": "ㄓㄠ", "jou": "ㄓㄡ", "jan": "ㄓㄢ", "jen": "ㄓㄣ",
    "jwa": "ㄓㄨㄚ", "sya": "ㄒㄧㄚ", "bye": "ㄅㄧㄝ", "pye": "ㄆㄧㄝ", "mye": "ㄇㄧㄝ", "dye": "ㄉㄧㄝ", "tye": "ㄊㄧㄝ", "nye": "ㄋㄧㄝ",
    "lye": "ㄌㄧㄝ", "jya": "ㄐㄧㄚ", "jin": "ㄐㄧㄣ", "chr": "ㄔ", "shr": "ㄕ", "ywe": "ㄩㄝ", "jwo": "ㄓㄨㄛ", "bai": "ㄅㄞ",
    "bei": "ㄅㄟ", "bau": "ㄅㄠ", "ban": "ㄅㄢ", "ben": "ㄅㄣ", "bin": "ㄅㄧㄣ", "pai": "ㄆㄞ", "pei": "ㄆㄟ", "pau": "ㄆㄠ",
    "pou": "ㄆㄡ", "pan": "ㄆㄢ", "pen": "ㄆㄣ", "pya": "ㄆㄧㄚ", "pin": "ㄆㄧㄣ", "mai": "ㄇㄞ", "mei": "ㄇㄟ", "mau": "ㄇㄠ",
    "mou": "ㄇㄡ", "man": "ㄇㄢ", "men": "ㄇㄣ", "min": "ㄇㄧㄣ", "fei": "ㄈㄟ", "fou": "ㄈㄡ", "fan": "ㄈㄢ", "fen": "ㄈㄣ",
    "dai": "ㄉㄞ", "dei": "ㄉㄟ", "dau": "ㄉㄠ", "dou": "ㄉㄡ", "dan": "ㄉㄢ", "den": "ㄉㄣ", "dya": "ㄉㄧㄚ", "tai": "ㄊㄞ",
    "tau": "ㄊㄠ", "tou": "ㄊㄡ", "tan": "ㄊㄢ", "nai": "ㄋㄞ", "nei": "ㄋㄟ", "nau": "ㄋㄠ", "nou": "ㄋㄡ", "nan": "ㄋㄢ", "nen": "ㄋㄣ",
    "nin": "ㄋㄧㄣ", "lai": "ㄌㄞ", "lei": "ㄌㄟ", "lau": "ㄌㄠ", "lou": "ㄌㄡ", "lan": "ㄌㄢ", "lya": "ㄌㄧㄚ", "lin": "ㄌㄧㄣ",
    "gai": "ㄍㄞ", "gei": "ㄍㄟ", "gau": "ㄍㄠ", "gou": "ㄍㄡ", "gan": "ㄍㄢ", "gen": "ㄍㄣ", "gwa": "ㄍㄨㄚ", "gwo": "ㄍㄨㄛ",
    "gue": "ㄍㄨㄜ", "kai": "ㄎㄞ", "kau": "ㄎㄠ", "kou": "ㄎㄡ", "kan": "ㄎㄢ", "ken": "ㄎㄣ", "kwa": "ㄎㄨㄚ", "kwo": "ㄎㄨㄛ",
    "hai": "ㄏㄞ", "hei": "ㄏㄟ", "hau": "ㄏㄠ", "hou": "ㄏㄡ", "han": "ㄏㄢ", "hen": "ㄏㄣ", "hwa": "ㄏㄨㄚ", "hwo": "ㄏㄨㄛ",
    "cha": "ㄔㄚ", "che": "ㄔㄜ", "chu": "ㄔㄨ", "sha": "ㄕㄚ", "she": "ㄕㄜ", "shu": "ㄕㄨ", "rau": "ㄖㄠ", "rou": "ㄖㄡ", "ran": "ㄖㄢ",
    "ren": "ㄖㄣ", "sai": "ㄙㄞ", "sei": "ㄙㄟ", "sau": "ㄙㄠ", "sou": "ㄙㄡ", "san": "ㄙㄢ", "sen": "ㄙㄣ", "ang": "ㄤ", "eng": "ㄥ",
    "yai": "ㄧㄞ", "yau": "ㄧㄠ", "yan": "ㄧㄢ", "yin": "ㄧㄣ", "wai": "ㄨㄞ", "wei": "ㄨㄟ", "wan": "ㄨㄢ", "wen": "ㄨㄣ", "yun": "ㄩㄣ",
    "syu": "ㄒㄩ", "jyu": "ㄐㄩ", "chi": "ㄑㄧ", "syi": "ㄒㄧ", "dza": "ㄗㄚ", "dze": "ㄗㄜ", "dzu": "ㄗㄨ", "tsz": "ㄘ", "tsa": "ㄘㄚ",
    "tse": "ㄘㄜ", "tsu": "ㄘㄨ", "dwo": "ㄉㄨㄛ", "two": "ㄊㄨㄛ", "nwo": "ㄋㄨㄛ", "lwo": "ㄌㄨㄛ", "rwo": "ㄖㄨㄛ", "swo": "ㄙㄨㄛ",
    "you": "ㄧㄡ", "nyu": "ㄋㄩ", "lyu": "ㄌㄩ", "bwo": "ㄅㄛ", "pwo": "ㄆㄛ", "mwo": "ㄇㄛ", "fwo": "ㄈㄛ", "gin": "ㄍㄧㄣ",
    "jr": "ㄓ", "ja": "ㄓㄚ", "je": "ㄓㄜ", "ju": "ㄓㄨ", "ji": "ㄐㄧ", "dz": "ㄗ", "sz": "ㄙ", "er": "ㄦ", "ye": "ㄧㄝ", "ba": "ㄅㄚ",
    "bi": "ㄅㄧ", "bu": "ㄅㄨ", "pa": "ㄆㄚ", "pi": "ㄆㄧ", "pu": "ㄆㄨ", "ma": "ㄇㄚ", "me": "ㄇㄜ", "mi": "ㄇㄧ", "mu": "ㄇㄨ",
    "fa": "ㄈㄚ", "fu": "ㄈㄨ", "da": "ㄉㄚ", "de": "ㄉㄜ", "di": "ㄉㄧ", "du": "ㄉㄨ", "ta": "ㄊㄚ", "te": "ㄊㄜ", "ti": "ㄊㄧ",
    "tu": "ㄊㄨ", "na": "ㄋㄚ", "ne": "ㄋㄜ", "ni": "ㄋㄧ", "nu": "ㄋㄨ", "la": "ㄌㄚ", "lo": "ㄌㄛ", "le": "ㄌㄜ", "li": "ㄌㄧ",
    "lu": "ㄌㄨ", "ga": "ㄍㄚ", "ge": "ㄍㄜ", "gu": "ㄍㄨ", "ka": "ㄎㄚ", "ke": "ㄎㄜ", "ku": "ㄎㄨ", "ha": "ㄏㄚ", "he": "ㄏㄜ",
    "hu": "ㄏㄨ", "re": "ㄖㄜ", "ru": "ㄖㄨ", "sa": "ㄙㄚ", "se": "ㄙㄜ", "su": "ㄙㄨ", "eh": "ㄝ", "ai": "ㄞ", "ei": "ㄟ", "au": "ㄠ",
    "ou": "ㄡ", "an": "ㄢ", "en": "ㄣ", "ya": "ㄧㄚ", "yo": "ㄧㄛ", "wu": "ㄨ", "wa": "ㄨㄚ", "wo": "ㄨㄛ", "yu": "ㄩ", "ch": "ㄑ",
    "yi": "ㄧ",
    "r": "ㄖ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ",
  ]

  /// 華羅拼音排列專用處理陣列
  static let mapHualuoPinyin: [String: String] = [
    "shuang": "ㄕㄨㄤ", "jhuang": "ㄓㄨㄤ", "chyueh": "ㄑㄩㄝ", "chyuan": "ㄑㄩㄢ", "chyong": "ㄑㄩㄥ", "chiang": "ㄑㄧㄤ",
    "chuang": "ㄔㄨㄤ",
    "biang": "ㄅㄧㄤ", "duang": "ㄉㄨㄤ", "kyang": "ㄎㄧㄤ", "syueh": "ㄒㄩㄝ", "syuan": "ㄒㄩㄢ", "syong": "ㄒㄩㄥ", "sihei": "ㄙㄟ",
    "siang": "ㄒㄧㄤ", "shuei": "ㄕㄨㄟ", "shuan": "ㄕㄨㄢ", "shuai": "ㄕㄨㄞ", "sheng": "ㄕㄥ", "shang": "ㄕㄤ", "nyueh": "ㄋㄩㄝ",
    "niang": "ㄋㄧㄤ", "lyueh": "ㄌㄩㄝ", "lyuan": "ㄌㄩㄢ", "liang": "ㄌㄧㄤ", "kuang": "ㄎㄨㄤ", "jyueh": "ㄐㄩㄝ", "jyuan": "ㄐㄩㄢ",
    "jyong": "ㄐㄩㄥ", "jiang": "ㄐㄧㄤ", "jhuei": "ㄓㄨㄟ", "jhuan": "ㄓㄨㄢ", "jhuai": "ㄓㄨㄞ", "jhong": "ㄓㄨㄥ", "jheng": "ㄓㄥ",
    "jhang": "ㄓㄤ", "huang": "ㄏㄨㄤ", "guang": "ㄍㄨㄤ", "chyun": "ㄑㄩㄣ", "tsuei": "ㄘㄨㄟ", "tsuan": "ㄘㄨㄢ", "tsong": "ㄘㄨㄥ",
    "chiou": "ㄑㄧㄡ", "ching": "ㄑㄧㄥ", "chieh": "ㄑㄧㄝ", "chiao": "ㄑㄧㄠ", "chian": "ㄑㄧㄢ", "chuei": "ㄔㄨㄟ", "chuan": "ㄔㄨㄢ",
    "chuai": "ㄔㄨㄞ", "chong": "ㄔㄨㄥ", "cheng": "ㄔㄥ", "chang": "ㄔㄤ", "tseng": "ㄘㄥ", "tsang": "ㄘㄤ",
    "gyao": "ㄍㄧㄠ", "fiao": "ㄈㄧㄠ", "zuei": "ㄗㄨㄟ", "zuan": "ㄗㄨㄢ", "zong": "ㄗㄨㄥ", "zeng": "ㄗㄥ", "zang": "ㄗㄤ", "yueh": "ㄩㄝ",
    "yuan": "ㄩㄢ", "yong": "ㄩㄥ", "ying": "ㄧㄥ", "yang": "ㄧㄤ", "wong": "ㄨㄥ", "wang": "ㄨㄤ", "tuei": "ㄊㄨㄟ", "tuan": "ㄊㄨㄢ",
    "tong": "ㄊㄨㄥ", "ting": "ㄊㄧㄥ", "tieh": "ㄊㄧㄝ", "tiao": "ㄊㄧㄠ", "tian": "ㄊㄧㄢ", "teng": "ㄊㄥ", "tang": "ㄊㄤ",
    "syun": "ㄒㄩㄣ", "suei": "ㄙㄨㄟ", "suan": "ㄙㄨㄢ", "song": "ㄙㄨㄥ", "siou": "ㄒㄧㄡ", "sing": "ㄒㄧㄥ", "sieh": "ㄒㄧㄝ",
    "siao": "ㄒㄧㄠ", "sian": "ㄒㄧㄢ", "shuo": "ㄕㄨㄛ", "shun": "ㄕㄨㄣ", "shua": "ㄕㄨㄚ", "shou": "ㄕㄡ", "shih": "ㄕ", "shen": "ㄕㄣ",
    "shei": "ㄕㄟ", "shao": "ㄕㄠ", "shan": "ㄕㄢ", "shai": "ㄕㄞ", "seng": "ㄙㄥ", "sang": "ㄙㄤ", "ruei": "ㄖㄨㄟ", "ruan": "ㄖㄨㄢ",
    "rong": "ㄖㄨㄥ", "reng": "ㄖㄥ", "rang": "ㄖㄤ", "ping": "ㄆㄧㄥ", "pieh": "ㄆㄧㄝ", "piao": "ㄆㄧㄠ", "pian": "ㄆㄧㄢ", "peng": "ㄆㄥ",
    "pang": "ㄆㄤ", "nuei": "ㄋㄨㄟ", "nuan": "ㄋㄨㄢ", "nong": "ㄋㄨㄥ", "niou": "ㄋㄧㄡ", "ning": "ㄋㄧㄥ", "nieh": "ㄋㄧㄝ",
    "niao": "ㄋㄧㄠ", "nian": "ㄋㄧㄢ", "neng": "ㄋㄥ", "nang": "ㄋㄤ", "miou": "ㄇㄧㄡ", "ming": "ㄇㄧㄥ", "mieh": "ㄇㄧㄝ",
    "miao": "ㄇㄧㄠ", "mian": "ㄇㄧㄢ", "meng": "ㄇㄥ", "mang": "ㄇㄤ", "luan": "ㄌㄨㄢ", "long": "ㄌㄨㄥ", "liou": "ㄌㄧㄡ",
    "ling": "ㄌㄧㄥ", "lieh": "ㄌㄧㄝ", "liao": "ㄌㄧㄠ", "lian": "ㄌㄧㄢ", "leng": "ㄌㄥ", "lang": "ㄌㄤ", "kuei": "ㄎㄨㄟ",
    "kuan": "ㄎㄨㄢ", "kuai": "ㄎㄨㄞ", "kong": "ㄎㄨㄥ", "keng": "ㄎㄥ", "kang": "ㄎㄤ", "jyun": "ㄐㄩㄣ", "jiou": "ㄐㄧㄡ",
    "jing": "ㄐㄧㄥ", "jieh": "ㄐㄧㄝ", "jiao": "ㄐㄧㄠ", "jian": "ㄐㄧㄢ", "jhuo": "ㄓㄨㄛ", "jhun": "ㄓㄨㄣ", "jhua": "ㄓㄨㄚ",
    "jhou": "ㄓㄡ", "jhih": "ㄓ", "jhen": "ㄓㄣ", "jhei": "ㄓㄟ", "jhao": "ㄓㄠ", "jhan": "ㄓㄢ", "jhai": "ㄓㄞ", "huei": "ㄏㄨㄟ",
    "huan": "ㄏㄨㄢ", "huai": "ㄏㄨㄞ", "hong": "ㄏㄨㄥ", "heng": "ㄏㄥ", "hang": "ㄏㄤ", "guei": "ㄍㄨㄟ", "guan": "ㄍㄨㄢ",
    "guai": "ㄍㄨㄞ", "gong": "ㄍㄨㄥ", "geng": "ㄍㄥ", "gang": "ㄍㄤ", "feng": "ㄈㄥ", "fang": "ㄈㄤ", "duei": "ㄉㄨㄟ", "duan": "ㄉㄨㄢ",
    "dong": "ㄉㄨㄥ", "diou": "ㄉㄧㄡ", "ding": "ㄉㄧㄥ", "dieh": "ㄉㄧㄝ", "diao": "ㄉㄧㄠ", "dian": "ㄉㄧㄢ", "deng": "ㄉㄥ",
    "dang": "ㄉㄤ", "chyu": "ㄑㄩ", "tsuo": "ㄘㄨㄛ", "tsun": "ㄘㄨㄣ", "tsou": "ㄘㄡ", "chin": "ㄑㄧㄣ", "tsih": "ㄘ", "chia": "ㄑㄧㄚ",
    "chuo": "ㄔㄨㄛ", "chun": "ㄔㄨㄣ", "chua": "ㄔㄨㄚ", "chou": "ㄔㄡ", "chih": "ㄔ", "chen": "ㄔㄣ", "chao": "ㄔㄠ", "chan": "ㄔㄢ",
    "chai": "ㄔㄞ", "tsen": "ㄘㄣ", "tsao": "ㄘㄠ", "tsan": "ㄘㄢ", "tsai": "ㄘㄞ", "bing": "ㄅㄧㄥ", "bieh": "ㄅㄧㄝ", "biao": "ㄅㄧㄠ",
    "bian": "ㄅㄧㄢ", "beng": "ㄅㄥ", "bang": "ㄅㄤ",
    "gin": "ㄍㄧㄣ", "den": "ㄉㄣ", "zuo": "ㄗㄨㄛ", "zun": "ㄗㄨㄣ", "zou": "ㄗㄡ", "zih": "ㄗ", "zen": "ㄗㄣ", "zei": "ㄗㄟ",
    "zao": "ㄗㄠ", "zan": "ㄗㄢ", "zai": "ㄗㄞ", "yun": "ㄩㄣ", "you": "ㄧㄡ", "yin": "ㄧㄣ", "yeh": "ㄧㄝ", "yao": "ㄧㄠ", "yan": "ㄧㄢ",
    "yai": "ㄧㄞ", "wun": "ㄨㄣ", "wei": "ㄨㄟ", "wan": "ㄨㄢ", "wai": "ㄨㄞ", "tuo": "ㄊㄨㄛ", "tun": "ㄊㄨㄣ", "tou": "ㄊㄡ",
    "tao": "ㄊㄠ", "tan": "ㄊㄢ", "tai": "ㄊㄞ", "syu": "ㄒㄩ", "suo": "ㄙㄨㄛ", "sun": "ㄙㄨㄣ", "sou": "ㄙㄡ", "sin": "ㄒㄧㄣ",
    "sih": "ㄙ", "sia": "ㄒㄧㄚ", "shu": "ㄕㄨ", "she": "ㄕㄜ", "sha": "ㄕㄚ", "sen": "ㄙㄣ", "sao": "ㄙㄠ", "san": "ㄙㄢ", "sai": "ㄙㄞ",
    "ruo": "ㄖㄨㄛ", "run": "ㄖㄨㄣ", "rou": "ㄖㄡ", "rih": "ㄖ", "ren": "ㄖㄣ", "rao": "ㄖㄠ", "ran": "ㄖㄢ", "pou": "ㄆㄡ",
    "pin": "ㄆㄧㄣ", "pia": "ㄆㄧㄚ", "pen": "ㄆㄣ", "pei": "ㄆㄟ", "pao": "ㄆㄠ", "pan": "ㄆㄢ", "pai": "ㄆㄞ", "nyu": "ㄋㄩ",
    "nuo": "ㄋㄨㄛ", "nun": "ㄋㄨㄣ", "nou": "ㄋㄡ", "nin": "ㄋㄧㄣ", "nen": "ㄋㄣ", "nei": "ㄋㄟ", "nao": "ㄋㄠ", "nan": "ㄋㄢ",
    "nai": "ㄋㄞ", "mou": "ㄇㄡ", "min": "ㄇㄧㄣ", "men": "ㄇㄣ", "mei": "ㄇㄟ", "mao": "ㄇㄠ", "man": "ㄇㄢ", "mai": "ㄇㄞ",
    "lyu": "ㄌㄩ", "luo": "ㄌㄨㄛ", "lun": "ㄌㄨㄣ", "lou": "ㄌㄡ", "lin": "ㄌㄧㄣ", "lia": "ㄌㄧㄚ", "lei": "ㄌㄟ", "lao": "ㄌㄠ",
    "lan": "ㄌㄢ", "lai": "ㄌㄞ", "kuo": "ㄎㄨㄛ", "kun": "ㄎㄨㄣ", "kua": "ㄎㄨㄚ", "kou": "ㄎㄡ", "ken": "ㄎㄣ", "kao": "ㄎㄠ",
    "kan": "ㄎㄢ", "kai": "ㄎㄞ", "jyu": "ㄐㄩ", "jin": "ㄐㄧㄣ", "jia": "ㄐㄧㄚ", "jhu": "ㄓㄨ", "jhe": "ㄓㄜ", "jha": "ㄓㄚ",
    "huo": "ㄏㄨㄛ", "hun": "ㄏㄨㄣ", "hua": "ㄏㄨㄚ", "hou": "ㄏㄡ", "hen": "ㄏㄣ", "hei": "ㄏㄟ", "hao": "ㄏㄠ", "han": "ㄏㄢ",
    "hai": "ㄏㄞ", "guo": "ㄍㄨㄛ", "gun": "ㄍㄨㄣ", "gue": "ㄍㄨㄜ", "gua": "ㄍㄨㄚ", "gou": "ㄍㄡ", "gen": "ㄍㄣ", "gei": "ㄍㄟ",
    "gao": "ㄍㄠ", "gan": "ㄍㄢ", "gai": "ㄍㄞ", "fou": "ㄈㄡ", "fen": "ㄈㄣ", "fei": "ㄈㄟ", "fan": "ㄈㄢ", "eng": "ㄥ", "duo": "ㄉㄨㄛ",
    "dun": "ㄉㄨㄣ", "dou": "ㄉㄡ", "dia": "ㄉㄧㄚ", "dei": "ㄉㄟ", "dao": "ㄉㄠ", "dan": "ㄉㄢ", "dai": "ㄉㄞ", "tsu": "ㄘㄨ",
    "chi": "ㄑㄧ", "chu": "ㄔㄨ", "che": "ㄔㄜ", "cha": "ㄔㄚ", "tse": "ㄘㄜ", "tsa": "ㄘㄚ", "bin": "ㄅㄧㄣ", "ben": "ㄅㄣ",
    "bei": "ㄅㄟ", "bao": "ㄅㄠ", "ban": "ㄅㄢ", "bai": "ㄅㄞ", "ang": "ㄤ",
    "ch": "ㄑ", "zu": "ㄗㄨ", "ze": "ㄗㄜ", "za": "ㄗㄚ", "yu": "ㄩ", "yo": "ㄧㄛ", "ya": "ㄧㄚ", "yi": "ㄧ", "wu": "ㄨ", "wo": "ㄨㄛ",
    "wa": "ㄨㄚ", "tu": "ㄊㄨ", "ti": "ㄊㄧ", "te": "ㄊㄜ", "ta": "ㄊㄚ", "su": "ㄙㄨ", "si": "ㄒㄧ", "se": "ㄙㄜ", "sa": "ㄙㄚ",
    "ru": "ㄖㄨ", "re": "ㄖㄜ", "pu": "ㄆㄨ", "po": "ㄆㄛ", "pi": "ㄆㄧ", "pa": "ㄆㄚ", "ou": "ㄡ", "nu": "ㄋㄨ", "ni": "ㄋㄧ",
    "ne": "ㄋㄜ", "na": "ㄋㄚ", "mu": "ㄇㄨ", "mo": "ㄇㄛ", "mi": "ㄇㄧ", "me": "ㄇㄜ", "ma": "ㄇㄚ", "lu": "ㄌㄨ", "lo": "ㄌㄛ",
    "li": "ㄌㄧ", "le": "ㄌㄜ", "la": "ㄌㄚ", "ku": "ㄎㄨ", "ke": "ㄎㄜ", "ka": "ㄎㄚ", "ji": "ㄐㄧ", "hu": "ㄏㄨ", "he": "ㄏㄜ",
    "ha": "ㄏㄚ", "gu": "ㄍㄨ", "ge": "ㄍㄜ", "ga": "ㄍㄚ", "fu": "ㄈㄨ", "fo": "ㄈㄛ", "fa": "ㄈㄚ", "er": "ㄦ", "en": "ㄣ", "ei": "ㄟ",
    "eh": "ㄝ", "du": "ㄉㄨ", "di": "ㄉㄧ", "de": "ㄉㄜ", "da": "ㄉㄚ", "bu": "ㄅㄨ", "bo": "ㄅㄛ", "bi": "ㄅㄧ", "ba": "ㄅㄚ",
    "ao": "ㄠ", "an": "ㄢ", "ai": "ㄞ",
    "o": "ㄛ", "e": "ㄜ", "a": "ㄚ",
  ]

  /// 通用拼音排列專用處理陣列
  static let mapUniversalPinyin: [String: String] = [
    "shuang": "ㄕㄨㄤ", "jhuang": "ㄓㄨㄤ", "chuang": "ㄔㄨㄤ",
    "biang": "ㄅㄧㄤ", "duang": "ㄉㄨㄤ", "cyuan": "ㄑㄩㄢ", "cyong": "ㄑㄩㄥ", "ciang": "ㄑㄧㄤ", "kyang": "ㄎㄧㄤ", "syuan": "ㄒㄩㄢ",
    "syong": "ㄒㄩㄥ", "sihei": "ㄙㄟ", "siang": "ㄒㄧㄤ", "shuei": "ㄕㄨㄟ", "shuan": "ㄕㄨㄢ", "shuai": "ㄕㄨㄞ", "sheng": "ㄕㄥ",
    "shang": "ㄕㄤ", "niang": "ㄋㄧㄤ", "lyuan": "ㄌㄩㄢ", "liang": "ㄌㄧㄤ", "kuang": "ㄎㄨㄤ", "jyuan": "ㄐㄩㄢ", "jyong": "ㄐㄩㄥ",
    "jiang": "ㄐㄧㄤ", "jhuei": "ㄓㄨㄟ", "jhuan": "ㄓㄨㄢ", "jhuai": "ㄓㄨㄞ", "jhong": "ㄓㄨㄥ", "jheng": "ㄓㄥ", "jhang": "ㄓㄤ",
    "huang": "ㄏㄨㄤ", "guang": "ㄍㄨㄤ", "chuei": "ㄔㄨㄟ", "chuan": "ㄔㄨㄢ", "chuai": "ㄔㄨㄞ", "chong": "ㄔㄨㄥ", "cheng": "ㄔㄥ",
    "chang": "ㄔㄤ",
    "cyue": "ㄑㄩㄝ", "syue": "ㄒㄩㄝ", "nyue": "ㄋㄩㄝ", "lyue": "ㄌㄩㄝ", "jyue": "ㄐㄩㄝ", "cyun": "ㄑㄩㄣ", "cuei": "ㄘㄨㄟ",
    "cuan": "ㄘㄨㄢ", "cong": "ㄘㄨㄥ", "ciou": "ㄑㄧㄡ", "cing": "ㄑㄧㄥ", "ciao": "ㄑㄧㄠ", "cian": "ㄑㄧㄢ", "ceng": "ㄘㄥ",
    "cang": "ㄘㄤ", "gyao": "ㄍㄧㄠ", "fiao": "ㄈㄧㄠ", "zuei": "ㄗㄨㄟ", "zuan": "ㄗㄨㄢ", "zong": "ㄗㄨㄥ", "zeng": "ㄗㄥ", "zang": "ㄗㄤ",
    "yuan": "ㄩㄢ", "yong": "ㄩㄥ", "ying": "ㄧㄥ", "yang": "ㄧㄤ", "wong": "ㄨㄥ", "wang": "ㄨㄤ", "tuei": "ㄊㄨㄟ", "tuan": "ㄊㄨㄢ",
    "tong": "ㄊㄨㄥ", "ting": "ㄊㄧㄥ", "tiao": "ㄊㄧㄠ", "tian": "ㄊㄧㄢ", "teng": "ㄊㄥ", "tang": "ㄊㄤ", "syun": "ㄒㄩㄣ",
    "suei": "ㄙㄨㄟ", "suan": "ㄙㄨㄢ", "song": "ㄙㄨㄥ", "siou": "ㄒㄧㄡ", "sing": "ㄒㄧㄥ", "siao": "ㄒㄧㄠ", "sian": "ㄒㄧㄢ",
    "shuo": "ㄕㄨㄛ", "shun": "ㄕㄨㄣ", "shua": "ㄕㄨㄚ", "shou": "ㄕㄡ", "shih": "ㄕ", "shen": "ㄕㄣ", "shei": "ㄕㄟ", "shao": "ㄕㄠ",
    "shan": "ㄕㄢ", "shai": "ㄕㄞ", "seng": "ㄙㄥ", "sang": "ㄙㄤ", "ruei": "ㄖㄨㄟ", "ruan": "ㄖㄨㄢ", "rong": "ㄖㄨㄥ", "reng": "ㄖㄥ",
    "rang": "ㄖㄤ", "ping": "ㄆㄧㄥ", "piao": "ㄆㄧㄠ", "pian": "ㄆㄧㄢ", "peng": "ㄆㄥ", "pang": "ㄆㄤ", "nuei": "ㄋㄨㄟ", "nuan": "ㄋㄨㄢ",
    "nong": "ㄋㄨㄥ", "niou": "ㄋㄧㄡ", "ning": "ㄋㄧㄥ", "niao": "ㄋㄧㄠ", "nian": "ㄋㄧㄢ", "neng": "ㄋㄥ", "nang": "ㄋㄤ",
    "miou": "ㄇㄧㄡ", "ming": "ㄇㄧㄥ", "miao": "ㄇㄧㄠ", "mian": "ㄇㄧㄢ", "meng": "ㄇㄥ", "mang": "ㄇㄤ", "luan": "ㄌㄨㄢ",
    "long": "ㄌㄨㄥ", "liou": "ㄌㄧㄡ", "ling": "ㄌㄧㄥ", "liao": "ㄌㄧㄠ", "lian": "ㄌㄧㄢ", "leng": "ㄌㄥ", "lang": "ㄌㄤ",
    "kuei": "ㄎㄨㄟ", "kuan": "ㄎㄨㄢ", "kuai": "ㄎㄨㄞ", "kong": "ㄎㄨㄥ", "keng": "ㄎㄥ", "kang": "ㄎㄤ", "jyun": "ㄐㄩㄣ",
    "jiou": "ㄐㄧㄡ", "jing": "ㄐㄧㄥ", "jiao": "ㄐㄧㄠ", "jian": "ㄐㄧㄢ", "jhuo": "ㄓㄨㄛ", "jhun": "ㄓㄨㄣ", "jhua": "ㄓㄨㄚ",
    "jhou": "ㄓㄡ", "jhih": "ㄓ", "jhen": "ㄓㄣ", "jhei": "ㄓㄟ", "jhao": "ㄓㄠ", "jhan": "ㄓㄢ", "jhai": "ㄓㄞ", "huei": "ㄏㄨㄟ",
    "huan": "ㄏㄨㄢ", "huai": "ㄏㄨㄞ", "hong": "ㄏㄨㄥ", "heng": "ㄏㄥ", "hang": "ㄏㄤ", "guei": "ㄍㄨㄟ", "guan": "ㄍㄨㄢ",
    "guai": "ㄍㄨㄞ", "gong": "ㄍㄨㄥ", "geng": "ㄍㄥ", "gang": "ㄍㄤ", "fong": "ㄈㄥ", "fang": "ㄈㄤ", "duei": "ㄉㄨㄟ", "duan": "ㄉㄨㄢ",
    "dong": "ㄉㄨㄥ", "diou": "ㄉㄧㄡ", "ding": "ㄉㄧㄥ", "diao": "ㄉㄧㄠ", "dian": "ㄉㄧㄢ", "deng": "ㄉㄥ", "dang": "ㄉㄤ",
    "chuo": "ㄔㄨㄛ", "chun": "ㄔㄨㄣ", "chua": "ㄔㄨㄚ", "chou": "ㄔㄡ", "chih": "ㄔ", "chen": "ㄔㄣ", "chao": "ㄔㄠ", "chan": "ㄔㄢ",
    "chai": "ㄔㄞ", "bing": "ㄅㄧㄥ", "biao": "ㄅㄧㄠ", "bian": "ㄅㄧㄢ", "beng": "ㄅㄥ", "bang": "ㄅㄤ",
    "cie": "ㄑㄧㄝ", "yue": "ㄩㄝ", "tie": "ㄊㄧㄝ", "sie": "ㄒㄧㄝ", "pie": "ㄆㄧㄝ", "nie": "ㄋㄧㄝ", "mie": "ㄇㄧㄝ", "lie": "ㄌㄧㄝ",
    "jie": "ㄐㄧㄝ", "die": "ㄉㄧㄝ", "cyu": "ㄑㄩ", "cuo": "ㄘㄨㄛ", "cun": "ㄘㄨㄣ", "cou": "ㄘㄡ", "cin": "ㄑㄧㄣ", "cih": "ㄘ",
    "cia": "ㄑㄧㄚ", "cen": "ㄘㄣ", "cao": "ㄘㄠ", "can": "ㄘㄢ", "cai": "ㄘㄞ", "bie": "ㄅㄧㄝ", "gin": "ㄍㄧㄣ", "den": "ㄉㄣ",
    "zuo": "ㄗㄨㄛ", "zun": "ㄗㄨㄣ", "zou": "ㄗㄡ", "zih": "ㄗ", "zen": "ㄗㄣ", "zei": "ㄗㄟ", "zao": "ㄗㄠ", "zan": "ㄗㄢ",
    "zai": "ㄗㄞ", "yun": "ㄩㄣ", "you": "ㄧㄡ", "yin": "ㄧㄣ", "yao": "ㄧㄠ", "yan": "ㄧㄢ", "yai": "ㄧㄞ", "wun": "ㄨㄣ", "wei": "ㄨㄟ",
    "wan": "ㄨㄢ", "wai": "ㄨㄞ", "tuo": "ㄊㄨㄛ", "tun": "ㄊㄨㄣ", "tou": "ㄊㄡ", "tao": "ㄊㄠ", "tan": "ㄊㄢ", "tai": "ㄊㄞ",
    "syu": "ㄒㄩ", "suo": "ㄙㄨㄛ", "sun": "ㄙㄨㄣ", "sou": "ㄙㄡ", "sin": "ㄒㄧㄣ", "sih": "ㄙ", "sia": "ㄒㄧㄚ", "shu": "ㄕㄨ",
    "she": "ㄕㄜ", "sha": "ㄕㄚ", "sen": "ㄙㄣ", "sao": "ㄙㄠ", "san": "ㄙㄢ", "sai": "ㄙㄞ", "ruo": "ㄖㄨㄛ", "run": "ㄖㄨㄣ",
    "rou": "ㄖㄡ", "rih": "ㄖ", "ren": "ㄖㄣ", "rao": "ㄖㄠ", "ran": "ㄖㄢ", "pou": "ㄆㄡ", "pin": "ㄆㄧㄣ", "pia": "ㄆㄧㄚ",
    "pen": "ㄆㄣ", "pei": "ㄆㄟ", "pao": "ㄆㄠ", "pan": "ㄆㄢ", "pai": "ㄆㄞ", "nyu": "ㄋㄩ", "nuo": "ㄋㄨㄛ", "nun": "ㄋㄨㄣ",
    "nou": "ㄋㄡ", "nin": "ㄋㄧㄣ", "nen": "ㄋㄣ", "nei": "ㄋㄟ", "nao": "ㄋㄠ", "nan": "ㄋㄢ", "nai": "ㄋㄞ", "mou": "ㄇㄡ",
    "min": "ㄇㄧㄣ", "men": "ㄇㄣ", "mei": "ㄇㄟ", "mao": "ㄇㄠ", "man": "ㄇㄢ", "mai": "ㄇㄞ", "lyu": "ㄌㄩ", "luo": "ㄌㄨㄛ",
    "lun": "ㄌㄨㄣ", "lou": "ㄌㄡ", "lin": "ㄌㄧㄣ", "lia": "ㄌㄧㄚ", "lei": "ㄌㄟ", "lao": "ㄌㄠ", "lan": "ㄌㄢ", "lai": "ㄌㄞ",
    "kuo": "ㄎㄨㄛ", "kun": "ㄎㄨㄣ", "kua": "ㄎㄨㄚ", "kou": "ㄎㄡ", "ken": "ㄎㄣ", "kao": "ㄎㄠ", "kan": "ㄎㄢ", "kai": "ㄎㄞ",
    "jyu": "ㄐㄩ", "jin": "ㄐㄧㄣ", "jia": "ㄐㄧㄚ", "jhu": "ㄓㄨ", "jhe": "ㄓㄜ", "jha": "ㄓㄚ", "huo": "ㄏㄨㄛ", "hun": "ㄏㄨㄣ",
    "hua": "ㄏㄨㄚ", "hou": "ㄏㄡ", "hen": "ㄏㄣ", "hei": "ㄏㄟ", "hao": "ㄏㄠ", "han": "ㄏㄢ", "hai": "ㄏㄞ", "guo": "ㄍㄨㄛ",
    "gun": "ㄍㄨㄣ", "gue": "ㄍㄨㄜ", "gua": "ㄍㄨㄚ", "gou": "ㄍㄡ", "gen": "ㄍㄣ", "gei": "ㄍㄟ", "gao": "ㄍㄠ", "gan": "ㄍㄢ",
    "gai": "ㄍㄞ", "fou": "ㄈㄡ", "fen": "ㄈㄣ", "fei": "ㄈㄟ", "fan": "ㄈㄢ", "eng": "ㄥ", "duo": "ㄉㄨㄛ", "dun": "ㄉㄨㄣ",
    "dou": "ㄉㄡ", "dia": "ㄉㄧㄚ", "dei": "ㄉㄟ", "dao": "ㄉㄠ", "dan": "ㄉㄢ", "dai": "ㄉㄞ", "chu": "ㄔㄨ", "che": "ㄔㄜ",
    "cha": "ㄔㄚ", "bin": "ㄅㄧㄣ", "ben": "ㄅㄣ", "bei": "ㄅㄟ", "bao": "ㄅㄠ", "ban": "ㄅㄢ", "bai": "ㄅㄞ", "ang": "ㄤ", "yia": "ㄧㄚ",
    "ye": "ㄧㄝ", "cu": "ㄘㄨ", "ci": "ㄑㄧ", "ce": "ㄘㄜ", "ca": "ㄘㄚ", "zu": "ㄗㄨ", "ze": "ㄗㄜ", "za": "ㄗㄚ", "yu": "ㄩ",
    "yo": "ㄧㄛ", "yi": "ㄧ", "wu": "ㄨ", "wo": "ㄨㄛ", "wa": "ㄨㄚ", "tu": "ㄊㄨ", "ti": "ㄊㄧ", "te": "ㄊㄜ", "ta": "ㄊㄚ",
    "su": "ㄙㄨ", "si": "ㄒㄧ", "se": "ㄙㄜ", "sa": "ㄙㄚ", "ru": "ㄖㄨ", "re": "ㄖㄜ", "pu": "ㄆㄨ", "po": "ㄆㄛ", "pi": "ㄆㄧ",
    "pa": "ㄆㄚ", "ou": "ㄡ", "nu": "ㄋㄨ", "ni": "ㄋㄧ", "ne": "ㄋㄜ", "na": "ㄋㄚ", "mu": "ㄇㄨ", "mo": "ㄇㄛ", "mi": "ㄇㄧ",
    "me": "ㄇㄜ", "ma": "ㄇㄚ", "lu": "ㄌㄨ", "lo": "ㄌㄛ", "li": "ㄌㄧ", "le": "ㄌㄜ", "la": "ㄌㄚ", "ku": "ㄎㄨ", "ke": "ㄎㄜ",
    "ka": "ㄎㄚ", "ji": "ㄐㄧ", "hu": "ㄏㄨ", "he": "ㄏㄜ", "ha": "ㄏㄚ", "gu": "ㄍㄨ", "ge": "ㄍㄜ", "ga": "ㄍㄚ", "fu": "ㄈㄨ",
    "fo": "ㄈㄛ", "fa": "ㄈㄚ", "er": "ㄦ", "en": "ㄣ", "ei": "ㄟ", "eh": "ㄝ", "du": "ㄉㄨ", "di": "ㄉㄧ", "de": "ㄉㄜ", "da": "ㄉㄚ",
    "bu": "ㄅㄨ", "bo": "ㄅㄛ", "bi": "ㄅㄧ", "ba": "ㄅㄚ", "ao": "ㄠ", "an": "ㄢ", "ai": "ㄞ",
    "c": "ㄑ", "o": "ㄛ", "e": "ㄜ", "a": "ㄚ",
  ]

  // MARK: - Maps for Keyboard-to-Phonabet parsers

  /// 標準大千排列專用處理陣列。
  ///
  /// 威注音輸入法 macOS 版使用了 Ukelele 佈局來完成對諸如倚天傳統等其它注音鍵盤排列的支援。
  /// 如果要將鐵恨模組拿給別的平台的輸入法使用的話，恐怕需要針對這些注音鍵盤排列各自新增專用陣列才可以。
  static let mapQwertyDachen: [String: String] = [
    "0": "ㄢ", "1": "ㄅ", "2": "ㄉ", "3": "ˇ", "4": "ˋ", "5": "ㄓ", "6": "ˊ", "7": "˙", "8": "ㄚ", "9": "ㄞ", "-": "ㄦ",
    ",": "ㄝ", ".": "ㄡ", "/": "ㄥ", ";": "ㄤ", "a": "ㄇ", "b": "ㄖ", "c": "ㄏ", "d": "ㄎ", "e": "ㄍ", "f": "ㄑ", "g": "ㄕ",
    "h": "ㄘ", "i": "ㄛ", "j": "ㄨ", "k": "ㄜ", "l": "ㄠ", "m": "ㄩ", "n": "ㄙ", "o": "ㄟ", "p": "ㄣ", "q": "ㄆ", "r": "ㄐ",
    "s": "ㄋ", "t": "ㄔ", "u": "ㄧ", "v": "ㄒ", "w": "ㄊ", "x": "ㄌ", "y": "ㄗ", "z": "ㄈ", " ": " ",
  ]

  /// 大千忘形排列專用處理陣列，但未包含全部的處理內容。
  ///
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapDachenCP26StaticKeys: [String: String] = [
    "a": "ㄇ", "b": "ㄖ", "c": "ㄏ", "d": "ㄎ", "e": "ㄍ", "f": "ㄑ", "g": "ㄕ", "h": "ㄘ", "i": "ㄛ", "j": "ㄨ", "k": "ㄜ",
    "l": "ㄠ", "m": "ㄩ", "n": "ㄙ", "o": "ㄟ", "p": "ㄣ", "q": "ㄆ", "r": "ㄐ", "s": "ㄋ", "t": "ㄔ", "u": "ㄧ", "v": "ㄒ",
    "w": "ㄊ", "x": "ㄌ", "y": "ㄗ", "z": "ㄈ", " ": " ",
  ]

  /// 許氏排列專用處理陣列，但未包含全部的映射內容。
  ///
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapHsuStaticKeys: [String: String] = [
    "a": "ㄘ", "b": "ㄅ", "c": "ㄒ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄍ", "h": "ㄏ", "i": "ㄞ", "j": "ㄐ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄡ", "p": "ㄆ", "r": "ㄖ", "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄔ", "w": "ㄠ",
    "x": "ㄨ", "y": "ㄚ", "z": "ㄗ", " ": " ",
  ]

  /// 倚天忘形排列預處理專用陣列，但未包含全部的映射內容。
  ///
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapETen26StaticKeys: [String: String] = [
    "a": "ㄚ", "b": "ㄅ", "c": "ㄕ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄓ", "h": "ㄏ", "i": "ㄞ", "j": "ㄖ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄛ", "p": "ㄆ", "q": "ㄗ", "r": "ㄜ", "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄍ",
    "w": "ㄘ", "x": "ㄨ", "y": "ㄔ", "z": "ㄠ", " ": " ",
  ]

  /// 星光排列預處理專用陣列，但未包含全部的映射內容。
  ///
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapStarlightStaticKeys: [String: String] = [
    "a": "ㄚ", "b": "ㄅ", "c": "ㄘ", "d": "ㄉ", "e": "ㄜ", "f": "ㄈ", "g": "ㄍ", "h": "ㄏ", "i": "ㄧ", "j": "ㄓ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄛ", "p": "ㄆ", "q": "ㄔ", "r": "ㄖ", "s": "ㄙ", "t": "ㄊ", "u": "ㄨ", "v": "ㄩ",
    "w": "ㄡ", "x": "ㄕ", "y": "ㄞ", "z": "ㄗ", " ": " ", "1": " ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙", "6": " ",
    "7": "ˊ", "8": "ˇ", "9": "ˋ", "0": "˙",
  ]

  /// 倚天傳統排列專用處理陣列。
  static let mapQwertyETenTraditional: [String: String] = [
    "'": "ㄘ", ",": "ㄓ", "-": "ㄥ", ".": "ㄔ", "/": "ㄕ", "0": "ㄤ", "1": "˙", "2": "ˊ", "3": "ˇ", "4": "ˋ", "7": "ㄑ",
    "8": "ㄢ", "9": "ㄣ", ";": "ㄗ", "=": "ㄦ", "a": "ㄚ", "b": "ㄅ", "c": "ㄒ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄐ",
    "h": "ㄏ", "i": "ㄞ", "j": "ㄖ", "k": "ㄎ", "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄛ", "p": "ㄆ", "q": "ㄟ", "r": "ㄜ",
    "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄍ", "w": "ㄝ", "x": "ㄨ", "y": "ㄡ", "z": "ㄠ", " ": " ",
  ]

  /// IBM排列專用處理陣列。
  static let mapQwertyIBM: [String: String] = [
    ",": "ˇ", "-": "ㄏ", ".": "ˋ", "/": "˙", "0": "ㄎ", "1": "ㄅ", "2": "ㄆ", "3": "ㄇ", "4": "ㄈ", "5": "ㄉ", "6": "ㄊ",
    "7": "ㄋ", "8": "ㄌ", "9": "ㄍ", ";": "ㄠ", "a": "ㄧ", "b": "ㄥ", "c": "ㄣ", "d": "ㄩ", "e": "ㄒ", "f": "ㄚ", "g": "ㄛ",
    "h": "ㄜ", "i": "ㄗ", "j": "ㄝ", "k": "ㄞ", "l": "ㄟ", "m": "ˊ", "n": "ㄦ", "o": "ㄘ", "p": "ㄙ", "q": "ㄐ", "r": "ㄓ",
    "s": "ㄨ", "t": "ㄔ", "u": "ㄖ", "v": "ㄤ", "w": "ㄑ", "x": "ㄢ", "y": "ㄕ", "z": "ㄡ", " ": " ",
  ]

  /// 精業排列專用處理陣列。
  static let mapSeigyou: [String: String] = [
    "a": "ˇ", "b": "ㄒ", "c": "ㄌ", "d": "ㄋ", "e": "ㄊ", "f": "ㄎ", "g": "ㄑ", "h": "ㄕ", "i": "ㄛ", "j": "ㄘ", "k": "ㄜ",
    "l": "ㄠ", "m": "ㄙ", "n": "ㄖ", "o": "ㄟ", "p": "ㄣ", "q": "ˊ", "r": "ㄍ", "s": "ㄇ", "t": "ㄐ", "u": "ㄗ", "v": "ㄏ",
    "w": "ㄆ", "x": "ㄈ", "y": "ㄔ", "z": "ˋ", "1": "˙", "2": "ㄅ", "3": "ㄉ", "6": "ㄓ", "8": "ㄚ", "9": "ㄞ", "0": "ㄢ",
    "-": "ㄧ", ";": "ㄤ", ",": "ㄝ", ".": "ㄡ", "/": "ㄥ", "'": "ㄩ", "[": "ㄨ", "=": "ㄦ", " ": " ",
  ]

  /// 偽精業排列專用處理陣列。
  static let mapFakeSeigyou: [String: String] = [
    "a": "ˇ", "b": "ㄒ", "c": "ㄌ", "d": "ㄋ", "e": "ㄊ", "f": "ㄎ", "g": "ㄑ", "h": "ㄕ", "i": "ㄛ", "j": "ㄘ", "k": "ㄜ",
    "l": "ㄠ", "m": "ㄙ", "n": "ㄖ", "o": "ㄟ", "p": "ㄣ", "q": "ˊ", "r": "ㄍ", "s": "ㄇ", "t": "ㄐ", "u": "ㄗ", "v": "ㄏ",
    "w": "ㄆ", "x": "ㄈ", "y": "ㄔ", "z": "ˋ", "1": "˙", "2": "ㄅ", "3": "ㄉ", "6": "ㄓ", "8": "ㄚ", "9": "ㄞ", "0": "ㄢ",
    "4": "ㄧ", ";": "ㄤ", ",": "ㄝ", ".": "ㄡ", "/": "ㄥ", "7": "ㄩ", "5": "ㄨ", "-": "ㄦ", " ": " ",
  ]

  /// 神通排列專用處理陣列。
  static let mapQwertyMiTAC: [String: String] = [
    ",": "ㄓ", "-": "ㄦ", ".": "ㄔ", "/": "ㄕ", "0": "ㄥ", "1": "˙", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "ㄞ", "6": "ㄠ",
    "7": "ㄢ", "8": "ㄣ", "9": "ㄤ", ";": "ㄝ", "a": "ㄚ", "b": "ㄅ", "c": "ㄘ", "d": "ㄉ", "e": "ㄜ", "f": "ㄈ", "g": "ㄍ",
    "h": "ㄏ", "i": "ㄟ", "j": "ㄐ", "k": "ㄎ", "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄛ", "p": "ㄆ", "q": "ㄑ", "r": "ㄖ",
    "s": "ㄙ", "t": "ㄊ", "u": "ㄡ", "v": "ㄩ", "w": "ㄨ", "x": "ㄒ", "y": "ㄧ", "z": "ㄗ", " ": " ",
  ]
}

/// 檢測字串是否包含半形英數內容
extension String {
  fileprivate var isNotPureAlphanumerical: Bool {
    let regex = ".*[^A-Za-z0-9].*"
    let testString = NSPredicate(format: "SELF MATCHES %@", regex)
    return testString.evaluate(with: self)
  }
}
