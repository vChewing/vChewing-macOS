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

  var testLM: LMAssembly.LMInstantiator!
  var testHandler: MockInputHandler!
  var testSession: MockSession!

  // MARK: - Setup and Teardown

  override func setUpWithError() throws {
    // 設定專用於單元測試的 UserDefaults
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true

    // 初始化測試 LM
    testLM = LMAssembly.LMInstantiator(isCHS: false)
    LMAssembly.LMInstantiator.connectToTestSQLDB()

    // 初始化測試用的 handler 和 session
    testHandler = MockInputHandler(lm: testLM, pref: PrefMgr())
    testSession = MockSession()
    testSession.inputHandler = testHandler
    testHandler.session = testSession
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
    // 簡化的打字模擬，直接操作 composer 和 assembler
    for char in sequence {
      let charStr = String(char)
      if charStr == " " {
        // 空格表示組字
        testHandler.assemble()
      } else {
        // 其他字符塞入 composer
        _ = testHandler.composer.receiveKey(fromString: charStr)
      }
    }
  }

  // MARK: - Test Cases

  /// 測試 InputHandler 基本初始化。
  func test101_InputHandler_Initialization() throws {
    vCTestLog("測試 InputHandler 初始化")
    
    // 測試基本初始化
    XCTAssertNotNil(testHandler)
    XCTAssertNotNil(testHandler.composer)
    XCTAssertNotNil(testHandler.assembler)
    XCTAssertTrue(testHandler.assembler.isEmpty)
    
    vCTestLog("InputHandler 初始化成功")
  }

  /// 測試注拼槽基本功能。
  func test103_InputHandler_ComposerBasics() throws {
    vCTestLog("測試注拼槽基本功能")
    
    testHandler.clear()
    XCTAssertTrue(testHandler.composer.isEmpty)
    
    // 測試接收單個按鍵
    testHandler.composer.receiveKey(fromString: "e")
    XCTAssertFalse(testHandler.composer.isEmpty)
    
    testHandler.clear()
    XCTAssertTrue(testHandler.composer.isEmpty)
    
    vCTestLog("成功完成注拼槽基本功能測試")
  }

  /// 測試組字器基本功能。
  func test106_InputHandler_AssemblerBasics() throws {
    vCTestLog("測試組字器基本功能")
    
    testHandler.clear()
    XCTAssertTrue(testHandler.assembler.isEmpty)
    
    // 測試組字器的基本屬性
    XCTAssertEqual(testHandler.assembler.cursor, 0)
    XCTAssertEqual(testHandler.assembler.length, 0)
    
    vCTestLog("成功完成組字器基本功能測試")
  }
}
