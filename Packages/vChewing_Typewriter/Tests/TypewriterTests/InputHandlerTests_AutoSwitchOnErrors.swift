// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import LangModelAssembly
import Shared
import Tekkon
import Testing
@testable import Typewriter

// MARK: - AutoSwitchOnConsecutiveErrors Tests

extension InputHandlerTests {
  @Test
  func test_AutoSwitchOnConsecutiveErrors_BasicSwitchToABC() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    var switchedToABC = false
    SessionHost.shared.switchToSystemABCInputSource = {
      switchedToABC = true
      return true
    }
    defer {
      SessionHost.shared.switchToSystemABCInputSource = { false }
    }

    // Dachen: g=ㄕ, r=ㄐ, e=ㄍ, a=ㄇ, t=ㄔ (5 consonants -> 5 consecutive errors)
    typeSentence("great")

    #expect(testSession.recentCommissions == ["great"])
    #expect(switchedToABC == true)
    #expect(testSession.isASCIIMode == false)
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_FallbackToASCIIModeWhenABCUnavailable() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    SessionHost.shared.switchToSystemABCInputSource = { false }

    // Dachen: g=ㄕ, r=ㄐ, e=ㄍ, a=ㄇ, t=ㄔ (5 consonants -> 5 consecutive errors)
    typeSentence("great")

    #expect(testSession.recentCommissions == ["great"])
    #expect(testSession.isASCIIMode == true)
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)

    // Subsequent input in ASCII mode should return false (pass-through to OS)
    let nextEvent = KBEvent.KeyEventData(chars: "s").asEvent
    let handled = testHandler.triageInput(event: nextEvent)
    #expect(!handled)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_PriorAssemblerContentDiscarded() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // Type a valid Chinese syllable first: ㄧㄡ ("u. ") -> forms a node in assembler
    typeSentence("u. ")
    #expect(!testHandler.assembler.isEmpty)

    // Now type 5 consecutive error keys: "great"
    typeSentence("great")

    // The prior assembled sentence must be discarded, only "great" committed
    #expect(testSession.recentCommissions.last == "great")
    #expect(testSession.isASCIIMode == true)
    #expect(testHandler.assembler.isEmpty)
    #expect(testHandler.composer.isEmpty)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_NormalChineseTypingDoesNotTrigger() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // Valid Chinese typing: ㄋㄧˇ ("su3") -> valid syllable
    typeSentence("su3")
    #expect(testSession.isASCIIMode == false)
    #expect(testHandler.consecutiveTypingErrors.isEmpty)

    // Followed by ㄏㄠˇ ("cl3") -> valid syllable
    typeSentence("cl3")
    #expect(testSession.isASCIIMode == false)
    #expect(testHandler.consecutiveTypingErrors.isEmpty)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_BackSpaceClearsErrorBuffer() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // Type 4 consecutive errors: "grea"
    typeSentence("grea")
    #expect(testHandler.consecutiveTypingErrors.count == 4)
    #expect(testSession.isASCIIMode == false)

    // Press BackSpace
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)
    #expect(testHandler.consecutiveTypingErrors.isEmpty)

    // Type 2 more errors: "ts"
    typeSentence("ts")
    #expect(testHandler.consecutiveTypingErrors.count == 2)
    #expect(testSession.isASCIIMode == false)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_DisabledPreference() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = false
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentence("great")
    #expect(testSession.isASCIIMode == false)
    #expect(testSession.recentCommissions.isEmpty)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_SimplifiedChineseModeIgnored() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHS
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentence("great")
    #expect(testSession.isASCIIMode == false)
    #expect(testSession.recentCommissions.isEmpty)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_PinyinModeIgnored() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)

    typeSentence("great")
    #expect(testSession.isASCIIMode == false)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_MixedAlphanumericalIgnored() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    typeSentence("great")
    #expect(testSession.isASCIIMode == false)
  }

  @Test
  func test_AutoSwitchOnConsecutiveErrors_UnmappedKeys() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    testHandler.prefs.autoSwitchToAlphanumericalOnConsecutiveErrors = true
    testSession.inputMode = .imeModeCHT
    testSession.isASCIIMode = false
    testSession.recentCommissions.removeAll()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // On Dachen, '[' and ']' are not assigned to any Bopomofo phonabet
    typeSentence("[][][")

    #expect(testSession.recentCommissions == ["[][]["])
    #expect(testSession.isASCIIMode == true)
    #expect(testHandler.composer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }
}
