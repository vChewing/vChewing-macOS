import Foundation

struct L10nOldKey: Hashable {
  let rawWithEscSlashes: String
  let sansEscSlashes: String
}

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let enURL = baseURL.appendingPathComponent("Source/Resources/en.lproj/Localizable.strings")
let data = try String(contentsOf: enURL, encoding: .utf8)
let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

var oldKeys = Set<L10nOldKey>()
regex.enumerateMatches(in: data, options: [], range: NSRange(data.startIndex..., in: data)) { match, _, _ in
  guard
    let match = match,
    let keyRange = Range(match.range(withName: "key"), in: data)
  else { return }
  let raw = String(data[keyRange])
  let unescaped = raw.unescaped
  oldKeys.insert(.init(rawWithEscSlashes: raw, sansEscSlashes: unescaped))
}

let placeholderPattern = try NSRegularExpression(pattern: "%(?:[0-9]+\\$)?[@dfFXsScC@]", options: [])

func placeholderSuffix(from text: String) -> String {
  let ns = NSString(string: text)
  let matches = placeholderPattern.matches(
    in: text,
    options: [],
    range: NSRange(location: 0, length: ns.length)
  )
  guard !matches.isEmpty else { return "" }
  let suffixes = matches
    .map { ns.substring(with: $0.range) }
    .reduce(into: [String]()) { array, item in
      if !array.contains(item) {
        array.append(item)
      }
    }
  return suffixes.map { ":\($0)" }.joined()
}

func normalizedIdentifier(from text: String) -> String {
  var words = [String]()
  var current = ""
  for scalar in text.unicodeScalars {
    if CharacterSet.alphanumerics.contains(scalar) {
      current.append(Character(scalar))
    } else if !current.isEmpty {
      words.append(current)
      current = ""
    }
  }
  if !current.isEmpty {
    words.append(current)
  }
  guard !words.isEmpty else {
    return "unnamed"
  }
  let normalizedWords = words.map { word -> String in
    guard !word.isEmpty else { return "" }
    let lower = word.lowercased()
    return lower
  }
  var result = normalizedWords[0]
  for word in normalizedWords.dropFirst() {
    result += word.prefix(1).uppercased() + word.dropFirst()
  }
  return result
}

var usedKeys = Set<String>()
var mapping = [String: String]()

let sortedKeys = oldKeys.sorted { $0.sansEscSlashes < $1.sansEscSlashes }

for entry in sortedKeys {
  let unescaped = entry.sansEscSlashes
  if unescaped.hasPrefix("i18n:") {
    usedKeys.insert(unescaped)
    mapping[unescaped] = unescaped
    continue
  }
  let suffix = placeholderSuffix(from: unescaped)
  let baseIdentifier = normalizedIdentifier(from: unescaped)
  let root = baseIdentifier.isEmpty ? "unnamed" : baseIdentifier
  var candidate = root
  var finalKey = "i18n:MainAssembly.\(candidate)\(suffix)"
  var counter = 1
  while usedKeys.contains(finalKey) {
    counter += 1
    candidate = "\(root)\(counter)"
    finalKey = "i18n:MainAssembly.\(candidate)\(suffix)"
  }
  usedKeys.insert(finalKey)
  mapping[unescaped] = finalKey
}

let jsonURL = baseURL.appendingPathComponent("LocalizationKeyMapping.json")
try JSONSerialization.data(withJSONObject: mapping, options: [.prettyPrinted, .sortedKeys]).write(to: jsonURL)
print("Generated mapping for \(mapping.count) keys")
if let sample = mapping.first {
  print("Sample: \(sample)")
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
