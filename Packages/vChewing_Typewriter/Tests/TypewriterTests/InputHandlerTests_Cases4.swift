// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import LMAssemblyMaterials4Tests

import Shared
import Testing

import HomaSharedTestComponents
@testable import LangModelAssembly
@testable import Tekkon
@testable import Typewriter

// MARK: - 測試案例 Vol 4 (Mixed Alphanumerical Mode)

extension InputHandlerTests {
  // MARK: - Izanami Tests

  /// Izanami tests for MixedAlnum Typewriter to make sure all applausable kanji readings are inputtable.
  ///
  /// Empty prefix covers basic phonetic typing sanity.
  /// Non-empty prefixes expose known auto-split bugs (e.g. aijo6 -> aij欸 instead of ai為).
  ///
  /// - Parameters:
  ///   - thePrefix: 要測試的前綴。
  ///   - givenReadings: 要測試的 Readings，必須是注音（且所有聲調都是最後書寫，包括輕聲；陰平不寫）。
  ///     填寫空陣列的話，會自動測試倚天中文系統打字所支援的全部注音（ㄈㄨㄥˋ）除外。
  /// - Warning: This unit test case is not designed for dynamic phonabet layouts.
  @Test(arguments: ["", "ai", "AI"], [String]())
  func test_IH400_MixedAlnumKanjiInputTest_Izanami(
    _ thePrefix: String, givenReadings: [String] = []
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    defer { testHandler.clear() }

    let pfTag = thePrefix.isEmpty ? "NoPF" : "PF `\(thePrefix)`"

    testHandler.currentLM.setOptions { cfg in
      cfg.alwaysSupplyETenDOSUnigrams = true
    }

    testHandler.prefs.mixedAlphanumericalEnabled = true
    // Disable Perceptor for performance concerns.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false

    let keyMap: [Unicode.Scalar: Unicode.Scalar] = Dictionary(
      uniqueKeysWithValues: Tekkon.mapQwertyDachen.map { ($1, $0) }
    )

    var failureReport: [String: String] = [:]

    let readingsToTest: [String]
    if givenReadings.isEmpty {
      readingsToTest = LMAssembly.LMInstantiator.lmPlainBopomofo.sortedKeys
    } else {
      readingsToTest = givenReadings
    }

    try readingsToTest.forEach { reading in
      // 唯一一例不需要測試的讀音「ㄈㄨㄥˋ」，因為這是老國音、不屬於「普通話/新國音」。
      guard !reading.hasPrefix("ㄈㄨㄥ") else { return }
      let hasIntonation = reading.unicodeScalars.last.map {
        Tekkon.allowedIntonations.contains($0)
      } ?? false

      let readingWithIntonation: String
      if !hasIntonation {
        readingWithIntonation = "\(reading) "
      } else {
        readingWithIntonation = reading
      }
      let dachenSequenceAsScalars = try readingWithIntonation.unicodeScalars.map {
        try #require(keyMap[$0], "keyMap[\($0)] Failed for reading: `\(reading)`.")
      }
      let dachenSequence = String(String.UnicodeScalarView(dachenSequenceAsScalars))

      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)

      typeSentence(thePrefix)
      typeSentence(dachenSequence)

      var failureNotes: [String] = []

      if thePrefix.isEmpty {
        // This step should have nothing committed but the only in-assembler reading intact.
        // If not, this case should be asserted as a failure.
        if testHandler.assembler.length > 1 {
          failureNotes.append(
            "  Early composition is tearing `\(reading)` apart,"
              + " leaving \(testHandler.assembler.actualKeys) in Assembler."
          )
        }
        if let actualKeysFirst = testHandler.assembler.actualKeys.first, actualKeysFirst != reading {
          failureNotes.append(
            "  Early commission is tearing `\(reading)` apart,"
              + " leaving \(actualKeysFirst) in Assembler."
          )
        }
      } else {
        // 此處不用 Enter 完成 commit，因為要檢查此時 Assembler 的狀況。
        let allCommissions = testSession.recentCommissions.joined()
        // ASCII prefix + 注音後綴：commissions 必須包含 prefix。
        // 若 prefix 本身是合法注音（如 `ai` = ㄇㄛ），會被 composer 吸收而消失，
        // 此斷言即為 Izanami 的核心曝光機制——強制揭露所有 affected readings。
        if !allCommissions.contains(thePrefix) {
          failureNotes.append("  Commissions `\(allCommissions)` missing prefix `\(thePrefix)`")
        }
        // This step should have nothing committed but the prefix, plus keeping in-assembler reading intact.
        // If not, this case should be asserted as a failure.
        if testHandler.assembler.length == 1 {
          if let frontestReading = testHandler.assembler.actualKeys.last, frontestReading != reading {
            failureNotes.append(
              "  Early commission is tearing `\(reading)` apart,"
                + " leaving \(frontestReading) in Assembler."
            )
          }
        } else if testHandler.assembler.length > 1 {
          failureNotes.append(
            "  Early composition is tearing `\(reading)` apart,"
              + " leaving \(testHandler.assembler.actualKeys) in Assembler."
          )
        } else if testHandler.assembler.isEmpty {
          failureNotes
            .append(
              "  Assembler is empty. Prefix: `\(thePrefix)`"
            )
        } else if testHandler.assembler.isEmpty {
          failureNotes
            .append(
              "  Assembler length larger than 1."
                + " Assembler Keys: \(testHandler.assembler.actualKeys). Prefix: `\(thePrefix)`"
            )
        }
      }

      testSession.recentCommissions.removeAll()

      func makeFailureComment() -> String {
        let typedSeqStr = "\(thePrefix)\(dachenSequence)"
        return "- [\(pfTag)] Reading \(reading) failed on typing `\(typedSeqStr)`:\n"
          + "\(failureNotes.joined(separator: "\n"))"
      }

      if !failureNotes.isEmpty {
        failureReport[reading] = makeFailureComment()
      }
    }

    func makeFinalFailureReport() -> String {
      var resultBuffer = """
      Found \(failureReport.count) failure(s) on testing [\(pfTag)]:\n
      """
      LMAssembly.LMInstantiator.lmPlainBopomofo.sortedKeys.forEach { reading in
        guard let matchedReport = failureReport[reading] else { return }
        resultBuffer.append("\(matchedReport)\n")
      }
      resultBuffer += "Print complete. Total \(failureReport.count) failure(s) on testing [\(pfTag)]\n"
      return resultBuffer
    }

    #expect(failureReport.isEmpty, "\(makeFinalFailureReport())")
  }

  // MARK: Group A — Mixed Buffer Exit Paths

  fileprivate struct MixedBufferExitScenario: Sendable {
    let id: String
    let input: String
    let exitKeyCode: UInt16
    let expectedBufferAfterInput: String
    let expectedCommission: String
    let expectedBufferAfterExit: String
    let escToCleanInputBuffer: Bool
    let expectedStateRawValue: String?
  }

  @Test(arguments: [
    MixedBufferExitScenario(
      id: "IH401A", input: "a=",
      exitKeyCode: KeyCode.kLineFeed.rawValue,
      expectedBufferAfterInput: "", expectedCommission: "a＝",
      expectedBufferAfterExit: "", escToCleanInputBuffer: true,
      expectedStateRawValue: .none
    ),
    MixedBufferExitScenario(
      id: "IH401B", input: "u.",
      exitKeyCode: KeyCode.kBackSpace.rawValue,
      expectedBufferAfterInput: "u.", expectedCommission: "",
      expectedBufferAfterExit: "u", escToCleanInputBuffer: true,
      expectedStateRawValue: .none
    ),
    MixedBufferExitScenario(
      id: "IH401C", input: "abc",
      exitKeyCode: KeyCode.kEscape.rawValue,
      expectedBufferAfterInput: "abc", expectedCommission: "",
      expectedBufferAfterExit: "", escToCleanInputBuffer: false,
      expectedStateRawValue: "Empty"
    ),
    MixedBufferExitScenario(
      id: "IH401D", input: "abc",
      exitKeyCode: KeyCode.kLineFeed.rawValue,
      expectedBufferAfterInput: "abc", expectedCommission: "abc",
      expectedBufferAfterExit: "", escToCleanInputBuffer: true,
      expectedStateRawValue: .none
    ),
  ])
  private func test_IH401_MixedBufferExitPaths(_ s: MixedBufferExitScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    testHandler.prefs.escToCleanInputBuffer = s.escToCleanInputBuffer

    typeSentence(s.input)

    #expect(testHandler.mixedAlphanumericalBuffer == s.expectedBufferAfterInput, "\(s.id) buffer after input")

    let exitEvent = KBEvent.KeyEventData(chars: "", keyCode: s.exitKeyCode).asEvent
    #expect(testHandler.triageInput(event: exitEvent))

    if !s.expectedCommission.isEmpty {
      #expect(testSession.recentCommissions.joined() == s.expectedCommission, "\(s.id) commission")
    }
    #expect(testHandler.mixedAlphanumericalBuffer == s.expectedBufferAfterExit, "\(s.id) buffer after exit")
    if let expectedState = s.expectedStateRawValue {
      #expect(testSession.state.type.rawValue == expectedState, "\(s.id) state after exit")
    }
  }

  /// 測試中英混打模式下，Space 鍵應走注音提交路徑而非 commit ASCII 讀音字串。
  /// 驗證修正前的 bug：「ㄐㄧ 」(Dachen: r+u+Space) 會直接 commit "ㄐㄧ " 純讀音字串。
  /// 修正後：Space 按下時若 composer 有注音內容，應交由 BPMFFullMatchTypewriter 處理，
  /// 進而 commit 對應漢字，而非 ASCII buffer 原文。
  @Test
  func test_IH402_MixedSpacePhoneticCommit() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    typeSentence("ru ")

    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    let commissioned = testSession.recentCommissions.joined()
    #expect(!commissioned.contains("ㄐ"), "Space 不應 commit 讀音字串，但得到：\(commissioned)")
  }

  /// Shift + 英文字開頭（大寫）在混輸模式下應保留 ASCII 大寫，
  /// 不得被誤送去注音路徑導致如 "This" -> "Tㄘㄛ"。
  @Test
  func test_IH403_MixedUppercaseLeadStaysASCII() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    typeSentence("This")

    #expect(testHandler.mixedAlphanumericalBuffer == "This")
    #expect(testHandler.generateStateOfInputting().displayedText == "This")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "This")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// 中英連打時，若組字區已有中文，
  /// 應可依觸發鍵（Enter / Space）一次提交「中文 + ASCII」。
  @Test(arguments: [
    (id: "IH404A", typing: "code", triggerEnter: true, expectedBuffer: "code", expectedCommission: "咱地code"),
    (id: "IH404B", typing: "aq ", triggerEnter: false, expectedBuffer: "", expectedCommission: "咱地aq "),
  ])
  func test_IH404_MixedCommitChinesePlusASCIIByEnterOrSpace(
    _ scenario: (id: String, typing: String, triggerEnter: Bool, expectedBuffer: String, expectedCommission: String)
  ) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let cleanup = injectTemporaryGrams(testHandler, testKanjiData)
    defer { cleanup(); testHandler.clear() }

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }
    testSession.switchState(testHandler.generateStateOfInputting())

    typeSentence(scenario.typing)
    #expect(testHandler.mixedAlphanumericalBuffer == scenario.expectedBuffer, "\(scenario.id) buffer mismatch")

    if scenario.triggerEnter {
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    }

    #expect(testSession.recentCommissions.joined() == scenario.expectedCommission)
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// 英文前綴 + 注音後綴應可自動切分，
  /// 在後綴成為合法可提交注音時先提交英文前綴，並保留中文於組字區。
  /// 參數化覆蓋大小寫 ASCII 前綴（`Hellosu3` / `hellosu3`）。
  @Test(arguments: ["Hellosu3", "hellosu3"])
  func test_IH405_MixedAutoSplitASCIIAndPhoneticSuffix(_ mixedPrefixInput: String) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let testKanjiData = """
    ㄋㄧˇ-ㄏㄠˇ 你好 -2
    ㄋㄧˇ 你 -1
    ㄋㄧˇ 擬 -1.5
    ㄧˇ 以 -1
    ㄏㄠˇ 好 -1
    ㄏㄠˇ 郝 -1.5
    """
    let cleanup = injectTemporaryGrams(testHandler, testKanjiData)
    defer { cleanup(); testHandler.clear() }

    #expect(mixedPrefixInput.hasSuffix("su3"))
    let expectedASCIIPrefix = String(mixedPrefixInput.dropLast("su3".count))

    typeSentence(mixedPrefixInput)

    #expect(testSession.recentCommissions.joined() == expectedASCIIPrefix)
    #expect(testHandler.committableDisplayText(sansReading: true) == "你")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    typeSentence("cl3")

    let composedChinese = testHandler.committableDisplayText(sansReading: true)
    #expect(!composedChinese.isEmpty)
    #expect(composedChinese == "你好")
    #expect(testSession.recentCommissions.joined() == expectedASCIIPrefix)
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == expectedASCIIPrefix + composedChinese)
  }

  /// 純注音雙音節在 mixed mode 下用 Space 確認後，
  /// displayText 不得殘留 mixed buffer 內容（例如 `呂方z;`）。
  @Test
  func test_IH406_MixedPurePhoneticSpaceLeavesNoASCIIResidue() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let testKanjiData = """
    ㄐㄧ 機 -1
    """
    let cleanup = injectTemporaryGrams(testHandler, testKanjiData)
    defer { cleanup(); testHandler.clear() }

    typeSentence("ru ")

    #expect(testSession.state.displayedText == "機")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  // MARK: Group C1 — Auto-Split with Prior Chinese

  private struct AutoSplitWithPriorChineseScenario: Sendable {
    let id: String
    let mixedInput: String
    let expectedCommissions: [String]
    let expectedComposedText: String
    let followUpInput: String?
    let expectedComposedTextAfterFollowUp: String?
  }

  @Test(arguments: [
    AutoSplitWithPriorChineseScenario(
      id: "IH407A", mixedInput: "xu.6u4Hellod93",
      expectedCommissions: ["留意", "Hello"], expectedComposedText: "凱",
      followUpInput: "ek ", expectedComposedTextAfterFollowUp: "凱歌"
    ),
    AutoSplitWithPriorChineseScenario(
      id: "IH407B", mixedInput: "xu.6u4Thisd93",
      expectedCommissions: ["留意", "This"], expectedComposedText: "凱",
      followUpInput: nil, expectedComposedTextAfterFollowUp: nil
    ),
  ])
  private func test_IH407_AutoSplitWithPriorChinese(_ s: AutoSplitWithPriorChineseScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let testKanjiData = s.followUpInput != nil
      ? """
      ㄌㄧㄡˊ-ㄧˋ 留意 -2
      ㄌㄧㄡˊ 留 -1
      ㄧˋ 意 -1
      ㄎㄞˇ 凱 -1
      ㄍㄜ 歌 -1
      ㄎㄞˇ-ㄍㄜ 凱歌 -2
      """
      : """
      ㄌㄧㄡˊ-ㄧˋ 留意 -2
      ㄌㄧㄡˊ 留 -1
      ㄧˋ 意 -1
      ㄎㄞˇ 凱 -1
      """
    let cleanup = injectTemporaryGrams(testHandler, testKanjiData)
    defer { cleanup(); testHandler.clear() }

    typeSentence(s.mixedInput)

    #expect(testSession.recentCommissions == s.expectedCommissions, "\(s.id) commissions")
    #expect(testHandler.committableDisplayText(sansReading: true) == s.expectedComposedText, "\(s.id) composed")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    if let followUp = s.followUpInput, let expectedAfter = s.expectedComposedTextAfterFollowUp {
      typeSentence(followUp)
      #expect(testSession.recentCommissions == s.expectedCommissions, "\(s.id) commissions after follow-up")
      #expect(
        testHandler.committableDisplayText(sansReading: true) == expectedAfter,
        "\(s.id) composed after follow-up"
      )
      #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    }
  }

  // MARK: Group C2 — Auto-Split Boundary Cases

  private struct GramSpec: Sendable {
    let rawSequence: String
    let value: String
    let score: Double
  }

  private struct AutoSplitBoundaryScenario: Sendable {
    let id: String
    let input: String
    let expectedCommissions: [String]
    let expectedComposedText: String
    let expectedDisplayMustNotContain: String?
    let gramSpecs: [GramSpec]
  }

  @Test(arguments: [
    AutoSplitBoundaryScenario(
      id: "IH408A", input: "Twinsu.4",
      expectedCommissions: ["Twins"], expectedComposedText: "又",
      expectedDisplayMustNotContain: .none,
      gramSpecs: [
        GramSpec(rawSequence: "u.4", value: "又", score: 999),
        GramSpec(rawSequence: "su.4", value: "拗", score: 100),
      ]
    ),
    AutoSplitBoundaryScenario(
      id: "IH408B", input: "This5jp3",
      expectedCommissions: ["This"], expectedComposedText: "準",
      expectedDisplayMustNotContain: .none,
      gramSpecs: [
        GramSpec(rawSequence: "5jp3", value: "準", score: 100),
        GramSpec(rawSequence: "jp3", value: "穩", score: 999),
      ]
    ),
    AutoSplitBoundaryScenario(
      id: "IH408C", input: "thisgjo6",
      expectedCommissions: ["this"], expectedComposedText: "誰",
      expectedDisplayMustNotContain: .none,
      gramSpecs: [
        GramSpec(rawSequence: "gjo6", value: "誰", score: -2),
        GramSpec(rawSequence: "jo6", value: "為", score: -2),
      ]
    ),
    AutoSplitBoundaryScenario(
      id: "IH408D", input: "?c96",
      expectedCommissions: [], expectedComposedText: "?還",
      expectedDisplayMustNotContain: "癌",
      gramSpecs: [
        GramSpec(rawSequence: "c96", value: "還", score: 100),
        GramSpec(rawSequence: "96", value: "癌", score: -1),
      ]
    ),
  ])
  private func test_IH408_MixedAutoSplitBoundaryCases(_ s: AutoSplitBoundaryScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    for spec in s.gramSpecs {
      guard let gram = makeTemporaryGram(
        rawSequence: spec.rawSequence,
        value: spec.value,
        score: spec.score,
        using: testHandler
      ) else {
        Issue.record("Failed to create gram for \(spec.rawSequence)")
        return
      }
      testHandler.currentLM.insertTemporaryData(unigram: gram, isFiltering: false)
    }
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false); testHandler.clear() }

    typeSentence(s.input)

    #expect(testSession.recentCommissions == s.expectedCommissions, "\(s.id) commissions")
    let currentDisplay = testHandler.committableDisplayText(sansReading: true)
    #expect([s.expectedComposedText, "？還"].contains(currentDisplay), "\(s.id) composed: got \(currentDisplay)")
    if let mustNotContain = s.expectedDisplayMustNotContain {
      #expect(!currentDisplay.contains(mustNotContain), "\(s.id) should not contain \(mustNotContain)")
    }
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  // MARK: Group B1 — Space Finalize: Auto-Split with Chinese Suffix

  private struct SpaceFinalizeAutoSplitScenario: Sendable {
    let id: String
    let input: String
    let expectedCommissions: [String]
    let expectedComposedText: String
  }

  @Test(arguments: [
    SpaceFinalizeAutoSplitScenario(
      id: "IH409A", input: "This5j; ",
      expectedCommissions: ["This"], expectedComposedText: "裝"
    ),
    SpaceFinalizeAutoSplitScenario(
      id: "IH409B", input: "this5j; ",
      expectedCommissions: ["this"], expectedComposedText: "裝"
    ),
  ])
  private func test_IH409_MixedSpaceFinalizeAutoSplit(_ s: SpaceFinalizeAutoSplitScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    guard let gram = makeTemporaryGram(rawSequence: "5j; ", value: "裝", score: 999, using: testHandler) else {
      Issue.record("Failed to create gram for 5j; ")
      return
    }
    testHandler.currentLM.insertTemporaryData(unigram: gram, isFiltering: false)
    defer { testHandler.currentLM.clearTemporaryData(isFiltering: false); testHandler.clear() }

    typeSentence(s.input)

    #expect(testSession.recentCommissions == s.expectedCommissions, "\(s.id) commissions")
    #expect(testHandler.committableDisplayText(sansReading: true) == s.expectedComposedText, "\(s.id) composed")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// `acceptLeadingIntonations = false` 時，mixed mode 的聲調前置路徑應被封鎖。
  /// 大千排列下 `3su` = ˇ（前置）+ ㄋ + ㄧ = ㄋㄧˇ（你）；
  /// 啟用時應進入注音路徑（整段可發音），停用時應作為 ASCII 留在 buffer。
  @Test
  func test_IH410_MixedLeadingIntonationAlwaysBlockedRegardlessOfPref() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    // 先推算 3su（聲調前置）的 reading key
    var composerNi3 = testHandler.composer
    composerNi3.clear()
    composerNi3.receiveSequence("3su", isRomaji: false)
    #expect(composerNi3.isPronounceable)
    #expect(composerNi3.hasIntonation())
    guard let readingKeyNi3 = composerNi3.phonabetKeyForQuery(pronounceableOnly: true) else {
      Issue.record("reading key for 3su (ㄋㄧˇ) is nil")
      return
    }

    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: [readingKeyNi3], value: "你", score: -2),
      isFiltering: false
    )

    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testHandler.prefs.acceptLeadingIntonations = true
    }

    // MixedAlnum 永遠不接受聲調前置鍵入，無論 acceptLeadingIntonations 偏好設定為何。
    // 案例 A：acceptLeadingIntonations = true，3su 仍應留在 ASCII buffer。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.acceptLeadingIntonations = true

    typeSentence("3su")

    #expect(testHandler.mixedAlphanumericalBuffer == "3su")
    #expect(testHandler.committableDisplayText(sansReading: true).isEmpty)

    // 案例 B：acceptLeadingIntonations = false，3su 同樣留在 ASCII buffer。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.acceptLeadingIntonations = false

    typeSentence("3su")

    #expect(testHandler.mixedAlphanumericalBuffer == "3su")
    #expect(testHandler.committableDisplayText(sansReading: true).isEmpty)

    // Enter 後應提交原始 ASCII
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent)
    #expect(testSession.recentCommissions.joined().contains("3su"))
  }

  // MARK: Group B2 — Space Finalize: Pure ASCII Word

  private struct SpaceFinalizeASCIIWordScenario: Sendable {
    let id: String
    let inputSequence: [String]
    let expectedCommission: String
  }

  @Test(arguments: [
    SpaceFinalizeASCIIWordScenario(
      id: "IH411A", inputSequence: ["tod "], expectedCommission: "tod "
    ),
    SpaceFinalizeASCIIWordScenario(
      id: "IH411B", inputSequence: ["film "], expectedCommission: "film "
    ),
    SpaceFinalizeASCIIWordScenario(
      id: "IH411C", inputSequence: ["What ", "the", " "], expectedCommission: "What the "
    ),
    SpaceFinalizeASCIIWordScenario(
      id: "IH411D", inputSequence: ["What the ", "hell", " "], expectedCommission: "What the hell "
    ),
  ])
  private func test_IH411_MixedSpaceFinalizeASCIIWord(_ s: SpaceFinalizeASCIIWordScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    for step in s.inputSequence {
      typeSentence(step)
    }
    #expect(testSession.recentCommissions.joined() == s.expectedCommission, "\(s.id) commission")
    #expect(testHandler.committableDisplayText(sansReading: true).isEmpty, "\(s.id) composer should be empty")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "\(s.id) buffer should be empty")
  }

  /// 符號字元在 mixed mode 下應保留可見字面語義。
  @Test
  func test_IH412_MixedSymbolKeepsVisibleSemantics() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("!")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.generateStateOfInputting().displayedText == "！")

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "！")
  }

  /// 符號串在 mixed mode 下應維持 ASCII 提交，不得被誤導到注音路徑。
  @Test
  func test_IH413_MixedSymbolSequenceCommitsAsASCII() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("!@#$")

    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "！＠＃＄")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// 中英混輸後接符號，Enter 應提交中文 + ASCII（含符號）而不污染 composer。
  @Test
  func test_IH414_MixedEnterCommitsChinesePlusSymbolASCII() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄗㄚˊ 咱 -1
    ㄉㄜ˙ 地 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄗㄚˊ") }
    #expect(throws: Never.self) { try testHandler.assembler.insertKey("ㄉㄜ˙") }
    testSession.switchState(testHandler.generateStateOfInputting())

    typeSentence("!")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "咱地！")
  }

  /// 數字鍵與符號字元應保留不同語義（1 != !）。
  @Test
  func test_IH415_MixedDigitAndSymbolStayDistinct() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("1!")

    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "1！")
  }

  /// `=` 存在於 ASCII 前綴時，auto-split 仍可在後綴合法注音處觸發。
  /// 現行行為會剔除該符號，故先以測試鎖住目前結果。
  @Test
  func test_IH416_MixedAutoSplitKeepsASCIIWithEqualsPrefix() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄋㄧˇ 你 -1
    ㄋㄧˇ 擬 -1.5
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("Hello=")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    typeSentence("su3")
    #expect(testSession.recentCommissions.joined() == "Hello")
    #expect(testHandler.committableDisplayText(sansReading: true) == "＝你")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
  }

  /// US Keyboard + 大千下，`=` 在 mixed mode 應可保留標點語義。
  @Test
  func test_IH417_MixedEqualsKeyCommitsAsASCIIInUSDachenContext() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("a=")

    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.generateStateOfInputting().displayedText == "＝")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "a＝")
  }

  /// US Keyboard + 大千下，`\\` 在 mixed mode 應可保留標點語義。
  @Test
  func test_IH418_MixedBackslashKeyCommitsAsASCIIInUSDachenContext() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("a\\")

    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.generateStateOfInputting().displayedText == "、")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "a、")
  }

  /// ASCII 片段含 `=` / `\\` 時，mixed mode 提交結果應保持字面一致。
  @Test
  func test_IH419_MixedASCIIChunksWithEqualsAndBackslashStayLiteral() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("abc=def")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined().hasSuffix("abc＝def"))

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("abc\\def")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined().hasSuffix("abc、def"))
  }

  // MARK: Group E — Option/Shift Orthogonal Paths

  private struct OptionShiftOrthogonalScenario: Sendable {
    let id: String
    let keyCode: UInt16
    let chars: String
    let charsSansModifiers: String
    let isOptionShift: Bool
    let expectedCommittedChar: String
    let needsDynamicLexiconInjection: Bool
    let halfWidthPunctuationEnabled: Bool?
  }

  @Test(arguments: [
    OptionShiftOrthogonalScenario(
      id: "IH420A", keyCode: 24, chars: "≠", charsSansModifiers: "=",
      isOptionShift: false, expectedCommittedChar: "=",
      needsDynamicLexiconInjection: true, halfWidthPunctuationEnabled: false
    ),
    OptionShiftOrthogonalScenario(
      id: "IH420B", keyCode: 18, chars: "¡", charsSansModifiers: "1",
      isOptionShift: false, expectedCommittedChar: "1",
      needsDynamicLexiconInjection: false, halfWidthPunctuationEnabled: .none
    ),
    OptionShiftOrthogonalScenario(
      id: "IH420C", keyCode: 0, chars: "Å", charsSansModifiers: "a",
      isOptionShift: true, expectedCommittedChar: "A",
      needsDynamicLexiconInjection: false, halfWidthPunctuationEnabled: .none
    ),
    OptionShiftOrthogonalScenario(
      id: "IH420D", keyCode: 44, chars: "¿", charsSansModifiers: "/",
      isOptionShift: true, expectedCommittedChar: "?",
      needsDynamicLexiconInjection: false, halfWidthPunctuationEnabled: false
    ),
  ])
  private func test_IH420_MixedOptionShiftOrthogonalPaths(_ s: OptionShiftOrthogonalScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    if let hwPref = s.halfWidthPunctuationEnabled {
      testHandler.prefs.halfWidthPunctuationEnabled = hwPref
    }

    let event = KBEvent.KeyEventData(
      flags: s.isOptionShift ? [.option, .shift] : .option,
      chars: s.chars,
      charsSansModifiers: s.charsSansModifiers,
      keyCode: s.keyCode
    ).asEvent

    if s.needsDynamicLexiconInjection {
      let dynamicKeys = testHandler.punctuationQueryStrings(input: event)
      #expect(!dynamicKeys.isEmpty)
      let target = "〔Alt等號標點測試〕"
      let customGrams: [Homa.Gram] = dynamicKeys.map {
        .init(keyArray: [$0], value: target, score: 999)
      }
      customGrams.forEach {
        testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
      }
      #expect(dynamicKeys.contains { testHandler.currentLM.hasUnigramsFor(keyArray: [$0]) })
    }

    typeSentence("abc")

    #expect(event.isOptionHold)
    if s.isOptionShift {
      #expect(event.isShiftHold)
    }
    if s.id == "IH420B" {
      #expect(event.isMainAreaNumKey)
      #expect(event.mainAreaNumKeyChar == s.expectedCommittedChar)
    }

    #expect(testHandler.triageInput(event: event))
    #expect(testSession.recentCommissions == ["abc", s.expectedCommittedChar], "\(s.id) commissions")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testSession.state.type == .ofEmpty)

    if s.needsDynamicLexiconInjection {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }
  }

  /// 新規格：一般（無修飾鍵）標點 key 在詞庫有命中時，
  /// mixed mode 應依動態生成 key 判定為 CJK 標點輸入。
  @Test
  func test_IH421_MixedPlainPunctuationUsesDynamicLexiconKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let target = "〔等號標點測試〕"
    let plainEqual = KBEvent.KeyEventData(chars: "=", keyCode: 24).asEvent
    let dynamicKeys = testHandler.punctuationQueryStrings(input: plainEqual)
    #expect(!dynamicKeys.isEmpty)
    let customGrams: [Homa.Gram] = dynamicKeys.map {
      .init(keyArray: [$0], value: target, score: 999)
    }
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    #expect(dynamicKeys.contains { testHandler.currentLM.hasUnigramsFor(keyArray: [$0]) })
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.halfWidthPunctuationEnabled = false

    typeSentence("abc")
    #expect(dynamicKeys.contains { testHandler.currentLM.hasUnigramsFor(keyArray: [$0]) })
    #expect(testHandler.triageInput(event: plainEqual))

    #expect(testSession.recentCommissions.joined() == "abc")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.committableDisplayText(sansReading: true) == target)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "abc" + target)
  }

  // MARK: Group D — CJK Punctuation vs. Phonetic Key

  private struct PunctuationVsPhoneticScenario: Sendable {
    let id: String
    let priorInput: String
    let keyCode: UInt16?
    let chars: String?
    let target: String?
    let expectedCommission: String
    let expectedComposedText: String
  }

  @Test(arguments: [
    PunctuationVsPhoneticScenario(
      id: "IH422A", priorInput: "z; ",
      keyCode: .none, chars: .none, target: .none,
      expectedCommission: "", expectedComposedText: "芳"
    ),
    PunctuationVsPhoneticScenario(
      id: "IH422B", priorInput: "abc",
      keyCode: 33, chars: "[", target: "「",
      expectedCommission: "abc", expectedComposedText: "「"
    ),
    PunctuationVsPhoneticScenario(
      id: "IH422C", priorInput: "abc",
      keyCode: 30, chars: "]", target: "」",
      expectedCommission: "abc", expectedComposedText: "」"
    ),
  ])
  private func test_IH422_MixedPunctuationVsPhoneticKey(_ s: PunctuationVsPhoneticScenario) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    if s.id == "IH422A" {
      _ = injectTemporaryGrams(testHandler, "ㄈㄤ 芳 -1")
    } else if let target = s.target, let keyCode = s.keyCode, let chars = s.chars {
      let event = KBEvent.KeyEventData(chars: chars, keyCode: keyCode).asEvent
      let dynamicKeys = testHandler.punctuationQueryStrings(input: event)
      #expect(!dynamicKeys.isEmpty)
      let customGrams: [Homa.Gram] = dynamicKeys.map {
        .init(keyArray: [$0], value: target, score: 999)
      }
      customGrams.forEach {
        testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
      }
    }

    typeSentence(s.priorInput)

    if let keyCode = s.keyCode, let chars = s.chars {
      let event = KBEvent.KeyEventData(chars: chars, keyCode: keyCode).asEvent
      #expect(testHandler.triageInput(event: event), "\(s.id) punctuation should be handled")
    }

    #expect(testSession.recentCommissions.joined() == s.expectedCommission, "\(s.id) commission")
    if s.id == "IH422A" {
      #expect(testSession.state.displayedText == s.expectedComposedText, "\(s.id) displayedText")
    } else {
      #expect(testHandler.committableDisplayText(sansReading: true) == s.expectedComposedText, "\(s.id) composed")
    }
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)

    if s.keyCode != nil {
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
      #expect(
        testSession.recentCommissions.joined() == s.expectedCommission + s.expectedComposedText,
        "\(s.id) after Enter"
      )
    }

    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    testHandler.clear()
  }

  /// symbol menu physical key 不得被 mixed handler 攔截。
  /// 當 mixed 緩衝非空時，應先提交全部內容，再落入符號選單分流。
  @Test
  func test_IH423_MixedSymbolMenuPhysicalKeyFlushesThenFallsThroughToMenu() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("abc")
    #expect(testHandler.mixedAlphanumericalBuffer == "abc")

    let symbolMenuEvent = KBEvent.KeyEventData.symbolMenuKeyEventIntl.asEvent
    #expect(symbolMenuEvent.isSymbolMenuPhysicalKey)
    #expect(testHandler.triageInput(event: symbolMenuEvent))

    #expect(testSession.recentCommissions.joined() == "abc")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testSession.state.type == .ofSymbolTable)
  }

  /// 若 key event 只帶 base glyph（`/`）但同時有 Shift，
  /// mixed mode 應仍保留可見語義 `?`，不得退化成 `/`。
  @Test
  func test_IH424_MixedShiftSlashKeepsQuestionMarkVisibleSemantics() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentence("What")
    let shiftSlash = KBEvent.KeyEventData(
      flags: .shift,
      chars: "/",
      charsSansModifiers: "/",
      keyCode: 44
    ).asEvent
    #expect(shiftSlash.isShiftHold)
    #expect(shiftSlash.text == "/")
    #expect(shiftSlash.inputTextIgnoringModifiers == "/")

    #expect(testHandler.triageInput(event: shiftSlash))
    #expect(testHandler.mixedAlphanumericalBuffer == "What?")
    #expect(!testHandler.mixedAlphanumericalBuffer.hasSuffix("/"))

    let displayed = testHandler.generateStateOfInputting().displayedText
    #expect(displayed.hasSuffix("?") || displayed.hasSuffix("？"))

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    let commissioned = testSession.recentCommissions.joined()
    #expect(!commissioned.contains("What/"))
    #expect(commissioned.contains("What?") || commissioned.contains("What？"))
  }

  // MARK: Group F — Phase 55 Leading Digit / Shift ASCII Block

  /// 純數字鍵在 mixed mode 下不得被 composer 吸收為注音聲調。
  @Test
  func test_IH425A_MixedLeadingDigitBlockedFromComposer() throws {
    let (testHandler, _) = try prepareMixedModeHandler()

    let digit4 = KBEvent.KeyEventData(chars: "4", keyCode: 21).asEvent
    #expect(testHandler.triageInput(event: digit4))
    #expect(testHandler.mixedAlphanumericalBuffer == "4")
    #expect(testHandler.composer.isEmpty, "數字 4 不得被 composer 吸收")

    let g = KBEvent.KeyEventData(chars: "g", keyCode: 5).asEvent
    #expect(testHandler.triageInput(event: g))
    #expect(testHandler.mixedAlphanumericalBuffer == "4g")
    #expect(testHandler.composer.isEmpty)
  }

  /// Shift+數字鍵在 mixed mode 下不得被 composer 吸收。
  @Test
  func test_IH425B_MixedShiftDigitBlockedFromComposer() throws {
    let (testHandler, _) = try prepareMixedModeHandler()

    let shift4 = KBEvent.KeyEventData(
      flags: .shift, chars: "4", charsSansModifiers: "4", keyCode: 21
    ).asEvent
    #expect(testHandler.triageInput(event: shift4))
    #expect(!testHandler.composer.isEmpty == false, "Shift+數字不得被 composer 吸收")
    #expect(testHandler.mixedAlphanumericalBuffer == "$" || testHandler.mixedAlphanumericalBuffer == "4")
  }

  /// 大寫字母在 mixed mode 下不得被 composer 吸收。
  @Test
  func test_IH425C_MixedUppercaseBlockedFromComposer() throws {
    let (testHandler, _) = try prepareMixedModeHandler()

    let shiftG = KBEvent.KeyEventData(
      flags: .shift, chars: "G", charsSansModifiers: "g", keyCode: 5
    ).asEvent
    #expect(testHandler.triageInput(event: shiftG))
    #expect(testHandler.mixedAlphanumericalBuffer == "G")
    #expect(testHandler.composer.isEmpty, "大寫 G 不得被 composer 吸收")
  }

  /// leading digit 阻斷後，auto-split 應可正確切分「數字前綴 + 注音後綴」。
  /// 4 + gj;3 → 4 + 爽
  @Test
  func test_IH426_MixedLeadingDigitAutoSplitWithTone() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "ㄕㄨㄤˇ 爽 -1")
    defer { cleanup(); testHandler.clear() }

    typeSentence("4gj;3")

    #expect(testSession.recentCommissions.joined() == "4")
    #expect(testHandler.committableDisplayText(sansReading: true) == "爽")
  }

  /// leading digit + 大寫字母阻斷後，auto-split 應可正確切分。
  /// 4G + j;3 → 4G + 往
  @Test
  func test_IH427_MixedLeadingDigitAndUppercaseAutoSplitWithTone() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "ㄨㄤˇ 往 -1")
    defer { cleanup(); testHandler.clear() }

    // 手動建立事件，模擬 4 → Shift+G → j → ; → 3
    let events = [
      KBEvent.KeyEventData(chars: "4", keyCode: 21).asEvent,
      KBEvent.KeyEventData(flags: .shift, chars: "G", charsSansModifiers: "g", keyCode: 5).asEvent,
      KBEvent.KeyEventData(chars: "j", keyCode: 38).asEvent,
      KBEvent.KeyEventData(chars: ";", keyCode: 41).asEvent,
      KBEvent.KeyEventData(chars: "3", keyCode: 20).asEvent,
    ]
    events.forEach { _ = testHandler.triageInput(event: $0) }

    #expect(testSession.recentCommissions.joined() == "4G")
    #expect(testHandler.committableDisplayText(sansReading: true) == "往")
  }

  /// 非聲調數字鍵（如大千鍵盤的 5=ㄓ）在 mixed mode 下應被 composer 吸收為注音，
  /// 不得被誤當 ASCII 前綴阻斷。
  @Test
  func test_IH428_MixedNonToneDigitAllowedAsPhoneticPrefix() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "ㄓㄜˋ 這 -1")
    defer { cleanup(); testHandler.clear() }

    typeSentence("5k4")

    #expect(testSession.recentCommissions.isEmpty, "非聲調數字鍵不應被誤當 ASCII 前綴提交")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "純注音輸入不應殘留 mixed buffer")
    #expect(testHandler.committableDisplayText(sansReading: true) == "這", "5k4 應為 ㄓㄜˋ=這")
  }

  // MARK: - Fileprivate Helpers.

  fileprivate func prepareMixedModeHandler() throws -> (handler: MockInputHandler, session: MockSession) {
    guard let testHandler, let testSession else {
      struct MissingTestFixture: Error {}
      Issue.record("testHandler and testSession at least one of them is nil.")
      throw MissingTestFixture()
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    return (testHandler, testSession)
  }

  fileprivate func injectTemporaryGrams(_ handler: MockInputHandler, _ kanjiData: String) -> (() -> ()) {
    let extractedGrams = extractGrams(from: kanjiData)
    extractedGrams.forEach {
      handler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    return { handler.currentLM.clearTemporaryData(isFiltering: false) }
  }

  /// Helper to build a temporary gram from a raw phonabet sequence using the handler's composer config.
  fileprivate func makeTemporaryGram(
    rawSequence: String, value: String, score: Double, using handler: MockInputHandler
  )
    -> Homa.Gram? {
    var composer = handler.composer
    composer.clear()
    composer.receiveSequence(rawSequence, isRomaji: false)
    guard composer.isPronounceable, composer.hasIntonation() else { return nil }
    guard let key = composer.phonabetKeyForQuery(
      pronounceableOnly: handler.prefs.acceptLeadingIntonations
    ) else { return nil }
    return .init(keyArray: [key], value: value, score: score)
  }
}
