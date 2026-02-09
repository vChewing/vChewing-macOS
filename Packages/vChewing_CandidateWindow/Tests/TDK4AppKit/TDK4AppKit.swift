// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import Testing

@testable import TDK4AppKit

@Suite(.serialized)
struct TDK4AppKitTests {
  let testCandidates: [String] = [
    "二十四歲是學生", "二十四歲", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
    "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
    "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
    "嗯", "哼", "啊",
  ]

  var testCandidatesConverted: [CandidateInState] {
    testCandidates.map { candidate in
      let firstValue: [String] = .init(repeating: "", count: candidate.count)
      return (firstValue, candidate)
    }
  }

  @Test
  func testPoolHorizontal() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: testCandidatesConverted, selectionKeys: "123456", layout: .horizontal
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }

  @Test
  func testPoolVertical() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: testCandidatesConverted, selectionKeys: "123456", layout: .vertical
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }
}
