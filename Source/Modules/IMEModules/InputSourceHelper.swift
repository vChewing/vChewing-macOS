// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import InputMethodKit

public class InputSourceHelper: NSObject {
  @available(*, unavailable)
  override public init() {
    super.init()
  }

  public static func allInstalledInputSources() -> [TISInputSource] {
    TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
  }

  public static func inputSource(for propertyKey: CFString, stringValue: String)
    -> TISInputSource?
  {
    let stringID = CFStringGetTypeID()
    for source in allInstalledInputSources() {
      if let propertyPtr = TISGetInputSourceProperty(source, propertyKey) {
        let property = Unmanaged<CFTypeRef>.fromOpaque(propertyPtr).takeUnretainedValue()
        let typeID = CFGetTypeID(property)
        if typeID != stringID {
          continue
        }
        if stringValue == property as? String {
          return source
        }
      }
    }
    return nil
  }

  public static func inputSource(for sourceID: String) -> TISInputSource? {
    inputSource(for: kTISPropertyInputSourceID, stringValue: sourceID)
  }

  public static func inputSourceEnabled(for source: TISInputSource) -> Bool {
    if let valuePts = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) {
      let value = Unmanaged<CFBoolean>.fromOpaque(valuePts).takeUnretainedValue()
      return value == kCFBooleanTrue
    }
    return false
  }

  public static func enable(inputSource: TISInputSource) -> Bool {
    let status = TISEnableInputSource(inputSource)
    return status == noErr
  }

  public static func enableAllInputMode(for inputSourceBundleD: String) -> Bool {
    var enabled = false
    for source in allInstalledInputSources() {
      guard let bundleIDPtr = TISGetInputSourceProperty(source, kTISPropertyBundleID),
        let _ = TISGetInputSourceProperty(source, kTISPropertyInputModeID)
      else {
        continue
      }
      let bundleID = Unmanaged<CFString>.fromOpaque(bundleIDPtr).takeUnretainedValue()
      if String(bundleID) == inputSourceBundleD {
        let modeEnabled = enable(inputSource: source)
        if !modeEnabled {
          return false
        }
        enabled = true
      }
    }

    return enabled
  }

  public static func enable(inputMode modeID: String, for bundleID: String) -> Bool {
    for source in allInstalledInputSources() {
      guard let bundleIDPtr = TISGetInputSourceProperty(source, kTISPropertyBundleID),
        let modePtr = TISGetInputSourceProperty(source, kTISPropertyInputModeID)
      else {
        continue
      }
      let inputsSourceBundleID = Unmanaged<CFString>.fromOpaque(bundleIDPtr)
        .takeUnretainedValue()
      let inputsSourceModeID = Unmanaged<CFString>.fromOpaque(modePtr).takeUnretainedValue()
      if modeID == String(inputsSourceModeID), bundleID == String(inputsSourceBundleID) {
        let enabled = enable(inputSource: source)
        print(
          "Attempt to enable input source of mode: \(modeID), bundle ID: \(bundleID), result: \(enabled)"
        )
        return enabled
      }
    }
    print("Failed to find any matching input source of mode: \(modeID), bundle ID: \(bundleID)")
    return false
  }

  public static func disable(inputSource: TISInputSource) -> Bool {
    let status = TISDisableInputSource(inputSource)
    return status == noErr
  }

  public static func registerTnputSource(at url: URL) -> Bool {
    let status = TISRegisterInputSource(url as CFURL)
    return status == noErr
  }
}
