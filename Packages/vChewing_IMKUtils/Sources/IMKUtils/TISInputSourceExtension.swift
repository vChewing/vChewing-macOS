// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import InputMethodKit

// MARK: - TISInputSource Extension by The vChewing Project (MIT-NTL License).

public extension TISInputSource {
  struct KeyboardLayout: Identifiable {
    public var id: String
    public var titleLocalized: String
  }

  static var allRegisteredInstancesOfThisInputMethod: [TISInputSource] {
    TISInputSource.match(modeIDs: TISInputSource.modes)
  }

  static var modes: [String] {
    guard let components = Bundle.main.infoDictionary?["ComponentInputModeDict"] as? [String: Any],
          let tsInputModeListKey = components["tsInputModeListKey"] as? [String: Any]
    else {
      return []
    }
    return tsInputModeListKey.keys.map(\.description)
  }

  @discardableResult static func registerInputMethod() -> Bool {
    let instances = TISInputSource.allRegisteredInstancesOfThisInputMethod
    if instances.isEmpty {
      // 有實例尚未登記。執行登記手續。
      NSLog("Registering input source.")
      if !TISInputSource.registerInputSource() {
        NSLog("Input source registration failed.")
        return false
      }
    }
    var succeeded = true
    instances.forEach {
      NSLog("Enabling input source: \($0.identifier)")
      if !$0.activate() {
        NSLog("Failed from enabling input source: \($0.identifier)")
        succeeded = false
      }
    }
    return succeeded
  }

  @discardableResult static func registerInputSource() -> Bool {
    TISRegisterInputSource(Bundle.main.bundleURL as CFURL) == noErr
  }

  @discardableResult func activate() -> Bool {
    TISEnableInputSource(self) == noErr
  }

  @discardableResult func select() -> Bool {
    if !isSelectable {
      NSLog("Non-selectable: \(identifier)")
      return false
    }
    if TISSelectInputSource(self) != noErr {
      NSLog("Failed from switching to \(identifier)")
      return false
    }
    return true
  }

  @discardableResult func deactivate() -> Bool {
    TISDisableInputSource(self) == noErr
  }

  var isActivated: Bool {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceIsEnabled), to: CFBoolean.self)
      == kCFBooleanTrue
  }

  var isSelectable: Bool {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceIsSelectCapable), to: CFBoolean.self)
      == kCFBooleanTrue
  }

  var inputModeID: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputModeID), to: NSString.self) as String? ?? ""
  }

  var vChewingLocalizedName: String {
    switch identifier {
    case "com.apple.keylayout.ZhuyinBopomofo":
      return NSLocalizedString("Apple Zhuyin Bopomofo (Dachen)", comment: "")
    case "com.apple.keylayout.ZhuyinEten":
      return NSLocalizedString("Apple Zhuyin Eten (Traditional)", comment: "")
    default: return localizedName
    }
  }
}

// MARK: - TISInputSource Extension by Mizuno Hiroki (a.k.a. "Mzp") (MIT License)

// Ref: Original source codes are written in Swift 4 from Mzp's InputMethodKit textbook.
// Note: Slightly modified by vChewing Project: Using Dictionaries when necessary.

public extension TISInputSource {
  var localizedName: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyLocalizedName), to: NSString.self) as String? ?? ""
  }

  var identifier: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceID), to: NSString.self) as String? ?? ""
  }

  var scriptCode: Int {
    // Shiki's note: There is no "kTISPropertyScriptCode" in TextInputSources.h file.
    // Using Mzp's latest solution in his blog: https://mzp.hatenablog.com/entry/2018/07/16/212026
    let r = TISGetInputSourceProperty(self, "TSMInputSourcePropertyScriptCode" as CFString)
    return unsafeBitCast(r, to: NSString.self).integerValue as Int? ?? 0
  }

  // Refactored by Shiki Suen.
  static func match(identifiers: [String] = [], modeIDs: [String] = [], onlyASCII: Bool = false) -> [TISInputSource] {
    let dicConditions: [CFString: Any] = !onlyASCII ? [:] : [
      kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString,
      kTISPropertyInputSourceIsASCIICapable: kCFBooleanTrue as CFBoolean,
    ]
    let cfDict = !onlyASCII ? nil : dicConditions as CFDictionary
    var resultStack: [TISInputSource] = []
    let unionedIDs = NSOrderedSet(array: modeIDs + identifiers).compactMap { $0 as? String }
    let retrieved = (TISCreateInputSourceList(cfDict, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
    retrieved.forEach { tis in
      unionedIDs.forEach { id in
        guard tis.identifier == id || tis.inputModeID == id else { return }
        if onlyASCII {
          guard tis.scriptCode == 0 else { return }
        }
        resultStack.append(tis)
      }
    }
    // 為了保持指定排序，才在最後做這種處理。效能略有打折，但至少比起直接迭代容量破百的 retrieved 要好多了。
    return unionedIDs.compactMap { currentIdentifier in
      retrieved.first { $0.identifier == currentIdentifier || $0.inputModeID == currentIdentifier }
    }
  }

  /// 備註：這是 Mzp 的原版函式，留在這裡當範本參考。上述的 .match() 函式都衍生自此。
  static func rawTISInputSources(onlyASCII: Bool = false) -> [TISInputSource] {
    // 為了指定檢索條件，先構築 CFDictionary 辭典。
    let dicConditions: [CFString: Any] = !onlyASCII ? [:] : [
      kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString,
      kTISPropertyInputSourceIsASCIICapable: kCFBooleanTrue as CFBoolean,
    ]
    // 返回鍵盤配列清單。
    var result = TISCreateInputSourceList(dicConditions as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource] ?? .init()
    if onlyASCII {
      result = result.filter { $0.scriptCode == 0 }
    }
    return result
  }

  /// Derived from rawTISInputSources().
  static func getAllTISInputKeyboardLayoutMap() -> [String: TISInputSource.KeyboardLayout] {
    // 為了指定檢索條件，先構築 CFDictionary 辭典。
    let dicConditions: [CFString: Any] = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString]
    // 返回鍵盤配列清單。
    let result = TISCreateInputSourceList(dicConditions as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource] ?? .init()
    var resultDictionary: [String: TISInputSource.KeyboardLayout] = [:]
    result.forEach {
      let newNeta1 = TISInputSource.KeyboardLayout(id: $0.inputModeID, titleLocalized: $0.vChewingLocalizedName)
      let newNeta2 = TISInputSource.KeyboardLayout(id: $0.identifier, titleLocalized: $0.vChewingLocalizedName)
      resultDictionary[$0.inputModeID] = newNeta1
      resultDictionary[$0.identifier] = newNeta2
    }
    return resultDictionary
  }
}
