// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

public extension Tekkon {
  // MARK: - Phonabet to Hanyu-Pinyin Conversion Processing

  /// 注音轉拼音，要求陰平必須是空格。
  /// - Parameters:
  ///   - targetJoined: 傳入的 String 對象物件。
  static func cnvPhonaToHanyuPinyin(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrPhonaToHanyuPinyin {
      targetConverted = targetConverted.swapping(pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 漢語拼音數字標調式轉漢語拼音教科書格式，要求陰平必須是數字 1。
  /// - Parameters:
  ///   - target: 傳入的 String 對象物件。
  static func cnvHanyuPinyinToTextbookStyle(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrHanyuPinyinTextbookStyleConversionTable {
      targetConverted = targetConverted.swapping(pair[0], with: pair[1])
    }
    return targetConverted
  }

  /// 該函式負責將注音轉為教科書印刷的方式（先寫輕聲）。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音。
  /// - Returns: 經過轉換處理的讀音。
  static func cnvPhonaToTextbookReading(target: String) -> String {
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
  static func restoreToneOneInPhona(
    target: String
  ) -> String {
    var newNeta = target
    if !"ˊˇˋ˙".has(string: String(target.reversed()[0])), !target.has(string: "_") { newNeta += "1" }
    return newNeta
  }

  /// 該函式用來將漢語拼音轉為注音。
  /// - Parameters:
  ///   - targetJoined: 要轉換的漢語拼音內容，要求必須帶有 12345 數字標調。
  ///   - newToneOne: 對陰平指定新的標記。預設情況下該標記為空字串。
  /// - Returns: 轉換結果。
  static func cnvHanyuPinyinToPhona(targetJoined: String, newToneOne: String = "") -> String {
    /// 如果當前內容有任何除了半形英數內容以外的內容的話，就直接放棄轉換。
    if targetJoined.contains("_") || !targetJoined.isNotPureAlphanumerical { return targetJoined }
    var result = targetJoined
    for key in Tekkon.mapHanyuPinyin.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapHanyuPinyin[key] else { continue }
      result = result.swapping(key, with: value)
    }
    for key in Tekkon.mapArayuruPinyinIntonation.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapArayuruPinyinIntonation[key] else { continue }
      result = result.swapping(key, with: (key == "1") ? newToneOne : value)
    }
    return result
  }
}

/// 檢測字串是否包含半形英數內容
private extension String {
  var isNotPureAlphanumerical: Bool {
    let x = unicodeScalars.map(\.value).filter {
      if $0 >= 48, $0 <= 57 { return false }
      if $0 >= 65, $0 <= 90 { return false }
      if $0 >= 97, $0 <= 122 { return false }
      return true
    }
    return !x.isEmpty
  }
}

// This package is trying to deprecate its dependency of Foundation, hence the following contents.

extension StringProtocol {
  func has(string target: any StringProtocol) -> Bool {
    let selfArray = Array(unicodeScalars)
    let targetArray = Array(target.description.unicodeScalars)
    guard !target.isEmpty else { return isEmpty }
    guard count >= target.count else { return false }
    for index in 0 ..< selfArray.count {
      let range = index ..< (Swift.min(index + targetArray.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped == targetArray { return true }
    }
    return false
  }

  func sliced(by separator: any StringProtocol = "") -> [String] {
    let selfArray = Array(unicodeScalars)
    let arrSeparator = Array(separator.description.unicodeScalars)
    var result: [String] = []
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in 0 ..< selfArray.count {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrSeparator.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrSeparator {
        sleepCount = range.count
        result.append(buffer.map { String($0) }.joined())
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }

  func swapping(_ target: String, with newString: String) -> String {
    let selfArray = Array(unicodeScalars)
    let arrTarget = Array(target.description.unicodeScalars)
    var result = ""
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in 0 ..< selfArray.count {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrTarget.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrTarget {
        sleepCount = ripped.count
        result.append(buffer.map { String($0) }.joined())
        result.append(newString)
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }
}
