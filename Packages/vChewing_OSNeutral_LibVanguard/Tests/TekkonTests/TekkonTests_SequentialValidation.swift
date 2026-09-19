// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@testable import Tekkon
import Testing

// MARK: - TekkonTestsSequentialValidation

@MainActor
@Suite(.serialized)
struct TekkonTestsSequentialValidation {
  @Test("[Tekkon] RawKeyOrder_StaticLayouts")
  func testStaticLayouts() async throws {
    // 靜態注音排列：逐鍵即為逐個注音，依序鍵入者恆應合格。首六筆皆為「ㄅㄚˇ」。
    let cases: [(Tekkon.MandarinParser, String, Bool)] = [
      (.ofDachen, "183", true),
      (.ofETen, "ba3", true),
      (.ofIBM, "1f,", true),
      (.ofMiTAC, "ba3", true),
      (.ofSeigyou, "28a", true),
      (.ofFakeSeigyou, "28a", true),
      (.ofDachen, "cl", true), // ㄏㄠ
      (.ofDachen, "1u,", true), // ㄅㄧㄝ
      (.ofDachen, "5j/ ", true), // ㄓㄨㄥ
      (.ofDachen, "xup6", true), // ㄌㄧㄣˊ
      (.ofDachen, "hl3", true), // ㄘㄠˇ
      (.ofDachen, "ll", true), // 同值之重複寫入不留痕跡、不構成違序
      (.ofDachen, "lc", false), // 先韻後聲：倒序
      (.ofDachen, "us", false), // 先介後聲：倒序
      (.ofDachen, "3u", false), // 聲調前置
      (.ofDachen, "44", false), // 僅聲調、不可唸
      (.ofDachen, "C", false), // 非該排列之按鍵
      (.ofDachen, "幹", false), // 非按鍵
      (.ofDachen, "", false), // 空序列
      (.ofDachen, " ", false), // 僅陰平
    ]
    for (parser, input, expected) in cases {
      let composer = Tekkon.Composer(arrange: parser)
      #expect(
        composer.isSequentiallyTypedRawKeyOrder(input) == expected,
        "\(parser.nameTag) \"\(input)\" 應為 \(expected)"
      )
    }
  }

  /// 覆寫修正（以另一鍵改寫既有槽值）於預設模式下判不合格；`suffixOnly` 模式下放寬之。
  @Test("[Tekkon] RawKeyOrder_OverwriteCorrectionAndSuffixOnly")
  func testOverwriteCorrectionAndSuffixOnly() async throws {
    let cases: [(Tekkon.MandarinParser, String, Bool, Bool)] = [
      // 排列、鍵序、預設（嚴）期望、suffixOnly 期望
      (.ofDachen, "cl", true, true),
      (.ofDachen, "dcl", false, true), // ㄎ→ㄏ 以另一鍵覆寫修正
      (.ofDachen, "qn", false, true), // ㄆ→ㄙ 以另一鍵覆寫修正
      (.ofDachen, "cl34", false, true), // 聲調 ˇ→ˋ 以另一鍵覆寫
      (.ofDachen, "ll", true, true), // 同值重寫：無可觀測變化
      (.ofDachen, "lc", false, false), // 倒序：兩模式皆不合格
      (.ofDachen26, "qquu", true, true), // 同鍵重寫：排列自身編碼所必需
      (.ofDachen26, "uuu", true, true),
      (.ofDachen26, "mm", true, true),
      (.ofETen26, "ge", true, true), // ㄓ→ㄐ：引擎自身之跨鍵糾正（動態排列之編碼路徑；條件五不在其限）
      (.ofHanyuPinyin, "su3", true, true),
      (.ofHanyuPinyin, "suan", true, true),
      (.ofHanyuPinyin, "3su", false, false),
    ]
    for (parser, input, expectedStrict, expectedSuffixOnly) in cases {
      let composer = Tekkon.Composer(arrange: parser)
      #expect(
        composer.isSequentiallyTypedRawKeyOrder(input) == expectedStrict,
        "\(parser.nameTag) \"\(input)\" 於預設模式應為 \(expectedStrict)"
      )
      #expect(
        composer.isSequentiallyTypedRawKeyOrder(input, suffixOnly: true) == expectedSuffixOnly,
        "\(parser.nameTag) \"\(input)\" 於 suffixOnly 模式應為 \(expectedSuffixOnly)"
      )
    }
  }

  @Test("[Tekkon] RawKeyOrder_DynamicLayouts_Typical")
  func testDynamicLayoutsTypical() async throws {
    let cases: [(Tekkon.MandarinParser, String, Bool)] = [
      (.ofDachen26, "qquu", true), // ㄅㄚ（首擊為ㄆ、次擊覆寫為ㄅ）
      (.ofDachen26, "qquur", true), // ㄅㄚˇ
      (.ofDachen26, "uuu", true), // ㄧㄚ（末擊補回介母）
      (.ofDachen26, "mm", true), // ㄩ（首擊為ㄡ、次擊覆寫為ㄩ）
      (.ofDachen26, "uuqq", false), // 亂序
      (.ofDachen26, "qqruu", false), // 聲調前置
      (.ofETen26, "baj", true), // ㄅㄚˇ
      (.ofHsu, "byf", true), // ㄅㄚˇ
      (.ofStarlight, "ba8", true), // ㄅㄚˇ
      (.ofAlvinLiu, "baj", true), // ㄅㄚˇ
    ]
    for (parser, input, expected) in cases {
      let composer = Tekkon.Composer(arrange: parser)
      #expect(
        composer.isSequentiallyTypedRawKeyOrder(input) == expected,
        "\(parser.nameTag) \"\(input)\" 應為 \(expected)"
      )
    }
  }

  /// 動態注音排列之合法編碼散見於測試素材；逐筆檢證其皆應被 `suffixOnly` 模式接受。
  @Test("[Tekkon] RawKeyOrder_DynamicLayouts_Corpus")
  func testDynamicLayoutsCorpus() async throws {
    let parserOrder: [Tekkon.MandarinParser] = [.ofDachen26, .ofETen26, .ofHsu, .ofStarlight, .ofAlvinLiu]
    var typings: [[String]] = .init(repeating: [], count: parserOrder.count)
    testTable4DynamicLayouts.split(separator: "\n").dropFirst().forEach { line in
      let cells = line.split(separator: " ").map { $0.replacingOccurrences(of: "_", with: " ") }
      guard cells.count > parserOrder.count else { return }
      for index in parserOrder.indices {
        let typing = cells[index + 1]
        guard !typing.hasPrefix("`") else { continue }
        typings[index].append(typing)
      }
    }
    for (index, parser) in parserOrder.enumerated() {
      var rejected: [String] = []
      for typing in typings[index] where !Tekkon.Composer(arrange: parser)
        .isSequentiallyTypedRawKeyOrder(typing, suffixOnly: true) {
        rejected.append(typing)
      }
      #expect(
        rejected.isEmpty,
        "\(parser.nameTag) 有 \(rejected.count) 筆合法編碼未被接受：\(rejected.prefix(8))"
      )
    }
  }

  @Test("[Tekkon] RawKeyOrder_PinyinLayouts")
  func testPinyinLayouts() async throws {
    let cases: [(Tekkon.MandarinParser, String, Bool)] = [
      (.ofHanyuPinyin, "su3", true),
      (.ofHanyuPinyin, "suan", true),
      (.ofHanyuPinyin, "suan3", true),
      (.ofHanyuPinyin, "su", true),
      (.ofHanyuPinyin, "su ", true),
      (.ofHanyuPinyin, "zhong", true),
      (.ofHanyuPinyin, "shi", true),
      (.ofHanyuPinyin, "nv", true),
      (.ofHanyuPinyin, "3su", false), // 聲調前置、為引擎所丟棄
      (.ofHanyuPinyin, "s u", false), // 聲調夾於字中、同遭丟棄
      (.ofHanyuPinyin, "sh", false), // 未成音節
      (.ofHanyuPinyin, "S", false), // 大寫非該排列之按鍵
      (.ofHanyuPinyin, "hello", false),
      (.ofHanyuPinyin, "us", false),
      (.ofSecondaryPinyin, "chiung2", true),
      (.ofSecondaryPinyin, "zhong", false),
      (.ofYalePinyin, "jung", true),
      (.ofYalePinyin, "suan", false),
      (.ofHualuoPinyin, "suan", true),
      (.ofUniversalPinyin, "suan", true),
      (.ofWadeGilesPinyin, "jung", true),
    ]
    for (parser, input, expected) in cases {
      let composer = Tekkon.Composer(arrange: parser)
      #expect(
        composer.isSequentiallyTypedRawKeyOrder(input) == expected,
        "\(parser.nameTag) \"\(input)\" 應為 \(expected)"
      )
    }
  }

  @Test("[Tekkon] RawKeyOrder_DoesNotMutateComposer")
  func testComposerIsNotMutated() async throws {
    var composer = Tekkon.Composer(arrange: .ofDachen)
    _ = composer.receiveSequence("hl3")
    var snapshotOfComposer = composer
    #expect(composer.isSequentiallyTypedRawKeyOrder("1u,"))
    #expect(composer == snapshotOfComposer)
    #expect(composer.isSequentiallyTypedRawKeyOrder("dcl", suffixOnly: true))
    #expect(composer == snapshotOfComposer)
    // 呼叫端之 CSVT 順序強制設定不應影響本 API 之判定（槽序由本 API 自行觀測）。
    composer.enforceCSVTOrdering = true
    snapshotOfComposer.enforceCSVTOrdering = true
    #expect(composer.isSequentiallyTypedRawKeyOrder("dcl", suffixOnly: true))
    #expect(composer == snapshotOfComposer)
  }
}
