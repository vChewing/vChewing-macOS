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
  override public func client() -> (IMKTextInput & NSObjectProtocol)! { testClient }
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
  let backspaceEvent = NSEvent.KeyEventData(
    type: .keyDown,
    chars: NSEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  let escapeEvent = NSEvent.KeyEventData(
    type: .keyDown,
    chars: String(UnicodeScalar(0x1B)!),
    charsSansModifiers: String(UnicodeScalar(0x1B)!),
    keyCode: KeyCode.kEscape.rawValue
  )
  let deleteForwardEvent = NSEvent.KeyEventData(
    type: .keyDown,
    chars: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  let shiftLeftEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: NSEvent.SpecialKey.leftArrow.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  let optionRightEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: NSEvent.SpecialKey.rightArrow.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.rightArrow.unicodeScalar.description,
    keyCode: KeyCode.kRightArrow.rawValue
  )
  let optionShiftRightEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .shift],
    chars: NSEvent.SpecialKey.rightArrow.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.rightArrow.unicodeScalar.description,
    keyCode: KeyCode.kRightArrow.rawValue
  )
  let optionLeftEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: NSEvent.SpecialKey.leftArrow.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  let nextCandidateEvent = NSEvent.KeyEventData(
    type: .keyDown,
    chars: NSEvent.SpecialKey.downArrow.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.downArrow.unicodeScalar.description,
    keyCode: KeyCode.kDownArrow.rawValue
  )
  let optionCommandMinusEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: "-",
    charsSansModifiers: "-",
    keyCode: mapKeyCodesANSIForTests["-"] ?? 27
  )
  let optionCommandEqualEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: "=",
    charsSansModifiers: "=",
    keyCode: mapKeyCodesANSIForTests["="] ?? 24
  )
  let optionCommandDeleteEventPC = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  let optionCommandBackspaceEventPC = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command],
    chars: NSEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  let optionCommandBackspaceEventMacAsDelete = NSEvent.KeyEventData(
    type: .keyDown,
    flags: [.option, .command, .function],
    chars: NSEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  let symbolMenuKeyEventIntlWithOpt = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: #"`"#,
    charsSansModifiers: #"`"#,
    keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue
  )
  let spaceEvent = NSEvent.KeyEventData(
    chars: " ",
    keyCode: KeyCode.kSpace.rawValue
  )
  let pageDownEvent = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.pageDown.unicodeScalar.description,
    keyCode: KeyCode.kPageDown.rawValue
  )
  let tabEvent = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.tab.unicodeScalar.description,
    keyCode: KeyCode.kTab.rawValue
  )
  let homeEvent = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.home.unicodeScalar.description,
    keyCode: KeyCode.kHome.rawValue
  )
  let endEvent = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.end.unicodeScalar.description,
    keyCode: KeyCode.kEnd.rawValue
  )
  let escEvent = NSEvent.KeyEventData(
    chars: String(UnicodeScalar(0x1B)!),
    charsSansModifiers: String(UnicodeScalar(0x1B)!),
    keyCode: KeyCode.kEscape.rawValue
  )
  let optionBackspaceEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: NSEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  let shiftBackspaceEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: NSEvent.SpecialKey.delete.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.delete.unicodeScalar.description,
    keyCode: KeyCode.kBackSpace.rawValue
  )
  let forwardDeleteEvent = NSEvent.KeyEventData(
    chars: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  let optionForwardDeleteEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .option,
    chars: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.deleteForward.unicodeScalar.description,
    keyCode: KeyCode.kWindowsDelete.rawValue
  )
  let shiftEnterEvent = NSEvent.KeyEventData(
    type: .keyDown,
    flags: .shift,
    chars: NSEvent.SpecialKey.enter.unicodeScalar.description,
    charsSansModifiers: NSEvent.SpecialKey.enter.unicodeScalar.description,
    keyCode: KeyCode.kLineFeed.rawValue
  )

  var testHandler: InputHandler {
    let result = Self._testHandler ?? InputHandler(lm: testLM, pref: PrefMgr.shared)
    if Self._testHandler == nil { Self._testHandler = result }
    return result
  }

  var testSession: InputSession {
    let session = Self._testSession ?? InputSession(
      controller: nil
    ) {
      testClient
    }
    if Self._testSession == nil { Self._testSession = session }
    return session
  }

  // MARK: - Preparing Unit Tests.

  override func setUpWithError() throws {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true
    LMMgr.prepareForUnitTests()
    testLM = LMAssembly.LMInstantiator.construct { _ in
      LMAssembly.LMInstantiator.connectToTestSQLDB()
    }
    Self._testHandler = nil
    Self._testSession = nil
    testSession.activateServer(testClient)
    testSession.isActivated = true
    testSession.inputHandler = testHandler
    testHandler.session = testSession
    LMMgr.syncLMPrefs()
    testClient.clear()
  }

  override func tearDownWithError() throws {
    testSession.switchState(IMEState.ofAbortion())
    LMMgr.resetAfterUnitTests()
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDef.resetAll()
    testClient.clear()
    testSession.deactivateServer(testClient)
  }

  func clearTestPOM() {
    testHandler.currentLM.clearPOMData()
  }

  func typeSentenceOrCandidates(_ sequence: String) {
    let isCandidateContainer = testSession.state.isCandidateContainer
    let stateType = testSession.state.type
    if !(
      [.ofEmpty, .ofInputting].contains(stateType) || isCandidateContainer
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

  @discardableResult
  func handleKeyEvent(
    _ data: NSEvent.KeyEventData,
    shouldHandle: Bool = true
  )
    -> Bool {
    var handled = false
    data.asPairedEvents.forEach { event in
      let result = testSession.handleNSEvent(event, client: testClient)
      if event.type == .keyDown {
        if shouldHandle {
          XCTAssertTrue(result, "Expected keyDown to be handled for keyCode \(data.keyCode).")
        } else {
          XCTAssertFalse(result, "Expected keyDown to pass through for keyCode \(data.keyCode).")
        }
        handled = result
      }
    }
    return handled
  }

  func handleEvents(
    _ events: [NSEvent],
    shouldHandle: Bool = true
  ) {
    events.forEach { event in
      let result = testSession.handleNSEvent(event, client: testClient)
      if event.type == .keyDown {
        if shouldHandle {
          XCTAssertTrue(result, "Expected keyDown to be handled for keyCode \(event.keyCode).")
        } else {
          XCTAssertFalse(result, "Expected keyDown to pass through for keyCode \(event.keyCode).")
        }
      }
    }
  }

  @discardableResult
  /// 預設測試序列是「科技蛋糕」。
  func prepareBasicComposition(sequence: String) -> String {
    testHandler.prefs.useSCPCTypingMode = false
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    typeSentenceOrCandidates(sequence)
    if testSession.state.type != .ofInputting {
      testSession.switchState(testHandler.generateStateOfInputting())
    }
    return testSession.state.displayedText
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
