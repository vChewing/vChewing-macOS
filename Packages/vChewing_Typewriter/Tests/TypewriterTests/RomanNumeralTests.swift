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
    // Test 0 (N)
    XCTAssertEqual(RomanNumeralConverter.convert(0, format: .uppercaseASCII), "N")
    
    // Test basic numbers
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
    
    // Test compound numbers
    XCTAssertEqual(RomanNumeralConverter.convert(3, format: .uppercaseASCII), "III")
    XCTAssertEqual(RomanNumeralConverter.convert(27, format: .uppercaseASCII), "XXVII")
    XCTAssertEqual(RomanNumeralConverter.convert(1994, format: .uppercaseASCII), "MCMXCIV")
    XCTAssertEqual(RomanNumeralConverter.convert(2023, format: .uppercaseASCII), "MMXXIII")
    XCTAssertEqual(RomanNumeralConverter.convert(3999, format: .uppercaseASCII), "MMMCMXCIX")
    
    // Test lowercase
    XCTAssertEqual(RomanNumeralConverter.convert(1994, format: .lowercaseASCII), "mcmxciv")
    
    // Test out of range
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
    let upperFullWidth = RomanNumeralConverter.convert(testNumber, format: .uppercaseFullWidth)
    XCTAssertNotNil(upperFullWidth)
    // XL = \u{2169}\u{216C}, II = \u{2160}\u{2160}
    XCTAssertEqual(upperFullWidth, "\u{2169}\u{216C}\u{2160}\u{2160}")
    
    let lowerFullWidth = RomanNumeralConverter.convert(testNumber, format: .lowercaseFullWidth)
    XCTAssertNotNil(lowerFullWidth)
    // xl = \u{2179}\u{217C}, ii = \u{2170}\u{2170}
    XCTAssertEqual(lowerFullWidth, "\u{2179}\u{217C}\u{2170}\u{2170}")
  }
  
  func testUnicodeRomanNumeralZero() {
    // Test that N (for 0) is converted properly in Unicode format
    let upperFullWidth = RomanNumeralConverter.convert(0, format: .uppercaseFullWidth)
    XCTAssertNotNil(upperFullWidth)
    XCTAssertEqual(upperFullWidth, "Ⓝ")
    
    let lowerFullWidth = RomanNumeralConverter.convert(0, format: .lowercaseFullWidth)
    XCTAssertNotNil(lowerFullWidth)
    XCTAssertEqual(lowerFullWidth, "ⓝ")
  }
}
