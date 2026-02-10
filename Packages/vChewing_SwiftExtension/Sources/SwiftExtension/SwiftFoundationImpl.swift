// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

#if canImport(Musl)
  @_exported import Musl
#elseif canImport(Glibc)
  @_exported import Glibc
#elseif canImport(Darwin)
  @_exported import Darwin
#elseif canImport(ucrt)
  @_exported import ucrt
#endif

#if canImport(OSLog)
  import OSLog
#endif

extension Process {
  public static func consoleLog<S: StringProtocol>(_ msg: S) {
    let msgStr = msg.description
    #if canImport(Darwin)
      if #available(macOS 26.0, *) {
        #if canImport(OSLog)
          let logger = Logger(subsystem: "vChewing", category: "Log")
          logger.log(level: .default, "\(msgStr, privacy: .public)")
          return
        #endif
      }

      // 兼容旧系统
      NSLog(msgStr)
    #else
      print(msgStr)
    #endif
  }
}

// MARK: - File Handle API Compatibility for macOS 10.15.3 and Earlier.

extension FileHandle {
  public func readData(upToCount count: Int) throws -> Data? {
    #if canImport(Darwin)
      if #available(macOS 10.15.4, *) {
        try read(upToCount: count)
      } else {
        readData(ofLength: count)
      }
    #else
      try read(upToCount: count)
    #endif
  }

  public func readDataToEnd() throws -> Data? {
    #if canImport(Darwin)
      if #available(macOS 10.15.4, *) {
        try readToEnd()
      } else {
        readDataToEndOfFile()
      }
    #else
      try readToEnd()
    #endif
  }
}

// MARK: - Real Home Dir for Sandboxed Apps

extension FileManager {
  public static let realHomeDir: URL = {
    // Avoid relativeTo: parameter (10.11+) to stay compatible with 10.9.
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
      let url = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
      return url.standardizedFileURL
    #else
      // Windows (or other non-POSIX platforms): try environment vars then fall back to Foundation API
      if let userProfile = ProcessInfo.processInfo.environment["USERPROFILE"] {
        return URL(fileURLWithPath: userProfile).standardizedFileURL
      } else if let home = ProcessInfo.processInfo.environment["HOME"] {
        return URL(fileURLWithPath: home).standardizedFileURL
      } else {
        // This one has potential bugs plagued in the implementation of Foundation on Windows.
        return FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
      }
    #endif
  }()
}

// MARK: - Check whether current date is the given date.

extension Date {
  /// Check whether current date is the given date.
  /// - Parameter dateDigits: `yyyyMMdd`, 8-digit integer. If only `MMdd`, then the year will be the current year.
  /// - Returns: The result. Will return false if the given dateDigits is invalid.
  public static func isTodayTheDate(from dateDigits: Int) -> Bool {
    let currentYear = Self.currentYear
    var dateDigits = dateDigits
    let strDateDigits = dateDigits.description
    switch strDateDigits.count {
    case 3, 4: dateDigits = currentYear * 10_000 + dateDigits
    case 8:
      if let theHighest = strDateDigits.first, "12".contains(theHighest) { break }
      return false
    default: return false
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    var calendar = NSCalendar.current
    calendar.timeZone = TimeZone.current
    let components = calendar.dateComponents([.day, .month, .year], from: Date())
    if let a = calendar.date(from: components), let b = formatter.date(
      from: dateDigits.description
    ),
      a == b {
      return true
    }
    return false
  }

  public static var currentYear: Int {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return Int(formatter.string(from: Date())) ?? 1_970
  }
}

// MARK: - NSRange Extension

extension NSRange {
  public static let zero = NSRange(location: 0, length: 0)
  public static let notFound = NSRange(location: NSNotFound, length: NSNotFound)
}

// MARK: - CGRect Extension

extension CGRect {
  public static let seniorTheBeast: CGRect = {
    var result = CGRect()
    result.origin = .init(x: 0, y: 0)
    result.size = .init(width: 0.114, height: 0.514)
    return result
  }()

  public static let zeroValue = CGRect(
    origin: .init(x: 0, y: 0),
    size: .init(width: 0, height: 0)
  )
}

// MARK: - String.i18n extension

extension StringLiteralType {
  public var i18n: String { NSLocalizedString(description, comment: "") }
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
  nonisolated public var errorDescription: String? {
    self
  }
}

// MARK: - CharCode printability check for UniChar (CoreFoundation)

extension UInt16 {
  public var isPrintableUniChar: Bool {
    Unicode.Scalar(UInt32(self)) != nil
  }

  public var isPrintableASCII: Bool {
    (32 ... 126).contains(self)
  }
}

// MARK: - User Defaults Storage

extension UserDefaults {
  public static var pendingUnitTests: Bool {
    get { _pendingUnitTests.value }
    set { _pendingUnitTests.value = newValue }
  }

  public static var unitTests: UserDefaults? {
    get { _unitTests.value }
    set { _unitTests.value = newValue }
  }

  public static var current: UserDefaults {
    pendingUnitTests ? (unitTests ?? .standard) : .standard
  }

  // MARK: - Private

  nonisolated private static let _pendingUnitTests = NSMutex(false)
  nonisolated private static let _unitTests: NSMutex<UserDefaults?> = .init(
    UserDefaults(suiteName: "UnitTests")
  )
}

// MARK: - AppProperty

// Ref: https://www.avanderlee.com/swift/property-wrappers/

@propertyWrapper
public struct AppProperty<Value: Sendable>: Sendable {
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
    nonmutating set {
      container.set(newValue, forKey: key)
    }
  }
}

// MARK: - String RegReplace Extension

// Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
extension String {
  nonisolated public mutating func regReplace(pattern: String, replaceWith: String = "") {
    do {
      let regex = try Self.cachedRegex(for: pattern)
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }

  nonisolated private static func cachedRegex(for pattern: String) throws -> NSRegularExpression {
    try regexCache.withLock { cache in
      if let cached = cache[pattern] as? NSRegularExpression {
        return cached
      }
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      cache[pattern] = regex
      return regex
    }
  }

  // MARK: Private

  // MARK: - 快取已編譯的 NSRegularExpression

  /// 以 pattern 為 key 快取已編譯的正規表示式，避免每次呼叫重新編譯。
  nonisolated private static let regexCache: NSMutex<NSMutableDictionary> = .init(.init())
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
  bypassAsync: Bool = false,
  execute work: @MainActor @escaping @Sendable @convention(block) () -> ()
) {
  guard !bypassAsync else {
    work()
    return
  }
  if #available(macOS 12, *) {
    Task { @MainActor in
      work()
    }
  } else {
    DispatchQueue.main.async { work() }
  }
}

public func asyncOnMain(
  after delayInterval: TimeInterval,
  bypassAsync: Bool = false,
  execute work: @MainActor @escaping @Sendable @convention(block) () -> ()
) {
  guard !bypassAsync else {
    work()
    return
  }
  let delayInterval = Swift.max(0, delayInterval)
  if #available(macOS 12, *) {
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

@discardableResult
public func mainSync<T>(execute work: @MainActor () throws -> T) rethrows -> T {
  if Thread.isMainThread {
    return try work()
  }
  return try DispatchQueue.main.sync(execute: work)
}

// MARK: - Total RAM Size.

extension Process {
  public static let totalMemoryGiB: Int = {
    let rawBytes = Double(ProcessInfo.processInfo.physicalMemory)
    return Int((rawBytes / pow(1_024.0, 3)).rounded(.down))
  }()

  public static let isAppleSilicon: Bool = {
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
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
    #else
      // On platforms without uname/utsname (e.g., Windows), assume not Apple Silicon
      return false
    #endif
  }()
}

// MARK: - Debouncer

nonisolated public final class Debouncer {
  // MARK: Lifecycle

  public init(delay: TimeInterval, queue: DispatchQueue) {
    self.delay = delay
    self.queue = queue
  }

  deinit {
    invalidate()
  }

  // MARK: Public

  public func schedule(_ block: @escaping () -> ()) {
    lock.withLock {
      let previousTimer = timer
      let newTimer = DispatchSource.makeTimerSource(queue: queue)
      newTimer.schedule(deadline: .now() + delay)
      let timerID = UUID()
      activeTimerID = timerID
      newTimer.setEventHandler { [weak self] in
        block()
        self?.completeActiveTimer(id: timerID)
      }
      timer = newTimer
      previousTimer?.cancel()
      newTimer.resume()
    }
  }

  public func invalidate() {
    lock.withLock {
      timer?.cancel()
      timer = nil
      activeTimerID = nil
    }
  }

  // MARK: Private

  private let delay: TimeInterval
  private let queue: DispatchQueue
  private var timer: DispatchSourceTimer?
  private var activeTimerID: UUID?
  private let lock = NSLock()

  private func completeActiveTimer(id: UUID) {
    lock.withLock {
      if activeTimerID == id {
        timer = nil
        activeTimerID = nil
      }
    }
  }
}

// MARK: - NSMutex

/// A simple NSMutex implementation using NSLock for macOS 10.9+ compatibility.
/// Provides thread-safe access to a wrapped value.
nonisolated public final class NSMutex<Value>: Sendable {
  // MARK: Lifecycle

  public init(_ value: Value) {
    self.storedValue = value
  }

  // MARK: Public

  public var value: Value {
    get {
      withLock { $0 }
    }
    set {
      withLock { $0 = newValue }
    }
  }

  /// Access the value with exclusive access (read and write).
  public func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    try lock.withLock { try body(&storedValue) }
  }

  /// Read the value with exclusive access (read-only).
  public func withLockRead<Result>(_ body: (Value) throws -> Result) rethrows -> Result {
    try lock.withLock { try body(storedValue) }
  }

  // MARK: Private

  nonisolated(unsafe) private var storedValue: Value
  private let lock = NSLock()
}

// MARK: - CRC32

nonisolated public enum CRC32 {
  // MARK: Public

  public static func checksum(data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFFFFFF
    data.forEach { byte in
      let index = Int((crc ^ UInt32(byte)) & 0xFF)
      crc = (crc >> 8) ^ table[index]
    }
    return crc ^ 0xFFFFFFFF
  }

  // MARK: Private

  private static let table: [UInt32] = {
    var table = [UInt32](repeating: 0, count: 256)
    let polynomial: UInt32 = 0xEDB88320

    for i in 0 ..< 256 {
      var crc = UInt32(i)
      for _ in 0 ..< 8 {
        if crc & 1 == 1 {
          crc = (crc >> 1) ^ polynomial
        } else {
          crc >>= 1
        }
      }
      table[i] = crc
    }
    return table
  }()
}

// MARK: - HSBA

/// 一個簡單的顏色結構體，用於跨平台（包括 Linux）承載 HSBA 顏色值。
/// 每個分量均為 Double 類型，範圍 0.0 ~ 1.0。
nonisolated public struct HSBA: Sendable {
  // MARK: Lifecycle

  /// 初始化 HSBA 顏色。
  public init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1.0) {
    self.hue = max(0.0, min(1.0, hue))
    self.saturation = max(0.0, min(1.0, saturation))
    self.brightness = max(0.0, min(1.0, brightness))
    self.alpha = max(0.0, min(1.0, alpha))
  }

  // MARK: Public

  public var hue: Double
  public var saturation: Double
  public var brightness: Double
  public var alpha: Double
}
