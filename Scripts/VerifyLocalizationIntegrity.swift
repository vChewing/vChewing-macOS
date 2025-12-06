#!/usr/bin/env swift

// (c) 2024 and onwards The vChewing Project (MIT-NTL License).
// This script verifies localization key integrity.

import Foundation

// MARK: - String Extensions

extension String {
  var unescaped: String {
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
}

// MARK: - Main Logic

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let fileManager = FileManager.default

print("=== Localization Key Integrity Verification ===\n")

// Step 1: Parse all localization files
let localeRoot = baseURL.appendingPathComponent("Source/Resources")
let localeDirs = try fileManager.contentsOfDirectory(atPath: localeRoot.path)
  .filter { $0.hasSuffix(".lproj") }

let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

var localizationKeys: [String: Set<String>] = [:]

for dir in localeDirs {
  let fileURL = localeRoot.appendingPathComponent(dir).appendingPathComponent("Localizable.strings")
  guard fileManager.fileExists(atPath: fileURL.path) else { continue }
  
  let data = try String(contentsOf: fileURL, encoding: .utf8)
  var keys = Set<String>()
  
  regex.enumerateMatches(in: data, options: [], range: NSRange(data.startIndex..., in: data)) { match, _, _ in
    guard
      let match = match,
      let keyRange = Range(match.range(withName: "key"), in: data)
    else { return }
    let raw = String(data[keyRange])
    let unescaped = raw.unescaped
    keys.insert(unescaped)
  }
  
  localizationKeys[dir] = keys
  print("✓ Loaded \(keys.count) keys from \(dir)")
}

// Step 2: Verify all localization files have the same keys
print("\n=== Key Consistency Check ===")
let referenceLocale = "en.lproj"
guard let referenceKeys = localizationKeys[referenceLocale] else {
  print("✗ Error: Could not find reference locale \(referenceLocale)")
  exit(1)
}

var allConsistent = true
for (locale, keys) in localizationKeys where locale != referenceLocale {
  let missingKeys = referenceKeys.subtracting(keys)
  let extraKeys = keys.subtracting(referenceKeys)
  
  if !missingKeys.isEmpty || !extraKeys.isEmpty {
    allConsistent = false
    print("\n✗ \(locale) has inconsistencies:")
    if !missingKeys.isEmpty {
      print("  Missing keys (\(missingKeys.count)):")
      for key in missingKeys.sorted().prefix(5) {
        print("    - \(key)")
      }
      if missingKeys.count > 5 {
        print("    ... and \(missingKeys.count - 5) more")
      }
    }
    if !extraKeys.isEmpty {
      print("  Extra keys (\(extraKeys.count)):")
      for key in extraKeys.sorted().prefix(5) {
        print("    + \(key)")
      }
      if extraKeys.count > 5 {
        print("    ... and \(extraKeys.count - 5) more")
      }
    }
  } else {
    print("✓ \(locale) is consistent with reference")
  }
}

if allConsistent {
  print("\n✓ All localization files have consistent keys")
}

// Step 3: Find all .localized calls in Swift source
print("\n=== Source Code Key Usage Check ===")

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

let mainAssemblyRoot = baseURL.appendingPathComponent("Packages/vChewing_MainAssembly/Sources/MainAssembly")
let swiftFiles = findSwiftFiles(in: mainAssemblyRoot)

let localizedLiteralRegex = try NSRegularExpression(
  pattern: "\"(?<key>(?:\\\\.|[^\\\\\"])*)\"(?=\\s*\\.localized)",
  options: []
)

var usedKeys = Set<String>()
var sourceFileCount = 0

for fileURL in swiftFiles {
  let content = try String(contentsOf: fileURL, encoding: .utf8)
  let matches = localizedLiteralRegex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
  
  for match in matches {
    guard let keyRange = Range(match.range(withName: "key"), in: content) else { continue }
    let rawKey = String(content[keyRange])
    let unescapedKey = rawKey.unescapedLiteral
    usedKeys.insert(unescapedKey)
  }
  sourceFileCount += 1
}

print("✓ Scanned \(sourceFileCount) Swift files")
print("✓ Found \(usedKeys.count) unique localization keys in use")

// Step 4: Check for missing keys
let missingInLocalization = usedKeys.subtracting(referenceKeys)
if !missingInLocalization.isEmpty {
  print("\n✗ Warning: \(missingInLocalization.count) keys used in code but missing in localization files:")
  for key in missingInLocalization.sorted().prefix(10) {
    print("  - \(key)")
  }
  if missingInLocalization.count > 10 {
    print("  ... and \(missingInLocalization.count - 10) more")
  }
} else {
  print("\n✓ All keys used in code exist in localization files")
}

// Step 5: Check for i18n format compliance
print("\n=== i18n Format Compliance Check ===")
let nonI18nKeys = referenceKeys.filter { !$0.hasPrefix("i18n:") }
if !nonI18nKeys.isEmpty {
  print("✗ Warning: \(nonI18nKeys.count) keys do not follow i18n: prefix format:")
  for key in nonI18nKeys.sorted().prefix(10) {
    print("  - \(key)")
  }
  if nonI18nKeys.count > 10 {
    print("  ... and \(nonI18nKeys.count - 10) more")
  }
} else {
  print("✓ All keys follow i18n: prefix format")
}

// Step 6: Summary
print("\n=== Summary ===")
print("Total localization keys: \(referenceKeys.count)")
print("Keys used in code: \(usedKeys.count)")
print("i18n format compliance: \(referenceKeys.count - nonI18nKeys.count)/\(referenceKeys.count)")
print("Locale consistency: \(allConsistent ? "✓ PASS" : "✗ FAIL")")
print("Code-Localization sync: \(missingInLocalization.isEmpty ? "✓ PASS" : "✗ FAIL")")

if allConsistent && missingInLocalization.isEmpty {
  print("\n✓✓✓ ALL CHECKS PASSED ✓✓✓")
  exit(0)
} else {
  print("\n✗✗✗ SOME CHECKS FAILED ✗✗✗")
  exit(1)
}
