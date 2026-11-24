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

  @Test("載入狀態可回報")
  func loadedState() {
    #expect(PunctuationData.isLoaded)
    #expect(PunctuationData.hasPairedEntries)
  }

  /// 資料檔缺席時回 `nil`、不崩潰：這條路徑在 5.10 legacy 佈局下曾是 `fatalError`。
  @Test("查無資源檔時回 nil")
  func missingResourceReturnsNil() {
    #expect(PunctuationData.loadText("no-such-punctuation-data-114514") == nil)
  }
}
