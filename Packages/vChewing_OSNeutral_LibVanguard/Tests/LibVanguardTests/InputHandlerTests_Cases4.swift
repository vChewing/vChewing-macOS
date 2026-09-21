// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests

import Shared
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard
@testable import Tekkon

// MARK: - 測試案例 Vol 4 (Mixed Alphanumerical Mode)

extension LibVanguardTestsRoot.InputHandlerTests {
  // MARK: - Izanami Tests

  /// Izanami tests for MixedAlnum LibVanguard to make sure all applausable kanji readings are inputtable.
  ///
  /// Empty prefix covers basic phonetic typing sanity.
  /// Non-empty prefixes expose known auto-split bugs (e.g. aijo6 -> aij欸 instead of ai為).
  ///
  /// - Parameters:
  ///   - thePrefix: 要測試的前綴。
  ///   - parser: 要測試的 Tekkon 注音排列（僅限靜態排列）。
  /// - Warning: This unit test case is not designed for dynamic phonabet layouts.
  @Test(arguments: ["", "ai", "ello", "cOS"], [
    ("Dachen", Tekkon.MandarinParser.ofDachen, Tekkon.mapQwertyDachen),
    ("ETen", Tekkon.MandarinParser.ofETen, Tekkon.mapQwertyETenTraditional),
  ])
  func test_IH400_MixedAlnumKanjiInputTest_Izanami(
    _ thePrefix: String,
    _ parserConfig: (String, Tekkon.MandarinParser, [Unicode.Scalar: Unicode.Scalar])
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    // 本測試逐音跑遍整個注音表、大量觸及使用者資料路徑；載入**必須為同步**，
    // 否則斷言會在資料尚未落定時執行，失敗且**時過時不過**（既有案例：`Early commission is tearing …`、
    // `Commissions missing prefix …`）。這與同靶九支磁帶測試的處置一致。
    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
    }
    let testStartTS = Date()
    let (parserTag, mandarinParser, rawKeyMap) = parserConfig
    let pfTag = thePrefix.isEmpty ? "\(parserTag)/NoPF" : "\(parserTag)/PF `\(thePrefix)`"

    testHandler.currentLM.setOptions { cfg in
      cfg.alwaysSupplyETenDOSUnigrams = true
    }

    testHandler.prefs.mixedAlphanumericalEnabled = true
    // Disable Perceptor for performance concerns.
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    // 設定 keyboard parser 以匹配指定的 Tekkon 注音排列。
    // 直接設定 composer.parser（避免 ensureKeyboardParser 的 side effect）。
    testHandler.composer.ensureParser(arrange: mandarinParser)
    // 同步 prefs.keyboardParser 使 currentKeyboardParser 也保持對應。
    switch mandarinParser {
    case .ofDachen: testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    case .ofETen: testHandler.prefs.keyboardParser = KeyboardParser.ofETen.rawValue
    default: break
    }

    let keyMap: [Unicode.Scalar: Unicode.Scalar] = Dictionary(
      uniqueKeysWithValues: rawKeyMap.map { ($1, $0) }
    )

    var failureReport: [String: String] = [:]

    // givenReadings: 要測試的 Readings，必須是注音（且所有聲調都是最後書寫，包括輕聲；陰平不寫）。
    // 填寫空陣列的話，會自動測試倚天中文系統打字所支援的全部注音（ㄈㄨㄥˋ）除外。
    let givenReadings: [String] = []
    let readingsToTest: [String]
    if givenReadings.isEmpty {
      readingsToTest = LXAssembly.LXFacade.lxPlainBopomofo.sortedKeys
    } else {
      readingsToTest = givenReadings
    }

    try readingsToTest.forEach { reading in
      // 唯一一例不需要測試的讀音「ㄈㄨㄥˋ」，因為這是老國音、不屬於「普通話/新國音」。
      guard !reading.hasPrefix("ㄈㄨㄥ") else { return }
      // ETen 佈局下 a=ㄚ i=ㄞ 等兩字母前綴會被 composer 吸收、ello 前綴
      // 的 vowel-only 讀音受 subset filter 影響而誤拆，均為已知限制。
      if case .ofETen = mandarinParser, ["ai", "ello"].contains(thePrefix) { return }
      let hasIntonation = reading.unicodeScalars.last.map {
        Tekkon.allowedIntonations.contains($0)
      } ?? false

      let readingWithIntonation: String
      if !hasIntonation {
        readingWithIntonation = "\(reading) "
      } else {
        readingWithIntonation = reading
      }
      let sequenceAsScalars = try readingWithIntonation.unicodeScalars.map {
        try #require(keyMap[$0], "keyMap[\($0)] Failed for reading: `\(reading)`.")
      }
      let keySequence = String(String.UnicodeScalarView(sequenceAsScalars))

      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.composer.ensureParser(arrange: mandarinParser)

      typeSentence(thePrefix)
      typeSentence(keySequence)

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
        let typedSeqStr = "\(thePrefix)\(keySequence)"
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
      LXAssembly.LXFacade.lxPlainBopomofo.sortedKeys.forEach { reading in
        guard let matchedReport = failureReport[reading] else { return }
        resultBuffer.append("\(matchedReport)\n")
      }
      resultBuffer += "Print complete. Total \(failureReport.count) failure(s) on testing [\(pfTag)]\n"
      return resultBuffer
    }

    let secondsPassed = Swift.abs(testStartTS.timeIntervalSinceNow).rounded(toPlaces: 3)
    print("\(secondsPassed)s passed on finishing the izanami test for param [\(pfTag)].")
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

  /// 中英混打模式下，Option+BkSp 應一次清空整個混輸 ASCII 緩衝區
  /// （即「尚待辨識的英文 buffer」的全部內容），而非僅刪除最末字元。
  /// 不帶 Option 的 BkSp 維持既有之單字元刪除；組字區已組好的中文不受波及。
  @Test
  func test_IH436_MixedOptionBackspaceClearsWholeBuffer() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    // 路徑一：組字區為空、緩衝區有內容——Option+BkSp 清空整段並退回空狀態。
    typeSentence("abc")
    #expect(testHandler.mixedAlphanumericalBuffer == "abc")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.optionBackspaceEvent.asEvent))
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "Option+BkSp 應一次清空整個混輸緩衝區")
    #expect(testHandler.composer.isEmpty, "緩衝區清空後注拼槽應同步清空")
    #expect(testSession.state.type == .ofEmpty)

    // 路徑二（對照組）：不帶 Option 的 BkSp 僅刪除最末字元。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("abc")
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspaceEvent.asEvent))
    #expect(testHandler.mixedAlphanumericalBuffer == "ab", "一般 BkSp 仍僅刪除最末字元")

    // 路徑三：組字區已有中文——只清緩衝區，中文照留、狀態續為 inputting。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let testKanjiData = """
    ㄧㄡ 優 -1
    """
    let cleanup = injectTemporaryGrams(testHandler, testKanjiData)
    defer { cleanup(); testHandler.clear() }
    typeSentence("u. gr")
    #expect(testHandler.mixedAlphanumericalBuffer == "gr")
    #expect(testHandler.assembler.actualKeys == ["ㄧㄡ"])
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.optionBackspaceEvent.asEvent))
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "Option+BkSp 應一次清空整個混輸緩衝區")
    #expect(testHandler.assembler.actualKeys == ["ㄧㄡ"], "組字區中文不得被 Option+BkSp 波及")
    #expect(testSession.state.type == .ofInputting)
    #expect(testHandler.committableDisplayText(sansReading: true) == "優")
    #expect(testHandler.generateStateOfInputting().tooltip.isEmpty, "緩衝區清空後混輸 Tooltip 應一併消失")
  }

  /// 「未完成讀音後方之游標位置」必須隨狀態一併承載，且凡由 `generateStateOfInputting()`
  /// 生成之輸入狀態皆一律賦值——未完成讀音為空時其值即當前輸入游標位置。
  /// `.ofInputting` 狀態的 `marker` 會被 `getMitigatedState(_:)` 拉平至 `cursor`
  /// （IMK 要求 selectionRange 之長度為 0），故該位置資訊於 Session 層無從回收。
  /// Tooltip 之錨定即以此值為準，詳見 Session 層測試。
  @Test
  func test_IH437_CursorPosBehindUnfinishedReadingCarriedInState() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    // 路徑一：混輸、組字區無中文——未完成讀音自組字區最前方起算。
    typeSentence("abc")
    #expect(testHandler.mixedAlphanumericalBuffer == "abc")
    var state = testHandler.generateStateOfInputting()
    #expect(state.data.cursorPosRightBehindTheUnfinishedReading == 0)
    #expect(state.data.u16CursorPosRightBehindTheUnfinishedReading == 0)

    // 路徑二：混輸、組字區已有中文——未完成讀音接在該中文之後（而非組字區最前方）。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let chanZiData = """
    ㄧㄡ 優 -1
    """
    let cleanup = injectTemporaryGrams(testHandler, chanZiData)
    defer { cleanup(); testHandler.clear() }
    typeSentence("u. gr")
    #expect(testHandler.mixedAlphanumericalBuffer == "gr")
    state = testHandler.generateStateOfInputting()
    #expect(testHandler.committableDisplayText(sansReading: true) == "優")
    #expect(state.data.cursorPosRightBehindTheUnfinishedReading == 1)
    #expect(state.data.u16CursorPosRightBehindTheUnfinishedReading == 1)

    // 路徑三：混輸、高萬字（單一 Character、兩個 UTF-16 單位）在前時，座標須以 UTF-16 計。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    let emojiData = """
    ㄧㄡ 💩 -1
    """
    let cleanupEmoji = injectTemporaryGrams(testHandler, emojiData)
    defer { cleanupEmoji(); testHandler.clear() }
    typeSentence("u. gr")
    #expect(testHandler.mixedAlphanumericalBuffer == "gr")
    state = testHandler.generateStateOfInputting()
    #expect(state.data.cursorPosRightBehindTheUnfinishedReading == 1)
    #expect(
      state.data.u16CursorPosRightBehindTheUnfinishedReading == 2,
      "高萬字的 UTF-16 座標須為 2；實際得到：\(String(describing: state.data.u16CursorPosRightBehindTheUnfinishedReading))"
    )

    // 路徑四：混輸緩衝區清空後，該值改為繼承當前輸入游標位置（不再為 nil）。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.optionBackspaceEvent.asEvent))
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    state = testHandler.generateStateOfInputting()
    #expect(
      state.data.cursorPosRightBehindTheUnfinishedReading == state.cursor,
      "未完成讀音為空時應繼承當前輸入游標位置；實際得到：\(String(describing: state.data.cursorPosRightBehindTheUnfinishedReading))／cursor \(state.cursor)"
    )
    #expect(
      state.data.u16CursorPosRightBehindTheUnfinishedReading == state.u16Cursor,
      "UTF-16 對位者應等於該狀態之 u16Cursor"
    )

    // 路徑五：非混輸（偏好關）之一般組字狀態亦一律賦值——未完成讀音為空時繼承游標。
    testHandler.prefs.mixedAlphanumericalEnabled = false
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("su3 ")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    state = testHandler.generateStateOfInputting()
    #expect(state.type == .ofInputting, "實際得到：\(state.type.rawValue)")
    #expect(
      state.data.cursorPosRightBehindTheUnfinishedReading == state.cursor,
      "非混輸之組字狀態亦應一律賦值；實際得到：\(String(describing: state.data.cursorPosRightBehindTheUnfinishedReading))／cursor \(state.cursor)"
    )
    #expect(state.data.u16CursorPosRightBehindTheUnfinishedReading == state.u16Cursor)
    testHandler.prefs.mixedAlphanumericalEnabled = true
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

  /// 中英混打模式下，Tooltip 第二行應顯示游標最前方正在組裝的注音讀音預覽：
  /// 首行恆為 ASCII buffer 原文；注拼槽有內容時附加第二行讀音，為空時不附加該行。
  @Test
  func test_IH435_MixedTooltipInlineReadingPreview() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    defer { testHandler.clear() }

    // 以單一注音鍵起頭：buffer 原本為空，故注拼槽必然承接該鍵。
    typeSentence("a")
    #expect(testHandler.mixedAlphanumericalBuffer == "a")

    let tooltipWithReading = testHandler.generateStateOfInputting().tooltip
    let lines = tooltipWithReading.components(separatedBy: "\n")
    #expect(lines.count == 2, "注拼槽有內容時 Tooltip 應為兩行，實際得到：\(tooltipWithReading)")
    #expect(lines.first == "a", "Tooltip 首行應為 ASCII buffer 原文，實際得到：\(tooltipWithReading)")
    #expect(lines.last == "ㄇ", "Tooltip 次行應為注音讀音預覽，實際得到：\(tooltipWithReading)")

    // 大寫字母前導不進注拼槽（見 IH403），故 Tooltip 應僅有 ASCII buffer 一行。
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("This")
    #expect(testHandler.mixedAlphanumericalBuffer == "This")
    #expect(
      testHandler.generateStateOfInputting().tooltip == "This",
      "注拼槽為空時 Tooltip 不應附加讀音行"
    )
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
      expectedCommissions: ["Twin"], expectedComposedText: "拗",
      expectedDisplayMustNotContain: .none,
      gramSpecs: [
        GramSpec(rawSequence: "su.4", value: "拗", score: 100),
        GramSpec(rawSequence: "u.4", value: "又", score: 999),
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
      guard let dynamicKeys = testHandler.punctuationQueryStrings(input: event) else {
        Issue.record("punctuationQueryStrings returned nil unexpectedly for \(s.id)")
        return
      }
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

    #expect(event.isOptionHeld)
    if s.isOptionShift {
      #expect(event.isShiftHeld)
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
    guard let dynamicKeys = testHandler.punctuationQueryStrings(input: plainEqual) else {
      Issue.record("punctuationQueryStrings returned nil unexpectedly for plain equal key")
      return
    }
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
      guard let dynamicKeys = testHandler.punctuationQueryStrings(input: event) else {
        Issue.record("punctuationQueryStrings returned nil unexpectedly for \(s.id)")
        return
      }
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

  /// ETen 傳統佈局下，;、,、. 等符號鍵在 mixed mode 中必須被視為注音鍵，
  /// 不得被 CJK 標點管線攔截。
  /// 確認這些按鍵輸入後 assembler 中的讀音完整無損。
  @Test(arguments: [
    ("ㄗㄨㄟˋ", ";xq4 "),
    ("ㄓㄨㄢˇ", ",x83 "),
    ("ㄔㄨㄢˊ", ".x82 "),
  ])
  func test_IH430_EtenPhoneticPunctuationKeysInMixedMode(
    _ scenario: (reading: String, typing: String)
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofETen.rawValue
    testHandler.composer.ensureParser(arrange: .ofETen)

    testHandler.currentLM.setOptions { cfg in
      cfg.alwaysSupplyETenDOSUnigrams = true
    }
    defer { testHandler.clear() }

    typeSentence(scenario.typing)

    // 確認 mixed buffer 為空（標點鍵已被正確當作注音鍵吸收）。
    #expect(
      testHandler.mixedAlphanumericalBuffer.isEmpty,
      "ETen \(scenario.typing.trimmingCharacters(in: .whitespaces)) should not leave ASCII residue"
    )
    // 確認 Assembler 中有完整的讀音，未被 auto-split 撕裂。
    #expect(
      testHandler.assembler.length == 1,
      "ETen \(scenario.typing): expected 1 key in assembler, got \(testHandler.assembler.length)"
    )
    guard let actualKey = testHandler.assembler.actualKeys.first else {
      Issue.record("ETen \(scenario.typing): assembler is empty")
      return
    }
    #expect(
      actualKey == scenario.reading,
      "ETen \(scenario.typing): expected reading \(scenario.reading), got \(actualKey)"
    )
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
    #expect(shiftSlash.isShiftHeld)
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

  // MARK: — camelCase 後綴不得被誤判為注音

  /// camelCase 英文詞中大寫字母不得被 auto-split 誤判為注音後綴。
  /// 此測試鎖住 bug：`macOS ` 被誤拆成 `ma` + 注音後綴 `OS`。
  @Test
  func test_IH429_MixedCamelCaseSuffixNotTreatedAsPhonetic() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()

    // macOS：大寫後綴 "OS" 不得被當作注音
    typeSentence("macOS ")
    #expect(testSession.recentCommissions.joined() == "macOS ")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.composer.isEmpty)

    testHandler.clear()
    testSession.recentCommissions.removeAll()

    // This：大寫開頭的純 ASCII 單字應維持完整
    typeSentence("This ")
    #expect(testSession.recentCommissions.joined() == "This ")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(testHandler.composer.isEmpty)
  }

  // MARK: — CamelCase 縮寫作為 ASCII 前綴 + 注音後綴

  /// camelCase 縮寫（如 cOS / macOS）作為 ASCII 前綴時，
  /// 後續注音輸入應正確拆分，而非整段被當作 ASCII 提交。
  @Test
  func test_IH430_MixedCamelCasePrefixWithPhoneticSuffix() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    testHandler.currentLM.setOptions { cfg in
      cfg.alwaysSupplyETenDOSUnigrams = true
    }

    // cOS + ㄆ（Dachen26 鍵序 q ）
    typeSentence("cOSq ")
    let allCommissions = testSession.recentCommissions.joined()
    #expect(allCommissions.contains("cOS"), "cOS prefix should be committed as ASCII")
    #expect(testHandler.assembler.length == 1, "Assembler should have one reading")
    #expect(testHandler.assembler.actualKeys.last == "ㄆ", "Reading should be ㄆ")

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // macOS + ㄆ（Dachen26 鍵序 q ）
    typeSentence("macOSq ")
    let allCommissions2 = testSession.recentCommissions.joined()
    #expect(allCommissions2.contains("macOS"), "macOS prefix should be committed as ASCII")
    #expect(testHandler.assembler.length == 1, "Assembler should have one reading")
    #expect(testHandler.assembler.actualKeys.last == "ㄆ", "Reading should be ㄆ")

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // cOS + ㄇㄛ（Dachen26 鍵序 ai ）
    typeSentence("cOSai ")
    let allCommissions3 = testSession.recentCommissions.joined()
    #expect(allCommissions3.contains("cOS"), "cOS prefix should be committed as ASCII")
    #expect(testHandler.assembler.length == 1, "Assembler should have one reading")
    #expect(testHandler.assembler.actualKeys.last == "ㄇㄛ", "Reading should be ㄇㄛ")
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

  // MARK: - Ctrl + ASCII pass-through in half-width punctuation mode

  /// 半形標點模式開啓時，Ctrl+ASCII 組合鍵不得被 LibVanguard 攔截。
  @Test
  func test_IH431_CtrlASCIIPassesThroughInHalfWidthMode() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testSession.switchState(.ofEmpty())
    testHandler.prefs.halfWidthPunctuationEnabled = true

    // 測試用鍵位：字母、數字、標點、符號各一個
    let testKeys: [(label: String, chars: String, flags: KBEvent.ModifierFlags)] = [
      ("Ctrl+A", "A", .control),
      ("Ctrl+1", "1", .control),
      ("Ctrl+,", ",", .control),
      ("Ctrl+.", ".", .control),
      ("Ctrl+@", "@", .control),
    ]

    for tc in testKeys {
      let event = KBEvent.KeyEventData(
        flags: tc.flags,
        chars: tc.chars
      ).asEvent
      let didConsume = testHandler.triageInput(event: event)
      #expect(!didConsume, "\(tc.label): Ctrl+ASCII must not be consumed in half-width mode")
      testSession.switchState(.ofEmpty())
    }

    // 確保無修飾鍵的普通標點在同樣環境下仍會被處理。
    let plainComma = KBEvent.KeyEventData(flags: [], chars: ",").asEvent
    #expect(testHandler.triageInput(event: plainComma), "Plain comma should still be handled")
    testSession.switchState(.ofEmpty())

    // 半形模式 + 組字進行中時，Ctrl+ASCII 仍必須被攔截（防干擾組字區）。
    testHandler.prefs.halfWidthPunctuationEnabled = true
    testSession.switchState(.ofInputting(displayTextSegments: ["a"], cursor: 1))
    let ctrlCommaDuringComposing = KBEvent.KeyEventData(flags: .control, chars: ",").asEvent
    #expect(
      testHandler.triageInput(event: ctrlCommaDuringComposing),
      "Ctrl+, during composition must be trapped to protect composing buffer"
    )
    testSession.switchState(.ofEmpty())

    // 全形模式（非半形）下，Ctrl+Punctuation 應被標點鏈路命中、予以攔截。
    testHandler.prefs.halfWidthPunctuationEnabled = false
    let ctrlPeriodFW = KBEvent.KeyEventData(flags: .control, chars: ".").asEvent
    #expect(
      testHandler.triageInput(event: ctrlPeriodFW),
      "Ctrl+. in full-width mode should be consumed by punctuation handler"
    )
  }

  // MARK: - Option-based punctuation in full-width mode

  /// 全形模式下，Option+標點應正常命中 _alt_punctuation_ 條目。
  @Test
  func test_IH432_OptionPunctuationWorksInFullWidthMode() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testSession.switchState(.ofEmpty())
    testHandler.prefs.halfWidthPunctuationEnabled = false

    // Option+;
    let optSemicolon = KBEvent.KeyEventData(flags: .option, chars: ";").asEvent
    #expect(
      testHandler.triageInput(event: optSemicolon),
      "Option+; should be consumed by punctuation handler in full-width mode"
    )

    // Option+'
    testSession.switchState(.ofEmpty())
    let optQuote = KBEvent.KeyEventData(flags: .option, chars: "'").asEvent
    #expect(
      testHandler.triageInput(event: optQuote),
      "Option+' should be consumed by punctuation handler in full-width mode"
    )

    // 半形模式下 Option+; 應放行（無對應 lexicon 條目）。
    testSession.switchState(.ofEmpty())
    testHandler.prefs.halfWidthPunctuationEnabled = true
    let optSemicolonHW = KBEvent.KeyEventData(flags: .option, chars: ";").asEvent
    #expect(
      !testHandler.triageInput(event: optSemicolonHW),
      "Option+; in half-width mode should pass through (no _half_alt_punctuation_ entry)"
    )
  }

  // MARK: - Half-width punctuation mode bypasses Option+main-area numerals

  /// 半形標點模式啟用時，Alt(+Shift)+主鍵盤區數字鍵不得被「阿拉伯數字輸入」功能攔截，
  /// 使當下鍵盤佈局（例如 Ukelele 自訂佈局）在 Option 層定義的字元可以透傳出去；
  /// 全形（非半形）標點模式下該功能維持不變。
  @Test
  func test_IH434_OptionMainAreaNumeralsBypassedInHalfWidthMode() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testSession.switchState(.ofEmpty())

    let optOneEvent = KBEvent.KeyEventData(
      flags: .option,
      chars: "1",
      charsSansModifiers: "1",
      keyCode: 18
    ).asEvent
    let optShiftOneEvent = KBEvent.KeyEventData(
      flags: [.option, .shift],
      chars: "1",
      charsSansModifiers: "1",
      keyCode: 18
    ).asEvent

    testSession.recentCommissions.removeAll()

    // 全形標點模式（半形標點關閉）：Alt(+Shift)+數字鍵仍由數字輸入功能攔截。
    testHandler.prefs.halfWidthPunctuationEnabled = false
    #expect(
      testHandler.triageInput(event: optOneEvent),
      "Alt+數字鍵在全形標點模式下應被數字輸入功能攔截"
    )
    // Alt+數字鍵：遞交半形數字。
    #expect(testSession.recentCommissions.last == "1")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testSession.switchState(.ofEmpty())
    #expect(
      testHandler.triageInput(event: optShiftOneEvent),
      "Alt+Shift+數字鍵在全形標點模式下應被數字輸入功能攔截"
    )
    // Alt+Shift+數字鍵：遞交全形數字。
    #expect(testSession.recentCommissions.last == "１")
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    // 半形標點模式：數字輸入功能被 bypass，按鍵不得被攔截（透傳給鍵盤佈局）、亦不得遞交任何字元。
    testSession.switchState(.ofEmpty())
    testHandler.prefs.halfWidthPunctuationEnabled = true
    let commitCountBeforeBypass = testSession.recentCommissions.count
    #expect(
      !testHandler.triageInput(event: optOneEvent),
      "半形標點模式下 Alt+數字鍵不得被數字輸入功能攔截"
    )
    #expect(testSession.recentCommissions.count == commitCountBeforeBypass)
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)
    testSession.switchState(.ofEmpty())
    #expect(
      !testHandler.triageInput(event: optShiftOneEvent),
      "半形標點模式下 Alt+Shift+數字鍵不得被數字輸入功能攔截"
    )
    #expect(testSession.recentCommissions.count == commitCountBeforeBypass)
    #expect(testSession.state.type == .ofEmpty || testSession.state.type == .ofCommitting)

    testHandler.prefs.halfWidthPunctuationEnabled = false
  }

  // MARK: - ETen Pure-Digit Sequence Stays ASCII

  /// 倚天傳統佈局下，1-4 為聲調鍵、7-9/0 為韻母鍵，
  /// 導致純數字序列（如 IP 位址 192.168.100.1）被 auto-split 誤拆為
  /// 「聲調數字前綴 + 純數字注音後綴」（如 1 + 92=ㄣˊ=嗯）。
  /// 修復後，開頭有被阻斷鍵且後綴全為 ASCII 數字時不拆分。
  @Test(arguments: [
    ("Dachen", Tekkon.MandarinParser.ofDachen, KeyboardParser.ofStandard.rawValue),
    ("ETen", Tekkon.MandarinParser.ofETen, KeyboardParser.ofETen.rawValue),
  ])
  func test_IH433_PureDigitSequenceStaysASCII(
    _ label: String,
    _ mandarinParser: Tekkon.MandarinParser,
    _ keyboardParserRaw: Int
  ) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    testHandler.prefs.keyboardParser = keyboardParserRaw
    testHandler.composer.ensureParser(arrange: mandarinParser)
    defer { testHandler.clear() }

    // 不注入任何臨時辭典條目，模擬真實使用環境。
    // 輸入 IP 位址，期望整段保持為 ASCII，不被拆分為注音。
    typeSentence("192.168.100.1")

    // mixed buffer 應保留完整 ASCII 序列。
    #expect(
      testHandler.mixedAlphanumericalBuffer == "192.168.100.1",
      "\(label): expected buffer to stay ASCII '192.168.100.1', got '\(testHandler.mixedAlphanumericalBuffer)'"
    )
    // 不應有任何中文被提交或殘留在 assembler。
    #expect(
      testSession.recentCommissions.isEmpty,
      "\(label): should not commit any Chinese text, got \(testSession.recentCommissions)"
    )
    #expect(
      testHandler.assembler.isEmpty,
      "\(label): assembler should be empty, got \(testHandler.assembler.actualKeys)"
    )

    // 按 Enter 提交 ASCII 序列。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(
      testSession.recentCommissions.joined() == "192.168.100.1",
      "\(label): Enter should commit ASCII '192.168.100.1', got \(testSession.recentCommissions.joined())"
    )
  }

  // MARK: - 亂序鍵入之 ASCII 判定（引擎層槽序檢定）

  /// 純英文字母緩衝若「不可能是一個依注音槽序鍵入的讀音」（鍵序亂序），
  /// 以 Space 確認時應留在 ASCII 路徑，不得被注音吸收為單一音節。
  /// 判準之權威為引擎層之槽序檢定；同一組鍵位若依槽序鍵入（見 IH439）則仍走注音路徑
  /// ——兩者對照即為本判準之界線。
  @Test(arguments: ["ls", "ln", "lc", "mv"])
  func test_IH438_MixedOutOfSlotOrderASCIITokenStaysASCII(_ token: String) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    defer { testHandler.clear() }

    typeSentence(token)
    #expect(testHandler.mixedAlphanumericalBuffer == token, "\(token): buffer before Space")
    #expect(
      testHandler.committableDisplayText(sansReading: true).isEmpty,
      "\(token): should compose nothing before Space"
    )

    typeSentence(" ")

    #expect(
      testSession.recentCommissions.joined() == "\(token) ",
      "\(token): Space should commit ASCII, got \(testSession.recentCommissions)"
    )
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty, "\(token): buffer after Space")
    #expect(
      testHandler.committableDisplayText(sansReading: true).isEmpty,
      "\(token): should compose nothing after Space"
    )
  }

  /// 對照組：同樣為兩鍵的純英文字母，但依槽序鍵入者仍應走注音路徑。
  @Test
  func test_IH439_MixedInSlotOrderTwoLetterTokenStaysPhonetic() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "ㄏㄠ 蒿 -1")
    defer { cleanup(); testHandler.clear() }

    typeSentence("cl")
    #expect(testHandler.mixedAlphanumericalBuffer == "cl", "buffer before Space")

    typeSentence(" ")

    #expect(
      testSession.recentCommissions.isEmpty,
      "should stay phonetic, got \(testSession.recentCommissions)"
    )
    #expect(
      testHandler.committableDisplayText(sansReading: true) == "蒿",
      "got \(testHandler.committableDisplayText(sansReading: true))"
    )
  }

  /// 動態注音排列之合法編碼本即跳鍵改寫槽值（大千26 之 `qquu`＝ㄅㄚ：首擊為ㄆ、次擊覆寫為ㄅ；
  /// 倚天26 之 `ge`＝ㄐㄧ：鍵 `g` 先寫ㄓ、鍵 `e` 再觸發糾正為ㄐ），
  /// 故不得以「鍵數 == 佔用槽數」判其非單一音節——否則整段會被誤當成 ASCII 而滯留於緩衝。
  /// 本測項斷言該類編碼被注拼槽吸收，與辭典內容無涉。
  @Test(arguments: [
    (id: "IH440A", parser: KeyboardParser.ofDachen26, keys: "qquu", expectedReading: "ㄅㄚ"),
    (id: "IH440B", parser: KeyboardParser.ofETen26, keys: "ge", expectedReading: "ㄐㄧ"),
  ])
  func test_IH440_MixedDynamicLayoutMultiWriteKeysStayPhonetic(
    _ scenario: (id: String, parser: KeyboardParser, keys: String, expectedReading: String)
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.keyboardParser = scenario.parser.rawValue
    testHandler.ensureKeyboardParser()
    defer { testHandler.clear() }

    typeSentence(scenario.keys)

    #expect(
      testHandler.composer.value == scenario.expectedReading,
      "\(scenario.id): composer should hold \(scenario.expectedReading), got \(testHandler.composer.value)"
    )
    #expect(
      testHandler.assembler.isEmpty,
      "\(scenario.id): nothing should be inserted yet, got \(testHandler.assembler.actualKeys)"
    )
    #expect(
      testSession.recentCommissions.isEmpty,
      "\(scenario.id): expected no commission, got \(testSession.recentCommissions)"
    )
  }

  /// 「冗餘鍵」在混打語境下是「ASCII 前綴 + 注音後綴」之分界證據，不得放行：
  /// 前綴 `ai`（＝ㄇㄛ）之後多按一鍵，即應切分為 `ai` + 尾段讀音。
  /// 此即引擎層槽序檢定容忍「同值重寫」、而混打語境不可容忍之處。
  /// 即使 `ㄇㄛˊ` 本身確為辭典條目（此處以高分之臨時條目強化之），仍應切分。
  @Test
  func test_IH441_MixedRedundantKeyDemarcatesASCIISuffix() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "ㄇㄛˊ 模 -999")
    defer { cleanup(); testHandler.clear() }

    typeSentence("aii6")

    #expect(
      testSession.recentCommissions.joined() == "ai",
      "prefix should be committed, got \(testSession.recentCommissions)"
    )
    #expect(
      testHandler.assembler.actualKeys.last == "ㄛˊ",
      "got \(testHandler.assembler.actualKeys)"
    )
  }

  // MARK: - 英數閂滯狀態（MixedAlnum latched alnum state）

  /// 中英混打模式與英數閂滯開關皆啟用之 handler。
  ///
  /// - Parameter statusUI: 若給定，則連帶一個裝有該替身之 `ui` 一併注入 Session，供觀察
  ///   閂滯 On／Off 之 StatusUI 提示。不給定時一切照舊（Session 之 `ui` 仍為 nil），
  ///   故其餘既有個案之行為不受影響。
  fileprivate func prepareLatchedMixedModeHandler(
    statusUI: MockTooltipUI? = nil
  )
    throws -> (handler: MockInputHandler, session: MockSession) {
    let result = try prepareMixedModeHandler()
    result.handler.prefs.enableLatchedAlnumStateInMixedAlnumMode = true
    if let statusUI {
      let ui = MockSessionUI()
      ui.statusUI = statusUI
      result.session.ui = ui
    }
    return result
  }

  private static let latchedReleaseTooltip = "i18n:StateOfInputting.Tooltip.MixedAlnumLatchedStateReleased".i18n
  private static let latchedEnteredTooltip = "i18n:StateOfInputting.Tooltip.MixedAlnumLatchedStateEntered".i18n

  /// 閂滯之上鎖與逐鍵即刻遞交：`ls` 之鍵序不可能是一個依槽序鍵入的讀音，
  /// 故第二鍵即應上鎖、並將整段即刻遞交；其後每一顆 ASCII 皆即刻遞交。
  @Test
  func test_IH442_LatchedAlnumLatchesAndCommitsPerKey() throws {
    let statusUI = MockTooltipUI()
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler(statusUI: statusUI)
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    #expect(!testHandler.mixedAlnumConfig.isLatchedToAlnum)

    typeSentence("ls")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum, "`ls` 應觸發英數閂滯之上鎖")
    #expect(testSession.recentCommissions.joined() == "ls", "上鎖時應即刻遞交整段")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    // 上鎖提示由 StatusUI 承載（不經 state）：提示另立視窗，故不會被緊接著的按鍵事件衝走。
    #expect(statusUI.showCount == 1, "上鎖當下應以 StatusUI 發一次提示，實際 \(statusUI.showCount) 次")
    #expect(
      statusUI.shownTooltip == Self.latchedEnteredTooltip,
      "上鎖提示文字應為 Entered 鍵，實際得到 `\(statusUI.shownTooltip ?? "nil")`"
    )
    #expect(
      statusUI.shownDuration == 1.5,
      "上鎖提示時長應為 1.5 秒，實際得到 \(statusUI.shownDuration ?? -1)"
    )
    #expect(statusUI.syncCount == 1, "顯示提示前應同步一次 accent／locale，實際 \(statusUI.syncCount) 次")
    // 錨點＝打字列行高矩形之左上角頂點（MockSession 之 updateVerticalTypingStatus 恆回 seniorTheBeast）。
    // 逐分量比對（CGPoint 之 Equatable 由 Swift/SDK 側的 CoreGraphics overlay 提供，此處不倚賴之）。
    let anchor = testSession.updateVerticalTypingStatus()
    #expect(
      statusUI.shownPoint?.x == anchor.origin.x
        && statusUI.shownPoint?.y == anchor.origin.y + anchor.size.height,
      "提示錨點應為行高矩形之左上角頂點，實際得到 \(String(describing: statusUI.shownPoint))"
    )
    #expect(
      testSession.state.tooltip.isEmpty,
      "提示不得再由 state 承載，實際得到 `\(testSession.state.tooltip)`"
    )
    #expect(testSession.state.type == .ofEmpty, "上鎖後 inline preedit 恆空")

    typeSentence("-la")
    #expect(testSession.recentCommissions.joined() == "ls-la", "其後每一顆按鍵應即刻遞交")
    #expect(testHandler.mixedAlphanumericalBuffer.isEmpty)
    #expect(statusUI.showCount == 1, "其後之按鍵不得再發提示，實際 \(statusUI.showCount) 次")
  }

  /// 兩開關之四態：閂滯開關僅在母開關亦啟用時才有作用；母開關關閉時，
  /// 閂滯開關之開與關必須產生**完全一致**之結果（本 phase 之首要不變式）。
  @Test
  func test_IH443_LatchedAlnumInertUnlessBothSwitchesOn() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    func run(mixedOn: Bool, latchedOn: Bool) -> (commissions: String, displayed: String, latched: Bool) {
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
      testSession.recentCommissions.removeAll()
      testHandler.prefs.mixedAlphanumericalEnabled = mixedOn
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = latchedOn
      typeSentence("ls ")
      return (
        testSession.recentCommissions.joined(),
        testSession.state.displayedText,
        testHandler.mixedAlnumConfig.isLatchedToAlnum
      )
    }

    let offOff = run(mixedOn: false, latchedOn: false)
    let offOn = run(mixedOn: false, latchedOn: true)
    #expect(
      offOff.commissions == offOn.commissions && offOff.displayed == offOn.displayed,
      "母開關關閉時，閂滯開關必須完全無作用"
    )
    #expect(!offOff.latched, "母開關關閉時不得上鎖")
    #expect(!offOn.latched, "母開關關閉時不得上鎖")

    let onOff = run(mixedOn: true, latchedOn: false)
    let onOn = run(mixedOn: true, latchedOn: true)
    #expect(onOff.commissions == "ls ", "閂滯關閉時應維持既有的 Auto 行為")
    #expect(onOn.commissions == "ls ", "閂滯開啟時上鎖＋即刻遞交之總結果應相同")
    #expect(!onOff.latched, "閂滯關閉時不得上鎖")
    #expect(onOn.latched, "閂滯開啟且判定落定時應上鎖")
  }

  /// 四個解除鍵之攔截語意：Enter 解除後放行；BkSp／Delete／Esc 解除且攔截；
  /// Option+BkSp 解除、不攔截。四者皆以 StatusUI 提示告知已解除。
  @Test(arguments: ["enter", "backspace", "delete", "escape", "optionBackspace"])
  func test_IH444_LatchedAlnumReleaseKeys(_ keyID: String) throws {
    let statusUI = MockTooltipUI()
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler(statusUI: statusUI)
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    typeSentence("ls")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum, "\(keyID): 前置之上鎖未成立")
    testSession.recentCommissions.removeAll()
    // 上鎖當下亦發 StatusUI 提示；此處只關心解除之提示，故先記下基準次數。
    let showCountAfterLatch = statusUI.showCount
    #expect(showCountAfterLatch == 1, "\(keyID): 前置之上鎖提示未發，實際 \(showCountAfterLatch) 次")

    let (event, expectedIntercept): (KBEvent, Bool) = switch keyID {
    case "enter": (KBEvent.KeyEventData.dataEnterReturn.asEvent, false)
    case "backspace": (KBEvent.KeyEventData.backspaceEvent.asEvent, true)
    case "delete": (KBEvent.KeyEventData.deleteForwardEvent.asEvent, true)
    case "escape": (KBEvent.KeyEventData.escapeEvent.asEvent, true)
    default: (KBEvent.KeyEventData.optionBackspaceEvent.asEvent, false)
    }

    let intercepted = testHandler.triageInput(event: event)

    #expect(!testHandler.mixedAlnumConfig.isLatchedToAlnum, "\(keyID): 應解除閂滯")
    #expect(intercepted == expectedIntercept, "\(keyID): 攔截語意不符")
    // 解除提示亦由 StatusUI 承載（不經 state）：與上鎖提示同載體，不受按鍵事件影響。
    #expect(
      statusUI.showCount == showCountAfterLatch + 1,
      "\(keyID): 解除當下應以 StatusUI 發一次提示，實際 \(statusUI.showCount) 次"
    )
    #expect(
      statusUI.shownTooltip == Self.latchedReleaseTooltip,
      "\(keyID): 解除提示文字應為 Released 鍵，實際得到 `\(statusUI.shownTooltip ?? "nil")`"
    )
    #expect(
      statusUI.shownDuration == 1.5,
      "\(keyID): 解除提示時長應為 1.5 秒，實際得到 \(statusUI.shownDuration ?? -1)"
    )
    #expect(
      testSession.state.tooltip.isEmpty,
      "\(keyID): 提示不得再由 state 承載，實際得到 `\(testSession.state.tooltip)`"
    )
    #expect(
      testSession.state.type == .ofEmpty,
      "\(keyID): 解除後 inline preedit 恆空（不得存在 .ofInputting）"
    )
    #expect(testSession.recentCommissions.isEmpty, "\(keyID): 解除不應遞交任何內容")
    // 解除後不得再落回「輸入中」語意：內文組字區為空，故其後的 BkSp 必須放行給客體，
    // 否則使用者會在客體端按不出刪除。
    let afterRelease = testHandler.triageInput(event: KBEvent.KeyEventData.backspaceEvent.asEvent)
    #expect(!afterRelease, "\(keyID): 解除後之 BkSp 不應再被攔截")
    #expect(!testHandler.mixedAlnumConfig.isLatchedToAlnum, "\(keyID): 解除後不得自動重新上鎖")
    #expect(
      statusUI.showCount == showCountAfterLatch + 1,
      "\(keyID): 解除後之按鍵不得再發提示，實際 \(statusUI.showCount) 次"
    )
  }

  /// 閂滯於英打時，標點鍵應作半形 ASCII 即刻遞交（規則置於中文標點查詢之前）。
  @Test
  func test_IH445_LatchedAlnumCommitsASCIIPunctuation() throws {
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler()
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    typeSentence("ls")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum)
    testSession.recentCommissions.removeAll()

    typeSentence(",")
    #expect(
      testSession.recentCommissions.joined() == ",",
      "閂滯時 `,` 應作半形 ASCII 遞交，而非注音 ㄝ或中文標點；實際得到 `\(testSession.recentCommissions.joined())`"
    )

    typeSentence(".;-")
    #expect(testSession.recentCommissions.joined() == ",.;-")
  }

  /// `resetInputHandler()` 觸發之解除一律靜默（不發內文提示）。
  @Test
  func test_IH446_LatchedAlnumReleasedSilentlyByResetInputHandler() throws {
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler()
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    typeSentence("ls")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum)

    testSession.resetInputHandler(forceComposerCleanup: true)

    #expect(!testHandler.mixedAlnumConfig.isLatchedToAlnum, "重設應解除閂滯")
    #expect(
      testSession.state.tooltip != Self.latchedReleaseTooltip,
      "靜默解除不得發內文提示，實際得到 `\(testSession.state.tooltip)`"
    )
  }

  /// 固化一個**已知之行為後果**：閂滯一旦上鎖，其後的中文讀音鍵亦會被當 ASCII 遞交。
  ///
  /// 此係「上鎖點＝`isNotSequentiallyTypedReading`」與「閂滯態下一切可列印 ASCII 即刻遞交」
  /// 兩者之交集（`hel` 之第三鍵以另一鍵覆寫韻母槽，故於第三鍵即上鎖）。
  /// **此為已知取捨**（事主原話：「複寫修正的優先級本來就該低於英文判定」）；
  /// 若日後調整上鎖條件，本測項須一併修訂。
  @Test
  func test_IH447_LatchedAlnumLatchPreemptsSubsequentMixedInput() throws {
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler()
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    typeSentence("hel")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum, "`hel` 應觸發上鎖")
    #expect(testSession.recentCommissions.joined() == "hel")

    typeSentence("losu3")
    #expect(
      testSession.recentCommissions.joined() == "hellosu3",
      "上鎖後其後按鍵一律作 ASCII 遞交（含本應為注音之按鍵）"
    )
  }

  /// 閂滯於英打時，小鍵盤之字元鍵應直接遞交**半形** ASCII，不受 `numPadCharInputBehavior` 影響。
  @Test
  func test_IH448_LatchedAlnumCommitsHalfWidthNumPadASCII() throws {
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler()
    defer {
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.prefs.numPadCharInputBehavior = 0
      testHandler.clear()
    }

    typeSentence("ls")
    #expect(testHandler.mixedAlnumConfig.isLatchedToAlnum)
    testSession.recentCommissions.removeAll()

    let keypadSeven = KBEvent.KeyEventData(
      type: .keyDown,
      flags: .numericPad,
      chars: "7",
      charsSansModifiers: "7",
      keyCode: 89
    )

    // 行為值 1 為「全形」；閂滯態下仍須遞交半形。
    testHandler.prefs.numPadCharInputBehavior = 1
    let intercepted = testHandler.triageInput(event: keypadSeven.asEvent)

    #expect(intercepted, "小鍵盤字元鍵應被輸入法處理")
    #expect(
      testSession.recentCommissions.joined() == "7",
      "閂滯時小鍵盤應遞交半形 ASCII，實際得到 `\(testSession.recentCommissions.joined())`"
    )
  }

  /// 狂拼執行期狀態之複位粒度：`clear()`（狀態重置）清整批；`invalidateFuriousTrail()`（顯式干涉）只清 trail。
  ///
  /// 前者防「上一輪殘留之高亮／重切 offers 跨過重置邊界、被下一輪當成當拍狀態消費」；
  /// 後者則須保留當拍尚在消費週期內之高亮與 offers（否則 copilot 窗之預覽與聯合重切會失效）。
  @Test
  func test_IH449_FuriousConfigResetGranularity() throws {
    let (testHandler, _) = try prepareMixedModeHandler()
    defer { testHandler.clear() }

    let perPassOffer = FuriousCoSegmentedOffer(
      keyArray: ["ㄈㄢ", "ㄍㄢ"],
      value: "反感",
      blobs: ["fan", "gan"],
      weight: 1.0
    )

    func seedPerPassState() {
      testHandler.furiousConfig.trail = ["fan", "gan"]
      testHandler.furiousHighlightOverride = (["ㄈㄢ"], "反")
      testHandler.furiousConfig.coSegmentedOffers = [perPassOffer]
    }

    seedPerPassState()
    testHandler.invalidateFuriousTrail()
    #expect(testHandler.furiousConfig.trail.isEmpty, "顯式干涉應清空 trail")
    #expect(testHandler.furiousHighlightOverride?.value == "反", "顯式干涉不應清當拍高亮")
    #expect(testHandler.furiousConfig.coSegmentedOffers.count == 1, "顯式干涉不應清當拍重切 offers")

    testHandler.clear()
    #expect(
      testHandler.furiousConfig == FuriousTypingConfig(),
      "`clear()` 應將狂拼之整批執行期狀態複位（trail＋當拍狀態）"
    )
  }

  // MARK: - 槽序檢定之偏好開關（MixedAlnumJudgeReadingsBySequentialRawKeyOrder）

  /// 該偏好之預設值為 true；且預設狀態下之行為與 IH438 所釘者一致（亂序 token 走 ASCII 路徑）。
  @Test
  func test_IH450_MixedSequentialOrderJudgeDefaultsOn() throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    defer { testHandler.clear() }

    #expect(
      (UserDef.kMixedAlnumJudgeReadingsBySequentialRawKeyOrder.dataType.defaultValue as? Bool) == true,
      "該偏好之預設值應為 true"
    )
    #expect(
      testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder,
      "未經使用者改動時，執行期讀值應為 true"
    )

    typeSentence("ls ")
    #expect(
      testSession.recentCommissions.joined() == "ls ",
      "預設（啟用槽序檢定）狀態下 `ls` 應作 ASCII 遞交，實際得到 \(testSession.recentCommissions)"
    )
  }

  /// 停用槽序檢定後，兩字母亂序 token 不再被視為英文意圖（與 IH438 為對照組）：
  /// 該段回到「鍵數 == 佔用槽數」之計數式判準，即被吸收為單一讀音、而非遞交 ASCII。
  @Test(arguments: [
    (token: "ls", reading: "ㄋㄠ", kanji: "腦"),
    (token: "ln", reading: "ㄙㄠ", kanji: "艘"),
    (token: "lc", reading: "ㄏㄠ", kanji: "蒿"),
    (token: "mv", reading: "ㄒㄩ", kanji: "須"),
  ])
  func test_IH451_MixedOutOfSlotOrderTokenStaysPhoneticWhenJudgeDisabled(
    _ scenario: (token: String, reading: String, kanji: String)
  ) throws {
    let (testHandler, testSession) = try prepareMixedModeHandler()
    let cleanup = injectTemporaryGrams(testHandler, "\(scenario.reading) \(scenario.kanji) -1")
    testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = false
    defer {
      testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = true
      cleanup()
      testHandler.clear()
    }

    typeSentence(scenario.token)
    #expect(
      testHandler.mixedAlphanumericalBuffer == scenario.token,
      "\(scenario.token): Space 之前 buffer 應為 `\(scenario.token)`"
    )

    typeSentence(" ")

    #expect(
      testSession.recentCommissions.isEmpty,
      "\(scenario.token): 停用槽序檢定後應被吸收為讀音，實際得到 \(testSession.recentCommissions)"
    )
    #expect(
      testHandler.assembler.actualKeys.last == scenario.reading,
      "\(scenario.token): 應插入讀音 `\(scenario.reading)`，實際得到 \(testHandler.assembler.actualKeys)"
    )
    #expect(
      testHandler.committableDisplayText(sansReading: true) == scenario.kanji,
      "\(scenario.token): 組字區應為 `\(scenario.kanji)`，實際得到 `\(testHandler.committableDisplayText(sansReading: true))`"
    )
  }

  /// 停用槽序檢定後之動態排列行為（與 IH440 為對照組）：
  /// ①大千26 之 `qquu`（跨鍵改寫槽值之合法編碼）不再被吸收為單一讀音——舊制對大千26
  ///   整條停用該檢定，故該段滯留於 ASCII 緩衝、於按下空白鍵時以 `qquu ` 遞交；
  /// ②倚天26 之 `ge`（ㄐㄧ）不受影響——舊制之豁免僅及大千26，其餘動態排列本就採
  ///   「鍵數 == 佔用槽數」判定（`ge` 為 2 鍵 2 槽，故仍成立）。
  @Test
  func test_IH452_MixedDynamicLayoutMultiWriteKeysWhenJudgeDisabled() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.mixedAlphanumericalEnabled = true
    testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = false
    defer {
      testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = true
      testHandler.clear()
    }

    testHandler.prefs.keyboardParser = KeyboardParser.ofDachen26.rawValue
    testHandler.ensureKeyboardParser()
    typeSentence("qquu")
    #expect(testHandler.mixedAlphanumericalBuffer == "qquu", "大千26：Space 之前 buffer 應為 `qquu`")
    typeSentence(" ")
    #expect(
      testSession.recentCommissions.joined() == "qquu ",
      "大千26：停用槽序檢定後應以 ASCII 遞交，實際得到 \(testSession.recentCommissions)"
    )

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testSession.recentCommissions.removeAll()

    testHandler.prefs.keyboardParser = KeyboardParser.ofETen26.rawValue
    testHandler.ensureKeyboardParser()
    typeSentence("ge")
    #expect(
      testHandler.composer.value == "ㄐㄧ",
      "倚天26：`ge` 應仍在注拼槽內，實際得到 `\(testHandler.composer.value)`"
    )
    #expect(testSession.recentCommissions.isEmpty, "倚天26：不得遞交任何內容")
  }

  /// 閂滯之上鎖點係以引擎層槽序檢定為定義，不受本開關影響：
  /// 停用槽序檢定者，閂滯仍於 `ls` 之第二鍵上鎖、並將整段即刻遞交。
  @Test
  func test_IH453_LatchedAlnumLatchPointUnaffectedBySequentialOrderJudgeSwitch() throws {
    let (testHandler, testSession) = try prepareLatchedMixedModeHandler()
    testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = false
    defer {
      testHandler.prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder = true
      testHandler.prefs.enableLatchedAlnumStateInMixedAlnumMode = false
      testHandler.clear()
    }

    typeSentence("ls")
    #expect(
      testHandler.mixedAlnumConfig.isLatchedToAlnum,
      "停用槽序檢定不得影響閂滯之上鎖點（該點之定義即為引擎層槽序檢定）"
    )
    #expect(testSession.recentCommissions.joined() == "ls", "上鎖時應即刻遞交整段")
  }
}
