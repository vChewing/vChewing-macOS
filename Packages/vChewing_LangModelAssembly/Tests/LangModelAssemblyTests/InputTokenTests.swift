// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LMAssemblyMaterials4Tests
import XCTest

@testable import LangModelAssembly

final class InputTokenTests: XCTestCase {
  func testTranslatingTokens_1_TimeZone() throws {
    print("測試時區俗稱：" + "MACRO@TIMEZONE_SHORTENED".parseAsInputToken(isCHS: false).description)
    print("測試時區全稱：" + "MACRO@TIMEZONE".parseAsInputToken(isCHS: false).description)
  }

  func testTranslatingTokens_2_TimeNow() throws {
    print("測試時間時分：" + "MACRO@TIME_SHORTENED".parseAsInputToken(isCHS: false).description)
    print("測試帶秒時間：" + "MACRO@TIME".parseAsInputToken(isCHS: true).description)
  }

  func testTranslatingTokens_3_Date() throws {
    print("測試農曆：" + "MACRO@DATE_LUNA".parseAsInputToken(isCHS: true).description)
    print("測試二戰勝利紀年：" + "MACRO@DATE_YEARDELTA:-1945".parseAsInputToken(isCHS: true).description)
    print(
      "測試短日期之135天前：" + "MACRO@DATE_DAYDELTA:-135_SHORTENED".parseAsInputToken(isCHS: true)
        .description
    )
    print("測試長日期之135天前：" + "MACRO@DATE_DAYDELTA:-135".parseAsInputToken(isCHS: true).description)
    print("測試短日期之今天：" + "MACRO@DATE_SHORTENED".parseAsInputToken(isCHS: true).description)
    print("測試長日期之今天：" + "MACRO@DATE".parseAsInputToken(isCHS: true).description)
    print(
      "測試短日期之明天：" + "MACRO@DATE_SHORTENED_DAYDELTA:1".parseAsInputToken(isCHS: true)
        .description
    )
    print("測試長日期之明天：" + "MACRO@DATE_DAYDELTA:1".parseAsInputToken(isCHS: true).description)
    print(
      "測試短日期之明年：" + "MACRO@DATE_SHORTENED_YEARDELTA:1".parseAsInputToken(isCHS: true)
        .description
    )
    print("測試長日期之明年：" + "MACRO@DATE_YEARDELTA:1".parseAsInputToken(isCHS: true).description)
  }

  func testTranslatingTokens_4_Week() throws {
    print("測試今天星期幾：" + "MACRO@WEEK".parseAsInputToken(isCHS: false).description)
    print("測試今天週幾：" + "MACRO@WEEK_SHORTENED".parseAsInputToken(isCHS: false).description)
    print("測試明天星期幾：" + "MACRO@WEEK_DAYDELTA:1".parseAsInputToken(isCHS: false).description)
    print("測試明天週幾：" + "MACRO@WEEK_SHORTENED_DAYDELTA:1".parseAsInputToken(isCHS: false).description)
    print("測試後天星期幾：" + "MACRO@WEEK_DAYDELTA:+2".parseAsInputToken(isCHS: false).description)
    print(
      "測試後天週幾：" + "MACRO@WEEK_SHORTENED_DAYDELTA:+2".parseAsInputToken(isCHS: false)
        .description
    )
  }

  func testTranslatingTokens_5_Year() throws {
    print("測試今年：" + "MACRO@YEAR".parseAsInputToken(isCHS: false).description)
    print("測試今年干支：" + "MACRO@YEAR_GANZHI".parseAsInputToken(isCHS: false).description)
    print("測試今年生肖：" + "MACRO@YEAR_ZODIAC".parseAsInputToken(isCHS: false).description)
    print("測試一千年以前：" + "MACRO@YEAR_YEARDELTA:-1000".parseAsInputToken(isCHS: false).description)
    print(
      "測試一千年以前干支：" + "MACRO@YEAR_GANZHI_YEARDELTA:-1000".parseAsInputToken(isCHS: false)
        .description
    )
    print(
      "測試一千年以前生肖：" + "MACRO@YEAR_ZODIAC_YEARDELTA:-1000".parseAsInputToken(isCHS: false)
        .description
    )
    print("測試一千年以後：" + "MACRO@YEAR_YEARDELTA:1000".parseAsInputToken(isCHS: false).description)
    print(
      "測試一千年以後干支：" + "MACRO@YEAR_GANZHI_YEARDELTA:1000".parseAsInputToken(isCHS: false)
        .description
    )
    print(
      "測試一千年以後生肖：" + "MACRO@YEAR_ZODIAC_YEARDELTA:1000".parseAsInputToken(isCHS: false)
        .description
    )
  }

  func testGeneratedResultsFromLMInstantiator() throws {
    let instance = LMAssembly.LMInstantiator(isCHS: true)
    XCTAssertTrue(LMAssembly.LMInstantiator.connectToTestSQLDB(sqlTestCoreLMData))
    instance.setOptions { config in
      config.isCNSEnabled = false
      config.isSymbolEnabled = false
    }
    instance.insertTemporaryData(
      unigram: .init(
        keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ", "ㄖˋ", "ㄑㄧˊ"],
        value: "MACRO@DATE_YEARDELTA:-1945",
        score: -97.5
      ),
      isFiltering: false
    )
    let x = instance.unigramsFor(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ", "ㄖˋ", "ㄑㄧˊ"]).description
    print(x)
    LMAssembly.LMInstantiator.disconnectSQLDB()
  }
}
