#!/usr/bin/env swift

// (c) 2024 and onwards The vChewing Project (MIT-NTL License).
// This script generates contextual i18n localization key mappings.

import Foundation

// MARK: - Data Structures

struct L10nOldKey: Hashable {
  let rawWithEscSlashes: String
  let sansEscSlashes: String
}

struct KeyContext {
  let oldKey: String
  let newKey: String
  let context: String
  let category: String
}

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

// MARK: - Placeholder Detection

let placeholderPattern = try NSRegularExpression(pattern: "%(?:[0-9]+\\$)?[@dfFXsScC]", options: [])

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

// MARK: - Main Logic

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

// MARK: - Contextual Mapping

var mapping = [String: String]()
var usedKeys = Set<String>()

// Preserve existing i18n keys
for entry in oldKeys {
  let unescaped = entry.sansEscSlashes
  if unescaped.hasPrefix("i18n:") {
    mapping[unescaped] = unescaped
    usedKeys.insert(unescaped)
  }
}

// Map keys based on context
func generateI18nKey(for text: String) -> String? {
  let suffix = placeholderSuffix(from: text)
  
  // Category-based keys (symbol menu categories)
  if text.hasPrefix("cat") {
    let name = String(text.dropFirst(3))
    return "i18n:SymbolMenu.Category.\(name)\(suffix)"
  }
  
  // Notification switches
  if text.hasPrefix("NotificationSwitch") {
    let state = String(text.dropFirst("NotificationSwitch".count))
    return "i18n:Notification.Switch.\(state)\(suffix)"
  }
  
  // Menu items
  if text.contains("…") || text.contains("Menu") {
    if text.contains("Preferences") {
      return "i18n:Menu.Preferences\(suffix)"
    } else if text.contains("Client Manager") {
      return "i18n:Menu.ClientManager\(suffix)"
    } else if text.contains("Service Menu Editor") {
      return "i18n:Menu.ServiceMenuEditor\(suffix)"
    } else if text.contains("Reverse Lookup") {
      return "i18n:Menu.ReverseLookup\(suffix)"
    } else if text.contains("Check for Updates") {
      return "i18n:Menu.CheckForUpdates\(suffix)"
    } else if text.contains("About vChewing") {
      return "i18n:Menu.AboutVChewing\(suffix)"
    } else if text.contains("Reboot vChewing") {
      return "i18n:Menu.RebootVChewing\(suffix)"
    } else if text.contains("Uninstall vChewing") {
      return "i18n:Menu.UninstallVChewing\(suffix)"
    } else if text.contains("Edit") && text.contains("Phrases") {
      return "i18n:Menu.EditUserPhrases\(suffix)"
    } else if text.contains("Edit") && text.contains("Associated") {
      return "i18n:Menu.EditAssociatedPhrases\(suffix)"
    } else if text.contains("Edit") && text.contains("Excluded") {
      return "i18n:Menu.EditExcludedPhrases\(suffix)"
    } else if text.contains("Edit") && text.contains("Replacement") {
      return "i18n:Menu.EditPhraseReplacement\(suffix)"
    } else if text.contains("Edit") && text.contains("Symbol") {
      return "i18n:Menu.EditUserSymbol\(suffix)"
    } else if text.contains("Clear Memorized") {
      return "i18n:Menu.ClearMemorizedPhrases\(suffix)"
    } else if text.contains("Optimize Memorized") {
      return "i18n:Menu.OptimizeMemorizedPhrases\(suffix)"
    } else if text.contains("Reload User Phrases") {
      return "i18n:Menu.ReloadUserPhrases\(suffix)"
    }
  }
  
  // Input mode related
  if text.contains("Input Mode") {
    if text.contains("Switch to") {
      return "i18n:InputMode.SwitchTo\(suffix)"
    } else if text.contains("Chinese") {
      return "i18n:InputMode.Chinese\(suffix)"
    } else if text.contains("Alphanumerical") {
      return "i18n:InputMode.Alphanumerical\(suffix)"
    } else if text.contains("CHS / CHT") {
      return "i18n:InputMode.ChsToggle\(suffix)"
    } else if text.contains("Target") && text.contains("Required") {
      return "i18n:InputMode.ActivationRequired\(suffix)"
    }
  }
  
  // Typing modes
  if text == "Per-Char Select Mode" {
    return "i18n:TypingMode.PerCharSelect\(suffix)"
  } else if text == "Force KangXi Writing" {
    return "i18n:TypingMode.ForceKangXi\(suffix)"
  } else if text == "JIS Shinjitai Output" {
    return "i18n:TypingMode.JisShinjitai\(suffix)"
  } else if text == "Currency Numeral Output" {
    return "i18n:TypingMode.CurrencyNumeral\(suffix)"
  } else if text == "Half-Width Punctuation Mode" {
    return "i18n:TypingMode.HalfWidthPunctuation\(suffix)"
  } else if text == "CNS11643 Mode" {
    return "i18n:TypingMode.Cns11643\(suffix)"
  } else if text == "Symbol & Emoji Input" {
    return "i18n:TypingMode.SymbolEmoji\(suffix)"
  } else if text == "Associated Phrases" {
    return "i18n:TypingMode.AssociatedPhrases\(suffix)"
  } else if text == "Use Phrase Replacement" {
    return "i18n:TypingMode.PhraseReplacement\(suffix)"
  } else if text == "CIN Cassette Mode" {
    return "i18n:TypingMode.Cassette\(suffix)"
  }
  
  // Phrase editor messages
  if text.contains("Succeeded") || text.contains("Failed") || text.contains("⚠︎") {
    if text.contains("boosting a candidate") {
      if text.contains("Succeeded") {
        return "i18n:PhraseEditor.BoostCandidate.Success\(suffix)"
      } else {
        return "i18n:PhraseEditor.BoostCandidate.Failed\(suffix)"
      }
    } else if text.contains("nerfing a candidate") {
      if text.contains("Succeeded") {
        return "i18n:PhraseEditor.NerfCandidate.Success\(suffix)"
      } else {
        return "i18n:PhraseEditor.NerfCandidate.Failed\(suffix)"
      }
    } else if text.contains("filtering a candidate") {
      if text.contains("Succeeded") {
        return "i18n:PhraseEditor.FilterCandidate.Success\(suffix)"
      } else {
        return "i18n:PhraseEditor.FilterCandidate.Failed\(suffix)"
      }
    } else if text.contains("nerfing a user phrase") {
      return "i18n:PhraseEditor.NerfUserPhrase.Success\(suffix)"
    } else if text.contains("filtering a user phrase") {
      return "i18n:PhraseEditor.FilterUserPhrase.Success\(suffix)"
    } else if text.contains("unfiltering a phrase") {
      return "i18n:PhraseEditor.UnfilterPhrase.Success\(suffix)"
    } else if text.contains("adding / boosting a user phrase") {
      return "i18n:PhraseEditor.AddBoostUserPhrase.Success\(suffix)"
    }
  }
  
  // Candidate selection messages
  if text.contains("already exists") {
    if text.contains("BackSpace") {
      return "i18n:Candidate.AlreadyExists.WithExclude\(suffix)"
    } else {
      return "i18n:Candidate.AlreadyExists.Simple\(suffix)"
    }
  } else if text.contains("selected. ENTER") {
    if text.contains("add user phrase") {
      return "i18n:Candidate.Selected.AddUserPhrase\(suffix)"
    } else if text.contains("unfilter") {
      return "i18n:Candidate.Selected.Unfilter\(suffix)"
    }
  } else if text.contains("length must") {
    return "i18n:Candidate.LengthMustBeAtLeast\(suffix)"
  } else if text.contains("length should") {
    return "i18n:Candidate.LengthShouldNotExceed\(suffix)"
  }
  
  // Keyboard layouts
  if text.contains("Dachen") || text.contains("Eten") || text.contains("Hsu") {
    if text.contains("Dachen 26") {
      return "i18n:KeyboardLayout.Dachen26\(suffix)"
    } else if text.contains("Dachen Trad") {
      return "i18n:KeyboardLayout.DachenTrad\(suffix)"
    } else if text.contains("Eten 26") {
      return "i18n:KeyboardLayout.Eten26\(suffix)"
    } else if text.contains("Eten Trad") {
      return "i18n:KeyboardLayout.EtenTrad\(suffix)"
    } else if text.contains("Eten Traditional") {
      return "i18n:KeyboardLayout.EtenTraditional\(suffix)"
    } else if text == "Hsu" {
      return "i18n:KeyboardLayout.Hsu\(suffix)"
    } else if text.contains("Dachen") {
      return "i18n:KeyboardLayout.Dachen\(suffix)"
    }
  } else if text.contains("Pinyin") {
    if text.contains("Hanyu") {
      return "i18n:KeyboardLayout.HanyuPinyin\(suffix)"
    } else if text.contains("Hualuo") {
      return "i18n:KeyboardLayout.HualuoPinyin\(suffix)"
    } else if text.contains("Universal") {
      return "i18n:KeyboardLayout.UniversalPinyin\(suffix)"
    } else if text.contains("Secondary") {
      return "i18n:KeyboardLayout.SecondaryPinyin\(suffix)"
    } else if text.contains("Wade-Giles") {
      return "i18n:KeyboardLayout.WadeGilesPinyin\(suffix)"
    } else if text.contains("Yale") {
      return "i18n:KeyboardLayout.YalePinyin\(suffix)"
    }
  } else if text.contains("Seigyou") || text.contains("IBM") || text.contains("MiTAC") || text.contains("Starlight") {
    if text == "Seigyou" || text.contains("JinYei") {
      return "i18n:KeyboardLayout.Seigyou\(suffix)"
    } else if text == "Fake Seigyou" || text.contains("Similar to JinYei") {
      return "i18n:KeyboardLayout.FakeSeigyou\(suffix)"
    } else if text == "IBM" {
      return "i18n:KeyboardLayout.Ibm\(suffix)"
    } else if text == "MiTAC" {
      return "i18n:KeyboardLayout.Mitac\(suffix)"
    } else if text == "Starlight" {
      return "i18n:KeyboardLayout.Starlight\(suffix)"
    }
  } else if text.contains("Apple") {
    if text.contains("ABC") {
      return "i18n:KeyboardLayout.AppleAbc\(suffix)"
    } else if text.contains("Zhuyin Bopomofo") {
      return "i18n:KeyboardLayout.AppleZhuyinBopomofo\(suffix)"
    } else if text.contains("Zhuyin Eten") {
      return "i18n:KeyboardLayout.AppleZhuyinEten\(suffix)"
    } else if text.contains("Chewing - Dachen") {
      return "i18n:KeyboardLayout.AppleChewingDachen\(suffix)"
    } else if text.contains("Chewing - Eten") {
      return "i18n:KeyboardLayout.AppleChewingEten\(suffix)"
    }
  }
  
  // Settings UI labels
  if text.contains("Layout:") || text.contains("Size:") || text.contains("Keys:") || text.contains("Key:") || text.contains("Parser:") || text.contains("Conversion:") || text.contains("Selection:") || text.contains("Style:") || text.contains("Language:") || text.contains("Settings:") || text.contains("Shortcuts:") || text.contains("Setup:") {
    if text == "Basic Keyboard Layout:" {
      return "i18n:Settings.BasicKeyboardLayout\(suffix)"
    } else if text == "Alphanumerical Layout:" {
      return "i18n:Settings.AlphanumericalLayout\(suffix)"
    } else if text == "Phonetic Parser:" {
      return "i18n:Settings.PhoneticParser\(suffix)"
    } else if text == "Candidate Layout:" {
      return "i18n:Settings.CandidateLayout\(suffix)"
    } else if text == "Candidate Size:" {
      return "i18n:Settings.CandidateSize\(suffix)"
    } else if text == "Selection Keys:" {
      return "i18n:Settings.SelectionKeys\(suffix)"
    } else if text == "Intonation Key:" {
      return "i18n:Settings.IntonationKey\(suffix)"
    } else if text == "Chinese Conversion:" {
      return "i18n:Settings.ChineseConversion\(suffix)"
    } else if text == "Cursor Selection:" {
      return "i18n:Settings.CursorSelection\(suffix)"
    } else if text == "Typing Style:" {
      return "i18n:Settings.TypingStyle\(suffix)"
    } else if text == "UI Language:" {
      return "i18n:Settings.UiLanguage\(suffix)"
    } else if text == "Output Settings:" {
      return "i18n:Settings.OutputSettings\(suffix)"
    } else if text == "Typing Settings:" {
      return "i18n:Settings.TypingSettings\(suffix)"
    } else if text == "Keyboard Shortcuts:" {
      return "i18n:Settings.KeyboardShortcuts\(suffix)"
    } else if text == "Misc Settings:" {
      return "i18n:Settings.MiscSettings\(suffix)"
    } else if text == "Quick Setup:" {
      return "i18n:Settings.QuickSetup\(suffix)"
    } else if text == "Experimental:" {
      return "i18n:Settings.Experimental\(suffix)"
    }
  }
  
  // Button labels
  if text == "OK" {
    return "i18n:Button.Ok\(suffix)"
  } else if text == "Cancel" {
    return "i18n:Button.Cancel\(suffix)"
  } else if text == "Yes" {
    return "i18n:Button.Yes\(suffix)"
  } else if text == "No" {
    return "i18n:Button.No\(suffix)"
  } else if text == "Save" {
    return "i18n:Button.Save\(suffix)"
  } else if text == "Reload" {
    return "i18n:Button.Reload\(suffix)"
  } else if text == "Reset Default" {
    return "i18n:Button.ResetDefault\(suffix)"
  } else if text == "Visit Website" {
    return "i18n:Button.VisitWebsite\(suffix)"
  } else if text == "Check Later" {
    return "i18n:Button.CheckLater\(suffix)"
  } else if text == "Not Now" {
    return "i18n:Button.NotNow\(suffix)"
  } else if text == "Add Client" {
    return "i18n:Button.AddClient\(suffix)"
  } else if text == "Add Service" {
    return "i18n:Button.AddService\(suffix)"
  } else if text == "Remove Selected" {
    return "i18n:Button.RemoveSelected\(suffix)"
  } else if text == "Copy All to Clipboard" {
    return "i18n:Button.CopyAllToClipboard\(suffix)"
  } else if text == "Open App Support Folder" {
    return "i18n:Button.OpenAppSupportFolder\(suffix)"
  } else if text == "Open User Dictionary Folder" {
    return "i18n:Button.OpenUserDictionaryFolder\(suffix)"
  }
  
  // Language names
  if text == "en" || text == "English" {
    return "i18n:Language.English\(suffix)"
  } else if text == "ja" || text == "Japanese" {
    return "i18n:Language.Japanese\(suffix)"
  } else if text == "zh-Hans" || text == "Simplified Chinese" {
    return "i18n:Language.SimplifiedChinese\(suffix)"
  } else if text == "zh-Hant" || text == "Traditional Chinese" {
    return "i18n:Language.TraditionalChinese\(suffix)"
  }
  
  // Categories
  if text == "General" {
    return "i18n:Category.General\(suffix)"
  } else if text == "Dictionary" {
    return "i18n:Category.Dictionary\(suffix)"
  } else if text == "Keyboard" {
    return "i18n:Category.Keyboard\(suffix)"
  } else if text == "Cassette" {
    return "i18n:Category.Cassette\(suffix)"
  } else if text == "Experience" {
    return "i18n:Category.Experience\(suffix)"
  } else if text == "Phrase Editor" {
    return "i18n:Category.PhraseEditor\(suffix)"
  } else if text == "DevZone" {
    return "i18n:Category.DevZone\(suffix)"
  }
  
  // Tooltips and instructions
  if text.contains("Stroke") {
    return "i18n:Tooltip.Stroke\(suffix)"
  } else if text.contains("Code Point Input") {
    return "i18n:Tooltip.CodePointInput\(suffix)"
  } else if text.contains("Hanin Keyboard Symbol Input") {
    return "i18n:Tooltip.HaninKeyboardSymbolInput\(suffix)"
  } else if text.contains("Roman Numeral") {
    if text.contains("tooltip") {
      return "i18n:TypingMethod.RomanNumerals.Tooltip\(suffix)"
    } else if text.contains("error") {
      if text.contains("invalidCharacter") {
        return "i18n:TypingMethod.RomanNumerals.Error.InvalidCharacter\(suffix)"
      } else if text.contains("invalidInput") {
        return "i18n:TypingMethod.RomanNumerals.Error.InvalidInput\(suffix)"
      } else if text.contains("valueOutOfRange") {
        return "i18n:TypingMethod.RomanNumerals.Error.ValueOutOfRange\(suffix)"
      }
    }
  }
  
  // Error messages
  if text.contains("Invalid") {
    if text.contains("Code Point") {
      return "i18n:Error.InvalidCodePoint\(suffix)"
    } else if text.contains("Selection Keys") {
      return "i18n:Error.InvalidSelectionKeys\(suffix)"
    }
  }
  
  // Loading messages
  if text.contains("Loading") {
    if text.contains("CHS Core Dict") {
      return "i18n:Loading.ChsCoreDict\(suffix)"
    } else if text.contains("CHT Core Dict") {
      return "i18n:Loading.ChtCoreDict\(suffix)"
    } else if text.contains("complete") {
      return "i18n:Loading.Complete\(suffix)"
    } else if text == "Loading…" {
      return "i18n:Loading.Ellipsis\(suffix)"
    }
  }
  
  // Fallback to generic mapping
  return nil
}

// Generate mappings for all non-i18n keys
let sortedKeys = oldKeys.sorted { $0.sansEscSlashes < $1.sansEscSlashes }

for entry in sortedKeys {
  let unescaped = entry.sansEscSlashes
  if mapping[unescaped] != nil {
    continue // Already mapped (existing i18n key)
  }
  
  if let contextualKey = generateI18nKey(for: unescaped) {
    // Ensure uniqueness
    var finalKey = contextualKey
    var counter = 1
    while usedKeys.contains(finalKey) {
      counter += 1
      let parts = contextualKey.split(separator: ":")
      if parts.count == 2 {
        let suffix = placeholderSuffix(from: unescaped)
        let basePart = String(parts[1]).replacingOccurrences(of: suffix, with: "")
        finalKey = "i18n:\(basePart)\(counter)\(suffix)"
      } else {
        finalKey = "\(contextualKey)\(counter)"
      }
    }
    mapping[unescaped] = finalKey
    usedKeys.insert(finalKey)
  } else {
    // Generate a generic fallback key
    let words = unescaped.split(whereSeparator: { !CharacterSet.alphanumerics.contains($0.unicodeScalars.first!) })
      .map { String($0) }
      .filter { !$0.isEmpty }
    
    guard !words.isEmpty else {
      mapping[unescaped] = "i18n:MainAssembly.Unnamed\(placeholderSuffix(from: unescaped))"
      usedKeys.insert(mapping[unescaped]!)
      continue
    }
    
    let camelCase = words.enumerated().map { index, word in
      index == 0 ? word.lowercased() : word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }.joined()
    
    var finalKey = "i18n:MainAssembly.\(camelCase)\(placeholderSuffix(from: unescaped))"
    var counter = 1
    while usedKeys.contains(finalKey) {
      counter += 1
      finalKey = "i18n:MainAssembly.\(camelCase)\(counter)\(placeholderSuffix(from: unescaped))"
    }
    mapping[unescaped] = finalKey
    usedKeys.insert(finalKey)
  }
}

// Save mapping to JSON
let jsonURL = baseURL.appendingPathComponent("Scripts/LocalizationKeyMapping.json")
let jsonData = try JSONSerialization.data(withJSONObject: mapping, options: [.prettyPrinted, .sortedKeys])
try jsonData.write(to: jsonURL)

print("Generated mapping for \(mapping.count) keys")
print("Saved to: \(jsonURL.path)")

// Print some statistics
let i18nCategories = mapping.values.compactMap { key -> String? in
  let parts = key.split(separator: ":")
  guard parts.count == 2 else { return nil }
  let components = parts[1].split(separator: ".")
  return components.first.map(String.init)
}.reduce(into: [:]) { counts, category in
  counts[category, default: 0] += 1
}

print("\nCategory distribution:")
for (category, count) in i18nCategories.sorted(by: { $0.key < $1.key }) {
  print("  \(category): \(count)")
}
