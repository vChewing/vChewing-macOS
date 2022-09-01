// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public enum ChineseConverter {
  public static let shared = HotenkaChineseConverter(plistDir: mgrLangModel.getBundleDataPath("convdict"))

  private static var punctuationConversionTable: [(String, String)] = [
    ("【", "︻"), ("】", "︼"), ("〖", "︗"), ("〗", "︘"), ("〔", "︹"), ("〕", "︺"), ("《", "︽"), ("》", "︾"),
    ("〈", "︿"), ("〉", "﹀"), ("「", "﹁"), ("」", "﹂"), ("『", "﹃"), ("』", "﹄"), ("｛", "︷"), ("｝", "︸"),
    ("（", "︵"), ("）", "︶"), ("［", "﹇"), ("］", "﹈"),
  ]

  /// 將操作對象內的橫排標點轉為縱排標點。
  /// 本來是不推薦使用的，但某些極端的排版情形下、使用的中文字型不支援縱排標點自動切換，才需要這個功能。
  /// - Parameters:
  ///   - target: 轉換目標。
  ///   - convert: 是否真的執行此操作。不填寫的話，該函式不執行。
  public static func hardenVerticalPunctuations(target: inout String, convert: Bool = false) {
    guard convert else { return }
    for neta in ChineseConverter.punctuationConversionTable {
      target = target.replacingOccurrences(of: neta.0, with: neta.1)
    }
  }

  // 給 JIS 轉換模式新增疊字符號支援。
  private static func processKanjiRepeatSymbol(target: inout String) {
    guard !target.isEmpty else { return }
    var arr = target.charComponents
    for (i, char) in arr.enumerated() {
      if i == 0 { continue }
      if char == target.charComponents[i - 1] {
        arr[i] = "々"
      }
    }
    target = arr.joined()
  }

  /// 漢字數字大寫轉換專用辭典，順序為：康熙、當代繁體中文、日文、簡體中文。
  private static let currencyNumeralDictTable: [String: (String, String, String, String)] = [
    "一": ("壹", "壹", "壹", "壹"), "二": ("貳", "貳", "弐", "贰"), "三": ("叄", "參", "参", "叁"),
    "四": ("肆", "肆", "肆", "肆"), "五": ("伍", "伍", "伍", "伍"), "六": ("陸", "陸", "陸", "陆"),
    "七": ("柒", "柒", "柒", "柒"), "八": ("捌", "捌", "捌", "捌"), "九": ("玖", "玖", "玖", "玖"),
    "十": ("拾", "拾", "拾", "拾"), "百": ("佰", "佰", "佰", "佰"), "千": ("仟", "仟", "仟", "仟"),
    "万": ("萬", "萬", "萬", "万"), "〇": ("零", "零", "零", "零"),
  ]

  /// 將指定字串內的小寫漢字數字轉換為大寫，會對轉換對象進行直接修改操作。
  /// - Parameter target: 轉換對象。
  public static func ensureCurrencyNumerals(target: inout String) {
    if !mgrPrefs.currencyNumeralsEnabled { return }
    for key in currencyNumeralDictTable.keys {
      guard let result = currencyNumeralDictTable[key] else { continue }
      if IME.currentInputMode == InputMode.imeModeCHS {
        target = target.replacingOccurrences(of: key, with: result.3)  // Simplified Chinese
        continue
      }
      switch (mgrPrefs.chineseConversionEnabled, mgrPrefs.shiftJISShinjitaiOutputEnabled) {
        case (false, true), (true, true): target = target.replacingOccurrences(of: key, with: result.2)  // JIS
        case (true, false): target = target.replacingOccurrences(of: key, with: result.0)  // KangXi
        default: target = target.replacingOccurrences(of: key, with: result.1)  // Contemporary
      }
    }
  }

  private static let tableMappingArabicNumeralsToChinese: [String: String] = [
    "0": "〇", "1": "一", "2": "二", "3": "三", "4": "四", "5": "五", "6": "六", "7": "七", "8": "八", "9": "九",
  ]

  /// 將給定的字串當中的阿拉伯數字轉為漢語小寫，逐字轉換。
  /// - Parameter target: 要進行轉換操作的對象，會直接修改該對象。
  public static func convertArabicNumeralsToChinese(target: String) -> String {
    var target = target
    for key in tableMappingArabicNumeralsToChinese.keys {
      guard let result = tableMappingArabicNumeralsToChinese[key] else { continue }
      target = target.replacingOccurrences(of: key, with: result)
    }
    return target
  }

  /// CrossConvert.
  ///
  /// - Parameter string: Text in Original Script.
  /// - Returns: Text converted to Different Script.
  public static func crossConvert(_ string: String) -> String? {
    switch IME.currentInputMode {
      case InputMode.imeModeCHS:
        return shared.convert(string, to: .zhHantTW)
      case InputMode.imeModeCHT:
        return shared.convert(string, to: .zhHansCN)
      default:
        return string
    }
  }

  public static func cnvTradToKangXi(_ strObj: String) -> String {
    shared.convert(strObj, to: .zhHantKX)
  }

  public static func cnvTradToJIS(_ strObj: String) -> String {
    // 該轉換是由康熙繁體轉換至日語當用漢字的，所以需要先跑一遍康熙轉換。
    let strObj = cnvTradToKangXi(strObj)
    var result = shared.convert(strObj, to: .zhHansJP)
    processKanjiRepeatSymbol(target: &result)
    return result
  }
}
