// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// This package is trying to deprecate its dependency of Foundation, hence this file.

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

  func sliced(by separator: any StringProtocol = "") -> [String] {
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

/// A simple UUID v4 implementation without Foundation.
/// Generates a random 128-bit UUID compliant with RFC 4122.
public struct FIUUID: Hashable, Codable {
  // MARK: Lifecycle

  public init() {
    var rng = SystemRandomNumberGenerator()
    self.bytes = Self.randomBytes(count: 16, using: &rng)
    // Set version to 4
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    // Set variant to 1 (RFC 4122)
    bytes[8] = (bytes[8] & 0x3F) | 0x80
  }

  // MARK: Public

  /// Returns the UUID as a standard hyphenated string (e.g., "123e4567-e89b-12d3-a456-426614174000").
  public func uuidString() -> String {
    let hexDigits = bytes.map { byte in
      let hex = String(byte, radix: 16)
      return hex.count == 1 ? "0" + hex : hex
    }
    let hexString = hexDigits.joined()
    let part1 = hexString.prefix(8)
    let part2 = hexString.dropFirst(8).prefix(4)
    let part3 = hexString.dropFirst(12).prefix(4)
    let part4 = hexString.dropFirst(16).prefix(4)
    let part5 = hexString.suffix(12)
    return "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
  }

  // MARK: Private

  private var bytes: [UInt8]

  private static func randomBytes(
    count: Int,
    using rng: inout SystemRandomNumberGenerator
  )
    -> [UInt8] {
    var result = [UInt8](repeating: 0, count: count)
    var offset = 0
    while offset < count {
      let randomValue = rng.next()
      withUnsafeBytes(of: randomValue) { buffer in
        let bytesToCopy = min(8, count - offset)
        let byteCount = min(bytesToCopy, buffer.count)
        for i in 0 ..< byteCount {
          result[offset + i] = buffer[i]
        }
        offset += byteCount
      }
    }
    return result
  }
}
