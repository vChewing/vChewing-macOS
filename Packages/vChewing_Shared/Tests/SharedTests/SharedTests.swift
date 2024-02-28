// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

@testable import Shared
import XCTest

final class SharedTests: XCTestCase {
  // MARK: - PrefMgr().dumpShellScriptBackup()

  func testDumpedPrefs() throws {
    let prefs = PrefMgr()
    let fetched = prefs.dumpShellScriptBackup() ?? ""
    XCTAssertFalse(fetched.isEmpty)
  }

  // MARK: - CandidateTextService (Basic Tests)

  static let testDataMap: [String] = [
    #"Bing: %s"# + "\t" + #"@WEB:https://www.bing.com/search?q=%s"#,
    #"Ecosia: %s"# + "\t" + #"@WEB:https://www.ecosia.org/search?method=index&q=%s"#,
  ]

  func testDataRestoration() throws {
    let stacked = Self.testDataMap.parseIntoCandidateTextServiceStack()
    stacked.forEach { currentService in
      print(currentService)
    }
    XCTAssertEqual(stacked.rawRepresentation, Self.testDataMap)
  }

  func testCandidateServiceMenuNode() throws {
    let rootNode = CandidateTextService.getCurrentServiceMenu(
      fromMap: Self.testDataMap,
      candidate: "🍰", reading: ["ㄉㄢˋ", "ㄍㄠ"]
    )
    guard let rootNode = rootNode else {
      XCTAssertThrowsError("Root Node Construction Failed.")
      return
    }
    print(rootNode.members.map(\.name))
    print(rootNode.members.compactMap(\.asServiceMenuNode?.service))
  }
}
