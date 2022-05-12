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

  public enum PhoneType: Int {
    case null = 0  // 假
    case consonant = 1  // 聲
    case semivowel = 2  // 韻
    case vowel = 3  // 介
    case intonation = 4  // 調
  }

  public enum MandarinParser: Int {
    case ofDachen = 0
    case ofEten = 1
    case ofHsu = 2
    case ofEten26 = 3
    case ofIBM = 4
    case ofMiTAC = 5
    case ofFakeSeigyou = 6
    case ofSeigyou = 7
    case ofHanyuPinyin = 10

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

  public static let allowedConsonants = [
    "ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄉ", "ㄊ", "ㄋ", "ㄌ",
    "ㄍ", "ㄎ", "ㄏ", "ㄐ", "ㄑ", "ㄒ",
    "ㄓ", "ㄔ", "ㄕ", "ㄖ", "ㄗ", "ㄘ", "ㄙ",
  ]

  public static let allowedsemivowels = ["ㄧ", "ㄨ", "ㄩ"]

  public static let allowedVowels = [
    "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ",
    "ㄠ", "ㄡ", "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
  ]

  public static let allowedIntonations = [" ", "ˊ", "ˇ", "ˋ", "˙"]

  public static var allowedPhonabets: [String] {
    allowedConsonants + allowedsemivowels + allowedVowels + allowedIntonations
  }

  // MARK: - Phonabet Structure

  @frozen public struct Phonabet: Equatable, Hashable, ExpressibleByStringLiteral {
    public var type: PhoneType = .null
    public var value: String = ""
    public var isEmpty: Bool {
      value.isEmpty
    }

    public init(_ input: String = "") {
      if !input.isEmpty {
        if allowedPhonabets.contains(String(input.reversed()[0])) {
          value = String(input.reversed()[0])
          if Tekkon.allowedConsonants.contains(value) { type = .consonant }
          if Tekkon.allowedsemivowels.contains(value) { type = .semivowel }
          if Tekkon.allowedVowels.contains(value) { type = .vowel }
          if Tekkon.allowedIntonations.contains(value) { type = .intonation }
        }
      }
    }

    public mutating func clear() {
      value = ""
    }

    // MARK: - Misc Definitions

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

  @frozen public struct Composer: Equatable, Hashable, ExpressibleByStringLiteral {
    public var consonant: Phonabet = ""
    public var semivowel: Phonabet = ""
    public var vowel: Phonabet = ""
    public var intonation: Phonabet = ""
    public var parser: MandarinParser = .ofDachen
    public var value: String {
      consonant.value + semivowel.value + vowel.value + intonation.value.replacingOccurrences(of: " ", with: "")
    }

    public var isEmpty: Bool {
      intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
    }

    public init(_ input: String = "", arrange parser: MandarinParser = .ofDachen) {
      receiveKey(fromString: input)
      ensureParser(arrange: parser)
    }

    public mutating func clear() {
      consonant.clear()
      semivowel.clear()
      vowel.clear()
      intonation.clear()
    }

    // MARK: - Public Functions

    /// 用於檢測「某個輸入字符訊號的合規性」的函數。
    /// Phonabet 是一個特殊的 String 類 Struct，
    /// 只會接受正確的注音符號資料、且根據其類型自動回報其類型。
    /// 類型只有「聲、韻、介、調」這四類。
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

    public mutating func receiveKey(fromCharCode inputCharCode: UniChar = 0) {
      if let scalar = UnicodeScalar(inputCharCode) {
        let translatedInput = translate(key: String(scalar))
        let thePhone: Phonabet = .init(translatedInput)
        switch thePhone.type {
          case .consonant: consonant = thePhone
          case .semivowel: semivowel = thePhone
          case .vowel: vowel = thePhone
          case .intonation: intonation = thePhone
          default: break
        }
      }
    }

    /// 本來這個函數是不需要的，但將來在做漢語拼音功能時、這裡得回傳別的東西。
    /// 也就是說，這個函數就是用來決定輸入法組字區內顯示的注音/拼音內容。
    public func getDisplayedComposition() -> String {
      value
    }

    /// 這是專門用來「生成用以進行詞庫檢索的 Key」的函數。
    public func getRealComposition() -> String {
      value
    }

    /// 專門用來響應使用者摁下 BackSpace 按鍵時的行為。
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

    /// 用來檢測是否有調號
    public func hasToneMarker(withNothingElse: Bool = false) -> Bool {
      if !withNothingElse {
        return !intonation.isEmpty
      }
      return !intonation.isEmpty && vowel.isEmpty && semivowel.isEmpty && consonant.isEmpty
    }

    /// 當接收按鍵輸入時的處理。本來 Phonabet 就會自動使輸入的無效數值被忽略掉。
    /// 然後再根據 Phonabet 初期化後自身的 type 屬性來決定「聲、韻、介、調」到底哪個該更新。
    public mutating func receiveCharCode(_ inputKey: UniChar = 0) {
      // TODO: 在這裡補上鍵盤轉換工序
      if let scalar = UnicodeScalar(inputKey) {
        let input = String(scalar)
        receiveKey(fromString: input)
      }
    }

    // 設定該 Composer 處於何種鍵盤排列分析模式
    public mutating func ensureParser(arrange: MandarinParser = .ofDachen) {
      parser = arrange
    }

    // MARK: - Parser Processings

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

      return strReturn
    }

    /// 許氏鍵盤與倚天忘形一樣同樣也比較麻煩，需要單獨處理。
    mutating func handleHsu(key: String = "") -> String {
      var strReturn = ""
      strReturn = Tekkon.mapHsuStaticKeys[key] ?? ""
      let incomingPhonabet = Phonabet(strReturn)

      switch key {
        case "e": if semivowel.isEmpty { semivowel = "ㄧ" } else { vowel = "ㄝ" }
        case "a": if consonant.isEmpty { consonant = "ㄘ" } else { vowel = "ㄟ" }
        case "g": if consonant.isEmpty { consonant = "ㄍ" } else { vowel = "ㄜ" }
        case "h": if consonant.isEmpty { consonant = "ㄏ" } else { vowel = "ㄛ" }
        case "k": if consonant.isEmpty { consonant = "ㄎ" } else { vowel = "ㄤ" }
        case "m": if consonant.isEmpty { consonant = "ㄇ" } else { vowel = "ㄢ" }
        case "n": if consonant.isEmpty { consonant = "ㄋ" } else { vowel = "ㄣ" }
        case "s": if consonant.isEmpty { consonant = "ㄙ" } else { intonation = "˙" }
        case "d": if consonant.isEmpty { consonant = "ㄉ" } else { intonation = "ˊ" }
        case "f": if consonant.isEmpty { consonant = "ㄈ" } else { intonation = "ˇ" }
        case "l": if value.isEmpty { vowel = "ㄦ" } else if consonant.isEmpty { consonant = "ㄌ" } else { vowel = "ㄥ" }
        case "j": if !consonant.isEmpty { intonation = "ˋ" }
        default: break
      }

      // 處理「一個按鍵對應兩個聲母」的情形。
      if !consonant.isEmpty, incomingPhonabet.type == .semivowel {
        switch consonant {
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

      return strReturn
    }

    // MARK: - Misc Definitions

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

  // MARK: - Maps for Keyboard-to-Phonabet parsers

  // 任何形式的拼音排列都會用到的陣列，用 Strings 反而省事一些。
  static let mapArayuruPinyin: String = "abcdefghijklmnopqrstuvwxyz12345 "

  /// 標準大千排列專用處理陣列。
  /// 威注音輸入法 macOS 版使用了 Ukelele 佈局來完成對諸如倚天傳統等其它注音鍵盤排列的支援。
  /// 如果要將鐵恨模組拿給別的平台的輸入法使用的話，恐怕需要針對這些注音鍵盤排列各自新增專用陣列才可以。
  static let mapQwertyDachen: [String: String] = [
    "0": "ㄢ", "1": "ㄅ", "2": "ㄉ", "3": "ˇ", "4": "ˋ", "5": "ㄓ", "6": "ˊ", "7": "˙", "8": "ㄚ", "9": "ㄞ", "-": "ㄦ",
    ",": "ㄝ", ".": "ㄡ", "/": "ㄥ", ";": "ㄤ", "a": "ㄇ", "b": "ㄖ", "c": "ㄏ", "d": "ㄎ", "e": "ㄍ", "f": "ㄑ", "g": "ㄕ",
    "h": "ㄘ", "i": "ㄛ", "j": "ㄨ", "k": "ㄜ", "l": "ㄠ", "m": "ㄩ", "n": "ㄙ", "o": "ㄟ", "p": "ㄣ", "q": "ㄆ", "r": "ㄐ",
    "s": "ㄋ", "t": "ㄔ", "u": "ㄧ", "v": "ㄒ", "w": "ㄊ", "x": "ㄌ", "y": "ㄗ", "z": "ㄈ", " ": " ",
  ]

  /// 許氏排列專用處理陣列，但未包含全部的映射內容。
  /// 在這裡將二十六個字母寫全，也只是為了方便做 validity check。
  /// 這裡提前對複音按鍵做處理，然後再用程式判斷介母類型、據此判斷是否需要做複音切換。
  static let mapHsuStaticKeys: [String: String] = [
    "a": "ㄘ", "b": "ㄅ", "c": "ㄕ", "d": "ㄉ", "e": "ㄧ", "f": "ㄈ", "g": "ㄍ", "h": "ㄏ", "i": "ㄞ", "j": "ㄓ", "k": "ㄎ",
    "l": "ㄌ", "m": "ㄇ", "n": "ㄋ", "o": "ㄡ", "p": "ㄆ", "r": "ㄖ", "s": "ㄙ", "t": "ㄊ", "u": "ㄩ", "v": "ㄑ", "w": "ㄠ",
    "x": "ㄨ", "y": "ㄚ", "z": "ㄗ", " ": " ",
  ]

  /// 倚天忘形排列預處理專用陣列，但未包含全部的映射內容。
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
