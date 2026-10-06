// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import SwiftExtension
import Tekkon
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard

// 客體橋接：AttributedString API 與 QEMU 游標放行熱鍵。

// MARK: - SS.ClientBridge

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  @Test("SS-ClientBridge-001 Attributed-string API tests")
  func test_SS_ClientBridge_001_AttrStrAPITests() throws {
    let markedClauseSegmentKey = NSAttributedString.Key(rawValue: "NSMarkedClauseSegment")
    let segments: [IMEStateParsed.AttrStrULStyle.StyledPair] = [
      ("", .single),
      ("甲", .single),
      ("", .thick),
      ("乙", .thick),
    ]
    let attributed = IMEStateParsed.AttrStrULStyle.pack(segments)
    #expect(attributed.string == "甲乙")

    var effectiveRange = NSRange(location: NSNotFound, length: 0)
    let firstValue = intValueOfAttribute(
      attributed.attribute(markedClauseSegmentKey, at: 0, effectiveRange: &effectiveRange)
    )
    #expect(firstValue == 0)
    #expect(effectiveRange.length == "甲".utf16.count)

    let secondIndex = max(0, attributed.string.utf16.count - "乙".utf16.count)
    var secondRange = NSRange(location: NSNotFound, length: 0)
    let secondValue = intValueOfAttribute(
      attributed.attribute(markedClauseSegmentKey, at: secondIndex, effectiveRange: &secondRange)
    )
    #expect(secondValue == 1)
    #expect(secondRange.length == "乙".utf16.count)
  }

  @Test("SS-ClientBridge-002 QEMU cursor release hotkey omission")
  func test_SS_ClientBridge_002_QEMUCursorReleaseHotKeyOmission() throws {
    // QEMU relies on `Control+Option+G` to release the mouse cursor.
    // This test ensures that the input method ignores this hotkey (returns false).
    resetToEmptyAndClear()
    press(.ctrlOptionGEvent, shouldHandle: false)
  }

  // MARK: - Test harness

  /// 跨平台讀取 `NSAttributedString` 屬性內的整數值。
  ///
  /// Darwin 端該值會橋接為 `NSNumber`；Linux／Windows 端則可能原樣保留為 `Int`。
  private func intValueOfAttribute(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    return value as? Int
  }
}
