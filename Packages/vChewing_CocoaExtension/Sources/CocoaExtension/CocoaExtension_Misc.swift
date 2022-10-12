// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: NSRect Extension

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
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
  }
}

extension NSApplication {
  // MARK: - System Dark Mode Status Detector.

  public static var isDarkMode: Bool {
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

  public static var isSudoMode: Bool {
    NSUserName() == "root"
  }
}

// MARK: - Real Home Dir for Sandboxed Apps

extension FileManager {
  public static let realHomeDir = URL(
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
  )
}

// MARK: - Trash a file if it exists.

extension FileManager {
  @discardableResult public static func trashTargetIfExists(_ path: String) -> Bool {
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
