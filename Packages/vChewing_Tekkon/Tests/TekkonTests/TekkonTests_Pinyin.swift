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

  @Test("[Tekkon] Composer_PinyinAutoChopResult")
  func testPinyinAutoChopResult() async throws {
    var composer = Tekkon.Composer(arrange: .ofHanyuPinyin)

    composer.receiveKey(fromString: "s")
    composer.receiveKey(fromString: "h")
    composer.receiveKey(fromString: "i")

    let autoChop = try #require(composer.pinyinAutoChopResult(appending: "j"))
    #expect(autoChop.committedReadings == ["ㄕ"])
    #expect(autoChop.remainingRomaji == "j")

    composer.replacePinyinBuffer(with: autoChop.remainingRomaji)
    #expect(composer.getInlineCompositionForDisplay(isHanyuPinyin: true) == "j")
    #expect(!composer.isPronounceable)
  }

  // MARK: - 狂拼模式（Furious Typing Mode）基礎：PinyinTrie.zhuyinReadings

  /// 完整音節：僅回傳該音節對應的注音，不做前綴展開（即使該音節是其他音節的字串前綴）。
  @Test("[Tekkon] PinyinTrie_zhuyinReadings_ExactCompleteSyllable")
  func testPinyinTrieZhuyinReadingsExactCompleteSyllable() async throws {
    // 漢語拼音：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)
      #expect(trie.zhuyinReadings(forPinyinFragment: "shi") == ["ㄕ"])
      #expect(trie.zhuyinReadings(forPinyinFragment: "ni") == ["ㄋㄧ"])
      // "nan" 同時是 "nang" 的字串前綴；精確匹配時不展開後者。
      #expect(trie.zhuyinReadings(forPinyinFragment: "nan") == ["ㄋㄢ"])
    }
    // 國音二式：
    do {
      let trie = Tekkon.PinyinTrie(parser: .ofSecondaryPinyin)
      #expect(trie.zhuyinReadings(forPinyinFragment: "chiung") == ["ㄑㄩㄥ"])
    }
  }

  /// 不完整前綴：回傳所有以該輸入為前綴的音節所對應的注音，去重且排序穩定。
  @Test("[Tekkon] PinyinTrie_zhuyinReadings_IncompletePrefixExpansion")
  func testPinyinTrieZhuyinReadingsIncompletePrefixExpansion() async throws {
    let trie = Tekkon.PinyinTrie(parser: .ofHanyuPinyin)

    // "z" 同時是 z- 與 zh- 兩系音節的字串前綴：兩種聲母的注音都應涵蓋。
    let zReadings = trie.zhuyinReadings(forPinyinFragment: "z")
    #expect(!zReadings.isEmpty)
    #expect(Set(zReadings).count == zReadings.count) // 去重。
    #expect(zReadings == zReadings.sorted()) // 排序穩定（Unicode 字典序）。
    #expect(zReadings.contains("ㄗ"))
    #expect(zReadings.contains("ㄓ"))

    // "zh" 前綴只涵蓋 zh- 系。
    let zhReadings = trie.zhuyinReadings(forPinyinFragment: "zh")
    #expect(!zhReadings.isEmpty)
    #expect(zhReadings == zhReadings.sorted())
    #expect(zhReadings.contains("ㄓ"))
    #expect(!zhReadings.contains("ㄗ"))
    // 確定性：重複呼叫輸出一致。
    #expect(zhReadings == trie.zhuyinReadings(forPinyinFragment: "zh"))
  }

  /// 邊界案例：空字串、非拼音排列、不可能的前綴。
  @Test("[Tekkon] PinyinTrie_zhuyinReadings_EdgeCases")
  func testPinyinTrieZhuyinReadingsEdgeCases() async throws {
    // 空字串：回傳空陣列。
    #expect(Tekkon.PinyinTrie(parser: .ofHanyuPinyin).zhuyinReadings(forPinyinFragment: "") == [])
    // 非拼音排列（大千注音）：直接回傳空陣列。
    #expect(Tekkon.PinyinTrie(parser: .ofDachen).zhuyinReadings(forPinyinFragment: "z") == [])
    // 不可能的前綴：無任何音節以之開頭。
    #expect(Tekkon.PinyinTrie(parser: .ofHanyuPinyin).zhuyinReadings(forPinyinFragment: "xw") == [])
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

  /// BackSpace 清空拼音緩衝後，聲介韻槽位須同步清空（不得殘留已刪除的讀音）——
  /// 否則 isPronounceable 誤判為真，後續的聲調鍵／空格鍵會把已刪除的讀音重新組回
  /// （狂拼模式「BackSpace 後按空格」的輪替／重組錯亂由此而來）。
  @Test("[Tekkon] Composer_BackSpaceResyncsPhonabetSlots_Pinyin")
  func testBackSpaceResyncsPhonabetSlotsInPinyinMode() async throws {
    var composer = Tekkon.Composer(arrange: .ofHanyuPinyin)

    // 輸入完整音節「ma」。
    composer.receiveKey(fromString: "m")
    composer.receiveKey(fromString: "a")
    #expect(composer.romajiBuffer == "ma")
    #expect(composer.isPronounceable)

    // 兩次 BackSpace 清空緩衝：聲介韻槽位須同步清空。
    composer.doBackSpace()
    #expect(composer.romajiBuffer == "m")
    composer.doBackSpace()
    #expect(composer.romajiBuffer.isEmpty)
    #expect(composer.isEmpty)
    #expect(!composer.isPronounceable)

    // 清空後收下陰平空格鍵：不應把已刪除的「ma」重新組回。
    composer.receiveKey(fromString: " ") // 陰平
    #expect(composer.intonation.value == " ")
    #expect(composer.getComposition() == "")
    #expect(!composer.isPronounceable)
  }
}
