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
    XCTAssertNil(RomanNumeralConverter.convert(4000, format: .uppercaseASCII))
  }
  
  func testRomanNumeralFormats() {
    let testNumber = 42
    
    // Test uppercase ASCII
    let upperASCII = RomanNumeralConverter.convert(testNumber, format: .uppercaseASCII)
    XCTAssertEqual(upperASCII, "XLII")
    
    // Test lowercase ASCII
    let lowerASCII = RomanNumeralConverter.convert(testNumber, format: .lowercaseASCII)
    XCTAssertEqual(lowerASCII, "xlii")
    
    // Test full-width formats (these depend on the applyingTransformFW2HW implementation)
    let upperFullWidth = RomanNumeralConverter.convert(testNumber, format: .uppercaseFullWidth)
    XCTAssertNotNil(upperFullWidth)
    
    let lowerFullWidth = RomanNumeralConverter.convert(testNumber, format: .lowercaseFullWidth)
    XCTAssertNotNil(lowerFullWidth)
  }
}
