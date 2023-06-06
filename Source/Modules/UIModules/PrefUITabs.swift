// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared

enum PrefUITabs: String, CaseIterable {
  case tabGeneral = "General"
  case tabCandidates = "Candidates"
  case tabBehavior = "Behavior"
  case tabOutput = "Output"
  case tabDictionary = "Dictionary"
  case tabPhrases = "Phrases"
  case tabCassette = "Cassette"
  case tabKeyboard = "Keyboard"
  case tabDevZone = "DevZone"
}

extension PrefUITabs {
  private static let i18nTable: [String: (Hans: String, Hant: String, Ja: String)] = [
    "General": (Hans: "一般设定", Hant: "一般設定", Ja: "一般設定"),
    "Candidates": (Hans: "选字设定", Hant: "選字設定", Ja: "候補設定"),
    "Behavior": (Hans: "行为设定", Hant: "行為設定", Ja: "作動設定"),
    "Output": (Hans: "输出设定", Hant: "輸出設定", Ja: "出力設定"),
    "Dictionary": (Hans: "辞典设定", Hant: "辭典設定", Ja: "辞書設定"),
    "Phrases": (Hans: "语汇编辑", Hant: "語彙編輯", Ja: "辞書編集"),
    "Cassette": (Hans: "磁带设定", Hant: "磁帶設定", Ja: "カセ設定"),
    "Keyboard": (Hans: "键盘设定", Hant: "鍵盤設定", Ja: "配列設定"),
    "DevZone": (Hans: "开发道场", Hant: "開發道場", Ja: "開発道場"),
  ]

  var cocoaTag: Int {
    switch self {
    case .tabGeneral: return 10
    case .tabCandidates: return 20
    case .tabBehavior: return 30
    case .tabOutput: return 40
    case .tabDictionary: return 50
    case .tabPhrases: return 60
    case .tabCassette: return 70
    case .tabKeyboard: return 80
    case .tabDevZone: return 90
    }
  }

  static func fromInt(_ int: Int) -> Self? {
    switch int {
    case 10: return .tabGeneral
    case 20: return .tabCandidates
    case 30: return .tabBehavior
    case 40: return .tabOutput
    case 50: return .tabDictionary
    case 60: return .tabPhrases
    case 70: return .tabCassette
    case 80: return .tabKeyboard
    case 90: return .tabDevZone
    default: return nil
    }
  }

  var toolbarIdentifier: NSToolbarItem.Identifier { .init(rawValue: rawValue) }

  var i18nTitle: String {
    switch PrefMgr.shared.appleLanguages[0] {
    case "ja": return Self.i18nTable[rawValue]?.Ja ?? rawValue
    default:
      if PrefMgr.shared.appleLanguages[0].contains("zh-Hans") {
        return Self.i18nTable[rawValue]?.Hans ?? rawValue
      } else if PrefMgr.shared.appleLanguages[0].contains("zh-Hant") {
        return Self.i18nTable[rawValue]?.Hant ?? rawValue
      }
      return rawValue
    }
  }

  var icon: NSImage {
    if #available(macOS 11.0, *) {
      let name: String = {
        switch self {
        case .tabGeneral:
          return "wrench.and.screwdriver.fill"
        case .tabCandidates:
          return "filemenu.and.selection"
        case .tabBehavior:
          return "switch.2"
        case .tabOutput:
          return "text.append"
        case .tabDictionary:
          return "text.book.closed.fill"
        case .tabPhrases:
          return "tablecells.badge.ellipsis"
        case .tabCassette:
          return "externaldrive.fill.badge.plus"
        case .tabKeyboard:
          return "keyboard.macwindow"
        case .tabDevZone:
          return "pc"
        }
      }()
      let note = "\(self.rawValue) Preferences"
      return NSImage(systemSymbolName: name, accessibilityDescription: note) ?? NSImage()
    }
    let legacyName = "PrefToolbar-\(rawValue)"
    return NSImage(named: legacyName) ?? NSImage()
  }
}
