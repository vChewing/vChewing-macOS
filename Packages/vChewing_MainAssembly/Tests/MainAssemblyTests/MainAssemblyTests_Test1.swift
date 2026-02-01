// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import LMAssemblyMaterials4Tests
import Megrez
import MegrezTestComponents
import OSFrameworkImpl
import Testing

@testable import LangModelAssembly
@testable import MainAssembly
@testable import Typewriter

// 本文的單元測試用例從 001 與 101 起算。

extension MainAssemblyTests {
  @Test
  func test001_ClientTest_BundleIdentifier() throws {
    guard let identifier = testSession.client()?.bundleIdentifier() else {
      fatalError("致命錯誤：客體唯一標幟碼無效。")
    }
    vCTestLog("測試客體唯一標幟碼：\(identifier)")
  }

  @Test
  func test002_ClientTest_TextInsertion() throws {
    testClient.clear()
    let testString = UUID().uuidString
    testSession.client().insertText(testString, replacementRange: .notFound)
    #expect(testClient.attributedString.string == testString)
    testClient.clear()
  }

  @Test
  func test011_LMMgr_UnitTestSandboxIO() throws {
    let directories = [
      (label: "default", url: LMMgr.unitTestDataURL(isDefaultFolder: true)),
      (label: "custom", url: LMMgr.unitTestDataURL(isDefaultFolder: false)),
    ]
    let fileManager = FileManager.default

    for (label, folderURL) in directories {
      let path = folderURL.path
      var isDirectory = ObjCBool(false)
      #expect(
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
        "Missing \(label) folder at: \(path)"
      )
      #expect(isDirectory.boolValue, "Path is not directory for \(label) folder at: \(path)")
      #expect(
        fileManager.isReadableFile(atPath: path),
        "Unreadable \(label) folder at: \(path)"
      )
      #expect(
        fileManager.isWritableFile(atPath: path),
        "Unwritable \(label) folder at: \(path)"
      )

      let payload = "io-check-\(UUID().uuidString)"
      let fileURL = folderURL.appendingPathComponent("io-check-\(UUID().uuidString).txt")

      try Data(payload.utf8).write(to: fileURL, options: [.atomic])
      let readBack = try String(contentsOf: fileURL, encoding: .utf8)
      #expect(readBack == payload, "Mismatched content for \(label) folder at: \(path)")
      try fileManager.removeItem(at: fileURL)
    }
  }

  // MARK: - Input Handler Tests.

  /// 測試基本的打字組句（不是ㄅ半注音）。
  @Test
  func test101_InputHandler_BasicSentenceComposition() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳，但這裡暫時先期待失敗結果「優跌能留意旅方」")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("u. 2u,6s/6xu.6u4xm3z; ")
    let resultText1 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(resultText1 == "優跌能留意旅方")
    guard let crlfEvent = dataEnterReturn.asEvent else { return }
    #expect(testHandler.triageInput(event: crlfEvent))
    #expect(testClient.toString() == "優跌能留意旅方")
  }

  /// 測試基本的逐字選字（ㄅ半注音）。
  @Test
  func test102_InputHandler_BasicSCPCTyping() throws {
    // 該測試已針對倚天中文DOS鍵盤排序更新過內容。
    testHandler.prefs.useSCPCTypingMode = true
    clearTestPOM()
    vCTestLog("測試組句：幽蝶能留一縷芳")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("u. 3")
    typeSentenceOrCandidates("2u,62")
    typeSentenceOrCandidates("s/6")
    typeSentenceOrCandidates("xu.63")
    typeSentenceOrCandidates("u4")
    press([dataArrowDown, dataArrowDown, dataArrowDown])
    typeSentenceOrCandidates("3")
    typeSentenceOrCandidates("xm3")
    press([dataArrowDown])
    typeSentenceOrCandidates("1")
    typeSentenceOrCandidates("z; ")
    typeSentenceOrCandidates("2")
    let resultText1 = testClient.toString()
    vCTestLog("- // 組字結果：\(resultText1)")
    #expect(resultText1 == "幽蝶能留一縷芳")
    testClient.clear()
  }

  /// 測試就地輪替候選字。
  @Test
  func test103_InputHandler_RevolvingCandidates() throws {
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    clearTestPOM()

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("u. 2u,6s/6xu.6u4xm3z; ")

    // Testing Inline Candidate Revolver.

    vCTestLog("測試就地輪替候選字：優跌能留意旅方 -> 幽蝶能留一縷芳")
    let eventDataChain: [NSEvent.KeyEventData] = [
      dataArrowHome, dataArrowRight, dataTab, dataTab,
      dataArrowRight, dataTab, dataArrowRight, dataArrowRight,
      dataArrowRight, dataArrowRight, dataTab, dataArrowRight,
      dataTab, dataTab, dataTab,
    ]
    press(eventDataChain)
    let resultText2 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText2)")
    #expect(resultText2 == "幽蝶能留一縷芳")
  }

  /// 測試藉由選字窗選字、且同時測試漸退記憶模組在此情況下的記憶資料生成與適用情況。
  /// - Remark: 這裡順便測試一下「在選字窗選字後自動推進游標」這個有被預設啟用的功能。
  @Test
  func test104_InputHandler_ManualCandidateSelectionAndPOM() throws {
    testHandler.prefs.enforceETenDOSCandidateSequence = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 1
    clearTestPOM()

    var sequenceChars = "u. 2u,6s/6xu.6u4xm3z; "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates(sequenceChars)

    // Testing Manual Candidate Selection, POM Observation, and Post-Candidate-Selection Cursor Jumping.

    vCTestLog("測試選字窗選字：優跌能留意旅方 -> 幽蝶能留一縷芳")
    vCTestLog("Pref=1 nodes prior to candidate selection: \(testHandler.assembler.assembledSentence.values)")
    vCTestLog(
      "Pref=1 cursor prior to candidate selection: \(testHandler.assembler.cursor)/length: \(testHandler.assembler.length)"
    )
    vCTestLog("Pref=1 candidates: \(testSession.state.candidates.map { $0.value })")
    press([dataArrowLeft, dataArrowDown])
    testSession.candidatePairSelectionConfirmed(at: 0) // 「一縷」
    // 此時游標應該有往前推進一格。
    #expect(testHandler.assembler.cursor == 7)
    press([dataArrowDown])
    testSession.candidatePairSelectionConfirmed(at: 3) // 「芳」
    vCTestLog("- // 組字結果：\(testSession.state.displayedText)")
    #expect(testSession.state.displayedText == "優跌能留一縷芳")
    #expect(testHandler.assembler.cursor == 7)

    // 把頭兩個節點也做選字。
    #expect(testSession.state.type == .ofInputting)
    press([dataArrowHome, dataArrowRight])
    #expect(testHandler.assembler.cursor == 1)
    press([dataArrowDown])
    testSession.candidatePairSelectionConfirmed(at: 2) // 「幽」
    #expect(testHandler.assembler.cursor == 2)
    #expect(testSession.state.displayedText == "幽跌能留一縷芳")
    testSession.switchState(testHandler.generateStateOfCandidates())
    testSession.candidatePairSelectionConfirmed(at: 1) // 「蝶」
    #expect(testSession.state.displayedText == "幽蝶能留一縷芳")
    #expect(testHandler.assembler.cursor == 4)

    // Continuing POM Tests (in the Current Context).

    vCTestLog("測試漸退記憶的適用範圍：此時已經生成的「芳」的記憶應僅對下述給定上下文情形生效。")
    vCTestLog("- 該給定上下文情形為「(ㄌㄧㄡˊ,留)&(ㄧˋ-ㄌㄩˇ,一縷)」且頭部讀音為「ㄈㄤ」。")
    vCTestLog("- 清空組字區，重新打剛才那句話來測試。")
    testSession.switchState(.ofAbortion())
    typeSentenceOrCandidates(sequenceChars)
    let resultText5 = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText5)")
    #expect(resultText5 == "幽蝶能留一縷芳")
    vCTestLog("- 已成功證實「年終」的記憶對該給定上下文情形生效。")

    vCTestLog("- 清空組字區，重新打另一句話來測試。")
    testSession.switchState(.ofAbortion())

    sequenceChars = "u. 2u,6s/6xu.6z; "
    typeSentenceOrCandidates(sequenceChars)
    vCTestLog("- // 組字結果：\(testSession.state.displayedText)")
    #expect(testSession.state.displayedText == "幽蝶能留方")
    #expect(testSession.state.displayedText != "幽蝶能留芳")
    vCTestLog("- 已成功證實「芳」的記憶不會對除了給定上下文以外的情形生效。")
  }

  /// 測試在選字後復原游標位置的功能，確保游標會回到叫出選字窗前的位置。
  @Test
  func test105_InputHandler_CursorPlacementRestoreAfterSelectingCandidate() throws {
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.useRearCursorMode = false
    testHandler.prefs.cursorPlacementAfterSelectingCandidate = 2
    clearTestPOM()

    let sequenceChars = "el dk ru4ej/ n 2k7su065j/ ru;3rup "

    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates(sequenceChars)

    press([dataArrowLeft, dataArrowLeft])

    let nodesPriorToCandidateSelection = testHandler.assembler.assembledSentence.values
    #expect(!(nodesPriorToCandidateSelection.isEmpty))
    let readingCursorIndex = testHandler.actualNodeCursorPosition
    var nodeIndex: Int?
    var readingCursor = 0
    for (index, node) in testHandler.assembler.assembledSentence.enumerated() {
      let segmentLength = node.keyArray.count
      if readingCursorIndex < readingCursor + segmentLength
        || index == nodesPriorToCandidateSelection.count - 1 {
        nodeIndex = index
        break
      }
      readingCursor += segmentLength
    }
    guard let nodeIndex else {
      Issue.record("Unable to locate node for cursor position: \(readingCursorIndex)")
      return
    }
    let currentNodeValue = nodesPriorToCandidateSelection[nodeIndex]
    let cursorPriorToCandidateSelection = testHandler.assembler.cursor

    press(dataArrowDown)

    #expect(testSession.state.type == .ofCandidates)
    let candidateValues = testSession.state.candidates.map { $0.value }
    #expect(!(candidateValues.isEmpty))
    let targetCandidate = candidateValues.first { $0 != currentNodeValue } ?? currentNodeValue
    guard let candidateIndex = candidateValues.firstIndex(of: targetCandidate) else {
      Issue.record("Target candidate not found. Candidates: \(candidateValues)")
      return
    }

    selectCandidate(at: candidateIndex)

    let nodesAfterSelectingCandidate = testHandler.assembler.assembledSentence.values
    #expect(nodesAfterSelectingCandidate.count == nodesPriorToCandidateSelection.count)
    #expect(nodesAfterSelectingCandidate[nodeIndex] == targetCandidate)
    let expectedText = nodesAfterSelectingCandidate.joined()
    let resultText = testSession.state.displayedText
    #expect(resultText == expectedText)
    #expect(testHandler.assembler.cursor == cursorPriorToCandidateSelection)
    #expect(testHandler.backupCursor == nil)
  }

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  @Test
  func test106_InputHandler_MiscCommissionTest() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentenceOrCandidates("dk ru4204el ")
    guard let handler = testSession.inputHandler else {
      Issue.record("testSession.handler is nil.")
      return
    }
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = handler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    #expect(result == "ㄎㄜ ㄐㄧˋ ㄉㄢˋ ㄍㄠ")
    result = handler.commissionByCtrlOptionCommandEnter() // isShiftPressed 的參數預設是 false。
    #expect(result == "科(ㄎㄜ)技(ㄐㄧˋ)蛋(ㄉㄢˋ)糕(ㄍㄠ)")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = handler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>蛋<rp>(</rp><rt>ㄉㄢˋ</rt><rp>)</rp></ruby><ruby>糕<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby>
    """
    #expect(result == expectedRubyResult)
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "⠇⠮⠄⠅⠡⠐⠙⠧⠐⠅⠩⠄")
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = handler.commissionByCtrlOptionCommandEnter()
    #expect(result == "⠅⠢⠁⠛⠊⠆⠙⠧⠆⠛⠖⠁")
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }

  @Test
  func test107_InputHandler_CassetteQuickPhraseSelection() throws {
    let dataPath = LMATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let dataPath else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取：array30.cin2")
      return
    }
    withSynchronousLMUserData {
      testHandler.prefs.cassetteEnabled = true
      LMMgr.syncLMPrefs()
      LMAssembly.LMInstantiator.loadCassetteData(path: dataPath)
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    typeSentenceOrCandidates(",,,")
    #expect(testHandler.calligrapher == ",,,")

    let initialCandidates = testSession.state.candidates.map(\.value)
    #expect(!(initialCandidates.isEmpty))
    #expect(initialCandidates.allSatisfy { $0.count == 1 })

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      Issue.record("Quick phrase commission key missing")
      return
    }

    typeSentenceOrCandidates(quickPhraseKey)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testSession.state.type == .ofEmpty)
    #expect(testClient.toString() == "米糕")
  }

  @Test
  func test108_InputHandler_CassetteQuickPhraseSymbolTableMultiple() throws {
    let dataPath = LMATestsData.getCINPath4Tests("array30", ext: "cin2")
    guard let dataPath else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取：array30.cin2")
      return
    }
    withSynchronousLMUserData {
      testHandler.prefs.cassetteEnabled = true
      LMMgr.syncLMPrefs()
      LMAssembly.LMInstantiator.loadCassetteData(path: dataPath)
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    typeSentenceOrCandidates(",,,,")
    #expect(testHandler.calligrapher == ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      Issue.record("Quick phrase commission key missing")
      return
    }

    typeSentenceOrCandidates(quickPhraseKey)

    #expect(testSession.state.type == .ofSymbolTable)
    #expect(testSession.state.node.name == ",,,,")
    #expect(
      testSession.state.node.members.map(\.name) ==
        ["炎炎", "迷迷糊糊", "熒熒"]
    )
    #expect(
      testSession.state.candidates.map(\.value) ==
        ["炎炎", "迷迷糊糊", "熒熒"]
    )
    #expect(testClient.toString().isEmpty)

    selectCandidate(at: 1)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testSession.state.type == .ofEmpty)
    #expect(testClient.toString() == "迷迷糊糊")
  }

  @Test
  func test109_InputHandler_CodePointInputCheck() throws {
    let testCodes: [(Shared.InputMode, String)] = [
      (.imeModeCHS, "C8D0"),
      (.imeModeCHT, "A462"),
    ]

    testSession.switchState(.ofAbortion())

    for (langMode, codePointHexStr) in testCodes {
      defer {
        // 切換至 Abortion 狀態會自動清理 Handler，此時會連帶重設 typingMethod。
        testSession.switchState(.ofAbortion())
        testClient.clear()
      }
      PrefMgr().mostRecentInputMode = langMode.rawValue
      #expect(testHandler.currentTypingMethod == .vChewingFactory)
      enterCodePointMode()
      #expect(testHandler.currentTypingMethod == .codePoint)
      vCTestLog("Testing code point input for mode \(langMode) with code point \(codePointHexStr)")
      typeCodePoint(codePointHexStr)
      #expect(testClient.toString() == "刃")
      vCTestLog("-> Result: \(testClient.toString())")
    }
    vCTestLog("成功完成碼點輸入測試。")
  }

  /// 測試在內文組字區對 SymbolTable 狀態的選字窗的高亮內容的預覽。
  @Test
  func test110_InputHandler_SymbolMenuKeyTablePreviewInCompositionBuffer() throws {
    CandidateNode.load()
    handleKeyEvent(symbolMenuKeyEventIntl)
    #expect(testSession.state.type == .ofSymbolTable)

    testSession.candidatePairHighlightChanged(at: 0)
    #expect(testSession.state.highlightedCandidateIndex == 0)
    #expect(testSession.state.displayedTextConverted == "　")
    #expect(testSession.state.displayTextSegments == ["　"])
    #expect(testSession.state.attributedString.string == "　")

    testSession.candidatePairHighlightChanged(at: 1)
    #expect(testSession.state.highlightedCandidateIndex == 1)
    #expect(testSession.state.displayedTextConverted == "｀")
    #expect(testSession.state.displayTextSegments == ["｀"])
    #expect(testSession.state.attributedString.string == "｀")

    testSession.candidatePairHighlightChanged(at: 2)
    #expect(testSession.state.highlightedCandidateIndex == 2)
    #expect(testSession.state.displayedTextConverted == "")
    #expect(testSession.state.displayTextSegments == [])
    #expect(
      testSession.state.attributedString.string ==
        testSession.state.data.attributedStringPlaceholder.string
    )
  }

  @Test
  func test111_InputHandler_SymbolTableInitSetsDisplaySegments() throws {
    CandidateNode.load()
    // 選一個有子元件的候選節點（Leaf Candidate）。
    let root = CandidateNode.root
    var leafCandidate: CandidateNode?
    func findLeaf(_ node: CandidateNode) {
      if leafCandidate != nil { return }
      if node.members.isEmpty { leafCandidate = node; return }
      for m in node.members { findLeaf(m) }
    }
    findLeaf(root)
    guard let leaf = leafCandidate else { Issue.record("No leaf candidate found."); return }
    testSession.switchState(.ofSymbolTable(node: leaf))
    #expect(testSession.state.type == .ofSymbolTable)
    #expect(!(testSession.state.node.name.isEmpty))
    #expect(testSession.state.data.displayTextSegments == [testSession.state.node.name])
    #expect(testSession.state.data.displayedText == testSession.state.node.name)
  }
}
