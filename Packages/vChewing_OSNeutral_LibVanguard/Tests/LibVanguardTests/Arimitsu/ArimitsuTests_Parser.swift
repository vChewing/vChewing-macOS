// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Arimitsu
import Foundation
import Shared
import Tekkon
import Testing

// MARK: - ArimitsuBuiltinSchemaTests

@Suite
struct ArimitsuBuiltinSchemaTests {
  @Test("[Arimitsu] 內建方案之鍵位空間與方案 ID")
  func testBuiltinIdentity() async throws {
    #expect(DualpinParser.mspy.rawID == "dualPin.Microsoft")
    #expect(DualpinParser.gbt17.rawID == "dualPin.GBT17")
    #expect(DualpinParser.builtinParsers.count == 2)
    #expect(DualpinParser.builtinRawIDs == ["dualPin.Microsoft", "dualPin.GBT17"])
    #expect(DualpinParser.mspy.alphabet.contains(";"))
    #expect(!DualpinParser.gbt17.alphabet.contains(";"))
    #expect(DualpinParser.builtinParser(forRawID: "dualPin.GBT17") == DualpinParser.gbt17)
    // 其餘方案一律不內建，改由使用者自官網倉匯入（見 `DualpinSchemaStore`）。
    #expect(DualpinParser.builtinParser(forRawID: "dualPin.ZiranChou") == nil)
    #expect(DualpinParser.builtinParser(forRawID: "dualPin.Nonexistent") == nil)
  }

  @Test("[Arimitsu] 內建方案與 `KeyboardParser` 之值域對應")
  func testBuiltinKeyboardParserMapping() async throws {
    // 雙拼族之值域下界為自訂案（200），其後 201…202 依序對應兩個內建方案。
    let dualpinCases = KeyboardParser.allCases.filter(\.isDualpin)
    #expect(dualpinCases.count == DualpinParser.builtinParsers.count + 1)
    #expect(dualpinCases.map(\.rawValue).sorted() == Array(200 ... 202))
    #expect(KeyboardParser.ofDualpinCustom.rawValue == 200)
    #expect(KeyboardParser.ofDualpinMSPY.rawValue == 201)
    #expect(KeyboardParser.ofDualpinGBT17.rawValue == 202)
    #expect(UserDef.kKeyboardParser4Dualpin.validNumeralValueRange == 200 ... 202)
  }

  @Test("[Arimitsu] 內建方案之詞幹清單即 Tekkon 之公開清單")
  func testInventorySource() async throws {
    #expect(Tekkon.allHanyuPinyinStems.count == 426)
    #expect(DualpinParser.mspy.validate().stats.inventoryCount == 426)
  }

  @Test("[Arimitsu] 內建方案皆無錯誤、且 DIPE 靜默略過")
  func testBuiltinValidationIsClean() async throws {
    for schema in DualpinParser.builtinParsers {
      let report = schema.validate()
      #expect(report.errors.isEmpty, "\(schema.rawID)：\(report.errors)")
      #expect(report.isUsable)
      #expect(report.stats.codableCount == 425)
      #expect(report.stats.ignoredStems == ["eh"])
      #expect(report.issues.count == report.warnings.count)
      #expect(report.stemToCode["eh"] == nil)
      #expect(!report.stemToCode.isEmpty)
    }
  }

  @Test("[Arimitsu] 內建方案之重碼組數與自由槽位數")
  func testBuiltinDuplicateGroupsAndFreeSlots() async throws {
    let mspyReport = DualpinParser.mspy.validate()
    #expect(mspyReport.stats.duplicateCodeGroups.count == 3)
    #expect(mspyReport.stats.distinctCodeCount == 422)
    #expect(mspyReport.stats.freeSlotCount == 307)
    #expect(mspyReport.stats.duplicateCodeGroups["kd"]?.sorted() == ["kiang", "kuang"])
    #expect(mspyReport.stats.duplicateCodeGroups["lo"]?.sorted() == ["lo", "luo"])
    #expect(mspyReport.stats.duplicateCodeGroups["lr"]?.sorted() == ["luan", "lvan"])

    let gbtReport = DualpinParser.gbt17.validate()
    #expect(gbtReport.stats.duplicateCodeGroups.count == 5)
    #expect(gbtReport.stats.distinctCodeCount == 420)
    #expect(gbtReport.stats.freeSlotCount == 256)
    #expect(gbtReport.stats.duplicateCodeGroups["kn"]?.sorted() == ["kiang", "kuang"])
    #expect(gbtReport.stats.duplicateCodeGroups["ky"]?.sorted() == ["kiu", "kuai"])
    #expect(gbtReport.stats.duplicateCodeGroups["lw"]?.sorted() == ["luan", "lvan"])
    #expect(gbtReport.stats.duplicateCodeGroups["nv"]?.sorted() == ["nui", "nv"])
  }

  @Test("[Arimitsu] 內建方案無冗餘鍵、且無 W3／W4／W7／W8")
  func testBuiltinWarningsAbsent() async throws {
    for schema in DualpinParser.builtinParsers {
      let report = schema.validate()
      let codes = Set(report.warnings.map(\.code))
      #expect(!codes.contains(.W1))
      #expect(!codes.contains(.W3))
      #expect(!codes.contains(.W4))
      #expect(!codes.contains(.W5))
      #expect(!codes.contains(.W7))
      #expect(!codes.contains(.W8))
      #expect(report.stats.usedKeys == schema.alphabet)
      #expect(!schema.normalizationApplied)
    }
  }

  @Test("[Arimitsu] 讀音鍵恆為「無調之完整注音」")
  func testReadingKeysAreToneFreeZhuyin() async throws {
    #expect(DualpinParser.mspy.code(forStem: "zhong") == "vs")
    #expect(DualpinParser.mspy.code(forStem: "chuang") == "id")
    #expect(DualpinParser.mspy.code(forStem: "zhuang") == "vd")
    #expect(DualpinParser.mspy.code(forStem: "xue") == "xt")
    #expect(DualpinParser.mspy.code(forStem: "nv") == "ny")
    #expect(DualpinParser.mspy.code(forStem: "ao") == "ok")
    #expect(DualpinParser.mspy.code(forStem: "a") == "oa")
    #expect(DualpinParser.mspy.code(forStem: "eh") == nil)
    #expect(DualpinParser.gbt17.code(forStem: "chi") == "ii")
    #expect(DualpinParser.gbt17.code(forStem: "ao") == "ac")
    #expect(DualpinParser.gbt17.code(forStem: "xue") == "xx")
    #expect(DualpinParser.gbt17.code(forStem: "eh") == nil)
  }

  @Test("[Arimitsu] 編解碼互逆")
  func testEncodeDecodeRoundTrip() async throws {
    for schema in DualpinParser.builtinParsers {
      let report = schema.validate()
      #expect(report.stemToCode.count == 425)
      for (stem, code) in report.stemToCode {
        #expect(report.codeToStems[code]?.contains(stem) == true, "\(schema.rawID)：\(stem)")
        #expect(schema.encode(stem: stem).contains(code), "\(schema.rawID)：\(stem) → \(code)")
      }
      // 反向：抽查若干碼能否解回詞幹。
      for code in ["vs", "id", "ni", "hk"] where report.codeToStems[code] != nil {
        for stem in report.codeToStems[code] ?? [] {
          #expect(schema.decode(code: code).contains(stem), "\(schema.rawID)：\(code) → \(stem)")
        }
      }
      // `eh`（感嘆詞）係 DIPE，永不入詞幹表；惟「照原樣之雙字母」政策下仍可編成自身。
      #expect(report.stemToCode["eh"] == nil)
      #expect(schema.encode(stem: "eh").isEmpty || schema.encode(stem: "eh") == ["eh"])
      #expect(schema.decode(code: "a;").isEmpty)
    }
  }

  @Test("[Arimitsu] 首鍵之全等碼義（限首鍵之位；非前綴詞幹，亦不含次鍵之韻母）")
  func testFirstKeyMeaningsAreFullMatches() async throws {
    // 首鍵之位只可能是聲母：`v` 為聲母 `zh`（韻母 `ui` 雖亦以 `v` 為鍵，然屬次鍵之位，不列）。
    let mspy = DualpinParser.mspy
    #expect(mspy.meanings(ofKey: "v") == ["zh"])
    #expect(mspy.meanings(ofKey: "i") == ["ch"])
    #expect(mspy.meanings(ofKey: "k") == ["k"])
    #expect(mspy.meanings(ofKey: "u") == ["sh"])
    // 零聲母鍵另予記號：`o` 於首鍵之位表「此音節無聲母」，不是表內單位。
    #expect(mspy.meanings(ofKey: "o") == [DualpinParser.nullOnsetMarker])
    // 前綴窮舉之反例：`v` 若作前綴即得 `zha`…`zhuo` 二十條，此處一律不列。
    #expect(!mspy.meanings(ofKey: "v").contains("zhong"))
    #expect(mspy.meanings(ofKey: "?") == [])

    let gbt17 = DualpinParser.gbt17
    #expect(gbt17.meanings(ofKey: "a") == [DualpinParser.nullOnsetMarker])
    #expect(gbt17.meanings(ofKey: "v") == ["zh"])

    // `.finalInitial`：零聲母以餘部首字元為首鍵，故該鍵之義即「以該字元起首之諸韻母」。
    let finalInitial = DualpinParser(
      rawID: "dualPin.TestFinalInitial",
      rawTitle: "TestFinalInitial",
      initials: ["b": "b"],
      finals: ["a": "x", "ai": "y", "an": "z"],
      nullOnset: .finalInitial
    )
    #expect(finalInitial.meanings(ofKey: "a") == ["a", "ai", "an"])
    #expect(finalInitial.meanings(ofKey: "b") == ["b"])
    // 反例：韻母鍵（`x` 為韻母 `a`）不作首鍵，故於首鍵之位無義。
    #expect(finalInitial.meanings(ofKey: "x") == [])
  }

  @Test("[Arimitsu] 方案 JSON 往返無損")
  func testSchemaCodableRoundTrip() async throws {
    for schema in DualpinParser.builtinParsers {
      let encoded = try JSONEncoder().encode(schema)
      let decoded = try JSONDecoder().decode(DualpinParser.self, from: encoded)
      #expect(decoded == schema)
      // 使用者自備之方案走完全相同的 decoder：內建 JSON 原文即格式範例。
      let rebuilt = DualpinParser.builtin(
        fromJSON: String(data: encoded, encoding: .utf8) ?? "",
        named: schema.rawID
      )
      #expect(rebuilt == schema)
      #expect(rebuilt.validate().errors.isEmpty)
    }
  }

  @Test("[Arimitsu] 標題之五級退路解析")
  func testTitleFallback() async throws {
    let mspy = DualpinParser.mspy
    #expect(mspy.title(forLocaleTag: "zh-Hant") == "微軟雙拼")
    #expect(mspy.title(forLocaleTag: "zh-Hant-TW") == "微軟雙拼")
    #expect(mspy.title(forLocaleTag: "zh_Hant") == "微軟雙拼")
    #expect(mspy.title(forLocaleTag: "en") == "Microsoft")
    #expect(mspy.title(forLocaleTag: "en-US") == "Microsoft")
    #expect(mspy.title(forLocaleTag: "fr") == "Microsoft")
    #expect(mspy.title(forLocaleTag: "") == "Microsoft")
    #expect(mspy.title(forLocaleTag: "zh-Hans") == "微软双拼")
    #expect(DualpinParser.gbt17.title(forLocaleTag: "zh-Hant") == "GB/T 34947-2017")

    // ②→⑤：無 en 時退至 rawTitle。
    let bare = DualpinParser(
      rawID: "dualPin.Bare",
      rawTitle: "無譯名",
      localizedTitle: ["ja": "テスト"],
      initials: ["b": "b"],
      finals: ["a": "a"],
      nullOnset: .fixedKey("o"),
      overrides: ["ba": "ba"]
    )
    #expect(bare.title(forLocaleTag: "ja-JP") == "テスト")
    #expect(bare.title(forLocaleTag: "zh-Hant") == "無譯名")
  }
}

// MARK: - ArimitsuValidationTests

@Suite
struct ArimitsuValidationTests {
  // MARK: Internal

  @Test("[Arimitsu] 基底方案於基底詞幹清單下全無問題")
  func testBaselineIsClean() async throws {
    let report = makeSchema().validate(inventory: probeInventory)
    #expect(report.issues.isEmpty, "\(report.issues)")
    #expect(report.isUsable)
    #expect(report.stats.codableCount == 8)
    #expect(report.stats.ignoredStems == ["eh"])
  }

  @Test("[Arimitsu] E1：碼用及兩表未給之鍵")
  func testE1() async throws {
    // 可用之鍵既由兩表推算，唯 `overrides` 能生出表外之鍵。
    let schema = makeSchema(overrides: ["ba": "b1"])
    let report = schema.validate(inventory: ["ba"])
    #expect(report.errors.map(\.code).contains(.E1))
    #expect(report.errors.first?.detail.contains("1") == true)
  }

  @Test("[Arimitsu] E3：詞幹無法得碼而未列於 acknowledgedUnreachable")
  func testE3() async throws {
    let incapable = makeSchema(initials: ["b": "b"])
    let report = incapable.validate(inventory: ["ba", "sha", "eh"])
    #expect(report.errors.map(\.code) == [.E3])
    #expect(report.errors.first?.detail.contains("sha") == true)

    let forgiven = makeSchema(initials: ["b": "b"], acknowledgedUnreachable: ["sha"])
    let forgivenReport = forgiven.validate(inventory: ["ba", "sha", "eh"])
    #expect(forgivenReport.errors.isEmpty)
    #expect(forgivenReport.warnings.map(\.code).contains(.W1))
    #expect(forgivenReport.stats.ignoredStems == ["eh"])
  }

  @Test("[Arimitsu] E4：可用之鍵含聲調鍵")
  func testE4() async throws {
    // 聲調鍵經兩表之值進入可用之鍵。
    let schema = makeSchema(initials: ["b": "b"], finals: ["a": "1"])
    #expect(codes(schema, inventory: ["ba"]).contains(.E4))
  }

  @Test("[Arimitsu] E5：別名與既有碼相撞")
  func testE5() async throws {
    let schema = makeSchema(aliases: ["ba": "sha"])
    #expect(codes(schema).contains(.E5))
  }

  @Test("[Arimitsu] E6：keyInterception 所列之鍵不在 alphabet 內")
  func testE6() async throws {
    let schema = makeSchema(keyInterception: .explicit(["z"]))
    #expect(codes(schema).contains(.E6))
  }

  @Test("[Arimitsu] E7：rawTitle 為空")
  func testE7() async throws {
    #expect(codes(makeSchema(rawTitle: " ")).contains(.E7))
  }

  @Test("[Arimitsu] E8：override 之碼非二鍵")
  func testE8() async throws {
    #expect(codes(makeSchema(overrides: ["ba": "b"])).contains(.E8))
    #expect(codes(makeSchema(overrides: ["ba": "ba"])).isEmpty)
  }

  @Test("[Arimitsu] E9：rawID 非 DNS 名或相衝")
  func testE9() async throws {
    #expect(codes(makeSchema(rawID: "")).contains(.E9))
    #expect(codes(makeSchema(rawID: "Test")).contains(.E9))
    #expect(codes(makeSchema(rawID: "dualPin.Microsoft")).contains(.E9))
    let conflicted = makeSchema(rawID: "dualPin.Mine").validate(
      inventory: ["ba"], conflictingRawIDs: ["dualPin.Mine"]
    )
    #expect(conflicted.errors.map(\.code).contains(.E9))
    // 內建方案校驗自身時不算相衝：即使把內建 IDs 全列為「現存方案」亦然。
    #expect(DualpinParser.mspy.validate(conflictingRawIDs: DualpinParser.builtinRawIDs).errors.isEmpty)
    #expect(DualpinParser.gbt17.validate(conflictingRawIDs: DualpinParser.builtinRawIDs).errors.isEmpty)
    // 惟自備方案冒用內建之 rawID 仍屬相衝（此處以內建原文換上他人之 rawID 造出冒名者）。
    let spoofingBuiltin = DualpinParser.builtin(
      fromJSON: DualpinParser.mspySchemaJSON
        .replacingOccurrences(of: "dualPin.Microsoft", with: "dualPin.GBT17"),
      named: "冒名方案"
    )
    #expect(spoofingBuiltin.validate(conflictingRawIDs: []).errors.map(\.code).contains(.E9))
  }

  @Test("[Arimitsu] W2：重碼為警訊而非錯誤")
  func testW2() async throws {
    let schema = makeSchema(initials: ["b": "b"], finals: [
      "a": "a", "b": "a",
    ])
    let report = schema.validate(inventory: ["ba", "bb"])
    #expect(report.errors.isEmpty)
    #expect(report.warnings.map(\.code).contains(.W2))
    #expect(report.stats.duplicateCodeGroups["ba"]?.sorted() == ["ba", "bb"])
  }

  @Test("[Arimitsu] W3：碼用及主機保留鍵而未列於 keyInterception")
  func testW3() async throws {
    let schema = makeSchema(initials: ["b": "b"], finals: [
      "a": "a", "b": "`",
    ])
    let report = schema.validate(inventory: ["ba", "bb"])
    #expect(report.warnings.map(\.code).contains(.W3))
    let intercepted = makeSchema(
      initials: ["b": "b"],
      finals: [
        "a": "a",
        "b": "`",
      ],
      keyInterception: .explicit(["`"])
    )
    let interceptedReport = intercepted.validate(inventory: ["ba", "bb"])
    #expect(!interceptedReport.warnings.map(\.code).contains(.W3))
  }

  @Test("[Arimitsu] W4：載入時對 n／l 之後之 ü 作正規化")
  func testW4() async throws {
    let normalized = DualpinParser.builtin(
      fromJSON: #"{"rawID":"dualPin.W4","rawTitle":"W4","initials":{"n":"n"},"finals":{"ü":"a"},"nullOnset":"o","overrides":{"nü":"ba"}}"#,
      named: "W4"
    )
    #expect(normalized.normalizationApplied)
    #expect(normalized.overrides["nv"] == "ba")
    #expect(normalized.validate(inventory: ["nv"]).warnings.map(\.code).contains(.W4))
    #expect(DualpinParser.normalizeSpelling("nüe") == "nve")
    #expect(DualpinParser.normalizeSpelling("lüan") == "lvan")
    #expect(DualpinParser.normalizeSpelling("nu") == "nu")
  }

  @Test("[Arimitsu] W5：兩表所給之鍵未被任何碼用到")
  func testW5() async throws {
    let schema = makeSchema(
      initials: ["b": "b"],
      finals: ["a": "a", "ha": "z"]
    )
    // 詞幹清單內無以「ha」收尾者，「z」遂為表列而不用之鍵。
    #expect(codes(schema, inventory: ["ba"]).contains(.W5))
  }

  @Test("[Arimitsu] W7：autochopPolicy 非 .disabled 仍可接受、但不靜默降級")
  func testW7() async throws {
    let schema = makeSchema(autochopPolicy: .backtrackToShorterReading)
    let report = schema.validate(inventory: ["ba"])
    #expect(report.errors.isEmpty)
    #expect(report.warnings.map(\.code).contains(.W7))
  }

  @Test("[Arimitsu] W8：localizedTitle 缺 en")
  func testW8() async throws {
    let schema = makeSchema(localizedTitle: ["zh-Hant": "測試"])
    #expect(codes(schema).contains(.W8))
  }

  // MARK: Private

  /// 供校驗用之基底詞幹清單。
  private let probeInventory = ["ba", "sha", "zha", "da", "sa", "ga", "oa", "aa", "eh"]

  /// 造一份「除指定缺陷外皆合法」之方案。
  private func makeSchema(
    rawID: String = "dualPin.Test",
    rawTitle: String = "測試方案",
    localizedTitle: [String: String] = ["en": "Test", "zh-Hant": "測試"],
    initials: [String: Character] = [
      "b": "b",
      "sh": "u",
      "zh": "v",
      "d": "d",
      "s": "s",
      "g": "g",
      "o": "o",
      "a": "a",
    ],
    finals: [String: Character] = ["a": "a"],
    nullOnset: DualpinParser.NullOnsetPolicy = .fixedKey("o"),
    keyInterception: DualpinParser.KeyInterception = .none,
    autochopPolicy: DualpinParser.AutochopPolicy = .disabled,
    overrides: [String: String] = [:],
    aliases: [String: String] = [:],
    acknowledgedUnreachable: Set<String> = []
  )
    -> DualpinParser {
    DualpinParser(
      rawID: rawID, rawTitle: rawTitle, localizedTitle: localizedTitle,
      initials: initials, finals: finals, nullOnset: nullOnset,
      keyInterception: keyInterception,
      autochopPolicy: autochopPolicy, overrides: overrides, aliases: aliases,
      acknowledgedUnreachable: acknowledgedUnreachable
    )
  }

  private func codes(
    _ schema: DualpinParser,
    inventory: [String]? = nil
  )
    -> Set<DualpinValidationReport.Code> {
    Set(schema.validate(inventory: inventory ?? probeInventory).issues.map(\.code))
  }
}
