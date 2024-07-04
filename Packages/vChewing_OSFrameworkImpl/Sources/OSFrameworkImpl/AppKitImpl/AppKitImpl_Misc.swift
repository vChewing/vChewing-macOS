// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftExtension

// MARK: - Get Bundle Signature Timestamp

extension Bundle {
  public func getCodeSignedDate() -> Date? {
    var code: SecStaticCode?
    var information: CFDictionary?
    let status4Code = SecStaticCodeCreateWithPath(
      bundleURL as CFURL,
      SecCSFlags(rawValue: 0),
      &code
    )
    guard status4Code == 0, let code = code else {
      NSLog("Error from getCodeSignedDate(): Failed from retrieving status4Code.")
      return nil
    }
    let status = SecCodeCopySigningInformation(
      code,
      SecCSFlags(rawValue: kSecCSSigningInformation),
      &information
    )
    guard status == noErr else {
      NSLog("Error from getCodeSignedDate(): Failed from retrieving code signing intelligence.")
      return nil
    }
    guard let dictionary = information as? [String: NSObject] else { return nil }
    guard dictionary[kSecCodeInfoIdentifier as String] != nil else {
      NSLog("Error from getCodeSignedDate(): Target not signed.")
      return nil
    }
    guard let infoDate = dictionary[kSecCodeInfoTimestamp as String] as? Date else {
      NSLog("Error from getCodeSignedDate(): Target signing timestamp is missing.")
      return nil
    }
    return infoDate as Date
  }
}

// MARK: - Detect whether a bundle is Electron-based.

extension Bundle {
  public var isElectronBasedApp: Bool {
    // Check the info.plist.
    guard let dict = infoDictionary else { return false }
    if dict.keys.contains(where: { $0.lowercased().contains("electron") }) { return true }
    let selectedValues: [String] = dict.values.compactMap {
      ($0 as? CustomStringConvertible)?.description.lowercased()
    }
    if selectedValues.contains(where: { $0.contains("electron") }) { return true }
    // Check the existence of the Electron framework bundle.
    guard let urlFrameworks = privateFrameworksURL else { return false }
    guard let paths = try? FileManager.default.contentsOfDirectory(
      at: urlFrameworks, includingPropertiesForKeys: nil, options: []
    ) else { return false }
    for path in paths {
      let pathLC = path.absoluteString.lowercased()
      if pathLC.contains("electron") { return true }
      if pathLC.contains("mswebview") { return true }
      if pathLC.contains("slimcorewebview") { return true }
    }
    return false
  }
}

// MARK: - Detect whether a running application is Electron-based.

extension NSRunningApplication {
  public static func isElectronBasedApp(identifier: String) -> Bool {
    let ids = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    guard !ids.isEmpty else { return false }
    for id in ids {
      guard let bURL = id.bundleURL, let bundle = Bundle(url: bURL) else { continue }
      if bundle.isElectronBasedApp { return true }
    }
    return false
  }
}

// MARK: - NSSize extension

extension NSSize {
  public static var infinity: NSSize { .init(width: Double.infinity, height: Double.infinity) }
}

// MARK: - NSAttributedString extension

// Ref: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

extension NSAttributedString {
  private static let tmpTextStorage = NSTextStorage()
  private static let tmpLayoutManager = NSLayoutManager()
  private static let tmpTextContainer = NSTextContainer()

  @objc
  public var boundingDimension: NSSize {
    Self.tmpTextStorage.setAttributedString(self)
    if Self.tmpLayoutManager.textContainers.isEmpty || Self.tmpLayoutManager.textContainers
      .first !== Self.tmpTextContainer {
      Self.tmpLayoutManager.addTextContainer(Self.tmpTextContainer)
    }
    if Self.tmpTextStorage.layoutManagers.isEmpty || Self.tmpTextStorage.layoutManagers
      .first !== Self.tmpLayoutManager {
      Self.tmpTextStorage.addLayoutManager(Self.tmpLayoutManager)
    }
    Self.tmpTextContainer.lineFragmentPadding = 0
    Self.tmpLayoutManager.glyphRange(for: Self.tmpTextContainer)
    return Self.tmpLayoutManager.usedRect(for: Self.tmpTextContainer).size
  }
}

// MARK: - NSString extension

extension NSString {
  public var localized: String { NSLocalizedString(description, comment: "") }

  @objc
  public func getCharDescriptions(_: Any? = nil) -> [String] {
    (self as String).charDescriptions
  }

  @objc
  public func getCodePoints(_: Any? = nil) -> [String] {
    (self as String).codePoints
  }

  @objc
  public func getDescriptionAsCodePoints(_: Any? = nil) -> [String] {
    (self as String).describedAsCodePoints
  }
}

// MARK: - NSRange Extension

extension NSRange {
  public static var zero = NSRange(location: 0, length: 0)
  public static var notFound = NSRange(location: NSNotFound, length: NSNotFound)
}

// MARK: - NSRect Extension

extension NSRect {
  public static var seniorTheBeast: NSRect {
    NSRect(x: 0.0, y: 0.0, width: 0.114, height: 0.514)
  }
}

// MARK: - Shell Extension

extension NSApplication {
  public static func shell(_ command: String) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    if #available(macOS 10.13, *) {
      task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    } else {
      task.launchPath = "/bin/zsh"
    }
    task.standardInput = nil

    if #available(macOS 10.13, *) {
      try task.run()
    } else {
      task.launch()
    }

    var output = ""
    do {
      let data = try pipe.fileHandleForReading.readToEnd()
      if let data = data, let str = String(data: data, encoding: .utf8) {
        output.append(str)
      }
    } catch {
      return ""
    }
    return output
  }
}

extension NSApplication {
  // MARK: - System Dark Mode Status Detector.

  public static var isDarkMode: Bool {
    // "NSApp" can be nil during SPM unit tests.
    // Therefore, the method dedicated for macOS 10.15 and later is not considered stable anymore.
    // Fortunately, the method for macOS 10.14 works well on later macOS releases.
    if #available(macOS 10.14, *),
       let strAIS = UserDefaults.current.string(forKey: "AppleInterfaceStyle") {
      return strAIS.lowercased().contains("dark")
    } else {
      return false
    }
  }

  // MARK: - Tell whether this IME is running with Root privileges.

  public static var isSudoMode: Bool {
    NSUserName() == "root"
  }
}

// MARK: - Real Home Dir for Sandboxed Apps

extension FileManager {
  public static let realHomeDir = URL(
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true,
    relativeTo: nil
  )
}

// MARK: - Trash a file if it exists.

extension FileManager {
  @discardableResult
  public static func trashTargetIfExists(_ path: String) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: path) {
        // 塞入垃圾桶
        try FileManager.default.trashItem(
          at: URL(fileURLWithPath: path), resultingItemURL: nil
        )
      } else {
        NSLog("Item doesn't exist: \(path)")
      }
    } catch let error as NSError {
      NSLog("Failed from removing this object: \(path) || Error: \(error)")
      return false
    }
    return true
  }
}

// MARK: - Memory Footprint Calculator

// Ref: https://developer.apple.com/forums/thread/105088?answerId=357415022#357415022
extension NSApplication {
  /// The memory footprint of the current application in bytes.
  public static var memoryFootprint: UInt64? {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let tskVMInfoCount = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let tskVMInfoRev1Count = mach_msg_type_number_t(
      MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size
    )
    var info = task_vm_info_data_t()
    var count = tskVMInfoCount
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
      infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
      }
    }
    guard kr == KERN_SUCCESS, count >= tskVMInfoRev1Count else { return nil }
    return info.phys_footprint as UInt64
  }
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
    case 3, 4: dateDigits = currentYear * 10000 + dateDigits
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
    return Int(formatter.string(from: Date())) ?? 1970
  }
}

// MARK: - Apple Silicon Detector

// Ref: https://developer.apple.com/forums/thread/678914

extension NSApplication {
  public static var isAppleSilicon: Bool {
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
  }
}

// MARK: - NSApp Activation Helper

// This is to deal with changes brought by macOS 14.

extension NSApplication {
  public func popup() {
    #if compiler(>=5.9) && canImport(AppKit, _version: 14.0)
      if #available(macOS 14.0, *) {
        NSApp.activate()
      } else {
        NSApp.activate(ignoringOtherApps: true)
      }
    #else
      NSApp.activate(ignoringOtherApps: true)
    #endif
  }
}

// MARK: - Reading bundle's accent color.

extension NSColor {
  public static var accentColor: NSColor {
    guard #unavailable(macOS 10.14) else { return .controlAccentColor }
    return .alternateSelectedControlColor
  }
}

extension Bundle {
  public func getAccentColor() -> NSColor {
    let defaultResult: NSColor = .accentColor
    let queryPhrase = localizedInfoDictionary?["NSAccentColorName"] as? String ??
      infoDictionary?["NSAccentColorName"] as? String
    guard let queryPhrase = queryPhrase, !queryPhrase.isEmpty else { return defaultResult }
    guard #available(macOS 10.13, *) else { return defaultResult }
    return NSColor(named: queryPhrase, bundle: self) ?? defaultResult
  }
}

extension NSRunningApplication {
  private static var temporatyBundlePtr: Bundle?

  public static func findAccentColor(with bundleIdentifier: String) -> NSColor {
    let matchedRunningApps = Self.runningApplications(withBundleIdentifier: bundleIdentifier)
    guard let matchedAppURL = matchedRunningApps.first?.bundleURL else { return .accentColor }
    Self.temporatyBundlePtr = Bundle(url: matchedAppURL)
    defer { temporatyBundlePtr = nil }
    let bundleColor = Self.temporatyBundlePtr?.getAccentColor().usingColorSpace(.deviceRGB)
    guard let bundleColor = bundleColor else { return .accentColor }
    let h = bundleColor.hueComponent
    let s = bundleColor.saturationComponent
    return .init(hue: h, saturation: s, brightness: 128, alpha: 1)
  }
}

// MARK: - Check whether system's accent color is fixed with non-default value.

extension NSApplication {
  public var isAccentColorCustomized: Bool {
    UserDefaults.standard.object(forKey: "AppleAccentColor") != nil
  }
}

// MARK: - Pasteboard Type Extension.

extension NSPasteboard.PasteboardType {
  public static let kUTTypeFileURL =
    Self(rawValue: "public.file-url") // import UniformTypeIdentifiers
  public static let kUTTypeData = Self(rawValue: "public.data") // import UniformTypeIdentifiers
  public static let kUTTypeAppBundle =
    Self(rawValue: "com.apple.application-bundle") // import UniformTypeIdentifiers
  public static let kUTTypeUTF8PlainText = Self(rawValue: "public.utf8-plain-text")
  public static let kNSFilenamesPboardType = Self(rawValue: "NSFilenamesPboardType")
}
