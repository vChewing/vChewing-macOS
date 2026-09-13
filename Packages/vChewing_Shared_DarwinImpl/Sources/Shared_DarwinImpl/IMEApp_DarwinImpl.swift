// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

#if canImport(Carbon)
  import Carbon
#endif

extension IMEApp {
  // MARK: - 獲取輸入法的版本以及建置編號

  public static let appVersionLabel: String = {
    [appMainVersionLabel.joined(separator: " Build "), appSignedDateLabel].joined(separator: " - ")
  }()

  public static let appMainVersionLabel: [String] = {
    #if canImport(Darwin)
      guard let intBuild = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
            let strVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      else {
        return ["1.14.514", "19190810"]
      }

      return [strVer, intBuild]
    #else
      return ["1.14.514", "19190810"]
    #endif
  }()

  public static let appSignedDateLabel: String = {
    #if canImport(Darwin)
      let maybeDateModified: Date? = {
        guard let executableURL = Bundle.main.executableURL,
              let infoDate = (
                try? executableURL
                  .resourceValues(forKeys: [.contentModificationDateKey])
              )?.contentModificationDate
        else {
          return nil
        }
        return infoDate
      }()

      if let theDate = Bundle.main.getCodeSignedDate() {
        return theDate.stringTag
      } else if let theDate = maybeDateModified {
        return "\(theDate.stringTag) Unsigned"
      } else {
        return "Unsigned"
      }
    #else
      return "Unsigned"
    #endif
  }()

  /// 當前鍵盤是否是 JIS 佈局
  public static var isKeyboardJIS: Bool {
    #if canImport(Carbon)
      return KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS
    #else
      // TODO: 需要找個方法判定 Linux 系統下怎樣辨識 JIS 鍵盤佈局。
      return false
    #endif
  }

  /// Fart or Beep?
  public static func buzz() {
    let prefs = PrefMgr.sharedSansDidSetOps
    switch prefs.beepSoundPreference {
    case 0: return
    case 1: NSSound.beep()
    default: NSSound.buzz(fart: !prefs.shouldNotFartInLieuOfBeep)
    }
  }
}

extension Date {
  public var stringTag: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd.HHmm"
    dateFormatter.timeZone = .init(secondsFromGMT: +28_800) ?? .current
    let strDate = dateFormatter.string(from: self)
    return strDate
  }
}
