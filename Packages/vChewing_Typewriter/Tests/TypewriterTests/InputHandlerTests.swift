// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared
@testable import Typewriter
import XCTest

func vCTestLog(_ str: String) {
  print("[VCLOG] \(str)")
}

// MARK: - InputHandlerTests

/// 威注音輸入法的 InputHandler 單元測試（Typewriter 模組）
class InputHandlerTests: XCTestCase {
  // MARK: - Properties

  var testLM = LMAssembly.LMInstantiator.construct { _ in
    LMAssembly.LMInstantiator.connectToTestSQLDB()
  }

  var testHandler: MockInputHandler!
  var testSession: MockSession!

  // MARK: - Setup and Teardown

  override func setUpWithError() throws {
    // 設定專用於單元測試的 UserDefaults
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true

    // 初始化測試用的 handler 和 session
    testHandler = MockInputHandler(lm: testLM, pref: PrefMgr())
    testSession = MockSession()
    testSession.inputHandler = testHandler
    testHandler.session = testSession

    // 同步語言模型設定
    LMMgr.syncLMPrefs()
  }

  override func tearDownWithError() throws {
    testSession.switchState(MockIMEState.ofAbortion())
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
  }

  // MARK: - Utility Functions

  func clearTestPOM() {
    testHandler.currentLM.clearPOMData()
  }

  func typeSentence(_ sequence: String) {
    for char in sequence {
      let charStr = String(char)
      // 這裡簡化處理，直接調用 InputHandler 的方法
      // 在實際應用中，這會通過 NSEvent 來處理
      _ = testHandler.handleInput(charStr, isTypingVertical: false)
    }
  }

  // MARK: - Test Cases

  /// 測試基本的打字組句（不是ㄅ半注音）。
  func test101_InputHandler_BasicSentenceComposition() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("測試組句：高科技公司的年中獎金")
    
    // 重置 InputHandler
    testHandler.clear()
    
    // 打字
    typeSentence("el dk ru4ej/ n 2k7su065j/ ru;3rup ")
    
    let resultText = testSession.state.displayedText
    vCTestLog("- // 組字結果：\(resultText)")
    XCTAssertEqual(resultText, "高科技公司的年中獎金")
  }

  /// 測試組字器基本功能。
  func test103_InputHandler_CompositorBasics() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()

    testHandler.clear()
    vCTestLog("測試組字器基本功能")
    
    // 測試組字器是否能正確初始化
    XCTAssertTrue(testHandler.assembler.isEmpty)
    
    // 打字後組字器應該不為空
    typeSentence("el ")
    XCTAssertFalse(testHandler.assembler.isEmpty)
    vCTestLog("成功完成組字器基本功能測試")

  /// 測試 inputHandler.commissionByCtrlOptionCommandEnter()。
  func test106_InputHandler_MiscCommissionTest() throws {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    vCTestLog("正在測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
    
    testHandler.clear()
    typeSentence("el dk ru4ej/ n 2k7")
    
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 0
    var result = testHandler.commissionByCtrlOptionCommandEnter(isShiftPressed: true)
    XCTAssertEqual(result, "ㄍㄠ ㄎㄜ ㄐㄧˋ ㄍㄨㄥ ㄙ ˙ㄉㄜ")
    
    result = testHandler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "高(ㄍㄠ)科(ㄎㄜ)技(ㄐㄧˋ)公(ㄍㄨㄥ)司(ㄙ)的(˙ㄉㄜ)")
    
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 1
    result = testHandler.commissionByCtrlOptionCommandEnter()
    let expectedRubyResult = """
    <ruby>高<rp>(</rp><rt>ㄍㄠ</rt><rp>)</rp></ruby><ruby>科<rp>(</rp><rt>ㄎㄜ</rt><rp>)</rp></ruby><ruby>技<rp>(</rp><rt>ㄐㄧˋ</rt><rp>)</rp></ruby><ruby>公<rp>(</rp><rt>ㄍㄨㄥ</rt><rp>)</rp></ruby><ruby>司<rp>(</rp><rt>ㄙ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>
    """
    XCTAssertEqual(result, expectedRubyResult)
    
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 2
    result = testHandler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠅⠩⠄⠇⠮⠄⠅⠡⠐⠅⠯⠄⠑⠄⠙⠮⠁")
    
    testHandler.prefs.specifyCmdOptCtrlEnterBehavior = 3
    result = testHandler.commissionByCtrlOptionCommandEnter()
    XCTAssertEqual(result, "⠛⠖⠁⠅⠢⠁⠛⠊⠆⠛⠲⠁⠎⠁⠙⠢")
    
    vCTestLog("成功完成測試 inputHandler.commissionByCtrlOptionCommandEnter()。")
  }
}

// MARK: - LMInstantiator Extension for Tests

extension LMAssembly.LMInstantiator {
  static func construct(
    isCHS: Bool = false, completionHandler: @escaping (_ this: LMAssembly.LMInstantiator) -> ()
  )
    -> LMAssembly.LMInstantiator {
    let this = LMAssembly.LMInstantiator(isCHS: isCHS)
    completionHandler(this)
    return this
  }
}
