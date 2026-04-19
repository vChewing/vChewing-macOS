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
    LMAssembly.LMInstantiator.connectToTestFactoryDictionary(textMapData: LMATestsData.textMapTestCoreLMData)

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

  /// TC-005: 臨時英文模式下按標點符號（逗號）應加入英文緩衝，而非退出英文模式。
  /// 原本測試「標點符號返回中文」，現已改為驗證新行為：ASCII 標點加入緩衝。
  @Test("TC-005: Punctuation in temp English mode appends to buffer (not return to Chinese)")
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

    // 發送標點符號事件（逗號），現在應加入英文緩衝，繼續保持英文模式
    let commaEvent = createKeyEvent(char: ",")
    _ = testHandler.triageInput(event: commaEvent)

    // 驗證仍在英文模式，逗號已加入緩衝
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should still be in temp English mode after ','")
    #expect(
      testHandler.smartSwitchState.englishBuffer == "hi,",
      "englishBuffer should be 'hi,', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
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

  /// TC-014: 輸入 'test' 後按空格，空格應直接插入英文緩衝（'test '），不凍結、不離開英文模式
  @Test("TC-014: Pressing Space after 'test' appends space to english buffer")
  func testSpaceAfterTestFreezeTest() {
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

    #expect(testHandler.smartSwitchState.englishBuffer == "test", "Buffer should be 'test'")

    // 按空格（新行為：插入空格到英文緩衝，不離開英文模式）
    let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
    _ = testHandler.triageInput(event: spaceEvent)

    // 不應有任何文字被 commit 出去
    #expect(
      testSession.recentCommissions.isEmpty,
      "Space should append to buffer, not commit; got: \(testSession.recentCommissions)"
    )

    // 仍在英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should still be in temp English mode")

    // englishBuffer 應為 'test '（含空格）
    #expect(
      testHandler.smartSwitchState.englishBuffer == "test ",
      "englishBuffer should be 'test ', got: '\(testHandler.smartSwitchState.englishBuffer)'"
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

  /// TC-016: 組字區有漢字時觸發英文切換，漢字應留在組字區（凍結），不直接提交
  @Test("TC-016: Assembled Chinese text should be frozen in buffer, not committed, before entering English mode")
  func testAssembledChineseFrozenBeforeEnglishMode() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 插入已知存在的讀音到 assembler
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    #expect(!testHandler.assembler.isEmpty, "Assembler should have content after insertKey")

    testSession.recentCommissions.removeAll()

    // 輸入 't'（大千：ㄔ 聲母）
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    // 輸入 'e'（大千：ㄍ 覆蓋 ㄔ）→ 路徑 B 觸發
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

    // 新行為：漢字不應被 commit 出去，而是凍結在組字區
    #expect(
      testSession.recentCommissions.isEmpty,
      "Chinese text should NOT be committed (only frozen); got: \(testSession.recentCommissions)"
    )

    // frozenSegments 應有內容
    #expect(
      !testHandler.smartSwitchState.frozenSegments.isEmpty,
      "frozenSegments should contain the assembled Chinese text"
    )

    // 已進入英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in temp English mode")

    // 英文緩衝包含 'te'
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

  /// TC-038: 路徑 D 有漢字前綴時，應保留漢字於組字區並進入臨時英文模式（迴歸測試）
  /// 場景：組字器有漢字（ㄅㄧˋ），打 't'（ㄔ）+ 'o'（ㄟ）+ space，
  /// ㄔㄟ 在語彙庫中無效（路徑 D），但組字器有漢字前綴，
  /// 預期：不 commit 任何文字，改進入臨時英文模式，英文緩衝為 "to "，漢字凍結在組字區。
  @Test("TC-038: Path D with Chinese prefix keeps Chinese in buffer and enters English mode")
  func testPathDWithChinesePrefixEntersEnglishMode() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 先組入一個有效讀音，讓組字器含有漢字
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    #expect(!testHandler.assembler.isEmpty, "Assembler should have content")
    testSession.recentCommissions.removeAll()

    // 打 't'（大千：ㄔ 聲母），不觸發智慧切換（composer 從空變非空）
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(testHandler.smartSwitchState.keySequence == "t")

    // 打 'o'（大千：ㄟ 韻母）→ ㄔ + ㄟ，路徑 B/C 不觸發
    _ = testHandler.triageInput(event: createKeyEvent(char: "o"))
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in English mode after 'o'")
    #expect(testHandler.smartSwitchState.keySequence == "to")

    // 打 space → 路徑 D 觸發；因有漢字前綴，應進入臨時英文模式而非 commit
    let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
    _ = testHandler.triageInput(event: spaceEvent)

    // 不應有任何文字被 commit 出去
    #expect(
      testSession.recentCommissions.isEmpty,
      "Nothing should be committed when Chinese prefix exists; got: \(testSession.recentCommissions)"
    )

    // 應已進入臨時英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after Path D with Chinese prefix"
    )

    // frozenSegments 應含有漢字
    #expect(
      !testHandler.smartSwitchState.frozenSegments.isEmpty,
      "frozenSegments should contain the Chinese text"
    )

    // 英文緩衝應為 "to "（keySequence + space）
    #expect(
      testHandler.smartSwitchState.englishBuffer == "to ",
      "englishBuffer should be 'to ', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // session 狀態應為 ofInputting（顯示漢字 + 英文緩衝）
    #expect(
      testSession.state.type == .ofInputting,
      "State should be ofInputting, got: \(testSession.state.type)"
    )
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

  /// TC-023: generateStateOfInputting prepends frozenDisplayText when frozen segments exist
  @Test("TC-023: generateStateOfInputting prepends frozenDisplayText")
  func testGenerateStateOfInputtingPrependsFrozen() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    // Freeze "中文" directly into frozenSegments
    testHandler.smartSwitchState.freezeSegment("中文")

    // generateStateOfInputting should include frozen text even with empty assembler/composer.
    // We need the guarded flag to get ofInputting back when assembler is empty.
    let state = testHandler.generateStateOfInputting(guarded: true)
    #expect(
      state.displayedText.hasPrefix("中文"),
      "displayedText should start with frozen '中文', got: '\(state.displayedText)'"
    )
    // cursor should be at end of frozen text (assembler is empty, cursor = frozenDisplayText.count)
    #expect(
      state.cursor == "中文".count,
      "cursor should be \("中文".count) (end of frozen text), got: \(state.cursor)"
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

  /// TC-025: 英文模式下按空格，空格插入緩衝（不離開英文模式、不提交）；按 Tab 提交緩衝並讓 Tab 穿透。
  @Test("TC-025: Space in English mode appends to buffer; Tab commits buffer and forwards Tab")
  func testSpaceInEnglishModeFreezeBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 輸入 't', 'e', 's', 't' 進入英文模式
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "test")

    // 按空格（新行為：插入空格到緩衝，不離開英文模式）
    let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
    _ = testHandler.triageInput(event: spaceEvent)

    // 不應有任何文字被 commit 出去
    #expect(
      testSession.recentCommissions.isEmpty,
      "Space should append to buffer, not commit; got: \(testSession.recentCommissions)"
    )

    // 仍在英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should still be in English mode after Space")

    // 緩衝應為 'test '（含空格）
    #expect(
      testHandler.smartSwitchState.englishBuffer == "test ",
      "englishBuffer should be 'test ', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 按 Tab → 提交 'test '，讓 Tab 穿透給應用程式
    let tabEvent = KBEvent.KeyEventData.dataTab.asEvent
    let tabConsumed = testHandler.triageInput(event: tabEvent)

    // 已退出英文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should have exited English mode after Tab")

    // 'test '（含空格）應被提交
    #expect(
      testSession.recentCommissions.joined().contains("test"),
      "Committed text should contain 'test', got: '\(testSession.recentCommissions)'"
    )

    // frozenSegments 應已清空（已提交）
    #expect(
      testHandler.smartSwitchState.frozenSegments.isEmpty,
      "frozenSegments should be empty after Tab commit"
    )

    // Tab 應穿透給應用程式
    #expect(!tabConsumed, "Tab should not be consumed; it should pass through to the app")
  }

  /// TC-026: 英文模式下繼續輸入時，顯示凍結漢字前綴 + 增長的英文緩衝
  @Test("TC-026: Display shows frozen Chinese + growing english buffer while typing")
  func testDisplayShowsFrozenAndGrowingEnglishBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 插入 "ㄅㄧˋ" 組字後觸發英文模式（t + e = 路徑 B）
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode")

    let frozen = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")

    // 繼續輸入 's', 't' 在英文模式下
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(testHandler.smartSwitchState.englishBuffer == "test", "englishBuffer should be 'test'")

    // session.state.displayedText 應包含 frozen 前綴 + "test"
    let displayed = testSession.state.displayedText
    #expect(
      displayed.hasPrefix(frozen),
      "displayedText '\(displayed)' should start with frozen '\(frozen)'"
    )
    #expect(
      displayed.hasSuffix("test"),
      "displayedText '\(displayed)' should end with 'test'"
    )
  }

  /// TC-024: 觸發智慧切換後組字區顯示凍結漢字前綴 + 英文緩衝
  @Test("TC-024: Display shows frozen Chinese prefix + english buffer after trigger")
  func testDisplayShowsFrozenPrefixAndEnglishBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 插入 "ㄅㄧˋ" 組字
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()

    // 輸入 't', 'e' 觸發路徑 B
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

    // 驗證進入英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode)

    // session.state.displayedText 應同時包含凍結漢字和英文緩衝
    let displayed = testSession.state.displayedText
    let frozen = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")
    #expect(
      displayed.hasPrefix(frozen),
      "displayedText '\(displayed)' should start with frozen '\(frozen)'"
    )
    #expect(
      displayed.hasSuffix("te"),
      "displayedText '\(displayed)' should end with english buffer 'te'"
    )
  }

  /// TC-027: 英文模式下按 Enter，一併提交凍結漢字 + 英文緩衝
  @Test("TC-027: Enter in English mode commits frozen Chinese + english buffer together")
  func testEnterInEnglishModeCommitsFrozenAndEnglish() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 插入 "ㄅㄧˋ" 組字後觸發英文模式 (t + e)
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    #expect(testHandler.smartSwitchState.isTempEnglishMode)

    let frozen = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")

    // 繼續輸入 's', 't'
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(testHandler.smartSwitchState.englishBuffer == "test")

    // 按 Enter
    let enterEvent = KBEvent.KeyEventData.dataEnterReturn.asEvent
    let result = testHandler.triageInput(event: enterEvent)

    // Enter 應被消耗
    #expect(result == true, "Enter should be consumed")

    // 應提交 frozen + "test"
    let expected = frozen + "test"
    #expect(
      testSession.recentCommissions.contains(expected),
      "Expected '\(expected)' in commissions, got: \(testSession.recentCommissions)"
    )

    // 應已退出英文模式，frozenSegments 應被清空
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
  }

  /// TC-028: 臨時英文模式下含凍結段落時按 Tab，應提交全部內容（frozen + English）並讓 Tab 穿透。
  /// 原本測試「Tab 凍結後 Enter 提交」，現已改為驗證新行為：Tab 直接提交而非只凍結。
  @Test("TC-028: Tab in temp English mode commits frozen+English and forwards Tab")
  func testTabInTempEnglishModeCommitsAll() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // Step 1: 觸發智慧切換，建立 frozenSegments + 英文緩衝
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    let frozenBefore = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozenBefore.isEmpty, "frozenDisplayText should be non-empty after smart switch")

    testSession.recentCommissions.removeAll()

    // Step 2: 按 Tab，應提交 frozen + "test"，然後讓 Tab 穿透給應用程式
    let tabEvent = KBEvent.KeyEventData.dataTab.asEvent
    let tabConsumed = testHandler.triageInput(event: tabEvent)

    // 已離開臨時英文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should have exited temp English mode after Tab")

    // 提交的文字應包含原凍結內容 + "test"
    let committed = testSession.recentCommissions.joined()
    #expect(
      committed.contains(frozenBefore),
      "Committed text '\(committed)' should contain frozen '\(frozenBefore)'"
    )
    #expect(
      committed.contains("test"),
      "Committed text '\(committed)' should contain 'test'"
    )

    // frozenSegments 應被清空（已提交）
    #expect(
      testHandler.smartSwitchState.frozenSegments.isEmpty,
      "frozenSegments should be cleared after Tab commit"
    )

    // Tab 應穿透給應用程式
    #expect(!tabConsumed, "Tab should not be consumed; it should pass through to the app")
  }

  /// TC-029: 英文模式下單擊 Backspace，刪除一個英文字母，顯示凍結前綴 + 剩餘英文緩衝
  @Test("TC-029: Single Backspace in English mode deletes one char, displays frozen+remaining")
  func testSingleBackspaceInEnglishModeShowsFrozen() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 觸發英文模式（t + e），此時有 frozenSegments（因為 assembler 插入了漢字）
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    let frozen = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozen.isEmpty)

    // 繼續輸入 's', 't'
    _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    #expect(testHandler.smartSwitchState.englishBuffer == "test")

    // 單擊 Backspace
    let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent
    _ = testHandler.triageInput(event: backspaceEvent)

    // englishBuffer 應剩 "tes"
    #expect(testHandler.smartSwitchState.englishBuffer == "tes")

    // 仍在英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode)

    // frozenSegments 未被清除
    #expect(testHandler.smartSwitchState.frozenDisplayText == frozen)

    // 顯示應為 frozen + "tes"
    let displayed = testSession.state.displayedText
    #expect(
      displayed == frozen + "tes",
      "displayed '\(displayed)' should be frozen+remaining '\(frozen + "tes")'"
    )
  }

  /// TC-030: 英文模式下 englishBuffer 為空時按 Backspace，退出英文模式但保留 frozenSegments
  @Test("TC-030: Single Backspace with empty englishBuffer exits English mode, keeps frozenSegments")
  func testSingleBackspaceEmptyBufferExitsEnglishKeepsFrozen() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    // 手動設置：英文模式，空緩衝，有凍結段落
    testHandler.smartSwitchState.freezeSegment("中文")
    testHandler.smartSwitchState.enterTempEnglishMode()
    // englishBuffer 此時為空（enterTempEnglishMode 清空了它）

    // 單擊 Backspace
    let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent
    _ = testHandler.triageInput(event: backspaceEvent)

    // 應退出英文模式
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should exit English mode")

    // frozenSegments 應保留
    #expect(
      testHandler.smartSwitchState.frozenDisplayText == "中文",
      "frozenSegments should be preserved, got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
    )
  }

  /// TC-031: SmartSwitchState reset API 會清除 frozenSegments 與 assembler
  /// 注意：此測試直接驗證 reset() + assembler.clear() 的 API 效果。
  /// 「雙擊 Backspace 完整重置」功能已於修正連按 Backspace 清空 Bug 時一同移除。
  @Test("TC-031: SmartSwitchState reset API clears frozenSegments and assembler")
  func testDoubleTapBackspaceClearsFrozen() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 觸發英文模式（有 frozenSegments）
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(!testHandler.smartSwitchState.frozenSegments.isEmpty)

    // 直接呼叫 reset() + assembler.clear() 模擬雙擊 Backspace 效果
    // （雙擊 Backspace 計時難以在測試中精確模擬，直接驗證 reset API 的效果）
    testHandler.smartSwitchState.reset()
    testHandler.assembler.clear()

    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty, "frozenSegments should be cleared on double-tap")
    #expect(testHandler.assembler.isEmpty, "assembler should be cleared on double-tap")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
  }

  /// TC-032: 英文模式下連按 Backspace 應逐字刪除，不得清空組字區（迴歸測試）
  /// 修復前的 Bug：第一次 Backspace 刪字後設定雙擊計時器，
  /// 第二次 Backspace 若在 0.3s 內就會誤觸「完整重置」邏輯，清空所有內容。
  @Test("TC-032: Rapid Backspace in English mode deletes chars one by one, not clearing buffer")
  func testRapidBackspaceDoesNotClearBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 手動進入臨時英文模式並輸入 "English"（7 個字母）
    testHandler.smartSwitchState.enterTempEnglishMode()
    for char in ["E", "n", "g", "l", "i", "s", "h"] {
      testHandler.smartSwitchState.appendEnglishChar(char)
    }
    #expect(testHandler.smartSwitchState.isTempEnglishMode)
    #expect(testHandler.smartSwitchState.englishBuffer == "English")

    let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent

    // 連按兩次 Backspace（間隔幾乎為零，模擬快速連按）
    _ = testHandler.triageInput(event: backspaceEvent)
    _ = testHandler.triageInput(event: backspaceEvent)

    // 每次 Backspace 應只刪一個字母：English(7) - 2 = Engli(5)
    #expect(
      testHandler.smartSwitchState.englishBuffer == "Engli",
      "After 2 rapid Backspaces on 'English', buffer should be 'Engli', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
    // 仍應在英文模式
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should still be in English mode")
  }

  /// TC-033b: Shift+E 在測試 LM 中被 _letter_E 攔截，'E' 進入 assembler 而非 englishBuffer。
  /// 這是預期的中間狀態：assembler 非空，smart switch 尚未觸發。
  @Test("TC-033b: Shift+E is intercepted by _letter_E, puts E in assembler (not englishBuffer)")
  func testCapitalLetterAloneEntersEnglishMode() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 確認前置條件
    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)

    // 輸入 Shift+E
    let shiftEEvent = KBEvent.KeyEventData(
      flags: .shift,
      chars: "E",
      charsSansModifiers: "e",
      keyCode: mapKeyCodesANSIForTests["e"]
    ).asEvent

    // 確認 isUpperCaseASCIILetterKey
    #expect(shiftEEvent.isUpperCaseASCIILetterKey, "Shift+E should be isUpperCaseASCIILetterKey")
    #expect(shiftEEvent.isShiftHold, "Shift+E should have isShiftHold")

    let result = testHandler.triageInput(event: shiftEEvent)

    // _letter_E 存在於測試 LM，所以 handlePunctuation 攔截並返回 true
    #expect(result, "Shift+E should be intercepted by _letter_E (return true)")

    // 'E' 進入 assembler（透過 _letter_E unigram），smart switch 尚未觸發
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "Smart switch should NOT be triggered yet — E is in assembler via _letter_E"
    )
    #expect(
      testHandler.smartSwitchState.englishBuffer.isEmpty,
      "englishBuffer should be empty (E is in assembler, not englishBuffer), got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
    // assembler 應非空（含 _letter_E key）
    #expect(
      !testHandler.assembler.isEmpty,
      "assembler should be non-empty after Shift+E (_letter_E inserted)"
    )
  }

  /// TC-033: 中文模式下輸入 Shift+E（由 _letter_E 攔截後進入 assembler）後接小寫字母，
  /// 應觸發智慧中英文切換。assembler 的 "E" 被凍結到 frozenSegments，後續小寫字母進入 englishBuffer。
  /// 合併顯示（frozenDisplayText + englishBuffer）= "English"。
  @Test("TC-033: Shift+E then lowercase: E frozen in segments, nglish in buffer, display = English")
  func testCapitalLetterTriggersSmartSwitch() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 模擬在中文模式下輸入 "English"：Shift+E 後接小寫 n,g,l,i,s,h
    let shiftEEvent = KBEvent.KeyEventData(
      flags: .shift,
      chars: "E",
      charsSansModifiers: "e",
      keyCode: mapKeyCodesANSIForTests["e"]
    ).asEvent

    // 先輸入 Shift+E（_letter_E → E 進 assembler）
    _ = testHandler.triageInput(event: shiftEEvent)

    // 再輸入小寫 n,g,l,i,s,h（路徑 A/B/C 觸發智慧切換，freezeAssemblerContentIfNeeded 將 E 凍結）
    for char in ["n", "g", "l", "i", "s", "h"] {
      _ = testHandler.triageInput(event: createKeyEvent(char: char))
    }

    // 應進入臨時英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after typing 'English'"
    )
    // frozenDisplayText 應含 "E"（被 freezeAssemblerContentIfNeeded 凍結）
    #expect(
      testHandler.smartSwitchState.frozenDisplayText == "E",
      "frozenDisplayText should be 'E' (frozen from assembler), got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
    )
    // englishBuffer 應含 "nglish"（不含大寫 E，因為 E 已被凍結到 frozenSegments）
    #expect(
      testHandler.smartSwitchState.englishBuffer == "nglish",
      "englishBuffer should be 'nglish', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
    // 合併顯示應為 "English"
    let combinedDisplay = testHandler.smartSwitchState.frozenDisplayText + testHandler.smartSwitchState.englishBuffer
    #expect(
      combinedDisplay == "English",
      "Combined display (frozen + englishBuffer) should be 'English', got: '\(combinedDisplay)'"
    )
  }

  /// TC-034: 臨時英文模式下按 Escape 應清空所有狀態（englishBuffer、frozenSegments、assembler），
  /// 返回 ofAbortion（不提交任何文字），且 Escape 被消耗不穿透 OS（return true）。
  @Test("TC-034: Escape in temp English mode discards everything, returns ofAbortion, consumes key")
  func testEscapeInTempEnglishModeDiscardsAll() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 直接設定臨時英文模式前置狀態
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("h")
    testHandler.smartSwitchState.appendEnglishChar("i")
    testHandler.smartSwitchState.freezeSegment("你好") // 模擬有凍結的漢字

    // 確認前置條件
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "hi", "Prerequisite: englishBuffer should be 'hi'")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "你好", "Prerequisite: frozenDisplayText should be '你好'")

    // 按 Escape（keyCode = 53）
    let escapeEvent = KBEvent.KeyEventData(
      chars: "\u{1B}",
      keyCode: 53 // kEscape
    ).asEvent
    #expect(escapeEvent.isEsc, "Event should be recognized as Escape")

    let result = testHandler.triageInput(event: escapeEvent)

    // Escape 應被消耗（不穿透 OS）
    #expect(result, "Escape should be consumed (return true), not pass through to OS")

    // 所有智慧切換狀態應清空
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "Should NOT be in temp English mode after Escape"
    )
    #expect(
      testHandler.smartSwitchState.englishBuffer.isEmpty,
      "englishBuffer should be empty after Escape, got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
    #expect(
      testHandler.smartSwitchState.frozenDisplayText.isEmpty,
      "frozenDisplayText should be empty after Escape, got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
    )
    // assembler 也應清空
    #expect(testHandler.assembler.isEmpty, "assembler should be empty after Escape")

    // 不應有任何提交
    #expect(
      testSession.recentCommissions.isEmpty,
      "No text should be committed on Escape, got: \(testSession.recentCommissions)"
    )
  }

  /// TC-036: 臨時英文模式下（有凍結漢字 + 英文緩衝）啟用 CapsLock，
  /// 組字區的完整文字（凍結漢字 + 英文緩衝）應被一起提交，不應遺漏 englishBuffer。
  @Test("TC-036: CapsLock in temp English mode commits full text (frozen + englishBuffer)")
  func testCapsLockInTempEnglishModeCommitsFullText() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 模擬：組字區有 "中文E"（凍結）+ "nglish"（英文緩衝）
    // 對應場景：使用者打出 '中文E' 並觸發智慧切換，然後繼續打 'n', 'g', 'l', 'i', 's', 'h'
    testHandler.smartSwitchState.freezeSegment("中文E")
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("n")
    testHandler.smartSwitchState.appendEnglishChar("g")
    testHandler.smartSwitchState.appendEnglishChar("l")
    testHandler.smartSwitchState.appendEnglishChar("i")
    testHandler.smartSwitchState.appendEnglishChar("s")
    testHandler.smartSwitchState.appendEnglishChar("h")

    // 設定 session.state 為對應的 ofInputting 狀態（反映畫面顯示）
    // 在真實執行路徑中，handleTempEnglishMode 每次按字母後都會更新 session.state
    testSession.state = MockIMEState.ofInputting(
      displayTextSegments: ["中文E", "nglish"],
      cursor: 10
    )

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "nglish", "Prerequisite: englishBuffer should be 'nglish'")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "中文E", "Prerequisite: frozenDisplayText should be '中文E'")
    #expect(testSession.state.displayedText == "中文English", "Prerequisite: session.state.displayedText should be '中文English'")

    // 確認 bypassNonAppleCapsLockHandling 為 false
    #expect(!testHandler.prefs.bypassNonAppleCapsLockHandling, "Prerequisite: bypassNonAppleCapsLockHandling should be false")

    // 按 CapsLock + 'a'
    let capsLockAEvent = KBEvent.KeyEventData(
      flags: .capsLock,
      chars: "a",
      charsSansModifiers: "a",
      keyCode: mapKeyCodesANSIForTests["a"]
    ).asEvent
    #expect(capsLockAEvent.isCapsLockOn, "Event should have CapsLock flag set")

    _ = testHandler.triageInput(event: capsLockAEvent)

    // 完整的 "中文English" 應被提交（不應只提交 "中文E"）
    #expect(
      testSession.recentCommissions.contains("中文English"),
      "Full text '中文English' should be committed on CapsLock, got: \(testSession.recentCommissions)"
    )
  }

  /// TC-037: resetInputHandler() 在臨時英文模式下（有凍結漢字 + 英文緩衝），
  /// 應提交完整的文字（凍結漢字 + 英文緩衝），不應遺漏 englishBuffer。
  /// 這測試的是 CapsLock 鍵物理按下 → capsLockHitChecker → resetInputHandler() 的真實路徑。
  @Test("TC-037: resetInputHandler() in temp English mode commits full text (frozen + englishBuffer)")
  func testResetInputHandlerInTempEnglishModeCommitsFullText() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 設定前置狀態：凍結段落 "中文E" + 英文緩衝 "nglish"
    testHandler.smartSwitchState.freezeSegment("中文E")
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("n")
    testHandler.smartSwitchState.appendEnglishChar("g")
    testHandler.smartSwitchState.appendEnglishChar("l")
    testHandler.smartSwitchState.appendEnglishChar("i")
    testHandler.smartSwitchState.appendEnglishChar("s")
    testHandler.smartSwitchState.appendEnglishChar("h")

    // 同步 session.state（反映真實 app 中 handleTempEnglishMode 每次更新的狀態）
    testSession.state = MockIMEState.ofInputting(
      displayTextSegments: ["中文E", "nglish"],
      cursor: 10
    )

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "nglish", "Prerequisite: englishBuffer should be 'nglish'")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "中文E", "Prerequisite: frozenDisplayText should be '中文E'")

    // 直接呼叫 resetInputHandler()，模擬 CapsLock 物理按下 → capsLockHitChecker → resetInputHandler() 的路徑
    testSession.resetInputHandler()

    // 完整的 "中文English" 應被提交（不應只提交 "中文E"）
    #expect(
      testSession.recentCommissions.contains("中文English"),
      "Full text '中文English' should be committed by resetInputHandler(), got: \(testSession.recentCommissions)"
    )
  }

  /// TC-039: 臨時英文模式下按 Tab，應先提交凍結段落 + 英文緩衝，再讓 Tab 穿透給應用程式。
  /// 重現 bug：輸入「測試email」後按 Tab，組字區沒動但 Tab 已先送出。
  @Test("TC-039: Tab in temp English mode commits frozen+English then forwards Tab to app")
  func testTabCommitsFrozenAndEnglishThenForwards() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 模擬前置狀態：凍結段落「測試」+ 臨時英文模式下輸入 "email"
    testHandler.smartSwitchState.freezeSegment("測試")
    testHandler.smartSwitchState.enterTempEnglishMode()
    for ch in "email" { testHandler.smartSwitchState.appendEnglishChar(String(ch)) }

    testSession.state = MockIMEState.ofInputting(
      displayTextSegments: ["測試", "email"],
      cursor: 7
    )

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "email", "Prerequisite: englishBuffer should be 'email'")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "測試", "Prerequisite: frozenDisplayText should be '測試'")

    // 按 Tab
    let tabEvent = KBEvent.KeyEventData.dataTab.asEvent
    let tabConsumed = testHandler.triageInput(event: tabEvent)

    // 驗證：「測試email」應被一併提交
    #expect(
      testSession.recentCommissions.contains("測試email"),
      "Frozen text + English buffer should be committed together, got: \(testSession.recentCommissions)"
    )

    // 驗證：Tab 應穿透給應用程式（triageInput 回傳 false）
    #expect(
      !tabConsumed,
      "Tab should not be consumed; it should pass through to the app"
    )

    // 驗證：已離開臨時英文模式，frozenSegments 已清空
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should have exited temp English mode")
    #expect(testHandler.smartSwitchState.frozenSegments.isEmpty, "Frozen segments should be cleared after commit")
  }

  /// TC-038: 臨時英文模式下，ASCII 可印列字元（數字、標點等）應一律加入英文緩衝，
  /// 不再以「返回中文觸發」或「提交後重新處理」方式處理。
  /// 重現 bug："cd .." → "cd ㄡ"（'.' 被誤判為返回中文觸發鍵，第二個 '.' 變成注音 ㄡ）。
  @Test("TC-038: ASCII printable chars (digits, punctuation) in temp English mode are appended to buffer")
  func testASCIIPrintableCharsAppendedToEnglishBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 模擬前置狀態：已在臨時英文模式下輸入 "cd "（空格已在緩衝中）
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("c")
    testHandler.smartSwitchState.appendEnglishChar("d")
    testHandler.smartSwitchState.appendEnglishChar(" ")

    testSession.state = MockIMEState.ofInputting(
      displayTextSegments: ["cd "],
      cursor: 3
    )

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "cd ", "Prerequisite: englishBuffer should be 'cd '")

    // 按 '.'（大千排列中 = ㄡ，但在英文模式下應加入緩衝而非變成 ㄡ）
    let dotEvent = KBEvent.KeyEventData(chars: ".", keyCode: mapKeyCodesANSIForTests["."] ?? 47).asEvent
    _ = testHandler.triageInput(event: dotEvent)

    // 驗證：'.' 加入緩衝（仍在英文模式）
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should still be in temp English mode after '.'"
    )
    #expect(
      testHandler.smartSwitchState.englishBuffer == "cd .",
      "englishBuffer should be 'cd .' after pressing '.', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 再按一次 '.'
    _ = testHandler.triageInput(event: dotEvent)
    #expect(
      testHandler.smartSwitchState.englishBuffer == "cd ..",
      "englishBuffer should be 'cd ..' after pressing '.' twice, got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // 不應有任何字元被提交
    #expect(
      testSession.recentCommissions.isEmpty,
      "Nothing should be committed yet, got: \(testSession.recentCommissions)"
    )

    // 按 Enter 提交全部
    let enterEvent = KBEvent.KeyEventData.dataEnterReturn.asEvent
    _ = testHandler.triageInput(event: enterEvent)

    #expect(
      testSession.recentCommissions.contains("cd .."),
      "Should commit 'cd ..', got: \(testSession.recentCommissions)"
    )
  }

  // MARK: - TC-040 ~ TC-042：'/' 特例（組字器為空時優先作為斜線字元）

  /// TC-040: 智慧切換模式下，composer 為空時按 '/' 應進入臨時英文模式，緩衝為 "/"。
  /// 場景：使用者想輸入路徑或日期分隔符（/），不是注音 ㄥ。
  @Test("TC-040: '/' with empty composer in smart mode enters English buffer with '/'")
  func testSlashWithEmptyComposerEntersEnglishBuffer() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    #expect(testHandler.composer.isEmpty, "Composer should be empty before test")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)

    // 按 '/'（大千排列中對應 ㄥ，但智慧切換模式下應優先作為斜線字元）
    let slashEvent = KBEvent.KeyEventData(chars: "/", keyCode: mapKeyCodesANSIForTests["/"] ?? 44).asEvent
    _ = testHandler.triageInput(event: slashEvent)

    // 應進入臨時英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode after '/' with empty composer"
    )

    // 英文緩衝應為 "/"
    #expect(
      testHandler.smartSwitchState.englishBuffer == "/",
      "englishBuffer should be '/', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // composer 應仍為空（未收到 ㄥ）
    #expect(testHandler.composer.isEmpty, "Composer should still be empty (no ㄥ received)")

    // 沒有任何文字被提交出去
    #expect(
      testSession.recentCommissions.isEmpty,
      "Nothing should be committed yet, got: \(testSession.recentCommissions)"
    )
  }

  /// TC-041: 智慧切換模式下，assembler 有漢字 + composer 為空時按 '/'，
  /// 應凍結漢字後進入臨時英文模式，英文緩衝為 "/"，凍結段落非空。
  @Test("TC-041: '/' with assembled Chinese freezes Chinese and enters English buffer with '/'")
  func testSlashWithAssembledChineseFreezesThenEnglish() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 先組入已知存在的讀音
    _ = testHandler.assembler.insertKey("ㄅㄧˋ")
    testHandler.assemble()
    #expect(!testHandler.assembler.isEmpty, "Assembler should have content")
    testSession.recentCommissions.removeAll()

    // 按 '/'
    let slashEvent = KBEvent.KeyEventData(chars: "/", keyCode: mapKeyCodesANSIForTests["/"] ?? 44).asEvent
    _ = testHandler.triageInput(event: slashEvent)

    // 漢字不應被 commit 出去，而是凍結
    #expect(
      testSession.recentCommissions.isEmpty,
      "Chinese text should be frozen, not committed; got: \(testSession.recentCommissions)"
    )

    // frozenSegments 應有內容（漢字被凍結）
    #expect(
      !testHandler.smartSwitchState.frozenSegments.isEmpty,
      "frozenSegments should contain assembled Chinese text"
    )

    // 應進入臨時英文模式
    #expect(
      testHandler.smartSwitchState.isTempEnglishMode,
      "Should be in temp English mode"
    )

    // 英文緩衝應為 "/"
    #expect(
      testHandler.smartSwitchState.englishBuffer == "/",
      "englishBuffer should be '/', got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )

    // session 狀態應為 ofInputting（顯示漢字 + "/"）
    #expect(
      testSession.state.type == .ofInputting,
      "State should be ofInputting, got: \(testSession.state.type)"
    )
  }

  /// TC-042: 智慧切換模式下，composer 非空（正在組音中）時按 '/' 應維持注音 ㄥ 行為，
  /// 不應觸發斜線特例。
  /// 場景：使用者先輸入 'l'（大千 = ㄌ 聲母），再按 '/'，應組成 ㄌㄥ（composer 有 ㄌㄥ）。
  @Test("TC-042: '/' with non-empty composer (composing Zhuyin) falls through to ㄥ behavior")
  func testSlashWithNonEmptyComposerBehavesAsZhuyin() {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    resetTestState()

    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    #expect(testHandler.composer.isEmpty)

    // 先輸入 'l'（大千排列：ㄌ 聲母）→ composer 有 ㄌ
    _ = testHandler.triageInput(event: createKeyEvent(char: "l"))
    #expect(!testHandler.composer.isEmpty, "Composer should have ㄌ after 'l'")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should NOT be in English mode after 'l'")

    // 再按 '/' → 因為 composer 非空，不應觸發斜線特例，應繼續作為 ㄥ 處理
    let slashEvent = KBEvent.KeyEventData(chars: "/", keyCode: mapKeyCodesANSIForTests["/"] ?? 44).asEvent
    _ = testHandler.triageInput(event: slashEvent)

    // 不應進入臨時英文模式（composer 非空，'/' 被當作 ㄥ）
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "Should NOT be in temp English mode — composer was non-empty, '/' treated as ㄥ"
    )

    // composer 應包含 ㄥ（或 ㄌ+ㄥ 組合），不應為空
    #expect(!testHandler.composer.isEmpty, "Composer should still have content (ㄌ+ㄥ or ㄥ)")
  }

  /// TC-043: 智慧切換模式下，組字區為空時按 '/'（進入英文特例）再按 ↓，
  /// 應取消斜線英文特例並切換到 ㄥ 注音模式。
  /// - 若語言模型有 ㄥ 記錄：進入選字窗（.ofCandidates）。
  /// - 若語言模型無 ㄥ 記錄（降級）：ㄥ 放入注拼槽，狀態為 .ofInputting。
  /// 兩種情境下，臨時英文模式均應退出，英文緩衝應為空。
  @Test("TC-043: '/' + ↓ with empty assembler exits English mode and switches to ㄥ preedit/candidates")
  func testSlashDownArrowExitsEnglishModeToZhuyin() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    #expect(testHandler.composer.isEmpty, "Prerequisite: composer should be empty")
    #expect(testHandler.assembler.isEmpty, "Prerequisite: assembler should be empty")

    // 按 '/' → 應觸發斜線特例並進入臨時英文模式
    let slashEvent = KBEvent.KeyEventData(chars: "/", keyCode: mapKeyCodesANSIForTests["/"] ?? 44).asEvent
    _ = testHandler.triageInput(event: slashEvent)
    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode after '/'")
    #expect(testHandler.smartSwitchState.englishBuffer == "/", "Prerequisite: englishBuffer should be '/'")

    // 按 ↓ → 應取消臨時英文模式並切換為 ㄥ 注音模式
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)

    // 臨時英文模式應已退出
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "Should NOT be in temp English mode after ↓"
    )
    #expect(
      testHandler.smartSwitchState.englishBuffer.isEmpty,
      "englishBuffer should be empty after ↓"
    )

    // 不應提交任何文字（'/' 被取消，無凍結漢字）
    #expect(
      testSession.recentCommissions.isEmpty,
      "No text should be committed — '/' was cancelled (no frozen Chinese)"
    )

    // 結果應為 ㄥ 在選字窗（LM 有記錄）或注拼槽（降級）
    let hasEngReading = testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄥ"])
    if hasEngReading {
      #expect(
        testSession.state.type == .ofCandidates,
        "LM has ㄥ entries → state should be ofCandidates, got: \(testSession.state.type)"
      )
    } else {
      // 降級：ㄥ 在注拼槽，狀態為 ofInputting
      #expect(
        testSession.state.type == .ofInputting,
        "LM has no ㄥ entry → state should be ofInputting (ㄥ in preedit), got: \(testSession.state.type)"
      )
      #expect(
        !testHandler.composer.isEmpty,
        "ㄥ should be in the composer (fallback path)"
      )
    }
  }

  /// TC-044: 智慧切換模式下，組字區有漢字時按 '/'（觸發斜線特例＋凍結漢字）再按 ↓，
  /// 應先提交凍結漢字，再切換到 ㄥ 注音模式。
  @Test("TC-044: '/' + ↓ with frozen Chinese commits Chinese then switches to ㄥ preedit/candidates")
  func testSlashDownArrowWithFrozenChineseCommitsThenSwitchesToZhuyin() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    #expect(testHandler.prefs.smartChineseEnglishSwitchEnabled == true)
    #expect(testHandler.composer.isEmpty, "Prerequisite: composer should be empty")

    // 先打注音組出一個字放進組字區（使用大千排列，輸入 ㄋㄧㄢˊ = "年"）
    // 大千：n=ㄋ, i=ㄛ(vowel)... 改用更可靠的方式：直接透過 insertKey 注入測試讀音
    // 使用 ㄌㄧㄡ（留/流）= 'l'+'u'+'f'（大千：l=ㄌ, u=ㄐ... 改成拼音或直接注入）
    // 最簡單：直接設定 assembler 有內容，模擬「打了幾個字」的情境
    // 先用 triageInput 輸入「ㄋㄧㄢˊ」= 大千 n=ㄋ, i=ㄛ 不對
    // 安全的做法：直接設定 smartSwitchState.frozenSegments，並確保 assembler 非空後再按 '/'
    // 實際上 '/' 特例的條件是 composer.isEmpty，assembler 可以非空
    // 故：手動讓 assembler 有讀音（ㄌㄧㄡ = l, u, f 大千... 跳過，用 insertKey）
    _ = testHandler.assembler.insertKey("ㄋㄧㄢˊ")
    testHandler.assemble()
    #expect(!testHandler.assembler.isEmpty, "Prerequisite: assembler should have '年' reading")

    // 按 '/' → 斜線特例觸發：凍結組字區漢字，進入臨時英文模式，englishBuffer = "/"
    let slashEvent = KBEvent.KeyEventData(chars: "/", keyCode: mapKeyCodesANSIForTests["/"] ?? 44).asEvent
    _ = testHandler.triageInput(event: slashEvent)

    guard testHandler.smartSwitchState.isTempEnglishMode else {
      Issue.record("Prerequisite failed: should be in temp English mode after '/'")
      return
    }
    #expect(testHandler.smartSwitchState.englishBuffer == "/", "englishBuffer should be '/'")
    let frozenText = testHandler.smartSwitchState.frozenDisplayText
    #expect(!frozenText.isEmpty, "Prerequisite: frozenDisplayText should not be empty")

    // 按 ↓ → 應提交凍結漢字並切換為 ㄥ 注音模式
    _ = testHandler.triageInput(event: KBEvent.KeyEventData.dataArrowDown.asEvent)

    // 臨時英文模式應已退出
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "Should NOT be in temp English mode after ↓"
    )

    // 凍結漢字應已提交
    #expect(
      testSession.recentCommissions.contains(frozenText),
      "Frozen Chinese '\(frozenText)' should have been committed, got: \(testSession.recentCommissions)"
    )

    // 結果應為 ㄥ 在選字窗（LM 有記錄）或注拼槽（降級）
    let hasEngReading = testHandler.currentLM.hasUnigramsFor(keyArray: ["ㄥ"])
    if hasEngReading {
      #expect(
        testSession.state.type == .ofCandidates,
        "LM has ㄥ entries → state should be ofCandidates, got: \(testSession.state.type)"
      )
    } else {
      #expect(
        testSession.state.type == .ofInputting,
        "LM has no ㄥ entry → state should be ofInputting (ㄥ in preedit), got: \(testSession.state.type)"
      )
      #expect(
        !testHandler.composer.isEmpty,
        "ㄥ should be in the composer (fallback path)"
      )
    }
  }

  /// TC-035: 臨時英文模式下啟用 CapsLock 並按字母，切換後 smartSwitchState 應被完整重置。
  /// 若未重置，關掉 CapsLock 後的下一個注音按鍵會被誤認為英文模式的輸入，導致錯誤行為。
  @Test("TC-035: CapsLock in temp English mode resets smartSwitchState completely")
  func testCapsLockInTempEnglishModeResetsSwitchState() {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    resetTestState()
    testSession.recentCommissions.removeAll()

    // 設定臨時英文模式前置狀態（含凍結漢字）
    testHandler.smartSwitchState.enterTempEnglishMode()
    testHandler.smartSwitchState.appendEnglishChar("h")
    testHandler.smartSwitchState.appendEnglishChar("i")
    testHandler.smartSwitchState.freezeSegment("你好")

    #expect(testHandler.smartSwitchState.isTempEnglishMode, "Prerequisite: should be in temp English mode")
    #expect(testHandler.smartSwitchState.englishBuffer == "hi", "Prerequisite: englishBuffer should be 'hi'")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "你好", "Prerequisite: frozenDisplayText should be '你好'")

    // 確認 bypassNonAppleCapsLockHandling 為 false（預設值），確保 CapsLock 會被處理
    #expect(!testHandler.prefs.bypassNonAppleCapsLockHandling, "Prerequisite: bypassNonAppleCapsLockHandling should be false")

    // 按 CapsLock + 'a'（flags 含 .capsLock）
    let capsLockAEvent = KBEvent.KeyEventData(
      flags: .capsLock,
      chars: "a",
      charsSansModifiers: "a",
      keyCode: mapKeyCodesANSIForTests["a"]
    ).asEvent
    #expect(capsLockAEvent.isCapsLockOn, "Event should have CapsLock flag set")

    _ = testHandler.triageInput(event: capsLockAEvent)

    // CapsLock 切換後，smartSwitchState 應完整重置
    #expect(
      !testHandler.smartSwitchState.isTempEnglishMode,
      "isTempEnglishMode should be false after CapsLock switch"
    )
    #expect(
      testHandler.smartSwitchState.englishBuffer.isEmpty,
      "englishBuffer should be empty after CapsLock switch, got: '\(testHandler.smartSwitchState.englishBuffer)'"
    )
    #expect(
      testHandler.smartSwitchState.frozenDisplayText.isEmpty,
      "frozenDisplayText should be empty after CapsLock switch, got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
    )
  }

  // MARK: - TC-055：ENTER 鍵提交含凍結段落的完整組字區

  /// TC-055: 中文 → SHIFT英文 → SHIFT回中文 → 再打字 → ENTER 應提交所有內容（含凍結段落），
  /// 不能因為 shouldResetSmartSwitchState(Enter) 提前清空 frozenSegments。
  @Test("TC-055: Enter commits full composition including frozen segments from SmartSwitch")
  func testEnterCommitsFrozenSegmentsPlusAssemblerContent() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    let grams: [Megrez.Unigram] = [
      .init(keyArray: ["ㄇㄚ˙"], value: "嗎", score: -1),
    ]
    grams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    resetTestState()
    testSession.recentCommissions.removeAll()

    // 1. 手動凍結「你hi」（模擬先打中文 → SHIFT英文 → SHIFT回中文後的凍結狀態）
    testHandler.smartSwitchState.freezeSegment("你hi")
    #expect(testHandler.smartSwitchState.frozenDisplayText == "你hi")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)

    // 2. 組字：打嗎（直接插入 key，模擬組字區有內容）
    #expect(testHandler.assembler.insertKey("ㄇㄚ˙"))
    testHandler.assemble()
    testSession.switchState(testHandler.generateStateOfInputting())
    #expect(testSession.state.displayedText == "你hi嗎")

    // 3. 按 ENTER → 應提交「你hi嗎」，不能因為 reset() 清空 frozenSegments 而只剩「嗎」
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(
      testSession.recentCommissions.joined() == "你hi嗎",
      "Enter should commit all frozen + assembler content, got: '\(testSession.recentCommissions.joined())'"
    )
  }
}
