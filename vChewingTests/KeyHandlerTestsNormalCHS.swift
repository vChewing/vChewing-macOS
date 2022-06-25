// Copyright (c) 2021 and onwards Zonble Yang (MIT-NTL License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest

@testable import vChewing

func charCode(_ string: String) -> UInt16 {
  let scalars = string.unicodeScalars
  return UInt16(scalars[scalars.startIndex].value)
}

class KeyHandlerTestsNormalCHS: XCTestCase {
  func reset() {
    mgrPrefs.allKeys.forEach {
      UserDefaults.standard.removeObject(forKey: $0)
    }
  }

  func makeSnapshot() -> [String: Any] {
    var dict = [String: Any]()
    mgrPrefs.allKeys.forEach {
      dict[$0] = UserDefaults.standard.object(forKey: $0)
    }
    return dict
  }

  func restore(from snapshot: [String: Any]) {
    mgrPrefs.allKeys.forEach {
      UserDefaults.standard.set(snapshot[$0], forKey: $0)
    }
  }

  var snapshot: [String: Any]?

  var handler = KeyHandler()

  override func setUpWithError() throws {
    snapshot = makeSnapshot()
    reset()
    mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ABC"
    mgrPrefs.mandarinParser = 0
    mgrPrefs.useSCPCTypingMode = false
    mgrLangModel.loadDataModel(.imeModeCHS)
    handler = KeyHandler()
    handler.inputMode = .imeModeCHS
  }

  override func tearDownWithError() throws {
    if let snapshot = snapshot {
      restore(from: snapshot)
    }
  }

  func testIgnoreEmpty() {
    let input = InputSignal(inputText: "", keyCode: 0, charCode: 0, flags: [], isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreEnterCR() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kCarriageReturn.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreEnterLF() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLineFeed.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreUp() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kUpArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result, "\(state)")
  }

  func testIgnoreDown() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kDownArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result, "\(state)")
  }

  func testIgnoreLeft() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreRight() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnorePageUp() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kPageUp.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnorePageDown() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kPageDown.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreHome() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kHome.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreEnd() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kEnd.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreDelete() {
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kWindowsDelete.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreCommand() {
    let input = InputSignal(inputText: "A", keyCode: 0, charCode: 0, flags: .command, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreOption() {
    let input = InputSignal(inputText: "A", keyCode: 0, charCode: 0, flags: .option, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreNumericPad() {
    let input = InputSignal(inputText: "A", keyCode: 0, charCode: 0, flags: .numericPad, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testIgnoreCapslock() {
    let input = InputSignal(inputText: "A", keyCode: 0, charCode: 0, flags: .capsLock, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    let result = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertFalse(result)
  }

  func testCapslock() {
    var input = InputSignal(inputText: "b", keyCode: 0, charCode: charCode("b"), flags: [], isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    var count = 0

    input = InputSignal(inputText: "a", keyCode: 0, charCode: charCode("a"), flags: .capsLock, isVerticalTyping: false)
    _ = handler.handle(input: input, state: state) { newState in
      if count == 1 {
        state = newState
      }
      count += 1
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Committing, "\(state)")
  }

  func testCapslockShift() {
    var input = InputSignal(inputText: "b", keyCode: 0, charCode: charCode("b"), flags: [], isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    input = InputSignal(
      inputText: "a", keyCode: 0, charCode: charCode("a"), flags: [.capsLock, .shift], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Empty, "\(state)")
  }

  func testisNumericPad() {
    var input = InputSignal(inputText: "b", keyCode: 0, charCode: charCode("b"), flags: [], isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    input = InputSignal(
      inputText: "1", keyCode: 0, charCode: charCode("1"), flags: .numericPad, isVerticalTyping: false
    )
    var count = 0
    var empty: InputStateProtocol = InputState.Empty()
    var target: InputStateProtocol = InputState.Committing()
    _ = handler.handle(input: input, state: state) { newState in
      switch count {
        case 0:
          state = newState
        case 1:
          target = newState
        case 2:
          empty = newState
        default:
          break
      }
      count += 1

    } errorCallback: {
    }
    XCTAssertEqual(count, 3)
    XCTAssertTrue(state is InputState.Empty, "\(state)")
    XCTAssertTrue(empty is InputState.Empty, "\(empty)")
    XCTAssertTrue(target is InputState.Committing, "\(target)")
    if let state = target as? InputState.Committing {
      XCTAssertEqual(state.textToCommit, "1")
    }
  }

  func testPunctuationTable1() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kSymbolMenuPhysicalKey.rawValue, charCode: 0, flags: [],
      isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testPunctuationTable2() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kSymbolMenuPhysicalKey.rawValue, charCode: 0, flags: .option,
      isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertTrue(state.candidates.contains("！"))
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testIgnorePunctuationTable() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    var state: InputStateProtocol = InputState.Empty()
    var input = InputSignal(inputText: "1", keyCode: 0, charCode: charCode("1"), flags: .shift, isVerticalTyping: false)
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    input = InputSignal(inputText: "`", keyCode: 0, charCode: charCode("`"), flags: .shift, isVerticalTyping: false)
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄅ")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testHalfPunctuationComma() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = true
    let input = InputSignal(inputText: "<", keyCode: 0, charCode: charCode("<"), flags: .shift, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, ",")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testPunctuationComma() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    let input = InputSignal(inputText: "<", keyCode: 0, charCode: charCode("<"), flags: .shift, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "，")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testHalfPunctuationPeriod() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = true
    let input = InputSignal(inputText: ">", keyCode: 0, charCode: charCode(">"), flags: .shift, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, ".")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testPunctuationPeriod() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false

    let input = InputSignal(inputText: ">", keyCode: 0, charCode: charCode(">"), flags: .shift, isVerticalTyping: false)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "。")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testCtrlPunctuationPeriod() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false

    let input = InputSignal(
      inputText: ".", keyCode: 0, charCode: charCode("."), flags: .control, isVerticalTyping: false
    )
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "。")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testInvalidBpmf() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("eul4").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
  }

  func testInputting() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("18 m,45j/ fu. g0 xup6xu;6").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "八月中秋山林凉")
    }
  }

  func testInputtingNihao() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
    }
  }

  func testInputtingTianKong() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("wu0 dj/ ").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "天空")
    }
  }

  func testCommittingNihao() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
    }

    let enter = InputSignal(
      inputText: " ", keyCode: KeyCode.kCarriageReturn.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var committing: InputStateProtocol = InputState.Committing()
    var empty: InputStateProtocol = InputState.Empty()
    var count = 0

    _ = handler.handle(input: enter, state: state) { newState in
      switch count {
        case 0:
          committing = newState
        case 1:
          empty = newState
        default:
          break
      }
      count += 1
    } errorCallback: {
    }

    XCTAssertTrue(committing is InputState.Committing, "\(state)")
    if let committing = committing as? InputState.Committing {
      XCTAssertEqual(committing.textToCommit, "你好")
    }
    XCTAssertTrue(empty is InputState.Empty, "\(state)")
  }

  func testDelete() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let left = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    let delete = InputSignal(
      inputText: " ", keyCode: KeyCode.kWindowsDelete.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var errorCalled = false

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: delete, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: delete, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }
    XCTAssertTrue(errorCalled)

    errorCalled = false

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 0)
    }

    _ = handler.handle(input: delete, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
  }

  func testBackspaceToDeleteReading() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let backspace = InputSignal(
      inputText: " ", keyCode: KeyCode.kBackSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋ")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
  }

  func testBackspaceAtBegin() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let left = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
    }

    let backspace = InputSignal(
      inputText: " ", keyCode: KeyCode.kBackSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var errorCall = false
    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCall = true
    }
    XCTAssertTrue(errorCall)
  }

  func testBackspaceToDeleteReadingWithText() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let backspace = InputSignal(
      inputText: " ", keyCode: KeyCode.kBackSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏ")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }
  }

  func testBackspace() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let backspace = InputSignal(
      inputText: " ", keyCode: KeyCode.kBackSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: backspace, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
  }

  func testCursorWithReading() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    let left = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    let right = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var leftErrorCalled = false
    var rightErrorCalled = false

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
      leftErrorCalled = true
    }

    _ = handler.handle(input: right, state: state) { newState in
      state = newState
    } errorCallback: {
      rightErrorCalled = true
    }

    XCTAssertTrue(leftErrorCalled)
    XCTAssertTrue(rightErrorCalled)
  }

  func testCursor() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let left = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    let right = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )

    var errorCalled = false

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
    }

    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
    }
    XCTAssertTrue(errorCalled)

    _ = handler.handle(input: right, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    _ = handler.handle(input: right, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    errorCalled = false
    _ = handler.handle(input: right, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }
    XCTAssertTrue(errorCalled)
  }

  func testCandidateWithDown() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    let down = InputSignal(
      inputText: " ", keyCode: KeyCode.kDownArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: down, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
      let candidates = state.candidates
      XCTAssertTrue(candidates.contains("你"))
    }
  }

  func testCandidateWithSpace() {
    let enabled = mgrPrefs.chooseCandidateUsingSpace
    mgrPrefs.chooseCandidateUsingSpace = true
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }

    let space = InputSignal(
      inputText: " ", keyCode: KeyCode.kSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: space, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
      let candidates = state.candidates
      XCTAssertTrue(candidates.contains("你"))
    }
    mgrPrefs.chooseCandidateUsingSpace = enabled
  }

  func testInputSpace() {
    let enabled = mgrPrefs.chooseCandidateUsingSpace
    mgrPrefs.chooseCandidateUsingSpace = false
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: InputState.Empty()) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting)
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")

      var count = 0
      var target: InputStateProtocol = InputState.Committing()
      var empty: InputStateProtocol = InputState.Empty()
      var state: InputStateProtocol = state
      let input = InputSignal(
        inputText: " ", keyCode: KeyCode.kSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
      )
      _ = handler.handle(input: input, state: state) { newState in
        switch count {
          case 0:
            if let newState = newState as? InputState.Committing {
              state = newState
            }
          case 1:
            target = newState
          case 2:
            empty = newState
          default:
            break
        }
        count += 1
      } errorCallback: {
      }

      XCTAssertEqual(count, 3)
      XCTAssertTrue(state is InputState.Committing, "\(state)")
      if let state = state as? InputState.Committing {
        XCTAssertEqual(state.textToCommit, "你")
      }
      XCTAssertTrue(target is InputState.Committing)
      if let target = target as? InputState.Committing {
        XCTAssertEqual(target.textToCommit, " ")
      }
      XCTAssertTrue(empty is InputState.Empty)
    }
    mgrPrefs.chooseCandidateUsingSpace = enabled
  }

  func testInputSpaceInBetween() {
    let enabled = mgrPrefs.chooseCandidateUsingSpace
    mgrPrefs.chooseCandidateUsingSpace = false
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
    }

    var input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    input = InputSignal(
      inputText: " ", keyCode: KeyCode.kSpace.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你 好")
    }
    mgrPrefs.chooseCandidateUsingSpace = enabled
  }

  func testHomeAndEnd() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let home = InputSignal(
      inputText: " ", keyCode: KeyCode.kHome.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    let end = InputSignal(
      inputText: " ", keyCode: KeyCode.kEnd.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )

    _ = handler.handle(input: home, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
    }

    var homeErrorCalled = false
    _ = handler.handle(input: home, state: state) { newState in
      state = newState
    } errorCallback: {
      homeErrorCalled = true
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
    }
    XCTAssertTrue(homeErrorCalled)

    _ = handler.handle(input: end, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    var endErrorCalled = false
    _ = handler.handle(input: end, state: state) { newState in
      state = newState
    } errorCallback: {
      endErrorCalled = true
    }

    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }
    XCTAssertTrue(endErrorCalled)
  }

  func testHomeAndEndWithReading() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏㄠ")
      XCTAssertEqual(state.cursorIndex, 3)
    }

    let home = InputSignal(
      inputText: " ", keyCode: KeyCode.kHome.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    let end = InputSignal(
      inputText: " ", keyCode: KeyCode.kEnd.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    var homeErrorCalled = false
    var endErrorCalled = false

    _ = handler.handle(input: home, state: state) { newState in
      state = newState
    } errorCallback: {
      homeErrorCalled = true
    }

    XCTAssertTrue(homeErrorCalled)
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏㄠ")
      XCTAssertEqual(state.cursorIndex, 3)
    }

    _ = handler.handle(input: end, state: state) { newState in
      state = newState
    } errorCallback: {
      endErrorCalled = true
    }

    XCTAssertTrue(endErrorCalled)
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏㄠ")
      XCTAssertEqual(state.cursorIndex, 3)
    }
  }

  func testMarkingLeftAtBegin() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    var errorCalled = false

    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }
    XCTAssertTrue(errorCalled)
  }

  func testMarkingRightAtEnd() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    var errorCalled = false
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }
    XCTAssertTrue(errorCalled)
  }

  func testMarkingLeft() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    var input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Marking, "\(state)")
    if let state = state as? InputState.Marking {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
      XCTAssertEqual(state.markerIndex, 1)
      XCTAssertEqual(state.markedRange, 1..<2)
    }

    input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Marking, "\(state)")
    if let state = state as? InputState.Marking {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
      XCTAssertEqual(state.markerIndex, 0)
      XCTAssertEqual(state.markedRange, 0..<2)
    }

    var stateForGoingRight: InputStateProtocol = state

    let right = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    _ = handler.handle(input: right, state: stateForGoingRight) { newState in
      stateForGoingRight = newState
    } errorCallback: {
    }
    _ = handler.handle(input: right, state: stateForGoingRight) { newState in
      stateForGoingRight = newState
    } errorCallback: {
    }

    XCTAssertTrue(stateForGoingRight is InputState.Inputting, "\(stateForGoingRight)")
  }

  func testMarkingRight() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let left = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    _ = handler.handle(input: left, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    let errorInput = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    var errorCalled = false
    _ = handler.handle(input: errorInput, state: state) { newState in
      state = newState
    } errorCallback: {
      errorCalled = true
    }
    XCTAssertTrue(errorCalled)

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kRightArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Marking, "\(state)")
    if let state = state as? InputState.Marking {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
      XCTAssertEqual(state.markerIndex, 1)
      XCTAssertEqual(state.markedRange, 0..<1)
    }

    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Marking, "\(state)")
    if let state = state as? InputState.Marking {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 0)
      XCTAssertEqual(state.markerIndex, 2)
      XCTAssertEqual(state.markedRange, 0..<2)
    }

    var stateForGoingLeft: InputStateProtocol = state

    _ = handler.handle(input: left, state: stateForGoingLeft) { newState in
      stateForGoingLeft = newState
    } errorCallback: {
    }
    _ = handler.handle(input: left, state: stateForGoingLeft) { newState in
      stateForGoingLeft = newState
    } errorCallback: {
    }

    XCTAssertTrue(stateForGoingLeft is InputState.Inputting, "\(stateForGoingLeft)")
  }

  func testCancelMarking() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl3").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    var input = InputSignal(
      inputText: " ", keyCode: KeyCode.kLeftArrow.rawValue, charCode: 0, flags: .shift, isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Marking, "\(state)")
    if let state = state as? InputState.Marking {
      XCTAssertEqual(state.composingBuffer, "你好")
      XCTAssertEqual(state.cursorIndex, 2)
      XCTAssertEqual(state.markerIndex, 1)
      XCTAssertEqual(state.markedRange, 1..<2)
    }

    input = InputSignal(inputText: "1", keyCode: 0, charCode: charCode("1"), flags: [], isVerticalTyping: false)
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你好ㄅ")
    }
  }

  func testEscToClearReadingAndGoToEmpty() {
    let enabled = mgrPrefs.escToCleanInputBuffer
    mgrPrefs.escToCleanInputBuffer = false
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋㄧ")
      XCTAssertEqual(state.cursorIndex, 2)
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kEscape.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
    mgrPrefs.escToCleanInputBuffer = enabled
  }

  func testEscToClearReadingAndGoToInputting() {
    let enabled = mgrPrefs.escToCleanInputBuffer
    mgrPrefs.escToCleanInputBuffer = false
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏㄠ")
      XCTAssertEqual(state.cursorIndex, 3)
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kEscape.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你")
      XCTAssertEqual(state.cursorIndex, 1)
    }
    mgrPrefs.escToCleanInputBuffer = enabled
  }

  func testEscToClearAll() {
    let enabled = mgrPrefs.escToCleanInputBuffer
    mgrPrefs.escToCleanInputBuffer = true
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3cl").map {
      String($0)
    }
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [], isVerticalTyping: false)
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "你ㄏㄠ")
      XCTAssertEqual(state.cursorIndex, 3)
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kEscape.rawValue, charCode: 0, flags: [], isVerticalTyping: false
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.EmptyIgnoringPreviousState, "\(state)")
    mgrPrefs.escToCleanInputBuffer = enabled
  }
}
