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

private let packageRootPath = URL(fileURLWithPath: #file).pathComponents
  .prefix(while: { $0 != "Tests" }).joined(
    separator: "/"
  ).dropFirst()

private let testDataPath: String = packageRootPath + "/Tests/TestCINData/"

// MARK: - LMCassetteTests

final class LMCassetteTests: XCTestCase {
  func testCassetteLoadWubi86() throws {
    let pathCINFile = testDataPath + "wubi.cin"
    var lmCassette = LMAssembly.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    print(lmCassette.unigramsFor(key: "aaaz"))
    XCTAssertEqual(lmCassette.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette.charDefMap.count, 23_494)
    XCTAssertEqual(lmCassette.charDefWildcardMap.count, 8_390)
    XCTAssertEqual(lmCassette.octagramMap.count, 14_616)
    XCTAssertEqual(lmCassette.octagramDividedMap.count, 0)
    XCTAssertEqual(lmCassette.nameShort, "WUBI")
    XCTAssertEqual(lmCassette.nameENG, "Wubi")
    XCTAssertEqual(lmCassette.nameCJK, "五笔")
    XCTAssertEqual(lmCassette.nameIntl, "Haifeng Wubi:en;海峰五笔:zh-Hans;海峰五筆:zh-Hant")
    XCTAssertEqual(lmCassette.maxKeyLength, 4)
    XCTAssertEqual(lmCassette.endKeys.count, 0)
    XCTAssertEqual(lmCassette.selectionKeys.count, 10)
  }

  func testCassetteLoadArray30() throws {
    let pathCINFile = testDataPath + "array30.cin2"
    var lmCassette = LMAssembly.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    XCTAssertFalse(lmCassette.quickDefMap.isEmpty)
    print(lmCassette.quickSetsFor(key: ",.") ?? "")
    XCTAssertEqual(lmCassette.keyNameMap.count, 31)
    XCTAssertEqual(lmCassette.charDefMap.count, 29_491)
    XCTAssertEqual(lmCassette.charDefWildcardMap.count, 11_946)
    XCTAssertEqual(lmCassette.octagramMap.count, 0)
    XCTAssertEqual(lmCassette.octagramDividedMap.count, 0)
    XCTAssertEqual(lmCassette.nameShort, "AR30")
    XCTAssertEqual(lmCassette.nameENG, "array30")
    XCTAssertEqual(lmCassette.nameCJK, "行列30")
    XCTAssertEqual(lmCassette.nameIntl, "Array 30:en;行列30:zh-Hans;行列30:zh-Hant")
    XCTAssertEqual(lmCassette.maxKeyLength, 5)
    XCTAssertEqual(lmCassette.endKeys.count, 10)
    XCTAssertEqual(lmCassette.selectionKeys.count, 10)
  }
}
