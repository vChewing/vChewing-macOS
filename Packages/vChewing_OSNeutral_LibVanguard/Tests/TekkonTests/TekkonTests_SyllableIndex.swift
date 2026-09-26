// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// `Tekkon.SyllableIndex` 之行為測試。
//
// 索引之語意與兩條紅線見 `Sources/Tekkon/Tekkon_SyllableIndex.swift` 之型別說明。
// 本檔之斷言分三類：① 資料規模（427／442／15／37 四項可稽核數字）；② 成員資格之正反例；
// ③ 與引擎既有表（`allowedConsonants` 等）及測試素材之交叉比對。

import Foundation
import Testing

@testable import Tekkon

@Suite("注音音節前綴索引")
struct TekkonTestsSyllableIndex {
  // MARK: 資料規模

  @Test("完整讀音集即 mapHanyuPinyin 之 value 集")
  func canonicalReadingsMatchThePinyinMap() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    #expect(index.readings.count == 427)
    #expect(Tekkon.SyllableIndex.allReadings == index.readings)
    #expect(Set(index.readings) == Set(Tekkon.mapHanyuPinyin.values))
    // 升冪、且無重複。
    #expect(index.readings == index.readings.sorted())
    #expect(Set(index.readings).count == index.readings.count)
  }

  @Test("全部非空前綴恰為 442 條")
  func prefixSetIsExactlyFourHundredFortyTwo() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    var derived: Set<String> = []
    for reading in index.readings {
      for length in 1 ... reading.count { derived.insert(String(reading.prefix(length))) }
    }
    #expect(derived.count == 442)
    // 每一條推導而得之前綴皆須被索引認可……
    let notRecognized = derived.filter { !index.isPrefix($0) }
    #expect(notRecognized.isEmpty, "索引漏收：\(notRecognized.sorted())")
    // ……且索引不得多收任何「非任何讀音之前綴」之字串。抽樣檢查一組必然為假者。
    for bogus in ["", "ㄍㄋ", "ㄅㄆ", "ㄚㄅ", "abc", "zhi", "ㄅㄚˇ", "ㄅㄚˋ", "ㄅㄚ1", " ㄅ"] {
      #expect(!index.isPrefix(bogus), "\(bogus) 不該是前綴")
    }
    // 索引之成員資格恰等於推導集：逐條讀音之每一段前綴皆真、且其延伸一符號後皆假。
    for reading in index.readings {
      #expect(index.isPrefix(reading))
      #expect(!index.isPrefix(reading + "ㄅ"), "\(reading)ㄅ 必定不是前綴")
    }
  }

  @Test("單符號前綴恰為引擎之聲母／介母／韻母三表之聯集")
  func oneCharacterPrefixesAreThePhonabetTables() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    var derivedOneChar: Set<String> = []
    for reading in index.readings {
      derivedOneChar.insert(String(reading.prefix(1)))
    }
    let tableUnion = Set(
      (Tekkon.allowedConsonants + Tekkon.allowedSemivowels + Tekkon.allowedVowels)
        .map { String(Character($0)) }
    )
    #expect(derivedOneChar.count == 37)
    #expect(derivedOneChar == tableUnion)
    for symbol in tableUnion { #expect(index.isPrefix(symbol)) }
  }

  @Test("嚴格前綴恰為 15 條，且其全表逐條斷言")
  func strictPrefixesAreExactlyTheFifteen() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    var derived: Set<String> = []
    for reading in index.readings {
      for length in 1 ... reading.count { derived.insert(String(reading.prefix(length))) }
    }
    let strict = derived.filter { !index.isComplete($0) }.sorted()
    #expect(
      strict == ["ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄈㄧ", "ㄉ", "ㄊ", "ㄋ", "ㄌ", "ㄍ", "ㄎ", "ㄎㄧ", "ㄏ", "ㄐ", "ㄒ"],
      "實得：\(strict)"
    )
    for symbol in strict {
      #expect(index.isPrefix(symbol), "\(symbol) 應為前綴")
      #expect(!index.isComplete(symbol), "\(symbol) 不應為完整讀音")
    }
    // 反向：推導集之中，凡不在上述 15 條者皆須為完整讀音。
    for prefix in derived where !strict.contains(prefix) {
      #expect(index.isComplete(prefix), "\(prefix) 應為完整讀音")
    }
    // 兩條 2 字嚴格前綴之來由：`ㄈㄧㄠ`／`ㄎㄧㄡ`／`ㄎㄧㄤ` 之存在使 `ㄈㄧ`／`ㄎㄧ` 成前綴，
    // 惟其本身非獨立音節。
    #expect(index.completions(of: "ㄈㄧ") == ["ㄈㄧㄠ"])
    #expect(index.completions(of: "ㄎㄧ") == ["ㄎㄧㄡ", "ㄎㄧㄤ"])
  }

  @Test("單符號讀音之 24／13 分裂，暨 mapHanyuPinyin 之單字母異常條目")
  func singleSymbolCompleteSplit() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    var oneChar: Set<String> = []
    for reading in index.readings { oneChar.insert(String(reading.prefix(1))) }
    let completeOneChar = oneChar.filter { index.isComplete($0) }.sorted()
    let strictOneChar = oneChar.filter { !index.isComplete($0) }.sorted()
    // 37 ＝ 24 完整 ＋ 13 嚴格。
    #expect(completeOneChar.count == 24)
    #expect(strictOneChar == ["ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄉ", "ㄊ", "ㄋ", "ㄌ", "ㄍ", "ㄎ", "ㄏ", "ㄐ", "ㄒ"])
    // 預期之完整單符號：21 個聲母中之 8 個（ㄑ ㄓ ㄔ ㄕ ㄖ ㄗ ㄘ ㄙ）
    // ＋ 3 個介母（ㄧ ㄨ ㄩ）＋ 13 個韻母。
    #expect(
      completeOneChar == [
        "ㄑ", "ㄓ", "ㄔ", "ㄕ", "ㄖ", "ㄗ", "ㄘ", "ㄙ",
        "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ", "ㄠ", "ㄡ", "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ",
        "ㄧ", "ㄨ", "ㄩ",
      ].sorted()
    )
    // **異常之釘死**：`ㄑ` 之所以擠身完整讀音，唯一原因是 `mapHanyuPinyin` 收了單字母條目
    // `"q": "ㄑ"`——其餘 20 個聲母皆無單字母條目（`b`／`p`／`m`… 皆不存在）。
    // `"q"` 不是合法之漢語拼音音節（`qi` 才是，且 `"qi"` 另有條目）。
    // 本 phase **不動**此條目（移除即為 Tekkon 之行為變動，超出本 phase 之範圍），
    // 僅以本斷言把它釘成可觀測之事實。
    #expect(Tekkon.mapHanyuPinyin["q"] == "ㄑ")
    #expect(Tekkon.mapHanyuPinyin["qi"] == "ㄑㄧ")
    #expect(Tekkon.mapHanyuPinyin["b"] == nil)
    #expect(Tekkon.mapHanyuPinyin["p"] == nil)
    let singleLetterKeys = Tekkon.mapHanyuPinyin.keys.filter { $0.count == 1 }.sorted()
    #expect(singleLetterKeys == ["a", "e", "o", "q"], "實得：\(singleLetterKeys)")
    // 前 3 條（a／e／o）確為合法之漢語拼音音節；`q` 不是。
    #expect(Tekkon.mapHanyuPinyin["a"] == "ㄚ")
    #expect(Tekkon.mapHanyuPinyin["e"] == "ㄜ")
    #expect(Tekkon.mapHanyuPinyin["o"] == "ㄛ")
  }

  // MARK: 成員資格

  @Test("isComplete 恆蘊含 isPrefix")
  func completeAlwaysImpliesPrefix() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    for reading in index.readings {
      #expect(index.isComplete(reading))
      #expect(index.isPrefix(reading))
    }
    #expect(Tekkon.SyllableIndex.allReadings.allSatisfy { index.isComplete($0) })
  }

  @Test("completions(of:) 之內容與排序穩定")
  func completionsAreSortedAndStable() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    // 完整讀音：僅回傳自身。
    #expect(index.completions(of: "ㄍㄚ") == ["ㄍㄚ"])
    // 空字串：全部 427 條（`hasPrefix("")` 恆真）。此與 `isPrefix("") == false` 並不矛盾
    // ——後者是「非空」之定義，前者是列舉之定義。
    #expect(index.completions(of: "").count == 427)
    #expect(!index.isPrefix(""))
    // 非前綴：空集。
    #expect(index.completions(of: "ㄍㄋ").isEmpty)
    #expect(index.completions(of: "zzz").isEmpty)
    // 升冪、且與兩次呼叫之結果一致。
    for prefix in ["ㄍ", "ㄓ", "ㄧ", "ㄈㄧ"] {
      let result = index.completions(of: prefix)
      #expect(!result.isEmpty, "\(prefix) 應有延伸")
      #expect(result == result.sorted())
      #expect(result == index.completions(of: prefix))
      #expect(result.allSatisfy { $0.hasPrefix(prefix) })
    }
    #expect(index.completions(of: "ㄍ").count > 1)
  }

  @Test("測試素材之全部無調詞幹皆為完整讀音")
  func testTableStemsAreAllCompleteReadings() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    let toneMarks: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙", " "]
    var stems: Set<String> = []
    for line in testTable4DynamicLayouts.split(separator: "\n").dropFirst() {
      let parts = line.split(separator: " ").map { $0.replacingOccurrences(of: "_", with: " ") }
      guard let first = parts.first else { continue }
      var reading = String(first)
      if let last = reading.last, toneMarks.contains(last) { reading.removeLast() }
      stems.insert(reading)
    }
    #expect(stems.count == 422)
    // 強於「成員或其前綴」：全部皆為**完整讀音**。
    let notComplete = stems.filter { !index.isComplete($0) }
    #expect(notComplete.isEmpty, "非完整讀音者：\(notComplete.sorted())")
    // 反向落差：字典有而素材無者恰為 5 條。
    #expect(
      Set(index.readings).subtracting(stems).sorted()
        == ["ㄈㄨㄥ", "ㄍㄧ", "ㄍㄨㄜ", "ㄎㄧㄡ", "ㄘㄟ"]
    )
  }

  // MARK: 共用快取

  @Test("共用索引與排列無關")
  func sharedIndexIsParserNeutral() {
    let parsers: [Tekkon.MandarinParser] = [
      .ofDachen, .ofDachen26, .ofETen, .ofHanyuPinyin, .ofWadeGilesPinyin,
    ]
    let readings = parsers.map { Tekkon.SyllableIndex.shared(parser: $0).readings }
    #expect(Set(readings.map { $0.count }) == [427])
    for list in readings { #expect(list == readings[0]) }
    // 清快取之後仍可重建，且內容不變。
    Tekkon.SyllableIndex.clearSharedCache()
    let rebuilt = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    #expect(rebuilt.readings == readings[0])
    #expect(rebuilt.isPrefix("ㄍ"))
    #expect(!rebuilt.isPrefix("ㄍㄋ"))
    #expect(rebuilt.isComplete("ㄍㄚ"))
    #expect(!rebuilt.isComplete("ㄍ"))
  }
}
