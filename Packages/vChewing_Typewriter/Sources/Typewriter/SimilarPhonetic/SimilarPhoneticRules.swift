// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - SimilarPhoneticRules

/// 近音規則表：聲母對、韻母對以及注音展開工具函式。
/// 所有函式均為 nonisolated pure functions，可在任意 actor context 呼叫。
public enum SimilarPhoneticRules {

  // MARK: - 聲調展開

  /// 五個聲調標記：一聲（無標記）、二聲、三聲、四聲、輕聲。
  public static let allToneMarkers: [String] = ["", "ˊ", "ˇ", "ˋ", "˙"]

  /// 將注音字串拆分為「無聲調的基底」與「聲調標記」。
  /// - Parameter phonetic: 含聲調的注音字串，如 "ㄘㄢˊ"。
  /// - Returns: (base, tone)，例如 ("ㄘㄢ", "ˊ")。一聲 tone = ""。
  public static func splitTone(_ phonetic: String) -> (base: String, tone: String) {
    let toneSet: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]
    if let last = phonetic.last, toneSet.contains(last) {
      return (String(phonetic.dropLast()), String(last))
    }
    return (phonetic, "")
  }

  /// 給定一個注音（含原聲調），返回同一基底的全部五個聲調版本，原聲調版本排第一。
  /// - Parameter phonetic: 原始注音（如 "ㄇㄡˊ"）。
  /// - Returns: 五個版本，原聲調第一。
  public static func allReadings(of phonetic: String) -> [String] {
    let (base, originalTone) = splitTone(phonetic)
    var result: [String] = [phonetic]
    for tone in allToneMarkers {
      guard tone != originalTone else { continue }
      result.append(base + tone)
    }
    return result
  }

  // MARK: - 聲母集合

  /// 注音聲母集合（用於判斷是否有聲母）。
  private static let consonants: Set<Character> = Set(
    "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ"
  )

  /// 將注音基底（無聲調）拆分為「聲母」與「其餘（介音+韻母）」。
  /// - Parameter base: 無聲調注音基底，如 "ㄘㄢ"、"ㄧㄣ"（無聲母）。
  /// - Returns: (consonant, remainder)，如 ("ㄘ", "ㄢ") 或 ("", "ㄧㄣ")。
  static func splitConsonant(from base: String) -> (consonant: String, remainder: String) {
    guard let first = base.first, consonants.contains(first) else {
      return ("", base)
    }
    return (String(first), String(base.dropFirst()))
  }

  // MARK: - 近音聲母對（白名單制）

  /// 近音聲母對映表。僅白名單內的聲母才有近音聲母。
  /// ㄅㄆㄇㄈ（唇音）、ㄐㄑㄒ（舌面音）、ㄦ（特殊）均無近音聲母。
  private static let consonantPairMap: [String: String] = [
    "ㄓ": "ㄗ", "ㄗ": "ㄓ",
    "ㄔ": "ㄘ", "ㄘ": "ㄔ",
    "ㄕ": "ㄙ", "ㄙ": "ㄕ",
    "ㄋ": "ㄌ", "ㄌ": "ㄋ",
    "ㄈ": "ㄏ", "ㄏ": "ㄈ",
    "ㄎ": "ㄍ", "ㄍ": "ㄎ",
  ]

  /// 給定無聲調基底，返回近音聲母替換後的基底（無聲調）。
  /// 若聲母不在白名單或為零聲母，返回 nil。
  /// - Parameter base: 無聲調注音基底，如 "ㄘㄢ"。
  /// - Returns: 近音聲母版本，如 "ㄔㄢ"；若無近音聲母則 nil。
  public static func nearConsonantBase(for base: String) -> String? {
    let (consonant, remainder) = splitConsonant(from: base)
    guard !consonant.isEmpty else { return nil } // 零聲母無近音聲母
    guard let nearConsonant = consonantPairMap[consonant] else { return nil }
    return nearConsonant + remainder
  }

  // MARK: - 近音韻母對

  /// 近音韻母對映表。Key 為「介音+韻母」部分（聲母已去除）。
  /// 長的要先比對（如 "ㄧㄣ" 先於 "ㄣ"），避免短的誤比對。
  private static let vowelPairs: [(String, String)] = [
    ("ㄧㄣ", "ㄧㄥ"), ("ㄧㄥ", "ㄧㄣ"),
    ("ㄨㄣ", "ㄨㄥ"), ("ㄨㄥ", "ㄨㄣ"),
    ("ㄣ", "ㄥ"), ("ㄥ", "ㄣ"),
    ("ㄢ", "ㄤ"), ("ㄤ", "ㄢ"),
    ("ㄡ", "ㄛ"), ("ㄛ", "ㄡ"),
  ]

  /// 語音上無效的「聲母+介音韻母」組合（無聲調），不做近音韻母擴展。
  /// 例如 ㄅㄡ 在國語中不存在，故 ㄅㄛ 不展開為 ㄅㄡ。
  private static let invalidPhoneticBases: Set<String> = [
    "ㄅㄡ", // bou 在國語中不存在。
  ]

  /// 給定無聲調基底，返回近音韻母替換後的基底（無聲調）。
  /// 若韻母部分不在韻母對映表中，返回 nil。
  /// - Parameter base: 無聲調注音基底，如 "ㄇㄡ"、"ㄙㄨㄣ"、"ㄧㄣ"（無聲母）。
  /// - Returns: 近音韻母版本，如 "ㄇㄛ"、"ㄙㄨㄥ"；若無近音韻母則 nil。
  public static func nearVowelBase(for base: String) -> String? {
    let (consonant, remainder) = splitConsonant(from: base)
    for (vowelA, vowelB) in vowelPairs where remainder.hasSuffix(vowelA) {
      // 替換 remainder 尾部的 vowelA 為 vowelB
      let prefix = String(remainder.dropLast(vowelA.count))
      let result = consonant + prefix + vowelB
      guard !invalidPhoneticBases.contains(result) else { return nil }
      return result
    }
    return nil
  }
}
