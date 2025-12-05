// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez
import MegrezTestComponents
import Shared
import XCTest

@testable import LangModelAssembly
@testable import Typewriter

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

// MARK: - 測試案例 Vol 1 (Basic Functions)

extension InputHandlerTests {
  /// 測試基本的打字組句（不是ㄅ半注音）。
  func test_IH101_BasicSentenceComposition() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳，但這裡暫時先期待失敗結果「優跌能留意旅方」")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("u. 2u,6s/6xu.6u4xm3z; ")
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertEqual(resultText1, "優跌能留意旅方")
    XCTAssertTrue(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    XCTAssertEqual(testSession.recentCommissions.joined(), "優跌能留意旅方")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  ///
  /// 注意：Typewriter Tests 並無測試選字窗行為的條件。
  /// SCPC 打字的行為處理過程高度強調選字窗的參與，所以此處僅測試打一個字。
  /// 完整測試需在 MainAssembly 測試進行。
  func test_IH102_BasicSCPCTyping() throws {
    guard let testHandler else {
      XCTFail("testHandler is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試逐字選字：優")
    testHandler.clear()
    typeSentence("u. ") // 打「優」字的讀音：「ㄧㄡ」，最後空格是陰平聲調。
    let resultText1 = generateDisplayedText()
    vCTestLog("- // 組字結果：\(resultText1)")
    XCTAssertFalse(resultText1.isEmpty)
    let candidates = testHandler.generateArrayOfCandidates()
    XCTAssertTrue(resultText1.contains("優") || candidates.map { $0.value }.contains("優"))
    // 測試到此為止，於 MainAssembly 的同名測試繼續。
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  func test_IH103_MiscCommissionTest() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("dk ru4204el ")
    guard let handler = testSession.inputHandler else {
      XCTAssertThrowsError("testSession.handler is nil.")
      return
    }
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    XCTAssertEqual(result, "ㄎㄜ ㄐㄧˋ ㄉㄢˋ ㄍㄠ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    XCTAssertEqual(result, "科(ㄎㄜ)技(ㄐㄧˋ)蛋(ㄉㄢˋ)糕(ㄍㄠ)")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>蛋<rp>(</rp><rt>ㄉㄢˋ</rt><rp>)</rp></ruby><ruby>糕<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby>
    """
    XCTAssertEqual(result, expectedRubyResult)
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠇⠮⠄⠅⠡⠐⠙⠧⠐⠅⠩⠄")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠅⠢⠁⠛⠊⠆⠙⠧⠆⠛⠖⠁")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  /// 測試磁帶模組的快速選字功能（單一結果）。
  func test_IH104_CassetteQuickPhraseSelection() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    testHandler.currentTypingMethod = .vChewingFactory

    let cassetteURL = cassetteURL4Array30CIN2

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

    // 打完 QuickPhrase 確認鍵之後，組筆區的內容應該會被清空、且此時應該有結果遞交出去。
    let currentState = testSession.state
    XCTAssertTrue(
      currentState.type == .ofEmpty || currentState.type == .ofSymbolTable,
      "Quick phrase with single result should either commit directly or open a symbol table, got \(currentState.type)."
    )
    // ↑MockSession 會在遞交結果時回復為 .ofEmpty，因此此處允許 .ofEmpty。
    XCTAssertTrue(testHandler.calligrapher.isEmpty)
    // 只有單筆結果時，得立刻遞交出去。組筆區應該是有結果的。
    let result = generateDisplayedText()
    vCTestLog("Result after quick phrase: '\(testSession.recentCommissions.last ?? "NULL")'")
    XCTAssertEqual(testSession.recentCommissions.last, "米糕")
    // 單一結果的快速片語會立即遞交，因此組字器可能維持為空；此時仍需檢查狀態是否合理
    XCTAssertTrue(testSession.state.type == .ofEmpty || !result.isEmpty)
  }

  /// 測試磁帶模組的快速選字功能（符號表多選）。
  func test_IH105_CassetteQuickPhraseSymbolTableMultiple() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LMAssembly.LMInstantiator.asyncLoadingUserData
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    defer { LMAssembly.LMInstantiator.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true

    let cassetteURL = cassetteURL4Array30CIN2

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

    XCTAssertEqual(testSession.state.type, .ofSymbolTable)
    XCTAssertEqual(testSession.state.node.name, ",,,,")
    XCTAssertEqual(testHandler.calligrapher, ",,,,")

    // 測試是否產生了多個候選字
    let symbolCandidates = testSession.state.node.members.map { $0.name }
    XCTAssertEqual(symbolCandidates, ["炎炎", "迷迷糊糊", "熒熒"])
    // 此時應該還沒有 Commit 才對，因為這時的狀態是選字窗顯示出來了。
    XCTAssertEqual(testSession.recentCommissions.last, nil)
    let stateCandidates = testSession.state.data.candidates.map { $0.value }
    XCTAssertEqual(stateCandidates, symbolCandidates)
    vCTestLog("Candidates: \(symbolCandidates)")
    // Typewriter 測試不會去測試選字窗的行為，這類行為的測試由 MainAssembly 測試負責。
    testSession.candidatePairSelectionConfirmed(at: 1)
    XCTAssertEqual(testSession.recentCommissions.last, "迷迷糊糊")
  }

  func test_IH106_CodePointInputCheck() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    let testCodes: [(Shared.InputMode, String)] = [
      (.imeModeCHS, "C8D0"),
      (.imeModeCHT, "A462"),
    ]

    // 模擬 `Opt+~` 熱鍵組合觸發碼點模式。
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )
    testSession.switchState(.ofAbortion())

    for (langMode, codePointHexStr) in testCodes {
      defer {
        // 切換至 Abortion 狀態會自動清理 Handler，此時會連帶重設 typingMethod。
        testSession.switchState(MockIMEState.ofAbortion())
      }
      PrefMgr().mostRecentInputMode = langMode.rawValue
      XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory)
      XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
      XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeSentence(codePointHexStr)
      XCTAssertEqual(testSession.recentCommissions.last, "刃")
      vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }

  func test_IH107_RomanNumeralInputCheck() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }

    // 模擬 `Opt+~` 熱鍵組合觸發羅馬數字模式。
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )

    func resetToRomanNumeralTypingMethod() throws {
      // 初始打字模式（TypingMethod）是唯音原廠模式。
      testSession.switchState(.ofAbortion())
      XCTAssertEqual(testHandler.currentTypingMethod, .vChewingFactory)
      // 開始輪替。
      var attempts = 0
      revolvingTypingMethod: while testHandler.currentTypingMethod != .romanNumerals {
        defer { attempts += 1 }
        XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
        if attempts > TypingMethod.allCases.count {
          break revolvingTypingMethod
        }
      }
      XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)
    }

    vCTestLog("Testing roman numeral input: 1994")
    try resetToRomanNumeralTypingMethod()
    typeSentence("1994")
    XCTAssertEqual(testSession.recentCommissions.last, "MCMXCIV")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 另外測試一個數字。
    try resetToRomanNumeralTypingMethod()
    vCTestLog("Testing roman numeral input: 1042")
    typeSentence("1042")
    XCTAssertEqual(testSession.recentCommissions.last, "MXLII")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字輸入測試。")
  }

  /// 測試羅馬數字模式下的空格鍵功能
  func test_IH108_RomanNumeralSpaceKeyHandling() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    // 建立空格鍵事件
    let spaceKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: [],
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: " ",
      charactersIgnoringModifiers: " ",
      isARepeat: false,
      keyCode: KeyCode.kSpace.rawValue
    )

    // 建立符號選單按鍵事件（Option + `）
    let symbolMenuKeyEvent = KBEvent(
      with: .keyDown,
      modifierFlags: .option,
      timestamp: Date().timeIntervalSince1970,
      windowNumber: nil,
      characters: "`",
      charactersIgnoringModifiers: "`",
      isARepeat: false,
      keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
    )

    testSession.switchState(.ofAbortion())

    // 進入羅馬數字模式
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .codePoint)
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .haninKeyboardSymbol)
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)

    // 測試一：空格鍵在緩衝區為空時應觸發 ofAbortion
    vCTestLog("測試一：空格鍵在緩衝區為空時")
    var errorCallbackTriggered = false
    testHandler.errorCallback = { errorID in
      vCTestLog("錯誤回呼被觸發，ID 為：\(errorID)")
      errorCallbackTriggered = true
    }
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertTrue(errorCallbackTriggered, "緩衝區為空時應觸發錯誤回呼")
    // ofAbortion() 狀態在狀態機中自動轉換為 ofEmpty()
    XCTAssertEqual(testSession.state.type, .ofEmpty, "狀態應在 ofAbortion 轉換後變為 ofEmpty")

    // 測試二：空格鍵在緩衝區有內容時應遞交羅馬數字
    vCTestLog("測試二：空格鍵鍵入 '42' 應遞交 'XLII'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)

    typeSentence("42")
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertEqual(testSession.recentCommissions.last, "XLII", "鍵入 '42' 應遞交 'XLII'")
    XCTAssertEqual(testSession.state.type, .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    XCTAssertEqual(
      testHandler.currentTypingMethod,
      .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試三：空格鍵用於三位數
    vCTestLog("測試三：空格鍵鍵入 '999' 應遞交 'CMXCIX'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)

    typeSentence("999")
    XCTAssertTrue(testHandler.triageInput(event: spaceKeyEvent))
    XCTAssertEqual(testSession.recentCommissions.last, "CMXCIX", "鍵入 '999' 應遞交 'CMXCIX'")
    XCTAssertEqual(testSession.state.type, .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    XCTAssertEqual(
      testHandler.currentTypingMethod,
      .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試四：Enter 鍵仍應正常工作（既有功能）
    vCTestLog("測試四：Enter 鍵鍵入 '2023' 應遞交 'MMXXIII'")
    testSession.switchState(.ofAbortion())
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertTrue(testHandler.triageInput(event: symbolMenuKeyEvent))
    XCTAssertEqual(testHandler.currentTypingMethod, .romanNumerals)

    typeSentence("2023")
    XCTAssertEqual(
      testSession.recentCommissions.last,
      "MMXXIII",
      "四位數輸入 '2023' 應自動遞交 'MMXXIII'"
    )
    XCTAssertEqual(testSession.state.type, .ofEmpty, "狀態應在自動遞交後變為 ofEmpty")
    XCTAssertEqual(
      testHandler.currentTypingMethod,
      .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字空格鍵測試。")
  }

  func test_IH109_SymbolMenuKeyTablePreviewInCompositionBuffer() throws {
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    CandidateNode.load()
    let event4SymbolMenu = KBEvent.KeyEventData.symbolMenuKeyEventIntl.asEvent
    testSession.resetInputHandler(forceComposerCleanup: true)
    XCTAssert(testHandler.triageInput(event: event4SymbolMenu))
    XCTAssertEqual(testSession.state.type, .ofSymbolTable)

    testSession.candidatePairHighlightChanged(at: 0)
    XCTAssertEqual(testSession.state.highlightedCandidateIndex, 0)
    XCTAssertEqual(testSession.state.displayedTextConverted, "　")

    testSession.candidatePairHighlightChanged(at: 1)
    XCTAssertEqual(testSession.state.highlightedCandidateIndex, 1)
    XCTAssertEqual(testSession.state.displayedTextConverted, "｀")

    testSession.candidatePairHighlightChanged(at: 2)
    XCTAssertEqual(testSession.state.highlightedCandidateIndex, 2)
    XCTAssertEqual(testSession.state.displayedTextConverted, "")
  }

  func test_IH110_IntonationKeyBehavior() throws {
    /// IntonationKeyBehavior 分為 [0, 1, 2] 三個情況，這裡只測試前兩種情況：
    /// - 0: 嘗試對游標正後方的字音覆寫聲調，且重設其選字狀態。
    /// - 1: 僅在鍵入的聲調與游標正後方的字音不同時，嘗試覆寫。
    /// - 2: 始終在內文組字區內鍵入聲調符號。
    guard let testHandler, let testSession else {
      XCTFail("testHandler and testSession at least one of them is nil.")
      return
    }
    let testKanjiData = """
    ㄒㄧㄢ 先 -1
    ㄒㄧㄢˊ 嫌 -1
    ㄒㄧㄢˊ 鹹 -2
    ㄒㄧㄢˇ 顯 -1
    ㄒㄧㄢˋ 線 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
    print(extractedGrams)
    extractedGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    clearTestPOM()
    // 測試 pref case 0。
    do {
      testHandler.clear()
      testHandler.prefs.specifyIntonationKeyBehavior = 0
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空格是陰平聲調。
      XCTAssertEqual(testSession.state.displayedText, "嫌")
      XCTAssert(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      XCTAssertEqual(testSession.state.displayedText, "鹹")
      typeSentence("6")
      XCTAssertEqual(testSession.state.displayedText, "嫌", "得復位")
      typeSentence("4")
      XCTAssertEqual(testSession.state.displayedText, "線")
    }
    // 測試 pref case 1。
    do {
      testHandler.clear()
      testHandler.prefs.specifyIntonationKeyBehavior = 1
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空格是陰平聲調。
      XCTAssertEqual(testSession.state.displayedText, "嫌")
      XCTAssert(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      XCTAssertEqual(testSession.state.displayedText, "鹹")
      typeSentence("6")
      XCTAssertEqual(testSession.state.displayedText, "鹹ˊ", "不得復位")
      XCTAssert(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
      typeSentence("4")
      XCTAssertEqual(testSession.state.displayedText, "線")
    }
  }
}
