import Foundation

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let mappingURL = baseURL.appendingPathComponent("LocalizationKeyMapping.json")
let mappingData = try Data(contentsOf: mappingURL)
guard let mapping = try JSONSerialization.jsonObject(with: mappingData) as? [String: String] else {
  fatalError("Unable to parse localization mapping")
}

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
}

func escapeForSwiftLiteral(_ text: String) -> String {
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

let swiftRoot = baseURL.appendingPathComponent("Packages/vChewing_MainAssembly/Sources/MainAssembly")
let fileManager = FileManager.default
let swiftFiles = try fileManager.contentsOfDirectory(atPath: swiftRoot.path)
  .flatMap { entry -> [String] in
    let url = swiftRoot.appendingPathComponent(entry)
    if fileManager.fileExists(atPath: url.path, isDirectory: nil), let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == true {
      return (try fileManager.subpathsOfDirectory(atPath: url.path)).map { url.appendingPathComponent($0).path }
    } else {
      return [url.path]
    }
  }
  .filter { $0.hasSuffix(".swift") }

let nsLocalizedRegex = try NSRegularExpression(
  pattern: "NSLocalizedString\\(\\s*\\\"(?<key>(?:\\\\.|[^\\\\\\\"])*)\\\"\\s*,\\s*comment:\\s*\\\"[^\\\"]*\\\"\\s*\\)",
  options: [.allowCommentsAndWhitespace]
)
let localizedLiteralRegex = try NSRegularExpression(
  pattern: "\\\"(?<key>(?:\\\\.|[^\\\\\\\"]))\\\"(?=\\s*\\.localized)",
  options: []
)

func replaceNSLocalized(in text: String) -> String {
  var result = text
  let matches = nsLocalizedRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
  for match in matches.reversed() {
    guard let keyRange = Range(match.range(withName: "key"), in: text) else { continue }
    let raw = String(text[keyRange])
    let unescaped = raw.unescapedLiteral
    let newKey = mapping[unescaped] ?? unescaped
    let replacement = "\"\(escapeForSwiftLiteral(newKey))\".localized"
    result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
  }
  return result
}

func replaceLocalizedLiterals(in text: String) -> String {
  var result = text
  let matches = localizedLiteralRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
  for match in matches.reversed() {
    guard let keyRange = Range(match.range(withName: "key"), in: result) else { continue }
    let raw = String(result[keyRange])
    let unescaped = raw.unescapedLiteral
    let newKey = mapping[unescaped] ?? unescaped
    let replacement = "\"\(escapeForSwiftLiteral(newKey))\""
    result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
  }
  return result
}

for path in swiftFiles {
  let url = URL(fileURLWithPath: path)
  print("Processing \(path)")
  let content = try String(contentsOf: url, encoding: .utf8)
  var updated = replaceNSLocalized(in: content)
  updated = replaceLocalizedLiterals(in: updated)
  if updated != content {
    try updated.write(to: url, atomically: true, encoding: .utf8)
    print("Updated localized literals in \(url.path)")
  }
}
print("Updated localized literals in MainAssembly source files")
