// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import Testing

// MARK: - TekkonTestsBasic

@MainActor
@Suite(.serialized)
struct TekkonTestsBasic {
  @Test("[Tekkon] TestCoverage")
  func testMandarinParser() async throws {
    // This is only for filling the testing coverage.
    var composer = Tekkon.Composer(arrange: .ofDachen)
    #expect(composer.isEmpty)
    #expect(composer.count(withIntonation: true) == 0)
    #expect(composer.count(withIntonation: false) == 0)
    var composer2 = Tekkon.Composer(arrange: .ofETen)
    composer2.ensureParser(arrange: .ofDachen)
    #expect(composer == composer2)
    Tekkon.MandarinParser.allCases.forEach {
      #expect($0.isDynamic.description != $0.nameTag)
      composer.ensureParser(arrange: $0)
      _ = composer.translate(key: "q")
      _ = composer.translate(key: "幹")
      _ = composer.translate(key: "3")
      _ = composer.translate(key: "1")
      composer.clear()
    }
  }

  @Test("[Tekkon] Phonabet_Init")
  func testInitializingPhonabet() async throws {
    let thePhonabetNull = Tekkon.Phonabet("0")
    let thePhonabetA = Tekkon.Phonabet("ㄉ")
    let thePhonabetB = Tekkon.Phonabet("ㄧ")
    let thePhonabetC = Tekkon.Phonabet("ㄠ")
    let thePhonabetD = Tekkon.Phonabet("ˇ")
    #expect(thePhonabetNull.type.rawValue == 0)
    #expect(thePhonabetA.type.rawValue == 1)
    #expect(thePhonabetB.type.rawValue == 2)
    #expect(thePhonabetC.type.rawValue == 3)
    #expect(thePhonabetD.type.rawValue == 4)
    var thePhonabetE = thePhonabetA
    thePhonabetE.selfReplace("ㄉ", "ㄋ")
    #expect(thePhonabetE.value == "ㄋ")
    thePhonabetE.selfReplace("ㄋ", "_")
    #expect(thePhonabetE.value != "_")
    #expect(thePhonabetE.type == .null)
  }

  @Test("[Tekkon] Composer_InputValidityCheck")
  func testIsValidKeyWithKeys() async throws {
    var result = true
    var composer = Tekkon.Composer(arrange: .ofDachen)

    // Testing failed char.
    result = composer.inputValidityCheck(charStr: "幹")
    #expect(result == false)

    // Testing Failed Key
    result = composer.inputValidityCheck(key: 0x0024)
    #expect(result == false)

    // Testing Correct Qwerty Dachen Key
    composer.ensureParser(arrange: .ofDachen)
    result = composer.inputValidityCheck(key: 0x002F)
    #expect(result == true)

    // Testing Correct ETen26 Key
    composer.ensureParser(arrange: .ofETen26)
    result = composer.inputValidityCheck(key: 0x0062)
    #expect(result == true)

    // Testing Correct Hanyu-Pinyin Key
    composer.ensureParser(arrange: .ofHanyuPinyin)
    result = composer.inputValidityCheck(key: 0x0062)
    #expect(result == true)
  }

  @Test("[Tekkon] Composer_Zhuyin_InputAndComposition")
  func testPhonabetKeyReceivingAndCompositions() async throws {
    var composer = Tekkon.Composer(arrange: .ofDachen)
    var toneMarkerIndicator = true

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 0x0032) // 2, ㄉ
    composer.receiveKey(fromString: "j") // ㄨ
    composer.receiveKey(fromString: "u") // ㄧ
    composer.receiveKey(fromString: "l") // ㄠ

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
    #expect(composer.getComposition() == "ㄅㄛ")
    composer.receiveKey(fromString: "q")
    #expect(composer.getComposition() == "ㄆㄛ")
    composer.receiveKey(fromString: "a")
    #expect(composer.getComposition() == "ㄇㄛ")
    composer.receiveKey(fromString: "z")
    #expect(composer.getComposition() == "ㄈㄛ")

    // Testing exceptions of handling "ㄅㄨㄥ ㄆㄨㄥ ㄇㄨㄥ ㄈㄨㄥ"
    composer.clear()
    composer.receiveKey(fromString: "1")
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "/")
    #expect(composer.getComposition() == "ㄅㄥ")
    composer.receiveKey(fromString: "q")
    #expect(composer.getComposition() == "ㄆㄥ")
    composer.receiveKey(fromString: "a")
    #expect(composer.getComposition() == "ㄇㄥ")
    composer.receiveKey(fromString: "z")
    #expect(composer.getComposition() == "ㄈㄥ")

    // Testing exceptions of handling "ㄋㄨㄟ ㄌㄨㄟ"
    composer.clear()
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "o")
    #expect(composer.getComposition() == "ㄋㄟ")
    composer.receiveKey(fromString: "x")
    #expect(composer.getComposition() == "ㄌㄟ")

    // Testing exceptions of handling "ㄧㄜ ㄩㄜ"
    composer.clear()
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "k")
    composer.receiveKey(fromString: "u")
    #expect(composer.getComposition() == "ㄋㄧㄝ")
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "m")
    composer.receiveKey(fromString: "k")
    #expect(composer.getComposition() == "ㄋㄩㄝ")
    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "u")
    composer.receiveKey(fromString: "k")
    #expect(composer.getComposition() == "ㄋㄧㄝ")

    // Testing exceptions of handling "ㄨㄜ ㄨㄝ"
    composer.clear()
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: "k")
    #expect(composer.getComposition() == "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: "j")
    composer.receiveKey(fromString: ",")
    #expect(composer.getComposition() == "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: ",")
    composer.receiveKey(fromString: "j")
    #expect(composer.getComposition() == "ㄩㄝ")
    composer.clear()
    composer.receiveKey(fromString: "k")
    composer.receiveKey(fromString: "j")
    #expect(composer.getComposition() == "ㄩㄝ")

    // Testing tool functions
    #expect(Tekkon.restoreToneOneInPhona(target: "ㄉㄧㄠ") == "ㄉㄧㄠ1")
    #expect(Tekkon.cnvPhonaToTextbookStyle(target: "ㄓㄜ˙") == "˙ㄓㄜ")
    #expect(Tekkon.cnvPhonaToHanyuPinyin(targetJoined: "ㄍㄢˋ") == "gan4")
    #expect(Tekkon.cnvHanyuPinyinToTextbookStyle(targetJoined: "起(qi3)居(ju1)") == "起(qǐ)居(jū)")
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "bian4-le5-tian1") == "ㄅㄧㄢˋ-ㄌㄜ˙-ㄊㄧㄢ")
    // 測試這種情形：「如果傳入的字串不包含任何半形英數內容的話，那麼應該直接將傳入的字串原樣返回」。
    #expect(Tekkon.cnvHanyuPinyinToPhona(targetJoined: "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ") == "ㄅㄧㄢˋ-˙ㄌㄜ-ㄊㄧㄢ")
  }

  @Test("[Tekkon] Composer_Zhuyin_AutoCorrect")
  func testPhonabetCombinationCorrection() async throws {
    var composer = Tekkon.Composer(arrange: .ofDachen, correction: true)
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄧ")
    composer.receiveKey(fromPhonabet: "ˋ")
    #expect(composer.value == "ㄓˋ")

    composer.clear()
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄩ")
    composer.receiveKey(fromPhonabet: "ˋ")
    #expect(composer.value == "ㄐㄩˋ")

    composer.clear()
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄧ")
    composer.receiveKey(fromPhonabet: "ㄢ")
    #expect(composer.value == "ㄓㄢ")

    composer.clear()
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄩ")
    composer.receiveKey(fromPhonabet: "ㄢ")
    #expect(composer.value == "ㄐㄩㄢ")

    composer.clear()
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄧ")
    composer.receiveKey(fromPhonabet: "ㄢ")
    composer.receiveKey(fromPhonabet: "ˋ")
    #expect(composer.value == "ㄓㄢˋ")

    composer.clear()
    composer.receiveKey(fromPhonabet: "ㄓ")
    composer.receiveKey(fromPhonabet: "ㄩ")
    composer.receiveKey(fromPhonabet: "ㄢ")
    composer.receiveKey(fromPhonabet: "ˋ")
    #expect(composer.value == "ㄐㄩㄢˋ")
  }

  @Test("[Tekkon] Chopper")
  func testChoppingRawComplex() async throws {
    let trieZhuyin = Tekkon.PinyinTrie(parser: .ofDachen)
    let triePinyin = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
    do {
      let choppedZhuyin = trieZhuyin.chop("ㄅㄩㄝㄓㄨㄑㄕㄢㄌㄧㄌㄧㄤ")
      let choppedPinyin = triePinyin.chop("byuezqsll")
      #expect(choppedZhuyin == ["ㄅ", "ㄩㄝ", "ㄓㄨ", "ㄑ", "ㄕㄢ", "ㄌㄧ", "ㄌㄧㄤ"])
      #expect(choppedPinyin == ["b", "yue", "z", "q", "s", "l", "l"])
      let choppedZhuyin2 = trieZhuyin.chop("ㄕㄐㄧㄉㄓ")
      #expect(choppedZhuyin2 == ["ㄕ", "ㄐㄧ", "ㄉ", "ㄓ"])
    }
    do {
      let choppedPinyin = triePinyin.chop("yod")
      #expect(choppedPinyin == ["yo", "d"])
      let deducted = triePinyin.deductChoppedPinyinToZhuyin(choppedPinyin)
      #expect(deducted.first == "ㄧㄛ&ㄧㄡ&ㄩㄥ")
    }
  }

  @Test("[Tekkon] Semivowel Normalization with Encouuntered Vowels")
  func testSemivowelNormalizationWithEncounteredVowels() async throws {
    // 測試「ㄩ」遇到特定韻母時會自動轉為「ㄨ」以維持正確拼法。
    let nullErr = "未能生成測試所需的 Unicode Scalar。"
    let yu = try #require("ㄩ".unicodeScalars.first, .init(rawValue: nullErr))
    let o = try #require("ㄛ".unicodeScalars.first, .init(rawValue: nullErr))
    let b = try #require("ㄅ".unicodeScalars.first, .init(rawValue: nullErr))

    var composer = Tekkon.Composer(arrange: .ofDachen, correction: true)
    composer.receiveKey(fromPhonabet: yu)
    composer.receiveKey(fromPhonabet: o)
    #expect(composer.value == "ㄨㄛ")

    composer.clear()
    composer.receiveKey(fromPhonabet: b)
    composer.receiveKey(fromPhonabet: yu)
    composer.receiveKey(fromPhonabet: o)
    #expect(composer.getComposition() == "ㄅㄛ")
  }

  @Test("[Tekkon] Pronounceable Query Key Gate")
  func testPronounceableQueryKeyGate() async throws {
    // 測試 pronounceableOnly 限制僅允許可唸組合被回傳。
    let tone = try #require("ˊ".unicodeScalars.first, "未能生成測試所需的 Unicode Scalar。")
    var composer = Tekkon.Composer(arrange: .ofDachen)
    composer.receiveKey(fromPhonabet: tone)
    #expect(!composer.isPronounceable)
    #expect(nil == composer.phonabetKeyForQuery(pronounceableOnly: true))
    #expect(composer.phonabetKeyForQuery(pronounceableOnly: false) == "ˊ")
  }

  @Test("[Tekkon] Pinyin Trie Batch Insert Keeps Existing Branches")
  func testPinyinTrieBranchInsertKeepsExistingBranches() async throws {
    // 測試 PinyinTrie 在同一節點底下追加多個分支時，不會覆蓋既有資料。
    let trie = Tekkon.PinyinTrie(parser: .ofDachen)
    trie.insert("li", entry: "ㄌㄧ")
    trie.insert("lin", entry: "ㄌㄧㄣ")
    trie.insert("liu", entry: "ㄌㄧㄡ")

    let fetched = trie.search("li")
    #expect(fetched.contains("ㄌㄧ"))
    #expect(fetched.contains("ㄌㄧㄣ"))
    #expect(fetched.contains("ㄌㄧㄡ"))
  }

  @Test("[Tekkon] Pinyin Trie Converting Pinyin Chops to Zhuyin")
  func testPinyinTrieConvertingPinyinChopsToZhuyin() async throws {
    // 漢語拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
      let choppedPinyin = ["b", "yue", "z", "q", "s", "l", "l"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄅ", "ㄩㄝ", "ㄓ&ㄗ", "ㄑ", "ㄕ&ㄙ", "ㄌ", "ㄌ"]
      #expect(deductedZhuyin == expected)
    }
    // 國音二式：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofSecondaryPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      #expect(deductedZhuyin == expected)
    }
    // 耶魯拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofYalePinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      #expect(deductedZhuyin == expected)
    }
    // 華羅拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofHualuoPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄑ&ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      #expect(deductedZhuyin == expected)
    }
    // 通用拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofUniversalPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄔ", "ㄈ", "ㄏ", "ㄒ&ㄕ&ㄙ"]
      #expect(deductedZhuyin == expected)
    }
    // 韋氏拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofWadeGilesPinyin)
      let choppedPinyin = ["ch", "f", "h", "s"]
      let deductedZhuyin = trie.deductChoppedPinyinToZhuyin(choppedPinyin)
      let expected: [String] = ["ㄐ&ㄑ&ㄓ&ㄔ", "ㄈ", "ㄏ&ㄒ", "ㄕ&ㄙ"]
      #expect(deductedZhuyin == expected)
    }
  }
}
