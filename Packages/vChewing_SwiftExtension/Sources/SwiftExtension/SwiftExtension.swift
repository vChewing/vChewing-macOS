// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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

// MARK: - Root Extensions (deduplicated)

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
extension RangeReplaceableCollection where Element: Hashable {
  /// 去重複化。
  /// - Remark: 該方法不適合用來處理 class，除非該 class 遵循 Identifiable 協定。
  public var deduplicated: Self {
    var set = Set<Element>()
    return filter { set.insert($0).inserted }
  }
}

// MARK: - UILayoutOrientation

public enum UILayoutOrientation: Int, Codable, Hashable, Sendable {
  case horizontal = 0
  case vertical = 1
}

// MARK: - Ensuring trailing slash of a string

extension String {
  public mutating func ensureTrailingSlash() {
    if !hasSuffix("/") {
      self += "/"
    }
  }
}

// MARK: - CharCode printability check

extension Unicode.Scalar {
  public var isPrintableASCII: Bool {
    (32 ... 126).contains(value)
  }
}

// MARK: - Stable Sort Extension

// Ref: https://stackoverflow.com/a/50545761/4162914
extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  public func stableSort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element] {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}

// MARK: - Return toggled value.

extension Bool {
  public mutating func toggled() -> Bool {
    toggle()
    return self
  }

  public static func from(integer: Int) -> Bool {
    integer > 0 ? true : false
  }
}

// MARK: - 引入小數點位數控制函式

// Ref: https://stackoverflow.com/a/32581409/4162914
extension Double {
  public func rounded(toPlaces places: Int) -> Double {
    let divisor = 10.0.mathPowered(by: places)
    return (self * divisor).rounded() / divisor
  }
}

extension Double {
  public func mathPowered(by operand: Int) -> Double {
    var target = self
    for _ in 0 ..< operand {
      target = target * target
    }
    return target
  }
}

// MARK: - String CharName and CodePoint Extension

extension String {
  public var charDescriptions: [String] {
    flatMap(\.unicodeScalars).compactMap {
      let theName: String = $0.properties.name ?? ""
      return String(format: "U+%02X %@", $0.value, theName)
    }
  }

  public var codePoints: [String] {
    map(\.codePoint)
  }

  public var describedAsCodePoints: [String] {
    map {
      "\($0) (\($0.codePoint))"
    }
  }
}

// MARK: - Character Codepoint

extension Character {
  public var codePoint: String {
    guard let value = unicodeScalars.first?.value else { return "U+NULL" }
    return String(format: "U+%02X", value)
  }
}

// MARK: - String Ellipsis Extension

extension String {
  public var withEllipsis: String { self + "…" }
}

// MARK: - Index Revolver (only for Array)

// Further discussion: https://forums.swift.org/t/62847

extension Array {
  public func revolvedIndex(_ id: Int, clockwise: Bool = true, steps: Int = 1) -> Int {
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

extension Int {
  public mutating func revolveAsIndex(with target: [Any], clockwise: Bool = true, steps: Int = 1) {
    if self < 0 || steps < 1 { return }
    self = target.revolvedIndex(self, clockwise: clockwise, steps: steps)
  }
}

// MARK: - Overlap Checker (for two sets)

extension Set where Element: Hashable {
  public func isOverlapped(with target: Set<Element>) -> Bool {
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

  public func isOverlapped(with target: [Element]) -> Bool {
    isOverlapped(with: Set(target))
  }
}

extension Array where Element: Hashable {
  public func isOverlapped(with target: [Element]) -> Bool {
    Set(self).isOverlapped(with: Set(target))
  }

  public func isOverlapped(with target: Set<Element>) -> Bool {
    Set(self).isOverlapped(with: target)
  }
}

// MARK: - ArrayBuilder

@resultBuilder
public enum ArrayBuilder<OutputModel> {
  public static func buildEither(first component: [OutputModel]) -> [OutputModel] {
    component
  }

  public static func buildEither(second component: [OutputModel]) -> [OutputModel] {
    component
  }

  public static func buildOptional(_ component: [OutputModel]?) -> [OutputModel] {
    component ?? []
  }

  public static func buildExpression(_ expression: OutputModel) -> [OutputModel] {
    [expression]
  }

  public static func buildExpression(_: ()) -> [OutputModel] {
    []
  }

  public static func buildBlock(_ components: [OutputModel]...) -> [OutputModel] {
    components.flatMap { $0 }
  }

  public static func buildArray(_ components: [[OutputModel]]) -> [OutputModel] {
    Array(components.joined())
  }
}

// MARK: - Extending Comparable to let it able to find its neighbor values in any collection.

extension Comparable {
  public func findNeighborValue(
    from givenSeq: any Collection<Self>,
    greater isGreater: Bool
  )
    -> Self? {
    let givenArray: [Self] = isGreater ? Array(givenSeq.sorted()) :
      Array(givenSeq.sorted().reversed())
    let givenMap: [Int: Self] = .init(uniqueKeysWithValues: Array(givenArray.enumerated()))
    var (startID, endID, returnableID) = (0, givenArray.count - 1, -1)
    func internalCompare(_ lhs: Self, _ rhs: Self) -> Bool { isGreater ? lhs <= rhs : lhs >= rhs }
    while let startObj = givenMap[startID], let endObj = givenMap[endID], internalCompare(
      startObj,
      endObj
    ) {
      let midID = (startID + endID) / 2
      if let midObj = givenMap[midID], internalCompare(midObj, self) {
        startID = midID + 1
      } else {
        returnableID = midID
        endID = midID - 1
      }
    }
    return givenMap[returnableID]
  }
}

// MARK: - String.applyingTransform

extension String {
  /// This only works with ASCII chars for now.
  public func applyingTransformFW2HW(reverse: Bool) -> String {
    var arr: [Character] = map { $0 }
    for i in 0 ..< arr.count {
      let oldChar = arr[i]
      guard oldChar.unicodeScalars.count == 1 else { continue }
      guard let oldCodePoint = oldChar.unicodeScalars.first?.value else { continue }
      if reverse {
        guard oldChar.isASCII else { continue }
      } else {
        guard oldCodePoint > 0xFEE0 || oldCodePoint == 0x3000 else { continue }
      }
      var newCodePoint: Int32 = reverse ? (Int32(oldCodePoint) + 0xFEE0) :
        (Int32(oldCodePoint) - 0xFEE0)
      checkSpace: switch (oldCodePoint, reverse) {
      case (0x3000, false): newCodePoint = 0x20
      case (0x20, true): newCodePoint = 0x3000
      default: break checkSpace
      }
      guard newCodePoint > 0 else { continue }
      guard let newScalar = Unicode.Scalar(UInt16(newCodePoint)) else { continue }
      let newChar = Character(newScalar)
      arr[i] = newChar
    }
    return String(arr)
  }
}
