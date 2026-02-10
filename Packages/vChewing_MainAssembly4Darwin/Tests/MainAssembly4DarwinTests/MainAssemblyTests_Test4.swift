// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import Testing

@testable import MainAssembly4Darwin

extension MainAssemblyTests {
  @Test
  func test401_Session_AttrStrAPITests() throws {
    let segments: [IMEStateData.AttrStrULStyle.StyledPair] = [
      ("", .single),
      ("甲", .single),
      ("", .thick),
      ("乙", .thick),
    ]
    let attributed = IMEStateData.AttrStrULStyle.pack(segments)
    #expect(attributed.string == "甲乙")

    var effectiveRange = NSRange(location: NSNotFound, length: 0)
    let firstValue = attributed.attribute(.markedClauseSegment, at: 0, effectiveRange: &effectiveRange)
      as? NSNumber
    #expect(firstValue?.intValue == 0)
    #expect(effectiveRange.length == "甲".utf16.count)

    let secondIndex = max(0, attributed.string.utf16.count - "乙".utf16.count)
    var secondRange = NSRange(location: NSNotFound, length: 0)
    let secondValue = attributed.attribute(
      .markedClauseSegment,
      at: secondIndex,
      effectiveRange: &secondRange
    ) as? NSNumber
    #expect(secondValue?.intValue == 1)
    #expect(secondRange.length == "乙".utf16.count)
  }

  @Test
  func test402_Session_QEMUCursorReleaseHotKeyOmission() throws {
    // QEMU relies on `Control+Option+G` to release the mouse cursor.
    // This test ensures that the input method ignores this hotkey (returns false).
    let ctrlOptionGEvent = NSEvent.KeyEventData(
      type: .keyDown,
      flags: [.control, .option],
      chars: "g",
      charsSansModifiers: "g",
      keyCode: mapKeyCodesANSIForTests["g"] ?? 5
    )
    resetToEmptyAndClear()
    press(ctrlOptionGEvent, shouldHandle: false)
  }
}
