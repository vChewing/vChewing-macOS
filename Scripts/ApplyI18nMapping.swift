#!/usr/bin/env swift

// (c) 2024 and onwards The vChewing Project (MIT-NTL License).
// This script applies the i18n mapping to all Localizable.strings files.

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
  
  var escaped: String {
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

// Regex for parsing .strings files
let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

func rewriteStrings(at url: URL) throws {
  let raw = try String(contentsOf: url, encoding: .utf8)
  let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
  
  let rewritten = lines.map { line -> String in
    let lineStr = String(line)
    let ns = NSString(string: lineStr)
    let range = NSRange(location: 0, length: ns.length)
    
    guard let match = regex.firstMatch(in: lineStr, options: [], range: range) else {
      return lineStr
    }
    
    guard
      let keyRange = Range(match.range(withName: "key"), in: lineStr),
      let valueRange = Range(match.range(withName: "value"), in: lineStr)
    else {
      return lineStr
    }
    
    let rawKey = String(lineStr[keyRange])
    let unescapedKey = rawKey.unescaped
    let newKey = mapping[unescapedKey] ?? unescapedKey
    let value = String(lineStr[valueRange])
    
    return "\"\(newKey.escaped)\" = \"\(value)\";"
  }
  
  try rewritten.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
}

// Apply to all .lproj directories
let localeRoot = baseURL.appendingPathComponent("Source/Resources")
let fileManager = FileManager.default
let localeDirs = try fileManager.contentsOfDirectory(atPath: localeRoot.path)

var updatedCount = 0

for dir in localeDirs where dir.hasSuffix(".lproj") {
  let fileURL = localeRoot.appendingPathComponent(dir).appendingPathComponent("Localizable.strings")
  guard fileManager.fileExists(atPath: fileURL.path) else { continue }
  
  print("Processing \(dir)...")
  try rewriteStrings(at: fileURL)
  updatedCount += 1
}

print("\nSuccessfully updated \(updatedCount) localization files")
