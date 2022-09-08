// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

enum VersionUpdateApi {
  static let kCheckUpdateAutomatically = UserDef.kCheckUpdateAutomatically.rawValue
  static let kNextUpdateCheckDateKey = "NextUpdateCheckDate"
  static let kUpdateInfoEndpointKey = "UpdateInfoEndpoint"
  static let kUpdateInfoSiteKey = "UpdateInfoSite"
  static let kVersionDescription = "VersionDescription"
  static let kNextCheckInterval: TimeInterval = 86400.0
  static let kTimeoutInterval: TimeInterval = 60.0
  static func check(
    forced: Bool, callback: @escaping (Result<VersionUpdateApiResult, Error>) -> Void
  ) -> URLSessionTask? {
    guard let infoDict = Bundle.main.infoDictionary,
      let updateInfoURLString = infoDict[kUpdateInfoEndpointKey] as? String,
      let updateInfoURL = URL(string: updateInfoURLString)
    else {
      return nil
    }

    let request = URLRequest(
      url: updateInfoURL, cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: kTimeoutInterval
    )
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        DispatchQueue.main.async {
          forced
            ? callback(
              .failure(
                VersionUpdateApiError.connectionError(
                  message: error.localizedDescription)))
            : callback(.success(.ignored))
        }
        return
      }

      do {
        guard
          let plist = try PropertyListSerialization.propertyList(
            from: data ?? Data(), options: [], format: nil
          ) as? [AnyHashable: Any],
          let remoteVersion = plist[kCFBundleVersionKey] as? String,
          let infoDict = Bundle.main.infoDictionary
        else {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          return
        }

        // TODO: Validate info (e.g. bundle identifier)
        // TODO: Use HTML to display change log, need a new key like UpdateInfoChangeLogURL for this

        let currentVersion = infoDict[kCFBundleVersionKey as String] as? String ?? ""
        let result = currentVersion.compare(
          remoteVersion, options: .numeric, range: nil, locale: nil
        )

        if result != .orderedAscending {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          IME.prtDebugIntel(
            "vChewingDebug: Update // Order is not Ascending, assuming that there's no new version available."
          )
          return
        }
        IME.prtDebugIntel(
          "vChewingDebug: Update // New version detected, proceeding to the next phase.")
        guard let siteInfoURLString = plist[kUpdateInfoSiteKey] as? String,
          let siteInfoURL = URL(string: siteInfoURLString)
        else {
          DispatchQueue.main.async {
            forced
              ? callback(.success(.noNeedToUpdate))
              : callback(.success(.ignored))
          }
          IME.prtDebugIntel(
            "vChewingDebug: Update // Failed from retrieving / parsing URL intel.")
          return
        }
        IME.prtDebugIntel(
          "vChewingDebug: Update // URL intel retrieved, proceeding to the next phase.")
        var report = VersionUpdateReport(siteUrl: siteInfoURL)
        var versionDescription = ""
        let versionDescriptions = plist[kVersionDescription] as? [AnyHashable: Any]
        if let versionDescriptions = versionDescriptions {
          var locale = "en"
          let preferredTags = Bundle.preferredLocalizations(from: IME.arrSupportedLocales)
          if let first = preferredTags.first {
            locale = first
          }
          versionDescription =
            versionDescriptions[locale] as? String ?? versionDescriptions["en"]
            as? String ?? ""
          if !versionDescription.isEmpty {
            versionDescription = "\n\n" + versionDescription
          }
        }
        report.currentShortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
        report.currentVersion = currentVersion
        report.remoteShortVersion = plist["CFBundleShortVersionString"] as? String ?? ""
        report.remoteVersion = remoteVersion
        report.versionDescription = versionDescription
        DispatchQueue.main.async {
          callback(.success(.shouldUpdate(report: report)))
        }
        IME.prtDebugIntel("vChewingDebug: Update // Callbck Complete.")
      } catch {
        DispatchQueue.main.async {
          forced ? callback(.success(.noNeedToUpdate)) : callback(.success(.ignored))
        }
      }
    }
    task.resume()
    return task
  }

  private static var checkTask: URLSessionTask?
  static func checkForUpdate(forced: Bool = false) {
    if checkTask != nil {
      // busy
      return
    }

    // time for update?
    if !forced {
      if !mgrPrefs.checkUpdateAutomatically {
        return
      }
      let now = Date()
      let date = UserDefaults.standard.object(forKey: VersionUpdateApi.kNextUpdateCheckDateKey) as? Date ?? now
      if now.compare(date) == .orderedAscending {
        return
      }
    }

    let nextUpdateDate = Date(timeInterval: VersionUpdateApi.kNextCheckInterval, since: Date())
    UserDefaults.standard.set(nextUpdateDate, forKey: VersionUpdateApi.kNextUpdateCheckDateKey)

    checkTask = VersionUpdateApi.check(forced: forced) { [self] result in
      defer {
        checkTask = nil
      }
      switch result {
        case .success(let apiResult):
          switch apiResult {
            case .shouldUpdate(let report):
              let content = String(
                format: NSLocalizedString(
                  "You're currently using vChewing %@ (%@), a new version %@ (%@) is now available. Do you want to visit vChewing's website to download the version?%@",
                  comment: ""
                ),
                report.currentShortVersion,
                report.currentVersion,
                report.remoteShortVersion,
                report.remoteVersion,
                report.versionDescription
              )
              IME.prtDebugIntel("vChewingDebug: \(content)")
              let alert = NSAlert()
              alert.messageText = NSLocalizedString("New Version Available", comment: "")
              alert.informativeText = content
              alert.addButton(withTitle: NSLocalizedString("Visit Website", comment: ""))
              alert.addButton(withTitle: NSLocalizedString("Not Now", comment: ""))
              NSApp.setActivationPolicy(.accessory)
              let result = alert.runModal()
              if result == NSApplication.ModalResponse.alertFirstButtonReturn {
                if let siteURL = report.siteUrl {
                  NSWorkspace.shared.open(siteURL)
                }
              }
            case .noNeedToUpdate, .ignored:
              break
          }
        case .failure(let error):
          switch error {
            case VersionUpdateApiError.connectionError(let message):
              let title = NSLocalizedString("Update Check Failed", comment: "")
              let content = String(
                format: NSLocalizedString(
                  "There may be no internet connection or the server failed to respond.\n\nError message: %@",
                  comment: ""
                ), message
              )
              let buttonTitle = NSLocalizedString("Dismiss", comment: "")
              IME.prtDebugIntel("vChewingDebug: \(content)")

              let alert = NSAlert()
              alert.messageText = title
              alert.informativeText = content
              alert.addButton(withTitle: buttonTitle)
              alert.runModal()
              NSApp.setActivationPolicy(.accessory)
            default:
              break
          }
      }
    }
  }

  struct VersionUpdateReport {
    var siteUrl: URL?
    var currentShortVersion: String = ""
    var currentVersion: String = ""
    var remoteShortVersion: String = ""
    var remoteVersion: String = ""
    var versionDescription: String = ""
  }

  enum VersionUpdateApiResult {
    case shouldUpdate(report: VersionUpdateReport)
    case noNeedToUpdate
    case ignored
  }

  enum VersionUpdateApiError: Error, LocalizedError {
    case connectionError(message: String)

    var errorDescription: String? {
      switch self {
        case .connectionError(let message):
          return String(
            format: NSLocalizedString(
              "There may be no internet connection or the server failed to respond.\n\nError message: %@",
              comment: ""
            ), message
          )
      }
    }
  }
}
