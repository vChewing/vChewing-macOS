// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import XCTest

// MARK: - TekkonTestsBasic

final class TekkonTestsBasic: XCTestCase {
  func testMandarinParser() {
    // This is only for filling the testing coverage.
    var composer = Tekkon.Composer(arrange: .ofDachen)
    XCTAssertTrue(composer.isEmpty)
    XCTAssertEqual(composer.count(withIntonation: true), 0)
    XCTAssertEqual(composer.count(withIntonation: false), 0)
    var composer2 = Tekkon.Composer(arrange: .ofETen)
    composer2.ensureParser(arrange: .ofDachen)
    XCTAssertEqual(composer, composer2)
    Tekkon.MandarinParser.allCases.forEach {
      XCTAssertNotEqual($0.isDynamic.description, $0.nameTag)
      composer.ensureParser(arrange: $0)
      _ = composer.translate(key: "q")
      _ = composer.translate(key: "幹")
      _ = composer.translate(key: "3")
      _ = composer.translate(key: "1")
      composer.clear()
    }
  }

  func testInitializingPhonabet() {
    let thePhonabetNull = Tekkon.Phonabet("0")
    let thePhonabetA = Tekkon.Phonabet("ㄉ")
    let thePhonabetB = Tekkon.Phonabet("ㄧ")
    let thePhonabetC = Tekkon.Phonabet("ㄠ")
    let thePhonabetD = Tekkon.Phonabet("ˇ")
    XCTAssertEqual(thePhonabetNull.type.rawValue, 0)
    XCTAssertEqual(thePhonabetA.type.rawValue, 1)
    XCTAssertEqual(thePhonabetB.type.rawValue, 2)
    XCTAssertEqual(thePhonabetC.type.rawValue, 3)
    XCTAssertEqual(thePhonabetD.type.rawValue, 4)
    var thePhonabetE = thePhonabetA
    thePhonabetE.selfReplace("ㄉ", "ㄋ")
    XCTAssertEqual(thePhonabetE.value, "ㄋ")
    thePhonabetE.selfReplace("ㄋ", "_")
    XCTAssertNotEqual(thePhonabetE.value, "_")
    XCTAssertEqual(thePhonabetE.type, .null)
  }

  func testIsValidKeyWithKeys() {
    var result = true
    var composer = Tekkon.Composer(arrange: .ofDachen)

    // Testing failed char.
    result = composer.inputValidityCheck(charStr: "幹")
    XCTAssertFalse(result)

    // Testing Failed Key
    result = composer.inputValidityCheck(key: 0x0024)
    XCTAssertFalse(result)

    // Testing Correct Qwerty Dachen Key
    composer.ensureParser(arrange: .ofDachen)
    result = composer.inputValidityCheck(key: 0x002F)
    XCTAssertTrue(result)

    // Testing Correct ETen26 Key
    composer.ensureParser(arrange: .ofETen26)
    result = composer.inputValidityCheck(key: 0x0062)
    XCTAssertTrue(result)

    // Testing Correct Hanyu-Pinyin Key
    composer.ensureParser(arrange: .ofHanyuPinyin)
    result = composer.inputValidityCheck(key: 0x0062)
    XCTAssertTrue(result)
  }

  func testPhonabetKeyReceivingAndCompositions() {
    var composer = Tekkon.Composer(arrange: .ofDachen)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 0x0032) // 2, ㄉ
    composer.receiveKey(fromString: "j") // ㄨ
    composer.receiveKey(fromString: "u") // ㄧ
    composer.receiveKey(fromString: "l") // ㄠ

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

    // Testing auto phonabet combination fixing process.
    composer.phonabetCombinationCorrectionEnabled = true

    // Testing .doBackSpace().
    while !composer.isEmpty {
      composer.doBackSpace()
    }

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
    XCTAssertEqual(Tekkon.restoreToneOneInPhona(target: "ㄉㄧㄠ"), "ㄉㄧㄠ1")
    XCTAssertEqual(Tekkon.cnvPhonaToTextbookStyle(target: "ㄓㄜ˙"), "˙ㄓㄜ")
    XCTAssertEqual(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: "ㄍㄢˋ"), "gan4")
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: "起(qi3)居(ju1)"), "起(qǐ)居(jū)")
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "bian4"), "ㄅㄧㄢˋ")
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "bian4-le5-tian1"), "ㄅㄧㄢˋ-ㄌㄜ˙-ㄊㄧㄢ")
    // 測試這種情形：「如果傳入的字串不包含任何半形英數內容的話，那麼應該直接將傳入的字串原樣返回」。
    XCTAssertEqual(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ"), "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ")
  }

  func testSemivowelNormalizationWithEncounteredVowels() {
    // 測試「ㄩ」遇到特定韻母時會自動轉為「ㄨ」以維持正確拼法。
    guard let yu = "ㄩ".unicodeScalars.first,
          let o = "ㄛ".unicodeScalars.first,
          let b = "ㄅ".unicodeScalars.first
    else {
      XCTFail("未能生成測試所需的 Unicode Scalar。")
      return
    }

    var composer = Tekkon.Composer(arrange: .ofDachen, correction: true)
    composer.receiveKey(fromPhonabet: yu)
    composer.receiveKey(fromPhonabet: o)
    XCTAssertEqual(composer.value, "ㄨㄛ")

    composer.clear()
    composer.receiveKey(fromPhonabet: b)
    composer.receiveKey(fromPhonabet: yu)
    composer.receiveKey(fromPhonabet: o)
    XCTAssertEqual(composer.getComposition(), "ㄅㄛ")
  }

  func testPronounceableQueryKeyGate() {
    // 測試 pronounceableOnly 限制僅允許可唸組合被回傳。
    guard let tone = "ˊ".unicodeScalars.first else {
      XCTFail("未能生成測試所需的 Unicode Scalar。")
      return
    }

    var composer = Tekkon.Composer(arrange: .ofDachen)
    composer.receiveKey(fromPhonabet: tone)
    XCTAssertFalse(composer.isPronounceable)
    XCTAssertNil(composer.phonabetKeyForQuery(pronounceableOnly: true))
    XCTAssertEqual(composer.phonabetKeyForQuery(pronounceableOnly: false), "ˊ")
  }

  func testPinyinTrieBranchInsertKeepsExistingBranches() {
    // 測試 PinyinTrie 在同一節點底下追加多個分支時，不會覆蓋既有資料。
    let trie = Tekkon.PinyinTrie(parser: .ofDachen)
    trie.insert("li", entry: "ㄌㄧ")
    trie.insert("lin", entry: "ㄌㄧㄣ")
    trie.insert("liu", entry: "ㄌㄧㄡ")

    let fetched = trie.search("li")
    XCTAssertTrue(fetched.contains("ㄌㄧ"))
    XCTAssertTrue(fetched.contains("ㄌㄧㄣ"))
    XCTAssertTrue(fetched.contains("ㄌㄧㄡ"))
  }

  func testChoppingRawComplex() {
    let trieZhuyin = Tekkon.PinyinTrie(parser: .ofDachen)
    let triePinyin = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
    do {
      let choppedZhuyin = trieZhuyin.chop("ㄅㄩㄝㄓㄨㄑㄕㄢㄌㄧㄌㄧㄤ")
      let choppedPinyin = triePinyin.chop("byuezqsll")
      XCTAssertTrue(choppedZhuyin == ["ㄅ", "ㄩㄝ", "ㄓㄨ", "ㄑ", "ㄕㄢ", "ㄌㄧ", "ㄌㄧㄤ"])
      XCTAssertTrue(choppedPinyin == ["b", "yue", "z", "q", "s", "l", "l"])
      let choppedZhuyin2 = trieZhuyin.chop("ㄕㄐㄧㄉㄓ")
      XCTAssertTrue(choppedZhuyin2 == ["ㄕ", "ㄐㄧ", "ㄉ", "ㄓ"])
    }
    do {
      let choppedPinyin = triePinyin.chop("yod")
      XCTAssertTrue(choppedPinyin == ["yo", "d"])
      let deducted = triePinyin.deductChoppedPinyinToZhuyin(choppedPinyin)
      XCTAssertTrue(deducted.first == "ㄧㄛ&ㄧㄡ&ㄩㄥ")
    }
  }

  func testPinyinTrieConvertingPinyinChopsToZhuyin() {
    // 漢語拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
      let choppedPinyin = ["b", "yue", "z", "q", "s", "l", "l"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄅ", "ㄩㄝ", "ㄓ&ㄗ", "ㄑ", "ㄕ&ㄙ", "ㄌ", "ㄌ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
    // 國音二式：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofSecondaryPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
    // 耶魯拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofYalePinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
    // 華羅拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofHualuoPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
    // 通用拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofUniversalPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
    // 韋氏拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofWadeGilesPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄐ&ㄑ&ㄓ&ㄔ", "ㄈ", "ㄏ&ㄒ", "ㄕ&ㄙ"]
      XCTAssertTrue(deductedZhuyin == expected)
    }
  }
}
