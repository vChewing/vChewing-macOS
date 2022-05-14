// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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
    case ofEten = 1
    case ofHsu = 2
    case ofEten26 = 3
    case ofIBM = 4
    case ofMiTAC = 5
    case ofFakeSeigyou = 6
    case ofSeigyou = 7
    case ofHanyuPinyin = 10  // 目前暫時沒有漢語拼音支援

    var name: String {
      switch self {
        case .ofDachen:
          return "Dachen"
        case .ofEten:
          return "ETen"
        case .ofHsu:
          return "Hsu"
        case .ofEten26:
          return "ETen26"
        case .ofIBM:
          return "IBM"
        case .ofMiTAC:
          return "MiTAC"
        case .ofFakeSeigyou:
          return "FakeSeigyou"
        case .ofSeigyou:
          return "Seigyou"
        case .ofHanyuPinyin:
          return "HanyuPinyin"
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
  public static let allowedsemivowels = ["ㄧ", "ㄨ", "ㄩ"]

  /// 引擎僅接受這些記號作為韻母
  public static let allowedVowels = [
    "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ",
    "ㄠ", "ㄡ", "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
  ]

  /// 引擎僅接受這些記號作為聲調
  public static let allowedIntonations = [" ", "ˊ", "ˇ", "ˋ", "˙"]

  /// 引擎僅接受這些記號作為注音（聲介韻調四個集合加起來）
  public static var allowedPhonabets: [String] {
    allowedConsonants + allowedsemivowels + allowedVowels + allowedIntonations
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
          if Tekkon.allowedConsonants.contains(value) {
            type = .consonant
          } else if Tekkon.allowedsemivowels.contains(value) {
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
      }
    }

    /// 自我清空內容。
    public mutating func clear() {
      valueStorage = ""
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
  /// @--DISCUSSION--@
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

    /// 注音排列種類。預設情況下是大千排列（Windows / macOS 預設注音排列）。
    public var parser: MandarinParser = .ofDachen

    /// 內容值，會直接按照正確的順序拼裝自己的聲介韻調內容、再回傳。
    /// 注意：直接取這個參數的內容的話，陰平聲調會成為一個空格。
    /// 如果是要取不帶空格的注音的話，請使用「.realComposition」而非「.value」。
    public var value: String {
      consonant.value + semivowel.value + vowel.value + intonation.value
    }

    /// 這是專門用來「生成用以進行詞庫檢索的 Key」的函數。
    public var realComposition: String {
      value.replacingOccurrences(of: " ", with: "")
    }

    /// 與 value 類似。這個函數就是用來決定輸入法組字區內顯示的注音/拼音內容。
    /// 但可以指定是否輸出教科書格式（拼音的調號在字母上方、注音的輕聲寫在左側）。
    public func getComposition(isHanyuPinyin: Bool = false, isTextBookStyle: Bool = false) -> String {
      switch isHanyuPinyin {
        case false:
          var valReturnZhuyin = value.replacingOccurrences(of: " ", with: "")
          if isTextBookStyle, valReturnZhuyin.contains("˙") {
            valReturnZhuyin = String(valReturnZhuyin.dropLast())
            valReturnZhuyin.insert("˙", at: valReturnZhuyin.startIndex)
          }
          return valReturnZhuyin
        case true:
          var valReturnPinyin = Tekkon.cnvPhonaToHanyuPinyin(target: value)
          if isTextBookStyle {
            valReturnPinyin = Tekkon.cnvHanyuPinyinToTextbookStyle(target: valReturnPinyin)
          }
          return valReturnPinyin
      }
    }

    /// 注拼槽內容是否為空。
    public var isEmpty: Bool {
      intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
    }

    // MARK: 注拼槽對外處理函數

    /// 初期化一個新的注拼槽。可以藉由 @input 參數指定初期已經傳入的按鍵訊號。
    /// 還可以在初期化時藉由 @arrange 參數來指定注音排列（預設為「.ofDachen」大千佈局）。
    public init(_ input: String = "", arrange parser: MandarinParser = .ofDachen) {
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
    }

    // MARK: - Public Functions

    /// 用於檢測「某個輸入字符訊號的合規性」的函數。
    /// @--DISCUSSION--@
    /// 注意：回傳結果會受到當前注音排列 parser 屬性的影響。
    /// - Parameters:
    ///   - key: 傳入的 UniChar 內容。
    public func inputValidityCheck(key inputKey: UniChar = 0) -> Bool {
      if let scalar = UnicodeScalar(inputKey) {
        let input = String(scalar)
        switch parser {
          case .ofDachen:
            return Tekkon.mapQwertyDachen[input] != nil
          case .ofEten:
            return Tekkon.mapQwertyEtenTraditional[input] != nil
          case .ofHsu:
            return Tekkon.mapHsuStaticKeys[input] != nil
          case .ofEten26:
            return Tekkon.mapEten26StaticKeys[input] != nil
          case .ofIBM:
            return Tekkon.mapQwertyIBM[input] != nil
          case .ofMiTAC:
            return Tekkon.mapQwertyMiTAC[input] != nil
          case .ofSeigyou:
            return Tekkon.mapSeigyou[input] != nil
          case .ofFakeSeigyou:
            return Tekkon.mapFakeSeigyou[input] != nil
          case .ofHanyuPinyin:
            return Tekkon.mapArayuruPinyin.contains(input)
        }
      }
      return false
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 String。
    /// 另有同名函數可處理 UniChar 訊號。
    /// @--DISCUSSION--@
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromString: 傳入的 String 內容。
    public mutating func receiveKey(fromString input: String = "") {
      let translatedInput = translate(key: String(input))
      let thePhone: Phonabet = .init(translatedInput)
      switch thePhone.type {
        case .consonant: consonant = thePhone
        case .semivowel: semivowel = thePhone
        case .vowel: vowel = thePhone
        case .intonation: intonation = thePhone
        default: break
      }
    }

    /// 接受傳入的按鍵訊號時的處理，處理對象為 UniChar。
    /// 其實也就是先將 UniChar 轉為 String 再交給某個同名異參的函數來處理而已。
    /// @--DISCUSSION--@
    /// 如果是諸如複合型注音排列的話，翻譯結果有可能為空，但翻譯過程已經處理好聲介韻調分配了。
    /// - Parameters:
    ///   - fromCharCode: 傳入的 UniChar 內容。
    public mutating func receiveKey(fromCharCode inputCharCode: UniChar = 0) {
      if let scalar = UnicodeScalar(inputCharCode) {
        receiveKey(fromString: String(scalar))
      }
    }

    /// 專門用來響應使用者摁下 BackSpace 按鍵時的行為。
    /// 刪除順序：調、韻、介、聲。
    /// @--DISCUSSION--@
    /// 基本上就是按順序從游標前方開始往後刪。
    public mutating func doBackSpace() {
      if !intonation.isEmpty {
        intonation.clear()
      } else if !vowel.isEmpty {
        vowel.clear()
      } else if !semivowel.isEmpty {
        semivowel.clear()
      } else if !consonant.isEmpty {
        consonant.clear()
      }
    }

    /// 用來檢測是否有調號的函數，預設情況下不判定聲調以外的內容的存無。
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

    // 注拼槽對內處理用函數都在這一小節。

    /// 根據目前的注音排列設定來翻譯傳入的 String 訊號。
    /// @--DISCUSSION--@
    /// 倚天或許氏鍵盤的處理函數會將分配過程代為處理過，此時回傳結果為空字串。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    mutating func translate(key: String = "") -> String {
      switch parser {
        case .ofDachen:
          return Tekkon.mapQwertyDachen[key] ?? ""
        case .ofEten:
          return Tekkon.mapQwertyEtenTraditional[key] ?? ""
        case .ofHsu:
          return handleHsu(key: key)
        case .ofEten26:
          return handleEten26(key: key)
        case .ofIBM:
          return Tekkon.mapQwertyIBM[key] ?? ""
        case .ofMiTAC:
          return Tekkon.mapQwertyMiTAC[key] ?? ""
        case .ofSeigyou:
          return Tekkon.mapSeigyou[key] ?? ""
        case .ofFakeSeigyou:
          return Tekkon.mapFakeSeigyou[key] ?? ""
        case .ofHanyuPinyin: break  // TODO: 待辦
      }
      return ""
    }

    /// 倚天忘形注音排列比較麻煩，需要單獨處理。
    /// @--DISCUSSION--@
    /// 回傳結果是空字串的話，不要緊，因為該函數內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    mutating func handleEten26(key: String = "") -> String {
      var strReturn = ""
      strReturn = Tekkon.mapEten26StaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)

      switch key {
        case "d": if consonant.isEmpty { consonant = "ㄉ" } else { intonation = "˙" }
        case "f": if consonant.isEmpty { consonant = "ㄈ" } else { intonation = "ˊ" }
        case "h": if consonant.isEmpty { consonant = "ㄏ" } else { vowel = "ㄦ" }
        case "j": if consonant.isEmpty { consonant = "ㄖ" } else { intonation = "ˇ" }
        case "k": if consonant.isEmpty { consonant = "ㄎ" } else { intonation = "ˋ" }
        case "l": if consonant.isEmpty { consonant = "ㄌ" } else { vowel = "ㄥ" }
        case "m": if consonant.isEmpty { consonant = "ㄇ" } else { vowel = "ㄢ" }
        case "n": if consonant.isEmpty { consonant = "ㄋ" } else { vowel = "ㄣ" }
        case "p": if consonant.isEmpty { consonant = "ㄆ" } else { vowel = "ㄡ" }
        case "q": if consonant.isEmpty { consonant = "ㄗ" } else { vowel = "ㄟ" }
        case "t": if consonant.isEmpty { consonant = "ㄊ" } else { vowel = "ㄤ" }
        case "w": if consonant.isEmpty { consonant = "ㄘ" } else { vowel = "ㄝ" }
        default: break
      }

      // 處理「一個按鍵對應兩個聲母」的情形。
      if !consonant.isEmpty, incomingPhonabet.type == .semivowel {
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
          case "ㄕ":
            switch incomingPhonabet {
              case "ㄧ": consonant = "ㄒ"  // ㄒㄧ
              case "ㄨ": consonant = "ㄕ"  // ㄕㄨ
              case "ㄩ": consonant = "ㄒ"  // ㄒㄩ
              default: break
            }
          default: break
        }
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "dfhjklmnpqtw".contains(key) { strReturn = "" }

      // 回傳結果是空字串的話，不要緊，因為上文已經代處理過分配過程了。
      return strReturn
    }

    /// 許氏鍵盤與倚天忘形一樣同樣也比較麻煩，需要單獨處理。
    /// @--DISCUSSION--@
    /// 回傳結果是空的話，不要緊，因為該函數內部已經處理過分配過程了。
    /// - Parameters:
    ///   - key: 傳入的 String 訊號。
    mutating func handleHsu(key: String = "") -> String {
      var strReturn = ""
      strReturn = Tekkon.mapHsuStaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)

      switch key {
        case "a": if consonant.isEmpty { consonant = "ㄘ" } else { vowel = "ㄟ" }
        case "d": if consonant.isEmpty { consonant = "ㄉ" } else { intonation = "ˊ" }
        case "e": if semivowel.isEmpty { semivowel = "ㄧ" } else { vowel = "ㄝ" }
        case "f": if consonant.isEmpty { consonant = "ㄈ" } else { intonation = "ˇ" }
        case "g": if consonant.isEmpty { consonant = "ㄍ" } else { vowel = "ㄜ" }
        case "h": if consonant.isEmpty { consonant = "ㄏ" } else { vowel = "ㄛ" }
        case "k": if consonant.isEmpty { consonant = "ㄎ" } else { vowel = "ㄤ" }
        case "l":
          if value.isEmpty, !consonant.isEmpty, !semivowel.isEmpty {
            vowel = "ㄦ"
          } else if consonant.isEmpty {
            consonant = "ㄌ"
          } else {
            vowel = "ㄥ"
          }
        case "m": if consonant.isEmpty { consonant = "ㄇ" } else { vowel = "ㄢ" }
        case "n": if consonant.isEmpty { consonant = "ㄋ" } else { vowel = "ㄣ" }
        case "s": if consonant.isEmpty { consonant = "ㄙ" } else { intonation = "˙" }
        default: break
      }
      // 處理「一個按鍵對應兩個聲母」的情形。
      if !consonant.isEmpty, incomingPhonabet.type == .semivowel {
        switch consonant {
          case "ㄍ":  // 許氏鍵盤應該也需要這個自動糾正
            switch incomingPhonabet {
              case "ㄧ": consonant = "ㄑ"  // ㄑㄧ
              case "ㄨ": consonant = "ㄍ"  // ㄍㄨ
              case "ㄩ": consonant = "ㄑ"  // ㄑㄩ
              default: break
            }
          case "ㄓ":
            if intonation.isEmpty {
              switch incomingPhonabet {
                case "ㄧ": consonant = "ㄐ"  // ㄐㄧ
                case "ㄨ": consonant = "ㄓ"  // ㄓㄨ
                case "ㄩ": consonant = "ㄐ"  // ㄐㄩ
                default: break
              }
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
      }

      if key == "j" {  // 對該按鍵作為調號的處理得放在最後
        if !consonant.isEmpty { intonation = "ˋ" }
      }

      // 這些按鍵在上文處理過了，就不要再回傳了。
      if "adefghklmns".contains(key) { strReturn = "" }

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

  // MARK: - Phonabets (Enum)

  /// 該 Enum 羅列了所有合理的注音符號，將來做漢語拼音功能支援時可能會用到。
  enum Phonabets: Phonabet {
    case ofBO = "ㄅ"
    case ofPO = "ㄆ"
    case ofMO = "ㄇ"
    case ofFO = "ㄈ"
    case ofDE = "ㄉ"
    case ofTE = "ㄊ"
    case ofNE = "ㄋ"
    case ofLE = "ㄌ"
    case ofGE = "ㄍ"
    case ofKE = "ㄎ"
    case ofHE = "ㄏ"
    case ofJI = "ㄐ"
    case ofQI = "ㄑ"
    case ofXI = "ㄒ"
    case ofZH = "ㄓ"
    case ofCH = "ㄔ"
    case ofSH = "ㄕ"
    case ofRI = "ㄖ"
    case ofZI = "ㄗ"
    case ofCI = "ㄘ"
    case ofSI = "ㄙ"
    case ofYI = "ㄧ"
    case ofWU = "ㄨ"
    case ofYU = "ㄩ"
    case ofAA = "ㄚ"
    case ofOO = "ㄛ"
    case ofEE = "ㄜ"
    case ofEA = "ㄝ"
    case ofAI = "ㄞ"
    case ofEI = "ㄟ"
    case ofAO = "ㄠ"
    case ofOU = "ㄡ"
    case ofAN = "ㄢ"
    case ofEN = "ㄣ"
    case ofAG = "ㄤ"
    case ofOG = "ㄥ"
    case ofT1 = " "
    case ofT2 = "ˊ"
    case ofT3 = "ˇ"
    case ofT4 = "ˋ"
    case ofT5 = "˙"
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

  static func cnvHanyuPinyinToTextbookStyle(target: String) -> String {
    var targetConverted = target
    for pair in arrHanyuPinyinTextbookStyleConversionTable {
      targetConverted = targetConverted.replacingOccurrences(of: pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 原始轉換對照表資料貯存專用佇列（數字標調格式）
  static let arrPhonaToHanyuPinyin = [  // 排序很重要。先處理最長的，再處理短的。不然會出亂子。
    [" ", "1"], ["ˊ", "2"], ["ˇ", "3"], ["ˋ", "4"], ["˙", "5"], ["ㄔㄨㄤ", "chuang"], ["ㄕㄨㄤ", "shuang"],
    ["ㄓㄨㄤ", "zhuang"], ["ㄔㄨㄥ", "chong"], ["ㄔㄨㄞ", "chuai"], ["ㄔㄨㄢ", "chuan"], ["ㄍㄨㄤ", "guang"], ["ㄏㄨㄤ", "huang"],
    ["ㄐㄧㄤ", "jiang"], ["ㄐㄩㄥ", "jiong"], ["ㄎㄨㄤ", "kuang"], ["ㄌㄧㄤ", "liang"], ["ㄋㄧㄤ", "niang"], ["ㄑㄧㄤ", "qiang"],
    ["ㄑㄩㄥ", "qiong"], ["ㄕㄨㄞ", "shuai"], ["ㄕㄨㄢ", "shuan"], ["ㄒㄧㄤ", "xiang"], ["ㄒㄩㄥ", "xiong"], ["ㄓㄨㄥ", "zhong"],
    ["ㄓㄨㄞ", "zhuai"], ["ㄓㄨㄢ", "zhuan"], ["ㄅㄧㄢ", "bian"], ["ㄅㄧㄠ", "biao"], ["ㄅㄧㄥ", "bing"], ["ㄔㄨㄚ", "chua"],
    ["ㄔㄨㄟ", "chui"], ["ㄔㄨㄣ", "chun"], ["ㄔㄨㄛ", "chuo"], ["ㄘㄨㄥ", "cong"], ["ㄘㄨㄢ", "cuan"], ["ㄉㄧㄢ", "dian"],
    ["ㄉㄧㄠ", "diao"], ["ㄉㄧㄥ", "ding"], ["ㄉㄨㄥ", "dong"], ["ㄉㄨㄢ", "duan"], ["ㄈㄧㄠ", "fiao"], ["ㄍㄧㄠ", "giao"],
    ["ㄍㄧㄣ", "gin"], ["ㄍㄨㄥ", "gong"], ["ㄍㄨㄞ", "guai"], ["ㄍㄨㄢ", "guan"], ["ㄏㄨㄥ", "hong"], ["ㄏㄨㄞ", "huai"],
    ["ㄏㄨㄢ", "huan"], ["ㄐㄧㄢ", "jian"], ["ㄐㄧㄠ", "jiao"], ["ㄐㄧㄥ", "jing"], ["ㄐㄩㄢ", "juan"], ["ㄎㄧㄡ", "kiu"],
    ["ㄎㄨㄥ", "kong"], ["ㄎㄨㄞ", "kuai"], ["ㄎㄨㄢ", "kuan"], ["ㄌㄧㄢ", "lian"], ["ㄌㄧㄠ", "liao"], ["ㄌㄧㄥ", "ling"],
    ["ㄌㄨㄥ", "long"], ["ㄌㄨㄢ", "luan"], ["ㄌㄩㄢ", "lvan"], ["ㄇㄧㄢ", "mian"], ["ㄇㄧㄠ", "miao"], ["ㄇㄧㄥ", "ming"],
    ["ㄋㄧㄢ", "nian"], ["ㄋㄧㄠ", "niao"], ["ㄋㄧㄥ", "ning"], ["ㄋㄨㄥ", "nong"], ["ㄋㄨㄢ", "nuan"], ["ㄆㄧㄢ", "pian"],
    ["ㄆㄧㄠ", "piao"], ["ㄆㄧㄥ", "ping"], ["ㄑㄧㄢ", "qian"], ["ㄑㄧㄠ", "qiao"], ["ㄑㄧㄥ", "qing"], ["ㄑㄩㄢ", "quan"],
    ["ㄖㄨㄥ", "rong"], ["ㄖㄨㄢ", "ruan"], ["ㄕㄨㄚ", "shua"], ["ㄕㄨㄟ", "shui"], ["ㄕㄨㄣ", "shun"], ["ㄕㄨㄛ", "shuo"],
    ["ㄙㄨㄥ", "song"], ["ㄙㄨㄢ", "suan"], ["ㄊㄧㄢ", "tian"], ["ㄊㄧㄠ", "tiao"], ["ㄊㄧㄥ", "ting"], ["ㄊㄨㄥ", "tong"],
    ["ㄊㄨㄢ", "tuan"], ["ㄒㄧㄢ", "xian"], ["ㄒㄧㄠ", "xiao"], ["ㄒㄧㄥ", "xing"], ["ㄒㄩㄢ", "xuan"], ["ㄓㄨㄚ", "zhua"],
    ["ㄓㄨㄟ", "zhui"], ["ㄓㄨㄣ", "zhun"], ["ㄓㄨㄛ", "zhuo"], ["ㄗㄨㄥ", "zong"], ["ㄗㄨㄢ", "zuan"], ["ㄈㄨㄥ", "fong"],
    ["ㄐㄩㄣ", "jun"], ["ㄅㄧㄝ", "bie"], ["ㄅㄧㄣ", "bin"], ["ㄘㄨㄟ", "cui"], ["ㄘㄨㄣ", "cun"], ["ㄘㄨㄛ", "cuo"], ["ㄉㄧㄚ", "dia"],
    ["ㄉㄧㄝ", "die"], ["ㄉㄧㄡ", "diu"], ["ㄉㄨㄟ", "dui"], ["ㄉㄨㄣ", "dun"], ["ㄉㄨㄛ", "duo"], ["ㄍㄨㄚ", "gua"], ["ㄍㄨㄜ", "gue"],
    ["ㄍㄨㄟ", "gui"], ["ㄍㄨㄣ", "gun"], ["ㄍㄨㄛ", "guo"], ["ㄏㄨㄚ", "hua"], ["ㄏㄨㄟ", "hui"], ["ㄏㄨㄣ", "hun"], ["ㄏㄨㄛ", "huo"],
    ["ㄐㄧㄚ", "jia"], ["ㄐㄧㄝ", "jie"], ["ㄐㄧㄣ", "jin"], ["ㄐㄧㄡ", "jiu"], ["ㄐㄩㄝ", "jue"], ["ㄎㄨㄚ", "kua"], ["ㄎㄨㄟ", "kui"],
    ["ㄎㄨㄣ", "kun"], ["ㄎㄨㄛ", "kuo"], ["ㄌㄧㄚ", "lia"], ["ㄌㄧㄝ", "lie"], ["ㄌㄧㄣ", "lin"], ["ㄌㄧㄡ", "liu"], ["ㄌㄨㄣ", "lun"],
    ["ㄌㄨㄛ", "luo"], ["ㄌㄩㄝ", "lve"], ["ㄇㄧㄝ", "mie"], ["ㄇㄧㄣ", "min"], ["ㄇㄧㄡ", "miu"], ["ㄋㄧㄝ", "nie"], ["ㄋㄧㄣ", "nin"],
    ["ㄋㄧㄡ", "niu"], ["ㄋㄨㄟ", "nui"], ["ㄋㄨㄣ", "nun"], ["ㄋㄨㄛ", "nuo"], ["ㄋㄩㄝ", "nve"], ["ㄆㄧㄚ", "pia"], ["ㄆㄧㄝ", "pie"],
    ["ㄆㄧㄣ", "pin"], ["ㄑㄧㄚ", "qia"], ["ㄑㄧㄝ", "qie"], ["ㄑㄧㄣ", "qin"], ["ㄑㄧㄡ", "qiu"], ["ㄑㄩㄝ", "que"], ["ㄑㄩㄣ", "qun"],
    ["ㄖㄨㄟ", "rui"], ["ㄖㄨㄣ", "run"], ["ㄖㄨㄛ", "ruo"], ["ㄙㄨㄟ", "sui"], ["ㄙㄨㄣ", "sun"], ["ㄙㄨㄛ", "suo"], ["ㄊㄧㄝ", "tie"],
    ["ㄊㄨㄟ", "tui"], ["ㄊㄨㄣ", "tun"], ["ㄊㄨㄛ", "tuo"], ["ㄒㄧㄚ", "xia"], ["ㄒㄧㄝ", "xie"], ["ㄒㄧㄣ", "xin"], ["ㄒㄧㄡ", "xiu"],
    ["ㄒㄩㄝ", "xue"], ["ㄒㄩㄣ", "xun"], ["ㄗㄨㄟ", "zui"], ["ㄗㄨㄣ", "zun"], ["ㄗㄨㄛ", "zuo"], ["ㄘㄟ", "cei"], ["ㄔㄤ", "chang"],
    ["ㄔㄥ", "cheng"], ["ㄕㄤ", "shang"], ["ㄕㄥ", "sheng"], ["ㄓㄤ", "zhang"], ["ㄓㄥ", "zheng"], ["ㄅㄤ", "bang"],
    ["ㄅㄥ", "beng"], ["ㄘㄤ", "cang"], ["ㄘㄥ", "ceng"], ["ㄔㄞ", "chai"], ["ㄔㄢ", "chan"], ["ㄔㄠ", "chao"], ["ㄔㄣ", "chen"],
    ["ㄔㄡ", "chou"], ["ㄉㄤ", "dang"], ["ㄉㄥ", "deng"], ["ㄈㄤ", "fang"], ["ㄈㄥ", "feng"], ["ㄍㄤ", "gang"], ["ㄍㄥ", "geng"],
    ["ㄏㄤ", "hang"], ["ㄏㄥ", "heng"], ["ㄎㄤ", "kang"], ["ㄎㄥ", "keng"], ["ㄌㄤ", "lang"], ["ㄌㄥ", "leng"], ["ㄇㄤ", "mang"],
    ["ㄇㄥ", "meng"], ["ㄋㄤ", "nang"], ["ㄋㄥ", "neng"], ["ㄆㄤ", "pang"], ["ㄆㄥ", "peng"], ["ㄖㄤ", "rang"], ["ㄖㄥ", "reng"],
    ["ㄙㄤ", "sang"], ["ㄙㄥ", "seng"], ["ㄕㄞ", "shai"], ["ㄕㄢ", "shan"], ["ㄕㄠ", "shao"], ["ㄕㄟ", "shei"], ["ㄕㄣ", "shen"],
    ["ㄕㄡ", "shou"], ["ㄊㄤ", "tang"], ["ㄊㄥ", "teng"], ["ㄨㄤ", "wang"], ["ㄨㄥ", "weng"], ["ㄧㄤ", "yang"], ["ㄧㄥ", "ying"],
    ["ㄩㄥ", "yong"], ["ㄩㄢ", "yuan"], ["ㄗㄤ", "zang"], ["ㄗㄥ", "zeng"], ["ㄓㄞ", "zhai"], ["ㄓㄢ", "zhan"], ["ㄓㄠ", "zhao"],
    ["ㄓㄟ", "zhei"], ["ㄓㄣ", "zhen"], ["ㄓㄡ", "zhou"], ["ㄅㄞ", "bai"], ["ㄅㄢ", "ban"], ["ㄅㄠ", "bao"], ["ㄅㄟ", "bei"],
    ["ㄅㄣ", "ben"], ["ㄘㄞ", "cai"], ["ㄘㄢ", "can"], ["ㄘㄠ", "cao"], ["ㄘㄣ", "cen"], ["ㄔㄚ", "cha"], ["ㄔㄜ", "che"],
    ["ㄔㄨ", "chu"], ["ㄘㄡ", "cou"], ["ㄉㄞ", "dai"], ["ㄉㄢ", "dan"], ["ㄉㄠ", "dao"], ["ㄉㄟ", "dei"], ["ㄉㄣ", "den"],
    ["ㄉㄡ", "dou"], ["ㄈㄢ", "fan"], ["ㄈㄟ", "fei"], ["ㄈㄣ", "fen"], ["ㄈㄡ", "fou"], ["ㄍㄞ", "gai"], ["ㄍㄢ", "gan"],
    ["ㄍㄠ", "gao"], ["ㄍㄟ", "gei"], ["ㄍㄣ", "gen"], ["ㄍㄡ", "gou"], ["ㄏㄞ", "hai"], ["ㄏㄢ", "han"], ["ㄏㄠ", "hao"],
    ["ㄏㄟ", "hei"], ["ㄏㄣ", "hen"], ["ㄏㄡ", "hou"], ["ㄎㄞ", "kai"], ["ㄎㄢ", "kan"], ["ㄎㄠ", "kao"], ["ㄎㄣ", "ken"],
    ["ㄎㄡ", "kou"], ["ㄌㄞ", "lai"], ["ㄌㄢ", "lan"], ["ㄌㄠ", "lao"], ["ㄌㄟ", "lei"], ["ㄌㄡ", "lou"], ["ㄇㄞ", "mai"],
    ["ㄇㄢ", "man"], ["ㄇㄠ", "mao"], ["ㄇㄟ", "mei"], ["ㄇㄣ", "men"], ["ㄇㄡ", "mou"], ["ㄋㄞ", "nai"], ["ㄋㄢ", "nan"],
    ["ㄋㄠ", "nao"], ["ㄋㄟ", "nei"], ["ㄋㄣ", "nen"], ["ㄋㄡ", "nou"], ["ㄆㄞ", "pai"], ["ㄆㄢ", "pan"], ["ㄆㄠ", "pao"],
    ["ㄆㄟ", "pei"], ["ㄆㄣ", "pen"], ["ㄆㄡ", "pou"], ["ㄖㄢ", "ran"], ["ㄖㄠ", "rao"], ["ㄖㄣ", "ren"], ["ㄖㄡ", "rou"],
    ["ㄙㄞ", "sai"], ["ㄙㄢ", "san"], ["ㄙㄠ", "sao"], ["ㄙㄟ", "sei"], ["ㄙㄣ", "sen"], ["ㄕㄚ", "sha"], ["ㄕㄜ", "she"],
    ["ㄕㄨ", "shu"], ["ㄙㄡ", "sou"], ["ㄊㄞ", "tai"], ["ㄊㄢ", "tan"], ["ㄊㄠ", "tao"], ["ㄊㄡ", "tou"], ["ㄨㄞ", "wai"],
    ["ㄨㄢ", "wan"], ["ㄨㄟ", "wei"], ["ㄨㄣ", "wen"], ["ㄧㄞ", "yai"], ["ㄧㄢ", "yan"], ["ㄧㄠ", "yao"], ["ㄧㄣ", "yin"],
    ["ㄧㄡ", "you"], ["ㄩㄝ", "yue"], ["ㄩㄣ", "yun"], ["ㄗㄞ", "zai"], ["ㄗㄢ", "zan"], ["ㄗㄠ", "zao"], ["ㄗㄟ", "zei"],
    ["ㄗㄣ", "zen"], ["ㄓㄚ", "zha"], ["ㄓㄜ", "zhe"], ["ㄓㄨ", "zhu"], ["ㄗㄡ", "zou"], ["ㄅㄚ", "ba"], ["ㄅㄧ", "bi"],
    ["ㄅㄛ", "bo"], ["ㄅㄨ", "bu"], ["ㄘㄚ", "ca"], ["ㄘㄜ", "ce"], ["ㄘㄨ", "cu"], ["ㄉㄚ", "da"], ["ㄉㄜ", "de"], ["ㄉㄧ", "di"],
    ["ㄉㄨ", "du"], ["ㄈㄚ", "fa"], ["ㄈㄛ", "fo"], ["ㄈㄨ", "fu"], ["ㄍㄚ", "ga"], ["ㄍㄜ", "ge"], ["ㄍㄧ", "gi"], ["ㄍㄨ", "gu"],
    ["ㄏㄚ", "ha"], ["ㄏㄜ", "he"], ["ㄏㄨ", "hu"], ["ㄐㄧ", "ji"], ["ㄐㄩ", "ju"], ["ㄎㄚ", "ka"], ["ㄎㄜ", "ke"], ["ㄎㄨ", "ku"],
    ["ㄌㄚ", "la"], ["ㄌㄜ", "le"], ["ㄌㄧ", "li"], ["ㄌㄛ", "lo"], ["ㄌㄨ", "lu"], ["ㄌㄩ", "lv"], ["ㄇㄚ", "ma"], ["ㄇㄜ", "me"],
    ["ㄇㄧ", "mi"], ["ㄇㄛ", "mo"], ["ㄇㄨ", "mu"], ["ㄋㄚ", "na"], ["ㄋㄜ", "ne"], ["ㄋㄧ", "ni"], ["ㄋㄨ", "nu"], ["ㄋㄩ", "nv"],
    ["ㄆㄚ", "pa"], ["ㄆㄧ", "pi"], ["ㄆㄛ", "po"], ["ㄆㄨ", "pu"], ["ㄑㄧ", "qi"], ["ㄑㄩ", "qu"], ["ㄖㄜ", "re"], ["ㄖㄨ", "ru"],
    ["ㄙㄚ", "sa"], ["ㄙㄜ", "se"], ["ㄙㄨ", "su"], ["ㄊㄚ", "ta"], ["ㄊㄜ", "te"], ["ㄊㄧ", "ti"], ["ㄊㄨ", "tu"], ["ㄨㄚ", "wa"],
    ["ㄨㄛ", "wo"], ["ㄒㄧ", "xi"], ["ㄒㄩ", "xu"], ["ㄧㄚ", "ya"], ["ㄧㄝ", "ye"], ["ㄧㄛ", "yo"], ["ㄗㄚ", "za"], ["ㄗㄜ", "ze"],
    ["ㄗㄨ", "zu"], ["ㄅ", "b"], ["ㄆ", "p"], ["ㄇ", "m"], ["ㄈ", "f"], ["ㄉ", "d"], ["ㄊ", "t"], ["ㄋ", "n"],
    ["ㄌ", "l"], ["ㄍ", "g"], ["ㄎ", "k"], ["ㄏ", "h"], ["ㄐ", "j"], ["ㄑ", "q"], ["ㄒ", "x"], ["ㄓ", "zhi"],
    ["ㄔ", "chi"], ["ㄕ", "shi"], ["ㄖ", "ri"], ["ㄗ", "zi"], ["ㄘ", "ci"], ["ㄙ", "si"], ["ㄚ", "a"], ["ㄛ", "o"], ["ㄜ", "e"],
    ["ㄝ", "eh"], ["ㄞ", "ai"], ["ㄟ", "ei"], ["ㄠ", "ao"], ["ㄡ", "ou"], ["ㄢ", "an"], ["ㄣ", "en"], ["ㄤ", "ang"],
    ["ㄥ", "eng"], ["ㄦ", "er"], ["ㄧ", "yi"], ["ㄨ", "wu"], ["ㄩ", "yu"],
  ]

  /// 漢語拼音韻母轉換對照表資料貯存專用佇列
  static let arrHanyuPinyinTextbookStyleConversionTable = [  // 排序很重要。先處理最長的，再處理短的。不然會出亂子。
    ["iang1", "iāng"], ["iang2", "iáng"], ["iang3", "iǎng"], ["iang4", "iàng"], ["iong1", "iōng"], ["iong2", "ióng"],
    ["iong3", "iǒng"], ["iong4", "iòng"], ["uang1", "uāng"], ["uang2", "uáng"], ["uang3", "uǎng"], ["uang4", "uàng"],
    ["uang5", "uang"], ["ang1", "āng"], ["ang2", "áng"], ["ang3", "ǎng"], ["ang4", "àng"], ["ang5", "ang"],
    ["eng1", "ēng"], ["eng2", "éng"], ["eng3", "ěng"], ["eng4", "èng"], ["ian1", "iān"], ["ian2", "ián"],
    ["ian3", "iǎn"], ["ian4", "iàn"], ["iao1", "iāo"], ["iao2", "iáo"], ["iao3", "iǎo"], ["iao4", "iào"],
    ["ing1", "īng"], ["ing2", "íng"], ["ing3", "ǐng"], ["ing4", "ìng"], ["ong1", "ōng"], ["ong2", "óng"],
    ["ong3", "ǒng"], ["ong4", "òng"], ["uai1", "uāi"], ["uai2", "uái"], ["uai3", "uǎi"], ["uai4", "uài"],
    ["uan1", "uān"], ["uan2", "uán"], ["uan3", "uǎn"], ["uan4", "uàn"], ["van2", "üán"], ["van3", "üǎn"],
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
    ["ve3", "üě"], ["ve4", "üè"], ["a1", "ā"], ["a2", "á"], ["a3", "ǎ"], ["a4", "à"], ["a5", "a"], ["e1", "ē"],
    ["e2", "é"], ["e3", "ě"], ["e4", "è"], ["e5", "e"], ["i1", "ī"], ["i2", "í"], ["i3", "ǐ"], ["i4", "ì"],
    ["i5", "i"], ["o1", "ō"], ["o2", "ó"], ["o3", "ǒ"], ["o4", "ò"], ["o5", "o"], ["u1", "ū"], ["u2", "ú"],
    ["u3", "ǔ"], ["u4", "ù"], ["v1", "ǖ"], ["v2", "ǘ"], ["v3", "ǚ"], ["v4", "ǜ"],
  ]

  // MARK: - Maps for Keyboard-to-Phonabet parsers

  /// 任何形式的拼音排列都會用到的陣列，用 Strings 反而省事一些。
  static let mapArayuruPinyin: String = "abcdefghijklmnopqrstuvwxyz12345 "

  /// 標準大千排列專用處理陣列。
  /// @--DISCUSSION--@
  /// 威注音輸入法 macOS 版使用了 Ukelele 佈局來完成對諸如倚天傳統等其它注音鍵盤排列的支援。
  /// 如果要將鐵恨模組拿給別的平台的輸入法使用的話，恐怕需要針對這些注音鍵盤排列各自新增專用陣列才可以。
  static let mapQwertyDachen: [String: String] = [
    "0": "ㄢ", "1": "ㄅ", "2": "ㄉ", "3": "ˇ", "4": "ˋ", "5": "ㄓ", "6": "ˊ", "7": "˙", "8": "ㄚ", "9": "ㄞ", "-": "ㄦ",
    ",": "ㄝ", ".": "ㄡ", "/": "ㄥ", ";": "ㄤ", "a": "ㄇ", "b": "ㄖ", "c": "ㄏ", "d": "ㄎ", "e": "ㄍ", "f": "ㄑ", "g": "ㄕ",
    "h": "ㄘ", "i": "ㄛ", "j": "ㄨ", "k": "ㄜ", "l": "ㄠ", "m": "ㄩ", "n": "ㄙ", "o": "ㄟ", "p": "ㄣ", "q": "ㄆ", "r": "ㄐ",
    "s": "ㄋ", "t": "ㄔ", "u": "ㄧ", "v": "ㄒ", "w": "ㄊ", "x": "ㄌ", "y": "ㄗ", "z": "ㄈ", " ": " ",
  ]

  /// 許氏排列專用處理陣列，但未包含全部的映射內容。
  /// @--DISCUSSION--@
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapHsuStaticKeys: [String: String] = [
    "a": "ㄘ", "b": "ㄅ", "c": "ㄕ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄍ", "h": "ㄏ", "i": "ㄞ", "j": "ㄓ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄡ", "p": "ㄆ", "r": "ㄖ", "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄑ", "w": "ㄠ",
    "x": "ㄨ", "y": "ㄚ", "z": "ㄗ", " ": " ",
  ]

  /// 倚天忘形排列預處理專用陣列，但未包含全部的映射內容。
  /// @--DISCUSSION--@
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對ㄓ/ㄍ/ㄕ做處理，然後再用程式判斷介母類型、據此判斷是否需要換成ㄒ/ㄑ/ㄐ。
  static let mapEten26StaticKeys: [String: String] = [
    "a": "ㄚ", "b": "ㄅ", "c": "ㄕ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄓ", "h": "ㄏ", "i": "ㄞ", "j": "ㄖ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄛ", "p": "ㄆ", "q": "ㄗ", "r": "ㄜ", "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄍ",
    "w": "ㄘ", "x": "ㄨ", "y": "ㄔ", "z": "ㄠ", " ": " ",
  ]

  /// 倚天傳統排列專用處理陣列。
  static let mapQwertyEtenTraditional: [String: String] = [
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
