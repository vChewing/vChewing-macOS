// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing
@testable import Typewriter

// MARK: - NumberConverter Tests

@Suite("NumberConverter")
struct NumberConverterTests {

  @Test("single digit 5 — 六種候選均存在")
  func testSingleDigit5() {
    let results = NumberConverter.candidates(for: "5").map(\.value)
    #expect(results.contains("5"))
    #expect(results.contains("五"))
    #expect(results.contains("伍"))
    #expect(results.contains("５"))   // 全形
    #expect(results.contains("⑤"))   // 圓圈序數
    #expect(results.contains("Ⅴ"))   // 羅馬數字
  }

  @Test("single digit 0 — 不含序數/羅馬（0不在範圍內）")
  func testSingleDigit0() {
    let results = NumberConverter.candidates(for: "0").map(\.value)
    #expect(results.contains("0"))
    #expect(results.contains("零"))
    // 0 不在序數/羅馬範圍 (1–10)，⓪ 不應出現
    #expect(!results.contains("⓪"))
  }

  @Test("10 → 十 (非 一十)")
  func testTen() {
    let results = NumberConverter.candidates(for: "10").map(\.value)
    #expect(results.contains("十"))
    #expect(!results.contains("一十"))
  }

  @Test("110 → 一百一十")
  func test110() {
    let results = NumberConverter.candidates(for: "110").map(\.value)
    #expect(results.contains("一百一十"))
  }

  @Test("1000 — 千分位、中文小寫、財務大寫均存在")
  func testThousand() {
    let results = NumberConverter.candidates(for: "1000").map(\.value)
    #expect(results.contains("1,000"))
    #expect(results.contains("一千"))
    #expect(results.contains("壹仟元整"))
  }

  @Test("123456 — 全部格式驗證")
  func test123456() {
    let results = NumberConverter.candidates(for: "123456").map(\.value)
    #expect(results.contains("123,456"))
    #expect(results.contains("十二萬3,456元"))    // 混合格式（chineseReadout(12) = 十二）
    #expect(results.contains("一二三四五六"))     // 逐位小寫
    #expect(results.contains("壹貳參肆伍陸"))     // 逐位大寫
    #expect(results.contains("十二萬三千四百五十六"))  // 中文讀法
  }

  @Test("1000000000 → 十億（非 一十億）")
  func testBillion() {
    let results = NumberConverter.candidates(for: "1000000000").map(\.value)
    // 中文小寫完整讀法：1,000,000,000 = 十億
    #expect(results.contains("十億"))
  }

  @Test("空字串 → 空清單")
  func testEmptyInput() {
    let results = NumberConverter.candidates(for: "")
    #expect(results.isEmpty)
  }

  @Test("非數字輸入 → 空清單")
  func testNonNumericInput() {
    let results = NumberConverter.candidates(for: "abc")
    #expect(results.isEmpty)
  }

  @Test("超長數字（14位）→ 回傳原始字串候選（不支援兆以上）")
  func testOverlong() {
    // 程式碼：input.count > 13 時回傳 [candidate(input)]（原始字串，非空清單）
    let input = "12345678901234"
    let results = NumberConverter.candidates(for: input)
    #expect(results.count == 1)
    #expect(results.first?.value == input)
  }
}

// MARK: - ExpressionEvaluator Tests

@Suite("ExpressionEvaluator")
struct ExpressionEvaluatorTests {

  // MARK: evaluate()

  @Test("3+5 = 8")
  func testSimpleAddition() {
    let result = ExpressionEvaluator.evaluate("3+5")
    #expect(result == .success(8.0))
  }

  @Test("20*300 = 6000")
  func testMultiplication() {
    let result = ExpressionEvaluator.evaluate("20*300")
    #expect(result == .success(6000.0))
  }

  @Test("10/3 ≈ 3.3333...")
  func testDivisionDecimal() {
    switch ExpressionEvaluator.evaluate("10/3") {
    case let .success(v):
      #expect(abs(v - (10.0 / 3.0)) < 1e-9)
    case .failure:
      Issue.record("Expected success but got failure")
    }
  }

  @Test("(3+5)*2 = 16")
  func testParentheses() {
    let result = ExpressionEvaluator.evaluate("(3+5)*2")
    #expect(result == .success(16.0))
  }

  @Test("5/0 → divisionByZero")
  func testDivisionByZero() {
    let result = ExpressionEvaluator.evaluate("5/0")
    #expect(result == .failure(.divisionByZero))
  }

  @Test("一元負號：-3+5 = 2")
  func testUnaryMinus() {
    let result = ExpressionEvaluator.evaluate("-3+5")
    #expect(result == .success(2.0))
  }

  @Test("小數：1.5+2.5 = 4")
  func testDecimalAddition() {
    let result = ExpressionEvaluator.evaluate("1.5+2.5")
    #expect(result == .success(4.0))
  }

  @Test("語法錯誤：3+ → syntaxError")
  func testSyntaxError() {
    let result = ExpressionEvaluator.evaluate("3+")
    #expect(result == .failure(.syntaxError))
  }

  @Test("空字串 → syntaxError")
  func testEmptyExpression() {
    let result = ExpressionEvaluator.evaluate("")
    #expect(result == .failure(.syntaxError))
  }

  @Test("純數字 8 → 8.0（無運算子仍可求值）")
  func testBareNumber() {
    let result = ExpressionEvaluator.evaluate("8")
    #expect(result == .success(8.0))
  }

  @Test("複合運算：2+3*4 = 14（乘除優先）")
  func testPrecedence() {
    let result = ExpressionEvaluator.evaluate("2+3*4")
    #expect(result == .success(14.0))
  }

  // MARK: displayHint()

  @Test("displayHint 3+5 → '= 8'")
  func testDisplayHintInteger() {
    let hint = ExpressionEvaluator.displayHint(for: "3+5")
    #expect(hint == "= 8")
  }

  @Test("displayHint 10/3 → '= 3.3333333333'")
  func testDisplayHintDecimal() {
    let hint = ExpressionEvaluator.displayHint(for: "10/3")
    #expect(hint == "= 3.3333333333")
  }

  @Test("displayHint 5/0 → '= 除以零'")
  func testDisplayHintDivisionByZero() {
    let hint = ExpressionEvaluator.displayHint(for: "5/0")
    #expect(hint == "= 除以零")
  }

  @Test("displayHint 語法錯誤 → nil")
  func testDisplayHintSyntaxError() {
    let hint = ExpressionEvaluator.displayHint(for: "3+")
    #expect(hint == nil)
  }

  @Test("displayHint 空字串 → nil")
  func testDisplayHintEmpty() {
    let hint = ExpressionEvaluator.displayHint(for: "")
    #expect(hint == nil)
  }

  // MARK: candidates()

  @Test("candidates 3+5 → 含 '8'、'運算式 = 8'、'八'、'捌元整'")
  func testCandidatesSimpleAddition() {
    let values = ExpressionEvaluator.candidates(for: "3+5").map(\.value)
    #expect(values.contains("8"))
    #expect(values.contains("運算式 = 8"))
    #expect(values.contains("八"))
    #expect(values.contains("捌元整"))
  }

  @Test("candidates 20*300 → 含 '6,000'、'運算式 = 6000'、'六千'")
  func testCandidatesMultiplication() {
    let values = ExpressionEvaluator.candidates(for: "20*300").map(\.value)
    #expect(values.contains("6,000"))
    #expect(values.contains("運算式 = 6000"))
    #expect(values.contains("六千"))
  }

  @Test("candidates 5/0 → 單一除以零提示")
  func testCandidatesDivisionByZero() {
    let results = ExpressionEvaluator.candidates(for: "5/0")
    #expect(results.count == 1)
    #expect(results.first?.value == "無法計算（除以零）")
    #expect(results.first?.keyArray == [""])
  }

  @Test("candidates 語法錯誤 → 空清單")
  func testCandidatesSyntaxError() {
    let results = ExpressionEvaluator.candidates(for: "3+")
    #expect(results.isEmpty)
  }

  @Test("candidates 純數字（無運算子）→ 空清單")
  func testCandidatesNoOperator() {
    let results = ExpressionEvaluator.candidates(for: "42")
    #expect(results.isEmpty)
  }
}

// MARK: - DateTimeConverter Tests

@Suite("DateTimeConverter")
struct DateTimeConverterTests {

  // MARK: dateCandidates

  @Test("2020.5.6 — 完整日期候選（西元輸入）")
  func testGregorianFullDate() {
    let values = DateTimeConverter.dateCandidates(for: "2020.5.6").map(\.value)
    #expect(values.contains("2020年5月6日"))
    #expect(values.contains("民國109年5月6日"))    // 2020 - 1911 = 109
    #expect(values.contains("109年5月6日"))
    #expect(values.contains("2020/05/06"))
    #expect(values.contains("2020-05-06"))
    #expect(values.contains("二○二○年五月六日"))
  }

  @Test("109.5.6 — 民國年輸入換算西元")
  func testROCFullDate() {
    let values = DateTimeConverter.dateCandidates(for: "109.5.6").map(\.value)
    #expect(values.contains("2020年5月6日"))        // 109 + 1911 = 2020
    #expect(values.contains("民國109年5月6日"))
    #expect(values.contains("109年5月6日"))
    #expect(values.contains("2020/05/06"))
    #expect(values.contains("2020-05-06"))
  }

  @Test("2020/5/6 — 斜線分隔符")
  func testSlashSeparator() {
    let values = DateTimeConverter.dateCandidates(for: "2020/5/6").map(\.value)
    #expect(values.contains("2020年5月6日"))
    #expect(values.contains("二○二○年五月六日"))
  }

  @Test("2020-5-6 — 連字號分隔符")
  func testHyphenSeparator() {
    let values = DateTimeConverter.dateCandidates(for: "2020-5-6").map(\.value)
    #expect(values.contains("2020年5月6日"))
  }

  @Test("2020.5 — 年月候選（無日）")
  func testYearMonth() {
    let values = DateTimeConverter.dateCandidates(for: "2020.5").map(\.value)
    #expect(values.contains("2020年5月"))
    #expect(values.contains("民國109年5月"))
    #expect(values.contains("二○二○年五月"))
    // 不含日格式
    #expect(!values.contains("2020年5月6日"))
  }

  @Test("2020 — 僅年份候選")
  func testYearOnly() {
    let values = DateTimeConverter.dateCandidates(for: "2020").map(\.value)
    #expect(values.contains("2020年"))
    #expect(values.contains("民國109年"))
    #expect(values.contains("二○二○年"))
  }

  @Test("無效月份 → 空清單")
  func testInvalidMonth() {
    let results = DateTimeConverter.dateCandidates(for: "2020.13.1")
    #expect(results.isEmpty)
  }

  @Test("無效日期 → 空清單")
  func testInvalidDay() {
    let results = DateTimeConverter.dateCandidates(for: "2020.5.32")
    #expect(results.isEmpty)
  }

  @Test("年份為零 → 空清單")
  func testZeroYear() {
    let results = DateTimeConverter.dateCandidates(for: "0.1.1")
    #expect(results.isEmpty)
  }

  @Test("2026.4.5 — 補零格式正確")
  func testZeroPadding() {
    let values = DateTimeConverter.dateCandidates(for: "2026.4.5").map(\.value)
    #expect(values.contains("2026/04/05"))
    #expect(values.contains("2026-04-05"))
  }

  // MARK: timeCandidates

  @Test("13:00 — 下午時段完整候選")
  func testTime1300() {
    let values = DateTimeConverter.timeCandidates(for: "13:00").map(\.value)
    #expect(values.contains("13:00"))
    #expect(values.contains("下午1點00分"))
    #expect(values.contains("下午1:00"))
    #expect(values.contains("13時0分"))
    #expect(values.contains("十三點整"))
  }

  @Test("8:05 — 上午時段、補零分鐘")
  func testTime0805() {
    let values = DateTimeConverter.timeCandidates(for: "8:05").map(\.value)
    #expect(values.contains("08:05"))
    #expect(values.contains("上午8點05分"))
    #expect(values.contains("上午8:05"))
    #expect(values.contains("八點零五分"))
  }

  @Test("0:30 — 凌晨時段")
  func testTime0030() {
    let values = DateTimeConverter.timeCandidates(for: "0:30").map(\.value)
    #expect(values.contains("凌晨12點30分"))
    #expect(values.contains("零點三十分"))
  }

  @Test("12:00 — 中午時段")
  func testTime1200() {
    let values = DateTimeConverter.timeCandidates(for: "12:00").map(\.value)
    #expect(values.contains("中午12點00分"))
    #expect(values.contains("十二點整"))
  }

  @Test("13:05:30 — 含秒數候選")
  func testTimeWithSeconds() {
    let values = DateTimeConverter.timeCandidates(for: "13:05:30").map(\.value)
    #expect(values.contains("13:05:30"))
    #expect(values.contains("13時5分30秒"))
  }

  @Test("25:00 — 無效小時 → 空清單")
  func testInvalidHour() {
    let results = DateTimeConverter.timeCandidates(for: "25:00")
    #expect(results.isEmpty)
  }

  @Test("12:60 — 無效分鐘 → 空清單")
  func testInvalidMinute() {
    let results = DateTimeConverter.timeCandidates(for: "12:60")
    #expect(results.isEmpty)
  }

  @Test("8:05:61 — 無效秒數 → 空清單")
  func testInvalidSecond() {
    let results = DateTimeConverter.timeCandidates(for: "8:05:61")
    #expect(results.isEmpty)
  }
}
