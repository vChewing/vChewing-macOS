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

extension LMAssembly.LMInstantiator {
  func queryDateTimeUnigrams(with key: String = "", keyArray: [String]) -> [Megrez.Unigram] {
    guard let tokenTrigger = TokenTrigger(rawValue: key) else { return [] }
    var results = [Megrez.Unigram]()
    var tokens: [String] = []

    func processDateWithDayDelta(_ delta: Int) {
      tokens = ["MACRO@DATE_DAYDELTA:\(delta)"]
      if config
        .deltaOfCalendarYears !=
        0 { tokens.append("MACRO@DATE_DAYDELTA:\(delta)_YEARDELTA:\(config.deltaOfCalendarYears)")
      }
      tokens.append("MACRO@DATE_DAYDELTA:\(delta)_SHORTENED")
      tokens.append("MACRO@DATE_DAYDELTA:\(delta)_LUNA")
    }

    func processYearWithYearDelta(_ delta: Int) {
      tokens = ["MACRO@YEAR_YEARDELTA:\(delta)"]
      if config
        .deltaOfCalendarYears !=
        0 { tokens.append("MACRO@YEAR_YEARDELTA:\(delta + config.deltaOfCalendarYears)") }
      tokens.append("MACRO@YEAR_GANZHI_YEARDELTA:\(delta)")
      tokens.append("MACRO@YEAR_ZODIAC_YEARDELTA:\(delta)")
    }

    switch tokenTrigger {
    case .jin1tian1ri4qi1, .jin1tian1ri4qi2: processDateWithDayDelta(0) // 今天日期
    case .zuo2tian1ri4qi1, .zuo2tian1ri4qi2: processDateWithDayDelta(-1) // 昨天日期
    case .qian2tian1ri4qi1, .qian2tian1ri4qi2: processDateWithDayDelta(-2) // 前天日期
    case .ming2tian1ri4qi1, .ming2tian1ri4qi2: processDateWithDayDelta(1) // 明天日期
    case .hou4tian1ri4qi1, .hou4tian1ri4qi2: processDateWithDayDelta(2) // 後天日期
    case .jin1nian2nian2du4: processYearWithYearDelta(0) // 今年年度
    case .qu4nian2nian2du4: processYearWithYearDelta(-1) // 去年年度
    case .qian2nian2nian2du4: processYearWithYearDelta(-2) // 前年年度
    case .ming2nian2nian2du4: processYearWithYearDelta(1) // 明年年度
    case .hou4nian2nian2du4: processYearWithYearDelta(2) // 後年年度
    case .shi2jian1: tokens = ["MACRO@TIME_SHORTENED"] // 時間
    case .xing1qi1, .xing1qi2: tokens = ["MACRO@WEEK_SHORTENED", "MACRO@WEEK"] // 星期
    case .dang1qian2shi2qu1, .mu4qian2shi2qu1, .suo3zai4shi2qu1: tokens = [
        "MACRO@TIMEZONE",
        "MACRO@TIMEZONE_SHORTENED",
      ] // 時區
    }
    // 終末處理。
    let values = tokens.map { $0.parseAsInputToken(isCHS: isCHS) }.flatMap { $0 }.deduplicated
    values.forEach { currentValue in
      let hashKey = "\(key)\t\(currentValue)".hashValue
      inputTokenHashesArray.insert(hashKey)
    }
    var i: Double = -99
    for strValue in values.reversed() {
      results.insert(.init(keyArray: keyArray, value: strValue, score: i), at: 0)
      i += 1
    }
    return results
  }
}

// MARK: - TokenTrigger

private enum TokenTrigger: String {
  case shi2jian1 = "ㄕˊ-ㄐㄧㄢ"
  case xing1qi1 = "ㄒㄧㄥ-ㄑㄧ"
  case xing1qi2 = "ㄒㄧㄥ-ㄑㄧˊ"
  case jin1nian2nian2du4 = "ㄐㄧㄣ-ㄋㄧㄢˊ-ㄋㄧㄢˊ-ㄉㄨˋ"
  case qu4nian2nian2du4 = "ㄑㄩˋ-ㄋㄧㄢˊ-ㄋㄧㄢˊ-ㄉㄨˋ"
  case ming2nian2nian2du4 = "ㄇㄧㄥˊ-ㄋㄧㄢˊ-ㄋㄧㄢˊ-ㄉㄨˋ"
  case qian2nian2nian2du4 = "ㄑㄧㄢˊ-ㄋㄧㄢˊ-ㄋㄧㄢˊ-ㄉㄨˋ"
  case hou4nian2nian2du4 = "ㄏㄡˋ-ㄋㄧㄢˊ-ㄋㄧㄢˊ-ㄉㄨˋ"
  case jin1tian1ri4qi2 = "ㄐㄧㄣ-ㄊㄧㄢ-ㄖˋ-ㄑㄧˊ"
  case ming2tian1ri4qi2 = "ㄇㄧㄥˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧˊ"
  case zuo2tian1ri4qi2 = "ㄗㄨㄛˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧˊ"
  case qian2tian1ri4qi2 = "ㄑㄧㄢˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧˊ"
  case hou4tian1ri4qi2 = "ㄏㄡˋ-ㄊㄧㄢ-ㄖˋ-ㄑㄧˊ"
  case jin1tian1ri4qi1 = "ㄐㄧㄣ-ㄊㄧㄢ-ㄖˋ-ㄑㄧ"
  case ming2tian1ri4qi1 = "ㄇㄧㄥˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧ"
  case zuo2tian1ri4qi1 = "ㄗㄨㄛˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧ"
  case qian2tian1ri4qi1 = "ㄑㄧㄢˊ-ㄊㄧㄢ-ㄖˋ-ㄑㄧ"
  case hou4tian1ri4qi1 = "ㄏㄡˋ-ㄊㄧㄢ-ㄖˋ-ㄑㄧ"
  case dang1qian2shi2qu1 = "ㄉㄤ-ㄑㄧㄢˊ-ㄕˊ-ㄑㄩ"
  case mu4qian2shi2qu1 = "ㄇㄨˋ-ㄑㄧㄢˊ-ㄕˊ-ㄑㄩ"
  case suo3zai4shi2qu1 = "ㄙㄨㄛˇ-ㄗㄞˋ-ㄕˊ-ㄑㄩ"
}
