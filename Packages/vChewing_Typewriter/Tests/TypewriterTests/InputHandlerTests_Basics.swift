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
import Shared
@testable import Typewriter
import XCTest

func vCTestLog(_ str: String) {
  print("[VCLOG] \(str)")
}

// MARK: - 測試用 KBEvent 按鍵實例

extension KBEvent.KeyEventData {
  static let dataArrowHome = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.home.unicodeScalar.description,
    keyCode: KeyCode.kHome.rawValue
  )
  static let dataArrowEnd = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.end.unicodeScalar.description,
    keyCode: KeyCode.kEnd.rawValue
  )
  static let dataArrowLeft = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.leftArrow.unicodeScalar.description,
    keyCode: KeyCode.kLeftArrow.rawValue
  )
  static let dataArrowRight = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.rightArrow.unicodeScalar.description,
    keyCode: KeyCode.kRightArrow.rawValue
  )
  static let dataArrowDown = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.downArrow.unicodeScalar.description,
    keyCode: KeyCode.kDownArrow.rawValue
  )
  static let dataEnterReturn = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.carriageReturn.unicodeScalar.description,
    keyCode: KeyCode.kLineFeed.rawValue
  )
  static let dataTab = KBEvent.KeyEventData(
    chars: KBEvent.SpecialKey.tab.unicodeScalar.description,
    keyCode: KeyCode.kTab.rawValue
  )
}

extension KBEvent {
  public struct KeyEventData {
    // MARK: Lifecycle

    public init(
      type: EventType = .keyDown,
      flags: ModifierFlags = [],
      chars: String,
      charsSansModifiers: String? = nil,
      keyCode: UInt16? = nil
    ) {
      self.type = type
      self.flags = flags
      self.chars = chars
      self.charsSansModifiers = charsSansModifiers ?? chars
      self.keyCode = keyCode ?? mapKeyCodesANSIForTests[chars] ?? 65_535
    }

    // MARK: Public

    public var type: EventType = .keyDown
    public var flags: ModifierFlags
    public var chars: String
    public var charsSansModifiers: String
    public var keyCode: UInt16

    public var asPairedEvents: [KBEvent] {
      KBEvent.keyEvents(data: self, paired: true)
    }

    public var asEvent: KBEvent {
      KBEvent.keyEvent(data: self)
    }

    public func toEvents(paired: Bool = false) -> [KBEvent] {
      KBEvent.keyEvents(data: self, paired: paired)
    }
  }

  public static func keyEvents(data: KeyEventData, paired: Bool = false) -> [KBEvent] {
    var resultArray = [KBEvent]()
    let eventA: KBEvent = Self.keyEvent(data: data)
    resultArray.append(eventA)
    if paired, eventA.type == .keyDown {
      let eventB = eventA.reinitiate(
        with: .keyUp,
        characters: nil,
        charactersIgnoringModifiers: nil
      )
      resultArray.append(eventB)
    }
    return resultArray
  }

  public static func keyEvent(data: KeyEventData) -> KBEvent {
    Self.keyEventSimple(
      type: data.type,
      flags: data.flags,
      chars: data.chars,
      charsSansModifiers: data.charsSansModifiers,
      keyCode: data.keyCode
    )
  }

  public static func keyEventSimple(
    type: EventType,
    flags: ModifierFlags,
    chars: String,
    charsSansModifiers: String? = nil,
    keyCode: UInt16
  )
    -> KBEvent {
    KBEvent(
      with: type,
      modifierFlags: flags,
      timestamp: .init(),
      windowNumber: 0,
      characters: chars,
      charactersIgnoringModifiers: charsSansModifiers ?? chars,
      isARepeat: false,
      keyCode: keyCode
    )
  }
}

// MARK: - 測試用鍵碼對照

/// ANSI 鍵盤字符到 KeyCode 的映射表（用於測試）
let mapKeyCodesANSIForTests: [String: UInt16] = [
  "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29, "-": 27,
  "=": 24, "q": 12, "w": 13, "e": 14, "r": 15, "t": 17, "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
  "[": 33, "]": 30, "\\": 42, "a": 0, "s": 1, "d": 2, "f": 3, "g": 5, "h": 4, "j": 38, "k": 40,
  "l": 37, ";": 41, "'": 39, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "n": 45, "m": 46, ",": 43,
  ".": 47, "/": 44, " ": 49,
]

let cassetteURL4Array30CIN2 = URL(fileURLWithPath: #file)
  .deletingLastPathComponent() // TypewriterTests 資料夾
  .deletingLastPathComponent() // Tests 資料夾
  .deletingLastPathComponent() // vChewing_Typewriter 專案資料夾
  .deletingLastPathComponent() // Packages 根目錄
  .appendingPathComponent("vChewing_LangModelAssembly")
  .appendingPathComponent("Tests")
  .appendingPathComponent("TestCINData")
  .appendingPathComponent("array30.cin2")

// MARK: - InputHandlerTests

/// 威注音輸入法的 InputHandler 單元測試（Typewriter 模組）
class InputHandlerTests: XCTestCase {
  var testLM: LMAssembly.LMInstantiator?
  var testHandler: MockInputHandler?
  var testSession: MockSession?

  // MARK: - 測試前後流程

  override func setUpWithError() throws {
    // 設定專用於單元測試的 UserDefaults
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true

    // 初始化測試 LM
    let lm = LMAssembly.LMInstantiator(isCHS: false)
    testLM = lm
    LMAssembly.LMInstantiator.connectToTestSQLDB(sqlTestCoreLMData)

    // 初始化測試用的 handler 和 session
    let handler = MockInputHandler(lm: lm, pref: PrefMgr())
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    testHandler = handler
    testSession = session
  }

  override func tearDownWithError() throws {
    testHandler?.errorCallback = nil
    testSession?.switchState(MockIMEState.ofAbortion())
    LMAssembly.resetSharedState()
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.UnitTests")
    UserDef.resetAll()
  }

  // MARK: - 工具函式

  func clearTestPOM() {
    testHandler?.currentLM.clearPOMData()
  }

  func typeSentence(_ sequence: String) {
    // 此處刻意跳過 KeyUp，因為 InputHandler 不處理 KeyUp。
    // 如果要做與 KeyUp 有關的測試的話，需在 MainAssemblyTests 進行。
    guard let testHandler, let testSession else { return }
    // 使用 KBEvent 模擬輸入，類似 MainAssembly 的 typeSentenceOrCandidates
    // 這樣可以正確處理注音、磁帶等各種輸入模式。
    let isCandidateContainer = testSession.state.isCandidateContainer
    let stateType = testSession.state.type
    if !(
      [.ofEmpty, .ofInputting].contains(stateType) || isCandidateContainer
    ) { return }

    // 為每個字符建立 KBEvent（按下事件）
    let typingSequence: [KBEvent] = sequence.map { charRAW in
      var finalArray = [KBEvent]()
      let char = charRAW.description
      let keyEventData = KBEvent.KeyEventData(chars: char)
      finalArray.append(keyEventData.asEvent)
      return finalArray
    }.flatMap { $0 }

    // 處理每個 keyDown 事件。
    typingSequence.forEach { event in
      _ = testHandler.triageInput(event: event)
    }
  }

  func generateDisplayedText() -> String {
    guard let testHandler else { return "" }
    return testHandler.assembler.assembledSentence.values.joined()
  }
}
