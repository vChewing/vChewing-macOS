// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
@testable import Typewriter
import XCTest

final class RomanNumeralTests: XCTestCase {
  func testRomanNumeralConversion() {
    // 測試基本數值（自 1 起算，羅馬數字不含 0）
    XCTAssertEqual(RomanNumeralConverter.convert(1, format: .uppercaseASCII), "I")
    XCTAssertEqual(RomanNumeralConverter.convert(4, format: .uppercaseASCII), "IV")
    XCTAssertEqual(RomanNumeralConverter.convert(5, format: .uppercaseASCII), "V")
    XCTAssertEqual(RomanNumeralConverter.convert(9, format: .uppercaseASCII), "IX")
    XCTAssertEqual(RomanNumeralConverter.convert(10, format: .uppercaseASCII), "X")
    XCTAssertEqual(RomanNumeralConverter.convert(40, format: .uppercaseASCII), "XL")
    XCTAssertEqual(RomanNumeralConverter.convert(50, format: .uppercaseASCII), "L")
    XCTAssertEqual(RomanNumeralConverter.convert(90, format: .uppercaseASCII), "XC")
    XCTAssertEqual(RomanNumeralConverter.convert(100, format: .uppercaseASCII), "C")
    XCTAssertEqual(RomanNumeralConverter.convert(400, format: .uppercaseASCII), "CD")
    XCTAssertEqual(RomanNumeralConverter.convert(500, format: .uppercaseASCII), "D")
    XCTAssertEqual(RomanNumeralConverter.convert(900, format: .uppercaseASCII), "CM")
    XCTAssertEqual(RomanNumeralConverter.convert(1_000, format: .uppercaseASCII), "M")

    // 測試含 0 的數值（僅限非首位時有效）
    XCTAssertEqual(RomanNumeralConverter.convert(10, format: .uppercaseASCII), "X")
    XCTAssertEqual(RomanNumeralConverter.convert(20, format: .uppercaseASCII), "XX")
    XCTAssertEqual(RomanNumeralConverter.convert(100, format: .uppercaseASCII), "C")
    XCTAssertEqual(RomanNumeralConverter.convert(200, format: .uppercaseASCII), "CC")
    XCTAssertEqual(RomanNumeralConverter.convert(1_000, format: .uppercaseASCII), "M")
    XCTAssertEqual(RomanNumeralConverter.convert(2_000, format: .uppercaseASCII), "MM")

    // 測試複合數值
    XCTAssertEqual(RomanNumeralConverter.convert(3, format: .uppercaseASCII), "III")
    XCTAssertEqual(RomanNumeralConverter.convert(27, format: .uppercaseASCII), "XXVII")
    XCTAssertEqual(RomanNumeralConverter.convert(1_994, format: .uppercaseASCII), "MCMXCIV")
    XCTAssertEqual(RomanNumeralConverter.convert(2_023, format: .uppercaseASCII), "MMXXIII")
    XCTAssertEqual(RomanNumeralConverter.convert(3_999, format: .uppercaseASCII), "MMMCMXCIX")

    // 測試小寫
    XCTAssertEqual(RomanNumeralConverter.convert(1_994, format: .lowercaseASCII), "mcmxciv")

    // 測試超出範圍（含 0）
    XCTAssertNil(RomanNumeralConverter.convert(0, format: .uppercaseASCII))
    XCTAssertNil(RomanNumeralConverter.convert(-1, format: .uppercaseASCII))
    XCTAssertNil(RomanNumeralConverter.convert(RomanNumeralConverter.maxValue, format: .uppercaseASCII))
  }

  func testRomanNumeralFormats() {
    let testNumber = 42

    // 測試 ASCII 大寫
    let upperASCII = RomanNumeralConverter.convert(testNumber, format: .uppercaseASCII)
    XCTAssertEqual(upperASCII, "XLII")

    // 測試 ASCII 小寫
    let lowerASCII = RomanNumeralConverter.convert(testNumber, format: .lowercaseASCII)
    XCTAssertEqual(lowerASCII, "xlii")

    // 測試全形格式（應使用 Unicode 羅馬數字符號 U+2160～U+217F）
    // 使用複合 Unicode 符號：XL = Ⅹ + Ⅼ，II = Ⅱ（複合）
    let upperFullWidth = RomanNumeralConverter.convert(testNumber, format: .uppercaseURN)
    XCTAssertNotNil(upperFullWidth)
    XCTAssertEqual(upperFullWidth, "\u{2169}\u{216C}\u{2161}") // Ⅹ Ⅼ Ⅱ

    let lowerFullWidth = RomanNumeralConverter.convert(testNumber, format: .lowercaseURN)
    XCTAssertNotNil(lowerFullWidth)
    XCTAssertEqual(lowerFullWidth, "\u{2179}\u{217C}\u{2171}") // ⅹ ⅼ ⅱ
  }

  func testUnicodeRomanNumeralCompounds() {
    // 測試在可用時是否使用複合 Unicode 符號
    // 3 = III 應使用 Ⅲ (U+2162)
    let three = RomanNumeralConverter.convert(3, format: .uppercaseURN)
    XCTAssertEqual(three, "\u{2162}") // Ⅲ

    // 4 = IV 應使用 Ⅳ (U+2163)
    let four = RomanNumeralConverter.convert(4, format: .uppercaseURN)
    XCTAssertEqual(four, "\u{2163}") // Ⅳ

    // 9 = IX 應使用 Ⅸ (U+2168)
    let nine = RomanNumeralConverter.convert(9, format: .uppercaseURN)
    XCTAssertEqual(nine, "\u{2168}") // Ⅸ

    // 12 = XII 應使用 Ⅻ (U+216B)
    let twelve = RomanNumeralConverter.convert(12, format: .uppercaseURN)
    XCTAssertEqual(twelve, "\u{216B}") // Ⅻ

    // 測試小寫版本
    let threeLower = RomanNumeralConverter.convert(3, format: .lowercaseURN)
    XCTAssertEqual(threeLower, "\u{2172}") // ⅲ
  }
}
