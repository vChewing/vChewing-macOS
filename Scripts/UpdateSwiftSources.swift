#!/usr/bin/env swift

// (c) 2024 and onwards The vChewing Project (MIT-NTL License).
// This script updates Swift source files to use .localized syntax and new i18n keys.

import Foundation

// MARK: - String Extensions

extension String {
  var unescapedLiteral: String {
    var output = ""
    var iterator = makeIterator()
    while let char = iterator.next() {
      if char == "\\" {
        guard let next = iterator.next() else { break }
        switch next {
        case "\\": output.append("\\")
        case "\"": output.append("\"")
        case "n": output.append("\n")
        case "r": output.append("\r")
        case "t": output.append("\t")
        default: output.append(next)
        }
      } else {
        output.append(char)
      }
    }
    return output
  }
  
  var escapedForSwift: String {
    var result = ""
    for char in self {
      switch char {
      case "\\": result.append("\\\\")
      case "\"": result.append("\\\"")
      case "\n": result.append("\\n")
      case "\r": result.append("\\r")
      case "\t": result.append("\\t")
      default: result.append(char)
      }
    }
    return result
  }
}

// MARK: - Main Logic

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let mappingURL = baseURL.appendingPathComponent("Scripts/LocalizationKeyMapping.json")

// Load mapping
let mappingData = try Data(contentsOf: mappingURL)
guard let mapping = try JSONSerialization.jsonObject(with: mappingData) as? [String: String] else {
  fatalError("Unable to parse mapping file")
}

print("Loaded mapping for \(mapping.count) keys")

// Find all Swift files in MainAssembly
let mainAssemblyRoot = baseURL.appendingPathComponent("Packages/vChewing_MainAssembly/Sources/MainAssembly")
let fileManager = FileManager.default

func findSwiftFiles(in directory: URL) -> [URL] {
  var swiftFiles: [URL] = []
  
  guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
    return []
  }
  
  for case let fileURL as URL in enumerator {
    guard fileURL.pathExtension == "swift" else { continue }
    swiftFiles.append(fileURL)
  }
  
  return swiftFiles
}

let swiftFiles = findSwiftFiles(in: mainAssemblyRoot)
print("Found \(swiftFiles.count) Swift files to process")

// Regex patterns for localization
// Pattern 1: Single-line NSLocalizedString
let nsLocalizedRegex = try NSRegularExpression(
  pattern: "NSLocalizedString\\(\\s*\"(?<key>(?:\\\\.|[^\\\\\"])*)\"\\s*,\\s*comment:\\s*\"[^\"]*\"\\s*\\)",
  options: [.dotMatchesLineSeparators]
)

// Pattern 2: Multi-line NSLocalizedString (opening paren at end of line)
let nsLocalizedMultilineRegex = try NSRegularExpression(
  pattern: "NSLocalizedString\\(\\s*\\n\\s*\"(?<key>(?:\\\\.|[^\\\\\"])*)\"\\s*,\\s*\\n?\\s*comment:\\s*\"[^\"]*\"\\s*\\)",
  options: [.dotMatchesLineSeparators]
)

let localizedLiteralRegex = try NSRegularExpression(
  pattern: "\"(?<key>(?:\\\\.|[^\\\\\"])*)\"(?=\\s*\\.localized)",
  options: []
)

func processFile(at url: URL) throws -> Bool {
  let content = try String(contentsOf: url, encoding: .utf8)
  var updated = content
  var changed = false
  
  // First, replace multi-line NSLocalizedString() with .localized
  let nsMultilineMatches = nsLocalizedMultilineRegex.matches(in: updated, options: [], range: NSRange(updated.startIndex..., in: updated))
  
  for match in nsMultilineMatches.reversed() {
    guard let keyRange = Range(match.range(withName: "key"), in: updated) else { continue }
    let rawKey = String(updated[keyRange])
    let unescapedKey = rawKey.unescapedLiteral
    let newKey = mapping[unescapedKey] ?? unescapedKey
    
    let replacement = "\"\(newKey.escapedForSwift)\".localized"
    let nsRange = match.range
    let range = Range(nsRange, in: updated)!
    updated.replaceSubrange(range, with: replacement)
    changed = true
  }
  
  // Second, replace single-line NSLocalizedString() with .localized
  let nsMatches = nsLocalizedRegex.matches(in: updated, options: [], range: NSRange(updated.startIndex..., in: updated))
  
  for match in nsMatches.reversed() {
    guard let keyRange = Range(match.range(withName: "key"), in: updated) else { continue }
    let rawKey = String(updated[keyRange])
    let unescapedKey = rawKey.unescapedLiteral
    let newKey = mapping[unescapedKey] ?? unescapedKey
    
    let replacement = "\"\(newKey.escapedForSwift)\".localized"
    let nsRange = match.range
    let range = Range(nsRange, in: updated)!
    updated.replaceSubrange(range, with: replacement)
    changed = true
  }
  
  // Third, update keys in existing .localized calls
  let localizedMatches = localizedLiteralRegex.matches(in: updated, options: [], range: NSRange(updated.startIndex..., in: updated))
  
  for match in localizedMatches.reversed() {
    guard let keyRange = Range(match.range(withName: "key"), in: updated) else { continue }
    let rawKey = String(updated[keyRange])
    let unescapedKey = rawKey.unescapedLiteral
    
    // Only update if the key has a mapping AND it's not already an i18n key
    guard let newKey = mapping[unescapedKey], newKey != unescapedKey else { continue }
    
    let replacement = "\"\(newKey.escapedForSwift)\""
    let matchRange = match.range
    let range = Range(matchRange, in: updated)!
    updated.replaceSubrange(range, with: replacement)
    changed = true
  }
  
  if changed {
    try updated.write(to: url, atomically: true, encoding: .utf8)
  }
  
  return changed
}

var updatedFileCount = 0
var totalChanges = 0

for fileURL in swiftFiles {
  do {
    let changed = try processFile(at: fileURL)
    if changed {
      updatedFileCount += 1
      print("✓ Updated: \(fileURL.lastPathComponent)")
    }
  } catch {
    print("✗ Error processing \(fileURL.lastPathComponent): \(error)")
  }
}

print("\nSuccessfully updated \(updatedFileCount) Swift files")
