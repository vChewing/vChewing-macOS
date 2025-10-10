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
  // MARK: - CandidateTextService (Basic Tests)

  static let testDataMap: [String] = [
    #"Bing: %s"# + "\t" + #"@WEB:https://www.bing.com/search?q=%s"#,
    #"Ecosia: %s"# + "\t" + #"@WEB:https://www.ecosia.org/search?method=index&q=%s"#,
  ]

  func testCandidateServiceNodeTestDataRestoration() throws {
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

  /// PrefMgr().dumpShellScriptBackup()
  func testDumpedPrefs() throws {
    let prefs = PrefMgr()
    let fetched = prefs.dumpShellScriptBackup() ?? ""
    XCTAssertFalse(fetched.isEmpty)
  }

  func testEmacsCtrlNPMappings() throws {
    guard let ctrlNScalar = UnicodeScalar(14),
          let ctrlPScalar = UnicodeScalar(16) else {
      XCTFail("Unable to create control character scalars.")
      return
    }
    let ctrlNString = String(ctrlNScalar)
    let ctrlPString = String(ctrlPScalar)

    let ctrlNEvent = KBEvent(
      modifierFlags: [.control],
      characters: ctrlNString,
      charactersIgnoringModifiers: ctrlNString,
      keyCode: KeyCode.kNone.rawValue
    )
    let ctrlPEvent = KBEvent(
      modifierFlags: [.control],
      characters: ctrlPString,
      charactersIgnoringModifiers: ctrlPString,
      keyCode: KeyCode.kNone.rawValue
    )

    let horizontalCtrlN = ctrlNEvent.convertFromEmacsKeyEvent(isVerticalContext: false)
    XCTAssertEqual(horizontalCtrlN.keyCode, KeyCode.kDownArrow.rawValue)
    XCTAssertTrue(horizontalCtrlN.modifierFlags.isEmpty)
    XCTAssertFalse(horizontalCtrlN.isEmacsKey)

    let horizontalCtrlP = ctrlPEvent.convertFromEmacsKeyEvent(isVerticalContext: false)
    XCTAssertEqual(horizontalCtrlP.keyCode, KeyCode.kUpArrow.rawValue)
    XCTAssertTrue(horizontalCtrlP.modifierFlags.isEmpty)
    XCTAssertFalse(horizontalCtrlP.isEmacsKey)

    let verticalCtrlN = ctrlNEvent.convertFromEmacsKeyEvent(isVerticalContext: true)
    XCTAssertEqual(verticalCtrlN.keyCode, KeyCode.kLeftArrow.rawValue)
    XCTAssertTrue(verticalCtrlN.modifierFlags.isEmpty)
    XCTAssertFalse(verticalCtrlN.isEmacsKey)

    let verticalCtrlP = ctrlPEvent.convertFromEmacsKeyEvent(isVerticalContext: true)
    XCTAssertEqual(verticalCtrlP.keyCode, KeyCode.kRightArrow.rawValue)
    XCTAssertTrue(verticalCtrlP.modifierFlags.isEmpty)
    XCTAssertFalse(verticalCtrlP.isEmacsKey)
  }
}
