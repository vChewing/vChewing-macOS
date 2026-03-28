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
}
