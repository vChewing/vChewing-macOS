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

// 特殊輸入模式：碼點輸入、羅馬數字、符號表與單獨聲調。

// MARK: - IH.InputMode

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test("IH-InputMode-001 Code point input check")
  func test_IH_InputMode_001_CodePointInputCheck() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
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
        testSession.switchState(IMEState.ofAbortion())
      }
      PrefMgr.sharedSansDidSetOps.mostRecentInputMode = langMode.rawValue
      #expect(testHandler.currentTypingMethod == .vChewingFactory)
      #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
      #expect(testHandler.currentTypingMethod == .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeSentence(codePointHexStr)
      #expect(testSession.recentCommissions.last == "刃")
      vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }

  @Test("IH-InputMode-002 Roman numeral input check")
  func test_IH_InputMode_002_RomanNumeralInputCheck() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
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
      #expect(testHandler.currentTypingMethod == .vChewingFactory)
      // 開始輪替。
      var attempts = 0
      revolvingTypingMethod: while testHandler.currentTypingMethod != .romanNumerals {
        defer { attempts += 1 }
        #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
        if attempts > TypingMethod.allCases.count {
          break revolvingTypingMethod
        }
      }
      #expect(testHandler.currentTypingMethod == .romanNumerals)
    }

    vCTestLog("Testing roman numeral input: 1994")
    try resetToRomanNumeralTypingMethod()
    typeSentence("1994")
    #expect(testSession.recentCommissions.last == "MCMXCIV")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 另外測試一個數字。
    try resetToRomanNumeralTypingMethod()
    vCTestLog("Testing roman numeral input: 1042")
    typeSentence("1042")
    #expect(testSession.recentCommissions.last == "MXLII")
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字輸入測試。")
  }

  /// 測試羅馬數字模式下的空白鍵功能
  @Test("IH-InputMode-003 Roman numeral Space key handling")
  func test_IH_InputMode_003_RomanNumeralSpaceKeyHandling() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    // 建立空白鍵事件
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
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .codePoint)
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .haninKeyboardSymbol)
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    // 測試一：空白鍵在緩衝區為空時應觸發 ofAbortion
    vCTestLog("測試一：空白鍵在緩衝區為空時")
    var errorCallbackTriggered = false
    testHandler.errorCallback = { errorID in
      vCTestLog("錯誤回呼被觸發，ID 為：\(errorID)")
      errorCallbackTriggered = true
    }
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(errorCallbackTriggered, "緩衝區為空時應觸發錯誤回呼")
    // ofAbortion() 狀態在狀態機中自動轉換為 ofEmpty()
    #expect(testSession.state.type == .ofEmpty, "狀態應在 ofAbortion 轉換後變為 ofEmpty")

    // 測試二：空白鍵在緩衝區有內容時應遞交羅馬數字
    vCTestLog("測試二：空白鍵鍵入 '42' 應遞交 'XLII'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("42")
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(testSession.recentCommissions.last == "XLII", "鍵入 '42' 應遞交 'XLII'")
    #expect(testSession.state.type == .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試三：空白鍵用於三位數
    vCTestLog("測試三：空白鍵鍵入 '999' 應遞交 'CMXCIX'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("999")
    #expect(testHandler.triageInput(event: spaceKeyEvent))
    #expect(testSession.recentCommissions.last == "CMXCIX", "鍵入 '999' 應遞交 'CMXCIX'")
    #expect(testSession.state.type == .ofEmpty, "狀態應在成功遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    // 測試四：Enter 鍵仍應正常工作（既有功能）
    vCTestLog("測試四：Enter 鍵鍵入 '2023' 應遞交 'MMXXIII'")
    testSession.switchState(.ofAbortion())
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.triageInput(event: symbolMenuKeyEvent))
    #expect(testHandler.currentTypingMethod == .romanNumerals)

    typeSentence("2023")
    #expect(
      testSession.recentCommissions.last == "MMXXIII",
      "四位數輸入 '2023' 應自動遞交 'MMXXIII'"
    )
    #expect(testSession.state.type == .ofEmpty, "狀態應在自動遞交後變為 ofEmpty")
    #expect(
      testHandler.currentTypingMethod == .vChewingFactory,
      "遞交後應返回唯音預設的打字方法"
    )
    vCTestLog("-> Result: \(testSession.recentCommissions.last ?? "NULL")")

    vCTestLog("成功完成羅馬數字空白鍵測試。")
  }

  @Test("IH-InputMode-004 Symbol menu key table preview in composition buffer")
  func test_IH_InputMode_004_SymbolMenuKeyTablePreviewInCompositionBuffer() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    CandidateNode.load()
    let event4SymbolMenu = KBEvent.KeyEventData.symbolMenuKeyEventIntl.asEvent
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.triageInput(event: event4SymbolMenu))
    #expect(testSession.state.type == .ofSymbolTable)

    testSession.candidatePairHighlightChanged(at: 0)
    #expect(testSession.state.highlightedCandidateIndex == 0)
    #expect(testSession.state.displayedTextConverted == "　")
    #expect(testSession.state.displayTextSegments == ["　"])
    #expect(IMEStateParsed(testSession.state).attributedString.string == "　")

    testSession.candidatePairHighlightChanged(at: 1)
    #expect(testSession.state.highlightedCandidateIndex == 1)
    #expect(testSession.state.displayedTextConverted == "｀")
    #expect(testSession.state.displayTextSegments == ["｀"])
    #expect(IMEStateParsed(testSession.state).attributedString.string == "｀")

    testSession.candidatePairHighlightChanged(at: 2)
    #expect(testSession.state.highlightedCandidateIndex == 2)
    #expect(testSession.state.displayedTextConverted == "")
    #expect(testSession.state.displayTextSegments == [])
    #expect(
      IMEStateParsed(testSession.state).attributedString.string ==
        IMEStateParsed(testSession.state).attributedStringPlaceholder.string
    )
  }

  /// 切換至符號表狀態時，應以該節點名稱作為組字區的顯示內容。
  @Test("IH-InputMode-005 Symbol table init sets display segments")
  func test_IH_InputMode_005_SymbolTableInitSetsDisplaySegments() throws {
    guard let testSession else {
      Issue.record("testSession is nil.")
      return
    }
    CandidateNode.load()
    // 選一個沒有子元件的候選節點（葉節點 Candidate）。
    let root = CandidateNode.root
    var leafCandidate: CandidateNode?
    func findLeaf(_ node: CandidateNode) {
      if leafCandidate != nil { return }
      if node.members.isEmpty {
        leafCandidate = node
        return
      }
      for member in node.members { findLeaf(member) }
    }
    findLeaf(root)
    guard let leaf = leafCandidate else {
      Issue.record("No leaf candidate found.")
      return
    }
    testSession.switchState(.ofSymbolTable(node: leaf))
    #expect(testSession.state.type == .ofSymbolTable)
    #expect(!(testSession.state.node.name.isEmpty))
    #expect(testSession.state.data.displayTextSegments == [testSession.state.node.name])
    #expect(testSession.state.data.displayedText == testSession.state.node.name)
  }

  @Test("IH-InputMode-006 Intonation key behavior")
  func test_IH_InputMode_006_IntonationKeyBehavior() throws {
    /// IntonationKeyBehavior 分為 [0, 1, 2] 三個情況，這裡只測試前兩種情況：
    /// - 0: 嘗試對游標正後方的字音覆寫聲調，且重設其選字狀態。
    /// - 1: 僅在鍵入的聲調與游標正後方的字音不同時，嘗試覆寫。
    /// - 2: 始終在內文組字區內鍵入聲調符號。
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    let testKanjiData = """
    ㄒㄧㄢ 先 -1
    ㄒㄧㄢˊ 嫌 -1
    ㄒㄧㄢˊ 鹹 -2
    ㄒㄧㄢˇ 顯 -1
    ㄒㄧㄢˋ 線 -1
    """
    let extractedGrams = extractGrams(from: testKanjiData)
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
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空白字元是陰平聲調。
      #expect(testSession.state.displayedText == "嫌")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      #expect(testSession.state.displayedText == "鹹")
      typeSentence("6")
      #expect(testSession.state.displayedText == "嫌", "得復位")
      typeSentence("4")
      #expect(testSession.state.displayedText == "線")
    }
    // 測試 pref case 1。
    do {
      testHandler.clear()
      testHandler.prefs.specifyIntonationKeyBehavior = 1
      typeSentence("vu06") // 打「嫌」字的讀音：「ㄒㄧㄢˊ」，最後空白字元是陰平聲調。
      #expect(testSession.state.displayedText == "嫌")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataTab.asEvent))
      #expect(testSession.state.displayedText == "鹹")
      typeSentence("6")
      #expect(testSession.state.displayedText == "鹹ˊ", "不得復位")
      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent))
      typeSentence("4")
      #expect(testSession.state.displayedText == "線")
    }
  }

  /// 測試單獨輸入聲調後敲 Enter 鍵能正確遞交聲調符號。
  ///
  /// 當唯音輸入法處於「允許單獨輸入聲調」模式時，使用者若先敲聲調鍵（如 ˊ）
  /// 再敲 Enter，則應將該聲調符號直接遞交，如同工具提示所述「敲 Enter 以遞交」。
  @Test("IH-InputMode-007 Standalone intonation Enter commits tone mark")
  func test_IH_InputMode_007_StandaloneIntonationEnterCommitsToneMark() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    testHandler.prefs.acceptLeadingIntonations = true
    testHandler.prefs.specifyIntonationKeyBehavior = 0
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    clearTestPOM()
    defer { testHandler.clear() }

    // 先重置狀態。
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 模擬敲聲調鍵「6」（Dachen 佈局下映射到「ˊ」）。
    // 此時 composer 僅有聲調、無讀音，應觸發 standalone intonation 工具提示狀態。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData(chars: "6").asEvent))
    #expect(testHandler.composer.hasIntonation(withNothingElse: true))
    #expect(!testHandler.tooltipForStandaloneIntonationMark.isEmpty)

    // 敲 Enter：應將聲調符號「ˊ」直接遞交。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "ˊ")
  }
}
