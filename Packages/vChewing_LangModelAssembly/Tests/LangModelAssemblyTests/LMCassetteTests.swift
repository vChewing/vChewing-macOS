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
  func testCassetteLoadWubi86() throws {
    let pathCINFile = testDataPath + "wubi.cin"
    let lmCassette = vChewingLM.LMCassette()
    NSLog("LMCassette: Start loading CIN.")
    lmCassette.open(pathCINFile)
    NSLog("LMCassette: Finished loading CIN. Entries: \(lmCassette.count)")
    print(lmCassette.unigramsFor(key: "aaaz"))
    XCTAssertEqual(lmCassette.keyNameMap.count, 26)
    XCTAssertEqual(lmCassette.charDefMap.count, 23494)
    XCTAssertEqual(lmCassette.charDefWildcardMap.count, 8390)
    XCTAssertEqual(lmCassette.octagramMap.count, 14616)
    XCTAssertEqual(lmCassette.octagramDividedMap.count, 0)
    XCTAssertEqual(lmCassette.nameENG, "Wubi")
    XCTAssertEqual(lmCassette.nameCJK, "五笔")
    XCTAssertEqual(lmCassette.maxKeyLength, 4)
    XCTAssertEqual(lmCassette.endKeys.count, 0)
    XCTAssertEqual(lmCassette.selectionKeys.count, 10)
  }
}
