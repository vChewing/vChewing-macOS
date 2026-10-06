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

// 磁帶（CIN）模組：快速選字、組筆區與花牌鍵之行為。

// MARK: - IH.Cassette

extension LibVanguardTestsRoot.InputHandlerTests {
  /// 測試磁帶模組的快速選字功能（單一結果）。
  @Test("IH-Cassette-001 Cassette quick phrase selection")
  func test_IH_Cassette_001_CassetteQuickPhraseSelection() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true
    testHandler.currentTypingMethod = .vChewingFactory

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    let cassetteLX = LXAssembly.LXFacade.lxCassette
    #expect(cassetteLX.isLoaded)
    #expect(!cassetteLX.charDefMap.isEmpty)

    testHandler.clear()
    typeSentence(",,,")
    #expect(testHandler.calligrapher == ",,,")

    // 磁帶快速片語的候選清單應已產生，且全為單字元候選（`,,,` 對應一組單字候選）。
    let initialCandidates = testSession.state.candidates.map(\.value)
    #expect(!initialCandidates.isEmpty)
    #expect(initialCandidates.allSatisfy { $0.count == 1 })

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    // 打完 QuickPhrase 確認鍵之後，組筆區的內容應該會被清空、且狀態必須回到 .ofEmpty。
    #expect(
      testSession.state.type == .ofEmpty,
      "Quick phrase with single result should commit directly, got \(testSession.state.type)."
    )
    #expect(testHandler.calligrapher.isEmpty)
    // 只有單筆結果時，得立刻遞交出去。組筆區應該是有結果的。
    let result = generateDisplayedText()
    vCTestLog("Result after quick phrase: '\(testSession.recentCommissions.last ?? "NULL")'")
    #expect(testSession.recentCommissions.last == "米糕")
    // 單一結果的快速片語會立即遞交，因此組字器可能維持為空；此時仍需檢查狀態是否合理
    #expect(testSession.state.type == .ofEmpty || !result.isEmpty)
  }

  /// 測試磁帶模組的快速選字功能（符號表多選）。
  @Test("IH-Cassette-002 Cassette quick phrase symbol table multiple")
  func test_IH_Cassette_002_CassetteQuickPhraseSymbolTableMultiple() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    testHandler.prefs.cassetteEnabled = true

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    typeSentence(",,,,")
    #expect(testHandler.calligrapher == ",,,,")

    guard let quickPhraseKey = testHandler.currentLM.cassetteQuickPhraseCommissionKey else {
      vCTestLog("Quick phrase commission key missing, skipping test")
      return
    }

    typeSentence(quickPhraseKey)

    vCTestLog("Testing symbol table multi-selection")
    vCTestLog("Calligrapher: \(testHandler.calligrapher)")

    #expect(testSession.state.type == .ofSymbolTable)
    #expect(testSession.state.node.name == ",,,,")
    #expect(testHandler.calligrapher == ",,,,")

    // 測試是否產生了多個候選字
    let symbolCandidates = testSession.state.node.members.map { $0.name }
    #expect(symbolCandidates == ["炎炎", "迷迷糊糊", "熒熒"])
    // 此時應該還沒有 Commit 才對，因為這時的狀態是選字窗顯示出來了。
    #expect(testSession.recentCommissions.last == nil)
    let stateCandidates = testSession.state.data.candidates.map { $0.value }
    #expect(stateCandidates == symbolCandidates)
    vCTestLog("Candidates: \(symbolCandidates)")

    // 安裝可見的模擬選字窗控制器，改以選字鍵（'2'）驅動符號表項目的選取。
    testSession.installMockCandidateController()
    defer { testSession.mockCandidateController = nil }
    let selectionKeys = Array(testSession.selectionKeys)
    #expect(selectionKeys.count > 1)
    let selectionEvent = KBEvent.KeyEventData(chars: String(selectionKeys[1])).asEvent
    #expect(testHandler.triageInput(event: selectionEvent))

    // 選取之後，組筆區應被清空、狀態回到 .ofEmpty，且該符號表項目已遞交。
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testSession.state.type == .ofEmpty)
    #expect(testSession.recentCommissions.last == "迷迷糊糊")
  }

  @Test("IH-Cassette-003 Cassette auto composite with longest possible key")
  func test_IH_Cassette_003_CassetteAutoCompositeWithLongestPossibleKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    var reportedErrors = [String]()
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer { testHandler.errorCallback = nil }

    typeSentence("qqqq")

    #expect(testHandler.calligrapher.isEmpty)
    #expect(generateDisplayedText() == "金")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.recentCommissions.last == nil)
    #expect(reportedErrors.isEmpty)
  }

  @Test("IH-Cassette-004 Cassette overflow does not leak to blocked data trap")
  func test_IH_Cassette_004_CassetteOverflowDoesNotLeakToBlockedDataTrap() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = false

    var reportedErrors = [String]()
    testHandler.errorCallback = { reportedErrors.append($0) }
    defer { testHandler.errorCallback = nil }

    typeSentence("qqqq")
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testSession.state.type == .ofInputting)

    let overflowHandled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "q").asEvent)

    #expect(overflowHandled)
    #expect(testHandler.calligrapher.isEmpty)
    #expect(generateDisplayedText().isEmpty)
    #expect(testSession.state.type == .ofEmpty)
    #expect(reportedErrors.contains(where: { $0.contains("2268DD51") }))
    #expect(!reportedErrors.contains(where: { $0.contains("A9BFF20E") }))
  }

  @Test("IH-Cassette-005 Cassette Backspace works at full calligrapher length")
  func test_IH_Cassette_005_CassetteBackspaceWorksAtFullCalligrapherLength() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = false

    typeSentence("qqqq")
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testSession.state.type == .ofInputting)

    let backspaceHandled = testHandler.triageInput(event: KBEvent.KeyEventData.backspace.asEvent)

    #expect(backspaceHandled)
    #expect(testHandler.calligrapher == "qqq")
    #expect(testSession.state.type == .ofInputting)
  }

  @Test("IH-Cassette-006 Cassette Shift+Backspace disassembles previous calligraph")
  func test_IH_Cassette_006_CassetteShiftBackspaceDisassemblesPreviousCalligraph() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：wubi.cin")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    typeSentence("qqqq")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.length == 1)
    #expect(testSession.state.type == .ofInputting)

    let shiftBackspace = KBEvent.KeyEventData(
      flags: .shift,
      chars: KBEvent.SpecialKey.backspace.unicodeScalar.description,
      keyCode: KeyCode.kBackSpace.rawValue
    ).asEvent
    let shiftBackspaceHandled = testHandler.triageInput(event: shiftBackspace)

    #expect(shiftBackspaceHandled)
    #expect(testHandler.calligrapher == "qqqq")
    #expect(testHandler.assembler.length == 0)
    #expect(testSession.state.type == .ofInputting)
  }

  /// 磁帶 quick-candidate 狀態下，敲任意單字元鍵（Shift+?）應錄入組筆區、而非叫出服務選單。
  @Test("IH-Cassette-007 Cassette Shift+? types any single-character key")
  func test_IH_Cassette_007_CassetteShiftQuestionTypesAnySingleCharKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    #expect(LXAssembly.LXFacade.lxCassette.anySingleCharKey == "?")

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.useShiftQuestionToCallServiceMenu = true

    // 裝上可見的模擬候選窗控制器，重現 quick candidate 已顯示的狀態。
    testSession.mockCandidateController = MockCandidateController(visible: true)
    defer { testSession.mockCandidateController = nil }

    // 敲「y」之後，array30 的 %quick 候選（立言裡新記該認說話就）應顯示。
    typeSentence("y")
    #expect(testHandler.calligrapher == "y")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.isCandidateContainer)

    // 以 Shift+/（輸出「?」）敲入任意單字元鍵。
    let shiftQuestion = KBEvent.KeyEventData(
      flags: .shift,
      chars: "?",
      charsSansModifiers: "/",
      keyCode: 44
    ).asEvent
    _ = testHandler.triageInput(event: shiftQuestion)

    // 任意單字元鍵應進入組筆區，且不應叫出服務選單（符號表）。
    #expect(testHandler.calligrapher == "y?")
    #expect(testSession.state.type != .ofSymbolTable)

    // 組字後組字區應直接顯示「熟」（`y,` 經任意單字元鍵匹配）。
    typeSentence(" ")
    #expect(testSession.state.displayedText == "熟")

    // 叫出選字窗，確認「熟」在候選清單內。
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    #expect(testSession.state.candidates.map(\.value).contains("熟"))
  }

  @Test("IH-Cassette-008 Cassette wildcard sandwich stays in calligrapher")
  func test_IH_Cassette_008_CassetteWildcardSandwichStaysInCalligrapher() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    #expect(LXAssembly.LXFacade.lxCassette.wildcardKey == "*")

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = true

    // 敲到 `*` 時不得觸發立即組字，否則 `y*y` 這類三明治 pattern 永遠敲不出來。
    typeSentence("y*")
    #expect(testHandler.calligrapher == "y*")
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.type == .ofInputting)

    // 繼續敲 `y`，組筆區應保留完整的三明治 pattern（array30 的 `y*y*` 仍有匹配，故不自動組字）。
    typeSentence("y")
    #expect(testHandler.calligrapher == "y*y")
    #expect(testHandler.assembler.isEmpty)

    // 空白鍵組字：`y*y` 應能組出內容（匹配 yky 誰、yyy 譶 等）。
    typeSentence(" ")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(!testHandler.assembler.isEmpty)
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent))
    let candidateValues = testSession.state.candidates.map(\.value)
    #expect(candidateValues.contains("誰"))
    #expect(candidateValues.contains("譶"))
  }

  /// 磁帶模式：對組筆區內容摁下 BackSpace 時，應只縮短組筆區、而不影響候選顯示。
  @Test("IH-Cassette-009 Cassette Backspace shrinks calligrapher")
  func test_IH_Cassette_009_CassetteBackspaceShrinksCalligrapher() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("array30", ext: "cin2") else {
      Issue.record("無法存取用以測試的資料。當前嘗試存取的檔案：array30.cin2")
      return
    }

    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true

    typeSentence(",,,")
    #expect(testHandler.calligrapher == ",,,")
    #expect(testSession.state.isCandidateContainer)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.backspaceEvent.asEvent))

    #expect(testHandler.calligrapher == ",,")
    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText.count < 6)
  }
}
