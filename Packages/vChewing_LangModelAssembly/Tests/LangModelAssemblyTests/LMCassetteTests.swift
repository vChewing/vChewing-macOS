//// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

private let packageRootPath = URL(fileURLWithPath: #file).pathComponents.prefix(while: { $0 != "Tests" }).joined(
  separator: "/"
).dropFirst()

private let testDataPath: String = packageRootPath + "/Tests/TestCINData/"

final class LMCassetteTests: XCTestCase {
  func testCassetteLoadWubi98() throws {
    let pathCINFile = testDataPath + "wubi98.cin"
    var lmCassette = vChewingLM.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    XCTAssertEqual(lmCassette.charDefMap.count, 21492)
    XCTAssertEqual(lmCassette.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette.nameENG, "Wubi98")
    XCTAssertEqual(lmCassette.nameCJK, "五笔98")
    XCTAssertEqual(lmCassette.maxKeyLength, 4)
    XCTAssertEqual(lmCassette.endKeys.count, 0)
    XCTAssertEqual(lmCassette.selectionKeys.count, 10)
  }

  func testCassetteLoadWubi86() throws {
    let pathCINFile = testDataPath + "wubi86.cin"
    var lmCassette = vChewingLM.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    XCTAssertEqual(lmCassette.charDefMap.count, 10691)
    XCTAssertEqual(lmCassette.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette.nameENG, "Wubi86")
    XCTAssertEqual(lmCassette.nameCJK, "五笔86")
    XCTAssertEqual(lmCassette.maxKeyLength, 4)
    XCTAssertEqual(lmCassette.endKeys.count, 0)
    XCTAssertEqual(lmCassette.selectionKeys.count, 10)
  }
}
