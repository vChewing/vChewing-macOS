//// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

@testable import LangModelAssembly

final class LMInstantiatorNumericPadTests: XCTestCase {
  func testSQL() throws {
    let instance = vChewingLM.LMInstantiator(isCHS: true)
    instance.setOptions { config in
      config.numPadFWHWStatus = nil
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: ["_NumPad_0"]).description, "[]")
    instance.setOptions { config in
      config.numPadFWHWStatus = true
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: ["_NumPad_0"]).description, "[(０,0.0), (0,-0.1)]")
    instance.setOptions { config in
      config.numPadFWHWStatus = false
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: ["_NumPad_0"]).description, "[(0,0.0), (０,-0.1)]")
  }
}
