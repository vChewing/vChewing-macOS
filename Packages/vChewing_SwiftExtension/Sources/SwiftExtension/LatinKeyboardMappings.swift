// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

public enum LatinKeyboardMappings: String, CaseIterable {
  case qwerty = "com.apple.keylayout.ABC"
  case qwertyBritish = "com.apple.keylayout.British"
  case qwertyUS = "com.apple.keylayout.US" // 10.9 - 10.12
  case azerty = "com.apple.keylayout.ABC-AZERTY"
  case qwertz = "com.apple.keylayout.ABC-QWERTZ"
  case azertyFrench = "com.apple.keylayout.French" // 10.9 - 10.12
  case qwertzGerman = "com.apple.keylayout.German" // 10.9 - 10.12
  case colemak = "com.apple.keylayout.Colemak"
  case dvorak = "com.apple.keylayout.Dvorak"
  case dvorakQwertyCMD = "com.apple.keylayout.DVORAK-QWERTYCMD"
  case dvorakLeft = "com.apple.keylayout.Dvorak-Left"
  case dvorakRight = "com.apple.keylayout.Dvorak-Right"

  // MARK: Public

  public var mapTable: [UInt16: (String, String)] {
    switch self {
    case .qwerty, .qwertyBritish, .qwertyUS: return Self.dictQwerty
    case .azerty, .azertyFrench: return Self.dictAzerty
    case .qwertz, .qwertzGerman: return Self.dictQwertz
    case .colemak: return Self.dictColemak
    case .dvorak, .dvorakQwertyCMD: return Self.dictDvorak
    case .dvorakLeft: return Self.dictDvorakLeft
    case .dvorakRight: return Self.dictDvorakRight
    }
  }

  // MARK: Private

  private static let dictQwerty: [UInt16: (String, String)] = [
    0: ("a", "A"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"), 4: ("h", "H"), 5: ("g", "G"),
    6: ("z", "Z"), 7: ("x", "X"), 8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("q", "Q"),
    13: ("w", "W"), 14: ("e", "E"), 15: ("r", "R"), 16: ("y", "Y"), 17: ("t", "T"), 18: ("1", "!"),
    19: ("2", "@"), 20: ("3", "#"), 21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("=", "+"),
    25: ("9", "("), 26: ("7", "&"), 27: ("-", "_"), 28: ("8", "*"), 29: ("0", ")"), 30: ("]", "}"),
    31: ("o", "O"), 32: ("u", "U"), 33: ("[", "{"), 34: ("i", "I"), 35: ("p", "P"), 37: ("l", "L"),
    38: ("j", "J"), 39: ("\'", "\""), 40: ("k", "K"), 41: (";", ":"), 42: ("\\", "|"),
    43: (",", "<"),
    44: ("/", "?"), 45: ("n", "N"), 46: ("m", "M"), 47: (".", ">"), 50: ("`", "~"),
  ]

  private static let dictAzerty: [UInt16: (String, String)] = [
    0: ("q", "Q"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"), 4: ("h", "H"), 5: ("g", "G"),
    6: ("w", "W"), 7: ("x", "X"), 8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("a", "A"),
    13: ("z", "Z"), 14: ("e", "E"), 15: ("r", "R"), 16: ("y", "Y"), 17: ("t", "T"), 18: ("&", "1"),
    19: ("é", "2"), 20: ("\"", "3"), 21: ("\'", "4"), 22: ("§", "6"), 23: ("(", "5"),
    24: ("-", "_"),
    25: ("ç", "9"), 26: ("è", "7"), 27: (")", "°"), 28: ("!", "8"), 29: ("à", "0"), 30: ("$", "*"),
    31: ("o", "O"), 32: ("u", "U"), 33: ("^", "¨"), 34: ("i", "I"), 35: ("p", "P"), 37: ("l", "L"),
    38: ("j", "J"), 39: ("ù", "%"), 40: ("k", "K"), 41: ("m", "M"), 42: ("`", "£"), 43: (";", "."),
    44: ("=", "+"), 45: ("n", "N"), 46: (",", "?"), 47: (":", "/"), 50: ("<", ">"),
  ]

  private static let dictQwertz: [UInt16: (String, String)] = [
    0: ("a", "A"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"), 4: ("h", "H"), 5: ("g", "G"),
    6: ("y", "Y"), 7: ("x", "X"), 8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("q", "Q"),
    13: ("w", "W"), 14: ("e", "E"), 15: ("r", "R"), 16: ("z", "Z"), 17: ("t", "T"), 18: ("1", "!"),
    19: ("2", "\""), 20: ("3", "§"), 21: ("4", "$"), 22: ("6", "&"), 23: ("5", "%"), 24: ("´", "`"),
    25: ("9", ")"), 26: ("7", "/"), 27: ("ß", "?"), 28: ("8", "("), 29: ("0", "="), 30: ("+", "*"),
    31: ("o", "O"), 32: ("u", "U"), 33: ("ü", "Ü"), 34: ("i", "I"), 35: ("p", "P"), 37: ("l", "L"),
    38: ("j", "J"), 39: ("ä", "Ä"), 40: ("k", "K"), 41: ("ö", "Ö"), 42: ("#", "\'"), 43: (",", ";"),
    44: ("-", "_"), 45: ("n", "N"), 46: ("m", "M"), 47: (".", ":"), 50: ("<", ">"),
  ]

  private static let dictColemak: [UInt16: (String, String)] = [
    0: ("a", "A"), 1: ("r", "R"), 2: ("s", "S"), 3: ("t", "T"), 4: ("h", "H"), 5: ("d", "D"),
    6: ("z", "Z"), 7: ("x", "X"), 8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("q", "Q"),
    13: ("w", "W"), 14: ("f", "F"), 15: ("p", "P"), 16: ("j", "J"), 17: ("g", "G"), 18: ("1", "!"),
    19: ("2", "@"), 20: ("3", "#"), 21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("=", "+"),
    25: ("9", "("), 26: ("7", "&"), 27: ("-", "_"), 28: ("8", "*"), 29: ("0", ")"), 30: ("]", "}"),
    31: ("y", "Y"), 32: ("l", "L"), 33: ("[", "{"), 34: ("u", "U"), 35: (";", ":"), 37: ("i", "I"),
    38: ("n", "N"), 39: ("\'", "\""), 40: ("e", "E"), 41: ("o", "O"), 42: ("\\", "|"),
    43: (",", "<"),
    44: ("/", "?"), 45: ("k", "K"), 46: ("m", "M"), 47: (".", ">"), 50: ("`", "~"),
  ]

  private static let dictDvorak: [UInt16: (String, String)] = [
    0: ("a", "A"), 1: ("o", "O"), 2: ("e", "E"), 3: ("u", "U"), 4: ("d", "D"), 5: ("i", "I"),
    6: (";", ":"), 7: ("q", "Q"), 8: ("j", "J"), 9: ("k", "K"), 11: ("x", "X"), 12: ("\'", "\""),
    13: (",", "<"), 14: (".", ">"), 15: ("p", "P"), 16: ("f", "F"), 17: ("y", "Y"), 18: ("1", "!"),
    19: ("2", "@"), 20: ("3", "#"), 21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("]", "}"),
    25: ("9", "("), 26: ("7", "&"), 27: ("[", "{"), 28: ("8", "*"), 29: ("0", ")"), 30: ("=", "+"),
    31: ("r", "R"), 32: ("g", "G"), 33: ("/", "?"), 34: ("c", "C"), 35: ("l", "L"), 37: ("n", "N"),
    38: ("h", "H"), 39: ("-", "_"), 40: ("t", "T"), 41: ("s", "S"), 42: ("\\", "|"), 43: ("w", "W"),
    44: ("z", "Z"), 45: ("b", "B"), 46: ("m", "M"), 47: ("v", "V"), 50: ("`", "~"),
  ]

  private static let dictDvorakLeft: [UInt16: (String, String)] = [
    0: ("-", "_"), 1: ("k", "K"), 2: ("c", "C"), 3: ("d", "D"), 4: ("h", "H"), 5: ("t", "T"),
    6: ("\'", "\""), 7: ("x", "X"), 8: ("g", "G"), 9: ("v", "V"), 11: ("w", "W"), 12: (";", ":"),
    13: ("q", "Q"), 14: ("b", "B"), 15: ("y", "Y"), 16: ("r", "R"), 17: ("u", "U"), 18: ("[", "{"),
    19: ("]", "}"), 20: ("/", "?"), 21: ("p", "P"), 22: ("m", "M"), 23: ("f", "F"), 24: ("1", "!"),
    25: ("4", "$"), 26: ("l", "L"), 27: ("2", "@"), 28: ("j", "J"), 29: ("3", "#"), 30: ("=", "+"),
    31: (".", ">"), 32: ("s", "S"), 33: ("5", "%"), 34: ("o", "O"), 35: ("6", "^"), 37: ("z", "Z"),
    38: ("e", "E"), 39: ("7", "&"), 40: ("a", "A"), 41: ("8", "*"), 42: ("\\", "|"), 43: (",", "<"),
    44: ("9", "("), 45: ("n", "N"), 46: ("i", "I"), 47: ("0", ")"), 50: ("`", "~"),
  ]

  private static let dictDvorakRight: [UInt16: (String, String)] = [
    0: ("7", "&"), 1: ("8", "*"), 2: ("z", "Z"), 3: ("a", "A"), 4: ("h", "H"), 5: ("e", "E"),
    6: ("9", "("), 7: ("0", ")"), 8: ("x", "X"), 9: (",", "<"), 11: ("i", "I"), 12: ("5", "%"),
    13: ("6", "^"), 14: ("q", "Q"), 15: (".", ">"), 16: ("r", "R"), 17: ("o", "O"), 18: ("1", "!"),
    19: ("2", "@"), 20: ("3", "#"), 21: ("4", "$"), 22: ("l", "L"), 23: ("j", "J"), 24: ("]", "}"),
    25: ("p", "P"), 26: ("m", "M"), 27: ("[", "{"), 28: ("f", "F"), 29: ("/", "?"), 30: ("=", "+"),
    31: ("y", "Y"), 32: ("s", "S"), 33: (";", ":"), 34: ("u", "U"), 35: ("b", "B"), 37: ("c", "C"),
    38: ("t", "T"), 39: ("-", "_"), 40: ("d", "D"), 41: ("k", "K"), 42: ("\\", "|"), 43: ("v", "V"),
    44: ("\'", "\""), 45: ("n", "N"), 46: ("w", "W"), 47: ("g", "G"), 50: ("`", "~"),
  ]
}
