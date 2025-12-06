import Foundation

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let mappingURL = baseURL.appendingPathComponent("LocalizationKeyMapping.json")
let mappingData = try Data(contentsOf: mappingURL)
guard let mappingRaw = try JSONSerialization.jsonObject(with: mappingData) as? [String: String] else {
  fatalError("Unable to parse mapping file")
}

let localeRoot = baseURL.appendingPathComponent("Source/Resources")
let fileManager = FileManager.default
let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

func escapeForStrings(_ text: String) -> String {
  var result = ""
  for char in text {
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
}

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
    let newKey = mappingRaw[unescapedKey] ?? unescapedKey
    let value = String(lineStr[valueRange])
    return "\"\(escapeForStrings(newKey))\" = \"\(value)\";"
  }
  try rewritten.joined(separator: "\n").write(to: url, atomically: true, encoding: String.Encoding.utf8)
}

let localeDirs = try fileManager.contentsOfDirectory(atPath: localeRoot.path)
for dir in localeDirs where dir.hasSuffix(".lproj") {
  let fileURL = localeRoot.appendingPathComponent(dir).appendingPathComponent("Localizable.strings")
  guard fileManager.fileExists(atPath: fileURL.path) else { continue }
  try rewriteStrings(at: fileURL)
}
print("Rewrote localization files using mapping")
