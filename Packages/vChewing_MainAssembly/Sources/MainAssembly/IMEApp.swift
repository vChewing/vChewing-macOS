// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Carbon
import Shared

// MARK: - Top-level Enums relating to Input Mode and Language Supports.

public enum IMEApp {
  // MARK: - 獲取輸入法的版本以及建置編號

  public static let appVersionLabel: String = {
    let maybeDateModified: Date? = {
      guard let executableURL = Bundle.main.executableURL,
            let infoDate = (try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      else {
        return nil
      }
      return infoDate
    }()

    func dateStringTag(date givenDate: Date) -> String {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyyMMdd.HHmm"
      dateFormatter.timeZone = .init(secondsFromGMT: +28800) ?? .current
      let strDate = dateFormatter.string(from: givenDate)
      return strDate
    }

    guard
      let intBuild = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
      let strVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    else {
      return "1.14.514 - 19190810"
    }

    var theResults = ["\(strVer) Build \(intBuild)"]

    if let theDate = Bundle.main.getCodeSignedDate() {
      theResults.append(dateStringTag(date: theDate))
    } else if let theDate = maybeDateModified {
      theResults.append("\(dateStringTag(date: theDate)) Unsigned")
    } else {
      theResults.append("Unsigned")
    }

    return theResults.joined(separator: " - ")
  }()

  // MARK: - 輸入法的當前的簡繁體中文模式

  public static var currentInputMode: Shared.InputMode {
    .init(rawValue: PrefMgr.shared.mostRecentInputMode) ?? .imeModeNULL
  }

  /// 當前鍵盤是否是 JIS 佈局
  public static var isKeyboardJIS: Bool {
    KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS
  }

  /// Fart or Beep?
  public static func buzz() {
    if PrefMgr.shared.isDebugModeEnabled {
      NSSound.buzz(fart: !PrefMgr.shared.shouldNotFartInLieuOfBeep)
    } else if !PrefMgr.shared.shouldNotFartInLieuOfBeep {
      NSSound.buzz(fart: true)
    } else {
      NSSound.beep()
    }
  }
}
