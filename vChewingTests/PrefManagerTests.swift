// Copyright (c) 2021 and onwards Zonble Yang (MIT-NTL License).
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

class PrefManagerTests: XCTestCase {
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

  override func setUpWithError() throws {
    snapshot = makeSnapshot()
    reset()
  }

  override func tearDownWithError() throws {
    if let snapshot = snapshot {
      restore(from: snapshot)
    }
  }

  func testMandarinParser() {
    XCTAssert(mgrPrefs.mandarinParser == 0)
    mgrPrefs.mandarinParser = 1
    XCTAssert(mgrPrefs.mandarinParser == 1)
  }

  func testMandarinParserName() {
    XCTAssert(mgrPrefs.mandarinParserName == "Standard")
    mgrPrefs.mandarinParser = 1
    XCTAssert(mgrPrefs.mandarinParserName == "ETen")
  }

  func testBasisKeyboardLayoutPreferenceKey() {
    XCTAssert(mgrPrefs.basicKeyboardLayout == "com.apple.keylayout.ZhuyinBopomofo")
    mgrPrefs.basicKeyboardLayout = "com.apple.keylayout.ABC"
    XCTAssert(mgrPrefs.basicKeyboardLayout == "com.apple.keylayout.ABC")
  }

  func testCandidateTextSize() {
    XCTAssert(mgrPrefs.candidateListTextSize == 18)

    mgrPrefs.candidateListTextSize = 16
    XCTAssert(mgrPrefs.candidateListTextSize == 16)

    mgrPrefs.candidateListTextSize = 11
    XCTAssert(mgrPrefs.candidateListTextSize == 12)
    mgrPrefs.candidateListTextSize = 197
    XCTAssert(mgrPrefs.candidateListTextSize == 196)

    mgrPrefs.candidateListTextSize = 12
    XCTAssert(mgrPrefs.candidateListTextSize == 12)
    mgrPrefs.candidateListTextSize = 196
    XCTAssert(mgrPrefs.candidateListTextSize == 196)

    mgrPrefs.candidateListTextSize = 13
    XCTAssert(mgrPrefs.candidateListTextSize == 13)
    mgrPrefs.candidateListTextSize = 195
    XCTAssert(mgrPrefs.candidateListTextSize == 195)
  }

  func testUseRearCursorMode() {
    XCTAssert(mgrPrefs.useRearCursorMode == false)
    mgrPrefs.useRearCursorMode = true
    XCTAssert(mgrPrefs.useRearCursorMode == true)
  }

  func testUseHorizontalCandidateList() {
    XCTAssert(mgrPrefs.useHorizontalCandidateList == true)
    mgrPrefs.useHorizontalCandidateList = false
    XCTAssert(mgrPrefs.useHorizontalCandidateList == false)
  }

  func testComposingBufferSize() {
    XCTAssert(mgrPrefs.composingBufferSize == 20)
    mgrPrefs.composingBufferSize = 10
    XCTAssert(mgrPrefs.composingBufferSize == 10)
    mgrPrefs.composingBufferSize = 4
    XCTAssert(mgrPrefs.composingBufferSize == 10)
    mgrPrefs.composingBufferSize = 50
    XCTAssert(mgrPrefs.composingBufferSize == 40)
  }

  func testChooseCandidateUsingSpace() {
    XCTAssert(mgrPrefs.chooseCandidateUsingSpace == true)
    mgrPrefs.chooseCandidateUsingSpace = false
    XCTAssert(mgrPrefs.chooseCandidateUsingSpace == false)
  }

  func testChineseConversionEnabled() {
    XCTAssert(mgrPrefs.chineseConversionEnabled == false)
    mgrPrefs.chineseConversionEnabled = true
    XCTAssert(mgrPrefs.chineseConversionEnabled == true)
    _ = mgrPrefs.toggleChineseConversionEnabled()
    XCTAssert(mgrPrefs.chineseConversionEnabled == false)
  }

  func testHalfWidthPunctuationEnabled() {
    XCTAssert(mgrPrefs.halfWidthPunctuationEnabled == false)
    mgrPrefs.halfWidthPunctuationEnabled = true
    XCTAssert(mgrPrefs.halfWidthPunctuationEnabled == true)
    _ = mgrPrefs.toggleHalfWidthPunctuationEnabled()
    XCTAssert(mgrPrefs.halfWidthPunctuationEnabled == false)
  }

  func testEscToCleanInputBuffer() {
    XCTAssert(mgrPrefs.escToCleanInputBuffer == true)
    mgrPrefs.escToCleanInputBuffer = false
    XCTAssert(mgrPrefs.escToCleanInputBuffer == false)
  }

  func testCandidateTextFontName() {
    XCTAssert(mgrPrefs.candidateTextFontName == nil)
    mgrPrefs.candidateTextFontName = "Helvetica"
    XCTAssert(mgrPrefs.candidateTextFontName == "Helvetica")
  }

  func testCandidateKeyLabelFontName() {
    XCTAssert(mgrPrefs.candidateKeyLabelFontName == nil)
    mgrPrefs.candidateKeyLabelFontName = "Helvetica"
    XCTAssert(mgrPrefs.candidateKeyLabelFontName == "Helvetica")
  }

  func testCandidateKeys() {
    XCTAssert(mgrPrefs.candidateKeys == mgrPrefs.defaultCandidateKeys)
    mgrPrefs.candidateKeys = "abcd"
    XCTAssert(mgrPrefs.candidateKeys == "abcd")
  }

  func testPhraseReplacementEnabledKey() {
    XCTAssert(mgrPrefs.phraseReplacementEnabled == false)
    mgrPrefs.phraseReplacementEnabled = true
    XCTAssert(mgrPrefs.phraseReplacementEnabled == true)
  }
}

class CandidateKeyValidationTests: XCTestCase {
  func testEmpty() {
    do {
      try mgrPrefs.validate(candidateKeys: "")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.empty {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testSpaces() {
    do {
      try mgrPrefs.validate(candidateKeys: "    ")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.empty {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testInvalidKeys() {
    do {
      try mgrPrefs.validate(candidateKeys: "中文字元")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.invalidCharacters {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testInvalidLatinLetters() {
    do {
      try mgrPrefs.validate(candidateKeys: "üåçøöacpo")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.invalidCharacters {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testSpaceInBetween() {
    do {
      try mgrPrefs.validate(candidateKeys: "1 2 3 4")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.containSpace {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testDuplicatedKeys() {
    do {
      try mgrPrefs.validate(candidateKeys: "aabbccdd")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.duplicatedCharacters {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testTooShort1() {
    do {
      try mgrPrefs.validate(candidateKeys: "abc")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.tooShort {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testTooShort2() {
    do {
      try mgrPrefs.validate(candidateKeys: "abcd")
    } catch {
      XCTFail("Should be safe")
    }
  }

  func testTooLong1() {
    do {
      try mgrPrefs.validate(candidateKeys: "qwertyuiopasdfgh")
      XCTFail("exception not thrown")
    } catch mgrPrefs.CandidateKeyError.tooLong {
    } catch {
      XCTFail("exception not thrown")
    }
  }

  func testTooLong2() {
    do {
      try mgrPrefs.validate(candidateKeys: "qwertyuiopasdfg")
    } catch {
      XCTFail("Should be safe")
    }
  }
}
