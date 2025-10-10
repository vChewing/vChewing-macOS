// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

#if canImport(OSLog)
  import OSLog
#endif

extension Process {
  public static func consoleLog<S: StringProtocol>(_ msg: S) {
    let msgStr = msg.description
    if #available(macOS 26.0, *) {
      #if canImport(OSLog)
        let logger = Logger(subsystem: "vChewing", category: "Log")
        logger.log(level: .default, "\(msgStr, privacy: .public)")
        return
      #else
        break
      #endif
    }

    // 兼容旧系统
    NSLog(msgStr)
  }
}

// MARK: - String.localized extension

extension StringLiteralType {
  public var localized: String { NSLocalizedString(description, comment: "") }
}

// MARK: - Root Extensions (classDeduplicated)

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
extension RangeReplaceableCollection where Element: Hashable {
  /// 使用 NSOrderedSet 處理 class 陣列的「去重複化」。
  public var classDeduplicated: Self {
    NSOrderedSet(array: Array(self)).compactMap { $0 as? Element.Type } as? Self ?? self
    // 下述方法有 Bug 會在處理 KeyValuePaired 的時候崩掉，暫時停用。
    // var set = Set<Element>()
    // return filter { set.insert($0).inserted }
  }
}

// MARK: - String Tildes Expansion Extension

extension String {
  public var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}

// MARK: - String + LocalizedError

#if hasFeature(RetroactiveAttribute)
  extension String: @retroactive LocalizedError {}
#else
  extension String: LocalizedError {}
#endif

extension String {
  public var errorDescription: String? {
    self
  }
}

// MARK: - CharCode printability check for UniChar (CoreFoundation)

// Ref: https://forums.swift.org/t/57085/5
extension UniChar {
  public var isPrintable: Bool {
    guard Unicode.Scalar(UInt32(self)) != nil else {
      struct NotAWholeScalar: Error {}
      return false
    }
    return true
  }

  public var isPrintableASCII: Bool {
    (32 ... 126).contains(self)
  }
}

// MARK: - User Defaults Storage

extension UserDefaults {
  // 內部標記，看輸入法是否處於測試模式。
  public static var pendingUnitTests = false

  public static var unitTests = UserDefaults(suiteName: "UnitTests")

  public static var current: UserDefaults {
    pendingUnitTests ? .unitTests ?? .standard : .standard
  }
}

// MARK: - AppProperty

// Ref: https://www.avanderlee.com/swift/property-wrappers/

@propertyWrapper
public final class AppProperty<Value> {
  // MARK: Lifecycle

  public init(key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    if container.object(forKey: key) == nil {
      container.set(defaultValue, forKey: key)
    }
  }

  // MARK: Public

  public let key: String
  public let defaultValue: Value

  public var container: UserDefaults { .current }
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
extension String {
  public mutating func regReplace(pattern: String, replaceWith: String = "") {
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

extension BinaryFloatingPoint {
  public func i18n(loc: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: loc)
    formatter.numberStyle = .spellOut
    return formatter.string(from: NSDecimalNumber(string: "\(self)")) ?? ""
  }
}

extension BinaryInteger {
  public func i18n(loc: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: loc)
    formatter.numberStyle = .spellOut
    return formatter.string(from: NSDecimalNumber(string: "\(self)")) ?? ""
  }
}

// MARK: - Parse String As Hex Literal

// Original author: Shiki Suen
// Refactored by: Isaac Xen

extension String {
  public func parsedAsHexLiteral(encoding: CFStringEncodings? = nil) -> String? {
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

extension String {
  /// ref: https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
  public func versionCompare(_ otherVersion: String) -> ComparisonResult {
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

// MARK: - Async Task

public func asyncOnMain(
  execute work: @escaping @convention(block) () -> ()
) {
  if #available(macOS 10.15, *) {
    Task { @MainActor in
      work()
    }
  } else {
    DispatchQueue.main.async { work() }
  }
}

public func asyncOnMain(
  after delayInterval: TimeInterval,
  execute work: @escaping @convention(block) () -> ()
) {
  let delayInterval = Swift.max(0, delayInterval)
  if #available(macOS 10.15, *) {
    Task { @MainActor in
      if delayInterval > 0 {
        let delay = UInt64(delayInterval * 1_000_000_000)
        try await Task<Never, Never>.sleep(nanoseconds: delay)
      }
      work()
    }
  } else {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delayInterval) {
      work()
    }
  }
}

// MARK: - Total RAM Size.

extension Process {
  public static let totalMemoryGiB: Int = {
    let rawBytes = Double(ProcessInfo.processInfo.physicalMemory)
    return Int((rawBytes / pow(1_024.0, 3)).rounded(.down))
  }()

  public static let isAppleSilicon: Bool = {
    var systeminfo = utsname()
    uname(&systeminfo)
    let machine = withUnsafeBytes(of: &systeminfo.machine) { bufPtr -> String in
      let data = Data(bufPtr)
      if let lastIndex = data.lastIndex(where: { $0 != 0 }) {
        return String(data: data[0 ... lastIndex], encoding: .isoLatin1) ?? "x86_64"
      } else {
        return String(data: data, encoding: .isoLatin1) ?? "x86_64"
      }
    }
    return machine == "arm64"
  }()
}
