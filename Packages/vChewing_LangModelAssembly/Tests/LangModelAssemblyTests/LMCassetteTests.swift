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
    let lmCassette98 = vChewingLM.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette98.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette98.count)")
    XCTAssertEqual(lmCassette98.charDefMap.count, 21491)
    XCTAssertEqual(lmCassette98.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette98.nameENG, "Wubi98")
    XCTAssertEqual(lmCassette98.nameCJK, "五笔98")
    XCTAssertEqual(lmCassette98.maxKeyLength, 4)
    XCTAssertEqual(lmCassette98.endKeys.count, 0)
    XCTAssertEqual(lmCassette98.selectionKeys.count, 10)
  }

  func testCassetteLoadWubi86() throws {
    let pathCINFile = testDataPath + "wubi86.cin"
    let lmCassette86 = vChewingLM.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette86.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette86.count)")
    XCTAssertEqual(lmCassette86.charDefMap.count, 10690)
    XCTAssertEqual(lmCassette86.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette86.nameENG, "Wubi86")
    XCTAssertEqual(lmCassette86.nameCJK, "五笔86")
    XCTAssertEqual(lmCassette86.maxKeyLength, 4)
    XCTAssertEqual(lmCassette86.endKeys.count, 0)
    XCTAssertEqual(lmCassette86.selectionKeys.count, 10)
  }
}
