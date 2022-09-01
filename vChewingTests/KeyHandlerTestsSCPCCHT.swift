// (c) 2021 and onwards Zonble Yang (MIT-NTL License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import vChewing

class KeyHandlerTestsSCPCCHT: XCTestCase {
  func reset() {
    UserDef.allCases.forEach {
      UserDefaults.standard.removeObject(forKey: $0.rawValue)
    }
  }

  func makeSnapshot() -> [String: Any] {
    var dict = [String: Any]()
    UserDef.allCases.forEach {
      dict[$0.rawValue] = UserDefaults.standard.object(forKey: $0.rawValue)
    }
    return dict
  }

  func restore(from snapshot: [String: Any]) {
    UserDef.allCases.forEach {
      UserDefaults.standard.set(snapshot[$0.rawValue], forKey: $0.rawValue)
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
    mgrPrefs.associatedPhrasesEnabled = false
    mgrLangModel.loadDataModel(.imeModeCHT)
    handler = KeyHandler()
    handler.inputMode = .imeModeCHT
    _ = mgrPrefs.toggleSCPCTypingModeEnabled()
    _ = mgrPrefs.toggleAssociatedPhrasesEnabled()
  }

  override func tearDownWithError() throws {
    if let snapshot = snapshot {
      restore(from: snapshot)
    }
  }

  func testPunctuationTable() {
    let input = InputSignal(
      inputText: "`", keyCode: KeyCode.kSymbolMenuPhysicalKeyIntl.rawValue, charCode: 0, flags: .option
    )
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertTrue(state.candidates.map(\.1).contains("，"))
    }
  }

  func testPunctuationComma() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    let input = InputSignal(inputText: "<", keyCode: 0, charCode: charCode("<"), flags: .shift)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertEqual(state.composingBuffer, "，")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testPunctuationPeriod() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = false
    let input = InputSignal(inputText: ">", keyCode: 0, charCode: charCode(">"), flags: .shift)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertEqual(state.composingBuffer, "。")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testHalfPunctuationPeriod() {
    let enabled = mgrPrefs.halfWidthPunctuationEnabled
    mgrPrefs.halfWidthPunctuationEnabled = true
    let input = InputSignal(inputText: ">", keyCode: 0, charCode: charCode(">"), flags: .shift)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertEqual(state.composingBuffer, ".")
    }
    mgrPrefs.halfWidthPunctuationEnabled = enabled
  }

  func testControlPunctuationPeriod() {
    let input = InputSignal(
      inputText: ".", keyCode: 0, charCode: charCode("."), flags: [.shift, .control]
    )
    var state: InputStateProtocol = InputState.Empty()
    var count = 0
    _ = handler.handle(input: input, state: state) { newState in
      if count == 0 {
        state = newState
      }
      count += 1
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "。")
    }
  }

  func testEnterWithReading() {
    let input = InputSignal(inputText: "s", keyCode: 0, charCode: charCode("s"), flags: .shift)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋ")
    }

    let enter = InputSignal(inputText: " ", keyCode: 0, charCode: 13, flags: [])
    var count = 0

    _ = handler.handle(input: enter, state: state) { newState in
      if count == 0 {
        state = newState
      }
      count += 1
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋ")
    }
  }

  func testInputNe() {
    let input = InputSignal(inputText: "s", keyCode: 0, charCode: charCode("s"), flags: .shift)
    var state: InputStateProtocol = InputState.Empty()
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋ")
    }
  }

  func testInputNi() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    XCTAssertTrue(state is InputState.Inputting, "\(state)")
    if let state = state as? InputState.Inputting {
      XCTAssertEqual(state.composingBuffer, "ㄋㄧ")
    }
  }

  func testInputNi3() {
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    XCTAssertTrue(state is InputState.ChoosingCandidate, "\(state)")
    if let state = state as? InputState.ChoosingCandidate {
      XCTAssertTrue(state.candidates.map(\.1).contains("你"))
    }
  }

  // TODO: Further bug-hunting needed.
  func testCancelCandidateUsingDelete() {
    mgrPrefs.useSCPCTypingMode = true
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let input = InputSignal(
      inputText: " ", keyCode: KeyCode.kWindowsDelete.rawValue, charCode: charCode(" "), flags: []
    )
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    print("Expecting EmptyIgnoringPreviousState.")
    print("\(state)")
    // XCTAssertTrue(state is InputState.Empty, "\(state)")
  }

  // TODO: Further bug-hunting needed.
  func testCancelCandidateUsingEsc() {
    mgrPrefs.useSCPCTypingMode = true
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("su3").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }

    let input = InputSignal(inputText: " ", keyCode: KeyCode.kEscape.rawValue, charCode: charCode(" "), flags: [])
    _ = handler.handle(input: input, state: state) { newState in
      state = newState
    } errorCallback: {
    }
    print("Expecting EmptyIgnoringPreviousState.")
    print("\(state)")
    // XCTAssertTrue(state is InputState.Empty, "\(state)")
  }

  // TODO: Further bug-hunting needed.
  func testAssociatedPhrases() {
    let enabled = mgrPrefs.associatedPhrasesEnabled
    mgrPrefs.associatedPhrasesEnabled = true
    mgrPrefs.useSCPCTypingMode = true
    handler.forceOpenStringInsteadForAssociatePhrases("二 百五")
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("-41").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState
      } errorCallback: {
      }
    }
    print("Expecting AssociatedPhrases.")
    print("\(state)")
    // XCTAssertTrue(state is InputState.AssociatedPhrases, "\(state)")
    // if let state = state as? InputState.AssociatedPhrases {
    // XCTAssertTrue(state.candidates.map(\.1).contains("百五"))
    // }
    mgrPrefs.associatedPhrasesEnabled = enabled
  }

  func testNoAssociatedPhrases() {
    let enabled = mgrPrefs.associatedPhrasesEnabled
    mgrPrefs.associatedPhrasesEnabled = false
    var state: InputStateProtocol = InputState.Empty()
    let keys = Array("aul ").charComponents
    for key in keys {
      let input = InputSignal(inputText: key, keyCode: 0, charCode: charCode(key), flags: [])
      _ = handler.handle(input: input, state: state) { newState in
        state = newState

      } errorCallback: {
      }
    }

    XCTAssertTrue(state is InputState.Empty, "\(state)")
    mgrPrefs.associatedPhrasesEnabled = enabled
  }
}

// MARK: - StringView Ranges Extension (by Isaac Xen)

extension String {
  fileprivate func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex..<endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}

extension vChewing.LMAssociates {
  public mutating func forceOpenStringInstead(_ strData: String) {
    strData.ranges(splitBy: "\n").filter { !$0.isEmpty }.forEach {
      let neta = strData[$0].split(separator: " ")
      if neta.count >= 2 {
        let theKey = String(neta[0])
        if !theKey.isEmpty, theKey.first != "#" {
          for (i, _) in neta.filter({ $0.first != "#" && !$0.isEmpty }).enumerated() {
            if i == 0 { continue }
            rangeMap[theKey, default: []].append(($0, i))
          }
        }
      }
    }
  }
}

extension vChewing.LMInstantiator {
  public func forceOpenStringInsteadForAssociatePhrases(_ strData: String) {
    lmAssociates.forceOpenStringInstead(strData)
  }
}

extension KeyHandler {
  public func forceOpenStringInsteadForAssociatePhrases(_ strData: String) {
    currentLM.forceOpenStringInsteadForAssociatePhrases(strData + "\n")
  }
}
