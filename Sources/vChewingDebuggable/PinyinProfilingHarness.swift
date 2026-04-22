// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import MainAssembly4Darwin

// MARK: - PinyinProfilingHarness

@MainActor
struct PinyinProfilingHarness {
  // MARK: Internal

  struct ScenarioResult {
    let stem: String
    let repeats: Int
    let elapsedNanoseconds: UInt64
    let assemblerLength: Int
    let remainingBuffer: String

    var reportLine: String {
      let elapsedMilliseconds = Double(elapsedNanoseconds) / 1_000_000
      return String(
        format: "%@ x %d -> %.3f ms | assembler=%d | remainingBuffer=%@",
        stem,
        repeats,
        elapsedMilliseconds,
        assemblerLength,
        remainingBuffer
      )
    }
  }

  func runAllScenarios() throws -> [ScenarioResult] {
    let previousPendingUnitTests = UserDefaults.pendingUnitTests
    let previousUnitTests = UserDefaults.unitTests
    let previousAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData

    UserDefaults.unitTests = UserDefaults(suiteName: suiteName)
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
    LMMgr.prepareForUnitTests()
    LMAssembly.LMInstantiator.asyncLoadingUserData = false

    defer {
      LMAssembly.LMInstantiator.asyncLoadingUserData = previousAsyncLoading
      LMAssembly.LMInstantiator.disconnectFactoryDictionary()
      Shared.InputMode.resetLangModelCache(forUnitTests: true)
      LMMgr.resetAfterUnitTests()
      UserDefaults.unitTests?.removeSuite(named: suiteName)
      UserDefaults.unitTests = previousUnitTests
      UserDefaults.pendingUnitTests = previousPendingUnitTests
    }

    Shared.InputMode.resetLangModelCache(forUnitTests: true)
    LMAssembly.LMInstantiator.disconnectFactoryDictionary()

    guard let bundledFactoryPath = LMMgr.getCoreDictionaryDBPath(factory: true) else {
      throw ProfilingHarnessError.factoryDictionaryNotFound
    }
    LMMgr.connectCoreDB(dbPath: bundledFactoryPath)

    let session = InputSession(controller: nil) { nil }
    session.ui = nil
    session.buzzer = nil
    session.clientBundleIdentifier = "org.atelierInmu.vChewing.vChewingDebuggable"
    session.syncCurrentSessionID()
    session.isActivated = true
    session.inputMode = .imeModeCHT

    guard let handler = session.inputHandler else {
      throw ProfilingHarnessError.inputHandlerUnavailable
    }

    return try [
      runScenario(stem: "shi", repeats: 8, expectedRemainingBuffer: "shi", session: session, handler: handler),
      runScenario(stem: "yi", repeats: 8, expectedRemainingBuffer: "yi", session: session, handler: handler),
    ]
  }

  // MARK: Private

  private let suiteName = "org.atelierInmu.vChewing.vChewingDebuggable.Profile"

  private func runScenario(
    stem: String,
    repeats: Int,
    expectedRemainingBuffer: String,
    session: InputSession,
    handler: InputHandler
  ) throws
    -> ScenarioResult {
    configureForPinyinProfiling(session: session, handler: handler)

    let sequence = String(repeating: stem, count: repeats)
    let startedAt = DispatchTime.now().uptimeNanoseconds
    for character in sequence {
      let event = KBEvent(
        with: .keyDown,
        modifierFlags: [],
        characters: String(character),
        charactersIgnoringModifiers: String(character),
        isARepeat: false
      )
      guard handler.triageInput(event: event) else {
        throw ProfilingHarnessError.unhandledKey(String(character))
      }
    }
    let endedAt = DispatchTime.now().uptimeNanoseconds

    guard session.state.type == .ofInputting else {
      throw ProfilingHarnessError.unexpectedState(expected: "ofInputting", actual: session.state.type.rawValue)
    }

    let expectedAssemblerLength = repeats - 1
    guard handler.assembler.length == expectedAssemblerLength else {
      throw ProfilingHarnessError.unexpectedAssemblerLength(
        expected: expectedAssemblerLength,
        actual: handler.assembler.length
      )
    }

    let remainingBuffer = handler.composer.getInlineCompositionForDisplay(isHanyuPinyin: true)
    guard remainingBuffer == expectedRemainingBuffer else {
      throw ProfilingHarnessError.unexpectedRemainingBuffer(
        expected: expectedRemainingBuffer,
        actual: remainingBuffer
      )
    }

    return .init(
      stem: stem,
      repeats: repeats,
      elapsedNanoseconds: endedAt - startedAt,
      assemblerLength: handler.assembler.length,
      remainingBuffer: remainingBuffer
    )
  }

  private func configureForPinyinProfiling(session: InputSession, handler: InputHandler) {
    handler.currentLM = Shared.InputMode.imeModeCHT.langModel
    handler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    handler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    handler.prefs.useSCPCTypingMode = false
    handler.ensureKeyboardParser()
    handler.currentLM.syncPrefs()
    session.resetInputHandler(forceComposerCleanup: true)
    session.switchState(.ofEmpty())
  }
}

// MARK: - ProfilingHarnessError

private enum ProfilingHarnessError: LocalizedError {
  case factoryDictionaryNotFound
  case inputHandlerUnavailable
  case unhandledKey(String)
  case unexpectedState(expected: String, actual: String)
  case unexpectedAssemblerLength(expected: Int, actual: Int)
  case unexpectedRemainingBuffer(expected: String, actual: String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .factoryDictionaryNotFound:
      return "Bundled factory dictionary was not found in MainAssembly4Darwin resources."
    case .inputHandlerUnavailable:
      return "InputSession did not initialize its InputHandler."
    case let .unhandledKey(key):
      return "The profiling harness failed to handle key input: \(key)."
    case let .unexpectedState(expected, actual):
      return "Unexpected session state. Expected \(expected), got \(actual)."
    case let .unexpectedAssemblerLength(expected, actual):
      return "Unexpected assembler length. Expected \(expected), got \(actual)."
    case let .unexpectedRemainingBuffer(expected, actual):
      return "Unexpected remaining buffer. Expected \(expected), got \(actual)."
    }
  }
}
