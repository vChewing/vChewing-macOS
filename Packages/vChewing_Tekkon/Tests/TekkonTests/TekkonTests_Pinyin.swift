// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import Testing

// MARK: - TekkonTestsPinyin

@MainActor
@Suite(.serialized)
struct TekkonTestsPinyin {
  @Test("[Tekkon] Composer_InputAndComposition_HanyuPinyin")
  func testHanyuPinyinKeyReceivingAndCompositions() async throws {
    var composer = Tekkon.Composer(arrange: .ofHanyuPinyin)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 100) // d
    composer.receiveKey(fromString: "i")
    composer.receiveKey(fromString: "a")
    composer.receiveKey(fromString: "o")

    // Testing missing tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "3") // 上聲
    #expect(composer.value == "ㄉㄧㄠˇ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄉㄧㄠ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄉㄧㄠ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "diao1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "diāo")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "diao1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄉㄧㄠ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄉㄧㄠ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }

  @Test("[Tekkon] Composer_InputAndComposition_SecondaryPinyin")
  func testSecondaryPinyinKeyReceivingAndCompositions() async throws {
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
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    #expect(composer.value == "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄑㄩㄥ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "qiong1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "qiōng")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "chiung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄑㄩㄥ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }

  @Test("[Tekkon] Composer_InputAndComposition_YalePinyin")
  func testYalePinyinKeyReceivingAndCompositions() async throws {
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
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    #expect(composer.value == "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄑㄩㄥ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "qiong1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "qiōng")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "chyung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄑㄩㄥ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }

  @Test("[Tekkon] Composer_InputAndComposition_HualuoPinyin")
  func testHualuoPinyinKeyReceivingAndCompositions() async throws {
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
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    #expect(composer.value == "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄑㄩㄥ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "qiong1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "qiōng")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "chyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄑㄩㄥ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }

  @Test("[Tekkon] Composer_InputAndComposition_UniversalPinyin")
  func testUniversalPinyinKeyReceivingAndCompositions() async throws {
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
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    #expect(composer.value == "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄑㄩㄥ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "qiong1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "qiōng")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "cyong1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄑㄩㄥ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }

  @Test("[Tekkon] Composer_InputAndComposition_WadeGiles")
  func testWadeGilesPinyinKeyReceivingAndCompositions() async throws {
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
    #expect(!toneMarkerIndicator)

    composer.receiveKey(fromString: "2") // 陽平
    #expect(composer.value == "ㄑㄩㄥˊ")
    composer.doBackSpace()
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.value == "ㄑㄩㄥ ") // 這裡回傳的結果的陰平是空格

    // Test Getting Displayed Composition
    #expect(composer.getComposition() == "ㄑㄩㄥ")
    #expect(composer.getComposition(isHanyuPinyin: true) == "qiong1")
    #expect(composer.getComposition(isHanyuPinyin: true, isTextBookStyle: true) == "qiōng")
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "ch'iung1")

    // Test Tone 5
    composer.receiveKey(fromString: "7") // 輕聲
    #expect(composer.getComposition() == "ㄑㄩㄥ˙")
    #expect(composer.getComposition(isTextBookStyle: true) == "˙ㄑㄩㄥ")

    // Testing having tone markers
    toneMarkerIndicator = composer.hasIntonation()
    #expect(toneMarkerIndicator)

    // Testing having not-only tone markers
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(!toneMarkerIndicator)

    // Testing having only tone markers
    composer.clear()
    composer.receiveKey(fromString: "3") // 上聲
    toneMarkerIndicator = composer.hasIntonation(withNothingElse: true)
    #expect(toneMarkerIndicator)
  }
}
