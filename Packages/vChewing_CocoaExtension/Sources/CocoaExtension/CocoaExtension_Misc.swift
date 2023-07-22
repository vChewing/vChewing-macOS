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

public extension Bundle {
  func getCodeSignedDate() -> Date? {
    var code: SecStaticCode?
    var information: CFDictionary?
    let status4Code = SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(rawValue: 0), &code)
    guard status4Code == 0, let code = code else {
      NSLog("Error from getCodeSignedDate(): Failed from retrieving status4Code.")
      return nil
    }
    let status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
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

// MARK: - NSSize extension

public extension NSSize {
  static var infinity: NSSize { .init(width: Double.infinity, height: Double.infinity) }
}

// MARK: - NSAttributedString extension

// Ref: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

public extension NSAttributedString {
  @objc var boundingDimension: NSSize {
    let rectA = boundingRect(
      with: NSSize(width: Double.infinity, height: Double.infinity),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let textStorage = NSTextStorage(attributedString: self)
    let textContainer = NSTextContainer()
    let layoutManager = NSLayoutManager()
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    textContainer.lineFragmentPadding = 0.0
    layoutManager.glyphRange(for: textContainer)
    let rectB = layoutManager.usedRect(for: textContainer)
    let width = ceil(max(rectA.width, rectB.width))
    let height = ceil(max(rectA.height, rectB.height))
    return .init(width: width, height: height)
  }
}

// MARK: - NSString extension

public extension NSString {
  var localized: String { NSLocalizedString(description, comment: "") }
}

// MARK: - NSRange Extension

public extension NSRange {
  static var zero = NSRange(location: 0, length: 0)
  static var notFound = NSRange(location: NSNotFound, length: NSNotFound)
}

// MARK: - NSRect Extension

public extension NSRect {
  static var seniorTheBeast: NSRect {
    NSRect(x: 0.0, y: 0.0, width: 0.114, height: 0.514)
  }
}

// MARK: - Shell Extension

public extension NSApplication {
  static func shell(_ command: String) throws -> String {
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

public extension NSApplication {
  // MARK: - System Dark Mode Status Detector.

  static var isDarkMode: Bool {
    if #unavailable(macOS 10.14) { return false }
    if #available(macOS 10.15, *) {
      let appearanceDescription = NSApp.effectiveAppearance.debugDescription
        .lowercased()
      return appearanceDescription.contains("dark")
    } else if let appleInterfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
      return appleInterfaceStyle.lowercased().contains("dark")
    }
    return false
  }

  // MARK: - Tell whether this IME is running with Root privileges.

  static var isSudoMode: Bool {
    NSUserName() == "root"
  }
}

// MARK: - Real Home Dir for Sandboxed Apps

public extension FileManager {
  static let realHomeDir = URL(
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
  )
}

// MARK: - Trash a file if it exists.

public extension FileManager {
  @discardableResult static func trashTargetIfExists(_ path: String) -> Bool {
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
public extension NSApplication {
  /// The memory footprint of the current application in bytes.
  static var memoryFootprint: UInt64? {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let tskVMInfoCount = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let tskVMInfoRev1Count = mach_msg_type_number_t(
      MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
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

// MARK: - String.applyingTransform

public extension String {
  func applyingTransformFW2HW(reverse: Bool) -> String {
    if #available(macOS 10.11, *) {
      return applyingTransform(.fullwidthToHalfwidth, reverse: reverse) ?? self
    }
    let theString = NSMutableString(string: self)
    CFStringTransform(theString, nil, kCFStringTransformFullwidthHalfwidth, reverse)
    return theString as String
  }
}

// MARK: - Check whether current date is the given date.

public extension Date {
  /// Check whether current date is the given date.
  /// - Parameter dateDigits: `yyyyMMdd`, 8-digit integer. If only `MMdd`, then the year will be the current year.
  /// - Returns: The result. Will return false if the given dateDigits is invalid.
  static func isTodayTheDate(from dateDigits: Int) -> Bool {
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
    if let a = calendar.date(from: components), let b = formatter.date(from: dateDigits.description), a == b {
      return true
    }
    return false
  }

  static var currentYear: Int {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return (Int(formatter.string(from: Date())) ?? 1970)
  }
}

// MARK: - Apple Silicon Detector

// Ref: https://developer.apple.com/forums/thread/678914

public extension NSApplication {
  static var isAppleSilicon: Bool {
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

public extension NSApplication {
  func popup() {
    #if compiler(>=5.9) && canImport(AppKit, _version: "14.0")
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
