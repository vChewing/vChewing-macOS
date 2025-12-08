// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - KeyKeyUserDBKit.PhonaSet

extension KeyKeyUserDBKit {
  /// 注音符號 (Phonabet) 的完整漢字讀音結構（PhonaSet）。
  ///
  /// - Remarks: 該結構體類型僅用於解密奇摩輸入法的讀音字串。
  public struct PhonaSet: Hashable, Sendable, CustomStringConvertible {
    // MARK: Lifecycle

    // MARK: - Initializers

    /// 以原始音節值初始化 PhonaSet
    /// - Parameter syllable: 16 位元原始音節值
    public init(syllable: UInt16 = 0) {
      self.syllable = syllable
    }

    /// 從 absolute order 值重建 PhonaSet 音節
    /// - Parameter order: absolute order 值
    public init(absoluteOrder order: Int) {
      let consonant = UInt16(order % 22)
      let semi = UInt16((order / 22) % 4) << 5
      let vowel = UInt16((order / (22 * 4)) % 14) << 7
      let tone = UInt16((order / (22 * 4 * 14)) % 5) << 11
      self.syllable = consonant | semi | vowel | tone
    }

    /// 以組件建立 PhonaSet 音節
    /// - Parameters:
    ///   - consonant: 聲母
    ///   - semivowel: 介音
    ///   - vowel: 韻母
    ///   - intonation: 聲調
    public init(
      consonant: Consonant? = nil, semivowel: Semivowel? = nil, vowel: Vowel? = nil,
      intonation: Intonation = .ˉ
    ) {
      let consRaw = consonant?.rawValue ?? 0
      let semiRaw = semivowel?.rawValue ?? 0
      let vowelRaw = vowel?.rawValue ?? 0
      self.syllable = consRaw | semiRaw | vowelRaw | intonation.rawValue
    }

    /// 從 2-char absolute order 字串重建 PhonaSet 音節
    ///
    /// 編碼方式: 79 進位制，用 ASCII 48-126 表示
    /// order = (high - 48) * 79 + (low - 48)
    /// - Parameter s: 2-char absolute order 字串
    public init?(absoluteOrderString s: String) {
      guard s.count == 2 else { return nil }
      let scalars = Array(s.unicodeScalars)
      guard scalars.count == 2 else { return nil }

      let low = Int(scalars[0].value) - 48
      let high = Int(scalars[1].value) - 48
      guard (0 ..< 79).contains(low), (0 ..< 79).contains(high) else { return nil }

      self.init(absoluteOrder: high * 79 + low)
    }

    // MARK: Public

    // MARK: - Bit Masks

    /// 注音組件類型的位元遮罩
    public enum PhonaType: UInt16, Codable, Hashable, Sendable {
      /// 聲母遮罩
      case consonant = 0x001F
      /// 介音遮罩
      case semivowel = 0x0060
      /// 韻母遮罩
      case vowel = 0x0780
      /// 聲調遮罩
      case intonation = 0x3800
    }

    // MARK: - Component Definitions

    /// 聲母枚舉（21 個聲母）
    public enum Consonant: UInt16, CaseIterable, Codable, Hashable, Sendable {
      case ㄅ = 0x0001
      case ㄆ, ㄇ, ㄈ, ㄉ, ㄊ, ㄋ, ㄌ, ㄍ, ㄎ, ㄏ, ㄐ, ㄑ, ㄒ
      case ㄓ = 0x000F
      case ㄔ, ㄕ, ㄖ, ㄗ, ㄘ, ㄙ

      // MARK: Internal

      var symbol: Unicode.Scalar {
        switch self {
        case .ㄅ: "\u{3105}"
        case .ㄆ: "\u{3106}"
        case .ㄇ: "\u{3107}"
        case .ㄈ: "\u{3108}"
        case .ㄉ: "\u{3109}"
        case .ㄊ: "\u{310A}"
        case .ㄋ: "\u{310B}"
        case .ㄌ: "\u{310C}"
        case .ㄍ: "\u{310D}"
        case .ㄎ: "\u{310E}"
        case .ㄏ: "\u{310F}"
        case .ㄐ: "\u{3110}"
        case .ㄑ: "\u{3111}"
        case .ㄒ: "\u{3112}"
        case .ㄓ: "\u{3113}"
        case .ㄔ: "\u{3114}"
        case .ㄕ: "\u{3115}"
        case .ㄖ: "\u{3116}"
        case .ㄗ: "\u{3117}"
        case .ㄘ: "\u{3118}"
        case .ㄙ: "\u{3119}"
        }
      }
    }

    /// 介音枚舉（3 個介音）
    public enum Semivowel: UInt16, CaseIterable, Codable, Hashable, Sendable {
      case ㄧ = 0x0020
      case ㄨ = 0x0040
      case ㄩ = 0x0060

      // MARK: Internal

      var symbol: Unicode.Scalar {
        switch self {
        case .ㄧ: "\u{3127}"
        case .ㄨ: "\u{3128}"
        case .ㄩ: "\u{3129}"
        }
      }
    }

    /// 韻母枚舉（13 個韻母）
    public enum Vowel: UInt16, CaseIterable, Codable, Hashable, Sendable {
      case ㄚ = 0x0080
      case ㄛ = 0x0100
      case ㄜ = 0x0180
      case ㄝ = 0x0200
      case ㄞ = 0x0280
      case ㄟ = 0x0300
      case ㄠ = 0x0380
      case ㄡ = 0x0400
      case ㄢ = 0x0480
      case ㄣ = 0x0500
      case ㄤ = 0x0580
      case ㄥ = 0x0600
      case ㄦ = 0x0680

      // MARK: Internal

      var symbol: Unicode.Scalar {
        switch self {
        case .ㄚ: "\u{311A}"
        case .ㄛ: "\u{311B}"
        case .ㄜ: "\u{311C}"
        case .ㄝ: "\u{311D}"
        case .ㄞ: "\u{311E}"
        case .ㄟ: "\u{311F}"
        case .ㄠ: "\u{3120}"
        case .ㄡ: "\u{3121}"
        case .ㄢ: "\u{3122}"
        case .ㄣ: "\u{3123}"
        case .ㄤ: "\u{3124}"
        case .ㄥ: "\u{3125}"
        case .ㄦ: "\u{3126}"
        }
      }
    }

    /// 聲調枚舉（5 種聲調）
    public enum Intonation: UInt16, CaseIterable, Codable, Hashable, Sendable {
      /// 一聲（陰平）
      case ˉ = 0x0000
      /// 二聲（陽平）
      case ˊ = 0x0800
      /// 三聲（上聲）
      case ˇ = 0x1000
      /// 四聲（去聲）
      case ˋ = 0x1800
      /// 輕聲
      case ˙ = 0x2000

      // MARK: Internal

      var symbol: Unicode.Scalar? {
        switch self {
        case .ˉ: nil
        case .ˊ: "\u{02CA}"
        case .ˇ: "\u{02C7}"
        case .ˋ: "\u{02CB}"
        case .˙: "\u{02D9}"
        }
      }
    }

    /// 16 位元原始音節值
    public var syllable: UInt16

    // MARK: - Public Methods

    /// 將 PhonaSet 音節轉換為 Unicode 注音符號字串
    public var description: String {
      var result = ""

      if let scalar = scalar4Consonant { result.unicodeScalars.append(scalar) }
      if let scalar = scalar4Semivowel { result.unicodeScalars.append(scalar) }
      if let scalar = scalar4Vowel { result.unicodeScalars.append(scalar) }
      if let scalar = scalar4Intonation { result.unicodeScalars.append(scalar) }

      return result
    }

    /// 取得聲母
    public var rawConsonant: UInt16 { syllable & PhonaType.consonant.rawValue }
    /// 取得介音
    public var rawSemivowel: UInt16 { syllable & PhonaType.semivowel.rawValue }
    /// 取得韻母
    public var rawVowel: UInt16 { syllable & PhonaType.vowel.rawValue }
    /// 取得聲調
    public var rawIntonation: UInt16 { syllable & PhonaType.intonation.rawValue }

    // MARK: Private

    // MARK: - Private Helpers

    private var scalar4Consonant: Unicode.Scalar? {
      guard let component = Consonant(rawValue: rawConsonant) else { return nil }
      return component.symbol
    }

    private var scalar4Semivowel: Unicode.Scalar? {
      guard let component = Semivowel(rawValue: rawSemivowel) else { return nil }
      return component.symbol
    }

    private var scalar4Vowel: Unicode.Scalar? {
      guard let component = Vowel(rawValue: rawVowel) else { return nil }
      return component.symbol
    }

    private var scalar4Intonation: Unicode.Scalar? {
      guard let component = Intonation(rawValue: rawIntonation) else { return nil }
      return component.symbol
    }
  }
}

// MARK: - QString Decoder

extension KeyKeyUserDBKit.PhonaSet {
  /// 將資料庫中的 qstring 解碼為注音符號
  ///
  /// - 格式1 (unigram): 連續的 2-char absolute order 字串，每 2 個字元代表一個注音音節
  /// - 格式2 (bigram):  "~{前字注音2char} {當前字注音2char}"，用空格分隔
  ///
  /// - 注意: `~` (ASCII 126) 可能是有效的編碼字元（order % 79 = 78），
  ///         只有當 `~` 後面有空格時才是真正的 bigram 格式
  public static func decodeQueryString(_ queryString: String) -> String {
    // 只有當 ~ 後面有空格時才是 bigram 格式
    if queryString.hasPrefix("~"), queryString.dropFirst().contains(" ") {
      return decodeBigram(queryString)
    }

    guard queryString.count.isMultiple(of: 2) else { return queryString }

    let syllables = decodeSyllables(queryString)
    return syllables.isEmpty ? queryString : syllables.joined(separator: ",")
  }

  /// 將資料庫中的 qstring 解碼為注音符號陣列（用於 Gram 的 keyArray）
  ///
  /// - 格式1 (unigram): 連續的 2-char absolute order 字串，每 2 個字元代表一個注音音節
  /// - 格式2 (bigram):  "~{前字注音2char} {當前字注音2char}"，用空格分隔
  ///
  /// - 注意: `~` (ASCII 126) 可能是有效的編碼字元（order % 79 = 78），
  ///         只有當 `~` 後面有空格時才是真正的 bigram 格式
  public static func decodeQueryStringAsKeyArray(_ queryString: String) -> [String] {
    // 只有當 ~ 後面有空格時才是 bigram 格式
    if queryString.hasPrefix("~"), queryString.dropFirst().contains(" ") {
      return decodeBigramAsKeyArray(queryString)
    }

    guard queryString.count.isMultiple(of: 2) else { return [queryString] }

    let syllables = decodeSyllables(queryString)
    return syllables.isEmpty ? [queryString] : syllables
  }

  private static func decodeBigram(_ queryString: String) -> String {
    let content = queryString.dropFirst()
    let parts = content.split(separator: " ", omittingEmptySubsequences: false)

    let decodedParts = parts.compactMap { part -> String? in
      let syllables = decodeSyllables(String(part))
      return syllables.isEmpty ? nil : syllables.joined()
    }

    return decodedParts.joined(separator: " → ")
  }

  private static func decodeBigramAsKeyArray(_ queryString: String) -> [String] {
    let content = queryString.dropFirst()
    let parts = content.split(separator: " ", omittingEmptySubsequences: false)

    // 只取最後一個部分的音節（當前字的注音）
    guard let lastPart = parts.last else { return [queryString] }
    let syllables = decodeSyllables(String(lastPart))
    return syllables.isEmpty ? [queryString] : syllables
  }

  /// 解碼連續的 2-char 音節
  /// - Note: 若字串長度為奇數，只解碼前面偶數個字元
  private static func decodeSyllables(_ stringToDecode: String) -> [String] {
    let decodableLength = stringToDecode.count - (stringToDecode.count % 2)
    guard decodableLength >= 2 else { return [] }

    return stride(from: 0, to: decodableLength, by: 2).compactMap { index in
      let start = stringToDecode.index(stringToDecode.startIndex, offsetBy: index)
      let end = stringToDecode.index(start, offsetBy: 2)
      let absStr = String(stringToDecode[start ..< end])

      guard let phonaSet = KeyKeyUserDBKit.PhonaSet(absoluteOrderString: absStr) else { return nil }
      let composed = phonaSet.description
      return composed.isEmpty ? nil : composed
    }
  }
}
