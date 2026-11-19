// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import Shared
import Testing

@Suite("原廠標點資料")
struct PunctuationDataTests {
  @Test("標點語料之鍵值數")
  func recordCounts() {
    #expect(PunctuationData.records.count == 1_080)
    #expect(PunctuationData.recordsByKey.count == 223)
    #expect(PunctuationData.recordsByKey["_punct_["]?.count == 12)
    #expect(PunctuationData.recordsByKey["_punct_list"]?.count == 442)
    #expect(PunctuationData.recordsByKey["_punct_["]?.contains { $0.value == "【" } == true)
  }

  @Test("成對標點資料之對數")
  func pairedCount() {
    #expect(PunctuationData.pairedEntries.count == 29)
    #expect(
      PunctuationData.pairedEntries.contains {
        $0.left == "【" && $0.right == "】"
          && $0.leftKey == "_punct_[" && $0.rightKey == "_punct_]"
      }
    )
    #expect(
      PunctuationData.pairedEntries.contains {
        $0.left == "<" && $0.right == ">" && $0.leftKey == "_half_punct_<"
      }
    )
  }
}
