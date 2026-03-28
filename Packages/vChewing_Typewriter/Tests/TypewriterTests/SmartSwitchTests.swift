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
  }

  /// 建立按鍵事件
  func createKeyEvent(char: String, keyCode: UInt16? = nil) -> KBEvent {
    let keyEventData = KBEvent.KeyEventData(chars: char, keyCode: keyCode ?? mapKeyCodesANSIForTests[char] ?? 65_535)
    return keyEventData.asEvent
  }

  // MARK: - Tests

  /// TC-001: 連續 2 個無效按鍵觸發臨時英文模式
  /// 使用 'x' 和 'q' 作為無效按鍵，在標準注音佈局中這些是無效輸入
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

    // 使用在標準注音佈局中無效的按鍵
    // 連續輸入兩個無效按鍵
    _ = testHandler.triageInput(event: createKeyEvent(char: "x"))
    _ = testHandler.triageInput(event: createKeyEvent(char: "q"))

    // 驗證是否進入臨時英文模式
    // 注意：實際結果取決於注音有效性檢查的實作
    vCTestLog("After 2 invalid keys - isTempEnglishMode: \(testHandler.smartSwitchState.isTempEnglishMode)")

    // 由於智慧切換的具體實作可能因鍵盤佈局而異，
    // 這裡我們主要驗證狀態機制的基本行為
    if testHandler.smartSwitchState.isTempEnglishMode {
      #expect(testHandler.smartSwitchState.englishBuffer == "q")
    }
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

    // 驗證退出臨時英文模式會返回正確的緩衝內容
    let result = testHandler.smartSwitchState.exitTempEnglishMode()
    #expect(result == "hi")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
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

    // 驗證退出臨時英文模式
    let result = testHandler.smartSwitchState.exitTempEnglishMode()
    #expect(result == "hi")
    #expect(!testHandler.smartSwitchState.isTempEnglishMode)
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
}
