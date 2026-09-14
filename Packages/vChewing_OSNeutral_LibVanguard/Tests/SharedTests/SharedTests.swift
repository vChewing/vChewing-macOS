// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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

  @Test
  func testFcitxKeyboardEventConversion() throws {
    // Unshifted / shifted letters resolve through the QWERTY map.
    let keyA = try #require(KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: 0))
    #expect(keyA.keyCode == 0x00)
    #expect(keyA.characters == "a")
    #expect(keyA.charactersIgnoringModifiers == "a")
    #expect(keyA.modifierFlags.isEmpty)
    #expect(keyA.type == .keyDown)

    let shiftedA = try #require(KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: 1 << 0))
    #expect(shiftedA.keyCode == 0x00)
    #expect(shiftedA.characters == "A")
    #expect(shiftedA.charactersIgnoringModifiers == "a")
    #expect(shiftedA.modifierFlags == .shift)

    // The Fcitx modifier bits are re-mapped onto their Darwin counterparts.
    let expectations: [(UInt32, KBEvent.ModifierFlags)] = [
      (1 << 1, .capsLock), (1 << 2, .control), (1 << 3, .option), (1 << 6, .command),
      (1 << 4, .numericPad), (1 << 5, .function), (1 << 27, .function), (1 << 26, .command),
      (1 << 28, .option),
    ]
    for (fcitxFlag, darwinFlag) in expectations {
      let event = try #require(KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: fcitxFlag))
      #expect(event.modifierFlags == darwinFlag, "Fcitx flag \(fcitxFlag) was not mapped correctly.")
    }

    // The Fcitx repeat bit rides on isARepeat instead of any Darwin modifier.
    let repeated = try #require(
      KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: 1 << 31, isKeyDown: true)
    )
    #expect(repeated.isARepeat)
    #expect(repeated.modifierFlags.isEmpty)

    // Key-down state, including the `nil` case which means a modifier-only event.
    let released = try #require(KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: 0, isKeyDown: false))
    #expect(released.type == .keyUp)
    let flagsChanged = try #require(KBEvent(fcitxKeyCode: 0x041, fcitxModifierFlags: 0, isKeyDown: nil))
    #expect(flagsChanged.type == .flagsChanged)

    // JIS-only keys absent from the QWERTY map still yield their literal glyph.
    let yen = try #require(KBEvent(fcitxKeyCode: 0x0A5, fcitxModifierFlags: 0))
    #expect(yen.keyCode == 0x5D)
    #expect(yen.characters == "¥")
    #expect(yen.charactersIgnoringModifiers == "¥")

    // Special keys resolve through the key-code table rather than the character map.
    let backspace = try #require(KBEvent(fcitxKeyCode: 0xFF08, fcitxModifierFlags: 0))
    #expect(backspace.keyCode == KeyCode.kBackSpace.rawValue)

    // Unmapped Fcitx key codes are rejected outright.
    #expect(KBEvent(fcitxKeyCode: 0x1234_5678, fcitxModifierFlags: 0) == nil)
  }

  // MARK: Private

  // MARK: - CandidateTextService (Basic Tests)

  private let testDataMap: [String] = [
    #"Bing: %s"# + "\t" + #"@WEB:https://www.bing.com/search?q=%s"#,
    #"Ecosia: %s"# + "\t" + #"@WEB:https://www.ecosia.org/search?method=index&q=%s"#,
  ]
}
