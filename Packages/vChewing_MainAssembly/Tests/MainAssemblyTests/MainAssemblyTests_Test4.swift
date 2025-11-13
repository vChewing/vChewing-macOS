// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import MainAssembly

extension MainAssemblyTests {
  func test401_Session_AttrStrAPITests() throws {
    let segments: [IMEStateData.AttrStrULStyle.StyledPair] = [
      ("", .single),
      ("甲", .single),
      ("", .thick),
      ("乙", .thick),
    ]
    let attributed = IMEStateData.AttrStrULStyle.pack(segments)
    XCTAssertEqual(attributed.string, "甲乙")

    var effectiveRange = NSRange(location: NSNotFound, length: 0)
    let firstValue = attributed.attribute(.markedClauseSegment, at: 0, effectiveRange: &effectiveRange)
      as? NSNumber
    XCTAssertEqual(firstValue?.intValue, 0)
    XCTAssertEqual(effectiveRange.length, "甲".utf16.count)

    let secondIndex = max(0, attributed.string.utf16.count - "乙".utf16.count)
    var secondRange = NSRange(location: NSNotFound, length: 0)
    let secondValue = attributed.attribute(
      .markedClauseSegment,
      at: secondIndex,
      effectiveRange: &secondRange
    ) as? NSNumber
    XCTAssertEqual(secondValue?.intValue, 1)
    XCTAssertEqual(secondRange.length, "乙".utf16.count)
  }
}
