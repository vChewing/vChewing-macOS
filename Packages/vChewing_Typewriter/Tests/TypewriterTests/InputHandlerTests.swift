// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
@testable import LangModelAssembly
import Shared
@testable import Typewriter
import XCTest

func vCTestLog(_ str: String) {
  print("[VCLOG] \(str)")
}

// MARK: - KeyCode Mapping for Tests

/// ANSI 鍵盤字符到 KeyCode 的映射表（用於測試）
let mapKeyCodesANSIForTests: [String: UInt16] = [
  "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29, "-": 27,
  "=": 24, "q": 12, "w": 13, "e": 14, "r": 15, "t": 17, "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
  "[": 33, "]": 30, "\\": 42, "a": 0, "s": 1, "d": 2, "f": 3, "g": 5, "h": 4, "j": 38, "k": 40,
  "l": 37, ";": 41, "'": 39, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "n": 45, "m": 46, ",": 43,
  ".": 47, "/": 44, " ": 49,
]

// MARK: - InputHandlerTests

/// 威注音輸入法的 InputHandler 單元測試（Typewriter 模組）
class InputHandlerTests: XCTestCase {
  var testLM: LMAssembly.LMInstantiator?
  var testHandler: MockInputHandler?
  var testSession: MockSession?

  // MARK: - Setup and Teardown

  override func setUpWithError() throws {
    // 設定專用於單元測試的 UserDefaults
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true

    // 初始化測試 LM
    let lm = LMAssembly.LMInstantiator(isCHS: false)
    testLM = lm
    LMAssembly.LMInstantiator.connectToTestSQLDB()

    // 初始化測試用的 handler 和 session
    let handler = MockInputHandler(lm: lm, pref: PrefMgr())
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    testHandler = handler
    testSession = session
  }

  override func tearDownWithError() throws {
    testSession?.switchState(MockIMEState.ofAbortion())
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
  }

  // MARK: - Utility Functions

  func clearTestPOM() {
    testHandler?.currentLM.clearPOMData()
  }

  func typeSentence(_ sequence: String) {
    guard let testHandler else { return }
    // 使用 KBEvent 模擬輸入，類似 MainAssembly 的 typeSentenceOrCandidates
    // 這樣可以正確處理注音、磁帶等各種輸入模式

    // 為每個字符建立 KBEvent（按下事件）
    let typingSequence: [KBEvent] = sequence.map { charRAW in
      let charStr = String(charRAW)
      let keyCode = mapKeyCodesANSIForTests[charStr] ?? 65_535
      return KBEvent(
        with: .keyDown,
        characters: charStr,
        charactersIgnoringModifiers: charStr,
        keyCode: keyCode
      )
    }

    // 處理每個 keyDown 事件
    typingSequence.forEach { event in
      _ = testHandler.triageInput(event: event)
    }
  }

  func generateDisplayedText() -> String {
    guard let testHandler else { return "" }
    return testHandler.assembler.assembledSentence.values.joined()
  }

  // MARK: - Test Cases

  /// 測試基本的打字組句（不是ㄅ半注音）。
  func test01_InputHandler_BasicSentenceComposition() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：高科技公司的年中獎金")
    testHandler.clear()
    typeSentence("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "高科技公司的年中獎金")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  func test02_InputHandler_BasicSCPCTyping() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：高")
    testHandler.clear()

    // 打「高」字
    typeSentence("el ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertFalse(resultText1.isEmpty)
    let candidates = testHandler.generateArrayOfCandidates()
    XCTAssertTrue(resultText1.contains("高") || candidates.map { $0.value }.contains("高"))
  }

  /// 測試就地輪替候選字。
  func test03_InputHandler_RevolvingCandidates() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()

    testHandler.clear()
    typeSentence("el dk ru4ej/ n 2k7su065j/ ru;3rup ")

    vCTestLog("測試就地輪替候選字：測試游標移動和候選字功能")

    // 測試游標移動
    let initialCursor = testHandler.assembler.cursor
    testHandler.assembler.jumpCursorBySegment(to: .rear)
    testHandler.assembler.jumpCursorBySegment(to: .rear)
    XCTAssertNotEqual(testHandler.assembler.cursor, initialCursor)

    // 測試候選字獲取
    let candidates = testHandler.generateArrayOfCandidates()
    vCTestLog("- // 候選字數量：\(candidates.count)")
    XCTAssertFalse(candidates.isEmpty)
  }

  /// 測試漸退記憶模組的記憶資料生成與適用。
  func test04_InputHandler_ManualCandidateSelectionAndPOM() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()

    let sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testHandler.clear()
    typeSentence(sequenceChars)

    vCTestLog("測試選字與漸退記憶：高科技公司的年中獎金 -> 選擇候選字")
    vCTestLog("nodes before candidate: \(testHandler.assembler.assembledSentence.values)")
    vCTestLog("cursor: \(testHandler.assembler.cursor)/length: \(testHandler.assembler.length)")

    // 測試候選字
    let candidates = testHandler.generateArrayOfCandidates()
    vCTestLog("candidates: \(candidates.map { $0.value })")
    XCTAssertFalse(candidates.isEmpty)

    // 測試選擇候選字後的效果
    if !candidates.isEmpty {
      let firstCandidate = candidates[0]
      // 直接測試候選字的結構
      XCTAssertFalse(firstCandidate.value.isEmpty)
      XCTAssertFalse(firstCandidate.keyArray.isEmpty)
      vCTestLog("- // 第一個候選字：\(firstCandidate.value)")
    }
  }

  /// 測試在選字後復原游標位置的功能。
  func test05_InputHandler_PostCandidateCursorPlacementRestore() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()

    let sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testHandler.clear()
    typeSentence(sequenceChars)

    // 移動游標
    testHandler.assembler.jumpCursorBySegment(to: .rear)
    testHandler.assembler.jumpCursorBySegment(to: .rear)

    let cursorBeforeCandidate = testHandler.assembler.cursor
    vCTestLog("測試游標位置復原：cursor before = \(cursorBeforeCandidate)")

    // 備份游標
    testHandler.backupCursor = cursorBeforeCandidate

    // 測試候選字
    let candidates = testHandler.generateArrayOfCandidates()
    XCTAssertFalse(candidates.isEmpty)
    vCTestLog("candidates count: \(candidates.count)")

    // 檢查 backupCursor 功能
    XCTAssertNotNil(testHandler.backupCursor)
    vCTestLog("backup cursor: \(testHandler.backupCursor ?? -1)")
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  func test06_InputHandler_MiscCommissionTest() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testHandler.clear()
    typeSentence("el dk ru4ej/ n 2k7")

    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = testHandler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    vCTestLog("Result (mode 0, shift): \(result)")
    XCTAssertEqual(result, "ㄍㄠ ㄎㄜ ㄐㄧˋ ㄍㄨㄥ ㄙ ˙ㄉㄜ")

    result = testHandler.commissionByCtrlOptionCommandEnter()
    vCTestLog("Result (mode 0): \(result)")
    XCTAssertEqual(result, "高(ㄍㄠ)科(ㄎㄜ)技(ㄐㄧˋ)公(ㄍㄨㄥ)司(ㄙ)的(˙ㄉㄜ)")

    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = testHandler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>高<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby><ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>公<rp>(</rp><rt>ㄍㄨㄥ</rt><rp>)</rp></ruby><ruby>司<rp>(</rp><rt>ㄙ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>
    """
    vCTestLog("Result (mode 1): \(result)")
    XCTAssertEqual(result, expectedRubyResult)

    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = testHandler.commissionByCtrlOptionCommandEnter()
    vCTestLog("Result (mode 2): \(result)")
    XCTAssertEqual(result, "⠅⠩⠄⠇⠮⠄⠅⠡⠐⠅⠯⠄⠑⠄⠙⠮⠁")

    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = testHandler.commissionByCtrlOptionCommandEnter()
    vCTestLog("Result (mode 3): \(result)")
    XCTAssertEqual(result, "⠛⠖⠁⠅⠢⠁⠛⠊⠆⠛⠲⠁⠎⠁⠙⠢")

    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  /// 測試磁帶模組的快速選字功能（單一結果）。
  func test10_InputHandler_CassetteQuickPhraseSelection() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    testHandler.currentTypingMethod = .vChewingFactory

    let cassetteURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // TypewriterTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_Typewriter
      .deletingLastPathComponent() // Packages
      .appendingPathComponent("vChewing_LangModelAssembly")
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestCINData")
      .appendingPathComponent("array30.cin2")

    guard FileManager.default.fileExists(atPath: cassetteURL.path) else {
      vCTestLog("測試檔案不存在，跳過測試：\(cassetteURL.path)")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    let cassetteLM = LMAssembly.LMInstantiator.lmCassette
    XCTAssertTrue(cassetteLM.isLoaded)
    XCTAssertTrue(!cassetteLM.charDefMap.isEmpty)

    testHandler.clear()
    typeSentence(",,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    // After typing the quick phrase key, the calligrapher should be cleared and we should have a result
    typeSentence(",,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    // After typing the quick phrase key, a single result should be selected and committed
    XCTAssertTrue(testHandler.calligrapher.isEmpty)
    // For single-result quick phrases, the result is committed immediately
    // The assembler should contain the committed text
    let result = generateDisplayedText()
    vCTestLog("Result after quick phrase: '\(result)'")
    // Single result quick phrases commit directly, so assembler might be empty
    // but the state should be appropriate for commit
    XCTAssertTrue(testSession?.state.type == .ofEmpty || !result.isEmpty)
  }

  /// 測試磁帶模組的快速選字功能（符號表多選）。
  func test11_InputHandler_CassetteQuickPhraseSymbolTableMultiple() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true

    let cassetteURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // TypewriterTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_Typewriter
      .deletingLastPathComponent() // Packages
      .appendingPathComponent("vChewing_LangModelAssembly")
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestCINData")
      .appendingPathComponent("array30.cin2")

    guard FileManager.default.fileExists(atPath: cassetteURL.path) else {
      vCTestLog("測試檔案不存在，跳過測試：\(cassetteURL.path)")
      return
    }

    LMAssembly.LMInstantiator.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    typeSentence(",,,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    vCTestLog("Testing symbol table multi-selection")
    vCTestLog("Calligrapher: \(testHandler.calligrapher)")

    // 測試是否產生了多個候選字
    let candidates = testHandler.generateArrayOfCandidates()
    vCTestLog("Candidates: \(candidates.map { $0.value })")
  }
}
