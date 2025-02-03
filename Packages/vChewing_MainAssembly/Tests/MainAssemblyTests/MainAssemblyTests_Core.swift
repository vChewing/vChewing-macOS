// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import LangModelAssembly
@testable import MainAssembly
import OSFrameworkImpl
import Shared
import XCTest

let testClient = FakeClient()

extension SessionCtl {
  public override func client() -> (IMKTextInput & NSObjectProtocol)! { testClient }
}

func vCTestLog(_ str: String) {
  print("[VCLOG] \(str)")
}

// MARK: - MainAssemblyTests

/// 威注音輸入法的控制模組單元測試。
/// - Remark: 歡迎來到威注音輸入法的控制模組單元測試。
///
/// 不似其他同類產品的單元測試，威注音輸入法的單元測試
/// 會盡量模擬使用者的日常打字擊鍵行為與使用方法。
/// 單元測試的內容可能算不上豐富，但會隨著今後來自各位
/// 使用者所提報的故障、而繼續逐漸擴大測試範圍。
///
/// 該單元測試使用獨立的語彙資料，因此會在選字時的候選字
/// 順序等方面與威注音輸入法實際使用時的體驗有差異。
class MainAssemblyTests: XCTestCase {
  static let testServer = IMKServer(
    name: "org.atelierInmu.vChewing.MainAssembly.UnitTests_Connection",
    bundleIdentifier: "org.atelierInmu.vChewing.MainAssembly.UnitTests"
  )

  static var _testHandler: InputHandler?
  static var _testSession: InputSession?

  var testLM = LMAssembly.LMInstantiator.construct { _ in
    LMAssembly.LMInstantiator.connectToTestSQLDB()
  }

  // MARK: - Utilities

  let dataArrowLeft = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  let dataArrowDown = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.downArrow.unicodeScalar.description,
    keyCode: KeyCode.kDownArrow.rawValue
  )
  let dataEnterReturn = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.carriageReturn.unicodeScalar.description,
    keyCode: KeyCode.kLineFeed.rawValue
  )
  let dataTab = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.tab.unicodeScalar.description,
    keyCode: KeyCode.kTab.rawValue
  )

  var testHandler: InputHandler {
    let result = Self._testHandler ?? InputHandler(lm: testLM, pref: PrefMgr.shared)
    if Self._testHandler == nil { Self._testHandler = result }
    return result
  }

  var testSession: InputSession {
    let session = Self._testSession ?? InputSession(
      controller: nil,
      client: testClient
    )
    if Self._testSession == nil { Self._testSession = session }
    return session
  }

  // MARK: - Preparing Unit Tests.

  override func setUpWithError() throws {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true
    testSession.activateServer(testClient)
    testSession.isActivated = true
    testSession.inputHandler = testHandler
    testHandler.session = testSession
    LMMgr.syncLMPrefs()
    testClient.clear()
  }

  override func tearDownWithError() throws {
    testSession.switchState(IMEState.ofAbortion())
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDef.resetAll()
    testClient.clear()
    testSession.deactivateServer(testClient)
  }

  func clearTestUOM() {
    testLM.clearUOMData()
  }

  func typeSentenceOrCandidates(_ sequence: String) {
    if !(
      [.ofEmpty, .ofInputting].contains(testSession.state.type) || testSession.state
        .isCandidateContainer
    ) { return }
    let typingSequence: [NSEvent] = sequence.compactMap { charRAW in
      var finalArray = [NSEvent]()
      let char = charRAW.description
      let keyEventData = NSEvent.KeyEventData(chars: char)
      finalArray.append(contentsOf: keyEventData.asPairedEvents)
      return finalArray
    }.flatMap { $0 }
    typingSequence.forEach { theEvent in
      let dismissed = !testSession.handleNSEvent(theEvent, client: testClient)
      if theEvent.type == .keyDown { XCTAssertFalse(dismissed) }
    }
  }
}

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
