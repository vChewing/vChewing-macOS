// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

infix operator <~: AssignmentPrecedence

extension Tekkon {
  // MARK: - Dynamic Constants and Basic Enums

  /// 定義注音符號的種類
  public enum PhoneType: Int, Codable, Hashable, Sendable {
    case null = 0 // 假
    case consonant = 1 // 聲
    case semivowel = 2 // 介
    case vowel = 3 // 韻
    case intonation = 4 // 調
  }

  /// 定義注音排列的類型
  public enum MandarinParser: Int, Codable, Hashable, Sendable, CaseIterable {
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
    case ofAlvinLiu = 10
    case ofHanyuPinyin = 100
    case ofSecondaryPinyin = 101
    case ofYalePinyin = 102
    case ofHualuoPinyin = 103
    case ofUniversalPinyin = 104
    case ofWadeGilesPinyin = 105

    // MARK: Public

    public static let allPinyinCases: [Self] = Self.allCases.filter(\.isPinyin)

    public static let allDynamicZhuyinCases: [Self] = Self.allCases.filter(\.isDynamic)

    public static let allStaticZhuyinCases: [Self] = Self.allCases.filter {
      !$0.isDynamic && !$0.isPinyin
    }

    public var isPinyin: Bool { rawValue >= 100 }

    public var isDynamic: Bool {
      switch self {
      case .ofDachen: false
      case .ofDachen26: true
      case .ofETen: false
      case .ofETen26: true
      case .ofHsu: true
      case .ofIBM: false
      case .ofMiTAC: false
      case .ofSeigyou: false
      case .ofFakeSeigyou: false
      case .ofStarlight: true
      case .ofAlvinLiu: true
      case .ofHanyuPinyin: false
      case .ofSecondaryPinyin: false
      case .ofYalePinyin: false
      case .ofHualuoPinyin: false
      case .ofUniversalPinyin: false
      case .ofWadeGilesPinyin: false
      }
    }

    public var mapZhuyinPinyin: [String: String]? {
      switch self {
      case .ofHanyuPinyin: Tekkon.mapHanyuPinyin
      case .ofSecondaryPinyin: Tekkon.mapSecondaryPinyin
      case .ofYalePinyin: Tekkon.mapYalePinyin
      case .ofHualuoPinyin: Tekkon.mapHualuoPinyin
      case .ofUniversalPinyin: Tekkon.mapUniversalPinyin
      case .ofWadeGilesPinyin: Tekkon.mapWadeGilesPinyin
      default: nil
      }
    }

    public var allPossibleReadings: Set<String> {
      let intonations: String = isPinyin ? " 12345" : " ˊˇˋ˙"
      let baseReadingStems: [String] = switch self {
      case .ofHanyuPinyin: Tekkon.mapHanyuPinyin.map(\.key)
      case .ofSecondaryPinyin: Tekkon.mapSecondaryPinyin.map(\.key)
      case .ofYalePinyin: Tekkon.mapYalePinyin.map(\.key)
      case .ofHualuoPinyin: Tekkon.mapHualuoPinyin.map(\.key)
      case .ofUniversalPinyin: Tekkon.mapUniversalPinyin.map(\.key)
      case .ofWadeGilesPinyin: Tekkon.mapWadeGilesPinyin.map(\.key)
      default: Tekkon.mapHanyuPinyin.map(\.value)
      }
      var result: [String] = baseReadingStems
      intonations.forEach { currentIntonation in
        result.append(
          contentsOf: baseReadingStems.map { $0 + currentIntonation.description }
        )
      }
      return Set(result)
    }

    // MARK: Internal

    var nameTag: String {
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
      case .ofAlvinLiu:
        return "AlvinLiu"
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
      case .ofWadeGilesPinyin:
        return "WadeGilesPinyin"
      }
    }
  }

  // MARK: - Phonabet Structure

  /// 注音符號型別。本身與字串差不多，但卻只能被設定成一個注音符號字元。
  /// 然後會根據自身的 value 的內容值自動計算自身的 PhoneType 類型（聲介韻調假）。
  /// 如果遇到被設為多個字元、或者字元不對的情況的話，value 會被清空、PhoneType 會變成 null。
  /// 賦值時最好直接重新 init 且一直用 let 來初期化 Phonabet。
  /// 其實 value 對外只讀，對內的話另有 valueStorage 代為存儲內容。這樣比較安全一些。
  @frozen
  public struct Phonabet: Equatable, Codable, Hashable, Sendable {
    // MARK: Lifecycle

    /// 初期化，會根據傳入的 input 字串參數來自動判定自身的 PhoneType 類型屬性值。
    public init(_ input: String = "") {
      if let lastChar = input.unicodeScalars.last, allowedPhonabets
        .contains(lastChar) {
        self.scalarValue = lastChar
      }
      ensureType()
    }

    /// 初期化，會根據傳入的 input 字串參數來自動判定自身的 PhoneType 類型屬性值。
    public init(_ input: Unicode.Scalar) {
      if allowedPhonabets.contains(input) {
        self.scalarValue = input
      }
      ensureType()
    }

    // MARK: Public

    public var type: PhoneType = .null

    public private(set) var scalarValue: Unicode.Scalar = .init(unicodeScalarLiteral: "~")

    public var value: String {
      guard isValid else { return "" }
      return String(Character(scalarValue))
    }

    public var isEmpty: Bool { type == .null }
    public var isValid: Bool { type != .null }

    public static func <~ (_ lhs: inout Tekkon.Phonabet, _ newValue: Unicode.Scalar) {
      lhs.setValue(newValue)
    }

    public static func + (lhs: Self, rhs: Self) -> String {
      lhs.value + rhs.value
    }

    /// 自我清空內容。
    public mutating func clear() {
      scalarValue = .nullPhonabet
      type = .null
    }

    /// 自我變換資料值。
    /// - Parameters:
    ///   - strOf: 要取代的內容。
    ///   - strWith: 要取代成的內容。
    public mutating func selfReplace(
      _ strOf: Unicode.Scalar,
      _ strWith: Unicode.Scalar? = nil
    ) {
      if scalarValue == strOf { scalarValue = strWith ?? .nullPhonabet }
      ensureType()
    }

    public mutating func setValue(_ newValue: Unicode.Scalar) {
      scalarValue = newValue
      ensureType()
    }

    // MARK: Private

    /// 用來自動更新自身的屬性值的函式。
    private mutating func ensureType() {
      if Tekkon.allowedConsonants.contains(scalarValue) {
        type = .consonant
      } else if Tekkon.allowedSemivowels.contains(scalarValue) {
        type = .semivowel
      } else if Tekkon.allowedVowels.contains(scalarValue) {
        type = .vowel
      } else if Tekkon.allowedIntonations.contains(scalarValue) {
        type = .intonation
      } else {
        type = .null
        scalarValue = .nullPhonabet
      }
    }
  }
}

// MARK: - Unicode.Scalar + Codable

#if hasFeature(RetroactiveAttribute)
  extension Unicode.Scalar: @retroactive Codable {}
#else
  extension Unicode.Scalar: Codable {}
#endif

extension Unicode.Scalar {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let scalarRawValue = try container.decode(UInt32.self)
    let newScalar = Unicode.Scalar(scalarRawValue)
    guard let newScalar else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Can't parse the following UInt32 into a Unicode Scalar: \(scalarRawValue)"
        )
      )
    }
    self = newScalar
  }

  fileprivate static let nullPhonabet = Unicode.Scalar("~")
}
