// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - NumberConverter

/// 數字快打的數字格式轉換器。將純數字字串轉換為多種中文/格式化候選。
public enum NumberConverter {

  // MARK: - Character Tables

  private static let lowerDigits: [String] = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
  private static let upperDigits: [String] = ["零", "壹", "貳", "參", "肆", "伍", "陸", "柒", "捌", "玖"]

  // MARK: - Public API

  /// 產生對應 `input`（純數字字串）的候選清單。
  /// - Parameter input: 純數字字串（僅含 "0"–"9"）。
  /// - Returns: 候選清單（keyArray 固定為 `[""]`）。
  public static func candidates(for input: String) -> [CandidateInState] {
    guard !input.isEmpty, input.allSatisfy(\.isNumber) else { return [] }
    if input.count == 1 {
      return singleDigitCandidates(input)
    }
    // 超過兆（10^12 = 13 位數）不支援
    guard input.count <= 13 else { return [candidate(input)] }
    // 需要整數值進行運算
    guard let n = Int(input) else {
      // 位數過多無法用 Int 表示（> Int.max），僅提供千分位候選
      return [candidate(thousandSeparated(input))]
    }
    return multiDigitCandidates(n, original: input)
  }

  // MARK: - Single Digit Candidates (1 digit)

  private static func singleDigitCandidates(_ input: String) -> [CandidateInState] {
    guard let digit = Int(input) else { return [candidate(input)] }
    var results: [CandidateInState] = []
    // 1. 阿拉伯數字
    results.append(candidate(input))
    // 2. 中文小寫
    results.append(candidate(lowerDigits[digit]))
    // 3. 中文大寫
    results.append(candidate(upperDigits[digit]))
    // 4. 全形
    let fullWidthBase = 0xFF10 // '０'
    if let scalar = Unicode.Scalar(fullWidthBase + digit) {
      results.append(candidate(String(scalar)))
    }
    // 5. 序數（圓圈）— 僅 1–10
    // ① = U+2460, ⑩ = U+2469
    if digit >= 1, digit <= 10,
       let scalar = Unicode.Scalar(0x2460 + digit - 1) {
      results.append(candidate(String(scalar)))
    }
    // 6. 羅馬數字 — 僅 1–10
    // Ⅰ = U+2160, Ⅹ = U+2169
    if digit >= 1, digit <= 10,
       let scalar = Unicode.Scalar(0x2160 + digit - 1) {
      results.append(candidate(String(scalar)))
    }
    return results
  }

  // MARK: - Multi-Digit Candidates (2+ digits)

  private static func multiDigitCandidates(_ n: Int, original: String) -> [CandidateInState] {
    var results: [CandidateInState] = []
    // 1. 千分位
    results.append(candidate(thousandSeparated(original)))
    // 2. 財務大寫含元整
    results.append(candidate(financialUppercase(n)))
    // 3. 中文小寫完整讀法
    results.append(candidate(chineseReadout(n, upper: false)))
    // 4. 混合格式（萬以上用中文，以下用千分位）
    results.append(candidate(mixedFormat(n, original: original)))
    // 5. 逐位中文小寫
    results.append(candidate(digitByDigit(original, upper: false)))
    // 6. 逐位中文大寫
    results.append(candidate(digitByDigit(original, upper: true)))
    return results
  }

  // MARK: - Format Implementations

  /// 千分位格式：123456 → "123,456"
  static func thousandSeparated(_ input: String) -> String {
    // 處理前導零（例如 "007"），原樣保留逐位格式
    guard let n = Int(input) else { return input }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.groupingSize = 3
    return formatter.string(from: NSNumber(value: n)) ?? input
  }

  /// 財務大寫含元整
  /// 規則：
  /// - 億以上：逐位大寫 + 億
  /// - 萬以上（但小於億）：萬以上部分逐位大寫，萬以下部分帶單位
  /// - 仟以下：帶仟/佰/拾單位
  /// - 例：123456 → "壹貳參仟肆佰伍拾陸元整"
  /// - 例：1000000 → "壹百萬元整"（仟以上萬以下）
  ///
  /// 簡化版規則（符合 spec 截圖）：
  /// 將 n 分解為：[億組][萬組][千組]
  /// - 千組（0–9999）：用仟佰拾單位格式
  /// - 萬組（0–9999，代表 ×10^4）：逐位大寫
  /// - 億組（0–9999，代表 ×10^8）：逐位大寫（若有）
  static func financialUppercase(_ n: Int) -> String {
    if n == 0 { return "零元整" }
    var result = ""
    let yi = n / 100_000_000          // 億組
    let wan = (n % 100_000_000) / 10_000  // 萬組
    let qian = n % 10_000             // 千以下

    // 億組（逐位大寫）
    if yi > 0 {
      result += digitByDigit(String(yi), upper: true) + "億"
    }
    // 萬組（逐位大寫，若億組已有，即使萬組=0也不寫；若萬組=0且億組有，不寫萬）
    if wan > 0 {
      result += digitByDigit(String(wan), upper: true)
    }
    // 千以下（帶單位）
    result += positionalUpper(qian)

    return result + "元整"
  }

  /// 千以下的帶單位大寫（0–9999）
  /// 例：3456 → "參仟肆佰伍拾陸"；0 → ""；100 → "壹佰"
  private static func positionalUpper(_ n: Int) -> String {
    guard n > 0 else { return "" }
    var result = ""
    let thousands = n / 1000
    let hundreds = (n % 1000) / 100
    let tens = (n % 100) / 10
    let ones = n % 10
    if thousands > 0 { result += upperDigits[thousands] + "仟" }
    if hundreds > 0 { result += upperDigits[hundreds] + "佰" }
    if tens > 0 { result += upperDigits[tens] + "拾" }
    if ones > 0 { result += upperDigits[ones] }
    // 處理中間零（例如 1001 → 壹仟零壹）
    // 注意：positionalUpper 只用於財務大寫的「千組」，此處簡化處理不加零
    return result
  }

  /// 中文小寫/大寫完整讀法
  /// 規則：
  /// - 10 → 十（非 一十）
  /// - 110 → 一百一十
  /// - 1000 → 一千
  /// - 10000 → 一萬
  /// - 1000000000 → 十億
  /// - 中間零折疊：10001 → 一萬零一
  static func chineseReadout(_ n: Int, upper: Bool) -> String {
    if n == 0 { return upper ? "零" : "零" }
    let digits = upper ? upperDigits : lowerDigits
    let units: [String] = upper
      ? ["", "拾", "佰", "仟", "萬", "拾", "佰", "仟", "億", "拾", "佰", "仟", "兆"]
      : ["", "十", "百", "千", "萬", "十", "百", "千", "億", "十", "百", "千", "兆"]
    return chineseNumber(n, digits: digits, units: units)
  }

  /// 核心中文數字轉換（支援到兆）
  private static func chineseNumber(_ n: Int, digits: [String], units: [String]) -> String {
    if n == 0 { return digits[0] }
    // 兆
    if n >= 1_000_000_000_000 {
      let zhao = n / 1_000_000_000_000
      let rem = n % 1_000_000_000_000
      let zhaoStr = chineseNumber(zhao, digits: digits, units: units)
      if rem == 0 { return zhaoStr + "兆" }
      let remStr = chineseNumber(rem, digits: digits, units: units)
      let needZero = rem < 100_000_000_000
      return zhaoStr + "兆" + (needZero ? digits[0] : "") + remStr
    }
    // 億
    if n >= 100_000_000 {
      let yi = n / 100_000_000
      let rem = n % 100_000_000
      let yiStr = chineseNumber(yi, digits: digits, units: units)
      if rem == 0 { return yiStr + "億" }
      let remStr = chineseNumber(rem, digits: digits, units: units)
      let needZero = rem < 10_000_000
      return yiStr + "億" + (needZero ? digits[0] : "") + remStr
    }
    // 萬
    if n >= 10_000 {
      let wan = n / 10_000
      let rem = n % 10_000
      let wanStr = chineseNumber(wan, digits: digits, units: units)
      if rem == 0 { return wanStr + "萬" }
      let remStr = chineseBelow10000(rem, digits: digits, units: units)
      let needZero = rem < 1000
      return wanStr + "萬" + (needZero ? digits[0] : "") + remStr
    }
    return chineseBelow10000(n, digits: digits, units: units)
  }

  /// 0–9999 的中文數字（不帶萬/億單位）
  private static func chineseBelow10000(_ n: Int, digits: [String], units: [String]) -> String {
    if n == 0 { return "" }
    var result = ""
    let thousands = n / 1000
    let hundreds = (n % 1000) / 100
    let tens = (n % 100) / 10
    let ones = n % 10
    if thousands > 0 {
      result += digits[thousands] + units[3]  // 千/仟
    }
    if hundreds > 0 {
      result += digits[hundreds] + units[2]  // 百/佰
    } else if thousands > 0, (tens > 0 || ones > 0) {
      result += digits[0]  // 插入零
    }
    if tens > 0 {
      // 特殊規則：10–19 以十開頭時不加一（只在最高位且為一時才省略）
      if tens == 1, result.isEmpty {
        result += units[1]  // 直接寫「十」不加「一」
      } else {
        result += digits[tens] + units[1]  // 二十、三十…
      }
    } else if hundreds > 0 || thousands > 0, ones > 0 {
      result += digits[0]  // 插入零（如 101、1001）
    }
    if ones > 0 {
      result += digits[ones]
    }
    return result
  }

  /// 混合格式：萬以上用中文，以下用千分位加元
  /// 例：123456 → "12萬3,456元"；1000000 → "100萬元"
  static func mixedFormat(_ n: Int, original: String) -> String {
    if n < 10000 {
      return thousandSeparated(original) + "元"
    }
    let wan = n / 10_000
    let rem = n % 10_000
    let wanStr = chineseReadout(wan, upper: false)
    if rem == 0 {
      return wanStr + "萬元"
    }
    let remStr = thousandSeparated(String(rem))
    return wanStr + "萬\(remStr)元"
  }

  /// 逐位中文（小寫或大寫）
  /// 例（小寫）："123456" → "一二三四五六"
  /// 例（大寫）："123456" → "壹貳參肆伍陸"
  static func digitByDigit(_ input: String, upper: Bool) -> String {
    let table = upper ? upperDigits : lowerDigits
    return input.compactMap { char -> String? in
      guard let d = char.wholeNumberValue, d >= 0, d <= 9 else { return nil }
      return table[d]
    }.joined()
  }

  // MARK: - Helpers

  private static func candidate(_ value: String) -> CandidateInState {
    (keyArray: [""], value: value)
  }
}
