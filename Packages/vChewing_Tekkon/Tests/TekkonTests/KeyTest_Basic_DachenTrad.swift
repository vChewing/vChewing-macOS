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
    var c = Tekkon.Composer(arrange: .ofDachen)
    XCTAssertEqual(c.cS2RC("18 "), "ㄅㄚ ")
    XCTAssertEqual(c.cS2RC("m,4"), "ㄩㄝˋ")
    XCTAssertEqual(c.cS2RC("5j/ "), "ㄓㄨㄥ ")
    XCTAssertEqual(c.cS2RC("fu."), "ㄑㄧㄡ")
    XCTAssertEqual(c.cS2RC("g0 "), "ㄕㄢ ")
    XCTAssertEqual(c.cS2RC("xup6"), "ㄌㄧㄣˊ")
    XCTAssertEqual(c.cS2RC("xu;6"), "ㄌㄧㄤˊ")
    XCTAssertEqual(c.cS2RC("z/"), "ㄈㄥ")
    XCTAssertEqual(c.cS2RC("tjo "), "ㄔㄨㄟ ")
    XCTAssertEqual(c.cS2RC("284"), "ㄉㄚˋ")
    XCTAssertEqual(c.cS2RC("2u4"), "ㄉㄧˋ")
    XCTAssertEqual(c.cS2RC("hl3"), "ㄘㄠˇ")
    XCTAssertEqual(c.cS2RC("5 "), "ㄓ ")
    XCTAssertEqual(c.cS2RC("193"), "ㄅㄞˇ")
  }
}

internal extension Tekkon.Composer {
  // Exactly "convertSequenceToRawComposition()" but with shorter symbol name.
  mutating func cS2RC(_ givenSequence: String = "") -> String {
    receiveSequence(givenSequence)
    return value
  }
}
