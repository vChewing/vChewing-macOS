// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
@testable import LangModelAssembly
import LMAssemblyMaterials4Tests
import Megrez
import Shared
import Testing
@testable import Typewriter

// MARK: - AutoBracketTests

/// 自動括號配對功能的單元測試。
///
/// 注意：這些測試直接呼叫 handler 方法，繞過完整的鍵盤輸入流，
/// 以便在不依賴 SQL LM 查詢結果的情況下驗證括號配對邏輯。
@Suite("AutoBracketTests", .serialized)
@MainActor
final class AutoBracketTests {

  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.AutoBracketTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true
    PrefMgr.sharedSansDidSetOps.autoBracketPairingEnabled = true

    let lm = LMAssembly.LMInstantiator(isCHS: false)
    self.testLM = lm
    LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData)

    let handler = MockInputHandler(lm: lm, pref: PrefMgr.sharedSansDidSetOps)
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    self.testHandler = handler
    self.testSession = session
  }

  deinit {
    mainSync {
      self.testHandler?.errorCallback = nil
      self.testSession?.switchState(MockIMEState.ofAbortion())
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.AutoBracketTests")
    UserDef.resetAll()
  }

  // MARK: Internal

  var testLM: LMAssembly.LMInstantiator?
  var testHandler: MockInputHandler?
  var testSession: MockSession?

  // MARK: - 輔助函式

  func resetTestState() {
    testHandler?.clear()
    testSession?.switchState(MockIMEState.ofAbortion())
    testHandler?.prefs.autoBracketPairingEnabled = true
  }

  /// 向 ephemeralUnigrams 注入一個括號對，模擬 LM 中已存在左括號 key。
  /// 插入左括號 key 後，呼叫 handleAutoBracketPairing 來觸發右括號補入。
  func insertBracketKeyManually(leftKey: String, leftChar: Character) {
    guard let handler = testHandler, let lm = testLM else { return }
    // 先注入左括號到 ephemeral，讓 assembler.insertKey 成功
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: String(leftChar))
    _ = handler.assembler.insertKey(leftKey)
    lm.ephemeralUnigrams.removeAll()
  }
}

// MARK: - BracketPairingRules Tests

@Suite("BracketPairingRules")
struct BracketPairingRulesTests {

  @Test("全形左括號集合包含所有預期字元")
  func testFullWidthLeftSetContainsAll() {
    let expected: [Character] = ["『", "「", "《", "〈", "【", "〔", "｛", "（", "\u{201C}", "\u{2018}"]
    for ch in expected {
      #expect(BracketPairingRules.fullWidthLeftSet.contains(ch), "Missing left bracket: \(ch)")
    }
  }

  @Test("全形右括號集合包含所有預期字元")
  func testIsRightBracketContainsAll() {
    let expected: [Character] = ["』", "」", "》", "〉", "】", "〕", "｝", "）", "\u{201D}", "\u{2019}"]
    for ch in expected {
      #expect(BracketPairingRules.isRightBracket.contains(ch), "Missing right bracket: \(ch)")
    }
  }

  @Test("rightOf 對照表正確")
  func testRightOfMapping() {
    #expect(BracketPairingRules.rightOf["（"] == "）")
    #expect(BracketPairingRules.rightOf["「"] == "」")
    #expect(BracketPairingRules.rightOf["【"] == "】")
    #expect(BracketPairingRules.rightOf["《"] == "》")
  }

  @Test("leftOf 對照表正確")
  func testLeftOfMapping() {
    #expect(BracketPairingRules.leftOf["）"] == "（")
    #expect(BracketPairingRules.leftOf["」"] == "「")
    #expect(BracketPairingRules.leftOf["】"] == "【")
    #expect(BracketPairingRules.leftOf["》"] == "《")
  }

  @Test("半形括號不在全形左括號集合中")
  func testHalfWidthNotInFullWidthSet() {
    let halfWidthLeft: [Character] = ["(", "[", "{"]
    for ch in halfWidthLeft {
      #expect(!BracketPairingRules.fullWidthLeftSet.contains(ch), "Half-width bracket '\(ch)' should not be in fullWidthLeftSet")
    }
  }

  @Test("ephemeralUnigrams 初始為空")
  @MainActor
  func testEphemeralUnigrams() {
    let lm = LMAssembly.LMInstantiator(isCHS: false)
    #expect(lm.ephemeralUnigrams.isEmpty)
    lm.ephemeralUnigrams["）"] = .init(keyArray: ["）"], value: "）")
    #expect(lm.ephemeralUnigrams.count == 1)
    let results = lm.unigramsFor(keyArray: ["）"])
    #expect(!results.isEmpty, "ephemeralUnigrams should be returned by unigramsFor")
    #expect(results.first?.value == "）")
    lm.ephemeralUnigrams.removeAll()
    #expect(lm.ephemeralUnigrams.isEmpty)
  }
}

// MARK: - handleAutoBracketPairing Tests

extension AutoBracketTests {

  /// TC-AB-041: 候選窗確認左括號候選後，也應自動補入對應右括號
  @Test("TC-AB-041: Candidate confirmation of left bracket triggers pairing")
  func testCandidateConfirmationTriggersAutoPairing() {
    guard let handler = testHandler, let lm = testLM, let session = testSession else {
      Issue.record("testHandler, testLM or testSession is nil.")
      return
    }
    resetTestState()

    // 先把「｛」插入組字器（模擬使用者輸入後 LM 已有此 key），再進入候選狀態
    let bracketKey = "_punctuation_braceLeft"
    lm.ephemeralUnigrams[bracketKey] = .init(keyArray: [bracketKey], value: "｛")
    _ = handler.assembler.insertKey(bracketKey)
    lm.ephemeralUnigrams.removeAll()
    #expect(handler.assembler.length == 1, "Assembler should have 1 key before candidate confirmation")

    // 建立候選狀態：高亮候選為單一左括號「｛」
    let candidate = CandidateInState(keyArray: [bracketKey], value: "｛")
    session.switchState(
      .ofCandidates(candidates: [candidate], displayTextSegments: ["｛"], cursor: 1)
    )

    // 模擬確認候選
    session.candidatePairSelectionConfirmed(at: 0)

    // 預期：確認後組字器內為「｛｝」，游標在中間
    #expect(handler.assembler.length == 2, "Assembler should have paired brackets after candidate confirmation")
    #expect(handler.assembler.cursor == 1, "Cursor should be between paired brackets")
    #expect(handler.assembler.keys[0] == bracketKey, "First key should be the bracket key")
    #expect(handler.assembler.keys[1] == "｝", "Second key should be the right bracket (ephemeral key)")
  }

  /// TC-AB-001: 自動配對功能停用時，不觸發自動配對
  @Test("TC-AB-001: Does not pair when feature is disabled")
  func testNoPairingWhenDisabled() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()
    handler.prefs.autoBracketPairingEnabled = false

    // 注入左括號到 ephemeral，插入 assembler
    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)
    lm.ephemeralUnigrams.removeAll()

    let lengthBefore = handler.assembler.length
    let result = handler.handleAutoBracketPairing(insertedKey: leftKey)

    #expect(result == false, "Should return false when feature is disabled")
    #expect(handler.assembler.length == lengthBefore, "Assembler length should not change when disabled")
  }

  /// TC-AB-002: 插入全形左括號後，自動補入對應右括號，游標在兩括號之間
  @Test("TC-AB-002: Auto-pairs right bracket after left bracket insertion")
  func testAutoPairsRightBracket() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 手動注入「（」到 ephemeral，模擬 LM 能回傳對應字元
    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)

    // assembler 中已有一個「（」，游標在最後
    #expect(handler.assembler.length == 1)
    #expect(handler.assembler.cursor == 1)

    // 呼叫 handleAutoBracketPairing（此時 ephemeral 仍有左括號，供查詢輸出字元）
    let result = handler.handleAutoBracketPairing(insertedKey: leftKey)
    lm.ephemeralUnigrams.removeAll()

    #expect(result == true, "Should return true when pairing succeeds")
    // 組字器應有兩個 key：「（」和「）」
    #expect(handler.assembler.length == 2, "Assembler should have 2 keys after pairing")
    // 游標應在兩括號之間（位置 1）
    #expect(handler.assembler.cursor == 1, "Cursor should be between the two brackets")
    // 游標右側的 key 應為單字元「）」
    let keyAfterCursor = handler.assembler.keys[handler.assembler.cursor]
    #expect(keyAfterCursor == "）", "Key after cursor should be '）', got: '\(keyAfterCursor)'")
  }

  /// TC-AB-003: 插入「「」後，自動補入「」」
  @Test("TC-AB-003: Auto-pairs 「」")
  func testAutoPairsCornerBrackets() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    let leftKey = "「"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "「")
    _ = handler.assembler.insertKey(leftKey)
    let result = handler.handleAutoBracketPairing(insertedKey: leftKey)
    lm.ephemeralUnigrams.removeAll()

    #expect(result == true)
    #expect(handler.assembler.length == 2)
    #expect(handler.assembler.cursor == 1)
    let keyAfterCursor = handler.assembler.keys[handler.assembler.cursor]
    #expect(keyAfterCursor == "」", "Key after cursor should be '」', got: '\(keyAfterCursor)'")
  }

  /// TC-AB-004: 非左括號的 key 不觸發自動配對
  @Test("TC-AB-004: Non-bracket key does not trigger pairing")
  func testNonBracketKeyDoesNotPair() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 插入一個普通讀音（語言模型中有）
    _ = handler.assembler.insertKey("ㄅㄧˋ")
    let lengthBefore = handler.assembler.length

    // 呼叫 handleAutoBracketPairing，key 是注音讀音（非括號 key）
    let result = handler.handleAutoBracketPairing(insertedKey: "ㄅㄧˋ")

    #expect(result == false, "Should return false for non-bracket key")
    #expect(handler.assembler.length == lengthBefore, "Assembler length should not change")
  }

  /// TC-AB-005: ephemeralUnigrams 在 handleAutoBracketPairing 結束後被清空
  @Test("TC-AB-005: ephemeralUnigrams is cleared after pairing")
  func testEphemeralUnigrams_ClearedAfterPairing() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)
    _ = handler.handleAutoBracketPairing(insertedKey: leftKey)

    // handleAutoBracketPairing 內部應已清除 ephemeralUnigrams
    #expect(lm.ephemeralUnigrams.isEmpty, "ephemeralUnigrams should be empty after handleAutoBracketPairing")
  }
}

// MARK: - handleSmartOverwrite Tests

extension AutoBracketTests {

  /// TC-AB-010: Smart Overwrite：游標右側有配對的右括號，輸入相同右括號時跳過
  @Test("TC-AB-010: Smart Overwrite skips duplicate right bracket")
  func testSmartOverwrite_SkipsDuplicate() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 模擬自動配對後的狀態：assembler 有 「（」+「）」，游標在中間（位置 1）
    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)
    _ = handler.handleAutoBracketPairing(insertedKey: leftKey)
    lm.ephemeralUnigrams.removeAll()

    #expect(handler.assembler.cursor == 1)
    #expect(handler.assembler.length == 2)

    // 現在使用者再次輸入「）」對應的標點 key
    // 注入 rightKey 到 LM 模擬能查到輸出字元
    let rightPunctKey = "_test_右括號"
    lm.ephemeralUnigrams[rightPunctKey] = .init(keyArray: [rightPunctKey], value: "）")

    let result = handler.handleSmartOverwrite(for: rightPunctKey)
    lm.ephemeralUnigrams.removeAll()

    #expect(result == true, "Smart Overwrite should trigger when right bracket already exists")
    // 游標應向右移一格（跳過「）」）
    #expect(handler.assembler.cursor == 2, "Cursor should move past the right bracket")
  }

  /// TC-AB-011: Smart Overwrite：游標右側沒有右括號時，不觸發
  @Test("TC-AB-011: Smart Overwrite does not trigger when no right bracket on the right")
  func testSmartOverwrite_NoRightBracket() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 游標在組字器末尾（沒有右括號在游標右側）
    _ = handler.assembler.insertKey("ㄅㄧˋ")
    #expect(handler.assembler.cursor == handler.assembler.length)

    let result = handler.handleSmartOverwrite(for: "（")
    #expect(result == false, "Smart Overwrite should not trigger at end of assembler")
  }

  /// TC-AB-012: Smart Overwrite 停用時不觸發
  @Test("TC-AB-012: Smart Overwrite does not trigger when feature is disabled")
  func testSmartOverwrite_DisabledFeature() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()
    handler.prefs.autoBracketPairingEnabled = false

    // 模擬游標右側有右括號的情況
    let rightKey = "）"
    lm.ephemeralUnigrams[rightKey] = .init(keyArray: [rightKey], value: "）")
    _ = handler.assembler.insertKey(rightKey)
    lm.ephemeralUnigrams.removeAll()
    handler.assembler.cursor = 0

    let result = handler.handleSmartOverwrite(for: "（")
    #expect(result == false, "Smart Overwrite should not trigger when feature is disabled")
  }

  /// TC-AB-013: Smart Overwrite 右側是一般注音 key（多字元），不觸發
  @Test("TC-AB-013: Smart Overwrite does not trigger on multi-char key after cursor")
  func testSmartOverwrite_MultiBCharKey() {
    guard let handler = testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    // 插入一個正常讀音（multi-char key），游標在末尾，然後退回游標到 0
    _ = handler.assembler.insertKey("ㄅㄧˋ")
    handler.assembler.cursor = 0

    // 游標右側是 "ㄅㄧˋ"（多字元 key），不是右括號
    let result = handler.handleSmartOverwrite(for: "（")
    #expect(result == false, "Smart Overwrite should not trigger on multi-char key")
  }
}

// MARK: - handleBracketBackspace Tests

extension AutoBracketTests {

  /// TC-AB-020: 游標在空括號內，Backspace 同時刪除左右括號
  @Test("TC-AB-020: Backspace deletes both brackets when cursor is between empty brackets")
  func testBracketBackspace_DeletesBothBrackets() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 模擬自動配對後的狀態：「（」+「）」，游標在中間
    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)
    _ = handler.handleAutoBracketPairing(insertedKey: leftKey)
    lm.ephemeralUnigrams.removeAll()

    #expect(handler.assembler.length == 2)
    #expect(handler.assembler.cursor == 1)

    let result = handler.handleBracketBackspace()

    #expect(result == true, "handleBracketBackspace should return true")
    #expect(handler.assembler.length == 0, "Assembler should be empty after paired deletion")
  }

  /// TC-AB-021: 游標不在空括號內（左側不是左括號），不觸發配對刪除
  @Test("TC-AB-021: Backspace does not pair-delete when left side is not a bracket")
  func testBracketBackspace_NotBracket() {
    guard let handler = testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    // 插入普通讀音到組字器，游標在末尾
    _ = handler.assembler.insertKey("ㄅㄧˋ")
    let result = handler.handleBracketBackspace()

    // 游標右側沒有右括號，不觸發
    #expect(result == false, "handleBracketBackspace should return false for non-bracket scenario")
  }

  /// TC-AB-022: 功能停用時 Backspace 不執行配對刪除
  @Test("TC-AB-022: Backspace does not pair-delete when feature is disabled")
  func testBracketBackspace_Disabled() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()
    handler.prefs.autoBracketPairingEnabled = false

    let leftKey = "（"
    lm.ephemeralUnigrams[leftKey] = .init(keyArray: [leftKey], value: "（")
    _ = handler.assembler.insertKey(leftKey)
    _ = handler.assembler.insertKey(leftKey) // 只是讓 assembler 有兩個 key
    lm.ephemeralUnigrams.removeAll()
    handler.assembler.cursor = 1

    let result = handler.handleBracketBackspace()
    #expect(result == false, "handleBracketBackspace should return false when disabled")
  }

  /// TC-AB-023: 游標在 assembler 最左側（cursor=0），不觸發配對刪除
  @Test("TC-AB-023: Backspace at cursor=0 does not pair-delete")
  func testBracketBackspace_AtStart() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    let rightKey = "）"
    lm.ephemeralUnigrams[rightKey] = .init(keyArray: [rightKey], value: "）")
    _ = handler.assembler.insertKey(rightKey)
    lm.ephemeralUnigrams.removeAll()
    handler.assembler.cursor = 0

    // 游標在最左側（cursor=0），左側沒有 key，不觸發
    let result = handler.handleBracketBackspace()
    #expect(result == false, "handleBracketBackspace should return false when cursor is at start")
  }
}

// MARK: - EnglishBufferCursorTests

/// SmartSwitchState 游標感知方法的單元測試（Task 1 — Phase 2）。
/// 這些測試直接操作 SmartSwitchState，不需要 MockInputHandler 或 session。
@Suite("EnglishBufferCursorTests")
struct EnglishBufferCursorTests {

  // MARK: - appendEnglishChar（游標感知插入）

  @Test("appendEnglishChar 在游標位置插入字元並推進游標")
  func testAppendInsertAtCursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    // 游標在末端
    #expect(state.englishBuffer == "ab")
    #expect(state.englishBufferCursor == 2)
    // 手動退回游標後再 append
    state.englishBufferCursor = 1
    state.appendEnglishChar("X")
    // 插入點在 index 1，結果 "aXb"，游標 = 2
    #expect(state.englishBuffer == "aXb")
    #expect(state.englishBufferCursor == 2)
  }

  // MARK: - insertEnglishAtCursor

  @Test("insertEnglishAtCursor(moveCursor: false) 插入但不移動游標")
  func testInsertAtCursorNoMove() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    // cursor = 1, buffer = "("
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor 應仍為 1，buffer = "()"
    #expect(state.englishBuffer == "()")
    #expect(state.englishBufferCursor == 1)
  }

  @Test("insertEnglishAtCursor(moveCursor: true) 插入並移動游標")
  func testInsertAtCursorWithMove() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: true)
    // cursor = 2, buffer = "()"
    #expect(state.englishBuffer == "()")
    #expect(state.englishBufferCursor == 2)
  }

  // MARK: - moveEnglishCursorRight

  @Test("moveEnglishCursorRight 在範圍內推進游標")
  func testMoveRight() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    state.moveEnglishCursorRight()
    #expect(state.englishBufferCursor == 2)
  }

  @Test("moveEnglishCursorRight 在末端時不越界")
  func testMoveRightAtEnd() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    // cursor = 1 = buffer.count
    state.moveEnglishCursorRight()
    #expect(state.englishBufferCursor == 1) // 不越界
  }

  // MARK: - deleteEnglishCharBeforeCursor

  @Test("deleteEnglishCharBeforeCursor 刪除游標前字元並退游標")
  func testDeleteBefore() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    // cursor = 2, buffer = "ab"
    state.deleteEnglishCharBeforeCursor()
    #expect(state.englishBuffer == "a")
    #expect(state.englishBufferCursor == 1)
  }

  @Test("deleteEnglishCharBeforeCursor 在游標=0 時無副作用")
  func testDeleteBeforeAtStart() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    // cursor = 0, buffer = ""
    state.deleteEnglishCharBeforeCursor()
    #expect(state.englishBuffer == "")
    #expect(state.englishBufferCursor == 0)
  }

  // MARK: - deleteEnglishCharAfterCursor

  @Test("deleteEnglishCharAfterCursor 刪除游標後字元，游標不動")
  func testDeleteAfter() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    state.deleteEnglishCharAfterCursor()
    #expect(state.englishBuffer == "(")
    #expect(state.englishBufferCursor == 1)
  }

  // MARK: - englishCharBeforeCursor / englishCharAfterCursor

  @Test("englishCharBeforeCursor 和 englishCharAfterCursor 回傳正確字元")
  func testCharAccessors() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    #expect(state.englishCharBeforeCursor == "(")
    #expect(state.englishCharAfterCursor == ")")
  }

  @Test("游標在開頭時 englishCharBeforeCursor 為 nil")
  func testCharBeforeNilAtStart() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    #expect(state.englishCharBeforeCursor == nil)
  }

  @Test("游標在末端時 englishCharAfterCursor 為 nil")
  func testCharAfterNilAtEnd() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    // cursor = 1 = buffer.count
    #expect(state.englishCharAfterCursor == nil)
  }

  // MARK: - 重置行為

  @Test("enterTempEnglishMode 重置游標至 0")
  func testEnterResetscursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    #expect(state.englishBufferCursor == 2)
    state.enterTempEnglishMode()
    #expect(state.englishBufferCursor == 0)
  }

  @Test("exitTempEnglishMode 重置游標至 0")
  func testExitResetsursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    #expect(state.englishBufferCursor == 1)
    _ = state.exitTempEnglishMode()
    #expect(state.englishBufferCursor == 0)
  }
}

// MARK: - HalfWidthAutoBracketTests

/// 半形括號自動配對功能的單元測試（Phase 2）。
/// 直接呼叫 handler 方法，不走完整鍵盤輸入流。
@Suite("HalfWidthAutoBracketTests", .serialized)
@MainActor
final class HalfWidthAutoBracketTests {

  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.HalfWidthAutoBracketTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true
    PrefMgr.sharedSansDidSetOps.autoBracketPairingEnabled = true
    PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true

    let lm = LMAssembly.LMInstantiator(isCHS: false)
    let handler = MockInputHandler(lm: lm, pref: PrefMgr.sharedSansDidSetOps)
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    self.testHandler = handler
    self.testSession = session
  }

  deinit {
    mainSync {
      self.testHandler?.errorCallback = nil
      self.testSession?.switchState(MockIMEState.ofAbortion())
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.HalfWidthAutoBracketTests")
    UserDef.resetAll()
  }

  // MARK: Internal

  var testHandler: MockInputHandler?
  var testSession: MockSession?

  func resetTestState() {
    testHandler?.prefs.autoBracketPairingEnabled = true
    testHandler?.prefs.smartChineseEnglishSwitchEnabled = true
    testHandler?.smartSwitchState.reset()
    testHandler?.smartSwitchState.enterTempEnglishMode()
  }

  // MARK: - handleHalfWidthAutoBracketPairing

  /// TC-AB-030: autoBracketPairingEnabled = false 時不觸發
  @Test("TC-AB-030: Does not pair when feature is disabled")
  func testNoPairWhenDisabled() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.prefs.autoBracketPairingEnabled = false
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "(")
  }

  /// TC-AB-031: smartChineseEnglishSwitchEnabled = false 時不觸發
  @Test("TC-AB-031: Does not pair when smart switch is disabled")
  func testNoPairWhenSmartSwitchDisabled() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.prefs.smartChineseEnglishSwitchEnabled = false
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "(")
  }

  /// TC-AB-032: 輸入 '(' 自動補 ')'，游標在括號中間
  @Test("TC-AB-032: Auto-pairs ) after ( in English buffer")
  func testAutoPairParenthesis() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  /// TC-AB-033: 輸入 '[' 自動補 ']'，游標在括號中間
  @Test("TC-AB-033: Auto-pairs ] after [ in English buffer")
  func testAutoPairBracket() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("[")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "[")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "[]")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  /// TC-AB-034: 非括號字元不觸發
  @Test("TC-AB-034: Non-bracket char does not trigger pairing")
  func testNoPairForNonBracket() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("a")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "a")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "a")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  // MARK: - handleHalfWidthSmartOverwrite

  /// TC-AB-035: 游標前方有 ')' 時，輸入 ')' 跳過（Smart Overwrite）
  @Test("TC-AB-035: Smart Overwrite skips ) in English buffer")
  func testSmartOverwrite() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "()", cursor = 1
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
    // Smart Overwrite
    let result = handler.handleHalfWidthSmartOverwrite(inputChar: ")")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 2)
  }

  /// TC-AB-036: isTempEnglishMode = false 時 Smart Overwrite 不觸發
  @Test("TC-AB-036: Smart Overwrite does not trigger outside temp English mode")
  func testSmartOverwriteNotInEnglishMode() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.isTempEnglishMode = false
    let result = handler.handleHalfWidthSmartOverwrite(inputChar: ")")
    #expect(result == false)
  }

  // MARK: - handleHalfWidthBracketBackspace

  /// TC-AB-037: 空括號 "(|)" 按 Backspace 同時刪除兩側括號
  @Test("TC-AB-037: Paired backspace deletes both brackets when cursor between empty brackets")
  func testPairedBackspace() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "()", cursor = 1
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    let result = handler.handleHalfWidthBracketBackspace()
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "")
    #expect(handler.smartSwitchState.englishBufferCursor == 0)
  }

  /// TC-AB-038: 非空括號 "(hi|)" 按 Backspace 不觸發配對刪除
  @Test("TC-AB-038: Backspace does not pair-delete in non-empty brackets")
  func testNoPairedBackspaceWhenNonEmpty() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "(hi)", cursor = 3
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    handler.smartSwitchState.appendEnglishChar("h")
    handler.smartSwitchState.appendEnglishChar("i")
    #expect(handler.smartSwitchState.englishBuffer == "(hi)")
    #expect(handler.smartSwitchState.englishBufferCursor == 3)
    // charBefore = "i", charAfter = ")" → "i" 不是左括號，不觸發
    let result = handler.handleHalfWidthBracketBackspace()
    #expect(result == false)
  }
}

// MARK: - Phase 1 End-to-End Tests (with real punctuation keys from SQL LM)

extension AutoBracketTests {

  /// TC-AB-039: 使用結構化 punctuation key（帶有輸出字元的 ephemeral unigram）觸發全形括號自動配對
  ///
  /// 此測試驗證當 `insertedKey` 為結構化格式（非直接字元）時，
  /// `handleAutoBracketPairing` 能正確透過 LM 查詢取得輸出字元並觸發配對。
  @Test("TC-AB-039: Structured punctuation key triggers auto-pairing via LM lookup")
  func testAutoPairing_WithStructuredPunctuationKey() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    // 使用結構化 punctuation key，並透過 ephemeral unigram 注入 LM 查詢結果（模擬 SQL LM 有此 key）
    let leftPunctKey = "_punctuation_bracketLeft"
    let leftChar: Character = "「"
    let rightChar = BracketPairingRules.rightOf[leftChar]!
    // 注入左括號 key → 讓 assembler.insertKey 通過 LM 檢查
    lm.ephemeralUnigrams[leftPunctKey] = .init(keyArray: [leftPunctKey], value: String(leftChar))
    guard handler.assembler.insertKey(leftPunctKey) else {
      lm.ephemeralUnigrams.removeAll()
      Issue.record("assembler.insertKey('\(leftPunctKey)') failed.")
      return
    }
    // 注意：此處不清除 ephemeralUnigrams，讓 handleAutoBracketPairing 的 LM 查詢也能成功

    // 呼叫 handleAutoBracketPairing，使用結構化 punctuation key
    let result = handler.handleAutoBracketPairing(insertedKey: leftPunctKey)
    // handleAutoBracketPairing 內部呼叫 lm.unigramsFor 後會自動 removeAll()

    #expect(result == true, "handleAutoBracketPairing should return true for structured punctuation key '\(leftPunctKey)'")
    #expect(handler.assembler.length == 2, "Assembler should have 2 keys: left bracket + right bracket")
    #expect(handler.assembler.cursor == 1, "Cursor should be between the two brackets")

    // 游標右側應為右括號的單字元 key
    let keyAfterCursor = handler.assembler.keys[handler.assembler.cursor]
    #expect(
      keyAfterCursor == String(rightChar),
      "Key after cursor should be the right bracket '\(rightChar)', got: '\(keyAfterCursor)'"
    )
  }

  /// TC-AB-040: 另一個結構化 punctuation key（｛｝）觸發全形括號自動配對
  @Test("TC-AB-040: Another structured punctuation key triggers auto-pairing for ｛｝")
  func testAutoPairing_WithStructuredPunctuationKey_Brace() {
    guard let handler = testHandler, let lm = testLM else {
      Issue.record("testHandler or testLM is nil.")
      return
    }
    resetTestState()

    let leftPunctKey = "_punctuation_braceLeft"
    let leftChar: Character = "｛"
    guard let rightChar = BracketPairingRules.rightOf[leftChar] else {
      Issue.record("No right bracket defined for '｛' in BracketPairingRules.")
      return
    }
    // 注入左括號 key → 讓 assembler.insertKey 通過 LM 檢查
    lm.ephemeralUnigrams[leftPunctKey] = .init(keyArray: [leftPunctKey], value: String(leftChar))
    guard handler.assembler.insertKey(leftPunctKey) else {
      lm.ephemeralUnigrams.removeAll()
      Issue.record("assembler.insertKey('\(leftPunctKey)') failed.")
      return
    }
    // 注意：此處不清除 ephemeralUnigrams，讓 handleAutoBracketPairing 的 LM 查詢也能成功

    let result = handler.handleAutoBracketPairing(insertedKey: leftPunctKey)
    #expect(result == true)
    #expect(handler.assembler.length == 2)
    #expect(handler.assembler.cursor == 1)
    let keyAfterCursor = handler.assembler.keys[handler.assembler.cursor]
    #expect(keyAfterCursor == String(rightChar))
  }
}
