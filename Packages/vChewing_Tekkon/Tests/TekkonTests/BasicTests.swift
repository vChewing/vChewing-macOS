// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import Tekkon

final class TekkonTestsBasic: XCTestCase {
  func testInitializingPhonabet() throws {
    let thePhonabetNull = Tekkon.Phonabet("0")
    let thePhonabetA = Tekkon.Phonabet("ㄉ")
    let thePhonabetB = Tekkon.Phonabet("ㄧ")
    let thePhonabetC = Tekkon.Phonabet("ㄠ")
    let thePhonabetD = Tekkon.Phonabet("ˇ")
    XCTAssert(
      thePhonabetNull.type.rawValue == 0
        && thePhonabetA.type.rawValue == 1
        && thePhonabetB.type.rawValue == 2
        && thePhonabetC.type.rawValue == 3
        && thePhonabetD.type.rawValue == 4
    )
  }

  func testIsValidKeyWithKeys() throws {
    var result = true
    var composer = Tekkon.Composer(arrange: .ofDachen)

    /// Testing Failed Key
    result = composer.inputValidityCheck(key: 0x0024)
    XCTAssert(result == false)

    // Testing Correct Qwerty Dachen Key
    composer.ensureParser(arrange: .ofDachen)
    result = composer.inputValidityCheck(key: 0x002F)
    XCTAssert(result == true)

    // Testing Correct ETen26 Key
    composer.ensureParser(arrange: .ofETen26)
    result = composer.inputValidityCheck(key: 0x0062)
    XCTAssert(result == true)

    // Testing Correct Hanyu-Pinyin Key
    composer.ensureParser(arrange: .ofHanyuPinyin)
    result = composer.inputValidityCheck(key: 0x0062)
    XCTAssert(result == true)
  }

  func testPhonabetKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofDachen)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 0x0032)  // 2, ㄉ
    composer.receiveKey(fromString: "j")  // ㄨ
    composer.receiveKey(fromString: "u")  // ㄧ
    composer.receiveKey(fromString: "l")  // ㄠ

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "3")  // 上聲
    XCTAssertEqual(composer.value, "ㄉㄧㄠˇ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄉㄧㄠ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "diao1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "diāo")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "diao1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄉㄧㄠ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)

    // Testing auto phonabet combination fixing process.
    composer.phonabetCombinationCorrectionEnabled = true

    // Testing exceptions of handling "ㄅㄨㄛ ㄆㄨㄛ ㄇㄨㄛ ㄈㄨㄛ"
    composer.clear()
    composer.receiveKey(fromString: "1")
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "i")
    XCTAssertEqual(composer.getComposition(), "ㄅㄛ")
    composer.receiveKey(fromString: "q")
    XCTAssertEqual(composer.getComposition(), "ㄆㄛ")
    composer.receiveKey(fromString: "a")
    XCTAssertEqual(composer.getComposition(), "ㄇㄛ")
    composer.receiveKey(fromString: "z")
    XCTAssertEqual(composer.getComposition(), "ㄈㄛ")

    // Testing exceptions of handling "ㄅㄨㄥ ㄆㄨㄥ ㄇㄨㄥ ㄈㄨㄥ"
    composer.clear()
    composer.receiveKey(fromString: "1")
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "/")
    XCTAssertEqual(composer.getComposition(), "ㄅㄥ")
    composer.receiveKey(fromString: "q")
    XCTAssertEqual(composer.getComposition(), "ㄆㄥ")
    composer.receiveKey(fromString: "a")
    XCTAssertEqual(composer.getComposition(), "ㄇㄥ")
    composer.receiveKey(fromString: "z")
    XCTAssertEqual(composer.getComposition(), "ㄈㄥ")

    // Testing exceptions of handling "ㄋㄨㄟ ㄌㄨㄟ"
    composer.clear()
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "o")
    XCTAssertEqual(composer.getComposition(), "ㄋㄟ")
    composer.receiveKey(fromString: "x")
    XCTAssertEqual(composer.getComposition(), "ㄌㄟ")

    // Testing exceptions of handling "ㄧㄜ ㄩㄜ"
    composer.clear()
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "k")
    composer.receiveKey(fromString: "u")
    XCTAssertEqual(composer.getComposition(), "ㄋㄧㄝ")
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "m")
    composer.receiveKey(fromString: "k")
    XCTAssertEqual(composer.getComposition(), "ㄋㄩㄝ")
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "k")
    XCTAssertEqual(composer.getComposition(), "ㄋㄧㄝ")

    // Testing exceptions of handling "ㄨㄜ ㄨㄝ"
    composer.clear()
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "k")
    XCTAssertEqual(composer.getComposition(), "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: ",")
    XCTAssertEqual(composer.getComposition(), "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: ",")
    composer.receiveKey(fromString: "j")
    XCTAssertEqual(composer.getComposition(), "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: "k")
    composer.receiveKey(fromString: "j")
    XCTAssertEqual(composer.getComposition(), "ㄩㄝ")

    // Testing tool functions
    XCTAssertEqual(Tekkon.restoreToneOneInZhuyinKey(target: "ㄉㄧㄠ"), "ㄉㄧㄠ1")
    XCTAssertEqual(Tekkon.cnvZhuyinChainToTextbookReading(target: "ㄊㄧㄥ-ㄓㄜ˙"), "ㄊㄧㄥ-˙ㄓㄜ")
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToPhona(target: "bian4-le5-tian1"), "ㄅㄧㄢˋ-ㄌㄜ˙-ㄊㄧㄢ")
    // 測試這種情形：「如果傳入的字串不包含任何半形英數內容的話，那麼應該直接將傳入的字串原樣返回」。
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToPhona(target: "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ"), "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ")
  }
}

// MARK: Testing Pinyin Arrangements

final class TekkonTestsPinyin: XCTestCase {
  func testHanyuPinyinKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofHanyuPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 100)  // d
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "a")
    composer.receiveKey(fromString: "o")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "3")  // 上聲
    XCTAssertEqual(composer.value, "ㄉㄧㄠˇ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄉㄧㄠ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "diao1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "diāo")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "diao1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄉㄧㄠ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)
  }

  func testSecondaryPinyinKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofSecondaryPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99)  // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2")  // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chiung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)
  }

  func testYalePinyinKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofYalePinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99)  // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2")  // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chyung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)
  }

  func testHualuoPinyinKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofHualuoPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99)  // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "o")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2")  // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)
  }

  func testUniversalPinyinKeyReceivingAndCompositions() throws {
    var composer = Tekkon.Composer(arrange: .ofUniversalPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99)  // c
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "o")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2")  // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ")  // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ")  // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "cyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7")  // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasToneMarker()
    XCTAssert(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3")  // 上聲
    toneMarkerIndicator = composer.hasToneMarker(withNothingElse: true)
    XCTAssert(toneMarkerIndicator)
  }
}
