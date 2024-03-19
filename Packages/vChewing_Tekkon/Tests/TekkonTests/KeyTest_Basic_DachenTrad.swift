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
  static func checkEq(
    _ counter: inout Int,
    _ composer: inout Tekkon.Composer,
    _ strGivenSeq: String,
    _ strExpected: String
  ) {
    let strResult = composer.receiveSequence(strGivenSeq)
    guard strResult != strExpected else { return }
    let strError = "MISMATCH: \(strGivenSeq) -> \"\(strResult)\" != \"\(strExpected)\""
    print(strError)
    counter += 1
  }

  func testQwertyDachenKeys() throws {
    // Testing Dachen Traditional Mapping (QWERTY)
    var c = Tekkon.Composer(arrange: .ofDachen)
    var counter = 0
    Self.checkEq(&counter, &c, " ", " ")
    Self.checkEq(&counter, &c, "18 ", "ㄅㄚ ")
    Self.checkEq(&counter, &c, "m,4", "ㄩㄝˋ")
    Self.checkEq(&counter, &c, "5j/ ", "ㄓㄨㄥ ")
    Self.checkEq(&counter, &c, "fu.", "ㄑㄧㄡ")
    Self.checkEq(&counter, &c, "g0 ", "ㄕㄢ ")
    Self.checkEq(&counter, &c, "xup6", "ㄌㄧㄣˊ")
    Self.checkEq(&counter, &c, "xu;6", "ㄌㄧㄤˊ")
    Self.checkEq(&counter, &c, "z/", "ㄈㄥ")
    Self.checkEq(&counter, &c, "tjo ", "ㄔㄨㄟ ")
    Self.checkEq(&counter, &c, "284", "ㄉㄚˋ")
    Self.checkEq(&counter, &c, "2u4", "ㄉㄧˋ")
    Self.checkEq(&counter, &c, "hl3", "ㄘㄠˇ")
    Self.checkEq(&counter, &c, "5 ", "ㄓ ")
    Self.checkEq(&counter, &c, "193", "ㄅㄞˇ")
    XCTAssertEqual(counter, 0)
  }
}

internal extension Tekkon.Composer {
  // Exactly "convertSequenceToRawComposition()" but with shorter symbol name.
  mutating func cS2RC(_ givenSequence: String = "") -> String {
    receiveSequence(givenSequence)
  }
}
