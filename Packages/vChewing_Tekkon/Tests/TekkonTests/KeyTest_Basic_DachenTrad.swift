// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import Tekkon

final class TekkonTestsKeyboardArrangments: XCTestCase {
  func testQwertyDachenKeys() throws {
    // Testing Dachen Traditional Mapping (QWERTY)
    var composer = Tekkon.Composer(arrange: .ofDachen)
    XCTAssertEqual(composer.convertSequenceToRawComposition("18 "), "ㄅㄚ ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("m,4"), "ㄩㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("5j/ "), "ㄓㄨㄥ ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fu."), "ㄑㄧㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("g0 "), "ㄕㄢ ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("xup6"), "ㄌㄧㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("xu;6"), "ㄌㄧㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("z/"), "ㄈㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tjo "), "ㄔㄨㄟ ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("284"), "ㄉㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("2u4"), "ㄉㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("hl3"), "ㄘㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("5 "), "ㄓ ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("193"), "ㄅㄞˇ")
  }
}
