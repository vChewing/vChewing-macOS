// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - RomanNumeralOutputFormat

public enum RomanNumeralOutputFormat: Int, CaseIterable {
  case uppercaseASCII = 0     // ASCII 大寫
  case lowercaseASCII = 1     // ASCII 小寫
  case uppercaseFullWidth = 2 // 全形大寫
  case lowercaseFullWidth = 3 // 全形小寫
}

// MARK: - RomanNumeralConverter

public enum RomanNumeralConverter {
  /// Maximum value supported for Roman numeral conversion (exclusive)
  public static let maxValue = 4000
  
  /// Convert an integer (1-3999) to Roman numeral representation
  /// - Parameters:
  ///   - number: The number to convert (1-3999)
  ///   - format: The output format for the Roman numeral
  /// - Returns: The Roman numeral string, or nil if the number is out of range
  public static func convert(_ number: Int, format: RomanNumeralOutputFormat = .uppercaseASCII) -> String? {
    // Check range (Roman numerals don't include zero)
    guard number > 0, number < maxValue else {
      return nil
    }
    
    // Roman numeral conversion table
    let romanValues: [(Int, String)] = [
      (1000, "M"),
      (900, "CM"),
      (500, "D"),
      (400, "CD"),
      (100, "C"),
      (90, "XC"),
      (50, "L"),
      (40, "XL"),
      (10, "X"),
      (9, "IX"),
      (5, "V"),
      (4, "IV"),
      (1, "I")
    ]
    
    var result = ""
    var remaining = number
    
    for (value, numeral) in romanValues {
      let count = remaining / value
      if count > 0 {
        result += String(repeating: numeral, count: count)
        remaining -= value * count
      }
    }
    
    return formatString(result, format: format)
  }
  
  /// Format a Roman numeral string according to the specified format
  private static func formatString(_ roman: String, format: RomanNumeralOutputFormat) -> String {
    switch format {
    case .uppercaseASCII:
      return roman
    case .lowercaseASCII:
      return roman.lowercased()
    case .uppercaseFullWidth:
      return convertToUnicodeRomanNumerals(roman, lowercase: false)
    case .lowercaseFullWidth:
      return convertToUnicodeRomanNumerals(roman, lowercase: true)
    }
  }
  
  /// Convert ASCII Roman numerals to Unicode Roman numeral characters (U+2160-U+217F)
  /// Uses compound Unicode characters where available (II, III, IV, VI, VII, VIII, IX, XI, XII)
  private static func convertToUnicodeRomanNumerals(_ roman: String, lowercase: Bool) -> String {
    // Try to use compound Unicode Roman numerals first
    let uppercaseCompounds: [String: String] = [
      "XII": "\u{216B}", "XI": "\u{216A}", "IX": "\u{2168}", "VIII": "\u{2167}",
      "VII": "\u{2166}", "VI": "\u{2165}", "IV": "\u{2163}", "III": "\u{2162}",
      "II": "\u{2161}"
    ]
    let lowercaseCompounds: [String: String] = [
      "XII": "\u{217B}", "XI": "\u{217A}", "IX": "\u{2178}", "VIII": "\u{2177}",
      "VII": "\u{2176}", "VI": "\u{2175}", "IV": "\u{2173}", "III": "\u{2172}",
      "II": "\u{2171}"
    ]
    let compounds = lowercase ? lowercaseCompounds : uppercaseCompounds
    
    var result = roman
    // Replace compound numerals first (longer matches first)
    for (ascii, unicode) in compounds.sorted(by: { $0.key.count > $1.key.count }) {
      result = result.replacingOccurrences(of: ascii, with: unicode)
    }
    
    // Then replace individual characters
    let uppercaseMap: [Character: String] = [
      "I": "\u{2160}", "V": "\u{2164}", "X": "\u{2169}",
      "L": "\u{216C}", "C": "\u{216D}", "D": "\u{216E}", "M": "\u{216F}"
    ]
    let lowercaseMap: [Character: String] = [
      "I": "\u{2170}", "V": "\u{2174}", "X": "\u{2179}",
      "L": "\u{217C}", "C": "\u{217D}", "D": "\u{217E}", "M": "\u{217F}"
    ]
    
    let map = lowercase ? lowercaseMap : uppercaseMap
    result = result.map { map[$0] ?? String($0) }.joined()
    
    return result
  }
}
