// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension Tekkon {
  // MARK: - Phonabet to Hanyu-Pinyin Conversion Processing

  /// 注音轉拼音，要求陰平必須是空格。
  /// - Parameters:
  ///   - targetJoined: 傳入的 String 對象物件。
  public static func cnvPhonaToHanyuPinyin(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrPhonaToHanyuPinyin {
      targetConverted = targetConverted.replacingOccurrences(of: pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 漢語拼音數字標調式轉漢語拼音教科書格式，要求陰平必須是數字 1。
  /// - Parameters:
  ///   - target: 傳入的 String 對象物件。
  public static func cnvHanyuPinyinToTextbookStyle(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrHanyuPinyinTextbookStyleConversionTable {
      targetConverted = targetConverted.replacingOccurrences(of: pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 該函式負責將注音轉為教科書印刷的方式（先寫輕聲）。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音。
  /// - Returns: 經過轉換處理的讀音。
  public static func cnvPhonaToTextbookReading(target: String) -> String {
    var newString = target
    if String(target.reversed()[0]) == "˙" {
      newString = String(target.dropLast())
      newString.insert("˙", at: newString.startIndex)
    }
    return newString
  }

  /// 該函式用來恢復注音當中的陰平聲調，恢復之後會以「1」表示陰平。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音。
  /// - Returns: 經過轉換處理的讀音。
  public static func restoreToneOneInPhona(
    target: String
  ) -> String {
    var newNeta = target
    if !"ˊˇˋ˙".contains(String(target.reversed()[0])), !target.contains("_") { newNeta += "1" }
    return newNeta
  }

  /// 該函式用來將漢語拼音轉為注音。
  /// - Parameters:
  ///   - targetJoined: 要轉換的漢語拼音內容，要求必須帶有 12345 數字標調。
  ///   - newToneOne: 對陰平指定新的標記。預設情況下該標記為空字串。
  /// - Returns: 轉換結果。
  public static func cnvHanyuPinyinToPhona(targetJoined: String, newToneOne: String = "") -> String {
    /// 如果當前內容有任何除了半形英數內容以外的內容的話，就直接放棄轉換。
    if targetJoined.contains("_") || !targetJoined.isNotPureAlphanumerical { return targetJoined }
    var result = targetJoined
    for key in Tekkon.mapHanyuPinyin.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapHanyuPinyin[key] else { continue }
      result = result.replacingOccurrences(of: key, with: value)
    }
    for key in Tekkon.mapArayuruPinyinIntonation.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapArayuruPinyinIntonation[key] else { continue }
      result = result.replacingOccurrences(of: key, with: (key == "1") ? newToneOne : value)
    }
    return result
  }
}

/// 檢測字串是否包含半形英數內容
extension String {
  fileprivate var isNotPureAlphanumerical: Bool {
    let regex = ".*[^A-Za-z0-9].*"
    let testString = NSPredicate(format: "SELF MATCHES %@", regex)
    return testString.evaluate(with: self)
  }
}
