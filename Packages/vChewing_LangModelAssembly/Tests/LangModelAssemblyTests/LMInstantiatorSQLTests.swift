// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LMAssemblyMaterials4Tests
import XCTest

@testable import LangModelAssembly

private let strCakeKey: [String] = ["ㄉㄢˋ", "ㄍㄠ"]
private let strHaninSymbolMenuKey: [String] = ["_punctuation_list"]
private let strZhongKey: [String] = ["ㄓㄨㄥ"]
private let strBoobsKey: [String] = ["ㄋㄟ", "ㄋㄟ"]
private let expectedReverseLookupResults: [String] = [
  "ㄏㄜˋ", "ㄏㄜ˙", "ㄏㄜˊ", "ㄏㄨㄛ", "ㄏㄨˊ",
  "ㄏㄨㄛ˙", "ㄏㄨㄛˊ", "ㄏㄨㄛˋ", "ㄏㄢˋ", "ㄉㄨㄥ",
]

// MARK: - LMInstantiatorSQLTests

final class LMInstantiatorSQLTests: XCTestCase {
  func testSQL() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    XCTAssertTrue(!sqlTestCoreLMData.isEmpty)
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlTestCoreLMData))
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
    }
    XCTAssertEqual(
      instance.unigramsFor(keyArray: strCakeKey).description,
      "[(ㄉㄢˋ-ㄍㄠ,蛋糕,-4.073)]"
    )
    XCTAssertEqual(
      instance.getHaninSymbolMenuUnigrams()[1].description,
      "(_punctuation_list,，,-9.9)"
    )
    XCTAssertEqual(
      instance.unigramsFor(keyArray: strBoobsKey).description,
      "[(ㄋㄟ-ㄋㄟ,ㄋㄟㄋㄟ,-1.0)]"
    )
    instance.setOptions { config in
      config.isCNSEnabled = true
      config.isSymbolEnabled = true
    }
    XCTAssertEqual(
      instance.unigramsFor(keyArray: strCakeKey).last?.description,
      "(ㄉㄢˋ-ㄍㄠ,🧁,-13.000001)"
    )
    XCTAssertEqual(
      instance.getHaninSymbolMenuUnigrams()[1].description,
      "(_punctuation_list,，,-9.9)"
    )
    XCTAssertEqual(instance.unigramsFor(keyArray: strZhongKey).count, 21)
    XCTAssertEqual(
      instance.unigramsFor(keyArray: strBoobsKey).last?.description,
      "(ㄋㄟ-ㄋㄟ,☉☉,-13.0)"
    )
    // 再測試反查。
    XCTAssertEqual(
      LMAssembly.LMInstantiator.getFactoryReverseLookupData(with: "和"),
      expectedReverseLookupResults
    )
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }

  func testCNSMask() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: false)
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlTestCoreLMData))
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
      config.filterNonCNSReadings = false
    }
    XCTAssertEqual(
      instance.unigramsFor(keyArray: ["ㄨㄟ"]).first(where: { $0.value == "危" })?.description,
      "(ㄨㄟ,危,-5.287)"
    )
    XCTAssertEqual(
      instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).first(where: { $0.value == "危" })?.description,
      "(ㄨㄟˊ,危,-5.287)"
    )
    instance.setOptions { config in
      config.filterNonCNSReadings = true
    }
    XCTAssertEqual(
      instance.unigramsFor(keyArray: ["ㄨㄟ"]).first(where: { $0.value == "危" }),
      nil
    )
    XCTAssertEqual(
      instance.unigramsFor(keyArray: ["ㄨㄟˊ"]).first(where: { $0.value == "危" })?.description,
      "(ㄨㄟˊ,危,-5.287)"
    )
  }
}
