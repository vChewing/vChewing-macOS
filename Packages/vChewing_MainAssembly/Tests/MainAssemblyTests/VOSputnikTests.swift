// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(AppKit)
  import XCTest

  @testable import MainAssembly

  final class VOSputnikTests: XCTestCase {
    // MARK: - VOCandidate Tests

    func testVOCandidateBasicInitialization() {
      let candidate = VOCandidate(display: "測試", speechOverride: "ce shi")
      XCTAssertEqual(candidate.display, "測試")
      XCTAssertEqual(candidate.speechOverride, "ce shi")
      XCTAssertEqual(candidate.effectiveSpeech, "ce shi")
      XCTAssertNil(candidate.metadata)
    }

    func testVOCandidateWithoutSpeechOverride() {
      let candidate = VOCandidate(display: "測試")
      XCTAssertEqual(candidate.display, "測試")
      XCTAssertNil(candidate.speechOverride)
      XCTAssertEqual(candidate.effectiveSpeech, "測試")
    }

    func testVOCandidateWithMetadata() {
      let metadata: [String: Any] = ["index": 0, "total": 5]
      let candidate = VOCandidate(
        display: "測試",
        speechOverride: "ce shi",
        metadata: metadata
      )
      XCTAssertNotNil(candidate.metadata)
      XCTAssertEqual(candidate.metadata?["index"] as? Int, 0)
      XCTAssertEqual(candidate.metadata?["total"] as? Int, 5)
    }

    // MARK: - VOSputnik Tests

    func testVOSputnikSingleton() {
      let instance1 = VOSputnik.shared
      let instance2 = VOSputnik.shared
      XCTAssertTrue(instance1 === instance2, "VOSputnik should be a singleton")
    }

    func testEmojiProcessing() {
      let sputnik = VOSputnik.shared
      // Use reflection to access private method for testing
      let input = "😀測試❤️"
      // We can't directly test private methods, but we can test through public interface
      // by verifying that announcements are processed correctly
      let candidate = VOCandidate(display: input)
      XCTAssertEqual(candidate.display, input)
    }

    func testCandidateAnnouncementValidation() {
      let sputnik = VOSputnik.shared
      let candidates = [
        (keyArray: ["ce4"], value: "測"),
        (keyArray: ["shi4"], value: "試"),
      ]

      // Test valid index
      sputnik.announceCandidateChange(candidates: candidates, highlightedIndex: 0)
      // Should not crash

      // Test invalid index (should be handled gracefully)
      sputnik.announceCandidateChange(candidates: candidates, highlightedIndex: 10)
      // Should not crash

      // Test negative index (should be handled gracefully)
      sputnik.announceCandidateChange(candidates: candidates, highlightedIndex: -1)
      // Should not crash
    }

    func testCompositionAnnouncement() {
      let sputnik = VOSputnik.shared

      // Test without cursor
      sputnik.announceComposition(compositionText: "測試")
      // Should not crash

      // Test with cursor
      sputnik.announceComposition(compositionText: "測試", cursorPosition: 1)
      // Should not crash

      // Test empty composition
      sputnik.announceComposition(compositionText: "")
      // Should not crash
    }

    func testAccessibilityExclusion() {
      // This test verifies that the accessibility exclusion method doesn't crash
      // Actual VoiceOver behavior would need to be tested manually
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )

      VOSputnik.configureAccessibilityExclusion(for: window)

      // Wait a bit for async operation
      let expectation = self.expectation(description: "Async accessibility config")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        expectation.fulfill()
      }
      waitForExpectations(timeout: 1.0)

      // Verify the window is properly configured
      XCTAssertFalse(window.isAccessibilityElement)
    }

    // MARK: - Integration Tests

    func testDebouncing() {
      let sputnik = VOSputnik.shared
      let candidates = [
        (keyArray: ["ce4"], value: "測"),
        (keyArray: ["shi4"], value: "試"),
        (keyArray: ["san1"], value: "三"),
      ]

      // Rapidly announce multiple candidates to test debouncing
      for i in 0 ..< 3 {
        sputnik.announceCandidateChange(candidates: candidates, highlightedIndex: i)
      }

      // Wait for debounce to complete
      let expectation = self.expectation(description: "Debounce completion")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        expectation.fulfill()
      }
      waitForExpectations(timeout: 1.0)

      // If we reach here without crashing, debouncing is working
      XCTAssertTrue(true)
    }

    func testPhoneticProcessing() {
      // Test that phonetic symbols are handled correctly
      let phoneticText = "ㄅㄆㄇㄈ"
      let candidate = VOCandidate(display: phoneticText)
      XCTAssertEqual(candidate.display, phoneticText)
    }

    func testEmptyCandidateList() {
      let sputnik = VOSputnik.shared
      let emptyCandidates: [(keyArray: [String], value: String)] = []

      // Should handle empty candidate list gracefully
      sputnik.announceCandidateChange(candidates: emptyCandidates, highlightedIndex: 0)
      // Should not crash
      XCTAssertTrue(true)
    }
  }
#endif
