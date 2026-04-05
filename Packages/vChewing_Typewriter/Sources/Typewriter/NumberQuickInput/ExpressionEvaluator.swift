// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - ExpressionEvaluator

/// 算術表達式求值器。支援 +、-、*、/ 及括號，使用遞迴下降解析法。
public enum ExpressionEvaluator {

  // MARK: - Public Error Type

  /// 求值過程中可能發生的錯誤。
  public enum EvalError: Error {
    case divisionByZero
    case syntaxError
  }

  // MARK: - Public API

  /// 對算術表達式求值。
  /// - Parameter expr: 算術表達式字串（例如："3+5*2"、"(10-2)/4"）。
  /// - Returns: `.success(Double)` 或 `.failure(EvalError)`。
  public static func evaluate(_ expr: String) -> Result<Double, EvalError> {
    let tokens = expr.filter { !$0.isWhitespace }
    guard !tokens.isEmpty else { return .failure(.syntaxError) }
    var parser = Parser(input: Array(tokens))
    return parser.parseExpression()
  }

  /// 回傳表達式的即時顯示提示字串（例如："= 8"、"= 3.3333333333"）。
  /// - Parameter input: 算術表達式字串。
  /// - Returns: 顯示提示字串，或 nil（語法錯誤/空字串時）。
  public static func displayHint(for input: String) -> String? {
    guard !input.isEmpty, containsOperator(input) else { return nil }
    switch evaluate(input) {
    case let .success(value):
      return "= \(formatResult(value))"
    case let .failure(error):
      switch error {
      case .divisionByZero: return "= 除以零"
      case .syntaxError: return nil
      }
    }
  }

  /// 根據算術表達式產生候選清單。
  /// - Parameter input: 算術表達式字串。
  /// - Returns: 候選清單；語法錯誤時回傳空清單，除以零時回傳單一提示候選。
  public static func candidates(for input: String) -> [CandidateInState] {
    guard !input.isEmpty, containsOperator(input) else { return [] }
    switch evaluate(input) {
    case let .success(value):
      return buildCandidates(from: value)
    case let .failure(error):
      switch error {
      case .divisionByZero:
        return [candidate("無法計算（除以零）", key: "")]
      case .syntaxError:
        return []
      }
    }
  }

  // MARK: - Internal Helpers

  /// 判斷字串是否含有算術運算子或括號。
  private static func containsOperator(_ input: String) -> Bool {
    input.contains(where: { "+-*/()".contains($0) })
  }

  /// 將 Double 結果格式化：整數時輸出不含小數點，非整數時輸出至多 10 位小數（去除尾零）。
  static func formatResult(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0, value >= Double(Int.min), value <= Double(Int.max) {
      return String(Int(value))
    }
    // 使用 %.10f 格式：固定 10 位小數，再去除末尾多餘的零
    var formatted = String(format: "%.10f", value)
    while formatted.hasSuffix("0") { formatted.removeLast() }
    if formatted.hasSuffix(".") { formatted.removeLast() }
    return formatted
  }

  /// 千分位格式化（整數）。
  private static func thousandSeparated(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.groupingSize = 3
    return formatter.string(from: NSNumber(value: n)) ?? String(n)
  }

  /// 根據計算結果建立候選清單。
  private static func buildCandidates(from value: Double) -> [CandidateInState] {
    var results: [CandidateInState] = []
    let formatted = formatResult(value)

    // 1. 格式化結果（整數或小數）
    results.append(candidate(formatted))

    // 2. 千分位格式（僅整數 ≥ 1000）
    let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
    if isWhole, let intValue = exactInt(from: value), intValue >= 1000 {
      results.append(candidate(thousandSeparated(intValue)))
    }

    // 3. 運算式 = 結果
    results.append(candidate("運算式 = \(formatted)"))

    // 4. 中文讀法 + 財務大寫（僅整數 ≥ 0）
    if isWhole, let intValue = exactInt(from: value), intValue >= 0 {
      results.append(candidate(NumberConverter.chineseReadout(intValue, upper: false)))
      results.append(candidate(NumberConverter.financialUppercase(intValue)))
    }

    return results
  }

  /// 嘗試從 Double 取得精確整數值（避免浮點誤差）。
  private static func exactInt(from value: Double) -> Int? {
    guard value >= Double(Int.min), value <= Double(Int.max) else { return nil }
    return Int(value)
  }

  /// 建立候選項目（key 預設為空字串）。
  private static func candidate(_ value: String, key: String = "") -> CandidateInState {
    (keyArray: [key], value: value)
  }
}

// MARK: - Parser（遞迴下降解析器）

/// 遞迴下降解析器，支援 +、-、*、/、括號及一元負號。
///
/// 語法定義：
/// ```
/// expression = term (('+' | '-') term)*
/// term       = factor (('*' | '/') factor)*
/// factor     = number | '(' expression ')' | '-' factor | '+' factor
/// number     = [0-9]+ ('.' [0-9]+)?
/// ```
private struct Parser {
  let input: [Character]
  var pos: Int = 0

  var current: Character? { pos < input.count ? input[pos] : nil }

  mutating func advance() { pos += 1 }

  mutating func parseExpression() -> Result<Double, ExpressionEvaluator.EvalError> {
    var result: Result<Double, ExpressionEvaluator.EvalError>
    // 解析第一個 term
    switch parseTerm() {
    case let .success(v): result = .success(v)
    case let .failure(e): return .failure(e)
    }
    // 迴圈處理 + 和 -
    while let ch = current, ch == "+" || ch == "-" {
      advance()
      switch parseTerm() {
      case let .success(rhs):
        switch result {
        case let .success(lhs):
          result = .success(ch == "+" ? lhs + rhs : lhs - rhs)
        case .failure:
          break
        }
      case let .failure(e):
        return .failure(e)
      }
    }
    // 確認已消耗所有輸入
    if pos < input.count {
      return .failure(.syntaxError)
    }
    return result
  }

  mutating func parseTerm() -> Result<Double, ExpressionEvaluator.EvalError> {
    var result: Result<Double, ExpressionEvaluator.EvalError>
    // 解析第一個 factor
    switch parseFactor() {
    case let .success(v): result = .success(v)
    case let .failure(e): return .failure(e)
    }
    // 迴圈處理 * 和 /
    while let ch = current, ch == "*" || ch == "/" {
      advance()
      switch parseFactor() {
      case let .success(rhs):
        switch result {
        case let .success(lhs):
          if ch == "/" {
            if rhs == 0 { return .failure(.divisionByZero) }
            result = .success(lhs / rhs)
          } else {
            result = .success(lhs * rhs)
          }
        case .failure:
          break
        }
      case let .failure(e):
        return .failure(e)
      }
    }
    return result
  }

  mutating func parseFactor() -> Result<Double, ExpressionEvaluator.EvalError> {
    guard let ch = current else { return .failure(.syntaxError) }
    // 一元負號
    if ch == "-" {
      advance()
      switch parseFactor() {
      case let .success(v): return .success(-v)
      case let .failure(e): return .failure(e)
      }
    }
    // 一元正號
    if ch == "+" {
      advance()
      return parseFactor()
    }
    // 括號運算式
    if ch == "(" {
      advance()
      var innerParser = Parser(input: input, pos: pos)
      switch innerParser.parseInner() {
      case let .success(v):
        pos = innerParser.pos
        return .success(v)
      case let .failure(e):
        return .failure(e)
      }
    }
    // 數字
    return parseNumber()
  }

  /// 解析括號內的運算式（不要求消耗全部輸入，僅確認右括號存在）。
  mutating func parseInner() -> Result<Double, ExpressionEvaluator.EvalError> {
    var result: Result<Double, ExpressionEvaluator.EvalError>
    switch parseTerm() {
    case let .success(v): result = .success(v)
    case let .failure(e): return .failure(e)
    }
    while let ch = current, ch == "+" || ch == "-" {
      advance()
      switch parseTerm() {
      case let .success(rhs):
        switch result {
        case let .success(lhs):
          result = .success(ch == "+" ? lhs + rhs : lhs - rhs)
        case .failure:
          break
        }
      case let .failure(e):
        return .failure(e)
      }
    }
    // 確認右括號
    guard current == ")" else { return .failure(.syntaxError) }
    advance()
    return result
  }

  mutating func parseNumber() -> Result<Double, ExpressionEvaluator.EvalError> {
    guard let ch = current, ch.isNumber || ch == "." else { return .failure(.syntaxError) }
    var numStr = ""
    // 整數部分
    while let c = current, c.isNumber {
      numStr.append(c)
      advance()
    }
    // 小數部分
    if current == "." {
      numStr.append(".")
      advance()
      while let c = current, c.isNumber {
        numStr.append(c)
        advance()
      }
    }
    guard let value = Double(numStr) else { return .failure(.syntaxError) }
    return .success(value)
  }
}
