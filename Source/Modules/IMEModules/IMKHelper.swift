// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import InputMethodKit

// MARK: - IMKHelper by The vChewing Project (MIT License).

enum IMKHelper {
  /// 威注音有專門統計過，實際上會有差異的英數鍵盤佈局只有這幾種。
  /// 精簡成這種清單的話，不但節省 SwiftUI 的繪製壓力，也方便使用者做選擇。
  static let arrWhitelistedKeyLayoutsASCII: [String] = [
    "com.apple.keylayout.ABC",
    "com.apple.keylayout.ABC-AZERTY",
    "com.apple.keylayout.ABC-QWERTZ",
    "com.apple.keylayout.British",
    "com.apple.keylayout.Colemak",
    "com.apple.keylayout.Dvorak",
    "com.apple.keylayout.Dvorak-Left",
    "com.apple.keylayout.DVORAK-QWERTYCMD",
    "com.apple.keylayout.Dvorak-Right",
  ]

  static let arrDynamicBasicKeyLayouts: [String] = [
    "com.apple.keylayout.ZhuyinBopomofo",
    "com.apple.keylayout.ZhuyinEten",
    "org.atelierInmu.vChewing.keyLayouts.vchewingdachen",
    "org.atelierInmu.vChewing.keyLayouts.vchewingmitac",
    "org.atelierInmu.vChewing.keyLayouts.vchewingibm",
    "org.atelierInmu.vChewing.keyLayouts.vchewingseigyou",
    "org.atelierInmu.vChewing.keyLayouts.vchewingeten",
    "org.unknown.keylayout.vChewingDachen",
    "org.unknown.keylayout.vChewingFakeSeigyou",
    "org.unknown.keylayout.vChewingETen",
    "org.unknown.keylayout.vChewingIBM",
    "org.unknown.keylayout.vChewingMiTAC",
  ]

  static var allowedBasicLayoutsAsTISInputSources: [TISInputSource?] {
    // 為了保證清單順序，先弄兩個容器。
    var containerA: [TISInputSource?] = []
    var containerB: [TISInputSource?] = []
    var containerC: [TISInputSource?] = []

    let rawDictionary = TISInputSource.rawTISInputSources(onlyASCII: false)

    IMKHelper.arrWhitelistedKeyLayoutsASCII.forEach {
      if let neta = rawDictionary[$0], !arrDynamicBasicKeyLayouts.contains(neta.identifier) {
        containerC.append(neta)
      }
    }

    IMKHelper.arrDynamicBasicKeyLayouts.forEach {
      if let neta = rawDictionary[$0] {
        if neta.identifier.contains("com.apple") {
          containerA.append(neta)
        } else {
          containerB.append(neta)
        }
      }
    }

    // 這裡的 nil 是用來讓選單插入分隔符用的。
    if !containerA.isEmpty { containerA.append(nil) }
    if !containerB.isEmpty { containerB.append(nil) }

    return containerA + containerB + containerC
  }

  struct CarbonKeyboardLayout {
    var strName: String = ""
    var strValue: String = ""
  }
}

// MARK: - 與輸入法的具體的安裝過程有關的命令

extension IMKHelper {
  @discardableResult static func registerInputMethod() -> Int32 {
    TISInputSource.registerInputMethod() ? 0 : -1
  }
}

// MARK: - TISInputSource Extension by The vChewing Project (MIT License).

extension TISInputSource {
  public static var allRegisteredInstancesOfThisInputMethod: [TISInputSource] {
    TISInputSource.modes.compactMap { TISInputSource.generate(from: $0) }
  }

  public static var modes: [String] {
    guard let components = Bundle.main.infoDictionary?["ComponentInputModeDict"] as? [String: Any],
      let tsInputModeListKey = components["tsInputModeListKey"] as? [String: Any]
    else {
      return []
    }
    return tsInputModeListKey.keys.map { $0 }
  }

  @discardableResult public static func registerInputMethod() -> Bool {
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

  @discardableResult public static func registerInputSource() -> Bool {
    TISRegisterInputSource(Bundle.main.bundleURL as CFURL) == noErr
  }

  @discardableResult public func activate() -> Bool {
    TISEnableInputSource(self) == noErr
  }

  @discardableResult public func select() -> Bool {
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

  @discardableResult public func deactivate() -> Bool {
    TISDisableInputSource(self) == noErr
  }

  public var isActivated: Bool {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceIsEnabled), to: CFBoolean.self)
      == kCFBooleanTrue
  }

  public var isSelectable: Bool {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceIsSelectCapable), to: CFBoolean.self)
      == kCFBooleanTrue
  }

  public static func generate(from identifier: String) -> TISInputSource? {
    TISInputSource.rawTISInputSources(onlyASCII: false)[identifier] ?? nil
  }

  public var inputModeID: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputModeID), to: NSString.self) as String
  }

  public var vChewingLocalizedName: String {
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

extension TISInputSource {
  public var localizedName: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyLocalizedName), to: NSString.self) as String
  }

  public var identifier: String {
    unsafeBitCast(TISGetInputSourceProperty(self, kTISPropertyInputSourceID), to: NSString.self) as String
  }

  public var scriptCode: Int {
    let r = TISGetInputSourceProperty(self, "TSMInputSourcePropertyScriptCode" as CFString)
    return unsafeBitCast(r, to: NSString.self).integerValue
  }

  public static func rawTISInputSources(onlyASCII: Bool = false) -> [String: TISInputSource] {
    // 為了指定檢索條件，先構築 CFDictionary 辭典。
    // 第二項代指辭典容量。
    let conditions = CFDictionaryCreateMutable(nil, 2, nil, nil)
    if onlyASCII {
      // 第一條件：僅接收靜態鍵盤佈局結果。
      CFDictionaryAddValue(
        conditions, unsafeBitCast(kTISPropertyInputSourceType, to: UnsafeRawPointer.self),
        unsafeBitCast(kTISTypeKeyboardLayout, to: UnsafeRawPointer.self)
      )
      // 第二條件：只能輸入 ASCII 內容。
      CFDictionaryAddValue(
        conditions, unsafeBitCast(kTISPropertyInputSourceIsASCIICapable, to: UnsafeRawPointer.self),
        unsafeBitCast(kCFBooleanTrue, to: UnsafeRawPointer.self)
      )
    }
    // 返回鍵盤配列清單。
    var result = TISCreateInputSourceList(conditions, true).takeRetainedValue() as? [TISInputSource] ?? .init()
    if onlyASCII {
      result = result.filter { $0.scriptCode == 0 }
    }
    var resultDictionary: [String: TISInputSource] = [:]
    result.forEach {
      resultDictionary[$0.inputModeID] = $0
      resultDictionary[$0.identifier] = $0
    }
    return resultDictionary
  }
}
