// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

public class ChineseConverter {
  public static let shared = HotenkaChineseConverter.init(plistDir: mgrLangModel.getBundleDataPath("convdict"))

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
    return
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
    return shared.convert(strObj, to: .zhHantKX)
  }

  public static func cnvTradToJIS(_ strObj: String) -> String {
    // 該轉換是由康熙繁體轉換至日語當用漢字的，所以需要先跑一遍康熙轉換。
    let strObj = cnvTradToKangXi(strObj)
    return shared.convert(strObj, to: .zhHansJP)
  }
}
