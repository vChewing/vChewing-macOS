// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared

@main
struct VCSharedCLI {
  static func main() {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
      printUsage()
      return
    }

    let subcommand = args[1]
    let subargs = Array(args.dropFirst(2))

    switch subcommand {
    case "convert-strings":
      convertStrings(paths: subargs)
    case "convert-userdef-source":
      convertUserDefSource(paths: subargs)
    case "generate-missing-strings":
      generateMissingStrings(paths: subargs)
    case "list-pending-userdef":
      listPendingUserDef()
    case "convert-bare-keys":
      convertBareKeys(paths: subargs)
    case "convert-bare-keys-in-source":
      convertBareKeysInSource(paths: subargs)
    default:
      print("Unknown subcommand: \(subcommand)")
      printUsage()
    }
  }

  // MARK: - Usage

  static func printUsage() {
    print("vChewingSharedCLI — i18n Key Migration Helper")
    print("Usage:")
    print("  swift run vChewingSharedCLI convert-strings <paths-to-.strings-files>")
    print("  swift run vChewingSharedCLI convert-userdef-source <path-to-UserDef.swift>")
    print("  swift run vChewingSharedCLI generate-missing-strings <paths-to-.strings-files>")
    print("  swift run vChewingSharedCLI list-pending-userdef")
    print("  swift run vChewingSharedCLI convert-bare-keys <paths-to-.strings-files>")
    print("  swift run vChewingSharedCLI convert-bare-keys-in-source <paths-to-.swift-files>")
  }

  // MARK: - Escape helpers

  /// Converts a Mirror-reflected actual string value back into the escaped form
  /// that appears in `.strings` files and Swift source code string literals.
  ///
  /// Both formats share the same escaping rules for `\\`, `\"`, `\n`, `\t`, `\r`.
  static func escapeForLiteralSearch(_ string: String) -> String {
    var result = ""
    for char in string {
      switch char {
      case "\\": result += "\\\\"
      case "\"": result += "\\\""
      case "\n": result += "\\n"
      case "\t": result += "\\t"
      case "\r": result += "\\r"
      default: result.append(char)
      }
    }
    return result
  }

  // MARK: - VarArg Type A: convert-strings

  static func convertStrings(paths: [String]) {
    let map = UserDef.i18nKeyConvMapTotal
    guard !map.isEmpty else {
      print("No i18n key mappings found. Nothing to convert.")
      return
    }

    // Sort by oldValue length descending to avoid partial-substring collisions.
    let sortedEntries = map.sorted { $0.value.count > $1.value.count }

    let fileManager = FileManager.default

    for rawPath in paths {
      let path = (rawPath as NSString).standardizingPath
      guard fileManager.fileExists(atPath: path) else {
        print("!! File not found: \(path)")
        continue
      }

      guard let originalContent = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("!! Failed to read: \(path)")
        continue
      }

      var convertedContent = originalContent
      var replacementCount = 0

      for (newKey, oldValue) in sortedEntries {
        let escapedOldValue = escapeForLiteralSearch(oldValue)
        let oldPattern = "\"\(escapedOldValue)\" = "
        guard convertedContent.contains(oldPattern) else { continue }
        let newPattern = "\"\(newKey)\" = "
        convertedContent = convertedContent.replacingOccurrences(of: oldPattern, with: newPattern)
        replacementCount += 1
      }

      guard convertedContent != originalContent else {
        print("-- No changes needed: \(path)")
        continue
      }

      do {
        try convertedContent.write(toFile: path, atomically: true, encoding: .utf8)
        print("OK Converted \(replacementCount) key(s) in \(path)")
      } catch {
        print("!! Failed to write: \(path) — \(error.localizedDescription)")
      }
    }
  }

  // MARK: - VarArg Type C: convert-userdef-source

  /// Replaces bare-English string literals in `UserDef.swift` source with `i18n:` keys.
  /// Unlike `convert-strings`, this operates on Swift source code where the pattern
  /// is `"oldValue"` → `"newKey"` (no ` = ` anchor).
  ///
  /// Uses `escapeForLiteralSearch` so that Mirror-reflected values containing `\\`,
  /// `\"`, etc. are correctly matched against the escaped source representation.
  static func convertUserDefSource(paths: [String]) {
    var pendingMappings = [(oldValue: String, newKey: String)]()
    for userDef in UserDef.allCases {
      guard let map = userDef.i18nKeyConvMap else { continue }
      for (newKey, oldValue) in map {
        pendingMappings.append((oldValue, newKey))
      }
    }

    guard !pendingMappings.isEmpty else {
      print("All UserDef cases are up-to-date. No source changes needed.")
      return
    }

    // Sort by oldValue length descending to avoid partial-substring collisions.
    pendingMappings.sort { $0.oldValue.count > $1.oldValue.count }

    let fileManager = FileManager.default

    for rawPath in paths {
      let path = (rawPath as NSString).standardizingPath
      guard fileManager.fileExists(atPath: path) else {
        print("!! File not found: \(path)")
        continue
      }

      guard let originalContent = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("!! Failed to read: \(path)")
        continue
      }

      var convertedContent = originalContent
      var replacementCount = 0

      for (oldValue, newKey) in pendingMappings {
        let escapedOldValue = escapeForLiteralSearch(oldValue)
        let oldPattern = "\"\(escapedOldValue)\""
        guard convertedContent.contains(oldPattern) else { continue }
        let newPattern = "\"\(newKey)\""
        convertedContent = convertedContent.replacingOccurrences(of: oldPattern, with: newPattern)
        replacementCount += 1
      }

      guard convertedContent != originalContent else {
        print("-- No changes needed: \(path)")
        continue
      }

      do {
        try convertedContent.write(toFile: path, atomically: true, encoding: .utf8)
        print("OK Converted \(replacementCount) literal(s) in \(path)")
      } catch {
        print("!! Failed to write: \(path) — \(error.localizedDescription)")
      }
    }
  }

  // MARK: - VarArg Type D: generate-missing-strings

  /// Appends missing `"i18n:…" = "englishFallback";` entries to `.strings` files
  /// for i18n keys that appear in `UserDef.swift` but are absent from the file.
  ///
  /// Run this **after** `convert-userdef-source` so that `i18nKeyConvMapTotal`
  /// can pair every new i18n key with its old English value as a fallback.
  static func generateMissingStrings(paths: [String]) {
    let map = UserDef.i18nKeyConvMapTotal
    guard !map.isEmpty else {
      print("No i18n key mappings found. Nothing to generate.")
      return
    }

    let fileManager = FileManager.default

    for rawPath in paths {
      let path = (rawPath as NSString).standardizingPath
      guard fileManager.fileExists(atPath: path) else {
        print("!! File not found: \(path)")
        continue
      }

      guard var content = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("!! Failed to read: \(path)")
        continue
      }

      var addedCount = 0
      var newLines = ""

      for (newKey, oldValue) in map {
        // Skip if this key already appears in the file.
        guard !content.contains("\"\(newKey)\"") else { continue }
        newLines += "\"\(newKey)\" = \"\(oldValue)\";\n"
        addedCount += 1
      }

      guard addedCount > 0 else {
        print("-- No missing keys: \(path)")
        continue
      }

      // Ensure exactly one trailing newline before appending.
      if !content.hasSuffix("\n") { content += "\n" }
      content += newLines

      do {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        print("OK Added \(addedCount) missing key(s) to \(path)")
      } catch {
        print("!! Failed to write: \(path) — \(error.localizedDescription)")
      }
    }
  }

  // MARK: - VarArg Type B: list-pending-userdef

  static func listPendingUserDef() {
    let pendingCases = UserDef.allCases.filter(\.isMetadataPendingManualUpdate)
    guard !pendingCases.isEmpty else {
      print("All UserDef cases are up-to-date. No manual update needed.")
      return
    }
    print("Pending manual update (\(pendingCases.count) cases):")
    for userDef in pendingCases {
      print("  \(String(describing: userDef))")
    }
  }

  // MARK: - Phase 75: convert-bare-keys (Non-UserDef .strings key migration)

  static func convertBareKeys(paths: [String]) {
    let map = NonUserDefI18nMap.keyMap
    guard !map.isEmpty else {
      print("No Non-UserDef i18n key mappings found. Nothing to convert.")
      return
    }

    let sortedEntries = map.sorted { $0.key.count > $1.key.count }
    let fileManager = FileManager.default

    for rawPath in paths {
      let path = (rawPath as NSString).standardizingPath
      guard fileManager.fileExists(atPath: path) else {
        print("!! File not found: \(path)")
        continue
      }

      guard let originalContent = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("!! Failed to read: \(path)")
        continue
      }

      var convertedContent = originalContent
      var replacementCount = 0
      var skippedAlreadyI18n = 0

      for (oldValue, newKey) in sortedEntries {
        let escapedOldValue = escapeForLiteralSearch(oldValue)
        let oldPattern = "\"\(escapedOldValue)\" = "

        guard !convertedContent.contains("\"\(newKey)\" = ") else {
          skippedAlreadyI18n += 1
          continue
        }

        guard convertedContent.contains(oldPattern) else { continue }
        let newPattern = "\"\(newKey)\" = "
        convertedContent = convertedContent.replacingOccurrences(of: oldPattern, with: newPattern)
        replacementCount += 1
      }

      guard convertedContent != originalContent else {
        if skippedAlreadyI18n > 0 {
          print("-- All \(skippedAlreadyI18n) key(s) already in i18n: format: \(path)")
        } else {
          print("-- No changes needed: \(path)")
        }
        continue
      }

      do {
        try convertedContent.write(toFile: path, atomically: true, encoding: .utf8)
        print(
          "OK Converted \(replacementCount) bare key(s)" +
            (skippedAlreadyI18n > 0 ? " (skipped \(skippedAlreadyI18n) already-i18n)" : "") +
            " in \(path)"
        )
      } catch {
        print("!! Failed to write: \(path) — \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Phase 75: convert-bare-keys-in-source (Non-UserDef Swift source migration)

  static func convertBareKeysInSource(paths: [String]) {
    let map = NonUserDefI18nMap.keyMap
    guard !map.isEmpty else {
      print("No Non-UserDef i18n key mappings found. Nothing to convert.")
      return
    }

    let sortedEntries = map.sorted { $0.key.count > $1.key.count }
    let fileManager = FileManager.default

    for rawPath in paths {
      let path = (rawPath as NSString).standardizingPath
      guard fileManager.fileExists(atPath: path) else {
        print("!! File not found: \(path)")
        continue
      }

      guard let originalContent = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("!! Failed to read: \(path)")
        continue
      }

      var convertedContent = originalContent
      var replacementCount = 0

      for (oldValue, newKey) in sortedEntries {
        let escapedOldValue = escapeForLiteralSearch(oldValue)
        let oldPattern = "\"\(escapedOldValue)\".i18n"
        guard convertedContent.contains(oldPattern) else { continue }
        let newPattern = "\"\(newKey)\".i18n"
        convertedContent = convertedContent.replacingOccurrences(of: oldPattern, with: newPattern)
        replacementCount += 1
      }

      guard convertedContent != originalContent else {
        print("-- No changes needed: \(path)")
        continue
      }

      do {
        try convertedContent.write(toFile: path, atomically: true, encoding: .utf8)
        print("OK Converted \(replacementCount) literal(s) in \(path)")
      } catch {
        print("!! Failed to write: \(path) — \(error.localizedDescription)")
      }
    }
  }
}
