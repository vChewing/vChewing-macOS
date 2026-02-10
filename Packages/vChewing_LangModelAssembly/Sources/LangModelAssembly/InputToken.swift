// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - LMAssembly.InputToken

/// 工作原理：先用 InputToken.parse 分析原始字串，給出準確的 Token。
/// 然後再讓這個 Token 用 .translated() 自我表述出轉換結果。

extension LMAssembly {
  enum InputToken {
    case timeZone(shortened: Bool)
    case timeNow(shortened: Bool)
    case date(dayDelta: Int = 0, yearDelta: Int = 0, shortened: Bool = true, luna: Bool = false)
    case week(dayDelta: Int = 0, shortened: Bool = true)
    case year(yearDelta: Int = 0)
    case yearGanzhi(yearDelta: Int = 0)
    case yearZodiac(yearDelta: Int = 0)
  }
}

// MARK: - 正式對外投入使用的 API。

extension String {
  public func parseAsInputToken(isCHS: Bool) -> [String] {
    LMAssembly.InputToken.parse(from: self).map { $0.translated(isCHS: isCHS) }.flatMap { $0 }
      .deduplicated
  }
}

// MARK: - Parser parsing raw token value to construct token.

extension LMAssembly.InputToken {
  static func parse(from rawToken: String) -> [LMAssembly.InputToken] {
    var result: [LMAssembly.InputToken] = []
    guard rawToken.prefix(6) == "MACRO@" else { return result }
    var mapParams: [String: Int] = [:]
    let tokenComponents = rawToken.dropFirst(6).split(separator: "_").map { param in
      let result = param.uppercased()
      let kvPair = param.split(separator: ":")
      guard kvPair.count == 2 else { return result }
      guard let pairValue = Int(kvPair[1]) else { return result }
      mapParams[kvPair[0].description] = pairValue
      return result
    }
    guard !tokenComponents.isEmpty else { return result }
    // 準備接收參數。
    let dayDelta: Int = mapParams["dayDelta".uppercased()] ?? 0
    let yearDelta: Int = mapParams["yearDelta".uppercased()] ?? 0
    let shortened: Bool = tokenComponents.contains("SHORTENED")
    let hasZodiac: Bool = tokenComponents.contains("ZODIAC")
    let hasGanzhi: Bool = tokenComponents.contains("GANZHI")
    let hasLuna: Bool = tokenComponents.contains("LUNA")

    switch tokenComponents[0] {
    case "TIMEZONE": result.append(.timeZone(shortened: shortened))
    case "TIME": result.append(.timeNow(shortened: shortened))
    case "DATE": result
      .append(.date(dayDelta: dayDelta, yearDelta: yearDelta, shortened: shortened, luna: hasLuna))
    case "WEEK": result.append(.week(dayDelta: dayDelta, shortened: shortened))
    case "YEAR": result.append(.year(yearDelta: yearDelta)) // 始終插入公曆年，方便對比參考。
      if hasZodiac { result.append(.yearZodiac(yearDelta: yearDelta)) }
      if hasGanzhi { result.append(.yearGanzhi(yearDelta: yearDelta)) }
    default: break
    }
    return result
  }
}

// MARK: - Parser parsing token itself.

extension LMAssembly.InputToken {
  func translated(isCHS: Bool) -> [String] {
    let locale = Locale(identifier: isCHS ? "zh-Hans" : "zh-Hant-TW")
    let formatter = DateFormatter()
    formatter.locale = locale
    let currentDate = Date()
    var dateToDescribe = currentDate // 接下來會針對給定參數修正這個資料值。
    var results: [String] = []

    /// 內部函式，用來修正 dateToDescribe 自身的參數值。
    func applyDelta(for type: Calendar.Component, delta deltaValue: Int) {
      switch type {
      case .year:
        var delta = DateComponents()
        let thisYear = Calendar.current.dateComponents([.year], from: currentDate).year ?? 2_018
        delta.year = max(deltaValue, thisYear * -1)
        dateToDescribe = Calendar.current.date(byAdding: delta, to: currentDate) ?? currentDate
      case .day:
        let dayLength = 60 * 60 * 24
        dateToDescribe = dateToDescribe.addingTimeInterval(Double(dayLength * deltaValue))
      default: break
      }
    }

    // 計算結果。
    switch self {
    case let .timeZone(shortened): // 時區
      let resultToAdd = TimeZone.current.localizedName(
        for: shortened ? .shortGeneric : .standard, locale: locale
      ) ?? TimeZone.current.description
      results.append(resultToAdd)
    case let .timeNow(shortened): // 當前時間
      var formats = [String]()
      switch (isCHS, shortened) {
      case (false, true): formats.append(contentsOf: ["HH:mm", "HH點mm分", "HH時mm分"])
      case (false, false): formats.append(contentsOf: ["HH:mm:ss", "HH點mm分ss秒", "HH時mm分ss秒"])
      case (true, true): formats.append(contentsOf: ["HH:mm", "HH点mm分", "HH时mm分"])
      case (true, false): formats.append(contentsOf: ["HH:mm:ss", "HH点mm分ss秒", "HH时mm分ss秒"])
      }
      formats.forEach { formatString in
        formatter.dateFormat = formatString
        results.append(formatter.string(from: dateToDescribe))
      }
      let resultsExtra: [String] = results.compactMap {
        guard !$0.contains(":") else { return nil }
        var newResult = $0
        if newResult.first == "0" { newResult = newResult.dropFirst().description }
        if newResult.prefix(2) == "2点" || newResult.prefix(2) == "2點" {
          newResult = (isCHS ? "两点" : "兩點") + newResult.dropFirst(2).description
        }
        newResult = newResult.convertArabicNumeralsToChinese(onlyDigits: false)
        newResult = newResult.replacingOccurrences(of: "〇", with: "零")
        return newResult
      }
      results.append(contentsOf: resultsExtra)
    case let .date(dayDelta, yearDelta, shortened, hasLuna): // 日期
      applyDelta(for: .year, delta: yearDelta)
      applyDelta(for: .day, delta: dayDelta)
      // 農曆單獨處理。
      guard !hasLuna else {
        formatter.calendar = .init(identifier: .chinese)
        formatter.dateStyle = .medium
        formatter.dateFormat = "MMMd"
        let dateString = formatter.string(from: dateToDescribe)
        formatter.dateFormat = "U"
        let yearGanzhi = formatter.string(from: dateToDescribe)
        results.append("\(yearGanzhi)年\(dateString)")
        if let yearZodiac = mapGanzhiToZodiac[yearGanzhi] {
          results.append("\(isCHS ? yearZodiac.1 : yearZodiac.0)年\(dateString)")
        }
        break
      }
      let formats: [String] = [
        "MM-dd", "M月d日", "MM月dd日",
      ]
      var additionalResult: String?
      for (i, formatString) in formats.enumerated() {
        formatter.dateFormat = formatString
        let dateStr = formatter.string(from: dateToDescribe)
        switch (i == 0, shortened) {
        case (false, true): formatter.dateFormat = "yy年"
        case (true, false): formatter.dateFormat = "y-"
        case (false, false): formatter.dateFormat = "y年"
        case (true, true): formatter.dateFormat = "yy-"
        }
        let yearStr = formatter.string(from: dateToDescribe)
        if i == 1 {
          let anotherDateStr = dateStr.convertArabicNumeralsToChinese(onlyDigits: false)
          let anotherYearStr = yearStr.convertArabicNumeralsToChinese(onlyDigits: true)
          additionalResult = anotherYearStr + anotherDateStr
        }
        let newResult = yearStr + dateStr
        guard !results.contains(newResult) else { continue }
        results.append(newResult)
      }
      if let additionalResult = additionalResult {
        results.append(additionalResult)
      }
    case let .week(dayDelta, shortened): // 星期
      applyDelta(for: .day, delta: dayDelta)
      formatter.dateFormat = shortened ? "EE" : "EEEE"
      results.append(formatter.string(from: dateToDescribe))
    case let .year(yearDelta): // 年度
      applyDelta(for: .year, delta: yearDelta)
      formatter.dateFormat = "U年"
      formatter.calendar = .init(identifier: .gregorian)
      let result = formatter.string(from: dateToDescribe)
      results.append(result)
      results.append(result.convertArabicNumeralsToChinese(onlyDigits: true))
    case let .yearGanzhi(yearDelta): // 幹支（其實嚴格來講「干支」才是錯的）
      applyDelta(for: .year, delta: yearDelta)
      formatter.dateFormat = "U年"
      formatter.calendar = .init(identifier: .chinese)
      let result = formatter.string(from: dateToDescribe)
      results.append(result)
    case let .yearZodiac(yearDelta): // 十二生肖
      applyDelta(for: .year, delta: yearDelta)
      formatter.dateFormat = "U"
      formatter.calendar = .init(identifier: .chinese)
      let rawKey = formatter.string(from: dateToDescribe)
      guard let rawResultPair = mapGanzhiToZodiac[rawKey] else { break }
      let rawResult = isCHS ? rawResultPair.1 : rawResultPair.0
      results.append(rawResult + "年")
    }

    return results
  }
}

/// 註一：天干地支在簡體中文與繁體中文的寫法完全雷同。
/// 註二：此處採吐蕃的陰陽五行生肖法、而非突厥五行納音生肖法。
private let mapGanzhiToZodiac: [String: (String, String)] = [
  "甲子": ("木鼠", "木鼠"), "乙丑": ("木牛", "木牛"), "丙寅": ("火虎", "火虎"), "丁卯": ("火兔", "火兔"),
  "戊辰": ("土龍", "土龙"), "己巳": ("土蛇", "土蛇"), "庚午": ("金馬", "金马"), "辛未": ("金羊", "金羊"),
  "壬申": ("水猴", "水猴"), "癸酉": ("水雞", "水鸡"), "甲戌": ("木狗", "木狗"), "乙亥": ("木豬", "木猪"),
  "丙子": ("火鼠", "火鼠"), "丁丑": ("火牛", "火牛"), "戊寅": ("土虎", "土虎"), "己卯": ("土兔", "土兔"),
  "庚辰": ("金龍", "金龙"), "辛巳": ("金蛇", "金蛇"), "壬午": ("水馬", "水马"), "癸未": ("水羊", "水羊"),
  "甲申": ("木猴", "木猴"), "乙酉": ("木雞", "木鸡"), "丙戌": ("火狗", "火狗"), "丁亥": ("火豬", "火猪"),
  "戊子": ("土鼠", "土鼠"), "己丑": ("土牛", "土牛"), "庚寅": ("金虎", "金虎"), "辛卯": ("金兔", "金兔"),
  "壬辰": ("水龍", "水龙"), "癸巳": ("水蛇", "水蛇"), "甲午": ("木馬", "木马"), "乙未": ("木羊", "木羊"),
  "丙申": ("火猴", "火猴"), "丁酉": ("火雞", "火鸡"), "戊戌": ("土狗", "土狗"), "己亥": ("土豬", "土猪"),
  "庚子": ("金鼠", "金鼠"), "辛丑": ("金牛", "金牛"), "壬寅": ("水虎", "水虎"), "癸卯": ("水兔", "水兔"),
  "甲辰": ("木龍", "木龙"), "乙巳": ("木蛇", "木蛇"), "丙午": ("火馬", "火马"), "丁未": ("火羊", "火羊"),
  "戊申": ("土猴", "土猴"), "己酉": ("土雞", "土鸡"), "庚戌": ("金狗", "金狗"), "辛亥": ("金豬", "金猪"),
  "壬子": ("水鼠", "水鼠"), "癸丑": ("水牛", "水牛"), "甲寅": ("木虎", "木虎"), "乙卯": ("木兔", "木兔"),
  "丙辰": ("火龍", "火龙"), "丁巳": ("火蛇", "火蛇"), "戊午": ("土馬", "土马"), "己未": ("土羊", "土羊"),
  "庚申": ("金猴", "金猴"), "辛酉": ("金雞", "金鸡"), "壬戌": ("水狗", "水狗"), "癸亥": ("水豬", "水猪"),
]

// MARK: - Date Time Language Conversion Extension

private let tableMappingArabicDatesToChinese: [String: String] = {
  let formatter = NumberFormatter()
  formatter.locale = Locale(identifier: "zh-Hant-TW") // 預設是英文，設定為中文。繁簡一致。
  formatter.numberStyle = .spellOut
  var result = [String: String]()
  for i in 0 ... 60 {
    result[i.description] = formatter.string(from: NSNumber(value: i))
  }
  return result
}()

/// 預先排序好的 key 陣列（按長度遞減），避免每次呼叫重新排序。
private let sortedArabicDateKeys: [String] = {
  tableMappingArabicDatesToChinese.keys.sorted { $0.count > $1.count }
}()

extension String {
  /// 將給定的字串當中的阿拉伯數字轉為漢語小寫，逐字轉換。
  /// - Parameter target: 要進行轉換操作的對象，會直接修改該對象。
  fileprivate func convertArabicNumeralsToChinese(onlyDigits: Bool) -> String {
    var target = self
    for key in sortedArabicDateKeys {
      if onlyDigits, key.count > 1 { continue }
      guard let result = tableMappingArabicDatesToChinese[key] else { continue }
      target = target.replacingOccurrences(of: key, with: result)
    }
    return target
  }
}
