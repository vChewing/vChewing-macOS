// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Megrez

// MARK: - 日期時間便捷輸入功能

extension vChewingLM.LMInstantiator {
  func queryDateTimeUnigrams(with key: String = "") -> [Megrez.Unigram] {
    if !["ㄖˋ-ㄑㄧ", "ㄖˋ-ㄑㄧˊ", "ㄕˊ-ㄐㄧㄢ", "ㄒㄧㄥ-ㄑㄧ", "ㄒㄧㄥ-ㄑㄧˊ"].contains(key) { return .init() }
    var results = [Megrez.Unigram]()
    let theLocale = Locale(identifier: "zh-Hant")
    let currentDate = Date()
    var delta = DateComponents()
    let thisYear = Calendar.current.dateComponents([.year], from: currentDate).year ?? 2018
    delta.year = max(min(deltaOfCalendarYears, 0), thisYear * -1)
    let currentDateShortened = Calendar.current.date(byAdding: delta, to: currentDate)
    switch key {
      case "ㄖˋ-ㄑㄧ", "ㄖˋ-ㄑㄧˊ":
        let formatterDate1 = DateFormatter()
        let formatterDate2 = DateFormatter()
        formatterDate1.dateFormat = "yyyy-MM-dd"
        formatterDate2.dateFormat = "yyyy年MM月dd日"
        let date1 = formatterDate1.string(from: currentDate)
        let date2 = formatterDate2.string(from: currentDate)
        var date3 = date2.convertArabicNumeralsToChinese
        date3 = date3.replacingOccurrences(of: "年〇", with: "年")
        date3 = date3.replacingOccurrences(of: "月〇", with: "月")
        results.append(.init(value: date1, score: -94))
        results.append(.init(value: date2, score: -95))
        results.append(.init(value: date3, score: -96))
        if let currentDateShortened = currentDateShortened, delta.year != 0 {
          var dateAlt1: String = formatterDate1.string(from: currentDateShortened)
          dateAlt1.regReplace(pattern: #"^0+"#)
          var dateAlt2: String = formatterDate2.string(from: currentDateShortened)
          dateAlt2.regReplace(pattern: #"^0+"#)
          var dateAlt3 = dateAlt2.convertArabicNumeralsToChinese
          dateAlt3 = dateAlt3.replacingOccurrences(of: "年〇", with: "年")
          dateAlt3 = dateAlt3.replacingOccurrences(of: "月〇", with: "月")
          results.append(.init(value: dateAlt1, score: -97))
          results.append(.init(value: dateAlt2, score: -98))
          results.append(.init(value: dateAlt3, score: -99))
        }
      case "ㄕˊ-ㄐㄧㄢ":
        let formatterTime1 = DateFormatter()
        let formatterTime2 = DateFormatter()
        let formatterTime3 = DateFormatter()
        formatterTime1.dateFormat = "HH:mm"
        formatterTime2.dateFormat = isCHS ? "HH点mm分" : "HH點mm分"
        formatterTime3.dateFormat = isCHS ? "HH时mm分" : "HH時mm分"
        let time1 = formatterTime1.string(from: currentDate)
        let time2 = formatterTime2.string(from: currentDate)
        let time3 = formatterTime3.string(from: currentDate)
        results.append(.init(value: time1, score: -97))
        results.append(.init(value: time2, score: -98))
        results.append(.init(value: time3, score: -99))
      case "ㄒㄧㄥ-ㄑㄧ", "ㄒㄧㄥ-ㄑㄧˊ":
        let formatterWeek1 = DateFormatter()
        let formatterWeek2 = DateFormatter()
        formatterWeek1.dateFormat = "EEEE"
        formatterWeek2.dateFormat = "EE"
        formatterWeek1.locale = theLocale
        formatterWeek2.locale = theLocale
        let week1 = formatterWeek1.string(from: currentDate)
        let week2 = formatterWeek2.string(from: currentDate)
        results.append(.init(value: week1, score: -98))
        results.append(.init(value: week2, score: -99))
      default: return .init()
    }
    return results
  }
}

// MARK: - String Extension

extension String {
  fileprivate mutating func regReplace(pattern: String, replaceWith: String = "") {
    // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
    do {
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }
}

// MARK: - Date Time Language Conversion Extension

private let tableMappingArabicNumeralsToChinese: [String: String] = [
  "0": "〇", "1": "一", "2": "二", "3": "三", "4": "四", "5": "五", "6": "六", "7": "七", "8": "八", "9": "九",
]

extension String {
  /// 將給定的字串當中的阿拉伯數字轉為漢語小寫，逐字轉換。
  /// - Parameter target: 要進行轉換操作的對象，會直接修改該對象。
  fileprivate var convertArabicNumeralsToChinese: String {
    var target = self
    for key in tableMappingArabicNumeralsToChinese.keys {
      guard let result = tableMappingArabicNumeralsToChinese[key] else { continue }
      target = target.replacingOccurrences(of: key, with: result)
    }
    return target
  }
}
