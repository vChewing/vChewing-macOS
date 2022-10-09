// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension Tekkon {
  // MARK: - Dynamic Constants and Basic Enums

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
          return "Dachen Trad."
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
    public mutating func selfReplace(_ strOf: String, _ strWith: String = "") {
      valueStorage = valueStorage.replacingOccurrences(of: strOf, with: strWith)
      ensureType()
    }

    /// 用來自動更新自身的屬性值的函式。
    public mutating func ensureType() {
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
}
