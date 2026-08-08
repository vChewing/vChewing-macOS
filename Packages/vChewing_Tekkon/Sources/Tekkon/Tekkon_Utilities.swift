// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Tekkon {
  // MARK: - Phonabet to Hanyu-Pinyin Conversion Processing

  // MARK: - Pre-built lookup for O(N) single-pass conversion.

  /// 從 `arrPhonaToHanyuPinyin` 預建的對照桶：以注音組合的首個 Unicode scalar 為鍵，
  /// 值為該首碼下的所有對照條目（pattern 以 scalar 陣列存放、按長度降冪排列）。
  /// 供零配置滑窗比對，免去逐長度具體化一次性 `String` 查表鍵。
  /// 最長比對優先的語意由桶內長度降冪排序保證（同長度條目內容唯一，順序無影響）。
  private static let _phonaToPinyinBuckets: [Unicode.Scalar: [(
    pattern: [Unicode.Scalar],
    replacement: String
  )]] = {
    var buckets: [Unicode.Scalar: [(pattern: [Unicode.Scalar], replacement: String)]] = [:]
    for (phona, pinyin) in arrPhonaToHanyuPinyin {
      let pattern = Array(phona.unicodeScalars)
      guard let firstScalar = pattern.first else { continue }
      buckets[firstScalar, default: []].append((pattern: pattern, replacement: pinyin))
    }
    buckets.keys.forEach { key in
      buckets[key]?.sort { $0.pattern.count > $1.pattern.count }
    }
    return buckets
  }()

  /// 注音轉拼音，要求陰平必須是空格。
  /// - Parameters:
  ///   - targetJoined: 傳入的 String 對象物件。
  public static func cnvPhonaToHanyuPinyin(targetJoined: String) -> String {
    let scalars = targetJoined.unicodeScalars
    var result = ""
    result.reserveCapacity(targetJoined.count * 2) // pinyin output typically longer than zhuyin
    var i = scalars.startIndex
    let endIndex = scalars.endIndex
    while i < endIndex {
      var matched = false
      // Greedy longest-match first: 桶內條目已按長度降冪排列，比對全程純檢視、零配置。
      if let candidates = _phonaToPinyinBuckets[scalars[i]] {
        for (pattern, replacement) in candidates {
          guard let j = scalars.index(i, offsetBy: pattern.count, limitedBy: endIndex),
                scalars[i ..< j].elementsEqual(pattern) else { continue }
          result.append(replacement)
          i = j
          matched = true
          break
        }
      }
      if !matched {
        result.unicodeScalars.append(scalars[i])
        i = scalars.index(after: i)
      }
    }
    return result
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
    guard let lastScalar = target.unicodeScalars.last else { return target }
    var newNeta = target
    if !"ˊˇˋ˙".unicodeScalars.contains(lastScalar),
       !target.has(string: "_") { newNeta += "1" }
    return newNeta
  }

  /// 預先排序的漢語拼音對照鍵（長度降冪），避免每次轉換都對辭典鍵重新排序。
  private static let _sortedHanyuPinyinKeys: [String] = {
    Tekkon.mapHanyuPinyin.keys.sorted { $0.count > $1.count }
  }()

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
    /// 如果當前內容含有底線或包含任何不在允許列表中的字元（英數、空白、Tab、連字號），則放棄轉換。
    if targetJoined.contains("_") || targetJoined
      .isNotAllowedCharOfPinyinChain { return targetJoined }
    var result = targetJoined
    for key in _sortedHanyuPinyinKeys {
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

// MARK: - Pinyin Chain Character Validation

extension Unicode.Scalar {
  /// 是否為拼音鏈當中不允許出現的字元。
  fileprivate var isNotAllowedScalarOfPinyinChain: Bool {
    // allowed: 0-9, A-Z, a-z, space(32), tab(9), dash(45)
    switch value {
    case 9, 32, 45, 48 ... 57, 65 ... 90, 97 ... 122: return false
    default: return true
    }
  }
}

/// 偵測字串是否包含半形英數內容
extension String {
  fileprivate var isNotAllowedCharOfPinyinChain: Bool {
    // 單趟掃描、遇到首個不允許字元即短路，不建立任何一次性陣列。
    unicodeScalars.contains { $0.isNotAllowedScalarOfPinyinChain }
  }
}

extension Character {
  fileprivate var isNotAllowedCharOfPinyinChain: Bool {
    unicodeScalars.contains { $0.isNotAllowedScalarOfPinyinChain }
  }
}

// This package is trying to deprecate its dependency of Foundation, hence the following contents.

extension StringProtocol {
  /// 檢查字串中是否包含指定子字串（純 Swift 實作，無 Foundation 相依）。
  ///
  /// - Parameters:
  ///   - target: 要查找的子字串。
  /// - Returns: 如果包含則回傳 true，否則回傳 false。
  ///
  /// 注意：此方法以 Unicode Scalar 為單位進行比對，對一些複雜合字或合成字情況可能與 Foundation 的 `contains` 行為略有不同。
  func has(string target: any StringProtocol) -> Bool {
    let scalars = unicodeScalars
    let targetScalars = target.description.unicodeScalars
    guard !target.isEmpty else { return scalars.isEmpty }
    let targetCount = targetScalars.count
    guard scalars.count >= targetCount else { return false }
    // 純檢視（view）滑窗掃描：不建立任何一次性陣列，每個滑窗以 elementsEqual 逐個比對。
    var offset = 0
    let lastOffset = scalars.count - targetCount
    while offset <= lastOffset {
      if scalars.dropFirst(offset).prefix(targetCount).elementsEqual(targetScalars) {
        return true
      }
      offset += 1
    }
    return false
  }

  /// 檢查字串中是否包含指定 Unicode scalar。
  /// - Parameter target: 要查找的 Unicode scalar。
  /// - Returns: 如果包含則回傳 true，否則回傳 false。
  func has(scalar target: Unicode.Scalar) -> Bool {
    unicodeScalars.contains(target)
  }

  /// 以純 Swift 方法將字串中的指定子字串替換為另一字串（無 Foundation 相依）。
  ///
  /// - Parameters:
  ///   - target: 要被替換的子字串。
  ///   - newString: 替換之後的新字串。
  /// - Returns: 替換完成的字串。
  ///
  /// 注意：此方法以 Unicode Scalar 為單位進行比對，且比對不重疊（自左向右、命中即跳過整段目標）。
  /// 對一些複雜合字或合成字情況可能與 Foundation 的替換行為略有不同。
  func swapping(_ target: some StringProtocol, with newString: some StringProtocol) -> String {
    let scalars = unicodeScalars
    let targetScalars = target.description.unicodeScalars
    let targetCount = targetScalars.count
    // 空目標的既有語義：原樣回傳自身。
    guard targetCount > 0 else { return description }
    var result = ""
    result.reserveCapacity(count)
    var i = scalars.startIndex
    let endIndex = scalars.endIndex
    // 單趟索引走訪：命中窗口即附加替換內容並整段跳過，否則逐 scalar 附加。
    // 全程純檢視比對，不建立任何一次性陣列。
    while i < endIndex {
      if let j = scalars.index(i, offsetBy: targetCount, limitedBy: endIndex),
         scalars[i ..< j].elementsEqual(targetScalars) {
        result.append(newString.description)
        i = j
      } else {
        result.unicodeScalars.append(scalars[i])
        i = scalars.index(after: i)
      }
    }
    return result
  }
}
