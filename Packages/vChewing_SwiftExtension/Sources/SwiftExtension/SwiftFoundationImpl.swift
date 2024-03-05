// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - String.localized extension

public extension StringLiteralType {
  var localized: String { NSLocalizedString(description, comment: "") }
}

// MARK: - Root Extensions (classDeduplicated)

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
public extension RangeReplaceableCollection where Element: Hashable {
  /// 使用 NSOrderedSet 處理 class 陣列的「去重複化」。
  var classDeduplicated: Self {
    NSOrderedSet(array: Array(self)).compactMap { $0 as? Element.Type } as? Self ?? self
    // 下述方法有 Bug 會在處理 KeyValuePaired 的時候崩掉，暫時停用。
    // var set = Set<Element>()
    // return filter { set.insert($0).inserted }
  }
}

// MARK: - String Tildes Expansion Extension

public extension String {
  var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}

// MARK: - String Localized Error Extension

extension String: LocalizedError {
  public var errorDescription: String? {
    self
  }
}

// MARK: - CharCode printability check for UniChar (CoreFoundation)

// Ref: https://forums.swift.org/t/57085/5
public extension UniChar {
  var isPrintable: Bool {
    guard Unicode.Scalar(UInt32(self)) != nil else {
      struct NotAWholeScalar: Error {}
      return false
    }
    return true
  }

  var isPrintableASCII: Bool {
    (32 ... 126).contains(self)
  }
}

// MARK: - User Defaults Storage

public extension UserDefaults {
  // 內部標記，看輸入法是否處於測試模式。
  static var pendingUnitTests = false

  static var unitTests = UserDefaults(suiteName: "UnitTests")

  static var current: UserDefaults {
    pendingUnitTests ? .unitTests ?? .standard : .standard
  }
}

// MARK: - Property Wrapper

// Ref: https://www.avanderlee.com/swift/property-wrappers/

@propertyWrapper
public struct AppProperty<Value> {
  public let key: String
  public let defaultValue: Value
  public var container: UserDefaults { .current }
  public init(key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    if container.object(forKey: key) == nil {
      container.set(defaultValue, forKey: key)
    }
  }

  public var wrappedValue: Value {
    get {
      container.object(forKey: key) as? Value ?? defaultValue
    }
    set {
      container.set(newValue, forKey: key)
    }
  }
}

// MARK: - String RegReplace Extension

// Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
public extension String {
  mutating func regReplace(pattern: String, replaceWith: String = "") {
    do {
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }
}

// MARK: - Localized String Extension for Integers and Floats

public extension BinaryFloatingPoint {
  func i18n(loc: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: loc)
    formatter.numberStyle = .spellOut
    return formatter.string(from: NSDecimalNumber(string: "\(self)")) ?? ""
  }
}

public extension BinaryInteger {
  func i18n(loc: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: loc)
    formatter.numberStyle = .spellOut
    return formatter.string(from: NSDecimalNumber(string: "\(self)")) ?? ""
  }
}

// MARK: - Parse String As Hex Literal

// Original author: Shiki Suen
// Refactored by: Isaac Xen

public extension String {
  func parsedAsHexLiteral(encoding: CFStringEncodings? = nil) -> String? {
    guard !isEmpty else { return nil }
    var charBytes = [Int8]()
    var buffer: Int?
    compactMap(\.hexDigitValue).forEach { neta in
      if let validBuffer = buffer {
        charBytes.append(.init(bitPattern: UInt8(validBuffer << 4 + neta)))
        buffer = nil
      } else {
        buffer = neta
      }
    }
    let encodingUBE = CFStringBuiltInEncodings.UTF16BE.rawValue
    let encodingRAW = encoding.map { UInt32($0.rawValue) } ?? encodingUBE
    let result = CFStringCreateWithCString(nil, &charBytes, encodingRAW) as String?
    return result?.isEmpty ?? true ? nil : result
  }
}

// MARK: - Version Comparer.

public extension String {
  /// ref: https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
  func versionCompare(_ otherVersion: String) -> ComparisonResult {
    let versionDelimiter = "."

    var versionComponents = components(separatedBy: versionDelimiter) // <1>
    var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

    let zeroDiff = versionComponents.count - otherVersionComponents.count // <2>

    // <3> Compare normally if the formats are the same.
    guard zeroDiff != 0 else { return compare(otherVersion, options: .numeric) }

    let zeros = Array(repeating: "0", count: abs(zeroDiff)) // <4>
    if zeroDiff > 0 {
      otherVersionComponents.append(contentsOf: zeros) // <5>
    } else {
      versionComponents.append(contentsOf: zeros)
    }
    return versionComponents.joined(separator: versionDelimiter)
      .compare(otherVersionComponents.joined(separator: versionDelimiter), options: .numeric) // <6>
  }
}
