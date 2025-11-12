// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import XCTest

// MARK: - TekkonTestsPinyin

final class TekkonTestsPinyin: XCTestCase {
  func testHanyuPinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofHanyuPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 100) // d
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "a")
    composer.receiveKey(fromString: "o")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "3") // 上聲
    XCTAssertEqual(composer.value, "ㄉㄧㄠˇ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄉㄧㄠ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "diao1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "diāo")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "diao1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄉㄧㄠ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄉㄧㄠ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }

  func testSecondaryPinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofSecondaryPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99) // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chiung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }

  func testYalePinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofYalePinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99) // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chyung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }

  func testHualuoPinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofHualuoPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99) // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "o")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "chyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }

  func testUniversalPinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofUniversalPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99) // c
    composer.receiveKey(fromString: "y")
    composer.receiveKey(fromString: "o")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "cyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }

  func testWadeGilesPinyinKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofWadeGilesPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 99) // c
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "'") // 韋氏拼音清濁分辨鍵
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "n")
    composer.receiveKey(fromString: "g")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertFalse(toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    XCTAssertEqual(composer.value, "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    XCTAssertEqual(composer.value, "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true), "qiong1")
    XCTAssertEqual(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true), "qiōng")
    XCTAssertEqual(composer.getInlineCompositionForDisplay(isHanyuPinyin: true), "ch'iung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    XCTAssertEqual(composer.getComposition(), "ㄑㄩㄥ˙")
    XCTAssertEqual(composer.getComposition(isTextBookStyle: true), "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    XCTAssertTrue(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertFalse(toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    XCTAssertTrue(toneMarkerIndicator)
  }
}
