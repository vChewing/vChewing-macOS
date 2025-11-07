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
    // Test basic numbers (starting from 1, no zero in Roman numerals)
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
    XCTAssertEqual(RomanNumeralConverter.convert(1000, format: .uppercaseASCII), "M")
    
    // Test numbers with zeros (valid when not leading)
    XCTAssertEqual(RomanNumeralConverter.convert(10, format: .uppercaseASCII), "X")
    XCTAssertEqual(RomanNumeralConverter.convert(20, format: .uppercaseASCII), "XX")
    XCTAssertEqual(RomanNumeralConverter.convert(100, format: .uppercaseASCII), "C")
    XCTAssertEqual(RomanNumeralConverter.convert(200, format: .uppercaseASCII), "CC")
    XCTAssertEqual(RomanNumeralConverter.convert(1000, format: .uppercaseASCII), "M")
    XCTAssertEqual(RomanNumeralConverter.convert(2000, format: .uppercaseASCII), "MM")
    
    // Test compound numbers
    XCTAssertEqual(RomanNumeralConverter.convert(3, format: .uppercaseASCII), "III")
    XCTAssertEqual(RomanNumeralConverter.convert(27, format: .uppercaseASCII), "XXVII")
    XCTAssertEqual(RomanNumeralConverter.convert(1994, format: .uppercaseASCII), "MCMXCIV")
    XCTAssertEqual(RomanNumeralConverter.convert(2023, format: .uppercaseASCII), "MMXXIII")
    XCTAssertEqual(RomanNumeralConverter.convert(3999, format: .uppercaseASCII), "MMMCMXCIX")
    
    // Test lowercase
    XCTAssertEqual(RomanNumeralConverter.convert(1994, format: .lowercaseASCII), "mcmxciv")
    
    // Test out of range (including 0)
    XCTAssertNil(RomanNumeralConverter.convert(0, format: .uppercaseASCII))
    XCTAssertNil(RomanNumeralConverter.convert(-1, format: .uppercaseASCII))
    XCTAssertNil(RomanNumeralConverter.convert(RomanNumeralConverter.maxValue, format: .uppercaseASCII))
  }
  
  func testRomanNumeralFormats() {
    let testNumber = 42
    
    // Test uppercase ASCII
    let upperASCII = RomanNumeralConverter.convert(testNumber, format: .uppercaseASCII)
    XCTAssertEqual(upperASCII, "XLII")
    
    // Test lowercase ASCII
    let lowerASCII = RomanNumeralConverter.convert(testNumber, format: .lowercaseASCII)
    XCTAssertEqual(lowerASCII, "xlii")
    
    // Test full-width formats (should use Unicode Roman numeral characters U+2160-U+217F)
    // With compound Unicode characters: XL = Ⅹ + Ⅼ, II = Ⅱ (compound)
    let upperFullWidth = RomanNumeralConverter.convert(testNumber, format: .uppercaseFullWidth)
    XCTAssertNotNil(upperFullWidth)
    XCTAssertEqual(upperFullWidth, "\u{2169}\u{216C}\u{2161}") // Ⅹ Ⅼ Ⅱ
    
    let lowerFullWidth = RomanNumeralConverter.convert(testNumber, format: .lowercaseFullWidth)
    XCTAssertNotNil(lowerFullWidth)
    XCTAssertEqual(lowerFullWidth, "\u{2179}\u{217C}\u{2171}") // ⅹ ⅼ ⅱ
  }
  
  func testUnicodeRomanNumeralCompounds() {
    // Test that compound Unicode characters are used where available
    // 3 = III should use Ⅲ (U+2162)
    let three = RomanNumeralConverter.convert(3, format: .uppercaseFullWidth)
    XCTAssertEqual(three, "\u{2162}") // Ⅲ
    
    // 4 = IV should use Ⅳ (U+2163)
    let four = RomanNumeralConverter.convert(4, format: .uppercaseFullWidth)
    XCTAssertEqual(four, "\u{2163}") // Ⅳ
    
    // 9 = IX should use Ⅸ (U+2168)
    let nine = RomanNumeralConverter.convert(9, format: .uppercaseFullWidth)
    XCTAssertEqual(nine, "\u{2168}") // Ⅸ
    
    // 12 = XII should use Ⅻ (U+216B)
    let twelve = RomanNumeralConverter.convert(12, format: .uppercaseFullWidth)
    XCTAssertEqual(twelve, "\u{216B}") // Ⅻ
    
    // Test lowercase versions
    let threeLower = RomanNumeralConverter.convert(3, format: .lowercaseFullWidth)
    XCTAssertEqual(threeLower, "\u{2172}") // ⅲ
  }
}
