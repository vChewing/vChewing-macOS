// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import XCTest

@testable import CandidateWindow

final class CandidatePoolTests: XCTestCase {
  let testCandidates: [String] = [
    "八月中秋山林涼", "八月中秋", "風吹大地", "山林涼", "草枝擺", "八月", "中秋",
    "山林", "風吹", "大地", "草枝", "涼", "擺", "涼", "擺", "涼", "擺", "涼", "擺",
    "涼", "擺", "擺", "涼",
  ]

  func testPoolHorizontal() throws {
    let pool = CandidatePool(candidates: testCandidates, rowCapacity: 6)
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

  func testPoolVertical() throws {
    let pool = CandidatePool(candidates: testCandidates, columnCapacity: 6)
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
