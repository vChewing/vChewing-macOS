// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - DateTimeConverter

/// 日期/時間格式轉換器。將日期/時間字串轉換為多種中文/格式化候選。
public enum DateTimeConverter {

  // MARK: - Character Table

  /// 日期用逐位數字對應表（0 → ○ U+3007，1 → 一 … 9 → 九）
  private static let dateDigitChars: [Character: String] = [
    "0": "○", "1": "一", "2": "二", "3": "三", "4": "四",
    "5": "五", "6": "六", "7": "七", "8": "八", "9": "九",
  ]

  // MARK: - Public API

  /// 對輸入的日期字串產生候選清單。
  /// - Parameter input: 日期字串（例如："2026/4/5"、"2026.4.5"、"109.5.6"）。
  /// - Returns: 候選清單；輸入無效時回傳空清單。
  public static func dateCandidates(for input: String) -> [CandidateInState] {
    guard let parsed = parseDate(input) else { return [] }
    return buildDateCandidates(year: parsed.year, month: parsed.month, day: parsed.day)
  }

  /// 對輸入的時間字串產生候選清單。
  /// - Parameter input: 時間字串（例如："14:30"、"8:05:30"）。
  /// - Returns: 候選清單；輸入無效時回傳空清單。
  public static func timeCandidates(for input: String) -> [CandidateInState] {
    guard let parsed = parseTime(input) else { return [] }
    return buildTimeCandidates(hour: parsed.hour, minute: parsed.minute, second: parsed.second)
  }

  // MARK: - Date Parsing

  private struct ParsedDate {
    let year: Int
    let month: Int?
    let day: Int?
  }

  /// 解析日期字串，支援分隔符：`.`、`/`、`-`
  /// 年份 ≤ 150 → 民國年（自動換算為西元）；年份 > 150 → 西元年。
  private static func parseDate(_ input: String) -> ParsedDate? {
    let separators = CharacterSet(charactersIn: "./\u{2D}")  // . / -
    let parts = input.components(separatedBy: separators)
    guard !parts.isEmpty else { return nil }
    guard let rawYear = Int(parts[0]), rawYear > 0 else { return nil }

    // 年份 ≤ 150 視為民國年，換算西元年
    let gregYear: Int
    let rocYear: Int
    if rawYear <= 150 {
      rocYear = rawYear
      gregYear = rawYear + 1911
    } else {
      gregYear = rawYear
      rocYear = rawYear - 1911
    }

    if parts.count == 1 {
      return ParsedDate(year: gregYear, month: nil, day: nil)
    }

    guard let month = Int(parts[1]), month >= 1, month <= 12 else { return nil }

    if parts.count == 2 {
      return ParsedDate(year: gregYear, month: month, day: nil)
    }

    guard let day = Int(parts[2]), day >= 1, day <= 31 else { return nil }

    // 儲存時已換算成西元年；但建候選時需要 ROC 年
    _ = rocYear
    return ParsedDate(year: gregYear, month: month, day: day)
  }

  // MARK: - Date Candidate Builder

  private static func buildDateCandidates(year: Int, month: Int?, day: Int?) -> [CandidateInState] {
    var results: [CandidateInState] = []
    let rocYear = year - 1911

    switch (month, day) {
    case (nil, _):
      // 僅有年份
      results.append(candidate("\(year)年"))
      if rocYear > 0 {
        results.append(candidate("民國\(rocYear)年"))
        results.append(candidate("\(rocYear)年"))
      }
      results.append(candidate(chineseDate(year: year, month: nil, day: nil)))

    case let (m?, nil):
      // 年 + 月
      results.append(candidate("\(year)年\(m)月"))
      if rocYear > 0 {
        results.append(candidate("民國\(rocYear)年\(m)月"))
        results.append(candidate("\(rocYear)年\(m)月"))
      }
      results.append(candidate(chineseDate(year: year, month: m, day: nil)))

    case let (m?, d?):
      // 完整日期
      results.append(candidate("\(year)年\(m)月\(d)日"))
      if rocYear > 0 {
        results.append(candidate("民國\(rocYear)年\(m)月\(d)日"))
        results.append(candidate("\(rocYear)年\(m)月\(d)日"))
      }
      let mmStr = String(format: "%02d", m)
      let ddStr = String(format: "%02d", d)
      results.append(candidate("\(year)/\(mmStr)/\(ddStr)"))
      results.append(candidate("\(year)-\(mmStr)-\(ddStr)"))
      results.append(candidate(chineseDate(year: year, month: m, day: d)))
    }

    return results
  }

  // MARK: - Chinese Date Helpers

  /// 產生中文日期字串，例如：`二○二○年五月六日`。
  /// 年份以逐位中文數字表示（○ 代替 零）；月日以傳統中文數字讀法表示。
  private static func chineseDate(year: Int, month: Int?, day: Int?) -> String {
    let yearStr = String(year).map { dateDigitChars[$0] ?? String($0) }.joined()
    var result = "\(yearStr)年"
    if let m = month {
      result += chineseMonthDay(m) + "月"
      if let d = day {
        result += chineseMonthDay(d) + "日"
      }
    }
    return result
  }

  /// 將月份或日期的數字轉成中文讀法（1→一，10→十，11→十一，20→二十，…）。
  private static func chineseMonthDay(_ n: Int) -> String {
    let lowerDigits = ["○", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    switch n {
    case 1 ... 9: return lowerDigits[n]
    case 10: return "十"
    case 11 ... 19: return "十\(lowerDigits[n - 10])"
    case 20: return "二十"
    case 21 ... 29: return "二十\(lowerDigits[n - 20])"
    case 30: return "三十"
    case 31: return "三十一"
    default: return "\(n)"
    }
  }

  // MARK: - Time Parsing

  private struct ParsedTime {
    let hour: Int
    let minute: Int
    let second: Int?
  }

  /// 解析時間字串，支援 `HH:MM` 及 `HH:MM:SS` 格式。
  private static func parseTime(_ input: String) -> ParsedTime? {
    let parts = input.components(separatedBy: ":")
    guard parts.count >= 2, parts.count <= 3 else { return nil }
    guard let hour = Int(parts[0]), hour >= 0, hour <= 23 else { return nil }
    guard let minute = Int(parts[1]), minute >= 0, minute <= 59 else { return nil }
    if parts.count == 3 {
      guard let second = Int(parts[2]), second >= 0, second <= 59 else { return nil }
      return ParsedTime(hour: hour, minute: minute, second: second)
    }
    return ParsedTime(hour: hour, minute: minute, second: nil)
  }

  // MARK: - Time Candidate Builder

  private static func buildTimeCandidates(hour: Int, minute: Int, second: Int?) -> [CandidateInState] {
    var results: [CandidateInState] = []

    let period = timePeriod(for: hour)
    let hour12 = hour % 12 == 0 ? 12 : hour % 12

    let mmStr = String(format: "%02d", minute)

    // 1. 原始格式 HH:MM 或 HH:MM:SS
    if let sec = second {
      let ssStr = String(format: "%02d", sec)
      results.append(candidate("\(String(format: "%02d", hour)):\(mmStr):\(ssStr)"))
    } else {
      results.append(candidate("\(String(format: "%02d", hour)):\(mmStr)"))
    }

    // 2. 時段X點MM分（12 小時制）
    results.append(candidate("\(period)\(hour12)點\(mmStr)分"))

    // 3. 時段X:MM（12 小時制）
    results.append(candidate("\(period)\(hour12):\(mmStr)"))

    // 4. HH時MM分
    if let sec = second {
      let ssStr = String(format: "%02d", sec)
      results.append(candidate("\(hour)時\(minute)分\(sec)秒"))
      _ = ssStr
    } else {
      results.append(candidate("\(hour)時\(minute)分"))
    }

    // 5. 中文時間讀法
    results.append(candidate(chineseTime(hour: hour, minute: minute, second: second)))

    return results
  }

  // MARK: - Time Period

  /// 根據 24 小時制小時判斷時段。
  private static func timePeriod(for hour: Int) -> String {
    switch hour {
    case 0 ... 4: return "凌晨"
    case 5 ... 11: return "上午"
    case 12: return "中午"
    default: return "下午"
    }
  }

  // MARK: - Chinese Time Helpers

  /// 產生中文時間字串，例如：`十三點整`、`十三點零五分`、`上午八點五分`。
  private static func chineseTime(hour: Int, minute: Int, second: Int?) -> String {
    let hourStr = chineseNumber(hour)
    if minute == 0, second == nil || second == 0 {
      return "\(hourStr)點整"
    }
    let minStr = chineseNumber(minute)
    // 0x 分鐘補「零」字首（如 05 → 零五）
    let minReading = minute < 10 ? "零\(minStr)" : minStr
    if let sec = second, sec > 0 {
      let secStr = chineseNumber(sec)
      let secReading = sec < 10 ? "零\(secStr)" : secStr
      return "\(hourStr)點\(minReading)分\(secReading)秒"
    }
    return "\(hourStr)點\(minReading)分"
  }

  /// 將 0–59 的整數轉成中文讀法（不含「一十」首位省略規則）。
  private static func chineseNumber(_ n: Int) -> String {
    let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    switch n {
    case 0: return "零"
    case 1 ... 9: return digits[n]
    case 10: return "十"
    case 11 ... 19: return "十\(digits[n - 10])"
    case 20 ... 29: return "二十\(n == 20 ? "" : digits[n - 20])"
    case 30 ... 39: return "三十\(n == 30 ? "" : digits[n - 30])"
    case 40 ... 49: return "四十\(n == 40 ? "" : digits[n - 40])"
    case 50 ... 59: return "五十\(n == 50 ? "" : digits[n - 50])"
    default: return "\(n)"
    }
  }

  // MARK: - Helpers

  private static func candidate(_ value: String) -> CandidateInState {
    (keyArray: [""], value: value)
  }
}
