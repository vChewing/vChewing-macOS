// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Tekkon {
  // MARK: - Phonabet to Hanyu-Pinyin Conversion Processing

  /// 注音轉拼音，要求陰平必須是空格。
  /// - Parameters:
  ///   - targetJoined: 傳入的 String 對象物件。
  public static func cnvPhonaToHanyuPinyin(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrPhonaToHanyuPinyin {
      targetConverted = targetConverted.swapping(pair.0, with: pair.1)
    }
    return targetConverted
  }

  /// 漢語拼音數字標調式轉漢語拼音教科書格式，要求陰平必須是數字 1。
  /// - Parameters:
  ///   - target: 傳入的 String 對象物件。
  public static func cnvHanyuPinyinToTextbookStyle(targetJoined: String) -> String {
    var targetConverted = targetJoined
    for pair in arrHanyuPinyinTextbookStyleConversionTable {
      targetConverted = targetConverted.swapping(pair.0, with: pair.1)
    }
    return targetConverted
  }

  /// 該函式負責將注音轉為教科書印刷的方式（先寫輕聲）。
  /// - Parameters:
  ///   - target: 要拿來做轉換處理的讀音。
  /// - Returns: 經過轉換處理的讀音。
  public static func cnvPhonaToTextbookStyle(target: String) -> String {
    var newString = target
    if target.last == "˙" {
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
  )
    -> String {
    var newNeta = target
    if !"ˊˇˋ˙".has(string: String(target.reversed()[0])),
       !target.has(string: "_") { newNeta += "1" }
    return newNeta
  }

  /// 該函式用來將漢語拼音轉為注音。
  /// - Parameters:
  ///   - targetJoined: 要轉換的漢語拼音內容，要求必須帶有 12345 數字標調。
  ///   - newToneOne: 對陰平指定新的標記。預設情況下該標記為空字串。
  /// - Returns: 轉換結果。
  public static func cnvHanyuPinyinToPhona(
    targetJoined: String,
    newToneOne: String = ""
  )
    -> String {
    /// 如果當前內容有任何除了半形英數內容以外的內容的話，就直接放棄轉換。
    if targetJoined.contains("_") || !targetJoined.isNotPureAlphanumerical { return targetJoined }
    var result = targetJoined
    for key in Tekkon.mapHanyuPinyin.keys.sorted(by: { $0.count > $1.count }) {
      guard let value = Tekkon.mapHanyuPinyin[key] else { continue }
      result = result.swapping(key, with: value)
    }
    for key in Tekkon.mapArayuruPinyinIntonation.keys {
      guard let value = Tekkon.mapArayuruPinyinIntonation[key] else { continue }
      result = result.swapping(String(key), with: (key == "1") ? newToneOne : String(value))
    }
    return result
  }
}

/// 檢測字串是否包含半形英數內容
extension String {
  fileprivate var isNotPureAlphanumerical: Bool {
    let x = unicodeScalars.map(\.value).filter {
      if $0 >= 48, $0 <= 57 { return false }
      if $0 >= 65, $0 <= 90 { return false }
      if $0 >= 97, $0 <= 122 { return false }
      return true
    }
    return !x.isEmpty
  }
}

extension Character {
  fileprivate var isNotPureAlphanumerical: Bool {
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
    for index in selfArray.indices {
      let range = index ..< (Swift.min(index + targetArray.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped == targetArray { return true }
    }
    return false
  }

  func has(scalar target: Unicode.Scalar) -> Bool {
    let targetStr = String(Character(target))
    return has(string: targetStr)
  }

  func swapping(_ target: some StringProtocol, with newString: some StringProtocol) -> String {
    let selfArray = Array(unicodeScalars)
    let arrTarget = Array(target.description.unicodeScalars)
    var result = [String]()
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in selfArray.indices {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrTarget.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrTarget {
        sleepCount = ripped.count
        result.append(buffer.map { String($0) }.joined())
        result.append(newString.description)
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result.joined()
  }
}
