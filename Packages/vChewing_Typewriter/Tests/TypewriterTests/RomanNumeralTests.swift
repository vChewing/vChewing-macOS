// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing
@testable import Typewriter

@Suite("RomanNumeralTests")
struct RomanNumeralTests {
  @Test
  func testRomanNumeralConversion() {
    // 測試基本數值（自 1 起算，羅馬數字不含 0）
    #expect(RomanNumeralConverter.convert(1, format: .uppercaseASCII) == "I")
    #expect(RomanNumeralConverter.convert(4, format: .uppercaseASCII) == "IV")
    #expect(RomanNumeralConverter.convert(5, format: .uppercaseASCII) == "V")
    #expect(RomanNumeralConverter.convert(9, format: .uppercaseASCII) == "IX")
    #expect(RomanNumeralConverter.convert(10, format: .uppercaseASCII) == "X")
    #expect(RomanNumeralConverter.convert(40, format: .uppercaseASCII) == "XL")
    #expect(RomanNumeralConverter.convert(50, format: .uppercaseASCII) == "L")
    #expect(RomanNumeralConverter.convert(90, format: .uppercaseASCII) == "XC")
    #expect(RomanNumeralConverter.convert(100, format: .uppercaseASCII) == "C")
    #expect(RomanNumeralConverter.convert(400, format: .uppercaseASCII) == "CD")
    #expect(RomanNumeralConverter.convert(500, format: .uppercaseASCII) == "D")
    #expect(RomanNumeralConverter.convert(900, format: .uppercaseASCII) == "CM")
    #expect(RomanNumeralConverter.convert(1_000, format: .uppercaseASCII) == "M")

    // 測試含 0 的數值（僅限非首位時有效）
    #expect(RomanNumeralConverter.convert(10, format: .uppercaseASCII) == "X")
    #expect(RomanNumeralConverter.convert(20, format: .uppercaseASCII) == "XX")
    #expect(RomanNumeralConverter.convert(100, format: .uppercaseASCII) == "C")
    #expect(RomanNumeralConverter.convert(200, format: .uppercaseASCII) == "CC")
    #expect(RomanNumeralConverter.convert(1_000, format: .uppercaseASCII) == "M")
    #expect(RomanNumeralConverter.convert(2_000, format: .uppercaseASCII) == "MM")

    // 測試複合數值
    #expect(RomanNumeralConverter.convert(3, format: .uppercaseASCII) == "III")
    #expect(RomanNumeralConverter.convert(27, format: .uppercaseASCII) == "XXVII")
    #expect(RomanNumeralConverter.convert(1_994, format: .uppercaseASCII) == "MCMXCIV")
    #expect(RomanNumeralConverter.convert(2_023, format: .uppercaseASCII) == "MMXXIII")
    #expect(RomanNumeralConverter.convert(3_999, format: .uppercaseASCII) == "MMMCMXCIX")

    // 測試小寫
    #expect(RomanNumeralConverter.convert(1_994, format: .lowercaseASCII) == "mcmxciv")

    // 測試超出範圍（含 0）
    #expect(RomanNumeralConverter.convert(0, format: .uppercaseASCII) == nil)
    #expect(RomanNumeralConverter.convert(-1, format: .uppercaseASCII) == nil)
    #expect(RomanNumeralConverter.convert(RomanNumeralConverter.maxValue, format: .uppercaseASCII) == nil)
  }

  @Test
  func testRomanNumeralFormats() {
    let testNumber = 42

    // 測試 ASCII 大寫
    let upperASCII = RomanNumeralConverter.convert(testNumber, format: .uppercaseASCII)
    #expect(upperASCII == "XLII")

    // 測試 ASCII 小寫
    let lowerASCII = RomanNumeralConverter.convert(testNumber, format: .lowercaseASCII)
    #expect(lowerASCII == "xlii")

    // 測試全形格式（應使用 Unicode 羅馬數字符號 U+2160～U+217F）
    // 使用複合 Unicode 符號：XL = Ⅹ + Ⅼ，II = Ⅱ（複合）
    let upperFullWidth = RomanNumeralConverter.convert(testNumber, format: .uppercaseURN)
    #expect(upperFullWidth != nil)
    #expect(upperFullWidth == "\u{2169}\u{216C}\u{2161}") // Ⅹ Ⅼ Ⅱ

    let lowerFullWidth = RomanNumeralConverter.convert(testNumber, format: .lowercaseURN)
    #expect(lowerFullWidth != nil)
    #expect(lowerFullWidth == "\u{2179}\u{217C}\u{2171}") // ⅹ ⅼ ⅱ
  }

  @Test
  func testUnicodeRomanNumeralCompounds() {
    // 測試在可用時是否使用複合 Unicode 符號
    // 3 = III 應使用 Ⅲ (U+2162)
    let three = RomanNumeralConverter.convert(3, format: .uppercaseURN)
    #expect(three == "\u{2162}") // Ⅲ

    // 4 = IV 應使用 Ⅳ (U+2163)
    let four = RomanNumeralConverter.convert(4, format: .uppercaseURN)
    #expect(four == "\u{2163}") // Ⅳ

    // 9 = IX 應使用 Ⅸ (U+2168)
    let nine = RomanNumeralConverter.convert(9, format: .uppercaseURN)
    #expect(nine == "\u{2168}") // Ⅸ

    // 12 = XII 應使用 Ⅻ (U+216B)
    let twelve = RomanNumeralConverter.convert(12, format: .uppercaseURN)
    #expect(twelve == "\u{216B}") // Ⅻ

    // 測試小寫版本
    let threeLower = RomanNumeralConverter.convert(3, format: .lowercaseURN)
    #expect(threeLower == "\u{2172}") // ⅲ
  }
}
