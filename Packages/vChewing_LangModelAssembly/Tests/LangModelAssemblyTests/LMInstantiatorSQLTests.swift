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

private let strBloatingKey: [String] = ["ㄔㄨㄟ", "ㄋㄧㄡˊ", "ㄅㄧ"]
private let strHaninSymbolMenuKey: [String] = ["_punctuation_list"]
private let strRefutationKey: [String] = ["ㄉㄨㄟˇ"]
private let strBoobsKey: [String] = ["ㄋㄟ", "ㄋㄟ"]
private let expectedReverseLookupResults: [String] = [
  "ㄏㄨㄛˊ", "ㄏㄜ˙", "ㄏㄨㄛ", "ㄉㄨㄥ", "ㄏㄜˊ",
  "ㄏㄜˋ", "ㄏㄢˋ", "ㄏㄨˊ", "ㄏㄨㄛ˙", "ㄏㄨㄛˋ",
]

// MARK: - LMInstantiatorSQLTests

final class LMInstantiatorSQLTests: XCTestCase {
  func testSQL() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB())
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
    }
    XCTAssertEqual(
      instance.unigramsFor(keyArray: strBloatingKey).description,
      "[(吹牛逼,-7.375), (吹牛屄,-7.399)]"
    )
    XCTAssertEqual(instance.unigramsFor(keyArray: strHaninSymbolMenuKey)[1].description, "(，,-9.9)")
    XCTAssertEqual(instance.unigramsFor(keyArray: strRefutationKey).description, "[(㨃,-9.544)]")
    XCTAssertEqual(instance.unigramsFor(keyArray: strBoobsKey).description, "[(ㄋㄟㄋㄟ,-1.0)]")
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = true
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: strBloatingKey).last?.description, "(🌳🆕🐝,-13.0)")
    XCTAssertEqual(instance.unigramsFor(keyArray: strHaninSymbolMenuKey)[1].description, "(，,-9.9)")
    XCTAssertEqual(instance.unigramsFor(keyArray: strRefutationKey).count, 10)
    XCTAssertEqual(instance.unigramsFor(keyArray: strBoobsKey).last?.description, "(☉☉,-13.0)")
    // 再測試反查。
    XCTAssertEqual(
      LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "和"),
      expectedReverseLookupResults
    )
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  func testCNSMask() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: false)
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB())
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.filterNonCNSReadings = false
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: ["ㄨㄟ"]).description, "[(危,-6.0)]")
    XCTAssertEqual(instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).description, "[(危,-6.0)]")
    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }
    XCTAssertEqual(instance.unigramsFor(keyArray: ["ㄨㄟ"]).description, "[]")
    XCTAssertEqual(instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).description, "[(危,-6.0)]")
  }
}
