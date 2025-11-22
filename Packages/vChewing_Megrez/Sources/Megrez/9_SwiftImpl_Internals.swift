// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// This package is trying to deprecate its dependency of Foundation, hence this file.

extension StringProtocol {
  /// 檢查字串中是否包含指定子字串。
  ///
  /// - 注意：此方法不仰賴 Foundation API，而是以 Unicode Scalar 為單位執行逐位比對。
  ///         因此在處理複雜的 Compose 字元（如合字）時結果可能與 Foundation 的 substring
  ///         搜尋略有差異；但該實作在純 Swift 環境下效能良好且不會引入 Foundation 的相依性。
  /// - Parameters:
  ///   - target: 要查找的子字串（可接受任何符合 StringProtocol 的型別）。
  /// - Returns: 如果找到則回傳 true，否則回傳 false。
  ///
  /// 範例：
  /// "abcd".has(string: "bc")  => true
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

  func sliced(by separator: any StringProtocol = "") -> [String] {
    /// 以指定分界字元拆分字串，回傳字串陣列；等同於 `split` 的功能，但不使用 Foundation。
    ///
    /// - 注意：該實作會將分隔符視為完整字串進行比對（以 Unicode Scalar 為基準），
    ///         若分隔符為空字串，則會視為不做分割。
    /// - Parameters:
    ///   - separator: 作為斷詞分界的字串，預設為空字串。
    /// - Returns: 拆分後的字串陣列，若輸入為空回傳空陣列（視實作情況）。
    ///
    /// 範例：
    /// "a-b-c".sliced(by: "-") => ["a","b","c"]
    let selfArray = Array(unicodeScalars)
    let arrSeparator = Array(separator.description.unicodeScalars)
    var result: [String] = []
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in selfArray.indices {
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

  /// 以純 Swift 方法將字串中的指定子字串替換為另一字串。
  ///
  /// - Parameters:
  ///   - target: 要被替換的子字串。
  ///   - newString: 替換為的新字串。
  /// - Returns: 替換完成的字串。
  ///
  /// 注意：此函式使用 Unicode Scalar 做逐個比對，不會使用 Foundation 的 replace API，
  /// 因此在面對某些特殊 Unicode 合字組合時，行為可能與 Foundation 產生差異。
  ///
  /// 範例：
  /// "a-b-c".swapping("-","+") => "a+b+c"
  func swapping(_ target: String, with newString: String) -> String {
    let selfArray = Array(unicodeScalars)
    let arrTarget = Array(target.description.unicodeScalars)
    var result = ""
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

// MARK: - FIUUID

/// A lightweight pseudo-UUID，採用兩個 UInt64 儲存 128 位元識別值，以維持標準 UUID 字串格式且降低陣列開銷。
@frozen
public struct FIUUID: Hashable, Codable, Sendable {
  // MARK: Lifecycle

  public init() {
    self.highBits = UInt64.random(in: UInt64.min ... UInt64.max)
    self.lowBits = UInt64.random(in: UInt64.min ... UInt64.max)
  }

  public init(highBits: UInt64, lowBits: UInt64) {
    self.highBits = highBits
    self.lowBits = lowBits
  }

  /// 與先前 64 位元版本相容：會將值儲存在低位元，並將高位元清零。
  public init(rawValue: UInt64) {
    self.highBits = 0
    self.lowBits = rawValue
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let stringValue = try? container.decode(String.self) {
      guard let decoded = Self(uuidString: stringValue) else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Invalid UUID string for FIUUID."
        )
      }
      self = decoded
      return
    }

    if let pair = try? container.decode([UInt64].self), pair.count == 2 {
      self.init(highBits: pair[0], lowBits: pair[1])
      return
    }

    if let legacyRaw = try? container.decode(UInt64.self) {
      self.init(rawValue: legacyRaw)
      return
    }

    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Unsupported FIUUID encoding."
    )
  }

  /// 依照 UUID 字串初始化識別值，支援大小寫。
  public init?(uuidString: String) {
    let filtered = uuidString.filter { $0 != "-" }
    guard filtered.count == 32 else { return nil }

    var bytes: [UInt8] = []
    bytes.reserveCapacity(16)

    var index = filtered.startIndex
    for _ in 0 ..< 16 {
      let highChar = filtered[index]
      index = filtered.index(after: index)
      let lowChar = filtered[index]
      index = filtered.index(after: index)

      guard let high = Self.hexValue(of: highChar),
            let low = Self.hexValue(of: lowChar)
      else { return nil }

      bytes.append((high << 4) | low)
    }

    self.init(bytes: bytes)
  }

  private init(bytes: [UInt8]) {
    self.highBits = Self.readBigEndian(from: bytes, offset: 0)
    self.lowBits = Self.readBigEndian(from: bytes, offset: 8)
  }

  // MARK: Public

  /// 高 64 位元與低 64 位元的原始識別值。
  public let highBits: UInt64
  public let lowBits: UInt64

  /// 以標準 UUID 格式（xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）返回識別字串。
  ///
  /// - Parameters:
  ///   - uppercase: 是否回傳大寫字母（預設 true）。
  /// - Returns: 符合 UUID 標準格式的字串表示。
  ///
  /// 範例：
  /// FIUUID().uuidString() => "AABBCCDD-..."
  public func uuidString(uppercase: Bool = true) -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    Self.write(bigEndian: highBits, to: &bytes, offset: 0)
    Self.write(bigEndian: lowBits, to: &bytes, offset: 8)

    let hexDigits = uppercase ? Self.upperHexDigits : Self.lowerHexDigits
    var characters: [Character] = []
    characters.reserveCapacity(36)

    for index in 0 ..< bytes.count {
      if index == 4 || index == 6 || index == 8 || index == 10 {
        characters.append("-")
      }
      let byte = bytes[index]
      characters.append(hexDigits[Int(byte >> 4)])
      characters.append(hexDigits[Int(byte & 0x0F)])
    }

    return String(characters)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(uuidString())
  }

  // MARK: Private

  private static let upperHexDigits: [Character] = Array("0123456789ABCDEF")
  private static let lowerHexDigits: [Character] = Array("0123456789abcdef")

  private static func write(bigEndian value: UInt64, to buffer: inout [UInt8], offset: Int) {
    for index in 0 ..< 8 {
      buffer[offset + index] = UInt8(truncatingIfNeeded: value >> (8 * (7 - index)))
    }
  }

  private static func readBigEndian(from buffer: [UInt8], offset: Int) -> UInt64 {
    var result: UInt64 = 0
    for index in 0 ..< 8 {
      result = (result << 8) | UInt64(buffer[offset + index])
    }
    return result
  }

  /// 取得 16 進位字元的數值表示，支援大小寫字母與數字 0~9。
  /// - Parameter character: 要轉換的 16 進位字元。
  /// - Returns: 對應的數值（0..15），若非合法 16 進位字元則回傳 nil。
  private static func hexValue(of character: Character) -> UInt8? {
    switch character {
    case "0" ... "9":
      return UInt8(character.unicodeScalars.first!.value - Unicode.Scalar("0").value)
    case "a" ... "f":
      return UInt8(character.unicodeScalars.first!.value - Unicode.Scalar("a").value + 10)
    case "A" ... "F":
      return UInt8(character.unicodeScalars.first!.value - Unicode.Scalar("A").value + 10)
    default:
      return nil
    }
  }
}
