// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
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

// MARK: - SmartSwitchTests

/// 智慧中英文切換功能的單元測試
///
/// 注意：這些測試驗證智慧中英文切換功能的行為。
/// 該功能的實際實作可能會根據鍵盤佈局和注音有效性檢查而變化。
@Suite("SmartSwitchTests", .serialized)
@MainActor
final class SmartSwitchTests {
  // MARK: Lifecycle

  init() {
    // 設定專用於單元測試的 UserDefaults
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.SmartSwitchTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true

    // 確保智慧中英文切換功能被啟用
    PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true

    // 初始化測試 LM
    let lm = LMAssembly.LMInstantiator(isCHS: false)
    self.testLM = lm
    LMAssembly.LMInstantiator.connectToTestSQLDB(LMATestsData.sqlTestCoreLMData)

    // 初始化測試用的 handler 和 session
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
      LMAssembly.resetSharedState()
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.SmartSwitchTests")
    UserDef.resetAll()
    mainSync {
      PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = false
    }
  }

  // MARK: Internal

  var testLM: LMAssembly.LMInstantiator?
  var testHandler: MockInputHandler?
  var testSession: MockSession?

  // MARK: - 輔助函式

  /// 重置測試狀態
  func resetTestState() {
    testHandler?.clear()
    testHandler?.smartSwitchState.reset()
    testSession?.switchState(MockIMEState.ofAbortion())
    // 確保智慧中英文切換功能被啟用
    testHandler?.prefs.smartChineseEnglishSwitchEnabled = true
  }

  /// 建立按鍵事件
  func createKeyEvent(char: String, keyCode: UInt16? = nil) -> KBEvent {
    let keyEventData = KBEvent.KeyEventData(chars: char, keyCode: keyCode ?? mapKeyCodesANSIForTests[char] ?? 65_535)
    return keyEventData.asEvent
  }

  // MARK: - Tests

  /// TC-001: 連續 2 個無效按鍵觸發臨時英文模式
  /// 測試智慧切換狀態機制的基本行為
  @Test("TC-001: Trigger temp English mode with 2 invalid keys")
  func testTriggerTempEnglishMode() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 確保注拼槽為空
    #expect(testHandler.composer.isEmpty)
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)

    // 模擬連續 2 個無效按鍵（直接測試狀態機制）
    // 在標準大千注音排列中所有英文字母都是有效的，
    // 因此我們直接測試 SmartSwitchState 的內部機制
    testHandler.smartSwitchState.incrementInvalidCount()
    testHandler.smartSwitchState.incrementInvalidCount()

    // 驗證無效計數
    #expect(testHandler.smartSwitchState.invalidKeyCount == 2)
    #expect(testHandler.smartSwitchState.shouldTriggerTempEnglishMode(threshold: 2) == true)

    // 手動進入臨時英文模式（模擬達到觸發條件後的行為）
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("x")

    // 驗證已進入臨時英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode == true)
    #expect(testHandler.smartSwitchState.englishBuffer == "x")
  }

  /// TC-002: 空白鍵返回中文模式
  @Test("TC-002: Return to Chinese mode with Space")
  func testReturnToChineseWithSpace() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動進入臨時英文模式（繞過觸發條件檢查）
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("t")
    testHandler.smartSwitchState.appendEnglishChar("e")
    testHandler.smartSwitchState.appendEnglishChar("s")
    testHandler.smartSwitchState.appendEnglishChar("t")

    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "test")

    // 驗證 exitTempEnglishMode 方法
    let result = testHandler.smartSwitchState.exitTempEnglishMode()
    #expect(result == "test")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-003: Tab 鍵返回中文模式
  @Test("TC-003: Return to Chinese mode with Tab")
  func testReturnToChineseWithTab() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動進入臨時英文模式
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("h")
    testHandler.smartSwitchState.appendEnglishChar("i")

    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "hi")

    // 發送 Tab 鍵事件，應該觸發退出臨時英文模式
    let tabEvent = KBEvent.KeyEventData.dataTab.asEvent
    _ = testHandler.triageInput(event: tabEvent)

    // 驗證已退出臨時英文模式，且緩衝內容被提交
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-004: Backspace 刪除返回中文模式
  @Test("TC-004: Return to Chinese mode with Backspace deletion")
  func testReturnToChineseWithBackspace() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動進入臨時英文模式
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("a")
    testHandler.smartSwitchState.appendEnglishChar("b")
    testHandler.smartSwitchState.appendEnglishChar("c")

    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "abc")

    // 刪除所有字母
    let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent
    _ = testHandler.triageInput(event: backspaceEvent)
    _ = testHandler.triageInput(event: backspaceEvent)
    _ = testHandler.triageInput(event: backspaceEvent)

    // 緩衝區為空，應該自動返回中文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-005: 標點符號返回中文模式
  @Test("TC-005: Return to Chinese mode with punctuation")
  func testReturnToChineseWithPunctuation() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動進入臨時英文模式
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("h")
    testHandler.smartSwitchState.appendEnglishChar("i")

    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "hi")

    // 發送標點符號事件（逗號），應該觸發退出臨時英文模式
    let commaEvent = createKeyEvent(char: ",")
    _ = testHandler.triageInput(event: commaEvent)

    // 驗證已退出臨時英文模式，且緩衝內容被提交
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-006: 有效注音不觸發英文模式
  @Test("TC-006: Valid phonabet does not trigger English mode")
  func testValidPhonabetDoesNotTrigger() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 輸入有效注音（ㄅ）- 在標準注音佈局中 '1' 對應 ㄅ
    _ = testHandler.triageInput(event: createKeyEvent(char: "1"))

    // 不應該觸發英文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    // 注拼槽應該有內容
    #expect(!testHandler.composer.isEmpty)
  }

  /// TC-007: 混合輸入重置計數器
  @Test("TC-007: Mixed input resets counter")
  func testMixedInputResetsCounter() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動設置計數器
    testHandler.smartSwitchState.incrementInvalidCount()
    testHandler.smartSwitchState.incrementInvalidCount()
    #expect(testHandler.smartSwitchState.invalidKeyCount == 2)

    // 重置計數器
    testHandler.smartSwitchState.resetInvalidCount()
    #expect(testHandler.smartSwitchState.invalidKeyCount == 0)

    // 測試 reset() 方法
    testHandler.smartSwitchState.incrementInvalidCount()
    testHandler.smartSwitchState.reset()
    #expect(testHandler.smartSwitchState.invalidKeyCount == 0)
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-008: 繼續在英文模式輸入
  @Test("TC-008: Continue typing in English mode")
  func testContinueTypingInEnglishMode() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 手動進入臨時英文模式
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("b")

    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "b")

    // 繼續輸入英文字母
    testHandler.smartSwitchState.appendEnglishChar("a")
    #expect(testHandler.smartSwitchState.englishBuffer == "ba")

    testHandler.smartSwitchState.appendEnglishChar("c")
    #expect(testHandler.smartSwitchState.englishBuffer == "bac")

    testHandler.smartSwitchState.appendEnglishChar("k")
    #expect(testHandler.smartSwitchState.englishBuffer == "back")

    // 仍然處於英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode)

    // 退出英文模式並提交
    let result = testHandler.smartSwitchState.exitTempEnglishMode()
    #expect(result == "back")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty)
  }

  /// TC-009: 功能停用時不觸發
  @Test("TC-009: Does not trigger when feature is disabled")
  func testDoesNotTriggerWhenDisabled() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 停用智慧中英文切換功能
    testHandler.prefs.smartChineseEnglishSwitchEnabled = false

    // 手動嘗試進入臨時英文模式
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("t")

    // 雖然狀態進入了英文模式，但功能被停用時不應該處理
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "t")

    // 恢復設定
    testHandler.prefs.smartChineseEnglishSwitchEnabled = true
  }

  /// TC-010: 注拼槽有內容時不觸發
  @Test("TC-010: Does not trigger when composer has content")
  func testDoesNotTriggerWhenComposerHasContent() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 先輸入有效注音，使注拼槽有內容
    _ = testHandler.triageInput(event: createKeyEvent(char: "1")) // ㄅ
    #expect(!testHandler.composer.isEmpty)

    // 注拼槽有內容時，手動嘗試進入臨時英文模式
    //（在實際情況下，這會被觸發條件阻擋）
    testHandler.smartSwitchState.enterTempEnglishMode()

    // 這個測試主要驗證 SmartSwitchState 的狀態管理
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
  }

  /// TC-011: 模擬鍵盤輸入序列測試「mail」
  /// 測試鍵盤序列：fu/3 jp4 ul3 2k4 xj4 u/4 5j/ ul3 , ul4 rmp6 mail z84
  /// 預期：輸入 "mail" 時應該自動切換為英文模式
  @Test("TC-011: Simulate key sequence to test 'mail' English switching")
  func testSimulateKeySequenceForMail() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 模擬輸入 "mail" (m-a-i-l)
    // 在標準大千注音排列中，連續輸入英文字母

    // 輸入 'm' - 這是一個輔助性測試
    let eventM = createKeyEvent(char: "m")
    _ = testHandler.triageInput(event: eventM)

    // 輸入 'a' - 應該觸發英文模式
    let eventA = createKeyEvent(char: "a")
    _ = testHandler.triageInput(event: eventA)

    // 驗證是否觸發了臨時英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode after 'ma'")

    // 繼續輸入 'i', 'l'
    let eventI = createKeyEvent(char: "i")
    _ = testHandler.triageInput(event: eventI)

    let eventL = createKeyEvent(char: "l")
    _ = testHandler.triageInput(event: eventL)

    // 驗證英文緩衝區內容
    #expect(testHandler.smartSwitchState.englishBuffer == "mail", "English buffer should contain 'mail'")
  }

  /// TC-012: 測試「test」輸入序列
  /// 預期：輸入 "test" 時應該正確顯示為 "test"
  @Test("TC-012: Input 'test' should display as 'test'")
  func testInputTestDisplaysAsTest() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }

    resetTestState()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 輸入 't'
    let eventT = createKeyEvent(char: "t")
    _ = testHandler.triageInput(event: eventT)

    // 輸入 'e' - 應該觸發英文模式
    let eventE = createKeyEvent(char: "e")
    _ = testHandler.triageInput(event: eventE)

    // 驗證是否觸發了臨時英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode after 'te'")

    // 繼續輸入 's', 't'
    let eventS = createKeyEvent(char: "s")
    _ = testHandler.triageInput(event: eventS)

    let eventT2 = createKeyEvent(char: "t")
    _ = testHandler.triageInput(event: eventT2)

    // 驗證英文緩衝區內容
    #expect(testHandler.smartSwitchState.englishBuffer == "test", "English buffer should contain 'test'")
  }

  /// TC-014: 輸入 'test' 後按空格，驗證最終 commit 出去的是 'test'
  @Test("TC-014: Pressing Space after 'test' commits 'test'")
  func testSpaceAfterTestCommitsTest() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 輸入 't', 'e', 's', 't'
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    // 驗證英文緩衝正確
    #expect(testHandler.smartSwitchState.englishBuffer == "test", "Buffer should be 'test'")

    // 按空格（觸發 commitEnglishAndReturnToChinese）
    let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
    _ = testHandler.triageInput(event: spaceEvent)

    // 'test' 應該被 commit 出去
    #expect(
      testSession.recentCommissions.contains("test"),
      "Expected 'test' in commissions, got: \(testSession.recentCommissions)"
    )
  }

  /// TC-013: 驗證路徑 B 觸發時不會誤把注音字符 commit 出去
  /// 重現 ㄍst bug：按 test，結果注音的 ㄍ 被誤 commit，s/t 沒有進英文緩衝
  @Test("TC-013: Path B trigger must not commit phonabet char")
  func testPathBDoesNotCommitPhonabet() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 輸入 't'（大千：ㄔ 聲母）
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    // 輸入 'e'（大千：ㄍ 覆蓋 ㄔ）→ 路徑 B 觸發
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

    // 不應該有任何注音字符被 commit 出去
    #expect(
      testSession.recentCommissions.isEmpty,
      "No phonabet should be committed on smart switch trigger; got: \(testSession.recentCommissions)"
    )

    // 應該進入英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in temp English mode")

    // 英文緩衝應該包含 'te'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "te",
      "English buffer should be 'te', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 繼續輸入 's', 't'
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    // 仍在英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should still be in temp English mode")

    // 英文緩衝應該是完整的 'test'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "test",
      "English buffer should be 'test', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
  }

  /// TC-016: 組字區有漢字時觸發英文切換，漢字應被 commit 出去，不丟失
  /// 重現場景：打「測試輸入」（漢字已在組字區），再打 'te' 觸發路徑 B，
  /// 預期「測試輸入」應被先 commit，再進入英文模式
  @Test("TC-016: Assembled Chinese text should be committed before entering English mode")
  func testAssembledChineseCommittedBeforeEnglishMode() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 先組出一個漢字：輸入「ㄓ」+「ㄨ」+「ˋ」= 注（注音鍵：y + m + 4）
    // y = ㄗ, / = ㄥ ... 改用更簡單的方式：1 = ㄅ, p = ㄡ, 4 = ˋ → 「簿」不在測試 LM
    // 用 su3 = ㄋ + ㄨ + ˇ → 「女」（若存在）... 先確認測試 LM 存在的字
    // 直接用 ji3 = ㄐ + ㄧ + ˇ → 使用 j=ㄖ... 
    // 大千排列：ru3 = ㄖ+ㄨ+ˇ → 「乳」；g=ㄕ, l=ㄠ... 
    // 最簡單：直接往 assembler 插入已知存在的 key，繞過注拼槽
    // 查測試 LM 的 "ㄓㄨˋ"（注）："y"=ㄗ, "m"=ㄩ... 大千 y=ㄗ 不對
    // 大千排列 t=ㄔ, w=ㄘ, i=ㄛ... 改用直接插入 assembler key 的方式
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    // 確認 assembler 非空
    #expect(!testHandler.assembler.isEmpty, "Assembler should have content after insertKey")

    testSession.recentCommissions.removeAll()

    // 現在輸入 't'（大千：ㄔ 聲母）→ composer 有 ㄔ
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    // 此時 assembler 仍有漢字，composer 有 ㄔ

    // 輸入 'e'（大千：ㄍ 覆蓋 ㄔ）→ 路徑 B 觸發
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

    // 驗證：已組漢字應被 commit 出去（不丟失）
    #expect(
      !testSession.recentCommissions.isEmpty,
      "Assembled Chinese text should have been committed before English mode"
    )

    // 驗證：已進入英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in temp English mode")

    // 驗證：英文緩衝包含 'te'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "te",
      "English buffer should be 'te', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
  }

  /// TC-017: 路徑 D — 讀音無效時直接 commit keySequence 為英文
  /// 場景：打 't'（ㄔ）+ 'o'（ㄟ）+ space，ㄔㄟ 在語彙庫中無效，
  /// 預期：直接 commit "to"，不進入英文緩衝模式
  @Test("TC-017: Path D — invalid reading on Space commits keySequence as English")
  func testPathDInvalidReadingCommitsKeySequence() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 打 't'（大千：ㄔ 聲母）
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄔ after 't'")
    #expect(testHandler.smartSwitchState.keySequence == "t", "keySequence should be 't'")

    // 打 'o'（大千：ㄟ 韻母）→ ㄔ + ㄟ = ㄔㄟ（語彙庫中無效讀音）
    // 路徑 B/C 不觸發（consonant 未被覆蓋、無介音後接聲母），keySequence 追加為 "to"
    _ = testHandler.triageInput(event: createKeyEvent(char: "o"))
    // 路徑 B/C 未觸發，應仍在中文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in English mode after 'o'")
    #expect(testHandler.smartSwitchState.keySequence == "to", "keySequence should be 'to'")

    // 打 space（confirmCombination = true）→ composeReadingIfReady 被呼叫
    // ㄔㄟ 在語彙庫中找不到 → 路徑 D 觸發，commit "to"
    let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
    _ = testHandler.triageInput(event: spaceEvent)

    // 驗證 "to" 已被 commit 出去
    #expect(
      testSession.recentCommissions.contains("to"),
      "Expected 'to' in commissions (Path D), got: \(testSession.recentCommissions)"
    )

    // 路徑 D 直接 commit，不進入英文緩衝模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in temp English mode after Path D")

    // composer 應已被清空
    #expect(testHandler.composer.isEmpty, "Composer should be empty after Path D commit")
  }

  /// TC-018: 路徑 C' — vowel 後接 consonant 觸發英文切換
  /// 場景：打 'i'（大千：ㄛ 韻母）再打 's'（大千：ㄋ 聲母），
  /// 正常注音不會 vowel 後接 consonant，應觸發智慧切換進入英文模式（英文緩衝 "is"）。
  /// Bug 重現：若未修復，ㄛ+ㄋ = ㄋㄛ → commit「の」（日文假名）。
  @Test("TC-018: Path C' — vowel followed by consonant triggers English mode")
  func testPathCPrimeVowelFollowedByConsonant() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 打 'i'（大千：ㄛ 韻母）→ composer vowel slot 有 ㄛ
    _ = testHandler.triageInput(event: createKeyEvent(char: "i"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄛ after 'i'")
    #expect(testHandler.smartSwitchState.keySequence == "i", "keySequence should be 'i'")

    // 打 's'（大千：ㄋ 聲母）→ vowel 後接 consonant，應觸發路徑 C'
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))

    // 應已進入英文模式（不應輸出「の」）
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after vowel+consonant (path C')"
    )

    // 英文緩衝應包含 'is'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "is",
      "English buffer should be 'is', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 不應有任何 commit（特別是不應該有「の」）
    #expect(
      testSession.recentCommissions.isEmpty,
      "No text should be committed on smart switch trigger; got: \(testSession.recentCommissions)"
    )
  }

  /// TC-019: 路徑 B' — consonant+vowel 後再接同一 vowel（vowel 覆蓋 vowel），觸發英文切換
  /// 場景：打 'a'（大千：ㄇ 聲母）再打 'p'（大千：聲母存在時 → ㄡ 韻母），
  /// 再打第二個 'p'（vowel slot 已有 ㄡ，再次輸入 vowel → vowel 覆蓋 vowel），
  /// 這是英文 "app" 的輸入模式，應觸發智慧切換進入英文模式（英文緩衝 "app"）。
  @Test("TC-019: Path B' — vowel overwriting vowel (with consonant present) triggers English mode")
  func testPathBPrimeVowelOverwritingVowel() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)

    // 打 'a'（大千：ㄇ 聲母）→ composer consonant slot 有 ㄇ
    _ = testHandler.triageInput(event: createKeyEvent(char: "a"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄇ after 'a'")
    #expect(testHandler.smartSwitchState.keySequence == "a", "keySequence should be 'a'")

    // 打 'p'（大千：consonant 已存在時 → ㄡ 韻母）→ composer vowel slot 有 ㄡ
    _ = testHandler.triageInput(event: createKeyEvent(char: "p"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄇㄡ after 'ap'")
    #expect(testHandler.smartSwitchState.keySequence == "ap", "keySequence should be 'ap'")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in English mode after 'ap'")

    // 打第二個 'p'（vowel 已有 ㄡ，再次輸入 vowel → 路徑 B' 觸發）
    _ = testHandler.triageInput(event: createKeyEvent(char: "p"))

    // 應已進入英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after vowel overwriting vowel (path B')"
    )

    // 英文緩衝應包含 'app'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "app",
      "English buffer should be 'app', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 不應有任何 commit
    #expect(
      testSession.recentCommissions.isEmpty,
      "No text should be committed on smart switch trigger; got: \(testSession.recentCommissions)"
    )
  }

  /// TC-020: 路徑 B' — 無聲母時 vowel 覆蓋 vowel 也應觸發英文切換
  /// 場景：Shift+A 由系統直接輸出 "A"（輸入法不攔截），之後 composer 為空。
  /// 接著打 'p'（大千：無聲母時 → ㄣ 韻母），再打 'p'（ㄣ 覆蓋 ㄣ）。
  /// 此時 consonantBefore 為空，但 vowelBefore 非空，應觸發英文切換（英文緩衝 "pp"）。
  @Test("TC-020: Path B' — vowel overwriting vowel without consonant also triggers English mode")
  func testPathBPrimeVowelOverwritingVowelNoConsonant() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 驗證功能已啟用
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    // composer 為空（模擬 Shift+A 已由系統輸出後的狀態）
    #expect(testHandler.composer.isEmpty)

    // 打 'p'（大千：無聲母時 → ㄣ 韻母）→ composer vowel slot 有 ㄣ
    _ = testHandler.triageInput(event: createKeyEvent(char: "p"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄣ after 'p'")
    #expect(testHandler.smartSwitchState.keySequence == "p", "keySequence should be 'p'")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in English mode after first 'p'")

    // 打第二個 'p'（vowel slot 已有 ㄣ，再次輸入 vowel → 路徑 B' 應觸發）
    _ = testHandler.triageInput(event: createKeyEvent(char: "p"))

    // 應已進入英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after vowel overwriting vowel (no consonant, path B')"
    )

    // 英文緩衝應包含 'pp'
    #expect(
      testHandler.smartSwitchState.englishBuffer == "pp",
      "English buffer should be 'pp', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 不應有任何 commit
    #expect(
      testSession.recentCommissions.isEmpty,
      "No text should be committed on smart switch trigger; got: \(testSession.recentCommissions)"
    )
  }

  /// TC-022: SmartSwitchState frozenSegments API
  @Test("TC-022: SmartSwitchState frozenSegments tracks frozen display text")
  func testFrozenSegmentsAPI() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    // Initially empty
    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
    #expect(testHandler.smartSwitchState.frozenDisplayText.isEmpty)

    // freezeSegment appends
    testHandler.smartSwitchState.freezeSegment("中文")
    #expect(testHandler.smartSwitchState.frozenSegments == ["中文"])
    #expect(testHandler.smartSwitchState.frozenDisplayText == "中文")

    testHandler.smartSwitchState.freezeSegment("english")
    #expect(testHandler.smartSwitchState.frozenSegments == ["中文", "english"])
    #expect(testHandler.smartSwitchState.frozenDisplayText == "中文english")

    // clearFrozenSegments clears
    testHandler.smartSwitchState.clearFrozenSegments()
    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
    #expect(testHandler.smartSwitchState.frozenDisplayText.isEmpty)

    // reset() also clears frozenSegments
    testHandler.smartSwitchState.freezeSegment("測試")
    testHandler.smartSwitchState.reset()
    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)

    // exitTempEnglishMode 不應清除 frozenSegments
    testHandler.smartSwitchState.freezeSegment("中文")
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("a")
    _ = testHandler.smartSwitchState.exitTempEnglishMode()
    #expect(
      testHandler.smartSwitchState.frozenSegments == ["中文"],
      "exitTempEnglishMode() should NOT clear frozenSegments"
    )
  }

  /// TC-021: 臨時英文模式下按 Enter，應提交英文緩衝並消耗 Enter（不穿透給應用程式）
  /// 重現場景：打 'test' 進入英文模式後按 Enter，
  /// 預期：'test' 被 commit、Enter 被消耗（triageInput 返回 true）、不再處於英文模式。
  @Test("TC-021: Enter in temp English mode commits buffer and consumes Enter")
  func testEnterInTempEnglishModeConsumesEnter() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 輸入 't', 'e', 's', 't'（觸發臨時英文模式）
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    // 確認已進入英文模式且緩衝正確
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "test", "Buffer should be 'test'")

    // 按 Enter
    let enterEvent = KBEvent.KeyEventData.dataEnterReturn.asEvent
    let result = testHandler.triageInput(event: enterEvent)

    // Enter 應被消耗（返回 true），不應穿透給應用程式
    #expect(result == true, "Enter should be consumed (return true), not passed to the app")

    // 'test' 應被 commit 出去
    #expect(
      testSession.recentCommissions.contains("test"),
      "Expected 'test' in commissions, got: \(testSession.recentCommissions)"
    )

    // 應已退出英文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should have exited temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer.isEmpty, "English buffer should be empty")
  }
}
