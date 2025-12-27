// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

@testable import LangModelAssembly

extension LMInstantiatorTests {
  func testLMPlainBPMFDataQuery() throws {
    let instance1 = LMAssembly.LMInstantiator(isCHS: false).setOptions { config in
      config.isSCPCEnabled = true
    }
    var liu2 = instance1.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.value).prefix(3)
    var bao3 = instance1.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.value).prefix(3)
    var jie2 = instance1.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.value).prefix(3)
    XCTAssertEqual(liu2, ["劉", "流", "留"])
    XCTAssertEqual(bao3, ["保", "寶", "飽"])
    XCTAssertEqual(jie2, ["節", "潔", "傑"])
    let instance2 = LMAssembly.LMInstantiator(isCHS: true).setOptions { config in
      config.isSCPCEnabled = true
    }
    liu2 = instance2.unigramsFor(keyArray: ["ㄌㄧㄡˊ"]).map(\.value).prefix(3)
    bao3 = instance2.unigramsFor(keyArray: ["ㄅㄠˇ"]).map(\.value).prefix(3)
    jie2 = instance2.unigramsFor(keyArray: ["ㄐㄧㄝˊ"]).map(\.value).prefix(3)
    XCTAssertEqual(liu2, ["刘", "流", "留"])
    XCTAssertEqual(bao3, ["保", "宝", "饱"])
    XCTAssertEqual(jie2, ["节", "洁", "杰"])
  }
}
