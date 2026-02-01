// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
@testable import Shared
import Testing

@Suite("vChewing_Shared_Tests", .serialized)
final class SharedTests {
  // MARK: Lifecycle

  init() {
    // Keep final sanity check disabled by default for tests. Individual tests that
    // need the check can enable it explicitly.
    CandidateTextService.disableFinalSanityCheck()
  }

  deinit {
    // Restore to default state.
    mainSync {
      CandidateTextService.enableFinalSanityCheck()
    }
  }

  // MARK: Internal

  @Test
  func testCandidateServiceNodeTestDataRestoration() throws {
    let stacked = testDataMap.parseIntoCandidateTextServiceStack()
    stacked.forEach { currentService in
      print(currentService)
    }
    #expect(stacked.rawRepresentation == testDataMap)
  }

  @Test
  func testCandidateServiceMenuNode() throws {
    let rootNode = CandidateTextService.getCurrentServiceMenu(
      fromMap: testDataMap,
      candidate: "🍰", reading: ["ㄉㄢˋ", "ㄍㄠ"]
    )
    #expect(rootNode != nil)
    guard let rootNode = rootNode else { return }
    print(rootNode.members.map(\.name))
    print(rootNode.members.compactMap(\.asServiceMenuNode?.service))
  }

  @Test
  func testEmacsCtrlNPMappings() throws {
    guard let ctrlNScalar = UnicodeScalar(14),
          let ctrlPScalar = UnicodeScalar(16) else {
      Issue.record("Failed to create control character UnicodeScalars.")
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
    #expect(horizontalCtrlN.keyCode == KeyCode.kDownArrow.rawValue)
    #expect(horizontalCtrlN.modifierFlags.isEmpty)
    #expect(!horizontalCtrlN.isEmacsKey)

    let horizontalCtrlP = ctrlPEvent.convertFromEmacsKeyEvent(isVerticalContext: false)
    #expect(horizontalCtrlP.keyCode == KeyCode.kUpArrow.rawValue)
    #expect(horizontalCtrlP.modifierFlags.isEmpty)
    #expect(!horizontalCtrlP.isEmacsKey)

    let verticalCtrlN = ctrlNEvent.convertFromEmacsKeyEvent(isVerticalContext: true)
    #expect(verticalCtrlN.keyCode == KeyCode.kLeftArrow.rawValue)
    #expect(verticalCtrlN.modifierFlags.isEmpty)
    #expect(!verticalCtrlN.isEmacsKey)

    let verticalCtrlP = ctrlPEvent.convertFromEmacsKeyEvent(isVerticalContext: true)
    #expect(verticalCtrlP.keyCode == KeyCode.kRightArrow.rawValue)
    #expect(verticalCtrlP.modifierFlags.isEmpty)
    #expect(!verticalCtrlP.isEmacsKey)
  }

  @Test
  func testCandidateTextServiceURLSchemeFiltering() throws {
    CandidateTextService.enableFinalSanityCheck()
    // Reject javascript scheme
    #expect(CandidateTextService(key: "js", definedValue: "@URL:javascript:alert(1)", param: "a") == nil)
    // Accept https scheme
    let ok = CandidateTextService(key: "Bing", definedValue: "@URL:https://www.bing.com/search?q=%s", param: "test")
    #expect(ok != nil)
    // Reject data scheme
    #expect(CandidateTextService(key: "data", definedValue: "@URL:data:text/plain,hello", param: "test") == nil)
  }

  @Test
  func testCandidateTextServiceMailtoValidation() throws {
    CandidateTextService.enableFinalSanityCheck()
    // Mailto is no longer allowed; should return nil even for valid address.
    #expect(CandidateTextService(key: "mail", definedValue: "@URL:mailto:invalid-address", param: "a") == nil)
    #expect(CandidateTextService(key: "mail2", definedValue: "@URL:mailto:someone@example.com", param: "a") == nil)
  }

  @Test
  func testCandidateTextServiceFileSchemeOnlyWithinAllowedDirs() throws {
    CandidateTextService.enableFinalSanityCheck()
    // Create a temporary file path inside NSTemporaryDirectory -> should be accepted
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("testfile.txt")
    let def = "@URL:file:\(temp.path)"
    let svc = CandidateTextService(key: "file", definedValue: def, param: "a")
    // 'file' scheme is now fully rejected
    #expect(svc == nil)
    // Now a path outside allowed dirs (root) should be rejected
    let def2 = "@URL:file:/etc/passwd"
    #expect(CandidateTextService(key: "file2", definedValue: def2, param: "a") == nil)
  }

  // MARK: Private

  // MARK: - CandidateTextService (Basic Tests)

  private let testDataMap: [String] = [
    #"Bing: %s"# + "\t" + #"@WEB:https://www.bing.com/search?q=%s"#,
    #"Ecosia: %s"# + "\t" + #"@WEB:https://www.ecosia.org/search?method=index&q=%s"#,
  ]
}
