// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Arimitsu
import Testing

@Suite
struct ArimitsuTranslatorTests {
  // MARK: Internal

  @Test("[Arimitsu] 首鍵僅入緩衝、次鍵方成碼")
  func testTwoKeySequence() async throws {
    var translator = makeTranslator()
    #expect(translator.isIdle)
    #expect(translator.ingest("v") == .bufferOnly(firstKey: "v"))
    #expect(translator.isPending)
    #expect(translator.displayText == "v")
    #expect(translator.ingest("s") == .translate(firstKey: "v", secondKey: "s", stems: ["zhong"]))
    #expect(translator.isIdle)
    #expect(translator.displayText.isEmpty)
    #expect(translator.siblingStems.isEmpty)
  }

  @Test("[Arimitsu] 非本方案鍵位空間之鍵一律穿透")
  func testPassthrough() async throws {
    var translator = makeTranslator()
    for key in ["1", "2", "3", "4", "5", " ", ",", ".", "-", "ˊ"] as [Character] {
      #expect(translator.ingest(key) == .passthrough, "\(key)")
      #expect(translator.isIdle)
    }
    // GB/T 34947-2017 之鍵位空間不含分號。
    var gbtTranslator = makeTranslator(.gbt17)
    #expect(gbtTranslator.ingest(";") == .passthrough)
    #expect(gbtTranslator.ingest("b") == .bufferOnly(firstKey: "b"))
  }

  @Test("[Arimitsu] 兩鍵不成碼者報 invalid")
  func testInvalidPair() async throws {
    let schema = DualpinParser.mspy
    let report = schema.validate()
    // 尋一組「合法首鍵＋不可能次鍵」之實鍵序：不假設任何特定鍵位之細節。
    guard let firstKey = report.codeToStems.keys.compactMap(\.first).min(),
          let secondKey = schema.alphabet.sorted().first(where: { candidate in
            !report.codeToStems.keys.contains("\(firstKey)\(candidate)")
              && !report.aliasCodeToStems.keys.contains("\(firstKey)\(candidate)")
          })
    else {
      Issue.record("無法自方案中尋得不成碼之鍵序。")
      return
    }
    var translator = makeTranslator()
    #expect(translator.ingest(firstKey) == .bufferOnly(firstKey: firstKey))
    #expect(translator.ingest(secondKey) == .invalid(firstKey: firstKey, secondKey: secondKey))
    #expect(translator.isIdle)
    #expect(translator.siblingStems.isEmpty)
  }

  @Test("[Arimitsu] 不可能起碼之首鍵當場作廢")
  func testInvalidFirstKey() async throws {
    var translator = makeTranslator()
    // 微軟雙拼之零聲母前綴鍵為 `o`（啊＝`oa`），故 `a`／`e`／`;` 三者皆只能居次鍵之位。
    for key in ["a", "e", ";"] as [Character] {
      #expect(translator.ingest(key) == .invalidFirstKey(firstKey: key), "\(key)")
      #expect(translator.isIdle, "\(key)")
    }
    #expect(translator.firstKeys.contains("o"))
    #expect(translator.firstKeys.isDisjoint(with: ["a", "e", ";"] as Set<Character>))
  }

  @Test("[Arimitsu] 重碼：首選入組音區、其餘駐留於翻譯器")
  func testDuplicateCodeStems() async throws {
    var translator = makeTranslator()
    #expect(translator.ingest("k") == .bufferOnly(firstKey: "k"))
    #expect(translator.ingest("d") == .translate(
      firstKey: "k", secondKey: "d", stems: ["kiang", "kuang"]
    ))
    #expect(translator.siblingStems == ["kuang"])
    #expect(translator.consumeSiblingStems() == ["kuang"])
    #expect(translator.siblingStems.isEmpty)
  }

  @Test("[Arimitsu] flush 只清待配之首鍵；resetAll 兼清駐留詞幹")
  func testFlush() async throws {
    var translator = makeTranslator()
    _ = translator.ingest("k")
    translator.flush()
    #expect(translator.isIdle)
    // flush 之後仍可正常起新碼。
    #expect(translator.ingest("n") == .bufferOnly(firstKey: "n"))
    #expect(translator.ingest("i") == .translate(firstKey: "n", secondKey: "i", stems: ["ni"]))

    // 駐留詞幹之生死與其音節同步：音節尚在組音區時，flush 不得殃及；
    // 唯有整個組字歷程遭廢棄（resetAll）時方一併清空。
    var second = makeTranslator()
    _ = second.ingest("k")
    _ = second.ingest("d")
    #expect(second.siblingStems == ["kuang"])
    second.flush()
    #expect(second.siblingStems == ["kuang"], "flush 不應殃及已進組音區之音節的駐留詞幹。")
    second.resetAll()
    #expect(second.siblingStems.isEmpty)
  }

  @Test("[Arimitsu] 連綴多碼")
  func testConsecutiveCodes() async throws {
    var translator = makeTranslator()
    _ = translator.ingest("n")
    #expect(translator.ingest("i") == .translate(firstKey: "n", secondKey: "i", stems: ["ni"]))
    _ = translator.ingest("h")
    #expect(translator.ingest("k") == .translate(firstKey: "h", secondKey: "k", stems: ["hao"]))
    #expect(translator.isIdle)
  }

  @Test("[Arimitsu] MSPY 之 11 個帶分號之 ing 音節皆得碼")
  func testSemicolonCodes() async throws {
    let report = DualpinParser.mspy.validate()
    let semicolonCodes = report.codeToStems.keys.filter { $0.contains(";") }.sorted()
    #expect(semicolonCodes.count == 11)
    for code in semicolonCodes {
      var translator = makeTranslator()
      let keys = Array(code)
      #expect(translator.ingest(keys[0]) == .bufferOnly(firstKey: keys[0]))
      guard case let .translate(_, _, stems) = translator.ingest(keys[1]) else {
        Issue.record("\(code) 未得碼。")
        continue
      }
      #expect(stems == report.codeToStems[code])
    }
  }

  @Test("[Arimitsu] 方案宣告之別名碼亦成碼")
  func testAliasCode() async throws {
    // 別名係 schema 之既有欄位（E5 校驗、`encode`／`decode` 皆認）：宣告者須於打字當下同樣吃鍵。
    // 內建之兩方案皆不宣告別名——微軟雙拼之零聲母前綴鍵為 `o`（啊＝`oa`），無任何碼起於 `a`。
    var aliasedSchema = DualpinParser.mspy
    aliasedSchema.rawID = "dualPin.TestAlias"
    aliasedSchema.aliases = ["aa": "a"]
    let aliasedReport = aliasedSchema.validate()
    #expect(aliasedReport.errors.isEmpty, "\(aliasedReport.errors)")
    #expect(aliasedReport.aliasCodeToStems == ["aa": ["a"]])
    // 主碼不動：別名只增可接受之輸入，不改本方案之編碼輸出。
    #expect(aliasedSchema.code(forStem: "a") == "oa")
    #expect(aliasedSchema.encode(stem: "a") == ["oa", "aa"])
    #expect(aliasedSchema.decode(code: "aa") == ["a"])

    var translator = makeTranslator(aliasedSchema)
    #expect(translator.ingest("a") == .bufferOnly(firstKey: "a"))
    #expect(translator.ingest("a") == .translate(firstKey: "a", secondKey: "a", stems: ["a"]))
    #expect(translator.isIdle)

    // 未經方案宣告者則連首鍵都不成立——微軟雙拼之實鍵序「aa」即是此況：其 `a` 不成首鍵，
    // 故「aa」連湊碼之機會都無（★ P310）。
    var undeclaredTranslator = makeTranslator()
    #expect(undeclaredTranslator.ingest("a") == .invalidFirstKey(firstKey: "a"))
    #expect(undeclaredTranslator.isIdle)
  }

  // MARK: Private

  private func makeTranslator(_ schema: DualpinParser = .mspy) -> DualpinTranslator {
    DualpinTranslator(report: schema.validate(), alphabet: schema.alphabet)
  }
}
