// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - Bool Operators

public func |= (lhs: inout Bool, rhs: Bool) {
  lhs = lhs || rhs
}

public func &= (lhs: inout Bool, rhs: Bool) {
  lhs = lhs && rhs
}

public func ^= (lhs: inout Bool, rhs: Bool) {
  lhs = lhs != rhs
}

// MARK: - String.localized extension

public extension StringLiteralType {
  var localized: String { NSLocalizedString(description, comment: "") }
}

// MARK: - Root Extensions

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
public extension RangeReplaceableCollection where Element: Hashable {
  var deduplicated: Self {
    var set = Set<Element>()
    return filter { set.insert($0).inserted }
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

// MARK: - Ensuring trailing slash of a string

public extension String {
  mutating func ensureTrailingSlash() {
    if !hasSuffix("/") {
      self += "/"
    }
  }
}

// MARK: - CharCode printability check

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

public extension Unicode.Scalar {
  var isPrintableASCII: Bool {
    (32 ... 126).contains(value)
  }
}

// MARK: - Stable Sort Extension

// Ref: https://stackoverflow.com/a/50545761/4162914
public extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  func stableSort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}

// MARK: - Return toggled value.

public extension Bool {
  mutating func toggled() -> Bool {
    toggle()
    return self
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

// MARK: - 引入小數點位數控制函式

// Ref: https://stackoverflow.com/a/32581409/4162914
public extension Double {
  func rounded(toPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return (self * divisor).rounded() / divisor
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

// MARK: - String CharName Extension

public extension String {
  var charDescriptions: [String] {
    flatMap(\.unicodeScalars).compactMap {
      let theName: String = $0.properties.name ?? ""
      return String(format: "U+%02X %@", $0.value, theName)
    }
  }
}

// MARK: - String Ellipsis Extension

public extension String {
  var withEllipsis: String { self + "…" }
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

// MARK: - Index Revolver (only for Array)

// Further discussion: https://forums.swift.org/t/62847

public extension Array {
  func revolvedIndex(_ id: Int, clockwise: Bool = true, steps: Int = 1) -> Int {
    if id < 0 || steps < 1 { return id }
    var result = id
    func revolvedIndexByOneStep(_ id: Int, clockwise: Bool = true) -> Int {
      let newID = clockwise ? id + 1 : id - 1
      if (0 ..< count).contains(newID) { return newID }
      return clockwise ? 0 : count - 1
    }
    for _ in 0 ..< steps {
      result = revolvedIndexByOneStep(result, clockwise: clockwise)
    }
    return result
  }
}

public extension Int {
  mutating func revolveAsIndex(with target: [Any], clockwise: Bool = true, steps: Int = 1) {
    if self < 0 || steps < 1 { return }
    self = target.revolvedIndex(self, clockwise: clockwise, steps: steps)
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

// MARK: - Overlap Checker (for two sets)

public extension Set where Element: Hashable {
  func isOverlapped(with target: Set<Element>) -> Bool {
    guard !target.isEmpty, !isEmpty else { return false }
    var container: (Set<Element>, Set<Element>)
    if target.count <= count {
      container = (target, self)
    } else {
      container = (self, target)
    }
    for neta in container.0 {
      guard !container.1.contains(neta) else { return true }
    }
    return false
  }

  func isOverlapped(with target: [Element]) -> Bool {
    isOverlapped(with: Set(target))
  }
}

public extension Array where Element: Hashable {
  func isOverlapped(with target: [Element]) -> Bool {
    Set(self).isOverlapped(with: Set(target))
  }

  func isOverlapped(with target: Set<Element>) -> Bool {
    Set(self).isOverlapped(with: target)
  }
}
